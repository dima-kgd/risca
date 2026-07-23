module risca (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] imem_addr,
    input  wire [15:0] imem_data,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire [3:0]  dmem_sel
);
    // debug only !!! remove
    // Для отладки в GTKWave - отдельные сигналы для каждого регистра
    wire [31:0] r0, r1, r2, r3, r4, r5, r6, r7;
    wire [31:0] r8, r9, r10, r11, r12, r13, r14, r15;
    assign r0  = regfile[0];
    assign r1  = regfile[1];
    assign r2  = regfile[2];
    assign r3  = regfile[3];
    assign r4  = regfile[4];
    assign r5  = regfile[5];
    assign r6  = regfile[6];
    assign r7  = regfile[7];
    assign r8  = regfile[8];
    assign r9  = regfile[9];
    assign r10 = regfile[10];
    assign r11 = regfile[11];
    assign r12 = regfile[12];
    assign r13 = regfile[13];
    assign r14 = regfile[14];
    assign r15 = regfile[15];
    // end debug only

    // opcodes
    localparam OP_ALU_RR   = 3'd0;
    localparam OP_ALU_RI   = 3'd1;
    localparam OP_MOV_RI    = 3'd2;
    localparam OP_ST_LD    = 3'd3;
    localparam OP_BRANCH   = 3'd4;
    localparam OP_LDI      = 3'd5;
    localparam OP_CALL_RET = 3'd6;
    localparam OP_INT      = 3'd7;

    // ALU
    localparam ALU_MOV   = 4'd0;
    localparam ALU_ADD   = 4'd1;
    localparam ALU_SUB   = 4'd2;
    localparam ALU_AND   = 4'd3;
    localparam ALU_OR    = 4'd4;
    localparam ALU_XOR   = 4'd5;
    localparam ALU_NOT   = 4'd6;
    localparam ALU_MUL   = 4'd7;
    localparam ALU_SHL   = 4'd8;
    localparam ALU_SHR   = 4'd9;
    localparam ALU_MOVI   = 4'd10;
    localparam ALU_MOVL   = 4'd11;

    // MOVI and MOVH
    localparam MOVI_MOV  = 3'd0;
    localparam MOVL_MOV  = 3'd1;

    // ALU IMM 
    localparam ALU_SHLI   = 2'd0;
    localparam ALU_SHRI   = 2'd1;
    localparam ALU_ADDI  = 2'd2;
    localparam ALU_SUBI  = 2'd3;

    reg [31:0] pc;
    reg [31:0] regfile [0:15];
    integer _i;
    initial for (_i = 0; _i < 16; _i = _i + 1) regfile[_i] = 32'b0;

    assign imem_addr = pc;

    // debug only !!! remove
    reg [15:0] id_instr;
    reg [15:0] ex_instr;
    reg [15:0] mem_instr;
    reg [15:0] wb_instr;
    // end debug only


    // IF stage ----------------------------------------------------------
    reg [15:0] if_instr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
            if_instr <= 16'h0000;
        end
        else begin
            pc <= pc + 2;
            if_instr <= imem_data;
        end
    end

    // ID stage ----------------------------------------------------------
    wire [2:0]  i_opcode = if_instr[2:0];
    wire [3:0]  i_rd     = if_instr[6:3];
    wire [3:0]  i_rs     = if_instr[10:7];
    wire [2:0]  i_func3  = if_instr[13:11];
    wire [1:0]  i_func2  = if_instr[8:7];
    wire        i_func1  = if_instr[7];
    wire [7:0]  i_imm8   = if_instr[15:8];
    wire [6:0]  i_imm7   = if_instr[15:9];
    
    reg [2:0] id_opcode;
    reg [3:0] id_rs;
    reg [3:0] id_rd;
    reg [2:0] id_func3;

    reg [31:0] id_alu_in_a;
    reg [31:0] id_alu_in_b;
    reg [3:0]  id_alu_op;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_opcode <= 3'd0;
            id_rs <= 4'd0;
            id_rd <= 4'd0;
            id_func3 <= 3'd0;
            id_alu_in_a <= 32'd0;
            id_alu_in_b <= 32'd0;
            id_alu_op <= 3'd0;
            id_instr <= 16'd0; //debug
        end
        else begin
            id_opcode <= i_opcode;
            id_rs <= i_rs;
            id_rd <= i_rd;
            id_func3 <= i_func3;
            id_alu_in_a <= 32'd0;
            id_alu_in_b <= 32'd0;
            id_instr <= if_instr; //debug
            case (i_opcode)
                OP_ALU_RR: begin
                    id_alu_in_a <= regfile[i_rd];
                    id_alu_in_b <= regfile[i_rs];
                    id_alu_op <= i_func3;
                end
                OP_ALU_RI: begin
                    id_alu_in_a <= regfile[i_rd];
                    id_alu_in_b <= {{24{i_imm7[6]}}, i_imm7};
                    id_alu_op <= i_func3;
                    case (i_func2) 
                        ALU_SHLI: id_alu_op <= ALU_SHL;
                        ALU_SHRI: id_alu_op <= ALU_SHR;
                        ALU_ADDI: id_alu_op <= ALU_ADD;
                        ALU_SUBI: id_alu_op <= ALU_SUB;
                    endcase
                end
                OP_MOV_RI: begin
                    id_alu_in_a <= regfile[i_rd];
                    id_alu_in_b <= {{24{i_imm8[7]}}, i_imm8}; // sign-extend immediate
                    case (i_func1)
                        MOVI_MOV: id_alu_op <= ALU_MOVI;
                        MOVL_MOV: id_alu_op <= ALU_MOVL;
                    endcase
                end
            endcase
        end
    end

    // EX stage ----------------------------------------------------------
    reg [31:0] ex_alu_out;
    reg [3:0]  ex_rd;
    reg [2:0]  ex_opcode;

    wire [31:0] fwd_in_a;
    wire [31:0] fwd_in_b;

    // Forwarding logic
    wire is_src_a_valid = (id_opcode == OP_ALU_RR) || (id_opcode == OP_ALU_RI) || (id_opcode == OP_MOV_RI);
    wire is_src_b_valid = (id_opcode == OP_ALU_RR);

    assign fwd_in_a = (is_src_a_valid && (id_rd == ex_rd)) ? ex_alu_out :
                      (is_src_a_valid && (id_rd == mem_rd)) ? mem_data_out :
                      id_alu_in_a;
    assign fwd_in_b = (is_src_b_valid && (id_rs == ex_rd) && (ex_rd != 0)) ? ex_alu_out :
                      (is_src_b_valid && (id_rs == mem_rd) && (mem_rd != 0)) ? mem_data_out :
                      id_alu_in_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_alu_out <= 32'd0;
            ex_rd <= 4'd0;
            ex_instr <= 16'd0; //debug
            ex_opcode <= 3'd0;
        end
        else begin
            ex_instr <= id_instr; //debug
            case (id_alu_op)
                ALU_MOV: ex_alu_out <= fwd_in_b;
                ALU_ADD: ex_alu_out <= fwd_in_a + fwd_in_b;
                ALU_SUB: ex_alu_out <= fwd_in_a - fwd_in_b;
                ALU_AND: ex_alu_out <= fwd_in_a & fwd_in_b;
                ALU_OR:  ex_alu_out <= fwd_in_a | fwd_in_b;
                ALU_XOR: ex_alu_out <= fwd_in_a ^ fwd_in_b;
                ALU_NOT: ex_alu_out <= ~fwd_in_b;
                ALU_MUL: ex_alu_out <= fwd_in_a * fwd_in_b;
                ALU_SHL: ex_alu_out <= fwd_in_a << fwd_in_b[4:0];
                ALU_SHR: ex_alu_out <= fwd_in_a >> fwd_in_b[4:0];
                ALU_MOVI: ex_alu_out <= fwd_in_b;
                ALU_MOVL: ex_alu_out <= {fwd_in_a[23:0], fwd_in_b[7:0]}; // shift left 8 bits and insert immediate
            endcase
            ex_rd <= id_rd;
            ex_opcode <= id_opcode;
        end
    end

    // MEM stage ----------------------------------------------------------
    reg [31:0] mem_data_out;
    reg [3:0]  mem_rd;
    reg [2:0]  mem_opcode;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_data_out <= 32'd0;
            mem_rd <= 4'd0;
            mem_opcode <= 3'd0;
            mem_instr <= 16'd0; //debug
        end
        else begin
            mem_instr <= ex_instr; //debug
            case (ex_opcode)
                OP_ALU_RR: mem_data_out <= ex_alu_out;
                OP_ALU_RI: mem_data_out <= ex_alu_out;
                OP_MOV_RI: mem_data_out <= ex_alu_out;
            endcase
            mem_rd <= ex_rd;
            mem_opcode <= ex_opcode;
        end
    end

    // WB stage  ----------------------------------------------------------
    always @(posedge clk  or negedge rst_n) begin
        if (!rst_n) begin
            wb_instr <= 16'd0;
        end
        else begin
            wb_instr <= mem_instr;
            case (mem_opcode)
                OP_ALU_RR: regfile[mem_rd] <= mem_data_out;
                OP_ALU_RI: regfile[mem_rd] <= mem_data_out;
                OP_MOV_RI: regfile[mem_rd] <= mem_data_out;
            endcase
        end
    end

endmodule
