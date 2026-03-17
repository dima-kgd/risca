# RiscA
RiscA 32 bit processor.

Risc A(Basic) 32 bit processor with 32 bit address bus and 32 bit data bus.

Byte order: Little-Endian.

ALU: add, sub, shl, shr, and, or, xor

Insructions: all 16 bit. Fetching from memory 2 instruction as data bus is 32 bit.

16 General Purpose Registers (32 bit):
```
	R0 - R15
	Bank 0: R0 - R7 (all opcodes)
	Bank 1: R8 - R15 (extended; only 0, 2, 3 opcodes)
```
2 Hidden registers (not banked):
```
	LR - link register, available to load\restore using common registers
	SP - stack pointer, available to load\restore using common registers
```

RiscA could execute some operation simultaneously (Dual-Issue (ALU + MEM),(ALU + ALU)), if target registers in different reg bank.

Example:
```
		LD.0 R0, 0xFF
		LD.D R8, [R1]
	or
		LD.0 R1,0x05
		ADD  R9,0x01
```

Current program pointer: PC

Mem copy sample (R2 source, R3 target, R4 size)
```
loop:
	LD.B R0, [R2++]
	ST.B [R3++], R0
	DJNZ R4, loop
```

Insctruction format.

1) 2 Register operations
```
+--------+- ------+------------+-------+-----------+
|15 14 13| 12 11  | 10 9 8 7 6 | 5 4 3 | 2 1 0     |
| Rs(3)  | Ex(2)  | func(5)    | Rd(3) | opcode(3) |
+--------+--------+------------+-------+-----------+
```

3) 3 Register operations
```
+--------+------+--------+-------+-------+-----------+
|15 14 13| 12 11| 10 9   | 8 7 6 | 5 4 3 | 2 1 0     |
| Rs(3)  | Ex(2)| func(2)| Rx(3) | Rd(3) | opcode(3) |
+--------+------+--------+-------+-------+-----------+
```

4) 7 bit Immediate operations
```
+--------------------+---------+-------+-----------+
|15 14 13 12 11 10 9 | 8 7 6   | 5 4 3 | 2 1 0     |
|        Number(7)   | func(3) | Rd(3) | opcode(3) |
+--------------------+---------+-------+-----------+
```

5) 8 bit Immediate operations
```
+----------------------+-------+-------+-----------+
|15 14 13 12 11 10 9 8 | 7 6   | 5 4 3 | 2 1 0     |
|        Number(8)     |func(2)| Rd(3) | opcode(3) |
+----------------------+-------+-------+-----------+
```

6) 13 bit Immediate operations
```
+--------------------------------------+-----------+
|15 14 13 12 11 10 9 8   7 6     5 4 3 | 2 1 0     |
|        Number(13)                    | opcode(3) |
+--------------------------------------+-----------+
```

Opcodes.

0) ALU REG, REG (2 Register operations) Ex could be used for extentions 
```
	Ex(0 bit) - register bank for Rd
	Ex(1 bit) - register bank for Rs
	func:
		0) Rd = Rs
		1) ADD Rd = Rd + Rs
		2) SUB Rd = Rd - Rs
		3) SHL Rd = Rd << Rs & 31 (bits)
		4) SHR Rd = Rd >> Rs & 31 (bits)
		5) AND Rd = Rd and Rs
		6) OR  Rd = Rd or  Rs
		7) XOR Rd = Rd xor Rs
		8) NOT Rd = ~Rd
		9) MUL Rd = Rd * Rs
		10) LD  Rd = SP
		11) LD  Rd = LR
		12) LD  SP = Rs
		13) LD  LR = Rs
		14) INT Rs, Rd; Rs - interrupt number, Rd - interrupt result
		...
		31)
```

1) LD REG, IMM (8 bit Immediate operations)
```
	LD.Byte Rd = IMM; func: register byte number = 0-3 
```

2) ALU REG, IMM (7 bit Immediate operations)
```
	func(3 bit) = register bank (0 or 1)
	func(0-2 bits):
		0) ADD/SUB: Rd = Rd + (signed(IMM))
		1) SHL/SHR: Rd = << or >> signed(IMM & 31)
		2) LDI Rd = [PC + signed(IMM)]; 32 bit constant loading, IMM in 32 bit dword (-512 ... +512 bytes)
		3) DJNZ Rd, PC + signed(IMM); Rd-- if not zero, jump taken
```

3) LD\ST REG <-> MEM (2 Register operations)
```
	MEM = Rd
	B: 8 bit byte    alignment = 1
	W: 16 bit word   alignment = 2
	D: 32 bit dword  alignment = 4
	Ex(0 bit) - register bank for Rd
	Ex(1 bit) - register bank for Rs
	func:
		0) LD.B Rs, [Rd];
		1) LD.W Rs, [Rd];
		2) LD.D Rs, [Rd];
		3) ST.B [Rd], Rs;
		4) ST.W [Rd], Rs;
		5) ST.D [Rd], Rs;
		6) LD.B Rs, [Rd++];
		7) LD.W Rs, [Rd++];
		8) LD.D Rs, [Rd++];
		9) ST.B [Rd++], Rs;
		10) ST.W [Rd++], Rs;
		11) ST.D [Rd++], Rs;
		12) LD.B Rs, [Rd--];
		13) LD.W Rs, [Rd--];
		14) LD.D Rs, [Rd--];
		15) ST.B [Rd--], Rs;
		16) ST.W [Rd--], Rs;
		17) ST.D [Rd--], Rs;
		18) LD.B Rs, [Rd+R(2+Ex)];	R2-R5; Only Bank 0
		19) ST.B [Rd+R(2+Ex)], Rs;	R2-R5; Only Bank 0
		20) LD.W Rs, [Rd+R(2+Ex)];	R2-R5; Only Bank 0
		21) ST.W [Rd+R(2+Ex)], Rs;	R2-R5; Only Bank 0
		22) LD.D Rs, [Rd+R(2+Ex)];	R2-R5; Only Bank 0
		23) ST.D [Rd+R(2+Ex)], Rs;	R2-R5; Only Bank 0
		24)	PUSH Rs; ST.D [--SP], Rs
		25) POP  Rd; LD.D Rd, [SP++]
		26) PUSH LR; ST.D [--SP], LR
		27) POP  LR; LD.D LR, [SP++]
```

4) LD\ST REG <-> MEM + IMM (3 Register operations)
```
	IMM = Ex(2)+Rx(3) = 5 bit = -16 ... +16 (0 not uzed, use opcode 3 instead) ; bytes for 8 bit acces, 32 bit dword for 32 bit access (-64...+64 bytes)
	func:
		0) LD.B Rd, [Rs + IMM]; 8bit access;
		1) ST.B [Rs + IMM], Rd; 8bit access;
		2) LD.D Rd, [Rs + IMM]; 32bit access;
		3) ST.D [Rs + IMM], Rd; 32bit access;
```

5) JMP\CALL\RET Rd (3 Register operations)
```
	Address: Rd
	Ex:
		0) JMP func Rd;
		1) CALL func Rd; LR = PC + 2; Return address + 1 (next instruction) 
		2) RET  func;    PC = LR
		3) Future extentions (RETI)
	func: 
		0) 
		1) Rs == Rx
		2) Rs != Rx
		3) Rs >= Rx
```

7) JMP RELATIVE (3 Register operations)
```
	Rx=0: JMP PC+signed(IMM); IMM = Rs(3)+Ex(2)+func(2)+Rd(3) = 10 bit (-1024 ... +1024 bytes)
		JMP cond Rs, Rd PC+signed(IMM); IMM = Ex(2)+func(2) = 4 bit (-16 ... +16 bytes)
		Rx=1: Rs == Rd
		Rx=2: Rs != Rd
		Rx=3: Rs >  Rd
		Rx=4: Rs >= Rd
		Rx=5: Rs <  Rd
		Rx=6: Rs <= Rd
		Rx=7:
```

8) CALL RELATIVE PC + IMM(signed) (13 bit Immediate operations); LR = PC + 2; Return address + 1 (next instruction) 
```
		IMM = -8K ... +8K bytes; in instructions, not bytes (Number*2)
```
