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

### Usage

```bash
bin/invasion_extractor --prefix pyro-invasion --outdir ~/Desktop/pyro-clips video1.mp4 video2.mp4
```

**Output:**
```
~/Desktop/pyro-clips/
├── pyro-invasion_00001.mp4
├── pyro-invasion_00002.mp4
├── pyro-invasion_00003.mp4
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

## Requirements & Compatibility

| Requirement | Details |
|------------|---------|
| **Resolution** | Optimized for 1440p (2560×1440), works at 1080p and 720p |
| **Framerate** | 30fps or 60fps |
| **Platform** | macOS (tested), Linux & Windows should work |
| **Language** | English only (for now) |

### Known Limitations

- **UI Overlays**: PSN quick menu or other overlays covering game text can cause missed detections
- **Text Position**: Invasion text must be visible—if you're in a menu when it appears, detection may fail
- **Performance**: Processing a 60-minute video takes ~30-60 seconds on CPU

---

## Planned Features

- [x] Automatically detect invasion start and end points
- [x] Support for Arena Duels
- [ ] Multi-language support
- [ ] Support for Taunter's Tongue runs
- [ ] Windows & Linux binaries

---

## Development

Want to hack on this or add new features? Here's the technical overview.

### Architecture

The codebase follows SOLID principles with a Strategy pattern for OCR providers:

```
lib/invasion_extractor/
├── ocr/
│   ├── provider.rb           # Abstract OCR interface
│   ├── tesseract_provider.rb # Tesseract implementation (default)
│   └── ollama_provider.rb    # Vision LLM implementation (experimental)
├── engine.rb                  # Main orchestration
├── video.rb                   # Video file representation
├── ocr_worker.rb             # Frame extraction & OCR processing
├── scanner.rb                # Pattern matching for invasion detection
└── clip.rb                   # Video clip generation
```

### Running Tests

```bash
bundle exec rake test
```

All tests run against sample video files in `test/samples/`.

### Using Different OCR Providers

The tool defaults to Tesseract, but you can swap OCR providers:

```ruby
# Using Tesseract (default)
provider = InvasionExtractor::OCR::TesseractProvider.new
engine = InvasionExtractor::Engine.new(["video.mp4"], ocr_provider: provider)

# Using Ollama (requires vision model + GPU)
provider = InvasionExtractor::OCR::OllamaProvider.new(
  model: 'llava:7b',
  host: 'http://localhost:11434'
)
```

See `BENCHMARK_SUMMARY.md` for performance comparisons between providers.

### Contributing

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
