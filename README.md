# HVL Lab - Verified SystemVerilog Verification Suite

Comprehensive, industry-standard SystemVerilog Hardware Verification Language (HVL) verification environments for 12 essential digital design experiments.

Every testbench has been simulated and verified using **Cadence Incisive (`irun`)** with 100% pass rates.

---

## ⚡ Quick Start: Download on Another Computer

You can download and extract the entire codebase with a single `curl` command:

```bash
# Option 1: One-liner via curl tarball
curl -sL https://github.com/real-vardrid/hvl-codes/archive/refs/heads/main.tar.gz | tar -xz && cd hvl-codes-main

# Option 2: Download zip
curl -sLO https://github.com/real-vardrid/hvl-codes/archive/refs/heads/main.zip && unzip main.zip && cd hvl-codes-main

# Option 3: Git clone
git clone https://github.com/real-vardrid/hvl-codes.git && cd hvl-codes
```

---

## 📁 Repository Structure

```
hvl-codes/
├── with_scoreboard/           # Layered HVL testbenches WITH reference model & Scoreboard
│   ├── 01_priority_encoder/
│   │   ├── dut/top.sv         # Synthesizable RTL design
│   │   ├── tb/tb_top.sv       # Layered HVL Testbench (Generator, Driver, Monitor, Scoreboard)
│   │   └── run.sh             # Executable simulation script for Cadence irun
│   ├── 02_alu/
│   ├── 03_fifo/
│   ├── 04_dual_port_memory/
│   ├── 05_single_port_ram/
│   ├── 06_traffic_light_controller_1way/
│   ├── 07_traffic_light_controller_2way/
│   ├── 08_universal_shift_register/
│   ├── 09_uart/
│   ├── 10_arbiter/
│   ├── 11_fsm/
│   ├── 12_axi4_lite/
│   └── run_all.sh             # Run all 12 experiments with scoreboard
│
├── without_scoreboard/        # Compact HVL testbenches (Generator, Driver, Monitor)
│   ├── 01_priority_encoder/
│   │   ├── dut/top.sv
│   │   ├── tb/tb_top.sv
│   │   └── run.sh
│   ├── ... (all 12 experiments)
│   └── run_all.sh             # Run all 12 experiments without scoreboard
│
├── run_all.sh                 # Master simulation script
└── download.sh                # Curl download helper
```

---

## 🔬 Lab Experiments Included

| # | Experiment | RTL Module | TB Module | Architecture |
|---|---|---|---|---|
| **01** | **4-Bit Priority Encoder** | `priority_encoder_4bit` | `tb_top` | Layered OOP HVL (SV Interfaces, Mailboxes, Transaction Classes) |
| **02** | **8-Bit ALU** | `alu_8bit` | `tb_top` | 8 arithmetic & logic ops (ADD, SUB, AND, OR, XOR, NAND, NOR, XNOR) |
| **03** | **Synchronous FIFO** | `synchronous_fifo` | `tb_top` | Circular buffer with Full/Empty flags & pointer management |
| **04** | **Dual Port Memory** | `dual_port_ram` | `tb_top` | Concurrent read/write with independent Port A and Port B |
| **05** | **Single Port RAM** | `single_port_ram` | `tb_top` | Synchronous write & asynchronous/synchronous read |
| **06** | **1-Way Traffic Light Controller** | `traffic_light_controller` | `tb_top` | Timed state sequence: RED -> GREEN -> YELLOW -> RED |
| **07** | **2-Way Traffic Light Controller** | `traffic_light_controller` | `tb_top` | Dual intersection (North-South & East-West) controller |
| **08** | **Universal Shift Register (USR)** | `universal_shift_register` | `tb_top` | Parallel load, Shift Left, Shift Right, and Hold modes |
| **09** | **UART Transceiver** | `uart_top` | `tb_top` | Full-duplex asynchronous serial transceiver |
| **10** | **Arbiter** | `arbiter` | `tb_top` | Multi-master grant arbitration logic |
| **11** | **Finite State Machine (FSM)** | `fsm_dut` | `tb_top` | Sequence detector FSM verification |
| **12** | **AXI4-Lite Slave** | `axi4_lite_slave` | `tb_top` | Standard 5-channel AXI4-Lite memory-mapped interface |

---

## 🚀 Running Simulations

### Run a single experiment:
```bash
cd with_scoreboard/01_priority_encoder
./run.sh
```
Or manually using Cadence `irun`:
```bash
irun -sv dut/top.sv tb/tb_top.sv -access +rwc
```

### Run all experiments:
```bash
# Run everything:
./run_all.sh

# Or run only with scoreboard:
./run_all.sh with

# Or run only compact (no scoreboard):
./run_all.sh without
```
