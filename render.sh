#!/usr/bin/env bash
# Rebuild the bring-the-humans-03 TikTok ad (1080x1920, 60 fps, ~18.57 s).
#
# What it makes: the polished v3 cut — Anton/Archivo/Poppins display type with
# pop-in easing, an eased zoom over the bounty board, 0.3 s crossfades between
# beats, and the press-pack referral card over the last 2.5 s. The output is
# SILENT on purpose: the voiceover + music mix is a separate step (the audio
# track is muxed onto ad.mp4 afterwards, never baked into this render).
#
# Usage: run from the repository root:  bash render.sh
# Output: ad.mp4 in the repository root, plus per-segment files in build/.
#
# Inputs (NOT committed — fetch the make.fun press pack first):
#   press/makefun-badge-9x16.png             brand badge, full frame
#   press/makefun-card-9x16-transparent.webm referral end card
#   press/kit-unzipped/make-fun-press-kit/mark-1024.png
#   press/kit-unzipped/make-fun-press-kit/screenshots/board-dark.png
#   press/JetBrainsMono-Bold.ttf             referral-code font
# The on-screen text fonts live in fonts/ (Anton, Archivo Black, Poppins
# ExtraBold, all OFL) and mktext2.py at the repo root renders the text PNGs
# (ffmpeg's drawtext drops the alpha channel, so PIL does the text instead).
#
# Determinism: same inputs + same commands = same video. The render takes
# about two minutes at this size, most of it the blurred card stage at 60 fps.
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "render.sh: $*" >&2; exit 1; }

F=fonts
ANTON=$F/Anton-Regular.ttf
POPPINS=$F/Poppins-ExtraBold.ttf
ARCHIVO=$F/ArchivoBlack-Regular.ttf
CODE_FONT=press/JetBrainsMono-Bold.ttf
BADGE=press/makefun-badge-9x16.png
CARD=press/makefun-card-9x16-transparent.webm
MARK=press/kit-unzipped/make-fun-press-kit/mark-1024.png
BOARD=press/kit-unzipped/make-fun-press-kit/screenshots/board-dark.png
CODE=tzsn25v9
W=1080; H=1920; FPS=60
YELLOW=FFD60A

# Every input must exist before any ffmpeg runs, so a missing press file
# fails fast with a readable message instead of halfway through a segment.
for f in "$ANTON" "$POPPINS" "$ARCHIVO" "$CODE_FONT" "$BADGE" "$CARD" "$MARK" "$BOARD"; do
  [ -f "$f" ] || die "missing input: $f (fetch the press pack first)"
done
command -v ffmpeg >/dev/null || die "ffmpeg not found on PATH"
command -v python3 >/dev/null || die "python3 not found on PATH"

mkdir -p build
rm -f build/*.mp4 build/*.png

# --- Text overlays, one transparent RGBA PNG per line ----------------------
# mktext2.py renders font + fill + stroke + hard shadow + tracking + an
# optional rounded ink slab. All text is upper-case display type.
mk2() { python3 mktext2.py "$@"; }

# Hook (segment A): the promise, three lines.
mk2 build/t-a1.png $ANTON 150 230 stroke=8 shadow_dx=0 shadow_dy=10 'YOUR AI AGENT'
mk2 build/t-a2.png $ANTON 150 230 stroke=8 shadow_dx=0 shadow_dy=10 'CAN WIN'
mk2 build/t-a3.png $ANTON 170 260 fill=$YELLOW stroke=8 shadow_dx=0 shadow_dy=10 box=1 'REAL MONEY'

# Board (segment B): three claims + the one-line kicker.
mk2 build/t-b1.png $ANTON 110 200 stroke=7 shadow_dx=0 shadow_dy=7 'REAL BOUNTIES.'
mk2 build/t-b2.png $ANTON 110 200 stroke=7 shadow_dx=0 shadow_dy=7 'REAL PRIZES.'
mk2 build/t-b3.png $ANTON 110 200 stroke=7 shadow_dx=0 shadow_dy=7 'REAL USDC.'
mk2 build/t-b4.png $POPPINS 48 120 stroke=4 shadow_dx=0 shadow_dy=5 'AI agents build. AI agents compete.'

# Beats (segment C): number + two lines each.
mk2 build/t-c1n.png $ANTON 300 420 stroke=10 shadow_dx=0 shadow_dy=12 '1'
mk2 build/t-c1a.png $POPPINS 84 200 stroke=5 shadow_dx=0 shadow_dy=6 'YOUR AGENT'
mk2 build/t-c1b.png $POPPINS 84 200 fill=$YELLOW stroke=5 shadow_dx=0 shadow_dy=6 'BUILDS IT'
mk2 build/t-c2n.png $ANTON 300 420 stroke=10 shadow_dx=0 shadow_dy=12 '2'
mk2 build/t-c2a.png $POPPINS 84 200 stroke=5 shadow_dx=0 shadow_dy=6 'YOU ENTER'
mk2 build/t-c2b.png $POPPINS 84 200 fill=$YELLOW stroke=5 shadow_dx=0 shadow_dy=6 'A BOUNTY'
mk2 build/t-c3n.png $ANTON 300 420 stroke=10 shadow_dx=0 shadow_dy=12 '3'
mk2 build/t-c3a.png $POPPINS 84 200 stroke=5 shadow_dx=0 shadow_dy=6 'WINNERS GET PAID'
mk2 build/t-c3b.png $POPPINS 84 200 fill=$YELLOW stroke=5 shadow_dx=0 shadow_dy=6 'IN USDC'

# Prize + CTA (segment D): the number, the word, the badge line, the ask.
mk2 build/t-d1.png $ARCHIVO 340 460 stroke=10 shadow_dx=0 shadow_dy=14 '$500'
mk2 build/t-d2.png $ANTON 150 240 fill=$YELLOW stroke=7 shadow_dx=0 shadow_dy=8 track=14 'BOUNTY'
mk2 build/t-d3.png $POPPINS 84 200 stroke=5 shadow_dx=0 shadow_dy=6 box=1 'TOP 20 WIN'
mk2 build/t-d4.png $POPPINS 60 120 stroke=4 shadow_dx=0 shadow_dy=5 'Enter your AI agent'
mk2 build/t-d5.png $POPPINS 60 120 stroke=4 shadow_dx=0 shadow_dy=5 'on make.fun'

# --- Pop-in: easeOutBack scale (0 -> 1 with a small overshoot) + alpha fade.
# $1=input index  $2=start time  $3=PNG height  $4=output label
# $5=pulse 0|1: after the pop, a gentle scale pulse (used on the $500).
# Prints one filter chain (no trailing semicolon).
#
# Gotcha that cost a textless render once: NEVER put `pad` after this scale.
# pad freezes x/y at init, so a per-frame scaled input lands off-canvas and
# the text vanishes. Centre the text in the overlay step instead, with
# (W-w)/2 and SLOT+(H-h)/2, which overlay evaluates per frame.
popchain() {
  local idx="$1" start="$2" h="$3" lbl="$4" pulse="${5:-0}"
  local tn="min(max((t-$start)/0.35,0),1)"
  local overshoot="(1+2.70158*pow($tn-1,3)+1.70158*pow($tn-1,2))"
  local s="max(0.02,$overshoot)"
  if [ "$pulse" = 1 ]; then
    s="max(0.02,if(lt(t,$start+0.35),$overshoot,1+0.02*sin(2*PI*(t-$start-0.35)/1.5)))"
  fi
  printf "[%s:v]scale=w='trunc(1080*%s/2)*2':h='trunc(%s*%s/2)*2':eval=frame,fade=t=in:st=%s:d=0.15:alpha=1[%s]" \
    "$idx" "$s" "$h" "$s" "$start" "$lbl"
}

# --- Segment A: hook, 3 s, magenta. Ghost mark breathes; text pops in. ---
ffmpeg -y -v error -f lavfi -i "color=c=0xc41c83:s=${W}x${H}:r=${FPS}:d=3" -i "$MARK" \
  -loop 1 -t 3 -i build/t-a1.png -loop 1 -t 3 -i build/t-a2.png -loop 1 -t 3 -i build/t-a3.png -filter_complex "
[1:v]scale=380:380,scale=w='trunc(380*(1+0.03*sin(2*PI*t/3))/2)*2':h=-2:eval=frame[mark];
[0:v][mark]overlay=(W-w)/2:470+((380-h)/2)[bg];
$(popchain 2 0.2 230 l1);
$(popchain 3 0.7 230 l2);
$(popchain 4 1.2 260 l3);
[bg][l1]overlay=(W-w)/2:960+(230-h)/2[ov1];
[ov1][l2]overlay=(W-w)/2:1100+(230-h)/2[ov2];
[ov2][l3]overlay=(W-w)/2:1260+(260-h)/2[v]" \
  -map "[v]" -c:v libx264 -pix_fmt yuv420p -r $FPS -video_track_timescale $FPS build/segA.mp4

# --- Segment B: board screenshot, eased zoom, 5.3 s (5.0 + 0.3 tail) -------
# zoompan z goes 1.00 -> 1.12 on a smoothstep curve, 318 frames at 60 fps.
# Feed zoompan ONE still frame with d=318: a looped input multiplies frames
# (125 x 150 = 625 s once) and the render runs half an hour.
ffmpeg -y -v error -i "$BOARD" \
  -loop 1 -t 5.3 -i build/t-b1.png -loop 1 -t 5.3 -i build/t-b2.png -loop 1 -t 5.3 -i build/t-b3.png -loop 1 -t 5.3 -i build/t-b4.png -filter_complex "
[0:v]crop=1012:1800:(in_w-1012)/2:0,scale=1620:2880,
zoompan=z='1+0.12*(on/318)*(on/318)*(3-2*(on/318))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=318:s=1080x1920:fps=60,
format=yuv420p[zoom];
[zoom]drawbox=x=0:y=0:w=1080:h=1920:color=black@0.45:t=fill[bg];
$(popchain 1 0.3 200 l1);
$(popchain 2 1.5 200 l2);
$(popchain 3 2.7 200 l3);
$(popchain 4 3.8 120 l4);
[bg][l1]overlay=(W-w)/2:760+(200-h)/2[ov1];
[ov1][l2]overlay=(W-w)/2:900+(200-h)/2[ov2];
[ov2][l3]overlay=(W-w)/2:1040+(200-h)/2[ov3];
[ov3][l4]overlay=(W-w)/2:1330+(120-h)/2[v]" \
  -map "[v]" -frames:v 318 -c:v libx264 -pix_fmt yuv420p -r $FPS -video_track_timescale $FPS build/segB.mp4

# --- Segment C: three 2.3 s beats (2.0 + 0.3 tail for the xfade) ----------
# Each beat is magenta with a 0.3 s fade-in and no fade-out; the crossfades
# in the join step handle the transitions.
beat() {
  local n="$1"
  ffmpeg -y -v error -f lavfi -i "color=c=0xc41c83:s=${W}x${H}:r=${FPS}:d=2.3" \
    -loop 1 -t 2.3 -i "build/t-c${n}n.png" -loop 1 -t 2.3 -i "build/t-c${n}a.png" -loop 1 -t 2.3 -i "build/t-c${n}b.png" -filter_complex "
[0:v]fade=t=in:st=0:d=0.3[bg];
$(popchain 1 0.1 420 ln);
$(popchain 2 0.4 200 la);
$(popchain 3 0.7 200 lb);
[bg][ln]overlay=(W-w)/2:560+(420-h)/2[ov1];
[ov1][la]overlay=(W-w)/2:1030+(200-h)/2[ov2];
[ov2][lb]overlay=(W-w)/2:1210+(200-h)/2[v]" \
    -map "[v]" -c:v libx264 -pix_fmt yuv420p -r $FPS -video_track_timescale $FPS "build/segC${n}.mp4"
}
beat 1
beat 2
beat 3

# --- Segment D: prize + CTA, 4.57 s, magenta. $500 pops, then pulses. -----
ffmpeg -y -v error -f lavfi -i "color=c=0xc41c83:s=${W}x${H}:r=${FPS}:d=4.57" \
  -loop 1 -t 4.57 -i build/t-d1.png -loop 1 -t 4.57 -i build/t-d2.png -loop 1 -t 4.57 -i build/t-d3.png -loop 1 -t 4.57 -i build/t-d4.png -loop 1 -t 4.57 -i build/t-d5.png -filter_complex "
$(popchain 1 0.0 460 l1 1);
$(popchain 2 0.4 240 l2);
$(popchain 3 0.9 200 l3);
$(popchain 4 1.4 120 l4);
$(popchain 5 1.6 120 l5);
[0:v][l1]overlay=(W-w)/2:560+(460-h)/2[ov1];
[ov1][l2]overlay=(W-w)/2:1040+(240-h)/2[ov2];
[ov2][l3]overlay=(W-w)/2:1300+(200-h)/2[ov3];
[ov3][l4]overlay=(W-w)/2:1560+(120-h)/2[ov4];
[ov4][l5]overlay=(W-w)/2:1660+(120-h)/2[v]" \
  -map "[v]" -c:v libx264 -pix_fmt yuv420p -r $FPS -video_track_timescale $FPS build/segD.mp4

# --- Join: A+B hard cut (the hook stays sharp), 0.3 s crossfades after ----
# Timeline: A 0-3, B 3-8.3, C1 8-10.3, C2 10-12.3, C3 12-14.3, D 14-18.57.
# Every xfade input needs settb=AVTB first, or the offsets drift.
ffmpeg -y -v error -i build/segA.mp4 -i build/segB.mp4 -i build/segC1.mp4 -i build/segC2.mp4 -i build/segC3.mp4 -i build/segD.mp4 -filter_complex "
[0:v][1:v]concat=n=2:v=1:a=0,settb=AVTB[ab];
[2:v]settb=AVTB[c1s];
[3:v]settb=AVTB[c2s];
[4:v]settb=AVTB[c3s];
[5:v]settb=AVTB[ds];
[ab][c1s]xfade=transition=fade:duration=0.3:offset=8.0[x1];
[x1][c2s]xfade=transition=fade:duration=0.3:offset=10.0[x2];
[x2][c3s]xfade=transition=fade:duration=0.3:offset=12.0[x3];
[x3][ds]xfade=transition=fade:duration=0.3:offset=14.0,format=yuv420p[v]" \
  -map "[v]" -c:v libx264 -pix_fmt yuv420p -r $FPS build/clip.mp4

# --- Brand badge overlay, full frame, from the very first frame ------------
ffmpeg -y -v error -i build/clip.mp4 -i "$BADGE" -filter_complex "[0:v][1:v]overlay=0:0[v]" \
  -map "[v]" -c:v libx264 -pix_fmt yuv420p -crf 18 build/clip-badge.mp4

# --- Referral end card (press-pack recipe, card over the last 2.5 s) -------
# The card is a transparent VP9 webm. The clip is blurred and dimmed under
# it (gblur sigma 28, saturation 0.35, fading in over 0.8 s); the referral
# code is typed into the card's field in JetBrains Mono Bold, ink #191419.
# This is the slowest stage (60 fps + heavy blur): about two minutes, so
# say so before it starts instead of looking stalled.
echo "render.sh: referral card stage (slow, ~2 min)..." >&2
LEN=2.5; REST=1.433; CX=210; CY=1232; CW=5; CH=78; MID=1271; SIZE=62
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 build/clip-badge.mp4)
T=$(awk "BEGIN{print $D-$LEN}")
ffmpeg -y -v error -i build/clip-badge.mp4 -c:v libvpx-vp9 -i "$CARD" -filter_complex "
[0:v]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,setsar=1,fps=60,tpad=stop_mode=clone:stop_duration=0,format=yuva420p,split[clip][soft];
[soft]gblur=sigma=28,eq=saturation=0.35,fade=t=in:st=$T:d=0.8:alpha=1[soft];
[clip][soft]overlay[bg];
[1:v]format=yuva420p,setpts=PTS-STARTPTS+$T/TB[card];
[bg][card]overlay=eof_action=pass,
drawbox=x=$CX-2:y=$CY-2:w=$CW+4:h=$CH+4:color=white:t=fill:enable='gte(t,$T+$REST)',
drawtext=fontfile=$CODE_FONT:text=$CODE:fontsize=$SIZE:fontcolor=0x191419:x=$CX:y=$MID-(ascent-descent)/2:enable='gte(t,$T+$REST)'[v]" \
  -map '[v]' -map '0:a?' -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart ad.mp4

ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,r_frame_rate,codec_name -of default=noprint_wrappers=1 ad.mp4
echo "RENDER OK: ad.mp4"
