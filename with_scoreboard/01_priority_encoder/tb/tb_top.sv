`timescale 1ns/1ps

interface pe_if;

    logic [3:0] req;
    logic [1:0] code;
    logic       valid;

endinterface

class pe_transaction;

    rand bit [3:0] req;

    logic [1:0] code;
    logic       valid;

endclass

class pe_generator;

    mailbox #(pe_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(pe_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        pe_transaction tr;

        repeat(n)
        begin

            tr = new();

            if(!tr.randomize())
                $display("Randomization failed");

            gen2drv.put(tr);

        end

    endtask

endclass

class pe_driver;

    virtual pe_if vif;

    mailbox #(pe_transaction) gen2drv;
    mailbox #(pe_transaction) drv2mon;

    int n;

    function new
    (
        virtual pe_if vif,
        mailbox #(pe_transaction) gen2drv,
        mailbox #(pe_transaction) drv2mon,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv2mon = drv2mon;
        this.n       = n;

    endfunction

    task run();

        pe_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            vif.req = tr.req;

            #1;

            drv2mon.put(tr);

            #1;

        end

    endtask

endclass

class pe_monitor;

    virtual pe_if vif;

    mailbox #(pe_transaction) drv2mon;
    mailbox #(pe_transaction) mon2sb;

    int n;

    function new
    (
        virtual pe_if vif,
        mailbox #(pe_transaction) drv2mon,
        mailbox #(pe_transaction) mon2sb,
        int n
    );

        this.vif     = vif;
        this.drv2mon = drv2mon;
        this.mon2sb  = mon2sb;
        this.n       = n;

    endfunction

    task run();

        pe_transaction tr;

        repeat(n)
        begin

            drv2mon.get(tr);

            tr.code  = vif.code;
            tr.valid = vif.valid;

            mon2sb.put(tr);

        end

    endtask

endclass

class pe_scoreboard;

    mailbox #(pe_transaction) mon2sb;

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(pe_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        pe_transaction tr;

        logic [1:0] exp_code;
        logic       exp_valid;

        repeat(n)
        begin

            mon2sb.get(tr);

            exp_valid = |tr.req;

            if(tr.req[3])
                exp_code = 2'b11;

            else if(tr.req[2])
                exp_code = 2'b10;

            else if(tr.req[1])
                exp_code = 2'b01;

            else
                exp_code = 2'b00;

            if((tr.code  === exp_code) &&
               (tr.valid === exp_valid))
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: req=%b Expected=%b,%b Actual=%b,%b",
                    tr.req,
                    exp_code,
                    exp_valid,
                    tr.code,
                    tr.valid
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);

    endtask

endclass

class pe_environment;

    virtual pe_if vif;

    mailbox #(pe_transaction) gen2drv;
    mailbox #(pe_transaction) drv2mon;
    mailbox #(pe_transaction) mon2sb;

    pe_generator  gen;
    pe_driver     drv;
    pe_monitor    mon;
    pe_scoreboard sb;

    int n;

    function new
    (
        virtual pe_if vif,
        int n
    );

        this.vif = vif;
        this.n   = n;

        gen2drv = new();
        drv2mon = new();
        mon2sb  = new();

        gen = new(
            gen2drv,
            n
        );

        drv = new(
            vif,
            gen2drv,
            drv2mon,
            n
        );

        mon = new(
            vif,
            drv2mon,
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

    pe_if intf();

    priority_encoder_4bit dut
    (
        .req   (intf.req),
        .code  (intf.code),
        .valid (intf.valid)
    );

    pe_environment env;

    initial
    begin

        intf.req = 4'b0000;

        env = new(
            intf,
            N
        );

        env.run();

        $finish;

    end

endmodule
