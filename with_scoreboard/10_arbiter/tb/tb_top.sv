`timescale 1ns/1ps

interface arb_if;

    logic       clk;
    logic       rst;
    logic [3:0] req;
    logic [3:0] grant;

endinterface

class arb_transaction;

    rand bit [3:0] req;

    logic [3:0] grant;

endclass

class arb_generator;

    mailbox #(arb_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(arb_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        arb_transaction tr;

        repeat(n)
        begin

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

    function new
    (
        virtual arb_if vif,
        mailbox #(arb_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        arb_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            @(negedge vif.clk);

            vif.req = tr.req;

        end

    endtask

endclass

class arb_monitor;

    virtual arb_if vif;

    mailbox #(arb_transaction) mon2sb;
    int n;

    function new
    (
        virtual arb_if vif,
        mailbox #(arb_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        arb_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.req = vif.req;

            #1;

            tr.grant = vif.grant;
            mon2sb.put(tr);

        end

    endtask

endclass

class arb_scoreboard;

    mailbox #(arb_transaction) mon2sb;

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(arb_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        arb_transaction tr;
        logic [3:0] exp_grant;

        repeat(n)
        begin

            mon2sb.get(tr);

            casex(tr.req)
                4'b1xxx: exp_grant = 4'd8;
                4'b01xx: exp_grant = 4'd4;
                4'b001x: exp_grant = 4'd2;
                4'b0001: exp_grant = 4'd1;
                default: exp_grant = 4'd0;
            endcase

            if(tr.grant === exp_grant)
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: REQ=%b Expected=%b Actual=%b",
                    tr.req,
                    exp_grant,
                    tr.grant
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class arb_environment;

    virtual arb_if vif;

    mailbox #(arb_transaction) gen2drv;
    mailbox #(arb_transaction) mon2sb;

    arb_generator  gen;
    arb_driver     drv;
    arb_monitor    mon;
    arb_scoreboard sb;
    int n;

    function new
    (
        virtual arb_if vif,
        int n
    );

        this.vif = vif;
        this.n   = n;

        gen2drv = new();
        mon2sb  = new();
        gen = new(
            gen2drv,
            n
        );

        drv = new(
            vif,
            gen2drv,
            n
        );

        mon = new(
            vif,
            mon2sb,
            n
        );

        sb = new(
            mon2sb,
            n
        );

    endfunction

    task run();

        fork

            gen.run();
            drv.run();
            mon.run();
            sb.run();

        join

    endtask

endclass

module tb_top;

    parameter int N = 100;

    arb_if intf();

    arbiter dut
    (
        .clk   (intf.clk),
        .rst   (intf.rst),
        .req   (intf.req),
        .grant (intf.grant)
    );

    arb_environment env;

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.rst = 1;
        intf.req = 0;

        repeat(2)
            @(posedge intf.clk);

        #1;

        intf.rst = 0;

        env = new(
            intf,
            N
        );

        env.run();
        $finish;

    end

endmodule
