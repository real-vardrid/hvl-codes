`timescale 1ns/1ps

module axi4_lite_slave (
    input  logic        aclk,
    input  logic        aresetn,

    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,

    input  logic [31:0] wdata,
    input  logic        wvalid,
    output logic        wready,

    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,

    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,

    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready
);

    logic [31:0] register_file [0:15];
    integer i;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
            bresp   <= 2'b00;
            arready <= 1'b0;
            rvalid  <= 1'b0;
            rresp   <= 2'b00;
            rdata   <= 32'h0000_0000;
            for (i = 0; i < 16; i = i + 1)
                register_file[i] <= 32'h0000_0000;
        end
        else begin

            if (awvalid && wvalid) begin
                awready                     <= 1'b1;
                wready                      <= 1'b1;
                register_file[awaddr[3:0]]  <= wdata;
                bvalid                      <= 1'b1;
                bresp                       <= 2'b00;
            end
            else begin
                awready <= 1'b0;
                wready  <= 1'b0;
                if (bready && bvalid)
                    bvalid <= 1'b0;
            end

            if (arvalid) begin
                arready <= 1'b1;
                rdata   <= register_file[araddr[3:0]];
                rvalid  <= 1'b1;
                rresp   <= 2'b00;
            end
            else begin
                arready <= 1'b0;
                if (rready && rvalid)
                    rvalid <= 1'b0;
            end
        end
    end

endmodule
