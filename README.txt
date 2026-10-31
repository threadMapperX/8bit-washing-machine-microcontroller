# Five-stage pipelined washing-machine microcontroller

Arka Mandal 2026EET2020

ELL7282 Assignment 2: an 8-bit, 5-stage pipelined CPU with a washing-machine control program, built in Logisim-Evolution.

## Contents

1. [Requirements](#1-requirements)
2. [Files](#2-files)
3. [Circuit structure](#3-circuit-structure)
4. [Load and run](#4-load-and-run)
5. [Pins](#5-pins)
6. [Washing program](#6-washing-program)
7. [Tests](#7-tests)

---

## 1. Requirements

| Item | Detail |
|---|---|
| Logisim-Evolution | File format 3.9.0 (`source="3.9.0"`). Also loads in 4.0.x, which converts the pin attributes automatically. |
| Java | 21 or newer (needed by Logisim-Evolution itself) |

## 2. Files

### Circuit and program

| File | Purpose |
|---|---|
| `washing_pipeline.circ` | Complete design. The ROM (`main > core > IF > IMEM`) already holds `program.hex`. |
| `program.asm`, `program.hex` | Washing program (Logisim "v3.0 hex words addressed" image) |

### Documents

| File | Contents |
|---|---|
| `isa.pdf` | Formats, opcode map, decode table, reserved bits, custom `SLTU` instruction |
| `architecture.pdf` | Block diagram, pipeline fields, forwarding / stall / flush, reset / HALT, safety |
| `memory_map.pdf` | Address map, bit fields, access, reset values, timer control |
| `listing.pdf` | Address / hex / assembly tables (program and test ROMs) |
| `pipeline_traces.pdf` | Cycle traces for 8.1 to 8.4 (plus a valid HALT) |

---

## 3. Circuit structure

| Level | Circuits |
|---|---|
| Top | `main`: Clock, input pins, output pins (commanded, safety-gated and debug) |
| Core | `mcu_core`: IF, IF_ID, CTRL, RF, HAZ, PCTL, ID_EX, FWD, EX, EX_MEM, MEM, SAFETY, MEM_WB, HALTED register |
| Arithmetic | `alu8`, `add8`, `full_add`, `half_add`, `inc8` |
| Selection and compare | `mux2_1/3/8`, `mux4_8`, `mux8_8`, `dec3to8`, `dec4to16`, `eq3`, `eq8`, `zero8` |
| Pipeline logic | `control_dec`, `hazard_unit`, `pipe_ctrl`, `fwd_unit`, `ex_stage`, `if_stage`, `mem_stage`, `addr_decode` |
| State | `regfile8x8`, `timer8`, `safety_ilock`, `if_id`, `id_ex`, `ex_mem`, `mem_wb` |

- Wiring inside every circuit uses labelled **Tunnels**; each tunnel label is the signal name.
- Only gates, splitters, tunnels, pins, probes, constants, the clock, Registers, ROM, RAM and Text are used.
- There are **no** built-in adders, muxes, decoders, comparators, shifters or Counters.

---

## 4. Load and run

1. **File > Open** and choose `washing_pipeline.circ`. The `main` circuit opens.
2. **Simulate > Simulation Enabled** must be ticked. Set **Simulate > Tick Frequency**: 1 to 4 Hz to watch the pipeline, 64 Hz to run fast.
3. **Set the inputs** you need (for example `DOOR_CLOSED = 1`) with the Poke tool.
4. **Reset:** click `RESET` to 1, then back to 0. The clear is asynchronous, so no clock tick is needed. PC, all valid bits, `HALTED`, the actuator latch, `DISPLAY`, the timer and `TRIP` are cleared.
5. **Clock it:**
   - **Simulate > Ticks Enabled** (Ctrl-K) for free running.
   - **Tick Half Cycle** (Ctrl-T) for single steps. Two half-ticks make one clock cycle, and everything triggers on the rising edge.
6. **Another program:** right-click `main > core > IF > IMEM` (the ROM), choose **Load Image...**, pick a `.hex` file, then reset.

> **Changing inputs.** Use the Poke tool *between* clock edges. Inputs are sampled by a valid `LD` in MEM or by the safety latch on the rising edge, so keep each value stable across that edge. Run slowly or single-tick when exact timing matters.

---

## 5. Pins

### Inputs (`main`)

| Pin | Width | Meaning |
|---|---|---|
| `RESET` | 1 | Hold at 1 to reset; CPU runs only while 0 |
| `START` | 1 | Start button |
| `MODE` | 2 | Wash program select (0 to 3) |
| `DOOR_CLOSED` | 1 | Door sensor |
| `WATER_LEVEL` | 8 | Unsigned water level |
| `TEMP` | 8 | Temperature readback |
| `DRUM_RPM` | 8 | Drum speed readback |

### Outputs (`main`)

| Group | Pins |
|---|---|
| Actuators | `VALVE_IN`, `HEATER`, `MOTOR_EN_REQ`, `MOTOR_DIR`, `PUMP_OUT`, `DOOR_LOCK`, `BUZZER` |
| Status | `DISPLAY[7:0]`, `HALTED`, `TRIP` |
| Safety-gated motor | `MOTOR_ACTUAL` = `MOTOR_EN_REQ` AND `DOOR_CLOSED` AND NOT `TRIP` |

### Debug pins

| Pins | Shows |
|---|---|
| `PC` | Address being fetched |
| `PC_ID`, `PC_EX`, `PC_MEM`, `PC_WB` with `V_ID`, `V_EX`, `V_MEM`, `V_WB` | Instruction in each stage and whether it is valid |
| `STALL`, `FLUSH` | Load-use bubble, branch / HALT flush |
| `FWD_A`, `FWD_B` | Operand source: `00` register file, `01` MEM/WB, `10` EX/MEM |
| `RF_WE`, `RF_WA`, `RF_WD` | Register write-back |
| `ST_COMMIT`, `ST_ADDR`, `ST_DATA` | Store being committed |
| `TMR_COUNT`, `TMR_MATCH` | Timer state |

**Inside the circuit:** register values are in `core > RF` (R0 to R7); RAM is in `core > MEM > DATA_RAM`.

---

## 6. Washing program

### Modes (`program.asm`)

| MODE | Name | Fill target | Wash ticks | Spin ticks | DISPLAY high digit |
|---|---|---|---|---|---|
| 0 | NORMAL | >= 100 | 120 | 60 | 1 |
| 1 | QUICK | >= 60 | 48 | 32 | 2 |
| 2 | HEAVY | >= 160 | 200 | 90 | 3 |
| 3 | DELICATE | >= 80 | 64 | 20 | 4 |

Drain threshold: `WATER_LEVEL <= 10` for every mode.

### DISPLAY codes

| Low digit | Phase |
|---|---|
| 1 | Waiting for START |
| 2 | Filling |
| 3 | Washing |
| 4 | Draining |
| 5 | Spinning |
| 6 | Done |

`E3` / `E5`: door opened while washing / spinning (motor blocked, waiting for re-arm).

---

## 7. Tests

### Test 0: Smoke test

`tests/t1_hazards.circ`: set `DOOR_CLOSED = 1`, reset, run about 90 cycles.

- `HALTED = 1`
- `RAM[0x21] = FF`
- `RAM[0x40..0x46] = 77 EE 77 04 22 09 22`

### Test 1: Forwarding and stalls

`tests/t1_hazards.circ`. Single-tick and watch `STALL`, `FWD_A/B`, `V_*` and `RF_WE/WA/WD` against `pipeline_traces.pdf` (8.1, 8.2, 8.3).

### Test 2: Branch and HALT

`tests/t2_branch.circ`

- `VALVE_IN` never becomes 1.
- `ST_ADDR` is never `F4` while `ST_COMMIT = 1`.
- `RAM[0x40] = 11`, `RAM[0x41] = 42`.
- The CPU halts only at the final `HALT`.

### Test 3: Memory and address decoding

`tests/t3_memory.circ` with `WATER_LEVEL = 0x2A`

- `RAM[0x50..0x57] = A5 5A 00 00 00 00 2A C3`
- `RAM[0x00] = A5` (a write to 0x80 did not alias)
- `DISPLAY = C3`

### Test 4: Timer

`tests/t4_timer.circ`. Watch `TMR_COUNT` / `TMR_MATCH`:

1. `MATCH` first rises with `COUNT = 05` and stays 1.
2. After clear and re-arm, `MATCH` rises again at `COUNT = 03`.
3. `COUNT` wraps `FF` to `00` with `MATCH = 0`.

`COUNT` also advances in `STALL = 1` cycles and after `HALTED = 1`. Final result: `RAM[0x60..0x65] = 00 0A 01 00 00 42`.

### Test 5: Safety interlock

`tests/t5_safety.circ`. Set `DOOR_CLOSED = 1`, `START = 0`, reset, run.

| Step | Action | Expect |
|---|---|---|
| 1 | Run about 15 cycles | `MOTOR_EN_REQ = 1`, `MOTOR_ACTUAL = 1` |
| 2 | Set `DOOR_CLOSED = 0` (no tick) | `MOTOR_ACTUAL` drops to 0 at once |
| 3 | Tick once | `TRIP = 1` |
| 4 | Set `DOOR_CLOSED = 1` | Motor does **not** restart, `TRIP` stays 1 |
| 5 | Pulse `START` 0 to 1 | `TRIP` clears, program requests the motor, `MOTOR_ACTUAL = 1` |

### Test 6: Full washing cycle

`washing_pipeline.circ`. Reset with `DOOR_CLOSED = 1`, `MODE = 0`, `WATER_LEVEL = 0`.

| Phase | You do | Expect |
|---|---|---|
| Start | `START = 1`, release once `DOOR_LOCK = 1` | `DISPLAY = 12`, `VALVE_IN = 1` |
| Fill | Raise `WATER_LEVEL` step by step: 99, then 102 | 99 keeps the valve open, 102 closes it |
| Wash | (changing `MODE` now has no effect) | `DISPLAY = 13`, motor on, `MOTOR_DIR` alternates |
| Drain | `PUMP_OUT = 1`: lower the level | Spin starts only at <= 10 |
| Spin | Keep `DRUM_RPM = 0` when the motor stops | `DISPLAY = 15`, motor, direction and pump on |
| Done | none | `DOOR_LOCK = 0`, `BUZZER = 1`, `DISPLAY = 16`, `HALTED = 1` |

Then repeat with `MODE = 1` (target 60, shorter wash and spin, ends at `DISPLAY = 26`).

**Optional door fault:** open the door during the wash. `DISPLAY` shows `E3` and the motor is blocked. Close the door and pulse `START` to continue.