`timescale 1ns/1ps

interface tlc_if;

    logic clk;
    logic rst;
    logic red;
    logic yellow;
    logic green;

endinterface

class tlc_transaction;

    rand bit rst;

    logic red;
    logic yellow;
    logic green;

    constraint rst_c
    {
        rst dist {0 := 97, 1 := 3};
    }

endclass

class tlc_generator;

    mailbox #(tlc_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(tlc_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        tlc_transaction tr;

        repeat(n)
        begin

            tr = new();

            if(!tr.randomize())
                $display("Randomization failed");

            gen2drv.put(tr);

        end

    endtask

endclass

class tlc_driver;

    virtual tlc_if vif;

    mailbox #(tlc_transaction) gen2drv;

    int n;

    function new
    (
        virtual tlc_if vif,
        mailbox #(tlc_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        tlc_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            @(negedge vif.clk);

            vif.rst = tr.rst;

        end

    endtask

endclass

class tlc_monitor;

    virtual tlc_if vif;

    mailbox #(tlc_transaction) mon2sb;
    int n;

    function new
    (
        virtual tlc_if vif,
        mailbox #(tlc_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        tlc_transaction tr;

        repeat(n)
        begin

            @(posedge vif.clk);

            tr = new();
            tr.rst = vif.rst;

            #1;

            tr.red    = vif.red;
            tr.yellow = vif.yellow;
            tr.green  = vif.green;
            mon2sb.put(tr);

        end

    endtask

endclass

class tlc_scoreboard;

    mailbox #(tlc_transaction) mon2sb;

    logic [1:0] exp_state = 2'b00;
    logic [3:0] exp_count = 4'd0;

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(tlc_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        tlc_transaction tr;
        logic exp_red, exp_yellow, exp_green;

        repeat(n)
        begin

            mon2sb.get(tr);

            if(tr.rst)
            begin
                exp_state = 2'b00;
                exp_count = 4'd0;
            end
            else
            begin
                case(exp_state)
                    2'b00: begin
                        if(exp_count == 4'd9) begin
                            exp_state = 2'b01;
                            exp_count = 4'd0;
                        end
                        else begin
                            exp_count = exp_count + 4'd1;
                        end
                    end
                    2'b01: begin
                        if(exp_count == 4'd9) begin
                            exp_state = 2'b10;
                            exp_count = 4'd0;
                        end
                        else begin
                            exp_count = exp_count + 4'd1;
                        end
                    end
                    2'b10: begin
                        if(exp_count == 4'd2) begin
                            exp_state = 2'b00;
                            exp_count = 4'd0;
                        end
                        else begin
                            exp_count = exp_count + 4'd1;
                        end
                    end
                    default: begin
                        exp_state = 2'b00;
                        exp_count = 4'd0;
                    end
                endcase
            end

            exp_red    = (exp_state == 2'b00);
            exp_green  = (exp_state == 2'b01);
            exp_yellow = (exp_state == 2'b10);

            if((tr.red    === exp_red)    &&
               (tr.yellow === exp_yellow) &&
               (tr.green  === exp_green))
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: RST=%b Expected={R=%b,Y=%b,G=%b} Actual={R=%b,Y=%b,G=%b}",
                    tr.rst,
                    exp_red, exp_yellow, exp_green,
                    tr.red, tr.yellow, tr.green
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class tlc_environment;

    virtual tlc_if vif;

    mailbox #(tlc_transaction) gen2drv;
    mailbox #(tlc_transaction) mon2sb;

    tlc_generator  gen;
    tlc_driver     drv;
    tlc_monitor    mon;
    tlc_scoreboard sb;
    int n;

    function new
    (
        virtual tlc_if vif,
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

    tlc_if intf();

    traffic_light_controller dut
    (
        .clk    (intf.clk),
        .rst    (intf.rst),
        .red    (intf.red),
        .yellow (intf.yellow),
        .green  (intf.green)
    );

    tlc_environment env;

    initial
    begin

        intf.clk = 0;

        forever #5
            intf.clk = ~intf.clk;

    end

    initial
    begin

        intf.rst = 1;

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
