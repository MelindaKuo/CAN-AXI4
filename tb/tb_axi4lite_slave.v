`timescale 1ns / 1ps
`default_nettype none

module tb_axi4lite_slave;

    reg ACLK = 1'b0;
    reg ARESETn;

    reg [31:0] AWADDR;
    reg AWVALID;
    wire AWREADY;

    reg [31:0] WDATA;
    reg [3:0] WSTRB;
    reg WVALID;
    wire WREADY;

    wire [1:0] BRESP;
    wire BVALID;
    reg BREADY;

    reg [31:0] ARADDR;
    reg ARVALID;
    wire ARREADY;

    wire [31:0] RDATA;
    wire [1:0] RRESP;
    wire RVALID;
    reg RREADY;

    reg [10:0] i_id;
    reg i_rtr;
    reg i_ide;
    reg [3:0] i_dlc;
    reg [63:0] i_data;

    reg i_frame_ready;
    reg i_crc_error;
    reg i_stuff_error;
    reg i_form_error;
    reg i_overrun;

    reg [31:0] i_frame_count;
    reg [31:0] i_error_count;

    wire o_clr_frame_ready;
    wire o_clr_crc_error;
    wire o_clr_stuff_error;
    wire o_clr_form_error;
    wire o_clr_overrun;
    wire o_enable;

    reg aw_done;
    reg w_done;

    reg [31:0] rd;
    reg [31:0] rd_slow;
    reg [1:0] rsp;
    integer errors;

    reg mon_arm;
    reg [4:0] clr_seen;
    reg [7:0] clr_ready_cycles;

    localparam ADDR_RX_ID = 32'h00;
    localparam ADDR_RX_DLC = 32'h04;
    localparam ADDR_RX_DATA0 = 32'h08;
    localparam ADDR_RX_DATA1 = 32'h0C;
    localparam ADDR_STATUS = 32'h10;
    localparam ADDR_CONTROL = 32'h14;
    localparam ADDR_FRAME_COUNT = 32'h18;
    localparam ADDR_ERROR_COUNT = 32'h1C;
    localparam ADDR_UNMAPPED = 32'h40;

    localparam [1:0] RESP_OKAY = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    always #5 ACLK = ~ACLK;

    axi4lite_slave dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),

        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),

        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY),

        .i_id(i_id),
        .i_rtr(i_rtr),
        .i_ide(i_ide),
        .i_dlc(i_dlc),
        .i_data(i_data),

        .i_frame_ready(i_frame_ready),
        .i_crc_error(i_crc_error),
        .i_stuff_error(i_stuff_error),
        .i_form_error(i_form_error),
        .i_overrun(i_overrun),

        .i_frame_count(i_frame_count),
        .i_error_count(i_error_count),

        .o_clr_frame_ready(o_clr_frame_ready),
        .o_clr_crc_error(o_clr_crc_error),
        .o_clr_stuff_error(o_clr_stuff_error),
        .o_clr_form_error(o_clr_form_error),
        .o_clr_overrun(o_clr_overrun),
        .o_enable(o_enable)
    );

    always @(posedge ACLK) begin
        if (!ARESETn || mon_arm) begin
            clr_seen <= 5'd0;
            clr_ready_cycles <= 8'd0;
        end
        else begin
            clr_seen <= clr_seen | {o_clr_overrun, o_clr_form_error,
                                    o_clr_stuff_error, o_clr_crc_error,
                                    o_clr_frame_ready};
            if (o_clr_frame_ready)
                clr_ready_cycles <= clr_ready_cycles + 8'd1;
        end
    end

    task check(input [8*40:1] name, input [63:0] got, input [63:0] expected);
        begin
            if (got !== expected) begin
                $display("  FAIL  %0s   got %h  expected %h", name, got, expected);
                errors = errors + 1;
            end
        end
    endtask

    task arm_monitor;
        begin
            @(negedge ACLK);
            mon_arm = 1'b1;
            @(negedge ACLK);
            mon_arm = 1'b0;
        end
    endtask

    task axi_write(input [31:0] addr, input [31:0] data, output [1:0] resp);
        begin
            @(negedge ACLK);
            AWADDR = addr;
            AWVALID = 1'b1;
            WDATA = data;
            WSTRB = 4'b1111;
            WVALID = 1'b1;
            aw_done = 1'b0;
            w_done = 1'b0;

            while (!aw_done || !w_done) begin
                @(posedge ACLK);
                if (AWVALID && AWREADY) aw_done = 1'b1;
                if (WVALID && WREADY) w_done = 1'b1;
                @(negedge ACLK);
                if (aw_done) AWVALID = 1'b0;
                if (w_done) WVALID = 1'b0;
            end

            BREADY = 1'b1;
            @(posedge ACLK);
            while (!BVALID) @(posedge ACLK);
            resp = BRESP;
            @(negedge ACLK);
            BREADY = 1'b0;
        end
    endtask

    task axi_read(input [31:0] addr, output [31:0] data, output [1:0] resp,
                  input integer rready_delay);
        begin
            @(negedge ACLK);
            ARADDR = addr;
            ARVALID = 1'b1;

            @(posedge ACLK);
            while (!ARREADY) @(posedge ACLK);

            @(negedge ACLK);
            ARVALID = 1'b0;

            @(posedge ACLK);
            while (!RVALID) @(posedge ACLK);

            repeat (rready_delay) @(negedge ACLK);

            @(negedge ACLK);
            RREADY = 1'b1;

            @(posedge ACLK);
            data = RDATA;
            resp = RRESP;

            @(negedge ACLK);
            RREADY = 1'b0;
        end
    endtask

    initial begin
        ARESETn = 1'b0;
        repeat (4) @(negedge ACLK);
        ARESETn = 1'b1;
    end

    initial begin
        #200000;
        $display("TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("sim/axi4lite.vcd");
        $dumpvars(0, tb_axi4lite_slave);
    end

    initial begin
        errors = 0;
        AWADDR = 32'd0;
        AWVALID = 1'b0;
        WDATA = 32'd0;
        WSTRB = 4'd0;
        WVALID = 1'b0;
        BREADY = 1'b0;
        ARADDR = 32'd0;
        ARVALID = 1'b0;
        RREADY = 1'b0;
        mon_arm = 1'b0;
        aw_done = 1'b0;
        w_done = 1'b0;

        i_id = 11'h123;
        i_rtr = 1'b1;
        i_ide = 1'b0;
        i_dlc = 4'd5;
        i_data = 64'hDEADBEEF_CAFEBABE;
        i_frame_ready = 1'b1;
        i_crc_error = 1'b0;
        i_stuff_error = 1'b1;
        i_form_error = 1'b0;
        i_overrun = 1'b1;
        i_frame_count = 32'd42;
        i_error_count = 32'd7;

        $display("TEST 1  outputs quiet during reset");
        repeat (3) @(negedge ACLK);
        check("BVALID low in reset", BVALID, 64'd0);
        check("RVALID low in reset", RVALID, 64'd0);

        wait (ARESETn === 1'b1);
        @(negedge ACLK);

        $display("TEST 2  every register reads back its source");
        axi_read(ADDR_RX_ID, rd, rsp, 0);
        check("RX_ID data", rd, 64'h00010123);
        check("RX_ID resp", rsp, RESP_OKAY);

        axi_read(ADDR_RX_DLC, rd, rsp, 0);
        check("RX_DLC data", rd, 64'h00000005);

        axi_read(ADDR_RX_DATA0, rd, rsp, 0);
        check("RX_DATA0 data", rd, 64'hCAFEBABE);

        axi_read(ADDR_RX_DATA1, rd, rsp, 0);
        check("RX_DATA1 data", rd, 64'hDEADBEEF);

        axi_read(ADDR_STATUS, rd, rsp, 0);
        check("STATUS data", rd, 64'h00000015);

        axi_read(ADDR_CONTROL, rd, rsp, 0);
        check("CONTROL after rst", rd, 64'h00000000);

        axi_read(ADDR_FRAME_COUNT, rd, rsp, 0);
        check("FRAME_COUNT data", rd, 64'd42);

        axi_read(ADDR_ERROR_COUNT, rd, rsp, 0);
        check("ERROR_COUNT data", rd, 64'd7);

        $display("TEST 3  read data survives a slow master");
        axi_read(ADDR_FRAME_COUNT, rd, rsp, 0);
        axi_read(ADDR_FRAME_COUNT, rd_slow, rsp, 5);
        check("delay 0 vs delay 5", rd_slow, rd);
        check("slow read resp", rsp, RESP_OKAY);

        $display("TEST 4  CONTROL is writable and reads back");
        axi_write(ADDR_CONTROL, 32'h00000001, rsp);
        check("CONTROL write resp", rsp, RESP_OKAY);
        check("o_enable follows", o_enable, 64'd1);
        axi_read(ADDR_CONTROL, rd, rsp, 0);
        check("CONTROL reads back", rd, 64'h00000001);

        $display("TEST 5  a STATUS write pulses the named strobes only");
        arm_monitor;
        axi_write(ADDR_STATUS, 32'h00000015, rsp);
        check("STATUS write resp", rsp, RESP_OKAY);
        check("strobes pulsed", clr_seen, 64'b10101);
        check("pulse is one cycle", clr_ready_cycles, 64'd1);

        $display("TEST 6  a zero bit clears nothing");
        arm_monitor;
        axi_write(ADDR_STATUS, 32'h00000000, rsp);
        check("no strobes pulsed", clr_seen, 64'd0);

        $display("TEST 7  writes to read-only registers change nothing");
        arm_monitor;
        axi_write(ADDR_RX_DATA0, 32'hFFFFFFFF, rsp);
        check("RO write resp", rsp, RESP_OKAY);
        check("RO write no strobes", clr_seen, 64'd0);
        check("o_enable untouched", o_enable, 64'd1);
        axi_read(ADDR_RX_DATA0, rd, rsp, 0);
        check("RX_DATA0 unchanged", rd, 64'hCAFEBABE);

        $display("TEST 8  unmapped addresses report SLVERR");
        axi_read(ADDR_UNMAPPED, rd, rsp, 0);
        check("unmapped read resp", rsp, RESP_SLVERR);
        check("unmapped read data", rd, 64'd0);

        axi_write(ADDR_UNMAPPED, 32'hDEADBEEF, rsp);
        check("unmapped write resp", rsp, RESP_SLVERR);

        $display("TEST 9  the slave recovers and still works");
        axi_read(ADDR_ERROR_COUNT, rd, rsp, 0);
        check("still responding", rd, 64'd7);
        check("resp back to OKAY", rsp, RESP_OKAY);

        if (errors == 0)
            $display("AXI4LITE PASS");
        else
            $display("AXI4LITE FAIL  %0d checks failed", errors);

        $finish;
    end

endmodule

`default_nettype wire
