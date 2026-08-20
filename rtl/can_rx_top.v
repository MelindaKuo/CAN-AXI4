
`default_nettype none

module can_rx_top (
    input  wire        ACLK,
    input  wire        ARESETn,

    
    input  wire        i_can_bit,       // sampled bus level, 0 = dominant
    input  wire        i_can_bit_valid, // one pulse per CAN bit

    //axi4
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output wire        AWREADY,
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output wire        WREADY,
    output wire [1:0]  BRESP,
    output wire        BVALID,
    input  wire        BREADY,
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output wire        ARREADY,
    output wire [31:0] RDATA,
    output wire [1:0]  RRESP,
    output wire        RVALID,
    input  wire        RREADY
);


    wire ds_bit; 
    wire ds_bit_valid; 
    wire ds_stuff_error;

    wire stuffing_en; 
    wire flush; 

    wire crc_clear; 
    wire crc_bit; 
    wire crc_bit_valid; 
    wire [14:0] crc_out;

    wire [10:0] dec_id; 
    wire dec_rtr; 
    wire dec_ide; 
    wire [3:0] dec_dlc; 
    wire [63:0] dec_data; 
    wire frame_done; 
    wire frame_valid; 
    wire dec_crc_error; 
    wire dec_form_error; 

    wire [10:0] snap_id; 
    wire snap_rtr; 
    wire snap_ide; 
    wire [3:0] snap_dlc; 
    wire [63:0] snap_data; 
    wire frame_ready; 
    wire st_crc_error; 
    wire st_stuff_error; 
    wire st_form_error; 
    wire overrun; 
    wire [31:0] frame_count; 
    wire [31:0] error_count; 

    wire clr_frame_ready; 
    wire clr_crc_error; 
    wire clr_stuff_error; 
    wire clr_form_error; 
    wire clr_overrun; 
    wire enable; 

    can_destuffer u_destuff(
                            .i_bit(i_can_bit), 
                            .i_bit_valid(i_can_bit_valid), 
                            .i_stuffing_en(stuffing_en), 
                            .i_flush(flush), 
                            .o_bit(ds_bit), 
                            .o_bit_valid(ds_bit_valid), 
                            .o_stuff_error(ds_stuff_error), 
                            .clk(ACLK), 
                            .rst_n(ARESETn));

    can_frame_fsm u_fsm (

                            .i_bit(ds_bit), 
                            .i_bit_valid(ds_bit_valid), 
                            .i_stuff_error(ds_stuff_error), 
                            .o_stuffing_en(stuffing_en), 
                            .o_flush(flush), 
                            .o_crc_clear(crc_clear), 
                            .o_crc_bit(crc_bit), 
                            .o_crc_bit_valid(crc_bit_valid), 
                            .i_crc(crc_out), 
                            .o_id(dec_id), 
                            .o_rtr(dec_rtr), 
                            .o_ide(dec_ide), 
                            .o_dlc(dec_dlc), 
                            .o_data(dec_data), 
                            .o_frame_done(frame_done), 
                            .o_frame_valid(frame_valid), 
                            .o_crc_error(dec_crc_error), 
                            .o_form_error(dec_form_error), 
                            .clk(ACLK), 
                            .rst_n(ARESETn)

    ); 


    can_crc15 u_crc (
                            .clk(ACLK), 
                            .rst_n(ARESETn), 
                            .i_clear(crc_clear), 
                            .i_bit(crc_bit), 
                            .i_bit_valid(crc_bit_valid), 
                            .o_crc(crc_out)

    ); 


    can_snapshot u_snapshot (
                            .clk(ACLK), 
                            .rst_n(ARESETn), 
                            .i_id(dec_id), 
                            .i_rtr(dec_rtr), 
                            .i_ide(dec_ide), 
                            .i_dlc(dec_dlc), 
                            .i_data(dec_data), 
                            .i_frame_done(frame_done), 
                            .i_frame_valid(frame_valid), 
                            .i_crc_error(dec_crc_error), 
                            .i_form_error(dec_form_error), 
                            .i_stuff_error(ds_stuff_error), 
                            .i_clr_crc_error(clr_crc_error), 
                            .i_clr_form_error(clr_form_error), 
                            .i_clr_overrun(clr_overrun), 
                            .i_enable(enable), 
                            .i_clr_frame_ready(clr_frame_ready), 
                            .i_clr_stuff_error(clr_stuff_error), 
                            .o_id(snap_id), 
                            .o_rtr(snap_rtr), 
                            .o_ide(snap_ide), 
                            .o_dlc(snap_dlc), 
                            .o_data(snap_data),
                            .o_frame_ready(frame_ready), 
                            .o_crc_error(st_crc_error), 
                            .o_form_error(st_form_error), 
                            .o_stuff_error(st_stuff_error), 
                            .o_overrun(overrun), 
                            .o_frame_count(frame_count), 
                            .o_error_count(error_count)
    ); 


    axi4lite_slave u_axi (
                            .ACLK(ACLK), 
                            .ARESETn(ARESETn),

                            .AWADDR(AWADDR), 
                            .AWVALID(AWVALID), 
                            .AWREADY(AWREADY), 

                            .WDATA(WDATA), 
                            .WVALID(WVALID), 
                            .WREADY(WREADY), 
                            .WSTRB(WSTRB), 


                            .BRESP(BRESP), 
                            .BVALID(BVALID), 
                            .BREADY(BREADY), 

                            .ARADDR(ARADDR), 
                            .ARREADY(ARREADY), 
                            .ARVALID(ARVALID), 

                            .RREADY(RREADY), 
                            .RDATA(RDATA), 
                            .RVALID(RVALID), 
                            .RRESP(RRESP), 

                            .i_id(snap_id), 
                            .i_rtr(snap_rtr),
                            .i_ide(snap_ide), 
                            .i_dlc(snap_dlc), 
                            .i_data(snap_data), 
                            .i_frame_ready(frame_ready), 
                            .i_frame_count(frame_count), 
                            .i_error_count(error_count), 
                            .i_crc_error(st_crc_error), 
                            .i_stuff_error(st_stuff_error), 
                            .i_form_error(st_form_error), 
                            .i_overrun(overrun), 

                            .o_clr_crc_error(clr_crc_error), 
                            .o_clr_form_error(clr_form_error), 
                            .o_clr_stuff_error(clr_stuff_error), 
                            .o_clr_frame_ready(clr_frame_ready), 
                            .o_clr_overrun(clr_overrun), 
                            .o_enable(enable)

    );


endmodule

`default_nettype wire
