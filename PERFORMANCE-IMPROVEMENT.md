# Performance Improvement Plan

## Context

A 1-hour 2K video takes ~30 minutes to process:
- ~5 min: frame extraction (ffmpeg → 7,200 JPEGs @ 2 fps)
- ~25 min: OCR (Parallel.map forks workers, each frame spawns `tesseract` CLI via `rtesseract` gem)

**Root cause:** `RTesseract` shells out to `tesseract` CLI once per frame. Tesseract boot time (~150–250 ms) dominates actual LSTM inference (~20–50 ms). ~80% of OCR time is process-spawn and Ruby `Open3` overhead, not text recognition.

---

## Improvement Table

| # | Improvement | Est. Impact | Effort | New Dependencies | Risks | Implementation Notes |
|---|-------------|-------------|--------|-----------------|-------|---------------------|
| **1** | **Lower default fps: 2 → 1** | **~2× total time** (~30 min → ~15 min) | 1 line | None | Invasion banners linger several seconds, so 1 fps is safe. Edge case: very brief events could be missed. Mitigation: already handled by padding. | Change default in `lib/invasion_extractor/engine.rb` or wherever `@options[:fps]` defaults. Add `ponytail:` comment noting the ceiling. |
| **2** | **Tesseract char whitelist + OEM mode** | **~20–40% OCR time reduction** | 1 line | None | Could miss non-ASCII characters, but Elden Ring UI text is strictly Latin. | Pass `tessedit_char_whitelist=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ` and `oem: 1` to `RTesseract`. In `lib/invasion_extractor/ocr/tesseract_provider.rb`, update `@options` hash. |
| **3** | **Pipeline extraction → OCR** (start OCR as soon as first frames are ready) | **Hides ~5 min extraction** inside OCR window | Low | None | Requires careful temp file lifecycle. Consumer may start before producer finishes. | In `OCRWorker#run!`, replace the two sequential stages with a producer-consumer pattern: ffmpeg writes frames; as soon as a frame file appears, a consumer thread submits it to the parallel pool. `Parallel.map` over a lazy enumerator fed by a `SizedQueue`. |
| **4** | **Eliminate persistent JPEG frame cache** | **Cuts disk I/O and JPEG encode/decode** | Low | None | None — the YAML cache at the video level already prevents re-processing. | Remove `frames_dir` persistence in `OCRWorker`. Extract frames to a temporary directory that is cleaned up immediately after OCR. Or better: extract to raw PGM via ffmpeg pipe and feed directly to OCR (see original architecture in `AGENTS.md`). This is a revert toward the designed rawvideo pipeline. |
| **5** | **Batch frames into multi-page TIFF** | **~5–10× OCR speed** (7,200 individual spawns → ~150 batches of 50) | Medium | Platform tool: `tiffcp` or ImageMagick (often pre-installed) | TIFF construction adds a small per-batch overhead. Error handling is coarser (one bad frame in a TIFF batch fails the whole batch). | Use `tiffcp` or ImageMagick to concatenate N extracted JPEGs into a single multi-page TIFF. Call `tesseract` once per TIFF. Parse the output delimited by `\f` (form feed) to split results per frame. Implement in `OCRWorker` or as a new `BatchOCRProvider`. |
| **6** | **Replace `rtesseract` with `tesseract-ocr` FFI gem** | **~5–10× OCR speed** | Medium | `tesseract-ocr` gem | FFI binding must match system tesseract version. Slightly more complex setup. | Use the `tesseract-ocr` Ruby gem (FFI bindings to libtesseract). Initialize one `Tesseract::Engine` per worker process in `Parallel.map` setup. Call `engine.text_for(image_path)` per frame — no CLI spawn, shared engine state. Requires updating `Gemfile` and `invasion_extractor.gemspec`. |
| **7** | **Adaptive two-pass scan** | **~3–4× typical** | High | None | Complex state machine. Harder to debug. Risk of edge cases around invasion boundaries. | Pass 1: extract at 0.25 fps, run OCR to find rough invasion windows. Pass 2: extract at 2 fps only in the ±30 s windows around Pass 1 hits. Only worth it if #1–#6 are insufficient. |
| **8** | **Parallelize at video level instead of frame level** | Scales with number of videos | Low | None | Only helps when multiple videos are passed in one invocation. Does not help single-video processing. | Move `Parallel.each` around `@videos.each` in `Engine#run_ocr_stage` instead of inside `OCRWorker`. Keep frame-level parallelism as fallback for single-video runs. |

---

## Priority Order

### Phase 1: Zero-cost wins (do immediately)

1. **#1 Lower fps to 1** — 1 line, 2× speedup, no risk.
2. **#2 Char whitelist + OEM mode** — 1 line, 20–40% OCR reduction.
3. **#3 Pipeline extraction → OCR** — overlaps I/O and CPU, hides the 5 min extraction.
4. **#4 Remove persistent JPEG cache** — reduces disk churn; reverts to rawvideo pipe design.

**Expected combined result:** ~30 min → **8–12 min** for a 1-hour video.

### Phase 2: Big win if Phase 1 is insufficient

Choose **ONE** of:
- **#5 Batch TIFF** — no new Ruby dependencies, leverages existing tesseract binary.
- **#6 FFI gem** — cleaner architecture, but adds a gem dependency.

Either should drop OCR from ~10 min → **1–2 min**, bringing total time to **~5 min**.

### Phase 3: Only if still too slow

- **#7 Adaptive two-pass** — last resort, high complexity.
- **#8 Video-level parallelism** — only relevant for batch jobs with multiple videos.

---

## Technical Details for Implementation

### Relevant Files

- `lib/invasion_extractor/ocr_worker.rb` — frame extraction, `Parallel.map` OCR loop
- `lib/invasion_extractor/ocr/tesseract_provider.rb` — tesseract options (whitelist, OEM)
- `lib/invasion_extractor/engine.rb` — orchestrates stages, sets default fps
- `lib/invasion_extractor/video.rb` — loads frames, uses YAML cache
- `invasion_extractor.gemspec` — dependency declarations

### Key Bottleneck Locations

1. **Per-frame CLI spawn** (`ocr_worker.rb:45-55`): `Parallel.map` over frame paths → each calls `@ocr_provider.recognize(path)` → `RTesseract.new(...).to_s.strip` → `Open3.capture3("tesseract", ...)`.
2. **Sequential staging** (`engine.rb:36-51`): `run_ocr_stage` does extraction for the *entire* video, then OCR for the *entire* video. No overlap.
3. **Disk-persistent JPEGs** (`ocr_worker.rb:66-76`): `ensure_frames_dir` writes to `~/.invasion_extractor/cache/frames/<hash>/`. These are never reused because `Video#load_frames` caches at the YAML level, not the JPEG level.

### Tesseract Command Overhead Evidence

For a 700×130 image:
- `tesseract` CLI cold start: ~150–250 ms
- Actual LSTM inference: ~20–50 ms
- Ruby `RTesseract` + `Open3` overhead: additional ~30–50 ms
- **Total per frame: ~250–350 ms**
- **For 7,200 frames: ~30–42 min of pure overhead**

Batching 50 frames into one TIFF:
- One `tesseract` spawn: ~200 ms
- 50 frames inference: ~50 × 30 ms = ~1,500 ms
- **Total per batch: ~1,700 ms**
- **For 144 batches: ~4 min**

### Data Points

- 1-hour video @ 2 fps = 7,200 frames
- 1-hour video @ 1 fps = 3,600 frames
- Crop region: 700×130 (scaled by video height / 1440)
- Current `Parallel.map` processes: `Etc.nprocessors` (number of CPU cores)
- `tesseract` version in environment: **5.5.2** (supports LSTM engine, multi-page TIFF, and char whitelist)

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| **Phase 1 before Phase 2** | Phase 1 changes are deletions and one-liners. Phase 2 changes introduce complexity or dependencies. Lazy principle: fewest files possible. |
| **Prefer batch TIFF over FFI gem** | If choosing one big win, batch TIFF requires no new Ruby gem (use system `tiffcp`/`convert`). FFI gem is architecturally cleaner but violates "no new dependency if it can be avoided." |
| **Do not implement adaptive two-pass** | Too clever, too much state, too many edge cases. Only if all else fails. |
| **Keep YAML cache, delete JPEG cache** | YAML cache prevents re-processing entire videos. JPEG cache is redundant and I/O-heavy. |

---

## Success Metrics

After Phase 1:
- 1-hour 2K video processes in **< 15 minutes**.

After Phase 2 (if implemented):
- 1-hour 2K video processes in **< 5 minutes**.

Test with: `test/samples/invasion-sample-full.mp4` (3.3 GB, full-length capture).
