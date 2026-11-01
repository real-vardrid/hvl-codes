`timescale 1ns/1ps

module traffic_light_controller (
    input  logic clk,
    input  logic rst,
    output logic red,
    output logic yellow,
    output logic green
);

    typedef enum logic [1:0] {
        RED    = 2'b00,
        GREEN  = 2'b01,
        YELLOW = 2'b10
    } state_t;

    state_t     state;
    logic [3:0] count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= RED;
            count <= 4'd0;
        end
        else begin
            case (state)
                RED: begin
                    if (count == 4'd9) begin
                        state <= GREEN;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                GREEN: begin
                    if (count == 4'd9) begin
                        state <= YELLOW;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                YELLOW: begin
                    if (count == 4'd2) begin
                        state <= RED;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                default: begin
                    state <= RED;
                    count <= 4'd0;
                end
            endcase
        end
    end

    always_comb begin
        red    = 1'b0;
        yellow = 1'b0;
        green  = 1'b0;
        case (state)
            RED:     red    = 1'b1;
            GREEN:   green  = 1'b1;
            YELLOW:  yellow = 1'b1;
            default: red    = 1'b1;
        endcase
    end

endmodule
