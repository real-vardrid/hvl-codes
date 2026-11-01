`timescale 1ns/1ps

interface fifo_if;
    logic       clk;
    logic       rst;
    logic       wr_en;
    logic       rd_en;
    logic [3:0] data_in;
    logic [3:0] data_out;
    logic       full;
    logic       empty;
endinterface

class fifo_transaction;
    rand bit       wr_en;
    rand bit       rd_en;
    rand bit [3:0] data_in;
    logic [3:0]    data_out;
    logic          full;
    logic          empty;
endclass

class fifo_generator;
    mailbox #(fifo_transaction) gen2drv;
    int n;

    function new(mailbox #(fifo_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        fifo_transaction tr;
        repeat(n) begin
            tr = new();
            if(!tr.randomize())
                $display("Randomization failed");
            gen2drv.put(tr);
        end
    endtask
endclass

class fifo_driver;
    virtual fifo_if vif;
    mailbox #(fifo_transaction) gen2drv;
    int n;

    function new(virtual fifo_if vif, mailbox #(fifo_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        fifo_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            @(negedge vif.clk);
            vif.wr_en   = tr.wr_en;
            vif.rd_en   = tr.rd_en;
            vif.data_in = tr.data_in;
        end
    endtask
endclass

class fifo_monitor;
    virtual fifo_if vif;
    int n;

    function new(virtual fifo_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | WR=%b RD=%b DIN=%h | DOUT=%h FULL=%b EMPTY=%b",
                     $time, vif.wr_en, vif.rd_en, vif.data_in, vif.data_out, vif.full, vif.empty);
        end
    endtask
endclass

class fifo_environment;
    virtual fifo_if vif;
    mailbox #(fifo_transaction) gen2drv;
    fifo_generator gen;
    fifo_driver    drv;
    fifo_monitor   mon;
    int n;

    function new(virtual fifo_if vif, int n);
        this.vif     = vif;
        this.n       = n;
        gen2drv      = new();
        gen          = new(gen2drv, n);
        drv          = new(vif, gen2drv, n);
        mon          = new(vif, n);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
        join
    endtask
endclass

module tb_top;
    parameter int N = 20;
    fifo_if intf();

    synchronous_fifo dut (
        .clk      (intf.clk),
        .rst      (intf.rst),
        .wr_en    (intf.wr_en),
        .rd_en    (intf.rd_en),
        .data_in  (intf.data_in),
        .data_out (intf.data_out),
        .full     (intf.full),
        .empty    (intf.empty)
    );

    fifo_environment env;

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.rst     = 1;
        intf.wr_en   = 0;
        intf.rd_en   = 0;
        intf.data_in = 0;

        repeat(2) @(posedge intf.clk);
        #1;
        intf.rst = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
