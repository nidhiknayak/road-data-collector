# Road Data Collector - Acceptance Test Cases

## Overview

This document describes the manual acceptance test cases used to validate the Road Data Collector application on a physical Android device.

Hardware-dependent functionality such as camera recording, GPS, IMU sensors, and Android sharing cannot be fully validated through automated unit tests and must therefore be verified manually.

---

## Test Environment

- Device: Android phone
- OS: Android 12 or later
- Build: Latest GitHub Actions APK
- Permissions:
  - Camera
  - Location
  - Storage (if applicable)

---

# AT-001 - Application Launch

### Objective

Verify that the application launches successfully.

### Steps

1. Install the APK.
2. Open the application.

### Expected Result

- Application launches successfully.
- No crashes occur.
- Recording screen is displayed.

---

# AT-002 - Camera Recording Enabled

### Objective

Verify recording with camera enabled.

### Preconditions

- Camera toggle is enabled.

### Steps

1. Press **Start Recording**.
2. Record for approximately 30 seconds.
3. Press **Stop Recording**.

### Expected Result

- Recording starts successfully.
- Timer increments.
- Recording stops successfully.
- Session folder is created.
- Files generated:
  - video.mp4
  - gps.csv
  - imu.csv
  - metadata.json

---

# AT-003 - Camera Recording Disabled

### Objective

Verify GPS and IMU recording without camera.

### Preconditions

- Camera toggle is disabled.

### Steps

1. Press **Start Recording**.
2. Wait approximately 30 seconds.
3. Press **Stop Recording**.

### Expected Result

- Recording starts successfully.
- Timer increments.
- Recording stops successfully.
- Session folder contains:
  - gps.csv
  - imu.csv
  - metadata.json
- No video.mp4 is expected.

---

# AT-004 - GPS Logging

### Objective

Verify GPS data collection.

### Steps

1. Start recording.
2. Move outdoors.
3. Stop recording.

### Expected Result

- gps.csv contains GPS samples.
- Latitude and longitude change as movement occurs.
- Speed values are recorded.

---

# AT-005 - IMU Logging

### Objective

Verify IMU sensor collection.

### Steps

1. Start recording.
2. Move the device.
3. Stop recording.

### Expected Result

- imu.csv contains accelerometer, gyroscope, and magnetometer readings.
- Timestamp values increase continuously.

---

# AT-006 - Session Browser

### Objective

Verify recorded sessions appear in the session list.

### Steps

1. Record a session.
2. Open Sessions page.

### Expected Result

- Newly created session is visible.
- Session details are displayed correctly.

---

# AT-007 - Video Playback

### Objective

Verify recorded videos can be played.

### Preconditions

- Session recorded with camera enabled.

### Steps

1. Open Session Details.
2. Play recorded video.

### Expected Result

- Video loads successfully.
- Playback functions correctly.

---

# AT-008 - Session Export

### Objective

Verify session export.

### Steps

1. Open Session Details.
2. Press Share.

### Expected Result

- ZIP archive is generated.
- Android Share Sheet opens.
- ZIP contains:
  - video.mp4 (if camera enabled)
  - gps.csv
  - imu.csv
  - metadata.json

---

# AT-009 - Delete Session

### Objective

Verify session deletion.

### Steps

1. Open Session Details.
2. Delete session.

### Expected Result

- Session folder is removed.
- Session no longer appears in Sessions list.

---

# AT-010 - Long Duration Recording

### Objective

Verify stability during extended recording.

### Steps

1. Record for at least 10 minutes.
2. Stop recording.

### Expected Result

- Recording completes successfully.
- Session is saved.
- No crashes occur.
- All generated files are present.

---

# AT-011 - Rate Session

### Objective

Verify that a session rating persists and labels exported correlation data.

### Steps

1. Stop a recording with the camera enabled. Verify that **How was the road?** appears and tapping outside or dragging does not dismiss it.
2. Choose **Very Bad**, then open the session details and return to the session list.
3. Generate correlation data from Session Details.
4. Change the rating to **Very Good**, return to the list, and reopen the session.
5. Share the session and inspect the exported JSON and CSV files.
6. Record with the camera disabled, stop, and choose **Skip for now**. Open that session later and rate it.
7. Open an older session without rating keys and set its rating.

### Expected Result

- All four rating choices and **Skip for now** are available after stopping, with or without video.
- Skipped and older sessions show **Not rated** in the session list and remain available for later rating.
- Session Details reflects the saved choice after reopening. The list shows its label and folder color, and the map shows a session rating chip alongside the existing segment colors.
- `metadata.json` preserves the session data and contains `road_rating`, `road_rating_score` (1–4), and an ISO timestamp in `rated_at`.
- Generating or regenerating `correlation.json` copies the current rating and score to its top level and every bucket. Changing a rating also patches existing correlation data.
- Exported JSON includes the latest rating. The GPS and IMU CSV files remain unchanged.

---

# Acceptance Criteria

The application is considered accepted if:

- All automated CI tests pass.
- All manual acceptance tests pass on a physical Android device.
- No application crashes occur during testing.
- Session data is successfully collected and exported.
