"""Measure a native Stage A tour or gzip export size, without changing source/branches.

Linux RSS includes software-GL driver allocations; it is not Godot static memory
or a GPU measurement. Run each native case in a fresh invocation of this script.
"""
import argparse
import gzip
import json
import os
from pathlib import Path
import resource
import signal
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    native = modes.add_parser("native")
    native.add_argument("--repo", type=Path, default=Path("."))
    native.add_argument("--script", default="tools/m11_stage_a_smoke.gd")
    native.add_argument("--log", type=Path, default=Path("build/stage_a/native.log"))
    native.add_argument("--out", type=Path, default=Path("build/stage_a/native_process.json"))
    native.add_argument("--timeout", type=int, default=300)
    native.add_argument("--profile-only", action="store_true", help="Suppress PNG readback in the Stage A tour")
    size = modes.add_parser("size")
    size.add_argument("--baseline", required=True, type=Path)
    size.add_argument("--build", type=Path, default=Path("build/web"))
    size.add_argument("--out", type=Path, default=Path("build/stage_a/size.json"))
    args = parser.parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.mode == "size":
        def measure(folder):
            files = sorted(path for path in folder.rglob("*") if path.is_file() and not path.name.startswith("."))
            return {"raw_bytes": sum(path.stat().st_size for path in files),
                    "gzip_bytes": sum(len(gzip.compress(path.read_bytes(), compresslevel=9, mtime=0)) for path in files)}
        baseline, current = measure(args.baseline), measure(args.build)
        result = {"pinned_m1": baseline, "stage_a": current,
                  "increment_gzip_bytes": current["gzip_bytes"] - baseline["gzip_bytes"],
                  "within_150_mb": current["gzip_bytes"] < 150_000_000,
                  "method": "Sum of gzip-9 sizes of individually served export files; decimal MB"}
        status = 0
    else:
        args.log.parent.mkdir(parents=True, exist_ok=True)
        command = ["xvfb-run", "-a", "-s", "-screen 0 2560x1600x24", "godot",
                   "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--path", ".", "-s", args.script]
        if args.profile_only:
            command += ["--", "--profile-only"]
        with args.log.open("w") as stream:
            process = subprocess.Popen(command, cwd=args.repo, stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                status = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                status = 124
        result = {"exit_code": status, "valid_measurement": status == 0,
                  "max_child_rss_bytes": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss * 1024,
                  "qualification": "Linux max RSS of native smoke process tree; includes software OpenGL",
                  "command": command}
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return status


if __name__ == "__main__":
    raise SystemExit(main())
