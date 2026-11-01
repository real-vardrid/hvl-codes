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

    logic [3:0] data_out;
    logic       full;
    logic       empty;

endclass

class fifo_generator;

    mailbox #(fifo_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(fifo_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        fifo_transaction tr;

        repeat(n)
        begin

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

    function new
    (
        virtual fifo_if vif,
        mailbox #(fifo_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        fifo_transaction tr;

        repeat(n)
        begin

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

    mailbox #(fifo_transaction) mon2sb;
    int n;

    function new
    (
        virtual fifo_if vif,
        mailbox #(fifo_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        fifo_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.wr_en   = vif.wr_en;
            tr.rd_en   = vif.rd_en;
            tr.data_in = vif.data_in;

            #1;

            tr.data_out = vif.data_out;
            tr.full     = vif.full;
            tr.empty    = vif.empty;
            mon2sb.put(tr);

        end

    endtask

endclass

class fifo_scoreboard;

    mailbox #(fifo_transaction) mon2sb;

    bit [3:0] ref_q[$];

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(fifo_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        fifo_transaction tr;

        bit [3:0] exp_data;

        bit do_write;
        bit do_read;

        bit exp_full;
        bit exp_empty;

        int size_before;

        repeat(n)
        begin

            mon2sb.get(tr);

            size_before = ref_q.size();

            do_write =
                tr.wr_en && (size_before < 4);

            do_read =
                tr.rd_en && (size_before > 0);

            if(do_read)
                exp_data = ref_q.pop_front();

            if(do_write)
                ref_q.push_back(tr.data_in);

            exp_full  = (ref_q.size() == 4);
            exp_empty = (ref_q.size() == 0);

            if((tr.full  === exp_full)  &&
               (tr.empty === exp_empty) &&
               (!do_read ||
                (tr.data_out === exp_data)))
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: WR=%b RD=%b DIN=%h DOUT=%h FULL=%b EMPTY=%b",
                    tr.wr_en,
                    tr.rd_en,
                    tr.data_in,
                    tr.data_out,
                    tr.full,
                    tr.empty
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class fifo_environment;

    virtual fifo_if vif;

    mailbox #(fifo_transaction) gen2drv;
    mailbox #(fifo_transaction) mon2sb;

    fifo_generator  gen;
    fifo_driver     drv;
    fifo_monitor    mon;
    fifo_scoreboard sb;
    int n;

    function new
    (
        virtual fifo_if vif,
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

    fifo_if intf();

    synchronous_fifo dut
    (
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

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.rst     = 1;
        intf.wr_en   = 0;
        intf.rd_en   = 0;
        intf.data_in = 0;

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
