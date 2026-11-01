`timescale 1ns/1ps

module arbiter (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] req,
    output logic [3:0] grant
);

    always_ff @(posedge clk) begin
        if (rst) begin
            grant <= 4'b0000;
        end
        else begin
            casex (req)
                4'b1xxx: grant <= 4'd8;
                4'b01xx: grant <= 4'd4;
                4'b001x: grant <= 4'd2;
                4'b0001: grant <= 4'd1;
                default: grant <= 4'd0;
            endcase
        end
    end

endmodule
