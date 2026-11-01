#!/bin/bash
# ==========================================================
# Run all 12 HVL experiments (WITH SCOREBOARD) using Cadence irun
# ==========================================================
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

echo "=========================================================="
echo " Running HVL Simulation Suite (WITH SCOREBOARD)"
echo " Simulator: Cadence Incisive (irun)"
echo "=========================================================="
echo

for dir in "$ROOT_DIR"/*/; do
    [ -d "$dir" ] || continue
    exp_name="$(basename "$dir")"
    echo -n "Running $exp_name ... "
    
    cd "$dir" || continue
    rm -rf INCA_libs irun.log irun.history
    
    OUTPUT=$(irun -sv -clean dut/top.sv tb/tb_top.sv -access +rwc 2>&1)
    RET=$?
    
    if [ $RET -eq 0 ] && echo "$OUTPUT" | grep -q "Simulation complete via \$finish" && ! echo "$OUTPUT" | grep -q "FAIL = [1-9]"; then
        echo "PASS [0 errors]"
        ((PASS_COUNT++))
    else
        echo "FAILED"
        echo "$OUTPUT" | tail -n 12
        ((FAIL_COUNT++))
    fi
    ((TOTAL++))
done

echo
echo "=========================================================="
echo " RESULTS: $PASS_COUNT/$TOTAL Passed, $FAIL_COUNT Failed"
echo "=========================================================="
