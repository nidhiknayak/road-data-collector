# Road Data Collector

A Flutter-based Android application developed as part of an **M.Tech research project at PES University** for synchronized multimodal road condition data collection.

The application records **rear camera video**, **GPS data**, and **IMU sensor data** simultaneously using a shared timestamp, enabling the creation of high-quality datasets for road condition analysis and machine learning.

---

# Features

- 📹 Rear camera video recording
- 📍 GPS data logging
- 📱 IMU (Accelerometer, Gyroscope & Magnetometer) logging
- ⏱ Shared synchronized timestamps across all sensors
- 📂 Automatic recording session management
- 📄 Metadata generation for every session
- 🗺️ Color-coded road quality map (green/yellow/orange/red, averaged every 250m)
- 📊 GPS/IMU/video correlation viewer, with automatic pothole flagging per time bucket
- 🕳️ IMU-based pothole candidate detection, for building a labeled CV training dataset
- 🎥 Video playback
- 📋 Session browser
- 📤 Share recorded sessions
- 🗑 Delete recorded sessions

---

# Project Objective

The goal of this application is to collect synchronized multimodal road data that can later be used for:

- Road quality analysis
- Road smoothness estimation
- Machine learning
- Computer vision research (pothole detection)
- Intelligent transportation research

The long-term goal is a live, on-device road quality overlay (similar to traffic-condition overlays in consumer map apps), fusing computer vision (pothole detection) with IMU roughness signal. The app is currently in the **data collection phase** of that pipeline — see [Road Quality Pipeline](#road-quality-pipeline) below.

---

# Architecture

```text
RecordingPage

	|
	v

CollectionService

	|
	+-- RecordingService
	+-- CameraService
	+-- GpsService
	+-- GpsLogger
	+-- ImuService
	+-- ImuLogger
	+-- SessionClock

SessionDetailsPage

	|
	+-- RoadQualityService      -> RoadQualityMapWidget
	+-- CorrelationService      -> CorrelationViewerPage
	+-- PotholeSpikeFinder      -> spike_timestamps.json
	+-- ExportService
	+-- SessionDeleteService
```

The `CollectionService` coordinates all sensors to ensure synchronized recording. Post-recording analysis (road quality, correlation, pothole candidates) is handled by separate services run on-demand from the Session Details screen, and does not touch the recording path.

---

# Recording Workflow

```text
User presses Start Recording

	|
	v

CollectionService

	|
	+-- Starts SessionClock
	+-- Starts Camera Recording (if enabled in Settings)
	+-- Starts GPS Logging
	+-- Starts IMU Logging
```

When recording stops:

```text
Stop Recording

	|
	v

Stop Camera
Stop GPS Logger
Stop IMU Logger
Write metadata.json
Save Session
```

Camera recording can be disabled in Settings, in which case only GPS + IMU are logged (no `video.mp4`).

---

# Synchronization

A shared `SessionClock` is used throughout the application.

Every GPS sample and IMU sample is timestamped using the same elapsed time, ensuring synchronization between:

- Video
- GPS
- IMU

---

# Session Structure

Each recording creates a dedicated session folder.

Example:

```text
Session_20260910_164500/

	|
	+-- video.mp4              (only if camera was enabled)
	+-- gps.csv
	+-- imu.csv
	+-- metadata.json
	+-- correlation.json       (generated on-demand, requires video)
	+-- spike_timestamps.json  (generated on-demand, from IMU spike scan)
	+-- candidates/            (generated offline, see below)
```

---

# GPS Logging

GPS data is continuously logged into `gps.csv`.

Columns:

```text
elapsed_ms
latitude
longitude
altitude
speed
speed_accuracy
heading
accuracy
```

---

# IMU Logging

IMU data is stored in `imu.csv`.

Columns:

```text
elapsed_ms
ax, ay, az   (accelerometer)
gx, gy, gz   (gyroscope)
mx, my, mz   (magnetometer)
```

---

# Metadata

Each session generates a `metadata.json` file containing:

- Session ID
- Start time / end time
- Duration
- Video / GPS / IMU filenames
- Camera start offset (ms) - used to align video time against GPS/IMU elapsed time

---

# Road Quality Pipeline

The app is building toward a live, color-coded road quality overlay. Current pieces, in order of the pipeline:

## 1. Road quality map (done)

`RoadQualityService` splits a session's GPS route into ~250m segments and averages accelerometer deviation-from-gravity within each segment. `RoadQualityMapWidget` renders the route on an OpenStreetMap-tiled map, with each segment colored by quality:

- Green - good
- Yellow - moderately good
- Orange - moderately bad
- Red - bad

The roughness thresholds used to classify segments (`RoadQualityService.goodThreshold` etc.) are first-pass estimates, not yet calibrated against real driving data. They will need tuning once a labeled dataset exists (see below).

## 2. GPS/IMU/video correlation (done)

`CorrelationService` buckets GPS + IMU data against video time (500ms buckets) and flags buckets where accelerometer deviation exceeds a threshold as a likely pothole. Viewable in-app via `CorrelationViewerPage` from Session Details.

## 3. Pothole candidate detection for dataset building (in progress)

`PotholeSpikeFinder` scans a session's `imu.csv` for accelerometer spikes and writes their timestamps to `spike_timestamps.json`. This identifies *candidate* moments worth reviewing for potholes - not a detector itself, just a fast way to avoid manually scrubbing through hours of video.

Actual frame extraction happens **offline**, on a development machine, via `scripts/extract_candidates.py`:

```bash
python scripts/extract_candidates.py "path/to/Session_YYYYMMDD_HHMMSS"
```

This reads `spike_timestamps.json` and `metadata.json` from the session folder, and uses a system-installed `ffmpeg` to pull the corresponding video frame for each candidate timestamp into a `candidates/` subfolder. These frames are then manually labeled (pothole / not-pothole) to build a training dataset for a future on-device CV model.

Frame extraction is intentionally **not** done in-app - `ffmpeg_kit_flutter` plugins have unresolved native build issues on Windows, and this stage of the project only needs to run once per session on a development machine, not on the phone.

## 4. Planned: CV model + live fusion (not started)

Once enough labeled candidate frames exist, a lightweight object-detection model (e.g. YOLOv8n exported to TFLite) will be trained and combined with the IMU roughness signal to produce statistically-derived road quality thresholds (rather than the current guessed constants), eventually running live on-device for a real-time overlay.

---

# Session Management

Users can:

- Browse recorded sessions
- View session details, including the road quality map
- View raw GPS/IMU data tables
- View GPS/IMU/video correlation data
- Play recorded videos
- Share session files (as a ZIP)
- Delete sessions

---

# Technology Stack

## Framework

- Flutter
- Dart

## Android

- Camera API
- Sensors
- GPS

## Packages

- camera
- geolocator
- sensors_plus
- path_provider
- permission_handler
- video_player / chewie
- share_plus
- flutter_map / latlong2
- archive
- wakelock_plus
- shared_preferences

## External tools (development machine, not bundled in the app)

- ffmpeg - used by `scripts/extract_candidates.py` for offline frame extraction

---

# Project Structure

```
lib/
|
+-- core/
|   `-- services/
|       +-- camera_service.dart
|       +-- collection_service.dart
|       +-- correlation_service.dart
|       +-- export_service.dart
|       +-- gps_logger.dart
|       +-- gps_service.dart
|       +-- imu_logger.dart
|       +-- imu_service.dart
|       +-- logger_service.dart
|       +-- permission_service.dart
|       +-- pothole_spike_finder.dart
|       +-- recording_service.dart
|       +-- road_quality_service.dart
|       +-- sensor_service.dart
|       +-- session_clock.dart
|       +-- session_delete_service.dart
|       +-- session_service.dart
|       `-- settings_service.dart
|
+-- features/
|   +-- camera/
|   +-- gps/
|   +-- home/
|   +-- recording/
|   +-- sensors/
|   +-- sessions/
|   `-- settings/
|
`-- main.dart

scripts/
`-- extract_candidates.py   (offline pothole-frame extraction, run on a dev machine)
```

---

# Current Functionality

- Current rear camera recording
- Current GPS logging
- Current IMU logging
- Current shared synchronized timestamps
- Current automatic session folder creation
- Current metadata generation
- Current session browser
- Current session details
- Current color-coded road quality map (250m segments)
- Current GPS/IMU/video correlation viewer
- Current IMU-based pothole candidate detection (offline labeling workflow)
- Current video playback
- Current session sharing
- Current session deletion
- Planned CV pothole detection model (not started - see Road Quality Pipeline)
- Planned live on-device road quality overlay (not started)

---

# Platform

- Android
- Flutter

---

# Research

This application is being developed as part of an **M.Tech research project at PES University** focused on multimodal road condition data collection and intelligent road infrastructure analysis.

---

# License

This project is intended for academic and research purposes.