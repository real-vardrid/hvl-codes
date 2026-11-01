`timescale 1ns/1ps

interface uart_if (input logic clk);
    logic       rst;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       rx;
    logic       tx;
    logic [7:0] rx_data;
    logic       tx_done;
    logic       rx_done;
endinterface

class transaction;
    rand bit [7:0] tx_data;
    logic    [7:0] rx_data;
    logic          tx_done;
    logic          rx_done;
endclass

class generator;
    mailbox #(transaction) gen2drv;
    int n;

    function new(mailbox #(transaction) gen2drv, int n);
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        transaction tr;
        repeat (n) begin
            tr = new();
            if (!tr.randomize())
                $display("Randomization failed");
            gen2drv.put(tr);
        end
    endtask
endclass

class driver;
    virtual uart_if vif;
    mailbox #(transaction) gen2drv;
    int n;

    function new(virtual uart_if vif, mailbox #(transaction) gen2drv, int n);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;
    endfunction

    task run();
        transaction tr;
        vif.tx_start = 1'b0;
        vif.tx_data  = 8'h00;
        repeat (n) begin
            gen2drv.get(tr);
            @(negedge vif.clk);
            vif.tx_data  = tr.tx_data;
            vif.tx_start = 1'b1;
            @(negedge vif.clk);
            vif.tx_start = 1'b0;
            @(posedge vif.rx_done);
        end
    endtask
endclass

class monitor;
    virtual uart_if vif;
    int n;

    function new(virtual uart_if vif, int n);
        this.vif = vif;
        this.n   = n;
    endfunction

    task run();
        repeat (n) begin
            @(posedge vif.clk);
            #1;
            while (!vif.rx_done) begin
                @(posedge vif.clk);
                #1;
            end
            $display("[MONITOR] time=%0t | TX_DATA=%0h RX_DATA=%0h (tx_done=%b, rx_done=%b)",
                     $time, vif.tx_data, vif.rx_data, vif.tx_done, vif.rx_done);
        end
    endtask
endclass

class environment;
    generator gen;
    driver    drv;
    monitor   mon;
    mailbox #(transaction) gen2drv;
    virtual uart_if vif;
    int n;

    function new(virtual uart_if vif, int n);
        this.vif = vif;
        this.n   = n;
        gen2drv  = new();
        gen      = new(gen2drv, n);
        drv      = new(vif, gen2drv, n);
        mon      = new(vif, n);
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
    parameter int N = 5;
    logic clk;

    uart_if intf(clk);

    uart_top dut (
        .clk      (intf.clk),
        .rst      (intf.rst),
        .tx_start (intf.tx_start),
        .tx_data  (intf.tx_data),
        .rx       (intf.rx),
        .tx       (intf.tx),
        .rx_data  (intf.rx_data),
        .tx_done  (intf.tx_done),
        .rx_done  (intf.rx_done)
    );

    assign intf.rx = intf.tx;

    environment env;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        intf.rst      = 1;
        intf.tx_start = 0;
        intf.tx_data  = 0;

        repeat (2) @(posedge clk);
        #1;
        intf.rst = 0;

        env = new(intf, N);
        env.run();
        $finish;
    end
endmodule
