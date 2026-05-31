#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG_FILE=".env/worker.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing $CONFIG_FILE. Create it before running the app."
  exit 1
fi

flutter run --dart-define-from-file="$CONFIG_FILE" "$@"