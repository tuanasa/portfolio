# Portfolio site

Static HTML/CSS/JS portfolio, deployed to GitHub Pages via `npm run build` (`gh-pages -d . -b deploy`). Local dev: `npm run dev` (live-server on port 3000).

## Git workflow

- After each bigger change (a completed feature/page, a batch of edits, a meaningful fix — not every tiny tweak), commit and push to `main` automatically without waiting to be asked.
- Stage new files too, as long as they aren't too big — skip anything over ~20MB (raw video exports, uncompressed masters, etc.) and flag it to the user instead of committing it. Compressed/exported media for the site (see video export notes below) is fine to add.
- GitHub hard-rejects any single file over 100MB, so oversized files must be compressed or excluded, never force-pushed through.
- Never run `npm run build` (the `gh-pages` deploy) on your own. Committing/pushing to `main` is automatic per above, but deploying to the live site only happens when the user explicitly asks for it.

## Media assets

After adding photos or videos, run `npm run compress` (`scripts/compress-media.sh`; `-- --dry-run` to preview). It:

- moves each original to `../portfolio-originals/<same path>` — outside the repo, so it's untracked and never uploaded by the `gh-pages` deploy (which publishes untracked files in the project folder too)
- writes a web-sized copy in its place: photos → JPEG q82, max 2400px long side; videos → the ffmpeg settings below (never upscaled)
- updates `src` references in `*.html` when the extension changes (e.g. `.png` → `.jpg`)
- skips anything already small (JPGs ≤ 2MB, h264 MP4s ≤ 4 Mbps) or already archived, so it's safe to rerun

Video settings (muted, looping clips — no audio track):

```bash
ffmpeg -i input.mov -vf "scale=1280:-2" -c:v libx264 -crf 28 -preset slow -an -movflags +faststart -pix_fmt yuv420p output.mp4
```

Keep only compressed output in the repo; originals live in `../portfolio-originals/` (or Downloads, external drive).
