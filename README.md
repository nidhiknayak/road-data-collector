# Road Data Collector

A Flutter-based Android application developed as part of an **M.Tech research project at PES University** for synchronized multimodal road condition data collection.

The application records **rear camera video**, **GPS data**, and **IMU sensor data** simultaneously using a shared timestamp, enabling the creation of high-quality datasets for road condition analysis and machine learning.

---

# Features

- 📹 Rear camera video recording
- 📍 GPS data logging
- 📱 IMU (Accelerometer & Gyroscope) logging
- ⏱ Shared synchronized timestamps across all sensors
- 📂 Automatic recording session management
- 📄 Metadata generation for every session
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
- Computer vision research
- Intelligent transportation research

---

# Architecture

```
RecordingPage
        │
        ▼
CollectionService
        │
        ├── RecordingService
        ├── CameraService
        ├── GpsService
        ├── GpsLogger
        ├── ImuService
        ├── ImuLogger
        └── SessionClock
```

The `CollectionService` coordinates all sensors to ensure synchronized recording.

---

# Recording Workflow

```
User presses Start Recording
            │
            ▼
CollectionService
            │
            ├── Starts SessionClock
            ├── Starts Camera Recording
            ├── Starts GPS Logging
            └── Starts IMU Logging
```

When recording stops:

```
Stop Recording
      │
      ▼
Stop Camera
Stop GPS Logger
Stop IMU Logger
Write metadata.json
Save Session
```

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

```
Session_2026_07_25_17_43_10/
│
├── video.mp4
├── gps.csv
├── imu.csv
└── metadata.json
```

---

# GPS Logging

GPS data is continuously logged into `gps.csv`.

Columns:

```
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

Each record contains:

- Timestamp
- Accelerometer X
- Accelerometer Y
- Accelerometer Z
- Gyroscope X
- Gyroscope Y
- Gyroscope Z

---

# Metadata

Each session generates a `metadata.json` file containing recording information, including:

- Session ID
- Start time
- End time
- Duration
- Video filename
- GPS filename
- IMU filename

---

# Session Management

The application includes a complete session management system.

Users can:

- Browse recorded sessions
- View session details
- Play recorded videos
- Share session files
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
- video_player
- share_plus

---

# Project Structure

```
lib/
│
├── core/
│   └── services/
│       ├── camera_service.dart
│       ├── collection_service.dart
│       ├── export_service.dart
│       ├── gps_logger.dart
│       ├── gps_service.dart
│       ├── imu_logger.dart
│       ├── imu_service.dart
│       ├── recording_service.dart
│       ├── session_clock.dart
│       ├── session_delete_service.dart
│       └── session_service.dart
│
├── features/
│   ├── recording/
│   └── sessions/
│
└── main.dart
```

---

# Current Functionality

- ✅ Rear camera recording
- ✅ GPS logging
- ✅ IMU logging
- ✅ Shared synchronized timestamps
- ✅ Automatic session folder creation
- ✅ Metadata generation
- ✅ Session browser
- ✅ Session details
- ✅ Video playback
- ✅ Session sharing
- ✅ Session deletion

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
