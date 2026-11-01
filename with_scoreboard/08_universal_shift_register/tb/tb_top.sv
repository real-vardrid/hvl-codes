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

    logic [3:0] q;

endclass

class usr_generator;

    mailbox #(usr_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(usr_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        usr_transaction tr;

        repeat(n)
        begin

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

    function new
    (
        virtual usr_if vif,
        mailbox #(usr_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        usr_transaction tr;

        repeat(n)
        begin

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

    mailbox #(usr_transaction) mon2sb;
    int n;

    function new
    (
        virtual usr_if vif,
        mailbox #(usr_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        usr_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.sel       = vif.sel;
            tr.sin_left  = vif.sin_left;
            tr.sin_right = vif.sin_right;
            tr.pdata     = vif.pdata;

            #1;

            tr.q = vif.q;
            mon2sb.put(tr);

        end

    endtask

endclass

class usr_scoreboard;

    mailbox #(usr_transaction) mon2sb;

    logic [3:0] exp_q = 4'b0000;

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(usr_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        usr_transaction tr;

        repeat(n)
        begin

            mon2sb.get(tr);

            case(tr.sel)

                2'b00:
                    exp_q = exp_q;

                2'b01:
                    exp_q = {tr.sin_left, exp_q[3:1]};

                2'b10:
                    exp_q = {exp_q[2:0], tr.sin_right};

                2'b11:
                    exp_q = tr.pdata;

            endcase

            if(tr.q === exp_q)
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: SEL=%b PDATA=%b Expected=%b Actual=%b",
                    tr.sel,
                    tr.pdata,
                    exp_q,
                    tr.q
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class usr_environment;

    virtual usr_if vif;

    mailbox #(usr_transaction) gen2drv;
    mailbox #(usr_transaction) mon2sb;

    usr_generator  gen;
    usr_driver     drv;
    usr_monitor    mon;
    usr_scoreboard sb;
    int n;

    function new
    (
        virtual usr_if vif,
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

    usr_if intf();

    universal_shift_register dut
    (
        .clk       (intf.clk),
        .rst       (intf.rst),
        .sel       (intf.sel),
        .sin_left  (intf.sin_left),
        .sin_right (intf.sin_right),
        .pdata     (intf.pdata),
        .q         (intf.q)
    );

    usr_environment env;

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.rst       = 1;
        intf.sel       = 0;
        intf.sin_left  = 0;
        intf.sin_right = 0;
        intf.pdata     = 0;

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
