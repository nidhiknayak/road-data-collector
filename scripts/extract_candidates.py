import json
import subprocess
import sys
from pathlib import Path


def extract_frames(session_dir):
    session_dir = Path(session_dir)
    metadata = json.loads((session_dir / "metadata.json").read_text())
    offset_ms = metadata.get("camera_start_offset_ms")
    if offset_ms is None:
        print("No video for this session, skipping.")
        return

    spike_file = session_dir / "spike_timestamps.json"
    if not spike_file.exists():
        print(
            "No spike_timestamps.json found - run PotholeSpikeFinder "
            "in-app first."
        )
        return

    spikes = json.loads(spike_file.read_text())["spike_elapsed_ms"]

    out_dir = session_dir / "candidates"
    out_dir.mkdir(exist_ok=True)

    extracted = 0
    for ms in spikes:
        video_ms = ms - offset_ms
        if video_ms < 0:
            continue
        seconds = video_ms / 1000
        out_path = out_dir / f"candidate_{ms}ms.jpg"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-ss",
                str(seconds),
                "-i",
                str(session_dir / "video.mp4"),
                "-frames:v",
                "1",
                "-q:v",
                "2",
                str(out_path),
            ],
            check=True,
            capture_output=True,
        )
        extracted += 1

    print(f"Extracted {extracted} candidate frames to {out_dir}")


if __name__ == "__main__":
    extract_frames(sys.argv[1])
