#!/bin/bash
# Cadence irun runner for Synchronous FIFO (Without Scoreboard)
cd "$(dirname "$0")" || exit 1
irun -sv -clean dut/top.sv tb/tb_top.sv -access +rwc "$@"
