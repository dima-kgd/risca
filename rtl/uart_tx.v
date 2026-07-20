module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       wr_en,
    input  wire [7:0] data_in,
    output reg        tx,
    output reg        busy
);

    parameter BAUD_DIV = 868;

    reg [9:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [1:0] state;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            busy      <= 1'b0;
            state     <= S_IDLE;
            baud_cnt  <= 0;
            bit_cnt   <= 0;
            shift_reg <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    baud_cnt  <= 0;
                    if (wr_en) begin
                        shift_reg <= data_in;
                        bit_cnt   <= 0;
                        state     <= S_START;
                        busy      <= 1'b1;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 0;
                        state    <= S_DATA;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                S_DATA: begin
                    tx <= shift_reg[0];
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt  <= 0;
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        if (bit_cnt == 7) begin
                            state <= S_STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 0;
                        state    <= S_IDLE;
                        busy     <= 1'b0;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule
