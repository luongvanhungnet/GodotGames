#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: bash scripts/test-android-cloud.sh GOOGLE_CLOUD_PROJECT [APK_PATH]" >&2
  exit 2
fi
project="$1"
apk="${2:-builds/PocketPuzzle-debug.apk}"
command -v gcloud >/dev/null || { echo 'Install and authenticate the Google Cloud CLI first.' >&2; exit 1; }
[[ -f "$apk" ]] || { echo "APK not found: $apk" >&2; exit 1; }

# Uses the caller's existing account; no credentials belong in this repository.
# Test Lab quotas and billing belong to the selected Google Cloud project.
gcloud firebase test android run \
  --project="$project" \
  --type=robo \
  --app="$apk" \
  --device=model=MediumPhone.arm,version=35,locale=en,orientation=portrait \
  --timeout=60s \
  --no-record-video \
  --results-history-name=PocketPuzzle
