# Invasion Extractor - Development Roadmap

## 1. GPU Acceleration

### 1.1 FFmpeg GPU Frame Extraction
- Add NVENC/VAAPI support for faster frame extraction
- Detect available GPU (NVIDIA/AMD/Intel) and use appropriate codec
- Benchmark: Current CPU extraction ~6-7s for 3.5min video, target <3s with GPU

### 1.2 GPU-Based OCR Providers
- **EasyOCR Provider**: Python-based with CUDA support (much faster than Tesseract)
- **ONNX Runtime Provider**: For lightweight GPU inference
- Performance target: <0.05s per frame on GPU vs 0.18s CPU

### 1.3 Ollama GPU Optimization
- Ensure llava runs on GPU (verify via `ollama ps`)
- Add batch processing for multiple frames per API call
- Currently ~19s/frame, target <2s with proper GPU batching

## 2. Frame Pre-filtering (30-50% Speedup)

### 2.1 Brightness/Edge Detection
```ruby
def should_process_frame?(frame_path)
  brightness = calculate_brightness(frame_path)
  edge_density = detect_edges(frame_path)
  brightness > 20 && edge_density > 0.1  # Skip dark/blurry frames
end
```

### 2.2 Quick Text Presence Check
- Use simple threshold + contour detection before full OCR
- Skip 60-70% of frames that clearly contain no text
- Estimated savings: Process 200 frames instead of 422 for 3.5min video

## 3. Progress Callbacks & CLI Feedback

### 3.1 Progress Reporting
```ruby
engine.extract_invasion_clips!('prefix', './output') do |event, current, total|
  case event
  when :extracting_frames then puts "Extracting: #{current}/#{total}"
  when :processing_ocr then puts "OCR: #{current}/#{total}"
  when :generating_clip then puts "Clip #{current}/#{total}"
  end
end
```

### 3.2 Progress Bar Integration
- Add `ruby-progressbar` gem for visual feedback
- Show ETA based on processing speed
- Essential for long videos (30+ minutes)

## 4. Multi-Language Support

### 4.1 Config Integration
- Integrate `config/detection.yml` into `Scanner` class
- Support: English (en), Japanese (jp), German (de), French (fr), etc.
- Allow CLI flag: `--language jp`

### 4.2 Language-Specific OCR
- Load appropriate Tesseract language packs
- Provider selection per language
- Fallback chain: Configured -> English -> Skip

## 5. Smart Crop Regions

### 5.1 Dynamic UI Detection
- Detect UI position based on aspect ratio
- Support: 16:9, 21:9 ultrawide, 32:9 super-ultrawide
- Auto-adjust crop coordinates

### 5.2 Multi-Region Scanning
- Scan multiple regions simultaneously (top, bottom, corners)
- Handle Elden Ring UI position variations
- Combine results from multiple crops

## 6. Error Handling & Resilience

### 6.1 Fault-Tolerant Processing
- Skip corrupt frames without crashing
- Retry failed OCR attempts (3x with backoff)
- Handle partial video files gracefully

### 6.2 Validation
- Verify ffmpeg commands succeed
- Check output file integrity after generation
- Warn on suspicious clip durations (<5s or >600s)

## 7. Cache Enhancements

### 7.1 Cache Versioning
```ruby
def cache_key
  "#{file_path}:#{File.mtime(file_path).to_i}:#{CACHE_VERSION}"
end
```
- Increment `CACHE_VERSION` on algorithm changes
- Auto-invalidate stale caches

### 7.2 Selective Cache Invalidation
- Cache invalidation per video
- Force refresh option: `--no-cache`

## 8. Refactorings

### 8.1 OCRWorker - Separate Concerns
Split into focused classes:
- `FrameExtractor`: FFmpeg operations only
- `FrameProcessor`: OCR + pre-filtering
- `FrameCleaner`: Temp file lifecycle management

### 8.2 Scanner - Strategy Pattern
```ruby
class InvasionDetector
  def detect(frames); end
end

class RegexDetector < InvasionDetector     # Current
class MLDetector < InvasionDetector        # Future ML model
class FuzzyDetector < InvasionDetector     # Levenshtein matching
```

### 8.3 Clip - Template Method Pattern
```ruby
class ClipGenerator
  def generate(segment, output); end
  def validate!(segment); end
end

class SingleFileGenerator < ClipGenerator
class MultiFileGenerator < ClipGenerator
```

## 9. Missing Tests

### 9.1 Scanner Tests (Critical Gap!)
- `test_invasion_spans_multiple_videos`: Edge case handling
- `test_no_invasions_detected`: Empty result handling
- `test_multiple_invasions_same_video`: 3+ invasions in one file
- `test_overlapping_invasions`: Malformed timestamp handling

### 9.2 Clip Tests (Critical Gap!)
- `test_single_file_clip_generation`: Verify ffmpeg command
- `test_multi_file_clip_generation`: TODO in code - needs implementation
- `test_clip_file_exists_check`: Skip existing files
- `test_invalid_timestamp_handling`: Graceful degradation

### 9.3 OCRWorker Tests
- `test_frame_pre_filtering`: Skip dark frames
- `test_parallel_processing`: Verify thread safety
- `test_cleanup_on_error`: Temp files removed on crash
- `test_different_resolutions`: 720p, 1080p, 1440p, 4K

### 9.4 Provider Tests
- `test_ollama_provider_mock`: HTTP response mocking
- `test_provider_timeout_handling`: 30s timeout enforcement
- `test_fallback_mechanism`: Tesseract -> Ollama fallback

## 10. Advanced Features

### 10.1 Hybrid Provider Strategy
```ruby
class HybridProvider < Provider
  def recognize(image_path)
    result = tesseract.recognize(image_path)
    return result if confidence_high?(result)
    ollama.recognize(image_path)  # Fallback for low confidence
  end
end
```

### 10.2 Adaptive Frame Rate
```ruby
def optimal_fps(duration)
  return 4 if duration < 300    # <5min: 4 fps
  return 2 if duration < 1800   # 5-30min: 2 fps
  1                              # >30min: 1 fps
end
```

### 10.3 Invasion Metadata Export
- Export JSON/YAML with timestamps, durations, confidence scores
- Useful for video editors and manual review
- Example: `invasion_metadata_2024-03-12.json`

### 10.4 Duplicate Detection
- Compare clip fingerprints to avoid duplicates
- Hash-based detection for similar invasions

## 11. Code Quality

### 11.1 Type Signatures
- Add RBS or Sorbet type definitions
- Better IDE support and catching type errors early

### 11.2 Structured Logging
Replace `puts` with proper logging:
```ruby
logger.info "Processing frame #{index}"
logger.debug "OCR result: #{text}"
logger.warn "Low confidence detection: #{text}"
```

### 11.3 Configuration Validation
- Validate config on startup
- Check for required binaries (ffmpeg, tesseract)
- Provide helpful error messages for missing dependencies

### 11.4 RuboCop Integration
- Add `.rubocop.yml` for consistent style
- Enforce naming conventions
- Auto-format with `rubocop -a`

## Priority Matrix

| Priority | Feature | Impact | Effort | Owner |
|----------|---------|--------|--------|-------|
| P0 | Frame Pre-filtering | High | Low | - |
| P0 | Scanner Tests | High | Low | - |
| P1 | Progress Callbacks | High | Low | - |
| P1 | GPU FFmpeg | High | Medium | - |
| P2 | Multi-language | Medium | Medium | - |
| P2 | Smart Crop | Medium | Medium | - |
| P3 | Hybrid Provider | Medium | High | - |
| P3 | Adaptive FPS | Low | Low | - |

## Current Benchmarks

| Method | Avg Time/Frame | 60min Video | Accuracy |
|--------|---------------|-------------|----------|
| Tesseract (current) | 0.18s | ~30-60s | ~50% |
| Tesseract + pre-filter | ~0.09s | ~15-30s | ~50% |
| Ollama (llava:7b) | 18.8s | ~6-8 hours | ~50% |
| Target (EasyOCR GPU) | <0.05s | <10s | ~70% |

---

*Last updated: Post-benchmark - Ollama 103x slower than Tesseract*
