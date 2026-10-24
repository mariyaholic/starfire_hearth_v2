"""Measure the real Web recovery smoke's browser/test process tree at 2 Hz."""
import json
from pathlib import Path
import subprocess
import sys
import time

import psutil


def tree_memory(pid: int) -> tuple[int, list[dict]]:
    try:
        root = psutil.Process(pid)
    except psutil.NoSuchProcess:
        return 0, []
    total = 0
    processes = []
    for process in [root, *root.children(recursive=True)]:
        try:
            rss = process.memory_info().rss
            total += rss
            processes.append({"pid": process.pid, "name": process.name(), "rss_bytes": rss})
        except psutil.NoSuchProcess:
            continue
    return total, processes


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    output = repo / "build/stage_g/recovery"
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / "profile_run.log"
    report_path = output / "verification.json"
    command = [sys.executable, "tools/m11_stage_g_web_recovery.py"]
    samples = []
    started = time.monotonic()
    with log_path.open("w") as log:
        process = subprocess.Popen(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        while process.poll() is None:
            rss, processes = tree_memory(process.pid)
            samples.append({"elapsed_seconds": round(time.monotonic() - started, 3),
                            "wall_time_unix": time.time(), "rss_bytes": rss,
                            "processes": processes})
            time.sleep(0.5)
        exit_code = process.wait()
    if not report_path.is_file():
        print(f"Web recovery smoke did not write {report_path}", file=sys.stderr)
        return exit_code or 1
    report = json.loads(report_path.read_text())
    report["web_process_memory"] = {
        "exit_code": exit_code,
        "valid_measurement": exit_code == 0 and len(samples) >= 2,
        "peak_rss_bytes": max((point["rss_bytes"] for point in samples), default=0),
        "first_rss_bytes": samples[0]["rss_bytes"] if samples else 0,
        "last_rss_bytes": samples[-1]["rss_bytes"] if samples else 0,
        "sample_count": len(samples),
        "samples": samples,
        "qualification": "RSS for the Web recovery smoke Python process, Playwright driver and all Chromium descendants, sampled at 2 Hz. Includes Chromium software SwiftShader. This is process memory, not WebAssembly heap or GPU allocation.",
        "command": command,
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: report["web_process_memory"][key]
                      for key in ["exit_code", "valid_measurement", "peak_rss_bytes", "sample_count"]}))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
