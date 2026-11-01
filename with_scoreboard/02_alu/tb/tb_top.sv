`timescale 1ns/1ps

interface alu_if;

    logic [7:0] a;
    logic [7:0] b;
    logic [2:0] opcode;
    logic [7:0] result;

endinterface

class alu_transaction;

    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit [2:0] opcode;

    logic [7:0] result;

endclass

class alu_generator;

    mailbox #(alu_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(alu_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        alu_transaction tr;

        repeat(n)
        begin

            tr = new();

            if(!tr.randomize())
                $display("Randomization failed");

            gen2drv.put(tr);

        end

    endtask

endclass

class alu_driver;

    virtual alu_if vif;

    mailbox #(alu_transaction) gen2drv;
    mailbox #(alu_transaction) drv2mon;

    int n;

    function new
    (
        virtual alu_if vif,
        mailbox #(alu_transaction) gen2drv,
        mailbox #(alu_transaction) drv2mon,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv2mon = drv2mon;
        this.n       = n;

    endfunction

    task run();

        alu_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            vif.a      = tr.a;
            vif.b      = tr.b;
            vif.opcode = tr.opcode;

            #1;

            drv2mon.put(tr);

            #1;

        end

    endtask

endclass

class alu_monitor;

    virtual alu_if vif;

    mailbox #(alu_transaction) drv2mon;
    mailbox #(alu_transaction) mon2sb;

    int n;

    function new
    (
        virtual alu_if vif,
        mailbox #(alu_transaction) drv2mon,
        mailbox #(alu_transaction) mon2sb,
        int n
    );

        this.vif     = vif;
        this.drv2mon = drv2mon;
        this.mon2sb  = mon2sb;
        this.n       = n;

    endfunction

    task run();

        alu_transaction tr;

        repeat(n)
        begin

            drv2mon.get(tr);

            tr.result = vif.result;

            mon2sb.put(tr);

        end

    endtask

endclass

class alu_scoreboard;

    mailbox #(alu_transaction) mon2sb;

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(alu_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        alu_transaction tr;

        logic [7:0] exp_result;

        repeat(n)
        begin

            mon2sb.get(tr);

            case(tr.opcode)

                3'b000:
                    exp_result = tr.a + tr.b;

                3'b001:
                    exp_result = tr.a - tr.b;

                3'b010:
                    exp_result = tr.a & tr.b;

                3'b011:
                    exp_result = tr.a | tr.b;

                3'b100:
                    exp_result = tr.a ^ tr.b;

                3'b101:
                    exp_result = ~(tr.a & tr.b);

                3'b110:
                    exp_result = ~(tr.a | tr.b);

                3'b111:
                    exp_result = ~(tr.a ^ tr.b);

            endcase

            if(tr.result === exp_result)
            begin

                pass++;

            end

            else
            begin

                fail++;

                $display(
                    "ERROR: A=%h B=%h OP=%b Expected=%h Actual=%h",
                    tr.a,
                    tr.b,
                    tr.opcode,
                    exp_result,
                    tr.result
                );

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);

    endtask

endclass

class alu_environment;

    virtual alu_if vif;

    mailbox #(alu_transaction) gen2drv;
    mailbox #(alu_transaction) drv2mon;
    mailbox #(alu_transaction) mon2sb;

    alu_generator  gen;
    alu_driver     drv;
    alu_monitor    mon;
    alu_scoreboard sb;

    int n;

    function new
    (
        virtual alu_if vif,
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

    alu_if intf();

    alu_8bit dut
    (
        .a      (intf.a),
        .b      (intf.b),
        .opcode (intf.opcode),
        .result (intf.result)
    );

    alu_environment env;

    initial
    begin

        intf.a      = 8'b0;
        intf.b      = 8'b0;
        intf.opcode = 3'b0;

        env = new(
            intf,
            N
        );

        env.run();

        $finish;

    end

endmodule
