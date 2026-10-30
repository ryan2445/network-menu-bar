#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running Network Menu Bar test suite..."

swift "$SCRIPT_DIR/test.swift"
