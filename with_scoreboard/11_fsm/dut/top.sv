`timescale 1ns/1ps

module fsm_dut (
    input  logic       clk,
    input  logic       rst,
    input  logic       in,
    output logic       out,
    output logic [1:0] state
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        LOAD = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        case (current_state)
            IDLE: begin
                if (in)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end

            LOAD: begin
                if (in)
                    next_state = DONE;
                else
                    next_state = IDLE;
            end

            DONE: begin
                if (!in)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    assign out   = (current_state == DONE);
    assign state = current_state;

endmodule
