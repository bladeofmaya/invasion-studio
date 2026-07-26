# Elden Ring Invasion Studio

Invasion Studio finds invasions and arena encounters in Elden Ring recordings,
extracts them as individual clips, and provides a local WebUI for reviewing,
organizing, trimming, and exporting them.

[Watch the demo](https://www.youtube.com/watch?v=-G9ARNrhMOI)

![Invasion Studio](images/invasion-studio.png)

## Install

Invasion Studio requires Ruby 3.3 or newer, ffmpeg, and Tesseract OCR.

```bash
# macOS
brew install ffmpeg tesseract

# Ubuntu/Debian
sudo apt-get install ffmpeg tesseract-ocr

# Arch Linux
sudo pacman -S ffmpeg tesseract tesseract-data-eng
```

Install the gem:

```bash
gem install invasion-studio
```

## Quick usage

The normal workflow has two steps.

### 1. Generate clips into a new folder

Choose a new output folder and pass one or more gameplay recordings:

```bash
invasion-studio extract \
  --outdir ~/Videos/ER/my-invasion-project \
  ~/Videos/Capture/*.mp4
```

The output folder is created automatically. Each detected encounter becomes an
MP4 clip inside it.

If OBS split one recording into several files, pass them together in
chronological order. Invasions spanning two files are joined automatically.

### 2. Start the WebUI with that folder

```bash
invasion-studio webui ~/Videos/ER/my-invasion-project
```

Open [http://localhost:4567](http://localhost:4567). The WebUI stores its
project metadata alongside the clips in the selected folder.

From the WebUI you can:

- preview clips and switch audio tracks;
- add titles, notes, ratings, and results;
- organize clips into groups;
- mark unwanted sections for removal;
- export a group as a combined video and Kdenlive project.

To use another port:

```bash
invasion-studio webui --port 8080 ~/Videos/ER/my-invasion-project
```

## How detection works

The extractor samples the game-text area and uses OCR to find these messages:

- Start: `Defeat … Host of Fingers` or `Commencing combat`
- End: `Returning to your world` or `Combat ends`

Clips include 10 seconds before the detected start and 7.5 seconds after the
detected end by default.

![How Invasion Studio detects and extracts encounters](images/invasion-extractor.jpg)

## Other commands

```bash
# Show detected timestamps without creating clips
invasion-studio scan ~/Videos/Capture/*.mp4

# Join every clip in a folder and add chapter markers
invasion-studio concat ~/Videos/ER/my-invasion-project

# Build a combined video and Kdenlive project directly
invasion-studio export-kdenlive ~/Videos/ER/my-invasion-project

# Show global or command-specific help
invasion-studio --help
invasion-studio extract --help
```

Commands:

| Command | Purpose |
|---|---|
| `extract` | Detect encounters and create clips; this is the default command |
| `scan` | Detect encounters without creating clips |
| `webui` | Start the local project WebUI |
| `concat` | Join clips into one chaptered video |
| `export-kdenlive` | Create a combined video and Kdenlive timeline |

## Useful extraction options

| Option | Default | Purpose |
|---|---:|---|
| `--outdir DIR` | `./invasion_clips` | Folder for generated clips |
| `--prefix NAME` | `invasion` | Generated filename prefix |
| `--fps RATE` | `1` | OCR samples per second |
| `--pad-start SEC` | `10` | Extra time before an encounter |
| `--pad-end SEC` | `7.5` | Extra time after an encounter |
| `--no-cache` | off | Reprocess footage without reading or writing OCR cache |
| `--continue-on-error` | off | Continue when one input cannot be processed |
| `--debug` | off | Print matches and write frame OCR to YAML |
| `--ocr-workers N` | up to `4` | Parallel Tesseract workers |
| `--ocr-batch-size N` | `1` | Images handled by one Tesseract process |
| `--hwaccel` | off | Use VAAPI frame extraction when available |

Increasing `--fps` can help with very short messages but increases OCR work
linearly. `--ocr-batch-size 8` reduced CPU use by about 29% on the project test
videos, but improved elapsed time by only 1–2%; it remains an optional tuning
setting rather than the default.

## Cache and troubleshooting

OCR results are cached under:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/invasion-studio
```

Use `--no-cache` when checking changed OCR settings or investigating a missed
encounter.

Detection can be missed when menus or platform overlays cover the game text.
Use `--debug` to inspect the recognized text and matched timestamps.

The extractor is optimized for English footage at 720p, 1080p, or 1440p on
macOS and Linux. A modern browser is required for the WebUI.

## Development

Ruby 3.4.9 and Node.js 24 LTS are pinned in `mise.toml`. Node is needed only to
build the packaged WebUI assets.

```bash
# Install dependencies and build WebUI assets
bundle install
bin/build-assets

# Run unit and component tests
bundle exec rake test

# Run the complete suite, including sample-video processing
bin/test

# Build and verify the gem
bin/build-gem
```

Generated WebUI assets under `lib/invasion_studio/webui/public/assets/` are
ignored and should not be committed.

## Support

If this tool saves you time, consider supporting development:

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/bladeofmaya)

## License

MIT License — see [MIT-LICENSE](MIT-LICENSE).
