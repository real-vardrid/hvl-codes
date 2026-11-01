#!/bin/bash
# Cadence irun runner for 2-Way Traffic Light Controller (With Scoreboard)
cd "$(dirname "$0")" || exit 1
irun -sv -clean dut/top.sv tb/tb_top.sv -access +rwc "$@"
