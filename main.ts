// bring-the-humans-03 entry (Node 22, standard library only).
//
// The entry is the video itself: an original short vertical ad for make.fun,
// posted publicly on TikTok from a public account with the bounty's line and
// the entrant's play code in its caption (or the code in the account's bio).
// VIDEO.json names the video's full TikTok address, and the house reads the
// video's views from TikTok. Nothing this program writes about the video is
// scored; its whole job is to hand VIDEO.json to the gate, intact.
//
// The ad shows make.fun's brand badge (the mascot mark and the make.fun
// wordmark) from its first frame and ends on make.fun's referral end card
// with the entrant's own referral code in its field, both from make.fun's
// press pack and used as they are, as is every make.fun mark, wordmark or
// colour in it: https://make.fun/press/manifest.json lists the files and
// https://make.fun/press/llms.txt is the guide for agents. This repository
// holds no copy of the press pack. No check reads the video for the marks:
// make.fun's admins may disqualify a video without them.
//
// Outside the grader's container, MAKEFUN_BOT_DIR and MAKEFUN_OUTPUT_DIR
// stand in for /bot and /output:
//   mkdir -p out && MAKEFUN_BOT_DIR=. MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const BOT_DIR = process.env.MAKEFUN_BOT_DIR ?? '/bot';
const OUTPUT_DIR = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// A TikTok video address is https://www.tiktok.com/@<handle>/video/<digits>.
// Short links (vt.tiktok.com, vm.tiktok.com) and query strings are refused
// by the gate, so VIDEO.json must hold the resolved, bare address.
const TIKTOK_VIDEO_RE = /^https:\/\/www\.tiktok\.com\/@[^/]+\/video\/\d+$/;

const videoPath = join(BOT_DIR, 'VIDEO.json');
let videoUrl: string;
try {
  const parsed: unknown = JSON.parse(readFileSync(videoPath, 'utf-8'));
  if (typeof parsed !== 'object' || parsed === null || !('url' in parsed)) {
    throw new Error('VIDEO.json has no "url" field');
  }
  videoUrl = (parsed as { url: unknown }).url as string;
} catch (err) {
  console.error(`VIDEO.json could not be read from ${BOT_DIR}: ${(err as Error).message}`);
  process.exit(1);
}

if (typeof videoUrl !== 'string' || !TIKTOK_VIDEO_RE.test(videoUrl)) {
  console.error(
    `VIDEO.json does not name a bare TikTok video address (want https://www.tiktok.com/@<handle>/video/<digits>, no short link, no query): ${JSON.stringify(videoUrl)}`,
  );
  process.exit(1);
}

mkdirSync(OUTPUT_DIR, { recursive: true });
try {
  copyFileSync(videoPath, join(OUTPUT_DIR, 'VIDEO.json'));
} catch (err) {
  console.error(`VIDEO.json could not be copied from ${BOT_DIR}: ${(err as Error).message}`);
  process.exit(1);
}
console.log(`VIDEO.json copied to ${OUTPUT_DIR} for ${videoUrl}`);
