# Invasion Extractor - Agent Documentation

## Overview

**Invasion Extractor** is a Ruby gem that automatically detects the start and end of invasions in Elden Ring gameplay footage. It uses OCR (Optical Character Recognition) to scan video frames for specific text markers (e.g., "Defeat the Host of Fingers", "Returning to your world") and extracts clips accordingly.

## Architecture

### Core Components

```
lib/invasion_extractor/
├── invasion_extractor.rb    # Main entry point, dependency checks
├── engine.rb                # High-level orchestration
├── video.rb                 # Video file representation & caching
├── ocr_worker.rb            # Frame extraction and OCR processing
├── frame.rb                 # Data structure for frame metadata
├── scanner.rb               # Pattern matching for invasion detection
├── clip.rb                  # Video clip generation (ffmpeg)
├── time_helper.rb           # Time manipulation utilities
└── version.rb               # Version constant
```

### Data Flow

```
Video Files → OCRWorker → Frames → Scanner → Segments → Clip → Output Files
     ↓            ↓          ↓         ↓          ↓       ↓
   ffmpeg    Tesseract   Cache(YAML)  Regex   Struct  ffmpeg
```

### Key Classes

#### 1. Engine (`engine.rb`)
- **Responsibility**: Main entry point for video processing
- **Key Methods**:
  - `run!(videos, options)` - Class method to start processing
  - `clips` - Returns array of detected invasion clips
  - `extract_invasion_clips!(prefix, output_dir)` - Generates output files

#### 2. OCRWorker (`ocr_worker.rb`)
- **Responsibility**: Extract frames from video and run OCR
- **Process**:
  1. Uses ffmpeg to extract frames at 2 fps
  2. Crops video to specific region (game text area)
  3. Applies contrast/brightness enhancement
  4. Runs Tesseract OCR in parallel (using all CPU cores)
  5. Returns array of Frame objects
- **Configuration**:
  - Base resolution: 2560x1440
  - Crop region: 700x150 @ 950x965
  - Frame rate: 2 fps (configurable)

#### 3. Video (`video.rb`)
- **Responsibility**: Represents a video file with caching
- **Features**:
  - Caches OCR results to YAML (in `tmp/ocr_cache/`)
  - Uses video filename as cache key
  - Avoids re-processing same video

#### 4. Scanner (`scanner.rb`)
- **Responsibility**: Detects invasion start/end from frame text
- **Pattern Matching**:
  - Start: `/Defeat.*Host of Fingers|Commencing combat/i`
  - End: `/Returning to your world|Combat ends/i`
- **Edge Cases**:
  - Handles invasions starting before first frame (assumes 00:00:00)
  - Handles invasions ending after last frame (uses last frame timestamp)
  - Supports multi-file invasions (when invasion spans video files)

#### 5. Clip (`clip.rb`)
- **Responsibility**: Generates output video clips
- **Features**:
  - Adjusts timestamps (winds back 10s at start, forward 7.5s at end)
  - Supports single-file and multi-file invasions
  - Uses ffmpeg for lossless cutting (copy codec)

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
- **FFmpeg**: Video processing (frame extraction, clip generation)
- **Tesseract OCR**: Text recognition from frames

### Ruby Dependencies
- `rtesseract` (~> 3.1.3): Ruby wrapper for Tesseract
- `parallel` (~> 1.25): Multi-process parallel processing
- `optparse` (~> 0.5): CLI argument parsing

### Development Dependencies
- `minitest` (~> 5.16): Testing framework
- `pry` (~> 0.14): Debugging
- `rake` (~> 13.0): Build tasks

## Testing

Test suite uses Minitest with sample video files:
- `test/samples/invasion-sample-720p.mp4`
- `test/samples/arena-sample-720p.mp4`
- `test/samples/invasion_start.jpg`
- `test/samples/invasion_end.jpg`

Run tests: `rake test` (default task)

## CLI Usage

```bash
bin/invasion_extractor --prefix pyro-invasion --outdir /path/to/output video1.mp4 video2.mp4
```

## Current Limitations

1. **Performance**: Tesseract OCR is CPU-intensive and slow
2. **Language**: Only English is supported (despite config having multi-language structure)
3. **Platform**: Only tested on macOS
4. **Resolution**: Optimized for 2560x1440, may need adjustment for other resolutions
5. **Config Integration**: YAML config exists but isn't wired into the Scanner
6. **No GPU Acceleration**: Current OCR doesn't use GPU
7. **Frame Processing**: Processes all frames, doesn't skip obvious non-matches

## File Structure

```
/
├── bin/
│   ├── invasion_extractor    # CLI executable
│   ├── console               # Interactive console
│   └── setup                 # Setup script
├── lib/
│   └── invasion_extractor/
│       └── [source files]
├── config/
│   └── detection.yml         # Detection patterns config
├── test/
│   ├── test_helper.rb
│   ├── test_engine.rb
│   ├── test_ocr_worker.rb
│   └── samples/              # Test video files
├── tmp/
│   ├── ocr_cache/            # OCR result cache
│   └── [frame images]
├── Gemfile
├── invasion_extractor.gemspec
└── README.md
```

## Version History

- **v0.2.2** (Current): Latest improvements
- **v0.2.0**: Base version with core functionality

## Performance Characteristics

- **Frame Rate**: 2 fps extraction (every 0.5 seconds)
- **Parallelism**: Uses all CPU cores for OCR
- **Caching**: OCR results cached per video file
- **Memory**: Temporary frames stored in `/tmp` during processing
- **I/O**: Heavy file I/O from frame extraction and cleanup

## Known Issues

1. TODO comments indicate unfinished features:
   - Better cache path implementation
   - Test for multi-file clip generation
   - Windows compatibility for ffmpeg calls
   - Integration of YAML config with Scanner

2. Frame processing doesn't skip obviously dark/empty frames

3. No progress indication beyond frame count

## Design Patterns Used

- **Factory**: `Engine.run!` creates instances
- **Strategy**: Clip handles single vs multi-file differently
- **Template Method**: Video loading with cache check
- **Data Transfer Object**: Frame, Segment structs
