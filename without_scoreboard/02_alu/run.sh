#!/bin/bash
# Cadence irun runner for 8-Bit Arithmetic Logic Unit (ALU) (Without Scoreboard)
cd "$(dirname "$0")" || exit 1
irun -sv -clean dut/top.sv tb/tb_top.sv -access +rwc "$@"
