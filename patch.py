#!/usr/bin/env python3
"""
Upstream and tree patches for realme-atoll ROM builds.
Can be executed directly via:
    curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/aosp-17/patch.py | python3
"""

import os
import re

def patch_soong_build_main():
    main_go = "build/soong/cmd/soong_build/main.go"
    if not os.path.exists(main_go):
        return
    with open(main_go, "r") as f:
        content = f.read()

    # Check if already patched
    if "debug.SetGCPercent" in content:
        print("cmd/soong_build/main.go already patched with GC tuning.")
        return

    # Add required imports if missing
    for imp in ['"runtime/debug"', '"strconv"']:
        if imp not in content:
            content = re.sub(r'import\s*\(\n', f'import (\n\t{imp}\n', content)

    # Inject GC tuning block matching rony1duet/android_build_soong commit 82910cd
    gc_block = '''\tavailableEnv := parseAvailableEnv()

\t// Tune Go GC for lower memory consumption during Android.bp analysis to prevent OOM
\tif gc := os.Getenv("GOGC"); gc != "" {
\t\tif val, err := strconv.Atoi(gc); err == nil {
\t\t\tdebug.SetGCPercent(val)
\t\t}
\t} else {
\t\tdebug.SetGCPercent(40)
\t}
\tif gc := availableEnv["SOONG_GOGC"]; gc != "" {
\t\tif val, err := strconv.Atoi(gc); err == nil {
\t\t\tdebug.SetGCPercent(val)
\t\t}
\t}'''

    if "\tavailableEnv := parseAvailableEnv()" in content:
        content = content.replace("\tavailableEnv := parseAvailableEnv()", gc_block, 1)
        with open(main_go, "w") as f:
            f.write(content)
        print("Successfully patched cmd/soong_build/main.go with GC tuning.")
    else:
        print("Notice: parseAvailableEnv pattern not matched in cmd/soong_build/main.go")

def patch_soong_ui():
    soong_go = "build/soong/ui/build/soong.go"
    if not os.path.exists(soong_go):
        return
    with open(soong_go, "r") as f:
        content = f.read()

    if "GOMEMLIMIT" in content and "invocationEnv" in content:
        print("ui/build/soong.go already patched with environment pass-through.")
        return

    # Inject environment pass-through matching rony1duet/android_build_soong commit 82910cd
    target = "invocationEnv := make(map[string]string)"
    env_block = '''invocationEnv := make(map[string]string)
\t// Pass through memory & GC tuning variables to prevent OOM in container builds
\tfor _, envVar := range []string{"GOMEMLIMIT", "GOGC", "GODEBUG", "MALLOC_ARENA_MAX"} {
\t\tif val := os.Getenv(envVar); val != "" {
\t\t\tinvocationEnv[envVar] = val
\t\t}
\t}'''

    if target in content:
        content = content.replace(target, env_block, 1)
        with open(soong_go, "w") as f:
            f.write(content)
        print("Successfully patched ui/build/soong.go with environment pass-through.")
    else:
        print("Notice: invocationEnv pattern not matched in ui/build/soong.go")

def patch():
    print("=== Applying Upstream Patches ===")
    patch_soong_build_main()
    patch_soong_ui()
    print("=== Upstream Patches Applied ===")

if __name__ == "__main__":
    patch()
