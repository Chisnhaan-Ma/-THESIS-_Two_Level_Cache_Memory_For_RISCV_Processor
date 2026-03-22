# SDRAM Controller (`sdram_controler.sv`) - Detailed Operation

## 1. Purpose

`00_src/sdram_controler.sv` is a simple SDR SDRAM controller for ISSI IS42S16400 on DE2.

- User side interface matches the old SRAM-style handshake:
  - Inputs: `i_sram_enb`, `i_wr_en`, `i_addr`, `i_wdata`
  - Outputs: `o_rdata`, `o_ready`
- SDRAM side is 16-bit data bus (`io_dram_dq`) with classic SDR command pins.
- Controller uses **closed-page policy** with **auto-precharge** (`A10=1` on READ/WRITE command).

## 2. User-side transaction model

A user request is accepted only when controller is in `S_IDLE` and no refresh is pending:

- `req_accept = (state == S_IDLE) && (!refresh_pending) && i_sram_enb`

One 32-bit request is executed as two 16-bit SDRAM accesses:

- `half_sel = 0`: low halfword (`[15:0]`)
- `half_sel = 1`: high halfword (`[31:16]`)

Completion behavior:

- `o_ready` pulses high for 1 cycle in `S_DONE`.
- For READ, `o_rdata` is valid when `o_ready=1`.

## 3. Address mapping

Controller converts byte address to halfword address (`16-bit` words):

- `halfword_addr = req_addr_reg[22:1] + half_sel`

Bit slicing:

- `bank = halfword_addr[21:20]`
- `row  = halfword_addr[19:8]`
- `col  = halfword_addr[7:0]`

Column command address:

- `rw_col_addr = {3'b000, 1'b1, col}`
- `A10=1` enables auto-precharge after READ/WRITE.

## 4. Initialization sequence

After reset (`i_reset=1`), controller executes SDRAM bring-up:

1. `S_INIT_WAIT`: wait `INIT_WAIT_US` (default 200 us)
2. `S_INIT_PRE`: issue `PRECHARGE ALL`
3. `S_INIT_TRP`: wait `tRP`
4. `S_INIT_AR1`: issue `AUTO REFRESH` #1
5. `S_INIT_AR1W`: wait `tRFC`
6. `S_INIT_AR2`: issue `AUTO REFRESH` #2
7. `S_INIT_AR2W`: wait `tRFC`
8. `S_INIT_MRS`: load mode register (`MODE_REG`)
9. `S_INIT_TMRD`: wait `tMRD`
10. enter `S_IDLE`

`MODE_REG = 12'b0010_0010_0000`:

- Burst length = 1
- Sequential burst type
- CAS latency = 2
- Single write burst mode

## 5. Refresh scheduler

Periodic refresh starts only after init is complete (`state >= S_IDLE`).

- Counter increments each cycle.
- When `refresh_cnt >= REFRESH_INTERVAL_CYC - 1`, set `refresh_pending=1`.
- In `S_IDLE`, refresh has higher priority than new request.

Refresh flow:

1. `S_REF_CMD`: issue `AUTO REFRESH`
2. `S_REF_WAIT`: wait `tRFC`
3. return to `S_IDLE`

## 6. Read/Write FSM flow

### Common front-end

1. `S_ACTIVATE`: issue `ACTIVATE` with selected bank/row
2. `S_TRCD_WAIT`: wait `tRCD`
3. `S_RW_CMD`: issue READ or WRITE at selected column (`A10=1`)

### Write path

- In `S_RW_CMD` with `req_wr_en_reg=1`:
  - Command = WRITE
  - `dq_oe=1`, drive `io_dram_dq` with selected halfword
- Then go to `S_PRE_WAIT` and wait write-recovery (`WRITE_RECOVERY_CYCLES`)

### Read path

- In `S_RW_CMD` with `req_wr_en_reg=0`:
  - Command = READ
  - `dq_oe=0` (controller releases DQ bus)
- `S_READ_WAIT`: wait CAS latency (`CAS_LATENCY_CYCLES`)
- `S_READ_CAP`: sample `dq_in` into `read_data_reg` halfword
- Then `S_PRE_WAIT` for `tRP`

### Halfword stitching and done

- `S_NEXT_HALF`:
  - if `half_sel==0`, set `half_sel=1` and run second half transaction
  - if `half_sel==1`, go `S_DONE`
- `S_DONE`: pulse `o_ready=1` for one cycle

## 7. SDRAM command encoding by state

Default output is NOP:

- `CS#=0, RAS#=1, CAS#=1, WE#=1`

Active command states:

- `S_INIT_PRE`: PRECHARGE ALL (`RAS#=0, WE#=0, A10=1`)
- `S_INIT_AR1`, `S_INIT_AR2`, `S_REF_CMD`: AUTO REFRESH (`RAS#=0, CAS#=0, WE#=1`)
- `S_INIT_MRS`: LOAD MODE REGISTER (`RAS#=0, CAS#=0, WE#=0`)
- `S_ACTIVATE`: ACTIVATE (`RAS#=0, CAS#=1, WE#=1`, BA=row select)
- `S_RW_CMD` + write: WRITE (`RAS#=1, CAS#=0, WE#=0`)
- `S_RW_CMD` + read: READ (`RAS#=1, CAS#=0, WE#=1`)

## 8. Data bus direction

- `io_dram_dq` is tri-stated unless writing.
- On WRITE command cycle:
  - `dq_oe=1`
  - `dq_out` drives low/high 16-bit halfword.
- On READ and all other states:
  - `dq_oe=0`
  - controller samples external data as `dq_in`.

## 9. Timing parameters (configurable)

Main tunable parameters:

- `TRP_CYCLES`
- `TRCD_CYCLES`
- `TRFC_CYCLES`
- `TMRD_CYCLES`
- `CAS_LATENCY_CYCLES`
- `WRITE_RECOVERY_CYCLES`
- `REFRESH_INTERVAL_CYC`

These are in controller clock cycles and should be adjusted for the actual clock frequency and SDRAM datasheet timing.

## 10. Design notes and limits

- Design prioritizes simplicity and deterministic behavior.
- Uses closed-page access, so each halfword incurs `ACTIVATE + READ/WRITE + auto-precharge` overhead.
- Throughput is lower than open-page burst controllers but logic is easier to verify.
- No byte-enable masking (`DQM` fixed to `2'b00`), so writes are full 16-bit per halfword.
