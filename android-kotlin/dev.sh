#!/usr/bin/env bash
# CLI dev loop: rebuild + reinstall + relaunch on every source change.
set -euo pipefail
cd "$(dirname "$0")"

app_id=$(sed -n 's/^appId=//p' gradle.properties)
gradle_cmd=$(command -v gradle || echo ./gradlew)

adb wait-for-device
"$gradle_cmd" --continuous installDebug 2>&1 | while IFS= read -r line; do
    printf '%s\n' "$line"
    if [[ "$line" == *"BUILD SUCCESSFUL"* ]]; then
        adb shell am start -n "$app_id/.MainActivity"
    fi
done
