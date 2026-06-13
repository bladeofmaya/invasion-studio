# Elden Ring Invasion Extractor

Automatically detect and extract invasion clips from your Elden Ring gameplay footage. This Ruby gem scans your recordings using OCR (Optical Character Recognition) to find invasion start/end points, cuts them into separate video files, and provides a browser-based studio to organize, review, and export them — perfect for content creators who want to streamline their editing workflow.

[📺 Watch the demo](https://www.youtube.com/watch?v=-G9ARNrhMOI)

![](images/invasion-extractor.jpg)

---

## Quick Start

### Prerequisites

Make sure you have **ffmpeg** and **tesseract** installed:

```bash
# macOS
brew install ffmpeg tesseract

# Ubuntu/Debian
sudo apt-get install ffmpeg tesseract-ocr

# Arch Linux
sudo pacman -S ffmpeg tesseract tesseract-data-eng
```

### Installation

```bash
git clone https://github.com/bladeofmaya/invasion_extractor.git
cd invasion_extractor
bundle install
```

### Typical Workflow

```bash
# 1. Extract invasions from your recordings
bin/invasion_extractor --prefix ps-daggers-tt-04 --outdir ~/Videos/ER/clips ~/Videos/Capture/*.mp4

# 2. Open the Invasion Studio to organize, review, and tag clips
bin/invasion_extractor webui ~/Videos/ER/clips

# 3. Export a group to a single video + Kdenlive timeline
# (Done from the studio UI — or via CLI)
bin/invasion_extractor export-kdenlive ~/Videos/ER/clips
```

**Pro tip:** If OBS splits your recordings into segments (e.g., 60-minute chunks), pass all files in order. The tool detects invasions that span across files and combines them automatically.

---

## What It Does

This tool reads on-screen text to detect:
- **Invasion Start**: "Defeat [Name], Host of Fingers" / "Commencing combat"
- **Invasion End**: "Returning to your world" / "Combat ends"

It then automatically cuts your video into individual invasion clips, adding a 10-second buffer before the start and 7.5 seconds after the end so you don't miss any action.

---

## Invasion Studio (WebUI)

After extracting clips, organize, review, and export them with the built-in browser-based studio.

![Invasion Studio](images/invasion-studio.png)

### Features

- **Browse & Organize** — View all clips with titles, notes, star ratings, and win/loss/dc tags
- **Groups** — Create groups to organize invasions by theme, build, or session
- **Video Preview** — Watch clips directly in the browser with audio track switching
- **Cut Editor** — Mark start/end cut points and export only the best moments
- **Export** — Export groups as a single spliced video with a Kdenlive timeline project

### How to Run

```bash
# Start the studio from your clips folder
bin/invasion_extractor webui ~/Videos/ER/clips

# Start on a custom port
bin/invasion_extractor webui -p 8080 ~/Videos/ER/clips
```

Then open `http://localhost:4567` (or your custom port) in your browser.

---

## Full CLI Reference

### Command Structure

```
bin/invasion_extractor [COMMAND] [OPTIONS] [VIDEO_FILES...]
```

### Commands

| Command | Description |
|---------|-------------|
| `extract` | Extract invasion clips (default) |
| `scan` | Scan videos and show timestamps only |
| `webui` | Start the Invasion Studio browser interface |
| `export-kdenlive` | Export clips to a Kdenlive timeline |
| `concat` | Concatenate clips into a single video |

### Complete Flag Reference

#### Extract / Scan Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-h, --help` | — | Show help message and exit |
| `-v, --version` | — | Show version and exit |
| `-d, --debug` | Off | Print debug output and write frame text to YAML |
| `-q, --quiet` | Off | Suppress all non-error output |
| `-p, --prefix PREFIX` | `invasion` | Prefix for output clip filenames |
| `-o, --outdir DIRECTORY` | `./invasion_clips` | Output directory for extracted clips |
| `--fps RATE` | `2` | Frames per second to extract for OCR |
| `--no-cache` | Off | Skip OCR cache and force re-processing |
| `--pad-start SECONDS` | `10.0` | Seconds to include before invasion start |
| `--pad-end SECONDS` | `7.5` | Seconds to include after invasion end |
| `--continue-on-error` | Off | Continue processing remaining videos if one fails |
| `--ffmpeg-threads N` | `4` | ffmpeg encoding threads |
| `--hwaccel` | Off | Enable VAAPI hardware acceleration |

#### Export & WebUI Flags

| Flag | Command | Description |
|------|---------|-------------|
| `-o, --output FILE` | `export-kdenlive`, `concat` | Output file path |
| `-t, --transition SECONDS` | `export-kdenlive` | Transition duration (default: 2.5) |
| `-p, --port PORT` | `webui` | Server port (default: 4567) |

### Flag Details

**`--fps RATE`** — Controls how many frames per second are extracted from the video for OCR. The default `2` means one frame every 0.5 seconds. Increasing to `4` or `5` improves detection accuracy for very short invasions but increases processing time linearly. Decreasing to `1` speeds things up but may miss brief text flashes.

**`--debug`** — Enables two things: (1) prints every matched start/end frame with its exact timestamp and raw OCR text so you can inspect why an invasion was missed, and (2) writes a `<video_hash>.debug.yml` file containing every extracted frame's timestamp and detected text.

**`--hwaccel`** — Enables VAAPI hardware acceleration for faster ffmpeg encoding. Requires a compatible GPU and drivers.

---

## Usage Examples

### Basic Extraction

```bash
# Extract from a single video
bin/invasion_extractor video.mp4

# Extract from multiple videos with prefix
bin/invasion_extractor --prefix my-invasions ~/Videos/Capture/*.mp4

# Specify output directory
bin/invasion_extractor -o ~/Desktop/clips ~/Videos/Capture/*.mp4
```

### Scan Mode (Preview Invasions)

```bash
# Scan only - shows timestamps without extracting
bin/invasion_extractor scan ~/Videos/Capture/*.mp4

# Output:
# Detected Invasions:
#   [1] 00:05:30.000 → 00:08:45.500
#       File: 2024-01-15_18-39-00.mp4
#   [2] 00:22:15.000 → 00:25:30.250
#       Cross-file: 2024-01-15_18-39-00.mp4 → 2024-01-15_19-39-00.mp4
#
# Total: 2 invasion(s) detected
```

### Debug Mode

```bash
# See exactly what OCR detected at every timestamp
bin/invasion_extractor -d ~/Videos/Capture/*.mp4

# Output includes:
#   [START] 00:01:23.500 => "Defeat the Host of Fingers"
#   [END]   00:02:45.000 => "Returning to your world"
#
# Plus a .debug.yml file with every frame's text
```

### Export & Concatenate

```bash
# Export clips folder to a Kdenlive timeline
bin/invasion_extractor export-kdenlive ~/Videos/ER/clips

# Export with custom output path and transition duration
bin/invasion_extractor export-kdenlive -o ~/Videos/ER/project.kdenlive -t 3.0 ~/Videos/ER/clips

# Concatenate all clips into a single video (no re-encoding, with chapter markers)
bin/invasion_extractor concat ~/Videos/ER/clips

# Concat with custom output
bin/invasion_extractor concat -o ~/Videos/ER/final.mp4 ~/Videos/ER/clips
```

### Cache Management

OCR results are cached automatically in `/dev/shm/invasion_extractor_cache/`. To force re-processing:

```bash
# Skip cache for this run
bin/invasion_extractor --no-cache ~/Videos/Capture/*.mp4

# Clear cache manually
rm -rf /dev/shm/invasion_extractor_cache/*.yml
```

---

## Requirements & Compatibility

| Requirement | Details |
|------------|---------|
| **Resolution** | Optimized for 1440p (2560×1440), works at 1080p and 720p |
| **Framerate** | 30fps or 60fps |
| **Platform** | macOS and Linux (tested), Windows should work |
| **Language** | English only (for now) |
| **Ruby** | 3.3+ |
| **Browsers** | Any modern browser (Chrome, Firefox, Safari, Edge) |

### Known Limitations

- **UI Overlays**: PSN quick menu or other overlays covering game text can cause missed detections
- **Text Position**: Invasion text must be visible — if you're in a menu when it appears, detection may fail
- **Performance**: OCR processing averages ~0.18s per frame on CPU. A 60-minute video at 2fps extracts ~7200 frames, taking approximately 20 minutes. Enable `--hwaccel` or use a faster machine for large batches.

---

## Architecture

```
lib/invasion_extractor/
├── invasion_extractor.rb    # Main entry point, dependency checks
├── cli.rb                   # CLI orchestrator (parses args, dispatches commands)
├── commands/
│   ├── base.rb              # Abstract command base class
│   ├── extract.rb           # Extract/scan command implementation
│   ├── export_kdenlive.rb # Kdenlive timeline export
│   ├── concat.rb           # Concatenate clips into single video
│   └── webui.rb            # WebUI server launcher
├── engine.rb                # High-level orchestration with 3-stage pipeline
├── video.rb                 # Video file representation & YAML caching
├── ocr_worker.rb            # Frame extraction (rawvideo pipe) and OCR processing
├── frame.rb                 # Data structure for frame metadata
├── scanner.rb               # Pattern matching for invasion detection
├── clip.rb                  # Video clip generation (ffmpeg)
├── time_helper.rb           # Time manipulation utilities
├── version.rb               # Version constant
├── project.rb               # Project data model (clips, groups, metadata)
├── project_exporter.rb      # Group export to spliced video + Kdenlive
├── kdenlive_exporter.rb     # Kdenlive MLT XML project generator
├── ocr/
│   ├── provider.rb          # Abstract OCR interface
│   └── tesseract_provider.rb # Tesseract OCR implementation (default)
└── webui/                   # Browser-based studio
    ├── server.rb            # Sinatra API and static file serving
    ├── views/               # ERB templates
    └── public/              # Stimulus.js controllers + CSS
```

### Data Flow

```
Video Files → OCRWorker → Frames → Scanner → Segments → Clip → Output Files
     ↓            ↓          ↓         ↓          ↓       ↓
   ffmpeg    rawvideo    Cache    Regex     Struct   ffmpeg
   pipe        pipe     (YAML)

Extracted Clips → Project.json → WebUI → Groups → Export (Spliced + Kdenlive)
```

---

## Development

### Running Tests

```bash
bundle exec rake test
```

All tests run against sample video files in `test/samples/`.

### Using the OCR Provider Directly

```ruby
provider = InvasionExtractor::OCR::TesseractProvider.new
result = provider.recognize('test/samples/invasion_start.jpg')
puts result
```

---

## Contributing

Contributions welcome! Areas that need help:

- **Windows testing**: Primarily tested on macOS and Linux
- **Multi-language support**: Japanese, German, French, etc.
- **OCR accuracy**: Tuning crop regions for better text detection
- **GPU acceleration**: EasyOCR/ONNX providers for faster processing

Open an issue or submit a PR at [github.com/bladeofmaya/invasion_extractor](https://github.com/bladeofmaya/invasion_extractor).

---

## Support

If this tool saves you time, consider supporting development:

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/bladeofmaya)

## License

MIT License - see [MIT-LICENSE](MIT-LICENSE)

---

*Happy invading! ⚔️*

*For a behind-the-scenes look at how this was built, check out the [creation stream summary](https://www.youtube.com/watch?v=ZAWuatbjIuc).*
