# Live road map

Android app version 1.5 adds a **Live road map** tab alongside **Collect**.
Choose the camera position, point the rear camera towards the road and select
**Start live mapping**. The screen shows OpenStreetMap, follows the GPS position
and colours the travelled route using camera estimates. The camera records
video while the map is visible. Video, GPS and IMU collection use the existing
session clock and storage format.

## Colours and model limits

The four original classes are retained: very good (dark green), good (light
green), bad (orange), and very bad (red). Grey means pending, warming up,
uncertain, no visible road, or unavailable inference. Estimates below a raw
model score of 0.5 are uncertain. Scores are not calibrated probabilities of
correctness. An information button explains the current independent test
result: **30.8% video accuracy on 13 test videos**. This is an experimental
research feature; integrating it does not improve its classification accuracy.

The model runs on the phone with ONNX Runtime. Frames are not uploaded to a
server. Internet is required for uncached OpenStreetMap tiles; standard tile
caching is provided by flutter_map. Attribution is always visible on the map.

The selected pipeline uses SegFormer B0 road segmentation, camera-specific
foreground exclusions, a contiguous road tile, DINOv2-small features from RGB
and contrast-normalized grayscale tiles, and five-frame temporal aggregation.
At least three valid samples are required before a prediction. The classifier
is the frozen L2-normalized logistic model selected in the dataset evaluation.
Sampling is at most once per second; a busy model drops new samples rather
than accumulating old frames. Actual throughput depends on the device.

## Route timing and recording lifecycle

Predictions carry their camera sampling window in session elapsed milliseconds.
Frames are timestamped on arrival from the camera plugin; camera delivery lag
and GPS timing uncertainty remain, rather than claiming frame-exact alignment.
Only GPS edges covered by that window can receive its colour. Processing
latency does not move a prediction to the user's later position. Completed
segments retain their original estimate; early warm-up can be replaced by the
first complete window. Unknown segments do not inherit an earlier good label.

GPS fixes over 25 m reported accuracy, stale fixes, implausible jumps and
location gaps are excluded from connected routes. GPS measurement timestamps
are aligned to the session clock. Stationary GPS jitter does not inflate mapped
distance. Pressing back while mapping asks the user to stop and save first.
Switching between the app's tabs preserves recording. Leaving the app or
locking the phone stops and saves the recording; Android screen-off background
recording is not part of this feature.

## Files and replay

Live-map sessions add these files to the usual `video.mp4`, `gps.csv`, `imu.csv`
and `metadata.json`:

- `vision_predictions.jsonl`: raw model scores, classes, statuses, frame window
  times, processing duration and model ID.
- `vision_route.geojson`: GPS route edges, quality estimates, status and timing.
  It is saved periodically and at the end of recording.
- `vision_feedback.jsonl`: user corrections of the current estimate. Each row
  saves the corrected class, original model scores, video/IMU window times,
  camera view and latest GPS fix. A second correction for the same window
  supersedes the first when training data is prepared. The saved map shows
  corrected colours for edges already associated with that estimate.

During a live recording, tap **Wrong rating? Correct this section** while an
estimate is fresh, then choose the actual quality. This immediately changes
the displayed estimate and affected mapped edges. It does not retrain the
phone model during the trip; the next estimate still comes from the current
model. This is supervised feedback, not reinforcement learning. Keeping the
original prediction and manual correction separate lets later model training
audit mistakes and avoid treating uncertain or mixed sections as ground truth.

After exporting sessions, join corrected windows to synchronized IMU and GPS
features with:

```sh
python3 scripts/build_feedback_dataset.py /path/to/sessions feedback_windows.csv
```

The CSV includes video clip times for later road-damage detection features,
accelerometer and gyroscope summaries, speed, camera position, and the manual
label. It is a training input; the current app model remains camera-only until
a fused candidate passes held-out-route evaluation.

Session details offer **View saved live road map**. Session ZIP export includes
these files automatically. Manual session ratings remain separate: model
predictions never populate the ground-truth `road_rating` field. After a normal
stop, the existing manual rating sheet is offered.

## Rebuilding the models

The ONNX models and linear head are bundled in
`android/app/src/main/assets/road_models/`. No model download is needed on the
phone. Re-export the selected Python model using:

```sh
HF_HUB_OFFLINE=1 /home/vlns/python-dev/.venv/bin/python scripts/export_mobile_vision.py
```

The exporter requires PyTorch, Transformers, NumPy, joblib, scikit-learn, ONNX,
ONNX Runtime and the cached pretrained feature models. It verifies both ONNX
graphs against PyTorch, including portrait and landscape segmentation, and
checks the portable classifier against scikit-learn. `classifier.json` records
model hashes, sizes and numerical check results. The exporter currently
supports the selected four-class surface-embedding/L2/logistic architecture;
changing architecture requires updating the Android adapter too.

```sh
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

## Device acceptance check

No Android device was connected during implementation. Before field use:

1. Install the APK, open the live-map tab and grant camera/location permission.
2. Choose the actual camera position. Start recording outdoors with a clear
   view of the road. Confirm the camera indicator and GPS location appear.
3. Walk a short route; confirm warm-up, quality estimates and coloured route.
   Aim away from the road briefly: new estimates should become grey.
4. Pan the map, then use the location button to resume following.
5. Switch to Collect and back; confirm the same recording continues. Stop and
   verify video, sensor logs, prediction log and saved route replay.
6. Check lifecycle interruption, camera/video+analysis compatibility, inference
   latency, memory use and battery/temperature on the intended phone. These
   hardware behaviours cannot be established by widget tests or model export
   checks alone.

References: [ONNX Runtime Android](https://onnxruntime.ai/docs/tutorials/mobile/),
[OpenCV Android](https://docs.opencv.org/4.11.0/d5/df8/tutorial_dev_with_OCV_on_Android.html),
[OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/).
