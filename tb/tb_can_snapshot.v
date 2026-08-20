`timescale 1ns / 1ps
`default_nettype none

module tb_can_snapshot;

    reg         clk = 1'b0;
    reg         rst_n;
    reg         i_enable;

    reg         i_frame_done;
    reg         i_frame_valid;
    reg         i_crc_error;
    reg         i_form_error;
    reg         i_stuff_error;

    reg  [10:0] i_id;
    reg         i_rtr;
    reg         i_ide;
    reg  [3:0]  i_dlc;
    reg  [63:0] i_data;

    reg         i_clr_frame_ready;
    reg         i_clr_crc_error;
    reg         i_clr_stuff_error;
    reg         i_clr_form_error;
    reg         i_clr_overrun;

    wire [10:0] o_id;
    wire        o_rtr;
    wire        o_ide;
    wire [3:0]  o_dlc;
    wire [63:0] o_data;

    wire        o_frame_ready;
    wire        o_crc_error;
    wire        o_stuff_error;
    wire        o_form_error;
    wire        o_overrun;

    wire [31:0] o_frame_count;
    wire [31:0] o_error_count;

    integer errors;

    always #5 clk = ~clk;

    can_snapshot dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .i_enable          (i_enable),

        .i_frame_done      (i_frame_done),
        .i_frame_valid     (i_frame_valid),
        .i_crc_error       (i_crc_error),
        .i_form_error      (i_form_error),
        .i_stuff_error     (i_stuff_error),

        .i_id              (i_id),
        .i_rtr             (i_rtr),
        .i_ide             (i_ide),
        .i_dlc             (i_dlc),
        .i_data            (i_data),

        .o_id              (o_id),
        .o_rtr             (o_rtr),
        .o_ide             (o_ide),
        .o_dlc             (o_dlc),
        .o_data            (o_data),

        .o_frame_ready     (o_frame_ready),
        .o_crc_error       (o_crc_error),
        .o_stuff_error     (o_stuff_error),
        .o_form_error      (o_form_error),
        .o_overrun         (o_overrun),

        .i_clr_frame_ready (i_clr_frame_ready),
        .i_clr_crc_error   (i_clr_crc_error),
        .i_clr_stuff_error (i_clr_stuff_error),
        .i_clr_form_error  (i_clr_form_error),
        .i_clr_overrun     (i_clr_overrun),

        .o_frame_count     (o_frame_count),
        .o_error_count     (o_error_count)
    );

    task check(input [8*40:1] name, input [63:0] got, input [63:0] expected);
        begin
            if (got !== expected) begin
                $display("  FAIL  %0s   got %h  expected %h", name, got, expected);
                errors = errors + 1;
            end
        end
    endtask

    task send_frame(input [10:0] id, input [3:0] dlc, input [63:0] data,
                    input valid, input crc_e, input form_e, input stuff_e);
        begin
            @(negedge clk);
            i_id          = id;
            i_rtr         = 1'b0;
            i_ide         = 1'b0;
            i_dlc         = dlc;
            i_data        = data;
            i_frame_valid = valid;
            i_crc_error   = crc_e;
            i_form_error  = form_e;
            i_stuff_error = stuff_e;
            i_frame_done  = 1'b1;
            @(negedge clk);
            i_frame_done  = 1'b0;
            @(negedge clk);
        end
    endtask

    task clear_ready;
        begin
            @(negedge clk);
            i_clr_frame_ready = 1'b1;
            @(negedge clk);
            i_clr_frame_ready = 1'b0;
            @(negedge clk);
        end
    endtask

    initial begin
        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
    end

    initial begin
        #200000;
        $display("TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("sim/snapshot.vcd");
        $dumpvars(0, tb_can_snapshot);
    end

    initial begin
        errors            = 0;
        i_enable          = 1'b1;
        i_frame_done      = 1'b0;
        i_frame_valid     = 1'b0;
        i_crc_error       = 1'b0;
        i_form_error      = 1'b0;
        i_stuff_error     = 1'b0;
        i_id              = 11'd0;
        i_rtr             = 1'b0;
        i_ide             = 1'b0;
        i_dlc             = 4'd0;
        i_data            = 64'd0;
        i_clr_frame_ready = 1'b0;
        i_clr_crc_error   = 1'b0;
        i_clr_stuff_error = 1'b0;
        i_clr_form_error  = 1'b0;
        i_clr_overrun     = 1'b0;

        wait (rst_n === 1'b1);
        @(negedge clk);

        $display("TEST 1  basic capture");
        send_frame(11'h123, 4'd4, 64'h0000000011223344, 1'b1, 1'b0, 1'b0, 1'b0);
        check("ready set",      o_frame_ready, 64'd1);
        check("id captured",    o_id,          64'h123);
        check("dlc captured",   o_dlc,         64'd4);
        check("data captured",  o_data,        64'h0000000011223344);
        check("frame count",    o_frame_count, 64'd1);
        check("no overrun",     o_overrun,     64'd0);

        $display("TEST 2  snapshot frozen, second frame dropped");
        send_frame(11'h7AA, 4'd8, 64'hDEADBEEFCAFEBABE, 1'b1, 1'b0, 1'b0, 1'b0);
        check("ready still set", o_frame_ready, 64'd1);
        check("id unchanged",    o_id,          64'h123);
        check("dlc unchanged",   o_dlc,         64'd4);
        check("data unchanged",  o_data,        64'h0000000011223344);
        check("overrun set",     o_overrun,     64'd1);
        check("frame count 2",   o_frame_count, 64'd2);

        $display("TEST 3  release, then capture the next frame");
        clear_ready;
        check("ready cleared",   o_frame_ready, 64'd0);
        send_frame(11'h0F0, 4'd2, 64'h000000000000AABB, 1'b1, 1'b0, 1'b0, 1'b0);
        check("ready set again", o_frame_ready, 64'd1);
        check("new id",          o_id,          64'h0F0);
        check("new data",        o_data,        64'h000000000000AABB);
        check("frame count 3",   o_frame_count, 64'd3);

        $display("TEST 4  invalid frame is not captured");
        clear_ready;
        send_frame(11'h111, 4'd1, 64'h0000000000000099, 1'b0, 1'b1, 1'b0, 1'b0);
        check("ready stays low", o_frame_ready, 64'd0);
        check("id untouched",    o_id,          64'h0F0);
        check("crc error set",   o_crc_error,   64'd1);
        check("error count 1",   o_error_count, 64'd1);
        check("frame count 3",   o_frame_count, 64'd3);

        $display("TEST 5  disabled core ignores frames");
        i_enable = 1'b0;
        send_frame(11'h222, 4'd8, 64'hFFFFFFFFFFFFFFFF, 1'b1, 1'b0, 1'b0, 1'b0);
        check("ready stays low", o_frame_ready, 64'd0);
        check("id untouched",    o_id,          64'h0F0);
        check("frame count 3",   o_frame_count, 64'd3);
        check("error count 1",   o_error_count, 64'd1);
        i_enable = 1'b1;

        $display("TEST 6  set beats clear on the same cycle");
        @(negedge clk);
        i_id              = 11'h0AA;
        i_dlc             = 4'd3;
        i_data            = 64'h0000000000556677;
        i_frame_valid     = 1'b1;
        i_crc_error       = 1'b0;
        i_form_error      = 1'b0;
        i_stuff_error     = 1'b0;
        i_frame_done      = 1'b1;
        i_clr_frame_ready = 1'b1;
        @(negedge clk);
        i_frame_done      = 1'b0;
        i_clr_frame_ready = 1'b0;
        @(negedge clk);
        check("ready survives", o_frame_ready, 64'd1);
        check("frame captured", o_id,          64'h0AA);
        check("frame count 4",  o_frame_count, 64'd4);

        if (errors == 0)
            $display("SNAPSHOT PASS");
        else
            $display("SNAPSHOT FAIL  %0d checks failed", errors);

        $finish;
    end

endmodule

`default_nettype wire
