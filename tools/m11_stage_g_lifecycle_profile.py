"""Run and externally profile the 100-cycle native Stage G lifecycle stress."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import statistics
import sys

import psutil


def process_tree_rss(root_pid: int) -> int:
    try:
        root = psutil.Process(root_pid)
    except psutil.NoSuchProcess:
        return 0
    total = 0
    for proc in [root, *root.children(recursive=True)]:
        try:
            total += proc.memory_info().rss
        except psutil.NoSuchProcess:
            pass
    return total


def stop_tree(root_pid: int) -> None:
    try:
        root = psutil.Process(root_pid)
    except psutil.NoSuchProcess:
        return
    children = root.children(recursive=True)
    for proc in reversed(children):
        try:
            proc.kill()
        except psutil.NoSuchProcess:
            pass
    try:
        root.kill()
    except psutil.NoSuchProcess:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--log", type=Path, default=Path("build/stage_g/lifecycle/run.log"))
    parser.add_argument("--report", type=Path, default=Path("build/stage_g/lifecycle/verification.json"))
    args = parser.parse_args()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    started_wall = time.time()
    command = ["xvfb-run", "-a", "-s", "-screen 0 2560x1600x24", "godot",
               "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--path", ".",
               "-s", "tools/m11_stage_g_lifecycle.gd"]
    points = []
    started = time.monotonic()
    with args.log.open("w") as stream:
        process = subprocess.Popen(command, cwd=args.repo, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            while process.poll() is None:
                rss = process_tree_rss(process.pid)
                points.append({"elapsed_seconds": round(time.monotonic() - started, 2),
                               "wall_time_unix": time.time(), "rss_bytes": rss})
                if time.monotonic() - started > args.timeout:
                    stop_tree(process.pid)
                    process.wait(timeout=10)
                    break
                time.sleep(0.5)
            exit_code = process.wait(timeout=10)
        except Exception:
            stop_tree(process.pid)
            raise
    if not args.report.exists() or args.report.stat().st_mtime < started_wall:
        print("lifecycle report is missing or predates this profiled run", file=sys.stderr)
        return exit_code if exit_code else 1
    report = json.loads(args.report.read_text())
    if report.get("failures"):
        print(f"lifecycle report has {len(report['failures'])} failed checks", file=sys.stderr)
        if exit_code == 0:
            exit_code = 1
    rss_values = [point["rss_bytes"] for point in points]
    endpoint_samples = report.get("endpoint_samples", [])
    aligned_endpoints = []
    for sample in endpoint_samples:
        if not points:
            continue
        nearest = min(points, key=lambda point: abs(point["wall_time_unix"] - float(sample.get("wall_time_unix", 0))))
        aligned_endpoints.append({"label": sample.get("label", ""),
                                  "endpoint_wall_time_unix": sample.get("wall_time_unix"),
                                  "rss_sample_wall_time_unix": nearest["wall_time_unix"],
                                  "rss_sample_delta_seconds": round(abs(nearest["wall_time_unix"] - float(sample.get("wall_time_unix", 0))), 3),
                                  "rss_bytes": nearest["rss_bytes"]})
    endpoint_trend = {"checked": False, "bounded": False}
    warmup = next((point for point in aligned_endpoints if point["label"] == "warmup_10"), None)
    settled = next((point for point in aligned_endpoints if point["label"] == "settled_100"), None)
    if warmup and settled:
        delta = int(settled["rss_bytes"]) - int(warmup["rss_bytes"])
        allowance = max(128 * 1024 * 1024, int(warmup["rss_bytes"] * 0.15))
        aligned = all(float(point["rss_sample_delta_seconds"]) <= 1.0 for point in aligned_endpoints)
        endpoint_trend = {"checked": True, "bounded": delta <= allowance,
                          "timestamps_aligned_within_one_second": aligned,
                          "warmup_rss_bytes": warmup["rss_bytes"], "settled_rss_bytes": settled["rss_bytes"],
                          "delta_bytes": delta, "allowance_bytes": allowance}
    report["whole_process_memory"] = {
        "exit_code": exit_code,
        "valid_measurement": exit_code == 0 and not report.get("failures") and bool(endpoint_trend.get("checked")) and bool(endpoint_trend.get("bounded")) and bool(endpoint_trend.get("timestamps_aligned_within_one_second")),
        "peak_rss_bytes": max(rss_values, default=0),
        "first_rss_bytes": rss_values[0] if rss_values else 0,
        "last_rss_bytes": rss_values[-1] if rss_values else 0,
        "rss_median_bytes": int(statistics.median(rss_values)) if rss_values else 0,
        "sample_count": len(points),
        "samples": points,
        "settled_endpoint_samples": aligned_endpoints,
        "endpoint_rss_trend": endpoint_trend,
        "qualification": "Sum of RSS for xvfb-run, Godot and all descendants, sampled at 2 Hz. Includes Xvfb and Mesa llvmpipe allocations; endpoints are native session process lifetime, not physical GPU memory.",
        "command": command,
    }
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report["whole_process_memory"]))
    if exit_code:
        return exit_code
    return 0 if report["whole_process_memory"]["valid_measurement"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
