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
    logic [7:0]    data_out;
endclass

class ram_generator;
    mailbox #(ram_transaction) gen2drv;
    int n;

    function new(mailbox #(ram_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        ram_transaction tr;
        repeat(n) begin
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

    function new(virtual ram_if vif, mailbox #(ram_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        ram_transaction tr;
        repeat(n) begin
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
    int n;

    function new(virtual ram_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | WE=%b ADDR=%h DIN=%h DOUT=%h",
                     $time, vif.we, vif.addr, vif.data_in, vif.data_out);
        end
    endtask
endclass

class ram_environment;
    virtual ram_if vif;
    mailbox #(ram_transaction) gen2drv;
    ram_generator gen;
    ram_driver    drv;
    ram_monitor   mon;
    int n;

    function new(virtual ram_if vif, int n);
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
    ram_if intf();

    single_port_ram dut (
        .clk      (intf.clk),
        .we       (intf.we),
        .addr     (intf.addr),
        .data_in  (intf.data_in),
        .data_out (intf.data_out)
    );

    ram_environment env;

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.we      = 0;
        intf.addr    = 0;
        intf.data_in = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
