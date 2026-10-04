#!/usr/bin/env python3
"""Desktop compatibility regressions; never certifies physical Android/GPU behavior.

python tools/check_android_compat.py --godot PATH
Logs stay in ignored build/android-compat. Existing verifier reports inapplicable gates.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    logs = ROOT / "build/android-compat"
    logs.mkdir(parents=True, exist_ok=True)
    base = [args.godot, "--headless", "--path", str(ROOT), "--fixed-fps", "60"]
    checks = [(name, base + ["--", "--" + name], 180)
              for name in ("home-selfcheck", "feedback-selfcheck", "smoke")]
    for name in ("android_reports", "home06_restart", "hub_crash_stress", "system_stress",
                 "low_fx", "activity_animation", "cooking_animation",
                 "breakfast_animation", "pouring_animation"):
        # Animation assertions sample exact phases at their documented 120 FPS.
        script_base = base[:-1] + ["120"] if name.endswith("animation") or name == "low_fx" else base
        checks.append((name, script_base + ["--script", f"res://tools/test_{name}.gd"], 600))
    # test_activities is RefCounted and already runs inside --smoke.
    for name, script, mode in (("kettle", "cooking", "kettle"), ("tea", "breakfast", "tea")):
        checks.append((name, base[:-1] + ["120", "--script", f"res://tools/test_{script}_animation.gd", "--", mode], 600))
    for loc in ("kitchen", "bath", "living"):
        checks.append(("layout_" + loc, base + ["--script", "res://tools/test_kitchen_layout.gd", "--", loc], 120))
    checks.append(("verify19", [sys.executable, "tools/verify.py", "--godot", args.godot,
                              "--no-cache", *[f"home_{i:02}" for i in range(1, 20)]], 3600))
    failed = []
    for name, command, timeout in checks:
        path = logs / (name + ".log")
        try:
            with path.open("w", encoding="utf-8") as log:
                result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
            output = path.read_text(encoding="utf-8", errors="replace")
            diagnostics = re.findall(r"^.*(?:SCRIPT ERROR|USER ERROR|ERROR:|WARNING:|ObjectDB|Parse Error).*$", output, re.M)
            expected = [line for line in diagnostics if name == "home-selfcheck"
                        and "WARNING: Profile:" in line and "is broken, using the backup" in line]
            unexpected = [line for line in diagnostics if line not in expected]
            ok = result.returncode == 0 and not unexpected
            print(f"{'PASS' if ok else 'FAIL'} {name}" + (f"; EXPECTED EXCEPTION: {len(expected)} corruption warnings" if expected else ""), flush=True)
            for line in unexpected:
                print(line, flush=True)
            if not ok:
                failed.append(name)
        except subprocess.TimeoutExpired:
            failed.append(name)
            print(f"FAIL {name}: timeout ({timeout}s), see {path.name}", flush=True)
    print("NOT TESTED: Android JNI/driver, physical devices, emulator, OS lifecycle, armv7 execution", flush=True)
    return bool(failed)


if __name__ == "__main__":
    sys.exit(main())
