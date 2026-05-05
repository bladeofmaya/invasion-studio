# Invasion Extractor - Agent Documentation

## Core directive when working with this project

Use Test Driven Development when implementing new features / refactoring code. Running tests are the most important thing for stability. Use SOLID design principles when shaping the code. Write simple and beautiful code that is human readable. Good naming is key.


## Overview

**Invasion Extractor** is a Ruby gem that automatically detects the start and end of invasions in Elden Ring gameplay footage. It uses OCR (Optical Character Recognition) to scan video frames for specific text markers (e.g., "Defeat the Host of Fingers", "Returning to your world") and extracts clips accordingly.

## Architecture

### Core Components

```
lib/invasion_extractor/
├── invasion_extractor.rb    # Main entry point, dependency checks
├── engine.rb                # High-level orchestration with stages
├── video.rb                 # Video file representation & caching
├── ocr_worker.rb            # Frame extraction and OCR processing
├── frame.rb                 # Data structure for frame metadata
├── frame_filter.rb          # Pre-filter frames before OCR (brightness, edges, text-likeness)
├── scanner.rb               # Pattern matching for invasion detection
├── clip.rb                  # Video clip generation (ffmpeg)
├── time_helper.rb           # Time manipulation utilities
├── gpu_detector.rb          # GPU detection for hardware acceleration
├── progress_reporter.rb     # Visual progress bars and stage reporting
├── progress_handler.rb      # Progress callback handler for OCRWorker
├── benchmark_runner.rb      # Benchmarking and performance profiling
├── session.rb               # Session state for resume capability
├── session_store.rb         # Session persistence to disk
├── version.rb               # Version constant
└── ocr/                     # OCR Provider implementations
    ├── provider.rb          # Abstract base class
    ├── tesseract_provider.rb# Tesseract OCR implementation
    ├── ollama_provider.rb   # Ollama vision LLM implementation
    └── easyocr_provider.rb  # EasyOCR Python bridge implementation
```

### Data Flow

```
Video Files → OCRWorker → FrameFilter → Frames → Scanner → Segments → Clip → Output Files
     ↓            ↓           ↓          ↓         ↓          ↓       ↓
   ffmpeg    Tesseract   ruby-vips   Cache(YAML) Regex   Struct  ffmpeg
```

### Key Classes

#### 1. Engine (`engine.rb`)
- **Responsibility**: Main entry point for video processing with 3-stage pipeline
- **Key Methods**:
  - `run!(videos, options)` - Class method to start processing
  - `run_ocr_stage` - Extract frames and run OCR with progress reporting
  - `run_scan_stage` - Detect invasions across all videos
  - `run_extraction_stage` - Generate output clips
  - `extract_invasion_clips!(prefix, output_dir)` - Generates output files (legacy)
  - `show_status` - Display session summary
- **Features**:
  - Session management with resume capability
  - Benchmarking integration
  - Progress reporting per stage
  - Error handling with `continue_on_error` option

#### 2. OCRWorker (`ocr_worker.rb`)
- **Responsibility**: Extract frames from video and run OCR
- **Process**:
  1. Uses ffmpeg to extract frames at 2 fps
  2. Crops video to specific region (game text area)
  3. Applies contrast/brightness enhancement
  4. Optionally uses GPU-accelerated decoding (nvidia/amd/intel)
  5. Filters frames via FrameFilter to skip dark/empty frames
  6. Runs OCR in parallel (using all CPU cores)
  7. Returns array of Frame objects
- **Configuration**:
  - Base resolution: 2560x1440
  - Crop region: 700x200 @ 950x960 (fixed from previous 965/150)
  - Frame rate: 2 fps (configurable)
  - GPU fallback: Falls back to CPU if GPU frame extraction fails

#### 3. Video (`video.rb`)
- **Responsibility**: Represents a video file with caching
- **Features**:
  - Caches OCR results to YAML (in `~/.invasion_extractor/cache/`)
  - Uses video filename + path hash as cache key
  - Avoids re-processing same video
  - Exposes metadata (height, width, fps)

#### 4. Scanner (`scanner.rb`)
- **Responsibility**: Detects invasion start/end from frame text
- **Pattern Matching**:
  - Start: `/Defeat.*Host of Fingers|Commencing combat/i`
  - End: `/Returning to your world|Combat ends/i`
- **Edge Cases**:
  - Handles invasions starting before first frame (assumes 00:00:00)
  - Handles invasions ending after last frame (uses last frame timestamp)
  - Supports multi-file invasions (when invasion spans video files)
- **Note**: YAML config exists but isn't wired into the Scanner class (still TODO)

#### 5. Clip (`clip.rb`)
- **Responsibility**: Generates output video clips
- **Features**:
  - Adjusts timestamps (winds back 10s at start, forward 7.5s at end)
  - Supports single-file and multi-file invasions
  - Uses ffmpeg for lossless cutting (copy codec)
  - Writes ffmpeg logs alongside output files

#### 6. FrameFilter (`frame_filter.rb`)
- **Responsibility**: Pre-filter frames before OCR to skip obviously empty/dark frames
- **Checks**:
  1. Brightness threshold (default: 15) - skip dark frames
  2. Edge density threshold (default: 0.05) - skip blurry/uniform frames
  3. Text-like pattern detection (default: 0.02) - check for horizontal text bands
- **Implementation**: Uses ruby-vips for fast image analysis
- **Stats tracking**: Tracks total, passed, skipped (dark/edges/text), skip rate

#### 7. OCR Providers (`ocr/`)
- **Provider (Base)**: Abstract interface with `recognize(image_path)`
- **TesseractProvider**: Default, uses RTesseract gem, ~0.3-0.5s per frame
- **OllamaProvider**: Uses vision LLM (llava:7b), requires Ollama server, batch support
- **EasyOCRProvider**: Python bridge using easyocr library, GPU/CPU support
- **Selection**: Configurable via `--ocr-provider` CLI flag

#### 8. Session Management (`session.rb`, `session_store.rb`)
- **Session**: Tracks video status, detected invasions, clips to extract
- **SessionStore**: Persists sessions as JSON to `~/.invasion_extractor/sessions/`
- **Features**:
  - Resume interrupted sessions (`--resume`)
  - Track per-video progress (frames processed, invasions detected)
  - Track clip extraction status

#### 9. BenchmarkRunner (`benchmark_runner.rb`)
- **Responsibility**: Performance benchmarking and profiling
- **Metrics**:
  - Stage timing (OCR, scan, extraction)
  - Memory usage (RSS from /proc)
  - Frames per second during OCR
  - Clips per minute during extraction
- **Output**: Console report + optional JSON file

### Configuration

**Detection Patterns** (`config/detection.yml`):
```yaml
fps: 2
ollama:
  model: "qwen3.5:27b"
  host: "http://localhost:11434"
languages:
  en:
    events:
      invasion_start:
        match_mode: "contains"
        match_text: ["Defeat the Host of Fingers", ...]
```

**Note**: The YAML config is loaded but not currently integrated into the Scanner class.

## Dependencies

### Required System Dependencies
- **FFmpeg**: Video processing (frame extraction, clip generation, metadata)
- **Tesseract OCR**: Text recognition from frames (default provider)

### Optional System Dependencies
- **Ollama**: For vision LLM OCR (requires running server with llava or similar model)
- **Python + easyocr**: For EasyOCR provider
- **NVIDIA/AMD/Intel GPU**: For GPU-accelerated frame extraction

### Ruby Dependencies
- `rtesseract` (~> 3.1.3): Ruby wrapper for Tesseract
- `parallel` (~> 1.25): Multi-process parallel processing
- `optparse` (~> 0.5): CLI argument parsing
- `ruby-progressbar` (~> 1.13): Visual progress bars
- `ruby-vips` (~> 2.2): Fast image processing for frame filtering
- `faraday` (~> 2.0): HTTP client for Ollama provider
- `base64` (~> 0.2): Image encoding for Ollama provider

### Development Dependencies
- `minitest` (~> 5.16): Testing framework
- `pry` (~> 0.14): Debugging
- `rake` (~> 13.0): Build tasks
- `bundler` (~> 2.0): Dependency management

## Testing

Test suite uses Minitest with sample video files:
- `test/samples/invasion-sample-720p.mp4` - Primary test video (720p, ~3.5 min)
- `test/samples/invasion-sample-full.mp4` - Full resolution test video
- `test/samples/arena-sample-720p.mp4` - Arena/combat test video
- `test/samples/invasion_start.jpg` - Static image for OCR provider tests
- `test/samples/invasion_end.jpg` - Static image for OCR provider tests

### Test Files
- `test/test_helper.rb` - Test setup
- `test/test_invasion_extractor.rb` - Version/basic tests
- `test/test_engine.rb` - End-to-end engine tests
- `test/test_ocr_worker.rb` - OCR worker tests (with/without filter, progress callbacks)
- `test/test_ocr_provider.rb` - Provider abstraction and Tesseract tests
- `test/test_frame_filter.rb` - FrameFilter unit tests
- `test/test_frame_filter_integration.rb` - Frame filter integration with real video
- `test/test_video.rb` - Video metadata and frame loading tests

Run tests: `rake test` (default task)

## CLI Usage

```bash
# Basic extraction
bin/invasion_extractor ~/Videos/Capture/*.mp4

# With prefix and output directory
bin/invasion_extractor extract -p ps-daggers-tt-04 -o ~/Videos/ER/clips ~/Videos/Capture/*.mp4

# Resume a long session
bin/invasion_extractor extract --resume session-001 --save-session session-001 ~/Videos/Capture/*.mp4

# Scan only - find invasions without extracting
bin/invasion_extractor scan ~/Videos/Capture/*.mp4

# Run with full benchmarking
bin/invasion_extractor extract --benchmark --profile all --benchmark-output report.json ~/Videos/*.mp4

# GPU-accelerated extraction with EasyOCR
bin/invasion_extractor extract --ocr-provider easyocr --use-gpu ~/Videos/Capture/*.mp4

# Session management
bin/invasion_extractor status                    # List all sessions
bin/invasion_extractor status --save-session ID  # Show specific session
bin/invasion_extractor cache list                # List OCR cache
bin/invasion_extractor cache clear               # Clear OCR cache
bin/invasion_extractor benchmark ~/Videos/*.mp4  # Run benchmarks
```

### CLI Options
- `-p, --prefix PREFIX` - Output file prefix (default: invasion)
- `-o, --outdir DIRECTORY` - Output directory (default: ./invasion_clips)
- `-j, --jobs N` - Parallel jobs (default: auto)
- `--fps RATE` - Frame extraction rate (default: 2)
- `--ocr-provider NAME` - OCR engine: tesseract (default), easyocr, ollama
- `--use-gpu` - Enable GPU acceleration for frame extraction
- `--no-cache` - Skip OCR cache, force re-processing
- `--resume SESSION` - Resume from saved session
- `--save-session NAME` - Save session ID
- `--no-progress` - Disable progress bars
- `--quiet` - Suppress non-error output
- `--pad-start SECONDS` - Seconds before invasion (default: 10)
- `--pad-end SECONDS` - Seconds after invasion (default: 7.5)
- `--start-pattern REGEX` - Custom regex for invasion start
- `--end-pattern REGEX` - Custom regex for invasion end
- `--benchmark` - Enable timing benchmarks
- `--profile [TYPE]` - Profile: memory, cpu, all
- `--benchmark-output FILE` - Save benchmark report to JSON

## Current Limitations

1. **Performance**: Tesseract OCR is CPU-intensive and slow (~0.3-0.5s per frame)
2. **Language**: Only English is supported (despite config having multi-language structure)
3. **Platform**: Primarily tested on macOS and Linux
4. **Resolution**: Optimized for 2560x1440, may need adjustment for other resolutions
5. **Config Integration**: YAML config exists but isn't wired into the Scanner
6. **Frame Processing**: FrameFilter helps but still processes many non-text frames
7. **GPU OCR**: Only frame extraction uses GPU; OCR itself is still CPU-based (except Ollama with GPU)
8. **Ollama Provider**: Requires running Ollama server, not self-contained

## File Structure

```
/
├── bin/
│   ├── invasion_extractor    # CLI executable
│   ├── console               # Interactive console
│   └── setup                 # Setup script
├── lib/
│   └── invasion_extractor/
│       ├── [core files]
│       └── ocr/
│           ├── provider.rb
│           ├── tesseract_provider.rb
│           ├── ollama_provider.rb
│           └── easyocr_provider.rb
├── config/
│   └── detection.yml         # Detection patterns config
├── test/
│   ├── test_helper.rb
│   ├── test_*.rb             # Test files
│   └── samples/              # Test video files
├── benchmark_ocr.rb          # OCR benchmarking script
├── tmp/
│   ├── ocr_cache/            # OCR result cache (legacy, now in ~/.invasion_extractor/cache/)
│   └── [frame images]
├── Gemfile
├── invasion_extractor.gemspec
├── Rakefile
└── README.md
```

## Version History

- **v0.2.0** (Current): Base version with core functionality
  - OCR provider abstraction (Tesseract, Ollama, EasyOCR)
  - Frame filtering with ruby-vips
  - GPU detection and acceleration
  - Session management with resume
  - Benchmarking and profiling
  - Progress reporting

## Performance Characteristics

- **Frame Rate**: 2 fps extraction (every 0.5 seconds)
- **Parallelism**: Uses all CPU cores for OCR via `Parallel` gem
- **Frame Filtering**: Can skip 30-50% of frames (dark/blurry/no text)
- **Caching**: OCR results cached per video file in `~/.invasion_extractor/cache/`
- **Memory**: Temporary frames stored in `/tmp` during processing
- **I/O**: Heavy file I/O from frame extraction and cleanup
- **GPU Acceleration**: Detects NVIDIA (cuda), AMD (vaapi), Intel (vaapi) for frame decoding

## Known Issues

1. TODO comments indicate unfinished features:
   - Better cache path implementation (partially done - now uses ~/.invasion_extractor/cache/)
   - Test for multi-file clip generation
   - Windows compatibility for ffmpeg calls
   - Integration of YAML config with Scanner
   - TimeHelper wind_forward needs testing

2. FrameFilter requires ruby-vips which may need system dependencies (libvips)

3. OllamaProvider requires faraday gem and running Ollama server

4. EasyOCRProvider requires Python with easyocr installed

5. No progress indication at the per-frame level within OCR stage (only stage-level)

## Design Patterns Used

- **Factory**: `Engine.run!` creates instances
- **Strategy**: OCR providers (Tesseract, Ollama, EasyOCR) and Clip single vs multi-file
- **Template Method**: Video loading with cache check
- **Data Transfer Object**: Frame, Segment structs
- **Observer**: Progress callbacks in OCRWorker and ProgressReporter
- **Command**: CLI command pattern (extract, scan, status, cache, benchmark)
