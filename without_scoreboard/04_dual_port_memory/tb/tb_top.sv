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
endclass

class dpram_generator;
    mailbox #(dpram_transaction) gen2drv;
    int n;

    function new(mailbox #(dpram_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        dpram_transaction tr;
        repeat(n) begin
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

    function new(virtual dpram_if vif, mailbox #(dpram_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        dpram_transaction tr;
        repeat(n) begin
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
    int n;

    function new(virtual dpram_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | PORT_A[we=%b,addr=%h,din=%h,dout=%h] | PORT_B[we=%b,addr=%h,din=%h,dout=%h]",
                     $time, vif.we_a, vif.addr_a, vif.data_in_a, vif.data_out_a, vif.we_b, vif.addr_b, vif.data_in_b, vif.data_out_b);
        end
    endtask
endclass

class dpram_environment;
    virtual dpram_if vif;
    mailbox #(dpram_transaction) gen2drv;
    dpram_generator gen;
    dpram_driver    drv;
    dpram_monitor   mon;
    int n;

    function new(virtual dpram_if vif, int n);
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
    dpram_if intf();

    dual_port_ram dut (
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

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.we_a      = 0;
        intf.addr_a    = 0;
        intf.data_in_a = 0;
        intf.we_b      = 0;
        intf.addr_b    = 0;
        intf.data_in_b = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
