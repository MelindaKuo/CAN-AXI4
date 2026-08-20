`timescale 1ns / 1ps
`default_nettype none

module tb_can_rx_top;

    localparam MAX_BITS = 65536;
    localparam BIT_CLOCKS = 20;
    localparam TOTAL_FRAMES = 310;

    localparam ADDR_RX_ID = 32'h00;
    localparam ADDR_RX_DLC = 32'h04;
    localparam ADDR_RX_DATA0 = 32'h08;
    localparam ADDR_RX_DATA1 = 32'h0C;
    localparam ADDR_STATUS = 32'h10;
    localparam ADDR_CONTROL = 32'h14;
    localparam ADDR_FRAME_COUNT = 32'h18;
    localparam ADDR_ERROR_COUNT = 32'h1C;

    localparam [1:0] RESP_OKAY = 2'b00;

    reg ACLK = 1'b0;
    reg ARESETn;

    reg i_can_bit;
    reg i_can_bit_valid;

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

    reg stim [0:MAX_BITS-1];
    integer bit_ptr;
    integer n;
    integer fd;
    integer errors;
    integer sw_frames;

    reg aw_done;
    reg w_done;
    reg run_poller;
    reg poll_done;

    reg [31:0] rd;
    reg [1:0] rsp;
    reg [31:0] st;
    reg [31:0] r_id;
    reg [31:0] r_dlc;
    reg [31:0] r_d0;
    reg [31:0] r_d1;
    reg [31:0] hw_frames;
    reg [31:0] hw_errors;

    always #5 ACLK = ~ACLK;

    can_rx_top dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .i_can_bit(i_can_bit),
        .i_can_bit_valid(i_can_bit_valid),

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
        .RREADY(RREADY)
    );

    task check(input [8*40:1] name, input [63:0] got, input [63:0] expected);
        begin
            if (got !== expected) begin
                $display("  FAIL  %0s   got %0d  expected %0d", name, got, expected);
                errors = errors + 1;
            end
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

    task send_bits(input integer count);
        integer k;
        begin
            for (k = 0; k < count; k = k + 1) begin
                @(negedge ACLK);
                i_can_bit = stim[bit_ptr];
                i_can_bit_valid = 1'b1;
                @(negedge ACLK);
                i_can_bit_valid = 1'b0;
                repeat (BIT_CLOCKS - 2) @(negedge ACLK);
                bit_ptr = bit_ptr + 1;
            end
        end
    endtask

    task pulse_reset;
        begin
            @(negedge ACLK);
            ARESETn = 1'b0;
            repeat (4) @(negedge ACLK);
            ARESETn = 1'b1;
            @(negedge ACLK);
        end
    endtask

    initial begin
        #12000000;
        $display("TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("sim/can_rx_top.vcd");
        $dumpvars(1, tb_can_rx_top);
    end

    initial begin
        poll_done = 1'b0;
        wait (run_poller === 1'b1);

        while (run_poller) begin
            axi_read(ADDR_STATUS, st, rsp, 0);
            if (st[0]) begin
                axi_read(ADDR_RX_ID, r_id, rsp, 0);
                axi_read(ADDR_RX_DLC, r_dlc, rsp, 0);
                axi_read(ADDR_RX_DATA0, r_d0, rsp, 0);
                axi_read(ADDR_RX_DATA1, r_d1, rsp, 0);

                $fwrite(fd, "%03X %0d %0X %02X%02X%02X%02X%02X%02X%02X%02X\n",
                        r_id[10:0], r_id[16], r_dlc[3:0],
                        r_d0[7:0], r_d0[15:8], r_d0[23:16], r_d0[31:24],
                        r_d1[7:0], r_d1[15:8], r_d1[23:16], r_d1[31:24]);

                sw_frames = sw_frames + 1;
                axi_write(ADDR_STATUS, 32'h00000001, rsp);
            end
        end

        poll_done = 1'b1;
    end

    initial begin
        errors = 0;
        sw_frames = 0;
        bit_ptr = 0;
        run_poller = 1'b0;
        ARESETn = 1'b0;
        i_can_bit = 1'b1;
        i_can_bit_valid = 1'b0;
        AWADDR = 32'd0;
        AWVALID = 1'b0;
        WDATA = 32'd0;
        WSTRB = 4'd0;
        WVALID = 1'b0;
        BREADY = 1'b0;
        ARADDR = 32'd0;
        ARVALID = 1'b0;
        RREADY = 1'b0;
        aw_done = 1'b0;
        w_done = 1'b0;

        $readmemb("sim/frame_stim.txt", stim);

        if (stim[0] === 1'bx) begin
            $display("ERROR: sim/frame_stim.txt did not load");
            $finish;
        end
        if (stim[MAX_BITS-1] !== 1'bx) begin
            $display("ERROR: stim array full, MAX_BITS too small");
            $finish;
        end

        n = 0;
        while (stim[n] !== 1'bx) n = n + 1;
        $display("loaded %0d bits", n);

        fd = $fopen("sim/top_actual.txt", "w");
        if (fd == 0) begin
            $display("ERROR: cannot open sim/top_actual.txt");
            $finish;
        end

        pulse_reset;

        $display("TEST 1  a disabled core ignores traffic");
        axi_read(ADDR_CONTROL, rd, rsp, 0);
        check("enable low after reset", rd, 64'd0);

        send_bits(600);

        axi_read(ADDR_FRAME_COUNT, hw_frames, rsp, 0);
        axi_read(ADDR_ERROR_COUNT, hw_errors, rsp, 0);
        axi_read(ADDR_STATUS, st, rsp, 0);
        check("no frames while off", hw_frames, 64'd0);
        check("no errors while off", hw_errors, 64'd0);
        check("not ready while off", st[0], 64'd0);

        pulse_reset;
        bit_ptr = 0;

        $display("TEST 2  streaming %0d frames with software polling", TOTAL_FRAMES);
        axi_write(ADDR_CONTROL, 32'h00000001, rsp);
        check("CONTROL write resp", rsp, RESP_OKAY);

        run_poller = 1'b1;
        send_bits(n);
        repeat (400 * BIT_CLOCKS) @(negedge ACLK);
        run_poller = 1'b0;
        wait (poll_done === 1'b1);

        $fclose(fd);

        axi_read(ADDR_FRAME_COUNT, hw_frames, rsp, 0);
        axi_read(ADDR_ERROR_COUNT, hw_errors, rsp, 0);
        axi_read(ADDR_STATUS, st, rsp, 0);

        $display("  hardware counted %0d valid, %0d rejected", hw_frames, hw_errors);
        $display("  software read    %0d frames", sw_frames);

        check("every frame ended", hw_frames + hw_errors, TOTAL_FRAMES);
        check("software saw all", sw_frames, hw_frames);
        check("no overrun", st[4], 64'd0);
        check("ready bit released", st[0], 64'd0);

        if (errors == 0)
            $display("TOP PASS  %0d frames through the full path", sw_frames);
        else
            $display("TOP FAIL  %0d checks failed", errors);

        $finish;
    end

endmodule

`default_nettype wire
