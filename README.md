# Elden Ring Invasion Extractor

Automatically detect and extract invasion clips from your Elden Ring gameplay footage. This Ruby gem scans your recordings using OCR (Optical Character Recognition) to find invasion start/end points and cuts them into separate video files—perfect for content creators who want to streamline their editing workflow.

[📺 Watch the demo](https://www.youtube.com/watch?v=-G9ARNrhMOI)

![](images/invasion-extractor.jpg)

---

## Quick Start

Just want to extract some invasions? Here's everything you need:

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

### Basic Usage

```bash
# Extract invasions from a single video
bin/invasion_extractor video.mp4

# Extract with custom prefix and output directory
bin/invasion_extractor --prefix ps-daggers-tt-04 --outdir ~/Videos/ER/clips ~/Videos/Capture/*.mp4

# Scan only - find invasions without extracting
bin/invasion_extractor scan ~/Videos/Capture/*.mp4
```

**Output:**
```
~/Videos/ER/clips/
├── ps-daggers-tt-04_00001.mp4
├── ps-daggers-tt-04_00002.mp4
├── ps-daggers-tt-04_00003.mp4
└── ...
```

**Pro tip:** If OBS splits your recordings into segments (e.g., 60-minute chunks), pass all files in order. The tool detects invasions that span across files and combines them automatically.

---

## What It Does

This tool reads on-screen text to detect:
- **Invasion Start**: "Invading another world" / "Defeat [Name], Host of Fingers"
- **Invasion End**: "Returning to your world" / "Host of Fingers defeated"
- **Arena Duels**: "Commencing combat" / "Combat ends"

It then automatically cuts your video into individual invasion clips, adding a 10-second buffer before the start and 7.5 seconds after the end so you don't miss any action.

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
| `status` | Show session status and resume info |
| `cache` | Manage OCR cache |
| `benchmark` | Run performance benchmarks |

### Global Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --version` | Show version |
| `-d, --debug` | Enable debug output |
| `-q, --quiet` | Suppress non-error output |

### Extract/Scan Options

| Option | Default | Description |
|--------|---------|-------------|
| `-p, --prefix PREFIX` | `invasion` | Prefix for output files |
| `-o, --outdir DIRECTORY` | `./invasion_clips` | Output directory |
| `-j, --jobs N` | Auto | Parallel jobs |
| `--fps RATE` | `2` | Frame extraction rate |
| `--ocr-provider NAME` | `tesseract` | OCR engine: tesseract, easyocr, ollama |
| `--use-gpu` | Off | Enable GPU acceleration |
| `--no-cache` | Off | Force re-processing |
| `--pad-start SECONDS` | `10.0` | Seconds before invasion |
| `--pad-end SECONDS` | `7.5` | Seconds after invasion |
| `--start-pattern REGEX` | Auto | Custom start pattern |
| `--end-pattern REGEX` | Auto | Custom end pattern |

### Resume & Session Options

| Option | Description |
|--------|-------------|
| `--resume SESSION` | Resume from saved session |
| `--save-session NAME` | Save session for resuming |
| `--no-progress` | Disable progress bars |

### Benchmarking Options

| Option | Description |
|--------|-------------|
| `--benchmark` | Enable timing benchmarks |
| `--profile [TYPE]` | Profile: memory, cpu, all |
| `--benchmark-output FILE` | Save report to JSON |

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

### Resume Long Sessions

When processing many large video files, sessions can take hours. The resume feature allows you to stop and continue later:

```bash
# Start a session with a name
bin/invasion_extractor extract --save-session stream-001 ~/Videos/Capture/*.mp4

# ... processing starts, progress bar shows ...
# Press Ctrl+C to interrupt

# Later, resume where you left off
bin/invasion_extractor extract --resume stream-001 --save-session stream-001 ~/Videos/Capture/*.mp4

# Check status of a session
bin/invasion_extractor status --save-session stream-001

# List all sessions
bin/invasion_extractor status
```

### Performance Benchmarking

```bash
# Basic benchmark
bin/invasion_extractor extract --benchmark ~/Videos/Capture/video.mp4

# Full profiling with report
bin/invasion_extractor extract --benchmark --profile all --benchmark-output report.json ~/Videos/Capture/*.mp4

# Benchmark different OCR providers
bin/invasion_extractor benchmark --ocr-provider tesseract ~/Videos/Capture/video.mp4
bin/invasion_extractor benchmark --ocr-provider easyocr ~/Videos/Capture/video.mp4
```

### GPU Acceleration

```bash
# Use GPU for frame extraction
bin/invasion_extractor extract --use-gpu ~/Videos/Capture/*.mp4

# GPU with EasyOCR (if you have GPU-enabled EasyOCR installed)
bin/invasion_extractor extract --use-gpu --ocr-provider easyocr ~/Videos/Capture/*.mp4
```

### Cache Management

```bash
# View cache statistics
bin/invasion_extractor cache stats

# List cached entries
bin/invasion_extractor cache list

# Clear all cached OCR data
bin/invasion_extractor cache clear
```

### Custom Detection Patterns

```bash
# Custom patterns for different languages or UI mods
bin/invasion_extractor extract \
  --start-pattern "Invadindo.*mundo" \
  --end-pattern "Retornando.*mundo" \
  ~/Videos/Capture/*.mp4
```

---

## Requirements & Compatibility

| Requirement | Details |
|------------|---------|
| **Resolution** | Optimized for 1440p (2560×1440), works at 1080p and 720p |
| **Framerate** | 30fps or 60fps |
| **Platform** | macOS (tested), Linux & Windows should work |
| **Language** | English only (for now) |
| **Ruby** | 3.0+ |

### Known Limitations

- **UI Overlays**: PSN quick menu or other overlays covering game text can cause missed detections
- **Text Position**: Invasion text must be visible—if you're in a menu when it appears, detection may fail
- **Performance**: Processing a 60-minute video takes ~30-60 seconds on CPU (GPU acceleration available)

---

## Session & Resume System

The tool automatically maintains state in `~/.invasion_extractor/`:

```
~/.invasion_extractor/
├── cache/           # OCR results cache
│   ├── video1-abc123.yml
│   └── video2-def456.yml
└── sessions/        # Processing sessions
    ├── 20260117-143052-a1b2.json
    └── stream-001.json
```

Sessions track:
- Video processing status (pending/completed/error)
- Frame processing counts
- Detected invasions with timestamps
- Clip extraction queue
- Resume capability for interrupted jobs

---

## Performance Tips

1. **Use cache**: Already-processed videos are skipped automatically
2. **Enable GPU**: `--use-gpu` for 2-3x faster frame extraction
3. **Resume long jobs**: Use `--save-session` for multi-hour extractions
4. **Parallel jobs**: Adjust `-j` flag based on your CPU cores
5. **Lower FPS**: For faster (but less accurate) scanning, use `--fps 1`

---

## Development

Want to hack on this or add new features? Here's the technical overview.

### Architecture

The codebase follows SOLID principles with a Strategy pattern for OCR providers:

```
lib/invasion_extractor/
├── ocr/
│   ├── provider.rb              # Abstract OCR interface
│   ├── tesseract_provider.rb      # Tesseract implementation (default)
│   ├── easyocr_provider.rb      # EasyOCR implementation
│   └── ollama_provider.rb         # Vision LLM implementation (experimental)
├── session.rb                     # Session state management
├── session_store.rb               # Session persistence
├── benchmark_runner.rb            # Performance profiling
├── progress_reporter.rb           # CLI progress display
├── engine.rb                      # Main orchestration
├── video.rb                       # Video file representation
├── ocr_worker.rb                  # Frame extraction & OCR processing
├── scanner.rb                     # Pattern matching for invasion detection
└── clip.rb                        # Video clip generation
```

### Data Flow with Sessions

```
Video Files → Session Init → OCR Stage → Scan Stage → Extract Stage
     ↓              ↓              ↓            ↓             ↓
  Validate    Create/Resume   (Parallel)   Detect        (Parallel)
  Existence   State File      per-video    Invasions      clip cuts
```

### Running Tests

```bash
bundle exec rake test
```

All tests run against sample video files in `test/samples/`.

### Using Different OCR Providers

```ruby
# Using Tesseract (default)
provider = InvasionExtractor::OCR::TesseractProvider.new
engine = InvasionExtractor::Engine.new(["video.mp4"], ocr_provider: provider)

# Using EasyOCR (requires easyocr gem)
provider = InvasionExtractor::OCR::EasyOCRProvider.new
engine = InvasionExtractor::Engine.new(["video.mp4"], ocr_provider: provider)

# Using Ollama (requires vision model + GPU)
provider = InvasionExtractor::OCR::OllamaProvider.new(
  model: 'llava:7b',
  host: 'http://localhost:11434'
)
```

See `BENCHMARK_SUMMARY.md` for performance comparisons between providers.

---

## Planned Features

- [x] Automatically detect invasion start and end points
- [x] Support for Arena Duels
- [x] Session-based resume capability
- [x] Progress bars with ETA
- [x] GPU acceleration for frame extraction
- [x] Performance benchmarking
- [x] EasyOCR provider support
- [ ] Multi-language support
- [ ] Support for Taunter's Tongue runs
- [ ] Windows & Linux binaries
- [ ] Real-time processing mode

---

## Contributing

Contributions welcome! Areas that need help:

- **Windows/Linux testing**: Currently only tested on macOS
- **Multi-language support**: Japanese, German, French, etc.
- **OCR accuracy**: Tuning crop regions for better text detection
- **Alternative OCR**: Benchmarking EasyOCR, PaddleOCR, etc.

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
