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

    logic       out;
    logic [1:0] state;

endclass

class fsm_generator;

    mailbox #(fsm_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(fsm_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        fsm_transaction tr;

        repeat(n)
        begin

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

    function new
    (
        virtual fsm_if vif,
        mailbox #(fsm_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        fsm_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            @(negedge vif.clk);

            vif.in = tr.in;

        end

    endtask

endclass

class fsm_monitor;

    virtual fsm_if vif;

    mailbox #(fsm_transaction) mon2sb;
    int n;

    function new
    (
        virtual fsm_if vif,
        mailbox #(fsm_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        fsm_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.in = vif.in;

            #1;

            tr.state = vif.state;
            tr.out   = vif.out;
            mon2sb.put(tr);

        end

    endtask

endclass

class fsm_scoreboard;

    mailbox #(fsm_transaction) mon2sb;

    logic [1:0] exp_state = 2'b00;

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(fsm_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        fsm_transaction tr;
        logic exp_out;

        repeat(n)
        begin

            mon2sb.get(tr);

            case(exp_state)
                2'b00:   exp_state = tr.in ? 2'b01 : 2'b00;
                2'b01:   exp_state = tr.in ? 2'b10 : 2'b00;
                2'b10:   exp_state = tr.in ? 2'b10 : 2'b00;
                default: exp_state = 2'b00;
            endcase

            exp_out = (exp_state == 2'b10);

            if((tr.state === exp_state) && (tr.out === exp_out))
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: IN=%b Expected_State=%b,Out=%b Actual_State=%b,Out=%b",
                    tr.in,
                    exp_state,
                    exp_out,
                    tr.state,
                    tr.out
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class fsm_environment;

    virtual fsm_if vif;

    mailbox #(fsm_transaction) gen2drv;
    mailbox #(fsm_transaction) mon2sb;

    fsm_generator  gen;
    fsm_driver     drv;
    fsm_monitor    mon;
    fsm_scoreboard sb;
    int n;

    function new
    (
        virtual fsm_if vif,
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

    fsm_if intf();

    fsm_dut dut
    (
        .clk   (intf.clk),
        .rst   (intf.rst),
        .in    (intf.in),
        .out   (intf.out),
        .state (intf.state)
    );

    fsm_environment env;

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.rst = 1;
        intf.in  = 0;

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
