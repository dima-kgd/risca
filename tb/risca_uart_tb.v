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

module risca_uart_tb;

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
    wire        uart_tx_serial;
    wire        uart_busy;

    localparam BAUD_DIV = 868;

    assign imem_data = imem[imem_addr[31:1]];

    wire is_uart_tx   = (dmem_addr == 32'hFFFF0003);
    wire is_uart_busy  = (dmem_addr == 32'hFFFF0004);
    wire is_mmio_addr  = is_uart_tx || is_uart_busy;

    assign dmem_rdata = is_uart_busy ? {31'b0, uart_busy} :
                        is_uart_tx   ? 32'b0 :
                        dmem[dmem_addr[31:2]];

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

    wire uart_tx_wr = dmem_we && is_uart_tx;

    uart_tx #(.BAUD_DIV(BAUD_DIV)) uart (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (uart_tx_wr),
        .data_in (dmem_wdata[7:0]),
        .tx      (uart_tx_serial),
        .busy    (uart_busy)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (dmem_we && !is_mmio_addr) begin
            if (dmem_sel[0]) dmem[dmem_addr[31:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_sel[1]) dmem[dmem_addr[31:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_sel[2]) dmem[dmem_addr[31:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_sel[3]) dmem[dmem_addr[31:2]][31:24] <= dmem_wdata[31:24];
        end
    end

    reg [2:0] uart_pass_count;
    reg [2:0] uart_fail_count;

    task uart_check;
        input [7:0] expected;
        reg [7:0] received;
        integer i;
        begin
            @(negedge uart_tx_serial);
            repeat (BAUD_DIV / 2) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                repeat (BAUD_DIV) @(posedge clk);
                received[i] = uart_tx_serial;
            end
            repeat (BAUD_DIV) @(posedge clk);
            if (received == expected) begin
                $display("UART OK: char '%c' (0x%02h)", expected, expected);
                uart_pass_count = uart_pass_count + 1;
            end else begin
                $display("UART ERROR: expected 0x%02h, got 0x%02h", expected, received);
                uart_fail_count = uart_fail_count + 1;
            end
        end
    endtask

    integer i;
    initial begin
        $dumpfile("risca_uart_tb.vcd");
        $dumpvars(0, risca_uart_tb);

        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 16'h0000;
            dmem[i] = 32'h00000000;
        end

        imem[0]  = `MOVI(1, 8'hFF);       // R1 = 0x000000FF
        imem[1]  = `MOVL(1, 8'hFF);       // R1 = 0x0000FFFF
        imem[2]  = `MOVL(1, 8'h00);       // R1 = 0x00FFFF00
        imem[3]  = `MOVL(1, 8'h03);       // R1 = 0xFFFF0003  UART_TX

        imem[4]  = `MOVI(2, 8'hFF);       // R2 = 0x000000FF
        imem[5]  = `MOVL(2, 8'hFF);       // R2 = 0x0000FFFF
        imem[6]  = `MOVL(2, 8'h00);       // R2 = 0x00FFFF00
        imem[7]  = `MOVL(2, 8'h04);       // R2 = 0xFFFF0004  UART_TX_BUSY

        imem[8]  = `MOVI(3, 8'h48);       // R3 = 'H'
        imem[9]  = `LDB(4, 2, 0);         // R4 = busy
        imem[10] = `BNEZ(4, 7'h7F);       // if busy, poll again
        imem[11] = `STB(3, 1, 0);         // write 'H' to UART

        imem[12] = `MOVI(3, 8'h65);       // R3 = 'e'
        imem[13] = `LDB(4, 2, 0);
        imem[14] = `BNEZ(4, 7'h7F);
        imem[15] = `STB(3, 1, 0);

        imem[16] = `MOVI(3, 8'h6C);       // R3 = 'l'
        imem[17] = `LDB(4, 2, 0);
        imem[18] = `BNEZ(4, 7'h7F);
        imem[19] = `STB(3, 1, 0);

        imem[20] = `MOVI(3, 8'h6C);       // R3 = 'l'
        imem[21] = `LDB(4, 2, 0);
        imem[22] = `BNEZ(4, 7'h7F);
        imem[23] = `STB(3, 1, 0);

        imem[24] = `MOVI(3, 8'h6F);       // R3 = 'o'
        imem[25] = `LDB(4, 2, 0);
        imem[26] = `BNEZ(4, 7'h7F);
        imem[27] = `STB(3, 1, 0);

        imem[28] = `MOVI(3, 8'h0A);       // R3 = '\n'
        imem[29] = `LDB(4, 2, 0);
        imem[30] = `BNEZ(4, 7'h7F);
        imem[31] = `STB(3, 1, 0);

        imem[32] = `BEQZ(0, 0);           // halt

        clk   = 0;
        rst_n = 0;
        uart_pass_count = 0;
        uart_fail_count = 0;

        #15 rst_n = 1;

        uart_check("H");
        uart_check("e");
        uart_check("l");
        uart_check("l");
        uart_check("o");
        uart_check("\n");

        @(posedge clk);

        $display("");
        $display("--- UART Test Complete ---");
        $display("Characters checked: %0d", uart_pass_count + uart_fail_count);

        if (uart_fail_count == 0)
            $display("*** UART TEST PASSED ***");
        else
            $display("*** UART TEST FAILED: %0d error(s) ***", uart_fail_count);

        $finish;
    end

endmodule
