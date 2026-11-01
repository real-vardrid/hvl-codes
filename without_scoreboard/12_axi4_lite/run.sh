#!/bin/bash
# Cadence irun runner for AXI4-Lite Slave Interface (Without Scoreboard)
cd "$(dirname "$0")" || exit 1
irun -sv -clean dut/top.sv tb/tb_top.sv -access +rwc "$@"
