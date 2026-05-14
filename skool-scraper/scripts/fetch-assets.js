#!/usr/bin/env node
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

// pipx installs land in ~/.local/bin which is often missing from headless PATHs
const localBin = path.join(os.homedir(), '.local', 'bin');
if (!process.env.PATH.split(':').includes(localBin)) {
  process.env.PATH = `${localBin}:${process.env.PATH}`;
}

// ---------- args ----------------------------------------------------------

const args = process.argv.slice(2);
const opts = {
  root: null,
  keepVideo: false,
  whisperModel: 'base',
  onlyCourse: null,
  skipWhisper: false,
  skipVideoDownload: false,
};
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--root') opts.root = args[++i];
  else if (a === '--keep-video') opts.keepVideo = true;
  else if (a === '--whisper-model') opts.whisperModel = args[++i];
  else if (a === '--only-course') opts.onlyCourse = args[++i];
  else if (a === '--skip-whisper') opts.skipWhisper = true;
  else if (a === '--skip-video-download') opts.skipVideoDownload = true;
  else if (a === '--help' || a === '-h') {
    console.log(`fetch-assets.js — download Skool transcripts/videos/images

Usage:
  node fetch-assets.js --root <SKOOL_OUT_DIR> [options]

Options:
  --root DIR              required: directory containing courses/*/manifest.json
  --keep-video            keep downloaded video file after Whisper transcription
  --whisper-model NAME    tiny|base|small|medium|large (default: base)
  --only-course PREFIX    process only one course slug (e.g. "01" or "01-start-here")
  --skip-whisper          don't run Whisper fallback; URL-only when no native transcript
  --skip-video-download   never download video (transcripts + thumbnails + images only)
`);
    process.exit(0);
  }
}

if (!opts.root) {
  console.error('Missing --root. Run with --help for usage.');
  process.exit(1);
}
opts.root = path.resolve(opts.root);

// ---------- helpers -------------------------------------------------------

function which(cmd) {
  const r = spawnSync('which', [cmd], { encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : null;
}

function run(cmd, cmdArgs, { silent = true, timeout = 600000 } = {}) {
  const r = spawnSync(cmd, cmdArgs, {
    encoding: 'utf8',
    timeout,
    stdio: silent ? ['ignore', 'pipe', 'pipe'] : 'inherit',
  });
  return { ok: r.status === 0, status: r.status, stdout: r.stdout || '', stderr: r.stderr || '' };
}

function exists(p) { try { fs.accessSync(p); return true; } catch { return false; } }

function ensureDir(p) { fs.mkdirSync(p, { recursive: true }); }

function vttToText(vtt) {
  const lines = vtt.split(/\r?\n/).map(l => l.trim());
  const out = [];
  let prev = '';
  for (const l of lines) {
    if (!l) continue;
    if (l === 'WEBVTT' || l.startsWith('WEBVTT ')) continue;
    if (l.startsWith('NOTE')) continue;
    if (/^\d+$/.test(l)) continue;            // cue index
    if (l.includes('-->')) continue;          // timestamp line
    const clean = l.replaceAll(/<[^>]+>/g, '').replaceAll(/&amp;/g, '&').trim();
    if (!clean) continue;
    if (clean === prev) continue;             // dedupe consecutive identical lines (common in YT captions)
    out.push(clean);
    prev = clean;
  }
  return out.join('\n');
}

function safeFileFromUrl(url) {
  try {
    const u = new URL(url);
    const base = path.basename(u.pathname) || 'file';
    return base.replaceAll(/[^A-Za-z0-9._-]/g, '_').slice(0, 80);
  } catch { return 'file'; }
}

// ---------- per-asset handlers --------------------------------------------

function fetchThumbnail(url, lessonDir) {
  if (!url) return null;
  const ext = (/\.([a-z0-9]{2,4})(?:\?|$)/i.exec(url) || [, 'jpg'])[1];
  const out = path.join(lessonDir, `thumbnail.${ext}`);
  if (exists(out)) return path.basename(out);
  const r = run('curl', ['-fsSL', '--max-time', '30', '-o', out, url]);
  return r.ok ? path.basename(out) : null;
}

function fetchNativeTranscript(videoUrl, source, lessonDir) {
  // Loom, YouTube, Vimeo
  if (!['loom', 'youtube', 'vimeo'].includes(source)) return null;

  const outBase = path.join(lessonDir, 'video');
  const ytArgs = [
    '--skip-download',
    '--write-sub',
    '--write-auto-sub',
    '--sub-lang', 'en,en-US,en-GB,en.*',
    '--convert-subs', 'vtt',
    '--no-warnings',
    '--no-progress',
    '-o', outBase,
    videoUrl,
  ];
  const r = run('yt-dlp', ytArgs, { timeout: 60000 });

  // yt-dlp writes <outBase>.<lang>.vtt
  const candidates = fs.readdirSync(lessonDir).filter(f =>
    f.startsWith('video.') && f.endsWith('.vtt')
  );
  if (!candidates.length) return null;

  const vttFile = path.join(lessonDir, candidates[0]);
  const finalVtt = path.join(lessonDir, 'transcript.vtt');
  const finalTxt = path.join(lessonDir, 'transcript.txt');
  fs.renameSync(vttFile, finalVtt);
  // remove other lang variants
  candidates.slice(1).forEach(f => { try { fs.unlinkSync(path.join(lessonDir, f)); } catch {} });

  const vtt = fs.readFileSync(finalVtt, 'utf8');
  fs.writeFileSync(finalTxt, vttToText(vtt));
  return { source: 'native', path: 'transcript.txt', vtt: 'transcript.vtt', tool: 'yt-dlp', exit: r.status };
}

function downloadVideo(videoUrl, source, lessonDir, video = {}) {
  const outBase = path.join(lessonDir, 'video');
  if (source === 'mux') {
    const out = `${outBase}.mp4`;
    if (exists(out)) return { ok: true, path: out };
    // Skool Mux URLs are signed: stream.mux.com/<id>.m3u8?token=<JWT>.
    // Without ?token=, Mux returns 403. Token expires ~1h after scrape.
    if (!video.muxToken) {
      return { ok: false, reason: 'mux_token_missing' };
    }
    if (video.muxTokenExpire && Date.now() / 1000 > video.muxTokenExpire) {
      return { ok: false, reason: 'mux_token_expired' };
    }
    const signedUrl = `${videoUrl}?token=${video.muxToken}`;
    const r = run('ffmpeg', [
      '-y', '-loglevel', 'error',
      '-headers', 'Referer: https://www.skool.com\r\n',
      '-i', signedUrl,
      '-c', 'copy',
      out,
    ], { timeout: 1200000 });
    return r.ok && exists(out) ? { ok: true, path: out } : { ok: false, reason: 'mux_fetch_failed' };
  }

  const r = run('yt-dlp', [
    '-f', 'best[ext=mp4]/best',
    '--no-warnings',
    '--no-progress',
    '-o', `${outBase}.%(ext)s`,
    videoUrl,
  ], { timeout: 1800000 });
  if (!r.ok) return { ok: false, reason: 'yt_dlp_failed' };

  const found = fs.readdirSync(lessonDir).find(f => /^video\.(mp4|mkv|webm|m4a)$/.test(f));
  return found ? { ok: true, path: path.join(lessonDir, found) } : { ok: false, reason: 'no_output' };
}

function whisperTranscribe(videoPath, lessonDir, model) {
  const r = run('whisper', [
    videoPath,
    '--model', model,
    '--output_format', 'all',
    '--output_dir', lessonDir,
    '--language', 'en',
  ], { timeout: 3600000, silent: false });
  if (!r.ok) return null;

  // whisper writes <video>.txt, <video>.vtt, <video>.srt, etc.
  const base = path.parse(videoPath).name;
  const wTxt = path.join(lessonDir, `${base}.txt`);
  const wVtt = path.join(lessonDir, `${base}.vtt`);
  const finalTxt = path.join(lessonDir, 'transcript.txt');
  const finalVtt = path.join(lessonDir, 'transcript.vtt');
  if (exists(wTxt)) fs.renameSync(wTxt, finalTxt);
  if (exists(wVtt)) fs.renameSync(wVtt, finalVtt);
  // tidy auxiliary outputs
  ['srt', 'tsv', 'json'].forEach(ext => {
    const p = path.join(lessonDir, `${base}.${ext}`);
    if (exists(p)) try { fs.unlinkSync(p); } catch {}
  });
  return { source: 'whisper', path: 'transcript.txt', vtt: 'transcript.vtt', model };
}

function fetchImage(url, lessonDir, idx) {
  const imagesDir = path.join(lessonDir, 'images');
  ensureDir(imagesDir);
  const fname = `${String(idx).padStart(2, '0')}-${safeFileFromUrl(url)}`;
  const out = path.join(imagesDir, fname);
  if (exists(out)) return path.relative(lessonDir, out);
  const r = run('curl', ['-fsSL', '--max-time', '30', '-o', out, url]);
  return r.ok ? path.relative(lessonDir, out) : null;
}

function fetchAttachment(att, lessonDir) {
  const attachDir = path.join(lessonDir, 'attachments');
  ensureDir(attachDir);
  const url = att.url;

  // Google Drive file
  const driveFile = /drive\.google\.com\/(?:file\/d\/|open\?id=|uc\?id=)([A-Za-z0-9_-]{20,})/.exec(url);
  if (driveFile) {
    const fname = `${safeFileFromUrl(att.label || 'drive-file')}`;
    const out = path.join(attachDir, fname);
    if (exists(out)) return path.relative(lessonDir, out);
    const r = run('gdown', [`https://drive.google.com/uc?id=${driveFile[1]}`, '-O', out, '--quiet'],
      { timeout: 600000 });
    return r.ok ? path.relative(lessonDir, out) : null;
  }

  // Google Docs / Sheets / Slides / Folders → save link only
  if (/(docs|drive)\.google\.com\/(document|spreadsheets|presentation|drive\/folders)/.test(url)) {
    return null;
  }

  // Generic file
  const fname = safeFileFromUrl(url);
  const out = path.join(attachDir, fname);
  if (exists(out)) return path.relative(lessonDir, out);
  const r = run('curl', ['-fsSL', '--max-time', '120', '-o', out, url]);
  return r.ok ? path.relative(lessonDir, out) : null;
}

// ---------- per-lesson processor ------------------------------------------

function processLesson(lesson, courseDir) {
  const lessonDir = path.join(courseDir, 'lessons', lesson.slug);
  ensureDir(lessonDir);

  const fetched = lesson.fetched || {};

  // 1. Thumbnail (small, always)
  if (lesson.video?.thumbnail && !fetched.thumbnail) {
    const t = fetchThumbnail(lesson.video.thumbnail, lessonDir);
    if (t) fetched.thumbnail = t;
  }

  // 2. Transcript (native first, then whisper fallback).
  // Retry if previous attempt failed due to skipped video download — Mux
  // signed URLs etc. are not retryable.
  const transcriptDone = fetched.transcript &&
    (fetched.transcript.source === 'native' || fetched.transcript.source === 'whisper');
  const retryReasons = new Set([
    'video_download_skipped',
    'no_native_transcript',
    'mux_token_expired',
    'mux_token_missing',
  ]);
  const shouldRetry = fetched.transcript &&
    fetched.transcript.source === 'none' &&
    retryReasons.has(fetched.transcript.reason) &&
    !opts.skipVideoDownload;
  if (lesson.video?.url && (!fetched.transcript || (!transcriptDone && shouldRetry))) {
    if (shouldRetry) { delete fetched.transcript; delete fetched.video; }
    const native = fetchNativeTranscript(lesson.video.url, lesson.video.source, lessonDir);
    if (native) {
      fetched.transcript = native;
      fetched.video = { downloaded: false, reason: 'transcript_available' };
    } else if (!opts.skipVideoDownload && !opts.skipWhisper && which('whisper')) {
      const dl = downloadVideo(lesson.video.url, lesson.video.source, lessonDir, lesson.video);
      if (dl.ok) {
        const ws = whisperTranscribe(dl.path, lessonDir, opts.whisperModel);
        if (ws) {
          fetched.transcript = ws;
          if (opts.keepVideo) {
            fetched.video = { downloaded: true, path: path.basename(dl.path) };
          } else {
            try { fs.unlinkSync(dl.path); } catch {}
            fetched.video = { downloaded: false, reason: 'deleted_after_whisper' };
          }
        } else {
          fetched.video = { downloaded: true, path: path.basename(dl.path), transcribed: false };
          fetched.transcript = { source: 'none', reason: 'whisper_failed' };
        }
      } else {
        fetched.transcript = { source: 'none', reason: dl.reason };
        fetched.video = { downloaded: false, reason: dl.reason };
      }
    } else {
      fetched.transcript = { source: 'none', reason: 'no_native_transcript' };
      fetched.video = { downloaded: false, reason: 'video_download_skipped' };
    }
  }

  // 3. Images
  if (lesson.images?.length && !fetched.images) {
    fetched.images = [];
    lesson.images.forEach((img, i) => {
      const rel = fetchImage(img.url, lessonDir, i + 1);
      if (rel) fetched.images.push(rel);
    });
  }

  // 4. Attachments (PDFs, drive files)
  if (lesson.attachments?.length && !fetched.attachments) {
    fetched.attachments = [];
    lesson.attachments.forEach(att => {
      const rel = fetchAttachment(att, lessonDir);
      if (rel) fetched.attachments.push({ label: att.label, path: rel });
      else fetched.attachments.push({ label: att.label, url: att.url, downloaded: false });
    });
  }

  // 5. External links → text file
  if (lesson.externalLinks?.length) {
    const linksOut = path.join(lessonDir, 'external-links.txt');
    if (!exists(linksOut)) {
      const lines = lesson.externalLinks.map(l => `${l.text || '(no label)'}\n  ${l.url}\n`).join('\n');
      fs.writeFileSync(linksOut, lines);
      fetched.externalLinks = 'external-links.txt';
    }
  }

  lesson.fetched = fetched;
  return fetched;
}

// ---------- main ----------------------------------------------------------

function main() {
  // Tooling preflight
  const tools = ['yt-dlp', 'ffmpeg', 'curl'];
  const missing = tools.filter(t => !which(t));
  if (missing.length) {
    console.error(`Missing required tools: ${missing.join(', ')}`);
    console.error('Install: brew install yt-dlp ffmpeg');
    process.exit(1);
  }
  if (!opts.skipWhisper && !which('whisper')) {
    console.warn('⚠️  whisper not found — only native transcripts will be saved.');
    console.warn('   pipx install openai-whisper  (or use --skip-whisper to silence this)');
  }
  if (!which('gdown')) {
    console.warn('⚠️  gdown not found — Google Drive files will not be downloaded.');
    console.warn('   pipx install gdown');
  }

  const coursesDir = path.join(opts.root, 'courses');
  if (!exists(coursesDir)) {
    console.error(`No courses/ directory at ${coursesDir}. Run classroom-scraper.js first.`);
    process.exit(1);
  }

  const courseSlugs = fs.readdirSync(coursesDir)
    .filter(s => fs.statSync(path.join(coursesDir, s)).isDirectory())
    .filter(s => !opts.onlyCourse || s.startsWith(opts.onlyCourse))
    .sort();

  console.log(`📦 Processing ${courseSlugs.length} courses from ${opts.root}\n`);

  const summary = { courses: 0, lessons: 0, native: 0, whisper: 0, none: 0, images: 0, attachments: 0 };

  for (const slug of courseSlugs) {
    const courseDir = path.join(coursesDir, slug);
    const manifestPath = path.join(courseDir, 'manifest.json');
    if (!exists(manifestPath)) { console.log(`[${slug}] skip — no manifest.json`); continue; }

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    console.log(`[${slug}] ${manifest.course.title} — ${manifest.lessons.length} lessons`);

    for (const lesson of manifest.lessons) {
      process.stdout.write(`  · ${lesson.slug.padEnd(60).slice(0, 60)} `);
      try {
        const f = processLesson(lesson, courseDir);
        const t = f.transcript?.source || 'skipped';
        const im = (f.images || []).length;
        const at = (f.attachments || []).filter(a => a.path).length;
        process.stdout.write(`transcript=${t.padEnd(7)} images=${im} attachments=${at}\n`);
        summary.lessons += 1;
        if (t === 'native') summary.native += 1;
        else if (t === 'whisper') summary.whisper += 1;
        else summary.none += 1;
        summary.images += im;
        summary.attachments += at;
      } catch (e) {
        process.stdout.write(`❌ ${e.message}\n`);
      }
      // persist after every lesson — safe to ctrl-c and resume
      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    }
    summary.courses += 1;
  }

  console.log(`\n✅ Done.`);
  console.log(`   ${summary.courses} courses, ${summary.lessons} lessons`);
  console.log(`   transcripts: ${summary.native} native, ${summary.whisper} whisper, ${summary.none} none`);
  console.log(`   ${summary.images} images, ${summary.attachments} attachments downloaded`);
}

main();
