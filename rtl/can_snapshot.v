
`default_nettype none

module can_snapshot (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        i_enable,        // CONTROL[0]; when low, frames are ignored

    //from frame fsm
    input  wire        i_frame_done,    // one-cycle pulse at end of frame
    input  wire        i_frame_valid,
    input  wire        i_crc_error,
    input  wire        i_form_error,
    input  wire        i_stuff_error,

    input  wire [10:0] i_id,
    input  wire        i_rtr,
    input  wire        i_ide,
    input  wire [3:0]  i_dlc,
    input  wire [63:0] i_data,

    //read by AXI
    output reg  [10:0] o_id,
    output reg         o_rtr,
    output reg         o_ide,
    output reg  [3:0]  o_dlc,
    output reg  [63:0] o_data,


    output reg         o_frame_ready,
    output reg         o_crc_error,
    output reg         o_stuff_error,
    output reg         o_form_error,
    output reg         o_overrun,

    //1 to clear
    input  wire        i_clr_frame_ready,
    input  wire        i_clr_crc_error,
    input  wire        i_clr_stuff_error,
    input  wire        i_clr_form_error,
    input  wire        i_clr_overrun,


    output reg  [31:0] o_frame_count,   // frames received with valid CRC
    output reg  [31:0] o_error_count    // frames rejected for any reason
);

    wire good_frame  = i_frame_done & i_enable &  i_frame_valid;
    wire bad_frame   = i_frame_done & i_enable & ~i_frame_valid;
    wire capture     = good_frame & ~o_frame_ready;
    wire overrun_now = good_frame &  o_frame_ready;

    always @(posedge clk) begin
        if (!rst_n) begin
            o_id   <= 11'd0;
            o_rtr  <= 1'b0;
            o_ide  <= 1'b0;
            o_dlc  <= 4'd0;
            o_data <= 64'd0;
        end
        else if (capture) begin
            o_id   <= i_id;
            o_rtr  <= i_rtr;
            o_ide  <= i_ide;
            o_dlc  <= i_dlc;
            o_data <= i_data;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_frame_ready <= 1'b0;
        end
        else if (capture) begin
            o_frame_ready <= 1'b1;
        end
        else if (i_clr_frame_ready) begin
            o_frame_ready <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_overrun <= 1'b0;
        end
        else if (overrun_now) begin
            o_overrun <= 1'b1;
        end
        else if (i_clr_overrun) begin
            o_overrun <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_crc_error <= 1'b0;
        end
        else if (bad_frame & i_crc_error) begin
            o_crc_error <= 1'b1;
        end
        else if (i_clr_crc_error) begin
            o_crc_error <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_form_error <= 1'b0;
        end
        else if (bad_frame & i_form_error) begin
            o_form_error <= 1'b1;
        end
        else if (i_clr_form_error) begin
            o_form_error <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_stuff_error <= 1'b0;
        end
        else if (bad_frame & i_stuff_error) begin
            o_stuff_error <= 1'b1;
        end
        else if (i_clr_stuff_error) begin
            o_stuff_error <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_frame_count <= 32'd0;
            o_error_count <= 32'd0;
        end
        else begin
            if (good_frame) begin
                o_frame_count <= o_frame_count + 32'd1;
            end
            if (bad_frame) begin
                o_error_count <= o_error_count + 32'd1;
            end
        end
    end

endmodule

`default_nettype wire
