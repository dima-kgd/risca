# RiscA

3-stage pipelined RiscA CPU implementation in Verilog.

## Architecture

- **Little-Endian**, 32-bit bus, 16-bit instructions (2 per 32-bit word)
- 16 general-purpose registers R0–R15 (32-bit), stack at R15, link register at R14
- Harvard architecture (separate instruction and data buses)
- 3-stage pipeline: Fetch → Decode → Execute
- RAW hazards resolved by forwarding from EX → ID (no stall)
- Branch: 1-cycle penalty (flush IF/ID on taken branch)
- Load-use: forwarding handles with combinational DMEM

## Interrupt vectors

| Address | Vector |
|---------|--------|
| `0x00`  | Reset  |
| `0x02`  | Timer  |
| `0x04`  | Syscall |
| `0x06+` | Reserved |

## Files

| Path | Contents |
|------|----------|
| `rtl/risca_cpu.v` | 3-stage pipeline CPU |
| `tb/risca_tb.v` | Testbench with IMEM/DEM arrays, instruction macros, VCD dump |
| `sim.bat` | Compile & simulate with iverilog + GTKWave |

## Simulation

```bat
sim.bat
```

Compiles with iverilog (`-g2012`), runs VVP simulation, opens GTKWave waveform viewer.

VCD output: `risca_tb.vcd`.

## Instructions implemented

`NOP`, `MOV`, `ADD`, `SUB`, `AND`, `OR`, `XOR`, `NOT`, `MUL`, `ADDI`, `SUBI`, `SHL`, `SHR`, `MOVI`, `MOVL`, `LDW`, `STW`, `BEQZ`, `BNEZ`, `BGTZ`, `BLTZ`, `CALL`, `RET`, `JR`

Refer to `RiscA.MD` for the canonical ISA reference.
