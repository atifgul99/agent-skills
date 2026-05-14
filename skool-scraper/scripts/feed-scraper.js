const helpers = require('./lib/helpers');
const fs = require('node:fs');
const path = require('node:path');

const COMMUNITY = process.env.SKOOL_COMMUNITY || 'launchfree';
const OUTPUT = process.env.SKOOL_FEED_OUT || '/Volumes/SSD/code/work/claude-course/research/skool-community-launch/feed-sanitized.md';
const BASE = `https://www.skool.com/${COMMUNITY}`;

const PROMO_PATTERNS = [
  /buy now/i, /limited time/i, /dm me/i, /only \$/i, /\bdiscount\b/i,
  /promo code/i, /\baffiliate\b/i, /free trial/i, /click here to buy/i,
  /enroll now/i, /special offer/i, /act now/i, /order now/i, /grab it/i,
  /\bcoupon\b/i, /\bcheckout\b/i, /book a call/i, /sign up here/i,
];

function isValuable(title, body) {
  const text = `${title} ${body}`;
  if (text.trim().length < 30) return false;
  const hits = PROMO_PATTERNS.filter(re => re.test(text)).length;
  return hits < 2;
}

function sanitize(s) {
  return (s || '').replace(/\s+/g, ' ').trim();
}

function postKey(p) {
  return (p.title + '|' + p.content.slice(0, 100)).trim();
}

(async () => {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });

  const { browser, context } = await helpers.launchPersistent();
  const page = context.pages().find(p => p.url().includes('skool.com'));
  if (!page) { console.log('No skool tab'); await browser.close(); return; }
  await page.bringToFront();

  console.log(`📥 Loading community feed: ${BASE}`);
  await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(4000);

  // Try to read pinned posts from __NEXT_DATA__ if available (high signal)
  const pinnedPosts = await page.evaluate(() => {
    const el = document.getElementById('__NEXT_DATA__');
    if (!el) return [];
    try { return JSON.parse(el.textContent).props.pageProps.pinnedPosts || []; }
    catch { return []; }
  });
  console.log(`   pinned posts in __NEXT_DATA__: ${pinnedPosts.length}`);

  const allPosts = [];
  let lastCount = 0;
  let stable = 0;

  for (let i = 0; i < 30; i++) {
    const posts = await page.evaluate(() => {
      const containers = Array.from(document.querySelectorAll('[class*="PostItem"], [class*="PostCard"], [class*="FeedItem"], [class*="PostWrapper"]'));
      const seen = new Set();
      const out = [];
      for (const el of containers) {
        const all = el.innerText.split('\n').map(s => s.trim()).filter(Boolean);
        const titleEl = el.querySelector('[class*="Title"], h1, h2, h3');
        const title = titleEl?.innerText?.trim() || all[0] || '';
        const authorEl = el.querySelector('[class*="Author"], [class*="UserName"]');
        const author = authorEl?.innerText.trim().split('\n')[0] || '';
        const ignore = new Set([title, author, 'Like', 'Comment', 'Share', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'New comment', 'Pinned']);
        const content = all.filter(line =>
          !ignore.has(line) &&
          line.length > 5 &&
          !/^\d+\s*(min|hour|day|week|month|year)s?\s+ago$/i.test(line) &&
          !/^(\d+|likes?|comments?|shares?)$/i.test(line)
        ).join('\n');
        const key = (title + content.slice(0, 60)).trim();
        if (!key || seen.has(key)) continue;
        seen.add(key);
        const linkEl = el.querySelector('a[href*="/p/"]');
        out.push({ title, author, content, link: linkEl?.href || '' });
      }
      return out;
    });

    for (const p of posts) {
      const k = postKey(p);
      if (k && !allPosts.some(pp => postKey(pp) === k)) allPosts.push(p);
    }
    process.stdout.write(`\r  scroll ${i + 1}/30 — total ${allPosts.length}`);

    if (allPosts.length === lastCount && ++stable >= 4) break;
    if (allPosts.length !== lastCount) stable = 0;
    lastCount = allPosts.length;

    await page.evaluate(() => globalThis.scrollBy(0, 1500));
    await page.waitForTimeout(1500);
  }

  console.log(`\n  raw: ${allPosts.length}`);
  console.log(`  sample[0]: title="${allPosts[0]?.title?.slice(0,60)}" contentLen=${allPosts[0]?.content?.length}`);
  console.log(`  sample[5]: title="${allPosts[5]?.title?.slice(0,60)}" contentLen=${allPosts[5]?.content?.length}`);
  const valuable = allPosts.filter(p => isValuable(p.title, p.content));
  console.log(`  valuable: ${valuable.length}\n`);

  let md = `# Community Launch — Sanitized Feed\n\n`;
  md += `Source: ${BASE}\n`;
  md += `Scraped: ${new Date().toISOString()}\n\n`;
  md += `Filtered out promotional content and posts under 120 chars.\n\n`;
  md += `---\n\n`;

  for (const p of valuable) {
    md += `## ${sanitize(p.title) || '(No title)'}\n\n`;
    if (p.author) md += `**Author:** ${sanitize(p.author)}\n\n`;
    if (p.link) md += `**Link:** ${p.link}\n\n`;
    md += `${sanitize(p.content)}\n\n---\n\n`;
  }

  fs.writeFileSync(OUTPUT, md);
  console.log(`💾 Saved: ${OUTPUT}`);

  await browser.close();
})();
