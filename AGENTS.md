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
│   ├── extract.rb           # Extract/scan command implementation
│   └── export_kdenlive.rb   # Kdenlive timeline export command
├── kdenlive_exporter.rb     # Kdenlive MLT XML project generator
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

### WebUI Components

```
lib/invasion_extractor/webui/
├── server.rb                # Sinatra app, API routes, static file serving
├── views/
│   ├── index.erb            # Main page layout (import map, controller wrapper)
│   ├── _header.erb          # Tab navigation (All Clips / Groups), back button
│   ├── _clip_panel.erb      # Clip list, filter dropdown, group grid, export controls
│   ├── _preview_panel.erb   # Editor + video player wrapper
│   ├── _editor.erb          # Title, note, rating, result, delete/restore
│   └── _video_controls.erb # Audio track, file link, cut markers, timeline
├── public/
│   ├── app.css              # Styling
│   ├── stimulus.js          # Stimulus bootstrap (imports + registers all controllers)
│   └── controllers/
│       ├── application_controller.js    # Base class with shared utilities (getNavState, resetEditor, escapeHtml, formatDuration)
│       ├── video_player_controller.js   # Video playback, audio track switching, cut management
│       ├── editor_controller.js           # Title, note, rating, result CRUD
│       ├── clip_list_controller.js       # Clip list rendering, filtering, drag-sort, group assignment, export
│       ├── navigation_controller.js       # Tab switching, view management, visibility control
│       └── group_manager_controller.js   # Group grid, create, rename, delete, inline rename
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

#### 7. KdenliveExporter (`kdenlive_exporter.rb`)
- **Responsibility**: Two-step export: splices clips into a single video, then generates a Kdenlive 26.04 `.kdenlive` project file
- **Process**:
  1. Discovers video files in the target folder (filtered by extension)
  2. Sorts clips alphabetically by filename
  3. Splices all clips into a single `combined.mp4` using ffmpeg concat (lossless, `-c copy`)
  4. Uses `ffprobe` (via `Video#metadata`) to gather duration, resolution, and fps for the spliced video
  5. Generates a Kdenlive 26.04-compatible MLT XML with the spliced video on the timeline:
     - 6 chain definitions for the single video (5 for timeline tracks + 1 for project bin)
     - 6 timeline track tractors (4 audio + 2 video) with proper filter structure
     - Sequence tractor with UUID-as-ID and internal transitions
     - `main_bin` with document properties, categories, and bin entries
     - Project tractor referencing the sequence
  6. Writes the project file to disk (overwrites if exists)
- **Output**: 
  - `combined.mp4` — spliced video in the input folder
  - `timeline.kdenlive` — Kdenlive 26.04+ compatible MLT XML
- **Design**: Self-contained class with no dependencies beyond existing `Video` metadata helper

#### 8. OCR Providers (`ocr/`)
- **Provider (Base)**: Abstract interface with `recognize(image_path)`
- **TesseractProvider**: Default, uses RTesseract gem

### WebUI Architecture

The WebUI is a single-page application built with **Sinatra** and **Stimulus.js** (Hotwire stack). It uses an import map to load `@hotwired/stimulus` from CDN. No build step (esbuild, webpack) is required.

#### Server (`server.rb`)
- **Responsibility**: Sinatra API and static file serving
- **Routes**:
  - `GET /` — Renders the main page with embedded ERB partials
  - `GET /api/clips` — Returns clips (with optional group/all/deleted filters)
  - `GET /api/clip/:id` — Returns a single clip's metadata
  - `POST /api/clip/:id/open` — Opens the clip file in the system's default video player
  - `DELETE /api/clip/:id` — Deletes (moves to trash) or restores a clip
  - `POST /api/reorder` — Reorders clips within a group (drag-and-drop)
  - `POST /api/note` — Updates a clip's note
  - `POST /api/rating` — Updates a clip's rating (1-5 stars)
  - `POST /api/result` — Updates a clip's result (win/loss/dc/none)
  - `POST /api/title` — Updates a clip's title
  - `POST /api/cuts` — Updates a clip's cut markers
  - `GET /api/groups` — Returns all groups
  - `GET /api/groups/stats` — Returns group statistics (clip count, total duration)
  - `POST /api/groups` — Creates a new group
  - `POST /api/groups/rename` — Renames a group
  - `DELETE /api/groups/:name` — Deletes a group
  - `POST /api/group/:name/add` — Adds a clip to a group
  - `POST /api/group/:name/remove` — Removes a clip from a group
  - `POST /api/export` — Exports a group to spliced video + Kdenlive project
  - `GET /clip/:filename` — Serves a clip video (with optional audio track selection)
- **Design**: Stateless API with a `Project` instance holding data; all mutations return JSON

#### Stimulus Controllers

All controllers extend `ApplicationController` (base class with shared utilities).

**1. `navigation` controller (orchestrates the app shell)**
- **Targets**: `tab`, `backBtn`, `groupGrid`, `previewPanel`, `newGroupCard`, `newGroupForm`
- **Values**: `currentView` (all/groups/group-detail), `selectedGroup`
- **Actions**: `switchView`, `goBack`, `openGroup`
- **Responsibilities**:
  - Tab switching (All Clips / Groups)
  - Back button navigation (group-detail → groups)
  - Active tab styling
  - Visibility control for all regions (group-grid, preview-panel, etc.)
  - Clip-list sync when view changes
  - Editor reset on view change
  - `editor:refresh` event listener (handles deleted/restored clip refresh)

**2. `clip-list` controller (manages the clip list panel)**
- **Targets**: `container`, `panelTitle`, `filterDropdown`, `filterSelect`, `groupExport`
- **Values**: `view`, `filter`, `group`, `selectedClipId`
- **Actions**: `setFilter`, `selectClip`, `exportGroup`, `reorderClip`, `restoreClip`, `addToGroup`, `removeFromGroup`
- **Responsibilities**:
  - Fetches and renders clips from `/api/clips`
  - Filtering (everything, unassigned, assigned, deleted)
  - Selection management (updates selected class, triggers video-player + editor)
  - Drag-and-drop reordering in group detail view
  - Group assignment (with inline new group creation)
  - Export group to spliced video + Kdenlive project
  - Panel title and visibility updates

**3. `editor` controller (manages the clip editor panel)**
- **Targets**: `titleInput`, `noteInput`, `ratingContainer`, `resultContainer`, `deleteBtn`, `restoreBtn`, `saveStatus`
- **Values**: `clipId`
- **Actions**: `saveTitle`, `saveNote`, `setRating`, `setResult`, `deleteClip`, `restoreClip`
- **Responsibilities**:
  - Title/note auto-save on blur
  - Star rating clicks (reads `data-value` from clicked star)
  - Result toggle (win/loss/dc/none) via radio button change events
  - Delete/Restore buttons with confirmation
  - Save status with auto-clear timeout
  - Dispatches `editor:refresh` events after saves/deletes/restores

**4. `video-player` controller (manages the video preview)**
- **Targets**: `videoWrapper`, `controls`, `audioTrack`, `filename`, `timeline`, `cutList`
- **Values**: `clipId`, `src`, `cuts`
- **Actions**: `changeAudioTrack`, `openFile`, `markCutStart`, `markCutEnd`, `clearCuts`, `deleteCut`
- **Responsibilities**:
  - Video loading with audio track switching (preserves playback time)
  - Cut marking (start/end) and deletion
  - Cut timeline rendering overlaid on a progress bar
  - Server persistence of cuts via `/api/cuts`
  - File opening in external player
  - Status dispatching (custom events for save status)

**5. `group-manager` controller (manages the group grid)**
- **Targets**: `grid`, `newGroupCard`, `newGroupForm`, `newGroupInput`
- **Actions**: `showNewGroupForm`, `cancelNewGroupForm`, `createGroup`, `handleNewGroupKeydown`, `deleteGroup`, `startRename`, `doRename`
- **Responsibilities**:
  - Fetches and renders group grid from `/api/groups` and `/api/groups/stats`
  - Inline rename form with Enter/Escape key handling
  - New group creation with inline form
  - Group deletion with confirmation
  - Group rename with navigation sync (updates selected group name if currently open)
  - Group opening (dispatches to `navigation` controller via dataset value changes)
  - `groups:refresh` and `nav:changed` event listeners

#### Communication Pattern
- **Custom events** for cross-controller communication:
  - `editor:refresh` — Editor triggers after save/delete/restore; `navigation` listens to refresh clip list
  - `groups:refresh` — Any controller triggers after group mutation; `group-manager` listens to re-render
  - `nav:changed` — Navigation triggers on view change; `group-manager` and `clip-list` listen
  - `clip-list:refresh` — Any controller triggers; `clip-list` listens to re-fetch and render

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
- `test/test_kdenlive_exporter.rb` - Kdenlive exporter (splice + project generation) tests
- `test/test_concat.rb` - Concat command tests

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

# Export clips folder to Kdenlive project
bin/invasion_extractor export-kdenlive ~/Videos/ER/clips

# Export with custom output path and transition duration
bin/invasion_extractor export-kdenlive -o ~/Videos/ER/project.kdenlive -t 3.0 ~/Videos/ER/clips

# Concatenate clips into a single video (no re-encoding, with chapter markers)
bin/invasion_extractor concat ~/Videos/ER/clips

# Concat with custom output
bin/invasion_extractor concat -o ~/Videos/ER/final.mp4 ~/Videos/ER/clips
```

### CLI Options

#### Extract/Scan Options
- `-p, --prefix PREFIX` - Output file prefix (default: invasion)
- `-o, --outdir DIRECTORY` - Output directory (default: ./invasion_clips)
- `--fps RATE` - Frame extraction rate (default: 2)
- `--no-cache` - Skip OCR cache, force re-processing
- `--pad-start SECONDS` - Seconds before invasion (default: 10)
- `--pad-end SECONDS` - Seconds after invasion (default: 7.5)
- `--continue-on-error` - Continue processing remaining videos if one fails
- `-d, --debug` - Enable debug output (writes frame text to YAML)
- `-q, --quiet` - Suppress non-error output

#### Export-Kdenlive Options
- `-o, --output FILE` - Output `.kdenlive` file path (default: `./timeline.kdenlive` in the input folder). Also generates `combined.mp4` (spliced video) in the input folder.

#### Concat Options
- `-o, --output FILE` - Output video file path (default: `./combined.mp4` in the input folder). Output includes chapter markers for each clip, visible in video players and editors that support MP4 chapters (e.g., VLC, mpv, DaVinci Resolve).

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
│       │   ├── concat.rb
│       │   ├── extract.rb
│       │   └── export_kdenlive.rb
│       ├── kdenlive_exporter.rb
│       ├── ocr/
│       │   ├── provider.rb
│       │   └── tesseract_provider.rb
│       └── webui/           # WebUI components
│           ├── server.rb
│           ├── views/
│           │   ├── index.erb
│           │   ├── _header.erb
│           │   ├── _clip_panel.erb
│           │   ├── _preview_panel.erb
│           │   ├── _editor.erb
│           │   └── _video_controls.erb
│           └── public/
│               ├── app.css
│               ├── stimulus.js
│               └── controllers/
│                   ├── application_controller.js
│                   ├── video_player_controller.js
│                   ├── editor_controller.js
│                   ├── clip_list_controller.js
│                   ├── navigation_controller.js
│                   └── group_manager_controller.js
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
- **Command**: CLI command pattern (extract, scan, export-kdenlive, concat)
