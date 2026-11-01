`timescale 1ns/1ps

module synchronous_fifo #(
    parameter DATA_WIDTH = 4,
    parameter DEPTH      = 4,
    parameter PTR_WIDTH  = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  full,
    output logic                  empty
);

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    logic [PTR_WIDTH-1:0]  wr_ptr;
    logic [PTR_WIDTH-1:0]  rd_ptr;
    logic [$clog2(DEPTH+1)-1:0] count;
    integer i;

    always_comb begin
        full  = (count == DEPTH);
        empty = (count == 0);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            count    <= '0;
            data_out <= '0;
            for (i = 0; i < DEPTH; i = i + 1)
                memory[i] <= '0;
        end
        else begin
            if (wr_en && !full) begin
                memory[wr_ptr] <= data_in;
                if (wr_ptr == DEPTH - 1)
                    wr_ptr <= '0;
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            if (rd_en && !empty) begin
                data_out <= memory[rd_ptr];
                if (rd_ptr == DEPTH - 1)
                    rd_ptr <= '0;
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            case ({(wr_en && !full), (rd_en && !empty)})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                2'b11:   count <= count;
                default: count <= count;
            endcase
        end
    end

endmodule
