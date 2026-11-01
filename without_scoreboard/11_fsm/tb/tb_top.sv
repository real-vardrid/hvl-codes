`timescale 1ns/1ps

interface fsm_if;
    logic       clk;
    logic       rst;
    logic       in;
    logic       out;
    logic [1:0] state;
endinterface

class fsm_transaction;
    rand bit in;
    logic    out;
    logic [1:0] state;
endclass

class fsm_generator;
    mailbox #(fsm_transaction) gen2drv;
    int n;

    function new(mailbox #(fsm_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        fsm_transaction tr;
        repeat(n) begin
            tr = new();
            if(!tr.randomize())
                $display("Randomization failed");
            gen2drv.put(tr);
        end
    endtask
endclass

class fsm_driver;
    virtual fsm_if vif;
    mailbox #(fsm_transaction) gen2drv;
    int n;

    function new(virtual fsm_if vif, mailbox #(fsm_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        fsm_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            @(negedge vif.clk);
            vif.in = tr.in;
        end
    endtask
endclass

class fsm_monitor;
    virtual fsm_if vif;
    int n;

    function new(virtual fsm_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | IN=%b => STATE=%b OUT=%b",
                     $time, vif.in, vif.state, vif.out);
        end
    endtask
endclass

class fsm_environment;
    virtual fsm_if vif;
    mailbox #(fsm_transaction) gen2drv;
    fsm_generator gen;
    fsm_driver    drv;
    fsm_monitor   mon;
    int n;

    function new(virtual fsm_if vif, int n);
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
    fsm_if intf();

    fsm_dut dut (
        .clk   (intf.clk),
        .rst   (intf.rst),
        .in    (intf.in),
        .out   (intf.out),
        .state (intf.state)
    );

    fsm_environment env;

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.rst = 1;
        intf.in  = 0;

        repeat(2) @(posedge intf.clk);
        #1;
        intf.rst = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
