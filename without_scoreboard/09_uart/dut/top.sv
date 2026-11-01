`timescale 1ns/1ps

module uart_top #(
    parameter CLK_FREQ  = 96000,
    parameter BAUD_RATE = 9600
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    input  logic       rx,
    output logic       tx,
    output logic [7:0] rx_data,
    output logic       tx_done,
    output logic       rx_done
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t      tx_state, rx_state;
    logic [2:0]  tx_idx, rx_idx;
    logic [7:0]  tx_reg, rx_reg;
    logic [15:0] baud_cnt;
    logic        baud_tick;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_cnt  <= 16'd0;
            baud_tick <= 1'b0;
        end
        else if (baud_cnt == CLKS_PER_BIT - 1) begin
            baud_cnt  <= 16'd0;
            baud_tick <= 1'b1;
        end
        else begin
            baud_cnt  <= baud_cnt + 1'b1;
            baud_tick <= 1'b0;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= IDLE;
            tx       <= 1'b1;
            tx_done  <= 1'b0;
            tx_idx   <= 3'd0;
            tx_reg   <= 8'h00;
        end
        else begin
            tx_done <= 1'b0;
            case (tx_state)
                IDLE: begin
                    tx     <= 1'b1;
                    tx_idx <= 3'd0;
                    if (tx_start) begin
                        tx_reg   <= tx_data;
                        tx_state <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        tx       <= 1'b0;
                        tx_state <= DATA;
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        tx <= tx_reg[tx_idx];
                        if (tx_idx == 3'd7) begin
                            tx_idx   <= 3'd0;
                            tx_state <= STOP;
                        end
                        else begin
                            tx_idx <= tx_idx + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        tx       <= 1'b1;
                        tx_done  <= 1'b1;
                        tx_state <= IDLE;
                    end
                end

                default: tx_state <= IDLE;
            endcase
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state <= IDLE;
            rx_data  <= 8'h00;
            rx_done  <= 1'b0;
            rx_idx   <= 3'd0;
            rx_reg   <= 8'h00;
        end
        else begin
            rx_done <= 1'b0;
            case (rx_state)
                IDLE: begin
                    rx_idx <= 3'd0;
                    if (baud_tick && rx == 1'b0) begin
                        rx_state <= DATA;
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        rx_reg[rx_idx] <= rx;
                        if (rx_idx == 3'd7) begin
                            rx_idx   <= 3'd0;
                            rx_state <= STOP;
                        end
                        else begin
                            rx_idx <= rx_idx + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (rx == 1'b1) begin
                            rx_data <= rx_reg;
                            rx_done <= 1'b1;
                        end
                        rx_state <= IDLE;
                    end
                end

                default: rx_state <= IDLE;
            endcase
        end
    end

endmodule
