# Portfolio site

Static HTML/CSS/JS portfolio, deployed to GitHub Pages via `npm run build` (`gh-pages -d . -b deploy`). Local dev: `npm run dev` (live-server on port 3000).

## Git workflow

- After each bigger change (a completed feature/page, a batch of edits, a meaningful fix — not every tiny tweak), commit and push to `main` automatically without waiting to be asked.
- Stage new files too, as long as they aren't too big — skip anything over ~20MB (raw video exports, uncompressed masters, etc.) and flag it to the user instead of committing it. Compressed/exported media for the site (see video export notes below) is fine to add.
- GitHub hard-rejects any single file over 100MB, so oversized files must be compressed or excluded, never force-pushed through.
- Never run `npm run build` (the `gh-pages` deploy) on your own. Committing/pushing to `main` is automatic per above, but deploying to the live site only happens when the user explicitly asks for it.

## Video assets

Background/lookbook `<video>` clips are muted and looping — export them compressed, not camera-native:

```bash
ffmpeg -i input.mov -vf "scale=1280:-2" -c:v libx264 -crf 28 -preset slow -an -movflags +faststart -pix_fmt yuv420p output.mp4
```

Keep only the compressed output in `videos/`; raw/original exports stay outside the repo (Downloads, external drive).
