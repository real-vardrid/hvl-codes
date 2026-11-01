`timescale 1ns/1ps

module dual_port_ram (
    input  logic       clk,

    input  logic       we_a,
    input  logic [3:0] addr_a,
    input  logic [7:0] data_in_a,
    output logic [7:0] data_out_a,

    input  logic       we_b,
    input  logic [3:0] addr_b,
    input  logic [7:0] data_in_b,
    output logic [7:0] data_out_b
);

    logic [7:0] memory [0:15];

    always_ff @(posedge clk) begin
        if (we_a) begin
            memory[addr_a] <= data_in_a;
        end
        else begin
            data_out_a <= memory[addr_a];
        end
    end

    always_ff @(posedge clk) begin
        if (we_b) begin
            memory[addr_b] <= data_in_b;
        end
        else begin
            data_out_b <= memory[addr_b];
        end
    end

endmodule
