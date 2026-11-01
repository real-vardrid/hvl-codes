#!/bin/bash
# Master runner for HVL Verification Repository
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$1" in
    with|sb)
        bash "$ROOT_DIR/with_scoreboard/run_all.sh"
        ;;
    without|nosb|compact)
        bash "$ROOT_DIR/without_scoreboard/run_all.sh"
        ;;
    all|"")
        echo ">>> Running With Scoreboard Suite <<<"
        bash "$ROOT_DIR/with_scoreboard/run_all.sh"
        echo
        echo ">>> Running Without Scoreboard Suite <<<"
        bash "$ROOT_DIR/without_scoreboard/run_all.sh"
        ;;
    *)
        echo "Usage: ./run_all.sh [with|without|all]"
        exit 1
        ;;
esac
