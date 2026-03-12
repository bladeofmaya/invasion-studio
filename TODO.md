# Invasion Extractor - Implementation Overview

## Current State

This Ruby gem automatically detects and extracts invasion clips from Elden Ring gameplay footage using OCR.

### ✅ Implemented Features

- **OCR Provider System**: Strategy pattern with pluggable providers
  - `TesseractProvider` (default) - CPU-based, ~0.2s/frame
  - `OllamaProvider` - Vision LLM support (requires GPU)
  
- **Video Processing**: 
  - Multi-file support (handles invasions spanning across files)
  - Automatic frame extraction at 2 fps
  - Crop region optimized for Elden Ring text position
  
- **Clip Generation**:
  - Detects invasion start/end from on-screen text
  - 10-second buffer before start, 7.5s after end
  - Outputs sequentially numbered files

- **Caching**: OCR results cached per video (YAML-based)

### 📁 Architecture

```
lib/invasion_extractor/
├── ocr/
│   ├── provider.rb              # Abstract base class
│   ├── tesseract_provider.rb    # Default OCR provider
│   └── ollama_provider.rb       # Vision LLM provider
├── engine.rb                    # Main orchestration
├── video.rb                     # Video file + caching
├── ocr_worker.rb               # Frame extraction + OCR
├── scanner.rb                  # Pattern matching
├── clip.rb                     # Video clip generation
└── time_helper.rb              # Time manipulation
```

### 🔧 OCR Providers

#### TesseractProvider (Default)
- **Speed**: ~0.2s per frame on CPU
- **Setup**: `sudo pacman -S tesseract tesseract-data-eng`
- **Best for**: Quick processing, no GPU required

#### OllamaProvider
- **Speed**: ~0.5-2s per frame on GPU
- **Setup**: Install Ollama + vision model (e.g., `llava:7b`)
- **Best for**: Better accuracy on stylized text, variable positions

### 🎯 Detection Patterns

Current hardcoded patterns in `scanner.rb`:

**Invasion Start**:
- "Defeat.*Host of Fingers"
- "Invading another world"
- "Commencing combat" (Arena)

**Invasion End**:
- "Returning to your world"
- "Host of Fingers defeated"
- "Combat ends" (Arena)

### ⚠️ Known Limitations

1. **English only** - Config system exists but not integrated
2. **Text position sensitivity** - OCR crop region is fixed
3. **UI overlays** - PSN quick menu can block detection
4. **macOS tested only** - Should work on Linux/Windows

### 🔮 Future Improvements

#### Near-term (High Value)
- [ ] Frame pre-filtering (skip dark/empty frames) - 30-50% speedup
- [ ] Multi-language support (integrate config/detection.yml)
- [ ] Larger/adaptive crop regions for variable text positions

#### Medium-term
- [ ] Hybrid provider (Tesseract + Ollama fallback)
- [ ] Progress callbacks for CLI feedback
- [ ] Enhanced cache with versioning

#### Nice-to-have
- [ ] EasyOCR provider (Python-based, GPU accelerated)
- [ ] Frame sampling strategy (adaptive fps)
- [ ] GPU acceleration for FFmpeg

### 📊 Performance Targets

| Method | 60min Video | Accuracy | Setup |
|--------|-------------|----------|-------|
| Tesseract (current) | ~30-60s | ~75% | Easy |
| Tesseract + pre-filter | ~20-40s | ~75% | Easy |
| Ollama (GPU) | ~5-10min | ~85% | Medium |

### 🚀 Usage

```bash
# Basic usage
bin/invasion_extractor --prefix invasion --outdir ./clips video1.mp4 video2.mp4

# With specific provider (Ruby)
require 'invasion_extractor'

provider = InvasionExtractor::OCR::OllamaProvider.new(
  model: 'llava:7b',
  host: 'http://localhost:11434'
)

engine = InvasionExtractor::Engine.new(
  ['video.mp4'], 
  ocr_provider: provider
)
engine.extract_invasion_clips!('prefix', './output')
```

### 🧪 Testing

```bash
bundle exec rake test  # Runs full test suite
ruby benchmark_ocr.rb  # Benchmark providers
```

### 📝 Notes

- The `TODO.md` was originally a detailed architecture proposal
- Phase 1 (Foundation) is **complete** - OCR abstraction working
- Phase 2 (Performance) is **partial** - Tesseract benchmarked, Ollama ready for GPU testing
- See `BENCHMARK_SUMMARY.md` for detailed findings

---

*Last updated: After implementation session - Tesseract working, Ollama skeleton ready, all tests passing*
