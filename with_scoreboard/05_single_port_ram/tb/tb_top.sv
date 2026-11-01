`timescale 1ns/1ps

interface ram_if;

    logic       clk;
    logic       we;
    logic [3:0] addr;
    logic [7:0] data_in;
    logic [7:0] data_out;

endinterface

class ram_transaction;

    rand bit       we;
    rand bit [3:0] addr;
    rand bit [7:0] data_in;

    logic [7:0] data_out;

endclass

class ram_generator;

    mailbox #(ram_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(ram_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        ram_transaction tr;

        repeat(n)
        begin

            tr = new();

            if(!tr.randomize())
                $display("Randomization failed");

            gen2drv.put(tr);

        end

    endtask

endclass

class ram_driver;

    virtual ram_if vif;

    mailbox #(ram_transaction) gen2drv;

    int n;

    function new
    (
        virtual ram_if vif,
        mailbox #(ram_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        ram_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            @(negedge vif.clk);

            vif.we      = tr.we;
            vif.addr    = tr.addr;
            vif.data_in = tr.data_in;

        end

    endtask

endclass

class ram_monitor;

    virtual ram_if vif;

    mailbox #(ram_transaction) mon2sb;
    int n;

    function new
    (
        virtual ram_if vif,
        mailbox #(ram_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        ram_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.we      = vif.we;
            tr.addr    = vif.addr;
            tr.data_in = vif.data_in;

            #1;

            tr.data_out = vif.data_out;
            mon2sb.put(tr);

        end

    endtask

endclass

class ram_scoreboard;

    mailbox #(ram_transaction) mon2sb;

    logic [7:0] ref_mem [0:15];

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(ram_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        ram_transaction tr;

        repeat(n)
        begin

            mon2sb.get(tr);

            if(tr.we)
            begin

                ref_mem[tr.addr] = tr.data_in;
                pass++;

            end

            else
            begin

                if(tr.data_out === ref_mem[tr.addr])
                begin

                    pass++;

                end

                else
                begin

                    fail++;

                    $display(
                        "ERROR: ADDR=%h Expected=%h Actual=%h",
                        tr.addr,
                        ref_mem[tr.addr],
                        tr.data_out
                    );

                end

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class ram_environment;

    virtual ram_if vif;

    mailbox #(ram_transaction) gen2drv;
    mailbox #(ram_transaction) mon2sb;

    ram_generator  gen;
    ram_driver     drv;
    ram_monitor    mon;
    ram_scoreboard sb;
    int n;

    function new
    (
        virtual ram_if vif,
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

    ram_if intf();

    single_port_ram dut
    (
        .clk      (intf.clk),
        .we       (intf.we),
        .addr     (intf.addr),
        .data_in  (intf.data_in),
        .data_out (intf.data_out)
    );

    ram_environment env;

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.we      = 0;
        intf.addr    = 0;
        intf.data_in = 0;

        env = new(
            intf,
            N
        );

        env.run();
        $finish;

    end

endmodule
