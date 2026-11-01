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
    mailbox #(transaction) mon2scb;
    int n;

    function new(virtual uart_if vif, mailbox #(transaction) mon2scb, int n);
        this.vif     = vif;
        this.mon2scb = mon2scb;
        this.n       = n;
    endfunction

    task run();
        transaction tr;
        repeat (n) begin
            @(posedge vif.clk);
            #1;
            while (!vif.rx_done) begin
                @(posedge vif.clk);
                #1;
            end
            tr = new();
            tr.tx_data = vif.tx_data;
            tr.rx_data = vif.rx_data;
            tr.tx_done = vif.tx_done;
            tr.rx_done = vif.rx_done;
            mon2scb.put(tr);
        end
    endtask
endclass

class scoreboard;
    mailbox #(transaction) mon2scb;
    int n;
    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(mailbox #(transaction) mon2scb, int n);
        this.mon2scb = mon2scb;
        this.n       = n;
    endfunction

    task run();
        transaction tr;
        repeat (n) begin
            mon2scb.get(tr);
            if (tr.rx_data === tr.tx_data && tr.rx_done === 1'b1)
                pass_cnt++;
            else begin
                fail_cnt++;
                $display("FAIL: exp=%0h act=%0h", tr.tx_data, tr.rx_data);
            end
        end
        $display("PASS = %0d | FAIL = %0d", pass_cnt, fail_cnt);
    endtask
endclass

class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2scb;
    virtual uart_if vif;
    int n;

    function new(virtual uart_if vif, int n);
        this.vif = vif;
        this.n   = n;
        gen2drv  = new();
        mon2scb  = new();
        gen      = new(gen2drv, n);
        drv      = new(vif, gen2drv, n);
        mon      = new(vif, mon2scb, n);
        scb      = new(mon2scb, n);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join
    endtask
endclass

module tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    uart_if intf(clk);

    uart_top #(
        .CLK_FREQ  (96000),
        .BAUD_RATE (9600)
    ) dut (
        .clk      (intf.clk),
        .rst      (intf.rst),
        .tx_start (intf.tx_start),
        .tx_data  (intf.tx_data),
        .rx       (intf.tx),
        .tx       (intf.tx),
        .rx_data  (intf.rx_data),
        .tx_done  (intf.tx_done),
        .rx_done  (intf.rx_done)
    );

    environment env;

    initial begin
        intf.rst      = 1;
        intf.tx_start = 0;
        intf.tx_data  = 0;
        repeat (2) @(posedge clk);
        #1;
        intf.rst = 0;

        env = new(intf, 100);
        env.run();
        #20;
        $finish;
    end
endmodule
