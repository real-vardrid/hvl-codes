`timescale 1ns/1ps

interface usr_if;
    logic       clk;
    logic       rst;
    logic [1:0] sel;
    logic       sin_left;
    logic       sin_right;
    logic [3:0] pdata;
    logic [3:0] q;
endinterface

class usr_transaction;
    rand bit [1:0] sel;
    rand bit       sin_left;
    rand bit       sin_right;
    rand bit [3:0] pdata;
    logic    [3:0] q;
endclass

class usr_generator;
    mailbox #(usr_transaction) gen2drv;
    int n;

    function new(mailbox #(usr_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        usr_transaction tr;
        repeat(n) begin
            tr = new();
            if(!tr.randomize())
                $display("Randomization failed");
            gen2drv.put(tr);
        end
    endtask
endclass

class usr_driver;
    virtual usr_if vif;
    mailbox #(usr_transaction) gen2drv;
    int n;

    function new(virtual usr_if vif, mailbox #(usr_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        usr_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            @(negedge vif.clk);
            vif.sel       = tr.sel;
            vif.sin_left  = tr.sin_left;
            vif.sin_right = tr.sin_right;
            vif.pdata     = tr.pdata;
        end
    endtask
endclass

class usr_monitor;
    virtual usr_if vif;
    int n;

    function new(virtual usr_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | SEL=%b SIN_L=%b SIN_R=%b PDATA=%b => Q=%b",
                     $time, vif.sel, vif.sin_left, vif.sin_right, vif.pdata, vif.q);
        end
    endtask
endclass

class usr_environment;
    virtual usr_if vif;
    mailbox #(usr_transaction) gen2drv;
    usr_generator gen;
    usr_driver    drv;
    usr_monitor   mon;
    int n;

    function new(virtual usr_if vif, int n);
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
    usr_if intf();

    universal_shift_register dut (
        .clk       (intf.clk),
        .rst       (intf.rst),
        .sel       (intf.sel),
        .sin_left  (intf.sin_left),
        .sin_right (intf.sin_right),
        .pdata     (intf.pdata),
        .q         (intf.q)
    );

    usr_environment env;

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.rst       = 1;
        intf.sel       = 2'b00;
        intf.sin_left  = 0;
        intf.sin_right = 0;
        intf.pdata     = 4'b0000;

        repeat(2) @(posedge intf.clk);
        #1;
        intf.rst = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
