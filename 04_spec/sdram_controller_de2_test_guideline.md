# SDRAM Controller Test Guideline (Altera DE2)

This guide shows how to test `sdram_controler.sv` in simulation and then on a DE2 board.

## 1. What Was Added

- Self-checking testbench: `01_bench/SDRAM_CONTROLLER_TB.sv`
- DUT under test: `00_src/sdram_controler.sv`

The testbench verifies:
- SDRAM init sequence completes
- 32-bit read from preloaded SDRAM content
- 32-bit write/read-back at multiple addresses
- Periodic AUTO REFRESH appears and data remains valid

## 2. Quick Simulation

Use one of these commands from workspace root.

### Xcelium/xrun

```sh
xrun -sv -timescale 1ns/1ps \
  00_src/sdram_controler.sv \
  01_bench/SDRAM_CONTROLLER_TB.sv \
  -top SDRAM_CONTROLLER_TB -access +rwc
```

### Icarus Verilog

```sh
iverilog -g2012 -o sdram_tb.vvp \
  00_src/sdram_controler.sv \
  01_bench/SDRAM_CONTROLLER_TB.sv
vvp sdram_tb.vvp
```

Expected result includes:
- `[PASS] READ ...`
- `[PASS] WRITE/READ ...`
- `[PASS] Refresh observed ...`
- `=== SDRAM_CONTROLLER_TB PASSED ===`

## 3. DE2 Top-Level Integration

Connect controller SDRAM interface to DE2 top-level ports.

Required top-level SDRAM ports:
- `DRAM_CLK`
- `DRAM_CKE`
- `DRAM_CS_N`
- `DRAM_RAS_N`
- `DRAM_CAS_N`
- `DRAM_WE_N`
- `DRAM_BA[1:0]`
- `DRAM_ADDR[11:0]`
- `DRAM_DQ[15:0]`
- `DRAM_LDQM`
- `DRAM_UDQM`

Suggested mapping:
- `o_dram_clk  -> DRAM_CLK`
- `o_dram_cke  -> DRAM_CKE`
- `o_dram_cs_n -> DRAM_CS_N`
- `o_dram_ras_n -> DRAM_RAS_N`
- `o_dram_cas_n -> DRAM_CAS_N`
- `o_dram_we_n  -> DRAM_WE_N`
- `o_dram_ba    -> DRAM_BA`
- `o_dram_addr  -> DRAM_ADDR`
- `io_dram_dq   <-> DRAM_DQ`
- `o_dram_dqm[0] -> DRAM_LDQM`
- `o_dram_dqm[1] -> DRAM_UDQM`

Clock/reset recommendations:
- Use DE2 `CLOCK_50` as `i_clk`
- Drive `i_reset` from `KEY[0]` (invert if key is active-low)
- Keep controller at 50 MHz first (same as current parameter assumptions)

## 4. On-Board Functional Test Flow

1. Build a small test wrapper around `sdram_controler`.
2. After reset, issue these requests in hardware:
- write `0x12345678` to address `0x00001000`
- read back from `0x00001000`
- write `0xA5A55A5A` to address `0x00001004`
- read back from `0x00001004`
3. Expose result on LEDs/HEX:
- LED pass bit = 1 only if both readbacks match
- Optional: show low 16 bits of read data on HEX displays
4. Keep issuing periodic reads while idle delay is longer than refresh interval to ensure data does not decay.

## 5. Timing Constraints (Quartus)

In your SDC, at minimum define the 50 MHz base clock:

```tcl
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
```

Then run full timing analysis and ensure no setup/hold violations on SDRAM path and controller logic.

## 6. SignalTap Debug Checklist

Probe these signals first:
- `state` (inside controller)
- `o_dram_cs_n/o_dram_ras_n/o_dram_cas_n/o_dram_we_n`
- `o_dram_ba`, `o_dram_addr`
- `io_dram_dq`
- `i_sram_enb`, `i_wr_en`, `i_addr`, `i_wdata`
- `o_rdata`, `o_ready`

Healthy behavior:
- init command sequence appears once after reset
- refresh commands appear periodically
- each request eventually produces one `o_ready` pulse
- read data matches previous write data

## 7. Common Bring-Up Issues

- Wrong SDRAM pin assignment: verify against DE2 pin CSV and board manual.
- Reset polarity mismatch: controller expects active-high `i_reset`.
- No constraints/incorrect clock: always define and verify 50 MHz timing.
- DQ direction bug: only drive DQ during write command cycles.
- Address mapping confusion: controller uses `req_addr[22:1]` as halfword address base.

## 8. Practical Notes

- File name in project is `sdram_controler.sv` (single `l` in `controler`). Keep naming consistent in scripts.
- Start with low traffic single-request tests before integrating with cache/pipeline.
