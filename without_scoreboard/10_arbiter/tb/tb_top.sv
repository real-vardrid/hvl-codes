`timescale 1ns/1ps

interface arb_if;
    logic       clk;
    logic       rst;
    logic [3:0] req;
    logic [3:0] grant;
endinterface

class arb_transaction;
    rand bit [3:0] req;
    logic    [3:0] grant;
endclass

class arb_generator;
    mailbox #(arb_transaction) gen2drv;
    int n;

    function new(mailbox #(arb_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        arb_transaction tr;
        repeat(n) begin
            tr = new();
            if(!tr.randomize())
                $display("Randomization failed");
            gen2drv.put(tr);
        end
    endtask
endclass

class arb_driver;
    virtual arb_if vif;
    mailbox #(arb_transaction) gen2drv;
    int n;

    function new(virtual arb_if vif, mailbox #(arb_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        arb_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            @(negedge vif.clk);
            vif.req = tr.req;
        end
    endtask
endclass

class arb_monitor;
    virtual arb_if vif;
    int n;

    function new(virtual arb_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | REQ=%b => GRANT=%b",
                     $time, vif.req, vif.grant);
        end
    endtask
endclass

class arb_environment;
    virtual arb_if vif;
    mailbox #(arb_transaction) gen2drv;
    arb_generator gen;
    arb_driver    drv;
    arb_monitor   mon;
    int n;

    function new(virtual arb_if vif, int n);
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
    arb_if intf();

    arbiter dut (
        .clk   (intf.clk),
        .rst   (intf.rst),
        .req   (intf.req),
        .grant (intf.grant)
    );

    arb_environment env;

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.rst = 1;
        intf.req = 0;

        repeat(2) @(posedge intf.clk);
        #1;
        intf.rst = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
