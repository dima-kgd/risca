`timescale 1ns/1ps

`define MOVI(rd, imm)  (((imm) << 8) | (1'b0 << 7) | ((rd) << 3) | 3'b010)
`define MOVL(rd, imm)  (((imm) << 8) | (1'b1 << 7) | ((rd) << 3) | 3'b010)
`define MOV(rd, rs)    ((3'b000 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define ADD(rd, rs)    ((3'b001 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define SUB(rd, rs)    ((3'b010 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define AND(rd, rs)    ((3'b011 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define OR(rd, rs)     ((3'b100 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define XOR(rd, rs)    ((3'b101 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define NOT(rd, rs)    ((3'b110 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define MUL(rd, rs)    ((3'b111 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b000)
`define ADDI(rd, imm)  (((imm) << 9) | (2'b10 << 7) | ((rd) << 3) | 3'b001)
`define SUBI(rd, imm)  (((imm) << 9) | (2'b11 << 7) | ((rd) << 3) | 3'b001)
`define SHL(rd, imm)   (((imm) << 9) | (2'b00 << 7) | ((rd) << 3) | 3'b001)
`define SHR(rd, imm)   (((imm) << 9) | (2'b01 << 7) | ((rd) << 3) | 3'b001)
`define LDW(rd, rs, imm) (((imm) << 13) | (1'b1 << 12) | (1'b0 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b011)
`define STW(rd, rs, imm) (((imm) << 13) | (1'b1 << 12) | (1'b1 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b011)
`define LDB(rd, rs, imm) (((imm) << 13) | (1'b0 << 12) | (1'b0 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b011)
`define STB(rd, rs, imm) (((imm) << 13) | (1'b0 << 12) | (1'b1 << 11) | ((rs) << 7) | ((rd) << 3) | 3'b011)
`define BEQZ(rd, imm)  (((imm) << 9) | (2'b00 << 7) | ((rd) << 3) | 3'b100)
`define BNEZ(rd, imm)  (((imm) << 9) | (2'b01 << 7) | ((rd) << 3) | 3'b100)
`define BGTZ(rd, imm)  (((imm) << 9) | (2'b10 << 7) | ((rd) << 3) | 3'b100)
`define BLTZ(rd, imm)  (((imm) << 9) | (2'b11 << 7) | ((rd) << 3) | 3'b100)
`define CALLI(rd, imm) (((imm) << 9) | (2'b00 << 7) | ((rd) << 3) | 3'b110)
`define CALLR(rd)      ((2'b01 << 7) | ((rd) << 3) | 3'b110)
`define RET(rd)        ((2'b10 << 7) | ((rd) << 3) | 3'b110)
`define JR(rd, imm)    (((imm) << 9) | (2'b11 << 7) | ((rd) << 3) | 3'b110)
`define NOP            16'h0000

module risca_tb;

    reg         clk;
    reg         rst_n;

    reg  [15:0] imem [0:1023];
    wire [31:0] imem_addr;
    wire [15:0] imem_data;

    reg  [31:0] dmem [0:1023];
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_sel;

    wire [31:0] pc_debug;

    assign imem_data = imem[imem_addr[31:1]];
    assign dmem_rdata = dmem[dmem_addr[31:2]];

    risca_cpu cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_data  (imem_data),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_we    (dmem_we),
        .dmem_sel   (dmem_sel),
        .pc_debug   (pc_debug)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (dmem_we) begin
            if (dmem_sel[0]) dmem[dmem_addr[31:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_sel[1]) dmem[dmem_addr[31:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_sel[2]) dmem[dmem_addr[31:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_sel[3]) dmem[dmem_addr[31:2]][31:24] <= dmem_wdata[31:24];
        end
    end

    initial begin
        $dumpfile("risca_tb.vcd");
        $dumpvars(0, risca_tb);

        imem[0]  = `MOVI(1, 10);      // 0x00: R1 = 10
        imem[1]  = `MOVI(2, 20);      // 0x02: R2 = 20
        imem[2]  = `MOV(3, 1);        // 0x04: R3 = R1 = 10
        imem[3]  = `ADD(3, 2);        // 0x06: R3 = 10 + 20 = 30
        imem[4]  = `MOV(4, 3);        // 0x08: R4 = R3 = 30
        imem[5]  = `SUB(4, 2);        // 0x0A: R4 = 30 - 20 = 10
        imem[6]  = `STW(3, 0, 0);     // 0x0C: mem[0] = 30
        imem[7]  = `LDW(5, 0, 0);     // 0x0E: R5 = 30
        imem[8]  = `MOVI(6, 0);       // 0x10: R6 = 0
        imem[9]  = `BNEZ(6, 2);       // 0x12: if R6!=0 skip NOP (NOT taken)
        imem[10] = `NOP;              // 0x14:
        imem[11] = `ADD(5, 5);        // 0x16: R5 = 30 + 30 = 60
        imem[12] = `MOVI(7, 2);       // 0x18: R7 = 2
        imem[13] = `MOV(7, 6);        // 0x1A: R7 = R6 = 0
        imem[14] = `BEQZ(7, 2);       // 0x1C: if R7==0 skip NOP (TAKEN to 0x20)
        imem[15] = `NOP;              // 0x1E: (skipped)
        imem[16] = `BEQZ(0, 0);       // 0x20: infinite loop

        clk = 0;
        rst_n = 0;
        #15 rst_n = 1;

        #600;

        $display("--- Simulation complete ---");
        $display("R1  = %0d (expected 10)",  cpu.regfile[1]);
        $display("R2  = %0d (expected 20)",  cpu.regfile[2]);
        $display("R3  = %0d (expected 30)",  cpu.regfile[3]);
        $display("R4  = %0d (expected 10)",  cpu.regfile[4]);
        $display("R5  = %0d (expected 60)",  cpu.regfile[5]);
        $display("R6  = %0d (expected 0)",   cpu.regfile[6]);
        $display("R7  = %0d (expected 0)",   cpu.regfile[7]);
        $display("mem[0] = %0d (expected 30)", dmem[0]);

        if (cpu.regfile[1] == 10 && cpu.regfile[2] == 20 &&
            cpu.regfile[3] == 30 && cpu.regfile[4] == 10 &&
            cpu.regfile[5] == 60 && cpu.regfile[6] == 0  &&
            cpu.regfile[7] == 0  && dmem[0] == 30)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED ***");

        $finish;
    end

endmodule
