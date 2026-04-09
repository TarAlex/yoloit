#!/bin/bash
# Hot reload the running yoloit app
# Requires run.sh to be running

FIFO="/tmp/yoloit_flutter_stdin"

if [[ ! -p "$FIFO" ]]; then
  echo "❌ Flutter is not running via run.sh (FIFO not found)"
  exit 1
fi

echo "🔥 Hot reloading..."
echo "r" > "$FIFO"
echo "✅ Hot reload triggered."
