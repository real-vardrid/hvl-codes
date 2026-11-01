#!/bin/bash
# Cadence irun runner for UART (Transmitter & Receiver) (Without Scoreboard)
cd "$(dirname "$0")" || exit 1
irun -sv -clean dut/top.sv tb/tb_top.sv -access +rwc "$@"
