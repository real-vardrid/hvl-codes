`timescale 1ns/1ps

module traffic_light_controller (
    input  logic       clk,
    input  logic       rst,
    output logic [2:0] ns_light,
    output logic [2:0] ew_light
);

    typedef enum logic [1:0] {
        S0_NS_GRN_EW_RED = 2'b00,
        S1_NS_YLW_EW_RED = 2'b01,
        S2_NS_RED_EW_GRN = 2'b10,
        S3_NS_RED_EW_YLW = 2'b11
    } state_t;

    state_t     state;
    logic [3:0] count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S0_NS_GRN_EW_RED;
            count <= 4'd0;
        end
        else begin
            case (state)
                S0_NS_GRN_EW_RED: begin
                    if (count == 4'd9) begin
                        state <= S1_NS_YLW_EW_RED;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                S1_NS_YLW_EW_RED: begin
                    if (count == 4'd2) begin
                        state <= S2_NS_RED_EW_GRN;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                S2_NS_RED_EW_GRN: begin
                    if (count == 4'd9) begin
                        state <= S3_NS_RED_EW_YLW;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                S3_NS_RED_EW_YLW: begin
                    if (count == 4'd2) begin
                        state <= S0_NS_GRN_EW_RED;
                        count <= 4'd0;
                    end
                    else begin
                        count <= count + 4'd1;
                    end
                end

                default: begin
                    state <= S0_NS_GRN_EW_RED;
                    count <= 4'd0;
                end
            endcase
        end
    end

    always_comb begin
        case (state)
            S0_NS_GRN_EW_RED: begin
                ns_light = 3'b001;
                ew_light = 3'b100;
            end
            S1_NS_YLW_EW_RED: begin
                ns_light = 3'b010;
                ew_light = 3'b100;
            end
            S2_NS_RED_EW_GRN: begin
                ns_light = 3'b100;
                ew_light = 3'b001;
            end
            S3_NS_RED_EW_YLW: begin
                ns_light = 3'b100;
                ew_light = 3'b010;
            end
            default: begin
                ns_light = 3'b100;
                ew_light = 3'b100;
            end
        endcase
    end

endmodule
