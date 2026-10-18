# Portfolio site

Static HTML/CSS/JS portfolio, deployed to GitHub Pages (tuanasandikci.com) via `npm run build` (`gh-pages` to the `deploy` branch). The deploy only publishes site files (`*.html`, `CNAME`, `robots.txt`, root images, `photoarchive/`, `videos/`, `favicon/`) plus `.nojekyll` (needed: Jekyll would drop files starting with `_`) — add new top-level folders to the `-s` pattern in package.json. The GitHub key is `~/.ssh/github`. Plain `npm run build` works while it's loaded in ssh-agent; gh-pages clones the repo itself and ignores the repo's `core.sshCommand`, so if the deploy fails with "Permission denied (publickey)" (e.g. after a reboot), run `GIT_SSH_COMMAND="ssh -i ~/.ssh/github -o IdentitiesOnly=yes" npm run build`. `robots.txt` keeps search engines away from all photo/video files (pages stay indexable). Local dev: `npm run dev` (live-server on port 3000).

Analytics: every page loads GoatCounter (`sandikci.goatcounter.com`) with one `<script data-goatcounter=…>` line right after its `<title>`. Copy it into any new page, along with the five favicon `<link>` lines below it (`favicon/` is skipped by the compress script). GoatCounter skips localhost, so local dev doesn't get counted.

## Git workflow

- After each bigger change (a completed feature/page, a batch of edits, a meaningful fix — not every tiny tweak), commit and push to `main` automatically without waiting to be asked.
- Stage new files too, as long as they aren't too big — skip anything over ~20MB (raw video exports, uncompressed masters, etc.) and flag it to the user instead of committing it. Compressed/exported media for the site (see video export notes below) is fine to add.
- GitHub hard-rejects any single file over 100MB, so oversized files must be compressed or excluded, never force-pushed through.
- Never run `npm run build` (the `gh-pages` deploy) on your own. Committing/pushing to `main` is automatic per above, but deploying to the live site only happens when the user explicitly asks for it.

## Media assets

After adding photos or videos, run `npm run compress` (`scripts/compress-media.sh`; `-- --dry-run` to preview). It also runs automatically before every deploy (`prebuild` hook on `npm run build`), and a failure stops the deploy. It:

- moves each original to `../portfolio-originals/<same path>` — outside the repo, so it's untracked and never uploaded by the `gh-pages` deploy (which publishes untracked files in the project folder too)
- writes a web-sized copy in its place: photos → JPEG q82, max 2400px long side; images with actually transparent pixels stay PNG (resized, plus `pngquant` if installed) so the background stays transparent; videos → the ffmpeg settings below (never upscaled)
- updates `src` references in `*.html` when the extension changes (e.g. `.png` → `.jpg`)
- skips anything already small (JPGs ≤ 2MB, h264 MP4s ≤ 4 Mbps) or already archived, so it's safe to rerun
- never touches files in its `KEEP` list (top of the script); `IMG_MAX_FOR` gives small-display images a lower max size — `tuana.png` (portrait, kept compressed in the repo but removed from the about page on purpose and excluded from the deploy via `!(tuana).png` in the package.json pattern — do not re-add it) is capped at 1200px and stays a transparent PNG
- `pngquant` (`brew install pngquant`) is optional but shrinks transparent PNGs a lot more — without it `tuana.png` would be ~1.1MB instead of ~330KB
- when running it from a git worktree, set `ORIGINALS_DIR=/Users/lasse/projects/portfolio-originals` — the default `../portfolio-originals` is relative to the checkout and would land inside `.claude/worktrees/`

Video settings (muted, looping clips — no audio track):

```bash
ffmpeg -i input.mov -vf "scale=1280:-2" -c:v libx264 -crf 28 -preset slow -an -movflags +faststart -pix_fmt yuv420p output.mp4
```

Keep only compressed output in the repo; originals live in `../portfolio-originals/` (or Downloads, external drive).
