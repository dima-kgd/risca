# RiscA — agents guide

## Project

Verilog implementation of a 3-stage RiscA CPU.

## Key documents

- `RiscA.MD` — the canonical ISA reference: instruction encoding, ABI, register
  conventions, interrupt vectors. Always consult this before writing/modifying the
  CPU implementation.

## ISA essentials

- Little-Endian, 32-bit bus, 16-bit instructions (2 per 32-bit word)
- 16 general-purpose registers R0–R15 (32-bit)
- 3-stage pipeline
- ABI: args R0–R5, return R0, stack R15, link register R14
- Interrupt vectors: 0x0 (Reset), 0x2 (Timer), 0x4 (Syscall), 0x6+

## Files

| Path | Contents |
|---|---|
| `rtl/risca_cpu.v` | 3-stage pipeline CPU: Fetch → Decode → Execute. Harvard arch (separate I/D buses). Forwarding, branch flush. |
| `tb/risca_tb.v` | Testbench with IMEM/DEM arrays, `define`-based instruction macros, test program, VCD dump |
| `sim.bat` | `iverilog -g2012 → vvp → gtkwave` |

## Simulation

```bat
sim.bat
```

Compiles with iverilog, runs VVP simulation, opens GTKWave waveform viewer.

- Instruction encoding macros are in `tb/risca_tb.v` (e.g., `` `ADD(rd, rs) ``, `` `BEQZ(rd, imm) ``).
- Edit the test program in `tb/risca_tb.v` to change the instruction sequence.
- VCD output: `risca_tb.vcd`.

## CPU interface

| Port | Width | Dir | Description |
|---|---|---|---|
| `clk` | 1 | in | Clock |
| `rst_n` | 1 | in | Active-low async reset |
| `imem_addr` | 32 | out | Instruction address (byte) |
| `imem_data` | 16 | in | Instruction word |
| `dmem_addr` | 32 | out | Data address (byte) |
| `dmem_wdata` | 32 | out | Store data |
| `dmem_rdata` | 32 | in | Load data |
| `dmem_we` | 1 | out | Write enable |
| `dmem_sel` | 4 | out | Byte write strobe |
| `pc_debug` | 32 | out | Program counter |

## Instructions implemented

NOP, MOV, ADD, SUB, AND, OR, XOR, NOT, MUL, ADDI, SUBI, SHL, SHR,
MOVI, MOVL, LDW, STW, BEQZ, BNEZ, BGTZ, BLTZ,
CALL, RET, JR

## Hazards

- RAW (ALU): resolved by forwarding from EX → ID (no stall)
- Branch: 1-cycle penalty (flush IF/ID on taken branch)
- Load-use: forwarding handles with combinational DMEM

## Status

Build system and testbench exist. No CI configured.
