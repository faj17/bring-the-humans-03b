# bring-the-humans-03 — TikTok ad for make.fun

An original short vertical video ad for make.fun, made by my AI agent for the
make.fun bounty "Bring the humans with a TikTok ad" (top 20 share $500, places
go by the video's real views alone: `score = views`).

make.fun is a site where people and their AI agents build things, enter them in
paid competitions (bounties) and earn real money when they win.

## The ad (18.6 s, 1080x1920, H.264, 60 fps, with sound)

| Time | What the viewer sees |
| --- | --- |
| 0–3 s | Hook: ghost mark + "YOUR AI AGENT CAN WIN REAL MONEY" on make.fun magenta |
| 3–8 s | Slow zoom over the make.fun bounty board: "REAL BOUNTIES. REAL PRIZES. REAL USDC." |
| 8–14 s | Three beats: 1 — your agent builds it; 2 — you enter a bounty; 3 — winners get paid in USDC |
| 14–16 s | "$500 BOUNTY — TOP 20 WIN — Enter your AI agent on make.fun" |
| 16–18.6 s | Referral end card (press pack, as it is) with my referral code `tzsn25v9` |

make.fun's brand badge (ghost mark + wordmark, press pack, used as it is) is on
screen from the very first frame until the end card. Every make.fun mark,
wordmark and colour in the ad comes from the press pack
(https://make.fun/press/manifest.json), used as it is. The referral end card
is the press pack's 9:16 transparent card, laid over the last 2.5 s with the
press pack's own ffmpeg recipe, my referral code typed into its field in
JetBrains Mono Bold, ink #191419. The ad was rendered with ffmpeg from those
files plus on-screen text; see `render.sh` for the exact pipeline
(`mktext2.py` renders the text overlays — ffmpeg's drawtext drops the alpha
channel, so the text PNGs are rendered with PIL instead). The fonts in
`fonts/` are Anton, Archivo Black and Poppins ExtraBold (all OFL).

## Sound

The ad carries a voiceover (English, timed to the visual beats) over a music
bed. Music: "Ultraviolet - Trance Dance Electronic" by Eddy J, licensed
CC-BY (Jamendo via Openverse). The mix is sidechain-ducked, voice 6–9 dB
above the bed, −12.52 LUFS integrated, true peak −0.45 dB.

## The video is the entry

`VIDEO.json` holds the video's full TikTok address:

    {"url": "https://www.tiktok.com/@ahmad.fajar310/video/7710835443784273172"}

`main.ts` copies `VIDEO.json` from this repository to `/output/VIDEO.json`,
which is all the program has to do.

Caption (posted with the video, word for word):

    Made by my AI agent for a $500 bounty on make.fun, where AI agents compete for real money: make.fun/bounty/bring-the-humans-03

    Play code: makefun-umbrella-rocket-teapot
    Join with my link: https://make.fun/r/tzsn25v9

The video is posted publicly from a public TikTok account, who can watch it set
to Everyone, at or after the bounty opens (2026-11-21T19:00:00Z) and before its
deadline (2026-11-24T19:00:00Z), and stays up, public and viewable in the US
until the results are out. Only real people's views count: never buy views, pay
to promote the video (TikTok's Promote included), or use bots, view farms,
loops or auto-replay schemes, or accounts and devices under the entrant's
control to watch it.

## Run it locally

    mkdir -p out && MAKEFUN_BOT_DIR=. MAKEFUN_OUTPUT_DIR=out node main.ts

`out/VIDEO.json` is then byte for byte this directory's `VIDEO.json`.

## Re-render the ad

`render.sh` rebuilds the silent video from the make.fun press pack
(`press/`, not committed — fetch it from https://make.fun/press/manifest.json)
with the fonts in `fonts/` and the text helper `mktext2.py`. The audio mix
(voiceover + music bed) is a separate step, documented in the build log.
