# Invasion Extractor - Agent Documentation

## Important note

- DO NOT RUN TESTS THAT PROCESS VIDEOS. These will be run by myself to avoid the agent to timeout.

## Core directive when working with this project

Use Test Driven Development when implementing new features / refactoring code. Running tests are the most important thing for stability. Use SOLID design principles when shaping the code. Write simple and beautiful code that is human readable. Good naming is key.

## Overview

**Invasion Extractor** is a Ruby gem that automatically detects the start and end of invasions in Elden Ring gameplay footage. It uses OCR (Optical Character Recognition) to scan video frames for specific text markers (e.g., "Defeat the Host of Fingers", "Returning to your world") and extracts clips accordingly.

## Architecture

### Core Components

```
lib/invasion_extractor/
├── invasion_extractor.rb    # Main entry point, dependency checks, VideoHasher
├── cli.rb                   # CLI orchestrator (parses args, dispatches commands)
├── commands/
│   ├── base.rb              # Abstract command base class
│   └── extract.rb           # Extract/scan command implementation
├── engine.rb                # High-level orchestration with 3-stage pipeline
├── video.rb                 # Video file representation & YAML caching
├── ocr_worker.rb            # Frame extraction (rawvideo pipe) and OCR processing
├── frame.rb                 # Data structure for frame metadata
├── scanner.rb               # Pattern matching for invasion detection
├── clip.rb                  # Video clip generation (ffmpeg)
├── time_helper.rb           # Time manipulation utilities
├── version.rb               # Version constant
└── ocr/
    ├── provider.rb          # Abstract OCR interface
    └── tesseract_provider.rb# Tesseract OCR implementation (default)
```

### Data Flow

```
Video Files → OCRWorker → Frames → Scanner → Segments → Clip → Output Files
     ↓            ↓          ↓         ↓          ↓       ↓
   ffmpeg    rawvideo    Cache    Regex     Struct   ffmpeg
   pipe        pipe     (YAML)
```

### Key Classes

#### 1. CLI (`cli.rb`) & Commands (`commands/`)
- **Responsibility**: Parse command-line arguments and dispatch to the appropriate command handler
- **CLI Class**:
  - `run` - Main entry point: parses global options, detects command, delegates execution
  - `parse_global_options!` - Extracts global flags (`--help`, `--version`, `--debug`, `--quiet`)
  - `detect_command!` - Identifies command from argv (defaults to `extract`)
  - `execute_command!` - Instantiates and runs the correct command class
- **Command Classes** (Strategy pattern):
  - `Commands::Base` - Abstract base with `run` method
  - `Commands::Extract` - Handles `extract` and `scan` commands (option parsing, validation, dependency checks, engine execution)
- **Design**: Follows Open/Closed Principle - new commands can be added without modifying existing code

#### 2. Engine (`engine.rb`)
- **Responsibility**: Main entry point for video processing with 3-stage pipeline
- **Key Methods**:
  - `run!(videos, options)` - Class method to start processing
  - `run_ocr_stage` - Extract frames and run OCR (writes debug YAML if `--debug`)
  - `run_scan_stage` - Detect invasions across all videos
  - `run_extraction_stage` - Generate output clips
  - `scanner` - Lazily builds Scanner once and caches it
  - `clips` - Builds Clip objects from scanner segments
- **Features**:
  - Scanner is built once and reused for scan + extraction stages
  - Error handling with `continue_on_error` option
  - Debug mode writes frame-by-frame OCR results to YAML and prints matched timestamps

#### 3. OCRWorker (`ocr_worker.rb`)
- **Responsibility**: Extract frames from video and run OCR
- **Process**:
  1. Uses ffmpeg with a `rawvideo` pipe to output grayscale frames directly to memory
  2. Crops video to specific region (game text area)
  3. Applies contrast/brightness enhancement
  4. A producer thread reads fixed-size chunks from the ffmpeg pipe
  5. Consumer threads write each frame to a temporary PGM file and run OCR
  6. Temporary files are immediately deleted
  7. Returns array of Frame objects
- **Configuration**:
  - Base resolution: 2560x1440
  - Crop region: 700x130 @ 950x960
  - Frame rate: 2 fps (configurable via `--fps`)
- **No disk I/O**: Frames are never written to disk as JPEGs

#### 4. Video (`video.rb`)
- **Responsibility**: Represents a video file with caching
- **Features**:
  - Caches OCR results to YAML (in `~/.invasion_extractor/cache/`)
  - Uses `VideoHasher.hash(path)` for cache key
  - Avoids re-processing same video
  - Exposes metadata (height, width, fps)

#### 5. Scanner (`scanner.rb`)
- **Responsibility**: Detects invasion start/end from frame text
- **Pattern Matching**:
  - Start: `/Defeat.*Host of Fingers|Commencing combat/i`
  - End: `/Returning to your world|Combat ends/i`
- **Edge Cases**:
  - Handles invasions starting before first frame (assumes 00:00:00)
  - Handles invasions ending after last frame (uses last frame timestamp)
  - Supports multi-file invasions (when invasion spans video files)
- **Debug support**: `matched_frames` exposes every frame that hit a pattern

#### 6. Clip (`clip.rb`)
- **Responsibility**: Generates output video clips
- **Features**:
  - Adjusts timestamps via `TimeHelper.wind_back` / `wind_forward`
  - Respects `--pad-start` and `--pad-end` options
  - Supports single-file and multi-file invasions
  - Uses ffmpeg for lossless cutting (copy codec)
  - Writes ffmpeg logs alongside output files

#### 7. OCR Providers (`ocr/`)
- **Provider (Base)**: Abstract interface with `recognize(image_path)`
- **TesseractProvider**: Default, uses RTesseract gem

### Shared Utilities

- **`InvasionExtractor::VideoHasher`** - Single source of truth for video path hashing (used by Video and cache)
- **`InvasionExtractor::CACHE_DIR`** - `~/.invasion_extractor/cache/`

## Dependencies

### Required System Dependencies
- **FFmpeg**: Video processing (frame extraction, clip generation, metadata)
- **Tesseract OCR**: Text recognition from frames (default provider)

### Ruby Dependencies
- `rtesseract` (~> 3.1.3): Ruby wrapper for Tesseract
- `optparse` (~> 0.5): CLI argument parsing
- `parallel` (~> 1.25): Multi-process parallel processing

### Development Dependencies
- `minitest` (~> 5.16): Testing framework
- `pry` (~> 0.14): Debugging
- `rake` (~> 13.0): Build tasks
- `bundler` (~> 2.0): Dependency management

## Testing

Test suite uses Minitest with sample video files:
- `test/samples/invasion-sample-720p.mp4` - Primary test video (720p, ~3.5 min)
- `test/samples/invasion_start.jpg` - Static image for OCR provider tests
- `test/samples/invasion_end.jpg` - Static image for OCR provider tests

### Test Files
- `test/test_helper.rb` - Test setup
- `test/test_invasion_extractor.rb` - Version/basic tests
- `test/test_engine.rb` - End-to-end engine tests
- `test/test_ocr_worker.rb` - OCR worker tests
- `test/test_ocr_provider.rb` - Provider abstraction and Tesseract tests
- `test/test_video.rb` - Video metadata and frame loading tests
- `test/test_cli.rb` - CLI parsing and dispatch tests
- `test/test_commands.rb` - Command class tests

Run tests: `rake test` (default task)

## CLI Usage

```bash
# Basic extraction
bin/invasion_extractor ~/Videos/Capture/*.mp4

# With prefix and output directory
bin/invasion_extractor extract -p ps-daggers-tt-04 -o ~/Videos/ER/clips ~/Videos/Capture/*.mp4

# Scan only - find invasions without extracting
bin/invasion_extractor scan ~/Videos/Capture/*.mp4

# Debug mode - see every matched frame and write YAML debug file
bin/invasion_extractor extract -d ~/Videos/Capture/*.mp4
```

### CLI Options
- `-p, --prefix PREFIX` - Output file prefix (default: invasion)
- `-o, --outdir DIRECTORY` - Output directory (default: ./invasion_clips)
- `--fps RATE` - Frame extraction rate (default: 2)
- `--no-cache` - Skip OCR cache, force re-processing
- `--pad-start SECONDS` - Seconds before invasion (default: 10)
- `--pad-end SECONDS` - Seconds after invasion (default: 7.5)
- `--continue-on-error` - Continue processing remaining videos if one fails
- `-d, --debug` - Enable debug output (writes frame text to YAML)
- `-q, --quiet` - Suppress non-error output

## Current Limitations

1. **Language**: Only English is supported
2. **Platform**: Primarily tested on macOS and Linux
3. **Resolution**: Optimized for 2560x1440, may need adjustment for other resolutions
4. **OCR**: Tesseract is CPU-intensive and slow (~0.3-0.5s per frame)

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
│       ├── commands/
│       │   ├── base.rb
│       │   └── extract.rb
│       └── ocr/
│           ├── provider.rb
│           └── tesseract_provider.rb
├── test/
│   ├── test_helper.rb
│   ├── test_*.rb             # Test files
│   └── samples/              # Test video files
├── tmp/
│   └── [temp files]
├── Gemfile
├── invasion_extractor.gemspec
├── Rakefile
├── README.md
└── AGENTS.md
```

## Design Patterns Used

- **Factory**: `Engine.run!` creates instances
- **Strategy**: Clip single vs multi-file generation
- **Template Method**: Video loading with cache check
- **Data Transfer Object**: Frame, Segment structs
- **Command**: CLI command pattern (extract, scan)
