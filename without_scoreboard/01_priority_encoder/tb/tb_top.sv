`timescale 1ns/1ps

interface pe_if;
    logic [3:0] req;
    logic [1:0] code;
    logic       valid;
endinterface

class pe_transaction;
    rand bit [3:0] req;
    logic    [1:0] code;
    logic          valid;
endclass

class pe_generator;
    mailbox #(pe_transaction) gen2drv;
    int n;

    function new(mailbox #(pe_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        pe_transaction tr;
        repeat(n) begin
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
    int n;

    function new(virtual pe_if vif, mailbox #(pe_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        pe_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            vif.req = tr.req;
            #2;
        end
    endtask
endclass

class pe_monitor;
    virtual pe_if vif;
    int n;

    function new(virtual pe_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            #1;
            $display("[MONITOR] time=%0t | REQ=%b => CODE=%b VALID=%b",
                     $time, vif.req, vif.code, vif.valid);
            #1;
        end
    endtask
endclass

class pe_environment;
    virtual pe_if vif;
    mailbox #(pe_transaction) gen2drv;
    pe_generator gen;
    pe_driver    drv;
    pe_monitor   mon;
    int n;

    function new(virtual pe_if vif, int n);
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
    pe_if intf();

    priority_encoder_4bit dut (
        .req   (intf.req),
        .code  (intf.code),
        .valid (intf.valid)
    );

    pe_environment env;

    initial begin
        intf.req = 4'b0000;
        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
