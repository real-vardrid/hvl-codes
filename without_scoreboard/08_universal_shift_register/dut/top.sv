`timescale 1ns/1ps

module universal_shift_register (
    input  logic       clk,
    input  logic       rst,
    input  logic [1:0] sel,
    input  logic       sin_left,
    input  logic       sin_right,
    input  logic [3:0] pdata,
    output logic [3:0] q
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            q <= 4'b0000;
        end
        else begin
            case (sel)
                2'b00:   q <= q;
                2'b01:   q <= {sin_left, q[3:1]};
                2'b10:   q <= {q[2:0], sin_right};
                2'b11:   q <= pdata;
                default: q <= q;
            endcase
        end
    end

endmodule
