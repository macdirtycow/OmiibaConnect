#!/usr/bin/env bash
# Double-click in Finder to build and update Omiiba Connect in /Applications.
cd "$(dirname "$0")/.."
exec ./scripts/update-macos.sh --build
