`timescale 1ns/1ps

interface axi_if;

    logic        aclk;
    logic        aresetn;

    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;

    logic [31:0] wdata;
    logic        wvalid;
    logic        wready;

    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;

    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

endinterface

class axi_transaction;

    rand bit        write_en;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;

    logic [31:0] rdata;
    logic [1:0]  bresp;
    logic [1:0]  rresp;
    logic        bvalid;
    logic        rvalid;

    constraint valid_addr_c
    {
        addr inside {[32'h0000_0000 : 32'h0000_000F]};
    }

endclass

class axi_generator;

    mailbox #(axi_transaction) gen2drv;
    int n;

    function new
    (
        mailbox #(axi_transaction) gen2drv,
        int n
    );

        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        axi_transaction tr;

        repeat(n)
        begin

            tr = new();

            if(!tr.randomize())
                $display("Randomization failed");

            gen2drv.put(tr);

        end

    endtask

endclass

class axi_driver;

    virtual axi_if vif;

    mailbox #(axi_transaction) gen2drv;

    int n;

    function new
    (
        virtual axi_if vif,
        mailbox #(axi_transaction) gen2drv,
        int n
    );

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.n       = n;

    endfunction

    task run();

        axi_transaction tr;

        repeat(n)
        begin

            gen2drv.get(tr);

            @(negedge vif.aclk);

            if(tr.write_en)
            begin
                vif.awaddr  = tr.addr;
                vif.awvalid = 1'b1;
                vif.wdata   = tr.wdata;
                vif.wvalid  = 1'b1;
                vif.bready  = 1'b1;

                vif.araddr  = 32'd0;
                vif.arvalid = 1'b0;
                vif.rready  = 1'b0;
            end
            else
            begin
                vif.araddr  = tr.addr;
                vif.arvalid = 1'b1;
                vif.rready  = 1'b1;

                vif.awaddr  = 32'd0;
                vif.awvalid = 1'b0;
                vif.wdata   = 32'd0;
                vif.wvalid  = 1'b0;
                vif.bready  = 1'b0;
            end

        end

    endtask

endclass

class axi_monitor;

    virtual axi_if vif;

    mailbox #(axi_transaction) mon2sb;
    int n;

    function new
    (
        virtual axi_if vif,
        mailbox #(axi_transaction) mon2sb,
        int n
    );

        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.n      = n;

    endfunction

    task run();

        axi_transaction tr;

        repeat(n)
        begin

            @(posedge vif.aclk);

            tr = new();
            tr.write_en = (vif.awvalid && vif.wvalid);
            tr.addr     = tr.write_en ? vif.awaddr : vif.araddr;
            tr.wdata    = vif.wdata;

            #1;

            tr.rdata  = vif.rdata;
            tr.bresp  = vif.bresp;
            tr.rresp  = vif.rresp;
            tr.bvalid = vif.bvalid;
            tr.rvalid = vif.rvalid;
            mon2sb.put(tr);

        end

    endtask

endclass

class axi_scoreboard;

    mailbox #(axi_transaction) mon2sb;

    logic [31:0] ref_reg [0:15];

    int n;
    int pass = 0;
    int fail = 0;

    function new
    (
        mailbox #(axi_transaction) mon2sb,
        int n
    );

        this.mon2sb = mon2sb;
        this.n      = n;

        for(int i = 0; i < 16; i++)
            ref_reg[i] = 32'h0000_0000;

    endfunction

    task run();

        axi_transaction tr;

        repeat(n)
        begin

            mon2sb.get(tr);

            if(tr.write_en)
            begin

                ref_reg[tr.addr[3:0]] = tr.wdata;

                if((tr.bvalid === 1'b1) && (tr.bresp === 2'b00))
                    pass++;
                else
                begin
                    fail++;
                    $display("ERROR WRITE: ADDR=%h BVALID=%b BRESP=%b", tr.addr, tr.bvalid, tr.bresp);
                end

            end

            else
            begin

                if((tr.rvalid === 1'b1) &&
                   (tr.rresp  === 2'b00) &&
                   (tr.rdata  === ref_reg[tr.addr[3:0]]))
                begin

                    pass++;

                end

                else
                begin

                    fail++;

                    $display(
                        "ERROR READ: ADDR=%h Expected=%h Actual=%h",
                        tr.addr,
                        ref_reg[tr.addr[3:0]],
                        tr.rdata
                    );

                end

            end

        end

        $display("PASS = %0d | FAIL = %0d", pass, fail);
    endtask

endclass

class axi_environment;

    virtual axi_if vif;

    mailbox #(axi_transaction) gen2drv;
    mailbox #(axi_transaction) mon2sb;

    axi_generator  gen;
    axi_driver     drv;
    axi_monitor    mon;
    axi_scoreboard sb;
    int n;

    function new
    (
        virtual axi_if vif,
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

    axi_if intf();

    axi4_lite_slave dut
    (
        .aclk    (intf.aclk),
        .aresetn (intf.aresetn),
        .awaddr  (intf.awaddr),
        .awvalid (intf.awvalid),
        .awready (intf.awready),
        .wdata   (intf.wdata),
        .wvalid  (intf.wvalid),
        .wready  (intf.wready),
        .bresp   (intf.bresp),
        .bvalid  (intf.bvalid),
        .bready  (intf.bready),
        .araddr  (intf.araddr),
        .arvalid (intf.arvalid),
        .arready (intf.arready),
        .rdata   (intf.rdata),
        .rresp   (intf.rresp),
        .rvalid  (intf.rvalid),
        .rready  (intf.rready)
    );

    axi_environment env;

    initial
    begin

        intf.aclk = 0;

        forever #5
            intf.aclk = ~intf.aclk;

    end

    initial
    begin

        intf.aresetn = 0;
        intf.awaddr  = 0;
        intf.awvalid = 0;
        intf.wdata   = 0;
        intf.wvalid  = 0;
        intf.bready  = 0;
        intf.araddr  = 0;
        intf.arvalid = 0;
        intf.rready  = 0;

        repeat(2)
            @(posedge intf.aclk);

        #1;

        intf.aresetn = 1;

        env = new(
            intf,
            N
        );

        env.run();
        $finish;

    end

endmodule
