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
    logic    [7:0] result;
endclass

class alu_generator;
    mailbox #(alu_transaction) gen2drv;
    int n;

    function new(mailbox #(alu_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        alu_transaction tr;
        repeat(n) begin
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
    int n;

    function new(virtual alu_if vif, mailbox #(alu_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        alu_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            vif.a      = tr.a;
            vif.b      = tr.b;
            vif.opcode = tr.opcode;
            #2;
        end
    endtask
endclass

class alu_monitor;
    virtual alu_if vif;
    int n;

    function new(virtual alu_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            #1;
            $display("[MONITOR] time=%0t | A=%h B=%h OP=%b => RESULT=%h",
                     $time, vif.a, vif.b, vif.opcode, vif.result);
            #1;
        end
    endtask
endclass

class alu_environment;
    virtual alu_if vif;
    mailbox #(alu_transaction) gen2drv;
    alu_generator gen;
    alu_driver    drv;
    alu_monitor   mon;
    int n;

    function new(virtual alu_if vif, int n);
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
    alu_if intf();

    alu_8bit dut (
        .a      (intf.a),
        .b      (intf.b),
        .opcode (intf.opcode),
        .result (intf.result)
    );

    alu_environment env;

    initial begin
        intf.a      = 8'b0;
        intf.b      = 8'b0;
        intf.opcode = 3'b0;
        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
