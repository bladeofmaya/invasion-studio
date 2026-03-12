# Invasion Extractor - TODO & Architecture Improvements

## Overview

This document outlines proposed architectural improvements, implementation changes, and OCR alternatives to enhance the Invasion Extractor gem. Focus areas include performance optimization, SOLID design principles, and API usability.

---

## High Priority Improvements

### 1. Abstract OCR Interface (Strategy Pattern)

**Problem**: OCR is tightly coupled to Tesseract via `RTesseract` gem.

**Solution**: Create an `OCRProvider` interface with multiple implementations:

```ruby
module InvasionExtractor
  module OCR
    class Provider
      def recognize(image_path)
        raise NotImplementedError
      end
    end
    
    class TesseractProvider < Provider
      # Current implementation
    end
    
    class OllamaProvider < Provider
      # LLM-based vision models
    end
    
    class EasyOCRProvider < Provider
      # Python-based EasyOCR
    end
  end
end
```

**Benefits**:
- Easy to swap OCR backends
- Can benchmark different providers
- Supports both local (Tesseract) and cloud/API (Ollama) options

**Implementation Steps**:
1. Create `lib/invasion_extractor/ocr/provider.rb` (abstract base)
2. Refactor current Tesseract code into `lib/invasion_extractor/ocr/tesseract_provider.rb`
3. Update `OCRWorker` to accept any `OCRProvider`
4. Add configuration option in `detection.yml`

---

### 2. Config System Integration

**Problem**: `config/detection.yml` exists but isn't used by `Scanner`.

**Solution**: Create a proper configuration system:

```ruby
module InvasionExtractor
  class Config
    def self.load(path = 'config/detection.yml')
      # Load and validate YAML
    end
    
    def patterns_for(event_type, language = 'en')
      # Return patterns for invasion_start, invasion_end, etc.
    end
    
    def match_mode(event_type)
      # :exact, :contains, :regex
    end
  end
end
```

**Update Scanner to use Config**:
```ruby
class Scanner
  def initialize(videos, config = Config.load)
    @config = config
  end
  
  def patterns_for(event)
    @config.patterns_for(event, @language)
  end
end
```

**Benefits**:
- Multi-language support
- User-customizable detection patterns
- No code changes needed for new patterns

---

### 3. Frame Pre-filtering

**Problem**: Every frame goes through OCR, even dark/empty ones.

**Solution**: Add brightness/contrast analysis before OCR:

```ruby
class FrameFilter
  BRIGHTNESS_THRESHOLD = 20.0
  
  def self.should_process?(image_path)
    stats = calculate_brightness_stats(image_path)
    stats[:mean] > BRIGHTNESS_THRESHOLD && 
    stats[:std_dev] > 5.0  # Has some variation (not solid color)
  end
  
  private
  
  def self.calculate_brightness_stats(image_path)
    # Use ImageMagick or similar to get mean/std dev
  end
end
```

**Integration in OCRWorker**:
```ruby
def run!
  frames = generate_image_frames
  
  all_frame_data = Parallel.map(frames.each_with_index, in_processes: Etc.nprocessors) do |frame_path, index|
    unless FrameFilter.should_process?(frame_path)
      puts "Skipping frame #{index + 1} (too dark/uniform)"
      next nil
    end
    # ... OCR processing
  end.compact
end
```

**Expected Performance Gain**: 30-50% reduction in OCR calls for typical gameplay footage.

---

### 4. Video Processing Pipeline

**Problem**: `Video` class mixes caching logic with video processing.

**Solution**: Separate concerns with a pipeline pattern:

```ruby
module InvasionExtractor
  class Pipeline
    def initialize(steps)
      @steps = steps
    end
    
    def process(video)
      @steps.reduce(video) do |data, step|
        step.call(data)
      end
    end
  end
  
  class FrameExtractionStep
    def call(video)
      # Extract frames
    end
  end
  
  class OCRStep
    def call(frames)
      # Run OCR
    end
  end
  
  class CacheStep
    def call(frames)
      # Cache results
    end
  end
end
```

**Benefits**:
- Each step is testable in isolation
- Easy to add/remove steps (e.g., add denoising)
- Clear data flow

---

### 5. Progress Reporting

**Problem**: No way to track long-running operations.

**Solution**: Add callbacks/progress reporting:

```ruby
class Engine
  def initialize(videos, options = {}, &progress_callback)
    @progress_callback = progress_callback || ->(event, data) {}
  end
  
  def run!
    @progress_callback.call(:started, { total_videos: @videos.size })
    
    @videos.each_with_index do |video, idx|
      @progress_callback.call(:processing_video, { 
        current: idx + 1, 
        total: @videos.size,
        filename: video.path 
      })
      # ... process
    end
    
    @progress_callback.call(:completed, { clips_found: clips.size })
  end
end
```

**CLI Usage**:
```ruby
engine = InvasionExtractor::Engine.run!(videos, options) do |event, data|
  case event
  when :processing_video
    puts "Processing #{data[:current]}/#{data[:total]}: #{data[:filename]}"
  when :ocr_progress
    puts "OCR: #{data[:current_frame]}/#{data[:total_frames]}"
  end
end
```

---

## OCR Alternatives Research

### Current: Tesseract OCR

**Pros**:
- Mature, widely supported
- Good accuracy for printed text
- No GPU required
- Ruby bindings available (`rtesseract`)

**Cons**:
- CPU-intensive and slow
- Struggles with stylized text
- No GPU acceleration
- Requires image preprocessing for best results

**Performance**: ~1-2 seconds per frame (varies by resolution)

---

### Alternative 1: EasyOCR

**Overview**: PyTorch-based OCR library supporting 80+ languages.

**Pros**:
- GPU acceleration (CUDA)
- Better handling of stylized text
- Good accuracy
- Active development

**Cons**:
- Python-based (requires Python bridge)
- Large model downloads (~100MB)
- Memory intensive
- Not native Ruby

**Performance**: 5-10x faster with GPU than Tesseract CPU

**Integration Options**:
1. **System call**: `python -c "import easyocr; ..."` (slow per-call overhead)
2. **Python service**: Flask/FastAPI service running EasyOCR (HTTP API)
3. **Ruby-Python bridge**: `pycall` gem (requires Python env)

**Recommended Approach**: Python service with HTTP API

```ruby
class EasyOCRProvider < OCRProvider
  def initialize(host: 'localhost', port: 5000)
    @client = Faraday.new("http://#{host}:#{port}")
  end
  
  def recognize(image_path)
    response = @client.post('/ocr', image: File.read(image_path))
    JSON.parse(response.body)['text']
  end
end
```

---

### Alternative 2: PaddleOCR

**Overview**: Baidu's OCR framework with state-of-the-art accuracy.

**Pros**:
- Excellent accuracy
- GPU/CPU support
- Supports 100+ languages
- Document structure understanding

**Cons**:
- Python-based
- Heavy dependencies
- Complex setup
- Overkill for simple text detection

**Performance**: Similar to EasyOCR with GPU

---

### Alternative 3: Ollama Vision Models

**Overview**: LLM-based vision models (LLaVA, etc.) via local Ollama instance.

**Pros**:
- No training needed for specific patterns
- Can understand context
- Single command to extract text: "Extract all visible text"
- Handles stylized text well

**Cons**:
- Requires GPU for reasonable speed
- Higher resource usage
- May hallucinate or add extra text
- More expensive per-inference

**Performance**: 
- CPU: 10-30 seconds per frame (too slow)
- GPU (RTX 3060): 0.5-2 seconds per frame

**Best Use Case**: 
- Pre-filtering: Use Tesseract first, fall back to LLM on uncertain frames
- Complex UI: When text is heavily stylized or embedded in complex graphics

**Integration Example**:

```ruby
class OllamaProvider < OCRProvider
  def initialize(model: 'llava:7b', host: 'localhost:11434')
    @model = model
    @host = host
  end
  
  def recognize(image_path)
    prompt = "Extract ONLY the visible text from this image. Return just the text, nothing else."
    
    response = Faraday.post("http://#{@host}/api/generate", {
      model: @model,
      prompt: prompt,
      images: [Base64.strict_encode64(File.read(image_path))],
      stream: false
    }.to_json, 'Content-Type' => 'application/json')
    
    JSON.parse(response.body)['response'].strip
  end
end
```

---

### Alternative 4: Hybrid Approach (Recommended)

**Strategy**: Combine multiple OCR methods for optimal speed/accuracy:

```ruby
class HybridOCRProvider < OCRProvider
  def initialize
    @fast_provider = TesseractProvider.new(fast_mode: true)
    @accurate_provider = EasyOCRProvider.new  # or OllamaProvider
    @confidence_threshold = 0.7
  end
  
  def recognize(image_path)
    # Try fast method first
    result = @fast_provider.recognize(image_path)
    confidence = calculate_confidence(result)
    
    if confidence < @confidence_threshold
      # Fall back to accurate method
      result = @accurate_provider.recognize(image_path)
    end
    
    result
  end
  
  private
  
  def calculate_confidence(result)
    # Tesseract provides confidence scores
    # or check text length, dictionary words, etc.
  end
end
```

**Benefits**:
- Fast for clear text (Tesseract)
- Accurate for difficult text (EasyOCR/Ollama)
- Cost-effective (only uses expensive OCR when needed)

---

## Medium Priority Improvements

### 6. Frame Sampling Strategy

**Current**: Fixed 2 fps sampling.

**Problem**: Wastes processing on static scenes, misses rapid events.

**Solution**: Adaptive sampling based on scene change detection:

```ruby
class AdaptiveSampler
  def initialize(video, target_fps: 2, min_fps: 0.5, max_fps: 5)
    @video = video
    @target_fps = target_fps
    @min_fps = min_fps
    @max_fps = max_fps
  end
  
  def sample_frames
    # Use ffmpeg scene detection to identify changes
    # Sample more frames around scene changes
    # Sample fewer frames during static scenes
  end
end
```

---

### 7. Multi-threading Improvements

**Current**: `Parallel` gem with process-based parallelism.

**Problems**:
- Process overhead is high
- Memory duplication
- Limited by CPU cores

**Solution**: Add async/threading options:

```ruby
class AsyncOCRWorker
  def initialize(provider, concurrency: 4)
    @provider = provider
    @concurrency = concurrency
    @semaphore = Async::Semaphore.new(concurrency)
  end
  
  def process_frames(frames)
    Async do
      frames.map do |frame|
        @semaphore.async do
          @provider.recognize(frame)
        end
      end.map(&:wait)
    end
  end
end
```

**Benefits**:
- Lower memory overhead
- Better for I/O-bound operations (API calls to Ollama)

---

### 8. Enhanced Cache System

**Current**: Simple YAML file per video.

**Problems**:
- No versioning
- No cache invalidation
- File-based is slow for many videos

**Solution**: Pluggable cache backends:

```ruby
module InvasionExtractor
  module Cache
    class Backend
      def get(key); end
      def set(key, value, ttl: nil); end
      def delete(key); end
    end
    
    class FileBackend < Backend
      # Current implementation
    end
    
    class RedisBackend < Backend
      # For distributed processing
    end
    
    class SQLiteBackend < Backend
      # Better for large datasets
    end
  end
end
```

**Cache Invalidation**:
```ruby
class CacheKey
  def self.for_video(video_path, config_version:)
    content_hash = Digest::MD5.file(video_path).hexdigest
    "#{content_hash}:#{config_version}:#{InvasionExtractor::VERSION}"
  end
end
```

---

### 9. Plugin System

**Allow users to add custom detectors**:

```ruby
module InvasionExtractor
  module Plugins
    class Base
      def detect(frame)
        # Return { event_type: :invasion_start, confidence: 0.95 } or nil
      end
    end
  end
end

# User plugin
class CustomBossDetector < InvasionExtractor::Plugins::Base
  def detect(frame)
    if frame.text.include?("BOSS DEFEATED")
      { event_type: :boss_defeated, confidence: 1.0 }
    end
  end
end

# Usage
engine = InvasionExtractor::Engine.run!(videos, plugins: [CustomBossDetector.new])
```

---

## Low Priority / Future Improvements

### 10. GPU Acceleration for FFmpeg

Use GPU-accelerated video decoding/encoding:

```bash
# NVIDIA
ffmpeg -hwaccel cuda -i input.mp4 ...

# AMD
ffmpeg -hwaccel vaapi -i input.mp4 ...

# Apple Silicon
ffmpeg -hwaccel videotoolbox -i input.mp4 ...
```

---

### 11. Stream Processing

Process video without extracting all frames to disk:

```ruby
class StreamingOCRWorker
  def run!
    # Use ffmpeg to pipe frames directly to OCR
    # No disk I/O for frames
  end
end
```

---

### 12. Web Interface

Optional web UI for monitoring and manual review:

```ruby
# Add to gemspec as optional dependency
spec.add_development_dependency "sinatra", "~> 3.0"

# invasion_extractor web --port 4567
```

---

## Recommended Migration Path

### Phase 1: Foundation (Week 1-2)
1. ✅ Implement OCR Provider interface
2. ✅ Refactor Tesseract into provider
3. ✅ Add FrameFilter for brightness checking
4. ✅ Integrate config system with Scanner

### Phase 2: Performance (Week 3-4)
5. ✅ Implement EasyOCR provider with Python service
6. ✅ Add HybridOCRProvider
7. ✅ Benchmark and optimize

### Phase 3: Polish (Week 5-6)
8. ✅ Add progress callbacks
9. ✅ Improve cache system
10. ✅ Enhanced error handling

---

## Performance Benchmarks (Target)

| Method | Time per 60min video | Accuracy | Setup Complexity |
|--------|---------------------|----------|------------------|
| Tesseract (current) | 15-30 min | 85% | Easy |
| Tesseract + FrameFilter | 10-20 min | 85% | Easy |
| EasyOCR (GPU) | 2-5 min | 92% | Medium |
| Hybrid (Tesseract + EasyOCR) | 3-8 min | 95% | Medium |
| Ollama (GPU) | 10-20 min | 90% | Hard |

---

## SOLID Principles Checklist

- **S**ingle Responsibility: Each class has one reason to change ✅
- **O**pen/Closed: New OCR providers without modifying existing code ✅
- **L**iskov Substitution: All OCR providers interchangeable ✅
- **I**nterface Segregation: Small, focused interfaces ✅
- **D**ependency Inversion: High-level modules don't depend on low-level details ✅

---

## API Design Goals

### Simple Usage (Current)
```ruby
engine = InvasionExtractor::Engine.run!(videos)
engine.extract_invasion_clips!("prefix", "/output")
```

### Advanced Usage (Proposed)
```ruby
config = InvasionExtractor::Config.load('custom.yml')
provider = InvasionExtractor::OCR::HybridProvider.new(
  fast: InvasionExtractor::OCR::TesseractProvider.new,
  accurate: InvasionExtractor::OCR::EasyOCRProvider.new(gpu: true)
)

engine = InvasionExtractor::Engine.new(videos, 
  config: config,
  ocr_provider: provider,
  cache_backend: InvasionExtractor::Cache::RedisBackend.new
) do |event, data|
  puts "#{event}: #{data}"
end

engine.run!
engine.extract_invasion_clips!("prefix", "/output")
```

Both APIs should work side-by-side with sensible defaults.
