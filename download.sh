#!/bin/bash
# Quick curl installer for HVL Lab codes
set -e
TARGET_DIR="${1:-hvl-codes}"
REPO_URL="https://github.com/real-vardrid/hvl-codes/archive/refs/heads/main.tar.gz"

echo "[HVL] Downloading HVL Verification Codes..."
mkdir -p "$TARGET_DIR"
curl -sL "$REPO_URL" | tar -xz --strip-components=1 -C "$TARGET_DIR"

echo "[HVL] Successfully downloaded to $TARGET_DIR!"
echo "[HVL] To simulate an experiment:"
echo "      cd $TARGET_DIR/with_scoreboard/01_priority_encoder && ./run.sh"
echo "      or run all: cd $TARGET_DIR && ./run_all.sh"
