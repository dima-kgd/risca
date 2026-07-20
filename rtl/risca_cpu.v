module risca_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] imem_addr,
    input  wire [15:0] imem_data,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire [3:0]  dmem_sel,
    output wire [31:0] pc_debug
);

    localparam ALU_MOV  = 4'd0;
    localparam ALU_ADD  = 4'd1;
    localparam ALU_SUB  = 4'd2;
    localparam ALU_AND  = 4'd3;
    localparam ALU_OR   = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_NOT  = 4'd6;
    localparam ALU_MUL  = 4'd7;
    localparam ALU_SHL  = 4'd8;
    localparam ALU_SHR  = 4'd9;
    localparam ALU_MOVL = 4'd10;

    localparam WB_ALU = 2'd0;
    localparam WB_DMEM = 2'd1;
    localparam WB_PC2 = 2'd2;

    reg [31:0] pc;
    wire [31:0] pc_next;
    wire        branch_taken;
    wire [31:0] branch_target;

    assign pc_debug = pc;
    assign imem_addr = pc;

    // -----------------------------------------------------------------
    // FETCH stage (IF): PC update
    // -----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0;
        else if (branch_taken)
            pc <= branch_target;
        else
            pc <= pc + 2;
    end

    // -----------------------------------------------------------------
    // IF/ID pipeline register
    // -----------------------------------------------------------------
    reg [15:0] if_id_inst;
    reg [31:0] if_id_pc;
    reg        if_id_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_inst  <= 16'h0000;
            if_id_pc    <= 32'h0;
            if_id_valid <= 1'b0;
        end else if (branch_taken) begin
            if_id_inst  <= 16'h0000;
            if_id_pc    <= 32'h0;
            if_id_valid <= 1'b0;
        end else begin
            if_id_inst  <= imem_data;
            if_id_pc    <= pc;
            if_id_valid <= 1'b1;
        end
    end

    // -----------------------------------------------------------------
    // DECODE stage (ID): register file, instruction decode, forwarding
    // -----------------------------------------------------------------
    reg [31:0] regfile [0:15];
    integer _i;
    initial for (_i = 0; _i < 16; _i = _i + 1) regfile[_i] = 32'b0;

    wire [2:0]  id_opcode = if_id_inst[2:0];
    wire [3:0]  id_rd     = if_id_inst[6:3];
    wire [3:0]  id_rs     = if_id_inst[10:7];
    wire [2:0]  id_func3  = if_id_inst[13:11];
    wire [1:0]  id_func2  = if_id_inst[15:14];
    wire        id_func1  = if_id_inst[7];
    wire [7:0]  id_imm8   = if_id_inst[15:8];
    wire [6:0]  id_imm7   = if_id_inst[15:9];
    wire [2:0]  id_imm3   = if_id_inst[15:13];

    wire [31:0] rf_rd_val = regfile[id_rd];
    wire [31:0] rf_rs_val = regfile[id_rs];

    wire [31:0] ex_wb_data;
    wire [3:0]  ex_wb_rd;
    wire        ex_wb_we;

    wire [31:0] fwd_rd_val = (if_id_valid && ex_wb_we && ex_wb_rd != 4'b0 &&
                              ex_wb_rd == id_rd) ? ex_wb_data : rf_rd_val;
    wire [31:0] fwd_rs_val = (if_id_valid && ex_wb_we && ex_wb_rd != 4'b0 &&
                              ex_wb_rd == id_rs) ? ex_wb_data : rf_rs_val;

    wire [31:0] dec_imm;
    wire [31:0] dec_store_data;
    reg  [3:0]  dec_alu_op;
    reg         dec_reg_we;
    reg  [1:0]  dec_wb_sel;
    reg         dec_mem_we;
    reg         dec_is_load;
    reg  [1:0]  dec_branch_op;
    wire        dec_is_st_ld;
    reg  [31:0] dec_alu_a;
    reg  [31:0] dec_alu_b;

    assign dec_is_st_ld = (id_opcode == 3'b011);

    always @(*) begin
        dec_alu_a    = 32'b0;
        dec_alu_b    = 32'b0;
        dec_alu_op   = ALU_MOV;
        dec_reg_we   = 1'b0;
        dec_wb_sel   = WB_ALU;
        dec_mem_we   = 1'b0;
        dec_is_load  = 1'b0;
        dec_branch_op = 2'b0;

        if (!if_id_valid) begin
        end else case (id_opcode)
            3'b000: begin
                dec_reg_we = 1'b1;
                dec_alu_a  = fwd_rd_val;
                dec_alu_b  = fwd_rs_val;
                case (id_func3)
                    3'b000: dec_alu_op = ALU_MOV;
                    3'b001: dec_alu_op = ALU_ADD;
                    3'b010: dec_alu_op = ALU_SUB;
                    3'b011: dec_alu_op = ALU_AND;
                    3'b100: dec_alu_op = ALU_OR;
                    3'b101: dec_alu_op = ALU_XOR;
                    3'b110: dec_alu_op = ALU_NOT;
                    3'b111: dec_alu_op = ALU_MUL;
                endcase
            end
            3'b001: begin
                dec_reg_we = 1'b1;
                dec_alu_a  = fwd_rd_val;
                dec_alu_b  = {{25{id_imm7[6]}}, id_imm7};
                case (id_func2)
                    2'b00: dec_alu_op = ALU_SHL;
                    2'b01: dec_alu_op = ALU_SHR;
                    2'b10: dec_alu_op = ALU_ADD;
                    2'b11: dec_alu_op = ALU_SUB;
                endcase
            end
            3'b010: begin
                dec_reg_we = 1'b1;
                if (id_func1) begin
                    dec_alu_a = fwd_rd_val;
                    dec_alu_b = {24'b0, id_imm8};
                    dec_alu_op = ALU_MOVL;
                end else begin
                    dec_alu_a = 32'b0;
                    dec_alu_b = {24'b0, id_imm8};
                    dec_alu_op = ALU_MOV;
                end
            end
            3'b011: begin
                dec_alu_a = fwd_rs_val;
                dec_alu_b = {27'b0, id_imm3, 2'b0};
                dec_alu_op = ALU_ADD;
                if (!if_id_inst[11]) begin
                    dec_reg_we  = 1'b1;
                    dec_wb_sel  = WB_DMEM;
                    dec_is_load = 1'b1;
                end else begin
                    dec_mem_we = 1'b1;
                end
            end
            3'b100: begin
                if (id_func2 == 2'b00) dec_branch_op = 2'b01;
                else dec_branch_op = 2'b10;
                dec_alu_a = fwd_rd_val;
            end
            3'b101: begin
            end
            3'b110: begin
                case (id_func2)
                    2'b00, 2'b01: begin
                        dec_reg_we = 1'b1;
                        dec_wb_sel = WB_PC2;
                    end
                    2'b10: begin
                    end
                    2'b11: begin
                    end
                endcase
            end
            3'b111: begin
            end
        endcase
    end

    wire [31:0] dec_branch_offset;

    assign dec_store_data = fwd_rd_val;
    assign dec_branch_offset = {id_imm7[6], id_imm7[6], id_imm7[6], id_imm7[6],
                                id_imm7[6], id_imm7[6], id_imm7[6], id_imm7[6],
                                id_imm7[6], id_imm7[6], id_imm7[6], id_imm7[6],
                                id_imm7[6], id_imm7[6], id_imm7[6], id_imm7[6],
                                id_imm7[6], id_imm7[6], id_imm7[6], id_imm7[6],
                                id_imm7[6], id_imm7[6], id_imm7[6], id_imm7[6],
                                id_imm7[6], id_imm7[5:0], 1'b0};

    // -----------------------------------------------------------------
    // ID/EX pipeline register
    // -----------------------------------------------------------------
    reg [31:0] id_ex_pc;
    reg [3:0]  id_ex_rd;
    reg [31:0] id_ex_alu_a;
    reg [31:0] id_ex_alu_b;
    reg [3:0]  id_ex_alu_op;
    reg        id_ex_reg_we;
    reg [1:0]  id_ex_wb_sel;
    reg        id_ex_mem_we;
    reg        id_ex_is_load;
    reg [1:0]  id_ex_branch_op;
    reg [31:0] id_ex_store_data;
    reg [31:0] id_ex_branch_offset;
    reg        id_ex_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc            <= 32'h0;
            id_ex_rd            <= 4'b0;
            id_ex_alu_a         <= 32'b0;
            id_ex_alu_b         <= 32'b0;
            id_ex_alu_op        <= ALU_MOV;
            id_ex_reg_we        <= 1'b0;
            id_ex_wb_sel        <= WB_ALU;
            id_ex_mem_we        <= 1'b0;
            id_ex_is_load       <= 1'b0;
            id_ex_branch_op     <= 2'b0;
            id_ex_store_data    <= 32'b0;
            id_ex_branch_offset <= 32'b0;
            id_ex_valid         <= 1'b0;
        end else begin
            id_ex_pc            <= if_id_pc;
            id_ex_rd            <= id_rd;
            id_ex_alu_a         <= dec_alu_a;
            id_ex_alu_b         <= dec_alu_b;
            id_ex_alu_op        <= dec_alu_op;
            id_ex_reg_we        <= dec_reg_we;
            id_ex_wb_sel        <= dec_wb_sel;
            id_ex_mem_we        <= dec_mem_we;
            id_ex_is_load       <= dec_is_load;
            id_ex_branch_op     <= dec_branch_op;
            id_ex_store_data    <= dec_store_data;
            id_ex_branch_offset <= dec_branch_offset;
            id_ex_valid         <= if_id_valid;
        end
    end

    // -----------------------------------------------------------------
    // EXECUTE stage (EX): ALU, branch, memory interface, writeback
    // -----------------------------------------------------------------
    wire [31:0] ex_alu_result;
    reg         ex_branch_taken;
    reg [31:0] ex_branch_target;

    assign dmem_addr   = ex_alu_result;
    assign dmem_wdata  = id_ex_store_data;
    assign dmem_we     = id_ex_valid && id_ex_mem_we;
    assign dmem_sel    = 4'b1111;

    assign ex_wb_rd = id_ex_rd;
    assign ex_wb_we = id_ex_valid && id_ex_reg_we;

    reg [31:0] alu_result;
    always @(*) begin
        case (id_ex_alu_op)
            ALU_MOV: alu_result = id_ex_alu_b;
            ALU_ADD: alu_result = id_ex_alu_a + id_ex_alu_b;
            ALU_SUB: alu_result = id_ex_alu_a - id_ex_alu_b;
            ALU_AND: alu_result = id_ex_alu_a & id_ex_alu_b;
            ALU_OR:  alu_result = id_ex_alu_a | id_ex_alu_b;
            ALU_XOR: alu_result = id_ex_alu_a ^ id_ex_alu_b;
            ALU_NOT: alu_result = ~id_ex_alu_b;
            ALU_MUL: alu_result = id_ex_alu_a * id_ex_alu_b;
            ALU_SHL:  alu_result = id_ex_alu_a << id_ex_alu_b[3:0];
            ALU_SHR:  alu_result = id_ex_alu_a >> id_ex_alu_b[3:0];
            ALU_MOVL: alu_result = {id_ex_alu_a[23:0], id_ex_alu_b[7:0]};
            default:  alu_result = 32'b0;
        endcase
    end

    assign ex_alu_result = alu_result;

    always @(*) begin
        ex_branch_taken = 1'b0;
        ex_branch_target = 32'b0;
        if (id_ex_valid && id_ex_branch_op != 2'b00) begin
            ex_branch_taken = (id_ex_branch_op == 2'b01) ? (id_ex_alu_a == 32'b0)
                                                         : (id_ex_alu_a != 32'b0);
            ex_branch_target = id_ex_pc + id_ex_branch_offset;
        end
    end

    assign branch_taken = ex_branch_taken;
    assign branch_target = ex_branch_target;

    assign ex_wb_data = (id_ex_wb_sel == WB_DMEM) ? dmem_rdata :
                        (id_ex_wb_sel == WB_PC2)  ? (id_ex_pc + 2) :
                        ex_alu_result;

    always @(posedge clk) begin
        if (ex_wb_we && ex_wb_rd != 4'b0)
            regfile[ex_wb_rd] <= ex_wb_data;
    end

endmodule
