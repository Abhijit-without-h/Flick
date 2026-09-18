# Hyperframes Composition Brief: Flick

## Objective
Create a short launch-style brag video for Flick.

## Output
- Composition directory: `brag-output-2026-09-18-115517/composition/`
- Rendered video: `brag-output-2026-09-18-115517/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 20 seconds

## Source Material
- Project root: `/Users/abhijitsr/flick`
- Primary files: `web/src/App.jsx`, `web/src/index.css`, `README.md`
- Product name: Flick
- Tagline / strongest claim: Option+Space. A native launcher for Mac. No Spotlight index.
- Key UI: dark HUD typing `saf` → Safari; website hero type
- Copy that must appear verbatim:
  - Spotlight is slow.
  - Option+Space.
  - Flick
  - Take a copy.

## Creative Direction
- Tone preset: polished
- Creative direction: letterpress product film
- Interpretation: paper/ink, long holds, one idea per scene
- Angle: print develops, then the HUD works
- Hook: Spotlight is slow.
- Outro / punchline: Flick. Take a copy.
- Avoid: generic SaaS language; abstract filler; Inter

## Visual Identity
- Background: #f4efe4
- Text: #141414
- Accent: #141414
- Display font: Palatino, Georgia, serif
- Body font: ui-monospace, SF Mono, Menlo
- Visual references: maze F (`assets/logo.png`), HUD chrome

## Storyboard
Use `brag-plan.md`. Scene summary:
1. Slow — 3.2s — Spotlight is slow.
2. Summon — 4.0s — F + Option+Space.
3. Type — 6.0s — HUD types saf, Safari
4. Press — 4.0s — three keys
5. Copy — 2.8s — Flick / Take a copy.

## Audio
- Audio role: sparse professional accents
- Audio arc: quiet bed, HUD ticks, name stamp, fade
- Music: happy-beats-business-moves-vol-12-by-ende-dot-app.mp3
- Music treatment: volume 0.18, fade last 1.2s
- Music cue guidance: bundled vol-12 cues; 3.27 / 8.74 / 17.47
- Audio-reactive treatment: subtle grain/glow RMS
- Audio-coupled moments:
  - Scene 3 — typing
  - Scene 4 — sequential rows
  - Scene 5 — logo
- SFX: drop_001, click_003, keypress, bong_001, impactSoft_medium_001
- Exact SFX choice: Hyperframes chooses after visuals exist
- Audio files: composition/assets/

## Hyperframes Instructions
Standalone index.html, GSAP paused timeline `main`, clips as direct children, paper fill on a child not the root, local assets only, check before render.
