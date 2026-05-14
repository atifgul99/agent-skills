const helpers = require('./lib/helpers');
const fs = require('node:fs');
const path = require('node:path');

const COMMUNITY = process.env.SKOOL_COMMUNITY || 'launchfree';
const OUTPUT_DIR = process.env.SKOOL_OUT_DIR ||
  `/Volumes/SSD/code/work/claude-course/research/skool-${COMMUNITY}`;
const BASE = `https://www.skool.com/${COMMUNITY}`;

// ---------- TipTap → Markdown + asset extractor ----------------------------

function tiptapText(node, accImages, accLinks) {
  if (!node) return '';
  if (typeof node === 'string') {
    if (node.startsWith('[v2]')) {
      try { return tiptapText(JSON.parse(node.slice(4)), accImages, accLinks); }
      catch { return node.slice(4); }
    }
    return node;
  }
  if (Array.isArray(node)) return node.map(n => tiptapText(n, accImages, accLinks)).join('');
  const { type, content = [], text, attrs = {}, marks = [] } = node;
  const inner = tiptapText(content, accImages, accLinks);
  switch (type) {
    case 'doc': return inner;
    case 'paragraph': return `${inner}\n\n`;
    case 'heading': return `${'#'.repeat(attrs.level || 2)} ${inner}\n\n`;
    case 'bulletList': return `${inner}\n`;
    case 'orderedList': return `${inner}\n`;
    case 'listItem': return `- ${inner.trim()}\n`;
    case 'blockquote': return `> ${inner.trim().replaceAll('\n', '\n> ')}\n\n`;
    case 'codeBlock': return `\`\`\`\n${inner}\n\`\`\`\n\n`;
    case 'horizontalRule': return `\n---\n\n`;
    case 'hardBreak': return '\n';
    case 'image': {
      if (attrs.src && accImages) accImages.push({ url: attrs.src, alt: attrs.alt || '' });
      return `![${attrs.alt || ''}](${attrs.src || ''})\n\n`;
    }
    case 'text': {
      let out = text || '';
      const link = marks.find(m => m.type === 'link');
      const isBold = marks.some(m => m.type === 'bold');
      const isItalic = marks.some(m => m.type === 'italic');
      const isCode = marks.some(m => m.type === 'code');
      if (isCode) out = `\`${out}\``;
      if (isBold) out = `**${out}**`;
      if (isItalic) out = `_${out}_`;
      if (link) {
        if (accLinks) accLinks.push({ text: text || '', url: link.attrs.href });
        out = `[${out}](${link.attrs.href})`;
      }
      return out;
    }
    default: return inner;
  }
}

function detectVideoSource(url) {
  if (!url) return null;
  if (/loom\.com\/share\//.test(url)) return 'loom';
  if (/(?:youtube\.com\/watch|youtu\.be\/)/.test(url)) return 'youtube';
  if (/vimeo\.com\//.test(url)) return 'vimeo';
  if (/stream\.mux\.com\//.test(url)) return 'mux';
  if (/wistia\./.test(url)) return 'wistia';
  return 'other';
}

function loomIdFromThumbnail(url) {
  const m = /loom\.com\/sessions\/thumbnails\/([a-f0-9]{20,})/.exec(url || '');
  return m ? m[1] : null;
}

function muxIdFromThumbnail(url) {
  const m = /image\.mux\.com\/([A-Za-z0-9]+)\//.exec(url || '');
  return m ? m[1] : null;
}

function safeFilename(s) {
  return (s || 'untitled')
    .replaceAll(/[^a-z0-9]+/gi, '-')
    .toLowerCase()
    .replaceAll(/^-|-$/g, '')
    .slice(0, 60);
}

function findInTree(children, id) {
  if (!Array.isArray(children)) return null;
  for (const ch of children) {
    if (ch.course?.id === id) return ch;
    const got = findInTree(ch.children, id);
    if (got) return got;
  }
  return null;
}

async function loadProps(page, url) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(1500);
  return await page.evaluate(() => {
    const el = document.getElementById('__NEXT_DATA__');
    return el ? JSON.parse(el.textContent).props.pageProps : null;
  });
}

// ---------- per-lesson probe (resolves Mux IDs / DOM links) ----------------

async function probeLesson(page, courseUrl, lessonId) {
  const url = `${courseUrl}?md=${lessonId}`;
  let props;
  try { props = await loadProps(page, url); }
  catch { return { url, error: 'navigation_failed' }; }

  const matched = findInTree(props?.course?.children || [], lessonId);
  const m = matched?.course?.metadata || {};
  const out = { url, metadata: m };

  // Skool serves Mux videos behind a short-lived JWT in props.video.playbackToken.
  // Without the token, stream.mux.com returns 403. Capture token + expiry so
  // fetch-assets.js can download before the token expires (~1h window).
  if (props?.video?.playbackId) {
    out.muxPlaybackId = props.video.playbackId;
    out.muxPlaybackToken = props.video.playbackToken || null;
    out.muxTokenExpire = props.video.expire || null;
    out.muxDurationMs = props.video.duration || null;
  }

  const loomId = loomIdFromThumbnail(m.videoThumbnail);
  if (!m.videoLink && loomId) {
    out.derivedVideoLink = `https://www.loom.com/share/${loomId}`;
  }
  if (!out.muxPlaybackId) {
    const muxId = muxIdFromThumbnail(m.videoThumbnail);
    if (muxId) out.muxPlaybackId = muxId;
  }

  const dom = await page.evaluate(() => {
    const main = document.querySelector('main') || document.body;
    const text = main.innerText || '';
    const locked = /unlock with premium|locked|upgrade to/i.test(text);
    const links = Array.from(main.querySelectorAll('a[href]'))
      .map(a => ({ text: a.innerText.trim().slice(0, 120), href: a.href }))
      .filter(l => l.href && l.text)
      .slice(0, 50);
    return { locked, links };
  });

  out.locked = dom.locked && !m.videoLink && !m.desc;
  out.domLinks = dom.links;
  return out;
}

// ---------- collect lessons (flatten leaves with section path) -------------

function collectLeaves(children, ordCounter, sectionPath) {
  const leaves = [];
  if (!Array.isArray(children)) return leaves;
  for (const child of children) {
    const c = child.course || child;
    const m = c.metadata || {};
    const isLeaf = c.unitType === 'module' || (!Array.isArray(child.children) || child.children.length === 0);
    if (isLeaf) {
      ordCounter.n += 1;
      leaves.push({
        ordinal: ordCounter.n,
        node: child,
        section: sectionPath.length ? sectionPath.join(' / ') : null,
      });
    } else {
      const nested = collectLeaves(child.children, ordCounter, [...sectionPath, m.title || c.name]);
      leaves.push(...nested);
    }
  }
  return leaves;
}

// ---------- manifest builder ----------------------------------------------

function buildManifest(course, courseUrl, leaves, probedMap, scrapedAt) {
  const lessons = [];
  for (const leaf of leaves) {
    const c = leaf.node.course || leaf.node;
    const m = c.metadata || {};
    const probed = probedMap.get(c.id) || {};

    const accImages = [];
    const accLinks = [];
    if (m.desc) tiptapText(m.desc, accImages, accLinks);

    let videoUrl = m.videoLink || probed.derivedVideoLink || null;
    let videoSource = detectVideoSource(videoUrl);
    let muxToken = null;
    let muxTokenExpire = null;
    if (!videoUrl && probed.muxPlaybackId) {
      videoUrl = `https://stream.mux.com/${probed.muxPlaybackId}.m3u8`;
      videoSource = 'mux';
      muxToken = probed.muxPlaybackToken || null;
      muxTokenExpire = probed.muxTokenExpire || null;
    }

    let attachments = [];
    if (m.resources && m.resources !== '[]') {
      try {
        const r = JSON.parse(m.resources);
        if (Array.isArray(r)) {
          attachments = r.map(res => ({
            label: res.title || res.name || res.label || 'resource',
            url: res.url || res.link || res.href || '',
          })).filter(a => a.url);
        }
      } catch { /* ignore */ }
    }

    const externalLinks = [];
    const seenLinks = new Set();
    const pushLink = (text, url) => {
      if (!url || !/^https?:/.test(url)) return;
      if (seenLinks.has(url)) return;
      seenLinks.add(url);
      externalLinks.push({ text: (text || '').slice(0, 200), url });
    };
    accLinks.forEach(l => pushLink(l.text, l.url));
    (probed.domLinks || []).forEach(l => {
      if (/^https?:\/\/(www\.)?skool\.com\/[^/]+(?:\/|$|\?)/.test(l.href) &&
          !/\/p\//.test(l.href)) return;
      pushLink(l.text, l.href);
    });

    lessons.push({
      ordinal: leaf.ordinal,
      id: c.id,
      slug: `${String(leaf.ordinal).padStart(2, '0')}-${safeFilename(m.title || c.name)}`,
      title: m.title || c.name || '(Untitled)',
      section: leaf.section,
      locked: !!probed.locked || (!videoUrl && !m.desc),
      url: probed.url || `${courseUrl}?md=${c.id}`,
      video: videoUrl ? {
        url: videoUrl,
        source: videoSource,
        thumbnail: m.videoThumbnail || null,
        lengthMs: m.videoLenMs || probed.muxDurationMs || null,
        muxToken,
        muxTokenExpire,
      } : null,
      images: accImages,
      attachments,
      externalLinks,
    });
  }

  return {
    community: COMMUNITY,
    course: {
      id: course.id,
      name: course.name,
      title: course.metadata?.title || course.name,
      url: courseUrl,
      coverImage: course.metadata?.coverImage || null,
      description: course.metadata?.desc ? tiptapText(course.metadata.desc).trim() : null,
      scrapedAt,
    },
    lessons,
  };
}

// ---------- markdown writer -----------------------------------------------

function buildCourseMarkdown(manifest, leaves) {
  const c = manifest.course;
  let md = `# ${c.title}\n\n`;
  md += `**Source:** ${c.url}\n\n`;
  md += `**Scraped:** ${c.scrapedAt}\n\n`;
  if (c.description) md += `${c.description}\n\n`;
  if (c.coverImage) md += `![cover](${c.coverImage})\n\n`;
  md += `---\n\n`;

  const sectionStack = [];
  manifest.lessons.forEach((lesson, i) => {
    const parts = lesson.section ? lesson.section.split(' / ') : [];
    let depth = 0;
    while (depth < parts.length && depth < sectionStack.length && sectionStack[depth] === parts[depth]) depth++;
    sectionStack.length = depth;
    while (sectionStack.length < parts.length) {
      const sec = parts[sectionStack.length];
      const h = '#'.repeat(Math.min(2 + sectionStack.length, 6));
      md += `${h} ${sec}\n\n`;
      sectionStack.push(sec);
    }

    const leafMeta = (leaves[i].node.course || leaves[i].node).metadata || {};
    const headingLevel = '#'.repeat(Math.min(2 + sectionStack.length, 6));
    md += `${headingLevel} ${lesson.title}\n\n`;
    if (lesson.locked && !lesson.video) md += `> 🔒 **Locked (Premium content)**\n\n`;
    if (lesson.video?.url) {
      md += `**Video:** ${lesson.video.url}  (\`${lesson.video.source}\`)\n\n`;
      if (lesson.video.lengthMs) {
        const mins = Math.floor(lesson.video.lengthMs / 60000);
        const secs = Math.round((lesson.video.lengthMs % 60000) / 1000);
        md += `**Duration:** ${mins}m ${secs}s\n\n`;
      }
    }
    if (leafMeta.desc) {
      const desc = tiptapText(leafMeta.desc).trim();
      if (desc) md += `${desc}\n\n`;
    }
    if (lesson.attachments?.length) {
      md += `**Attachments:**\n`;
      lesson.attachments.forEach(a => md += `- [${a.label}](${a.url})\n`);
      md += '\n';
    }
    md += `**Asset folder:** \`lessons/${lesson.slug}/\`\n\n`;
    md += `---\n\n`;
  });
  return md;
}

// ---------- main ----------------------------------------------------------

(async () => {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  fs.mkdirSync(path.join(OUTPUT_DIR, 'courses'), { recursive: true });

  const { browser, context } = await helpers.launchPersistent();
  const page = context.pages().find(p => p.url().includes('skool.com'));
  if (!page) { console.log('No Skool tab — open one first.'); await browser.close(); return; }
  await page.bringToFront();

  console.log(`📚 Loading classroom index: ${BASE}/classroom`);
  const indexProps = await loadProps(page, `${BASE}/classroom`);
  const allCourses = indexProps?.allCourses;
  if (!allCourses) {
    console.log('Could not find allCourses. Are you logged in & a member?');
    await browser.close();
    return;
  }

  console.log(`Found ${allCourses.length} courses.\n`);

  const scrapedAt = new Date().toISOString();
  const indexEntries = [];
  const tocLines = [
    `# Skool Community: ${COMMUNITY}\n`,
    `Source: ${BASE}/classroom`,
    `Scraped: ${scrapedAt}\n`,
    `Run \`fetch-assets.js\` to download transcripts/images/attachments.\n`,
    `## Courses\n`,
  ];

  for (let i = 0; i < allCourses.length; i++) {
    const course = allCourses[i];
    const courseTitle = course.metadata?.title || course.name;
    const courseSlug = `${String(i + 1).padStart(2, '0')}-${safeFilename(courseTitle)}`;
    const courseUrl = `${BASE}/classroom/${course.name}`;
    const courseDir = path.join(OUTPUT_DIR, 'courses', courseSlug);
    fs.mkdirSync(courseDir, { recursive: true });
    fs.mkdirSync(path.join(courseDir, 'lessons'), { recursive: true });

    console.log(`[${i + 1}/${allCourses.length}] ${courseTitle}`);

    try {
      const props = await loadProps(page, courseUrl);
      const courseTree = props?.course;
      if (!courseTree) { console.log(`   ⚠️  No payload`); continue; }

      const ord = { n: 0 };
      const leaves = collectLeaves(courseTree.children || [], ord, []);

      const probedMap = new Map();
      for (const leaf of leaves) {
        const c = leaf.node.course || leaf.node;
        const m = c.metadata || {};
        const needsProbe = !m.videoLink && !m.desc;
        if (needsProbe) {
          process.stdout.write(`     · probing ${m.title || c.name}\r`);
          const probed = await probeLesson(page, courseUrl, c.id);
          probedMap.set(c.id, probed);
        }
      }

      const manifest = buildManifest(courseTree.course || course, courseUrl, leaves, probedMap, scrapedAt);
      fs.writeFileSync(path.join(courseDir, 'manifest.json'), JSON.stringify(manifest, null, 2));

      const courseMd = buildCourseMarkdown(manifest, leaves);
      fs.writeFileSync(path.join(courseDir, 'course.md'), courseMd);

      for (const lesson of manifest.lessons) {
        fs.mkdirSync(path.join(courseDir, 'lessons', lesson.slug), { recursive: true });
      }

      const totalLessons = manifest.lessons.length;
      const lockedCount = manifest.lessons.filter(l => l.locked).length;
      const videoCount = manifest.lessons.filter(l => l.video?.url).length;

      indexEntries.push({
        ordinal: i + 1,
        title: manifest.course.title,
        slug: courseSlug,
        url: courseUrl,
        lessons: totalLessons,
        videos: videoCount,
        locked: lockedCount,
      });
      tocLines.push(`${i + 1}. **${manifest.course.title}** — [${courseSlug}/](courses/${courseSlug}/course.md) (${totalLessons} lessons, ${videoCount} with video${lockedCount ? `, ${lockedCount} locked` : ''})`);

      console.log(`   💾 ${courseSlug}/  (${totalLessons} lessons, ${videoCount} videos, ${lockedCount} locked)`);
    } catch (e) {
      console.log(`   ❌ ${e.message}`);
    }
  }

  fs.writeFileSync(path.join(OUTPUT_DIR, 'README.md'), tocLines.join('\n') + '\n');
  fs.writeFileSync(path.join(OUTPUT_DIR, 'index.json'),
    JSON.stringify({ community: COMMUNITY, source: `${BASE}/classroom`, scrapedAt, courses: indexEntries }, null, 2));
  console.log(`\n✅ Done. ${indexEntries.length} courses written to ${OUTPUT_DIR}`);
  console.log(`Next: node ~/.claude/skills/skool-scraper/scripts/fetch-assets.js --root ${OUTPUT_DIR}`);

  await browser.close();
})();
