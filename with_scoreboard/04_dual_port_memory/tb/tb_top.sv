`timescale 1ns/1ps

interface dpram_if;

    logic       clk;
    logic       we_a;
    logic [3:0] addr_a;
    logic [7:0] data_in_a;
    logic [7:0] data_out_a;

    logic       we_b;
    logic [3:0] addr_b;
    logic [7:0] data_in_b;
    logic [7:0] data_out_b;

endinterface

class dpram_transaction;

    rand bit       we_a;
    rand bit [3:0] addr_a;
    rand bit [7:0] data_in_a;

    rand bit       we_b;
    rand bit [3:0] addr_b;
    rand bit [7:0] data_in_b;

    logic [7:0] data_out_a;
    logic [7:0] data_out_b;

    constraint distinct_addr_c
    {
        addr_a != addr_b;
    }

endclass

class dpram_generator;

    mailbox #(dpram_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(dpram_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        dpram_transaction tr;

        repeat(n)
        begin

            tr = new();

            if(!tr.randomize())
                $display("Randomization failed");

            gen2drv.put(tr);

        end

    endtask

endclass

class dpram_driver;

    virtual dpram_if vif;

    mailbox #(dpram_transaction) gen2drv;

    int n;

    function new
    (
        virtual dpram_if vif,
        mailbox #(dpram_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        dpram_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            @(negedge vif.clk);

            vif.we_a      = tr.we_a;
            vif.addr_a    = tr.addr_a;
            vif.data_in_a = tr.data_in_a;

            vif.we_b      = tr.we_b;
            vif.addr_b    = tr.addr_b;
            vif.data_in_b = tr.data_in_b;

        end

    endtask

endclass

class dpram_monitor;

    virtual dpram_if vif;

    mailbox #(dpram_transaction) mon2sb;
    int n;

    function new
    (
        virtual dpram_if vif,
        mailbox #(dpram_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        dpram_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.we_a      = vif.we_a;
            tr.addr_a    = vif.addr_a;
            tr.data_in_a = vif.data_in_a;
            tr.we_b      = vif.we_b;
            tr.addr_b    = vif.addr_b;
            tr.data_in_b = vif.data_in_b;

            #1;

            tr.data_out_a = vif.data_out_a;
            tr.data_out_b = vif.data_out_b;
            mon2sb.put(tr);

        end

    endtask

endclass

class dpram_scoreboard;

    mailbox #(dpram_transaction) mon2sb;

    logic [7:0] ref_mem [0:15];

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(dpram_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        dpram_transaction tr;
        bit ok_a, ok_b;

        repeat(n)
        begin

            mon2sb.get(tr);

            if(tr.we_a)
            begin
                ref_mem[tr.addr_a] = tr.data_in_a;
                ok_a = 1'b1;
            end
            else
            begin
                ok_a = (tr.data_out_a === ref_mem[tr.addr_a]);
            end

            if(tr.we_b)
            begin
                ref_mem[tr.addr_b] = tr.data_in_b;
                ok_b = 1'b1;
            end
            else
            begin
                ok_b = (tr.data_out_b === ref_mem[tr.addr_b]);
            end

            if(ok_a && ok_b)
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: ADDR_A=%h EXP_A=%h ACT_A=%h | ADDR_B=%h EXP_B=%h ACT_B=%h",
                    tr.addr_a, ref_mem[tr.addr_a], tr.data_out_a,
                    tr.addr_b, ref_mem[tr.addr_b], tr.data_out_b
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class dpram_environment;

    virtual dpram_if vif;

    mailbox #(dpram_transaction) gen2drv;
    mailbox #(dpram_transaction) mon2sb;

    dpram_generator  gen;
    dpram_driver     drv;
    dpram_monitor    mon;
    dpram_scoreboard sb;
    int n;

    function new
    (
        virtual dpram_if vif,
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

    dpram_if intf();

    dual_port_ram dut
    (
        .clk        (intf.clk),
        .we_a       (intf.we_a),
        .addr_a     (intf.addr_a),
        .data_in_a  (intf.data_in_a),
        .data_out_a (intf.data_out_a),
        .we_b       (intf.we_b),
        .addr_b     (intf.addr_b),
        .data_in_b  (intf.data_in_b),
        .data_out_b (intf.data_out_b)
    );

    dpram_environment env;

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.we_a      = 0;
        intf.addr_a    = 0;
        intf.data_in_a = 0;
        intf.we_b      = 0;
        intf.addr_b    = 0;
        intf.data_in_b = 0;

        env = new(
            intf,
            N
        );

        env.run();
        $finish;

    end

endmodule
