`timescale 1ns/1ps

module single_port_ram (
    input  logic       clk,
    input  logic       we,
    input  logic [3:0] addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);

    logic [7:0] memory [0:15];

    always_ff @(posedge clk) begin
        if (we) begin
            memory[addr] <= data_in;
        end
        else begin
            data_out <= memory[addr];
        end
    end

endmodule
