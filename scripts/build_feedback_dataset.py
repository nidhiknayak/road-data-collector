#!/usr/bin/env python3
"""Join live-map corrections to video, IMU and GPS without inventing labels.

Usage: python3 scripts/build_feedback_dataset.py /path/to/session_parent output.csv
The CSV is a training input; it does not retrain or change the phone model.
"""
import argparse
import csv
import json
import math
import statistics
from pathlib import Path

LABELS = ('very_good', 'good', 'bad', 'very_bad')
FIELDS = (
    'session_id', 'camera_view', 'vehicle_type', 'video_file',
    'video_start_s', 'video_end_s', 'window_start_ms', 'window_end_ms',
    'corrected_class', 'predicted_class', 'model_id',
    'cv_score_very_good', 'cv_score_good', 'cv_score_bad', 'cv_score_very_bad',
    'imu_samples', 'accel_magnitude_std', 'accel_step_p95', 'gyro_magnitude_rms',
    'gps_samples', 'speed_mps_median', 'feedback_gps_lat', 'feedback_gps_lon',
)


def rows_in_window(path, start, end):
    if not path.exists():
        return []
    with path.open(newline='') as source:
        return [row for row in csv.DictReader(source)
                if start <= float(row['elapsed_ms']) <= end]


def percentile(values, q):
    if not values:
        return None
    values = sorted(values)
    position = (len(values)-1)*q
    lower = math.floor(position)
    upper = math.ceil(position)
    return values[lower] + (values[upper]-values[lower])*(position-lower)


def sensor_features(folder, start, end):
    imu = rows_in_window(folder/'imu.csv', start, end)
    gps = rows_in_window(folder/'gps.csv', start, end)
    accel = [math.sqrt(sum(float(row[key])**2 for key in ('ax','ay','az')))
             for row in imu]
    gyro = [sum(float(row[key])**2 for key in ('gx','gy','gz'))
            for row in imu]
    steps = [abs(b-a) for a,b in zip(accel, accel[1:])]
    speeds = [float(row['speed']) for row in gps
              if 0 <= float(row['speed']) < 60 and
              float(row['accuracy']) <= 25]
    return {
        'imu_samples': len(imu),
        'accel_magnitude_std': statistics.pstdev(accel) if len(accel)>1 else '',
        'accel_step_p95': percentile(steps, .95) if steps else '',
        'gyro_magnitude_rms': math.sqrt(statistics.mean(gyro)) if gyro else '',
        'gps_samples': len(speeds),
        'speed_mps_median': statistics.median(speeds) if speeds else '',
    }


def feedback_rows(folder):
    path = folder/'vision_feedback.jsonl'
    metadata_path = folder/'metadata.json'
    if not path.exists() or not metadata_path.exists():
        return []
    metadata = json.loads(metadata_path.read_text())
    latest = {}
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        if event.get('type') != 'rating_correction':
            continue
        start, end = int(event['window_start_ms']), int(event['window_end_ms'])
        if start < 0 or end <= start or event.get('corrected_class') not in LABELS:
            continue
        # A second correction of the same window supersedes the first.
        latest[(start,end)] = event
    result = []
    offset = int(metadata.get('camera_start_offset_ms') or 0)
    for (start,end),event in sorted(latest.items()):
        location = event.get('gps_fix') or {}
        scores = event.get('model_scores') or {}
        row = {
            'session_id': metadata.get('session_id', folder.name),
            'camera_view': event.get('camera_view', metadata.get('vision_camera_view')),
            'vehicle_type': metadata.get('vehicle_type'),
            'video_file': str(folder/metadata.get('video_file','video.mp4')),
            'video_start_s': max(0, start-offset)/1000,
            'video_end_s': max(0, end-offset)/1000,
            'window_start_ms': start,
            'window_end_ms': end,
            'corrected_class': event['corrected_class'],
            'predicted_class': event.get('predicted_class'),
            'model_id': event.get('model_id'),
            'feedback_gps_lat': location.get('latitude',''),
            'feedback_gps_lon': location.get('longitude',''),
        }
        row.update({f'cv_score_{label}':scores.get(label,'') for label in LABELS})
        row.update(sensor_features(folder,start,end))
        result.append(row)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sessions', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    rows = [row for folder in sorted(args.sessions.glob('Session_*'))
            for row in feedback_rows(folder)]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('w',newline='') as output:
        writer = csv.DictWriter(output,fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f'Wrote {len(rows)} corrected windows from '
          f'{len(set(row["session_id"] for row in rows))} sessions to {args.output}')


if __name__ == '__main__':
    main()
