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
    logic    red;
    logic    yellow;
    logic    green;

    constraint rst_c {
        rst dist {0 := 97, 1 := 3};
    }
endclass

class tlc_generator;
    mailbox #(tlc_transaction) gen2drv;
    int n;

    function new(mailbox #(tlc_transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        tlc_transaction tr;
        repeat(n) begin
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

    function new(virtual tlc_if vif, mailbox #(tlc_transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        tlc_transaction tr;
        repeat(n) begin
            gen2drv.get(tr);
            @(negedge vif.clk);
            vif.rst = tr.rst;
        end
    endtask
endclass

class tlc_monitor;
    virtual tlc_if vif;
    int n;

    function new(virtual tlc_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat(n) begin
            @(posedge vif.clk);
            #1;
            $display("[MONITOR] time=%0t | RST=%b => RED=%b YELLOW=%b GREEN=%b",
                     $time, vif.rst, vif.red, vif.yellow, vif.green);
        end
    endtask
endclass

class tlc_environment;
    virtual tlc_if vif;
    mailbox #(tlc_transaction) gen2drv;
    tlc_generator gen;
    tlc_driver    drv;
    tlc_monitor   mon;
    int n;

    function new(virtual tlc_if vif, int n);
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
    parameter int N = 25;
    tlc_if intf();

    traffic_light_controller dut (
        .clk    (intf.clk),
        .rst    (intf.rst),
        .red    (intf.red),
        .yellow (intf.yellow),
        .green  (intf.green)
    );

    tlc_environment env;

    initial begin
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        intf.rst = 1;
        repeat(2) @(posedge intf.clk);
        #1;
        intf.rst = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
