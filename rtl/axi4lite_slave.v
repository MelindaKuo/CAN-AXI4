
`default_nettype none

module axi4lite_slave (
    input  wire        ACLK,
    input  wire        ARESETn,       // active low
                                     
    //write
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output reg         AWREADY,

//write data

    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output reg         WREADY,

    //response    
    output reg  [1:0]  BRESP,         // 00 OKAY, 10 SLVERR, 11 DECERR
    output reg         BVALID,
    input  wire        BREADY,

// read address
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output reg         ARREADY,


//readdata
    output reg  [31:0] RDATA,
    output reg  [1:0]  RRESP,
    output reg         RVALID,
    input  wire        RREADY,

// from snapshot 

    input  wire [10:0] i_id,
    input  wire        i_rtr,
    input  wire        i_ide,
    input  wire [3:0]  i_dlc,
    input  wire [63:0] i_data,
    input  wire        i_frame_ready,
    input  wire        i_crc_error,
    input  wire        i_stuff_error,
    input  wire        i_form_error,
    input  wire        i_overrun,
    input  wire [31:0] i_frame_count,
    input  wire [31:0] i_error_count,

    // to snapshot
    output reg         o_clr_frame_ready,
    output reg         o_clr_crc_error,
    output reg         o_clr_stuff_error,
    output reg         o_clr_form_error,
    output reg         o_clr_overrun,
    output reg         o_enable            // CONTROL[0]
);

    localparam ADDR_RX_ID       = 5'h00;
    localparam ADDR_RX_DLC      = 5'h04;
    localparam ADDR_RX_DATA0    = 5'h08;
    localparam ADDR_RX_DATA1    = 5'h0C;
    localparam ADDR_STATUS      = 5'h10;
    localparam ADDR_CONTROL     = 5'h14;
    localparam ADDR_FRAME_COUNT = 5'h18;
    localparam ADDR_ERROR_COUNT = 5'h1C;

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;



    reg aw_seen; 
    reg w_seen; 
    reg [31:0] awaddr_q; 
    reg [31:0] wdata_q; 



    always @(posedge ACLK) begin 

        if(!ARESETn) begin 
            AWREADY  <= 1'b1;
            WREADY   <= 1'b1;
            BVALID   <= 1'b0;
            BRESP    <= RESP_OKAY;
            aw_seen  <= 1'b0;
            w_seen   <= 1'b0;
            awaddr_q <= 32'd0;
            wdata_q  <= 32'd0;
            o_enable <= 1'b0;
            o_clr_frame_ready <= 1'b0;
            o_clr_crc_error   <= 1'b0;
            o_clr_stuff_error <= 1'b0;
            o_clr_form_error  <= 1'b0;
            o_clr_overrun     <= 1'b0;
        end 

        else begin 

            o_clr_frame_ready <= 1'b0;
            o_clr_crc_error   <= 1'b0;
            o_clr_stuff_error <= 1'b0;
            o_clr_form_error  <= 1'b0;
            o_clr_overrun     <= 1'b0;

            if (AWVALID && AWREADY) begin 
                awaddr_q <= AWADDR; 
                aw_seen <= 1'b1; 
                AWREADY <= 1'b0; 
            end 

            if(WVALID && WREADY) begin 
                wdata_q <= WDATA;
                w_seen <= 1'b1;
                WREADY <= 1'b0; 
            end 

            if (aw_seen && w_seen) begin 
                aw_seen <= 1'b0; 
                w_seen<= 1'b0; 
                BVALID <= 1'b1; 


                case(awaddr_q) 
                    ADDR_CONTROL: begin 
                        o_enable <= wdata_q[0]; 
                        BRESP <= RESP_OKAY; 
                    end 

                    ADDR_STATUS: begin 
                        o_clr_frame_ready <= wdata_q[0];
                        o_clr_crc_error   <= wdata_q[1];
                        o_clr_stuff_error <= wdata_q[2];
                        o_clr_form_error  <= wdata_q[3];
                        o_clr_overrun     <= wdata_q[4];
                        BRESP <= RESP_OKAY; 
                    end 

                    ADDR_RX_ID, ADDR_RX_DLC, ADDR_RX_DATA0, ADDR_RX_DATA1, 
                    ADDR_FRAME_COUNT, ADDR_ERROR_COUNT: begin 
                        BRESP <= RESP_OKAY; 
                    end 

                    default : begin 
                        BRESP<= RESP_SLVERR; 
                    end 
                endcase
            end 

            if(BVALID && BREADY) begin 
                BVALID <= 1'b0; 
                AWREADY <= 1'b1; 
                WREADY <= 1'b1; 
            end
        end
    end



    always @(posedge ACLK) begin 
        if(!ARESETn) begin 
            ARREADY <= 1'b1; 
            RDATA <= 32'd0; 
            RRESP <= 2'd0; 
            RVALID <= 1'b0; 
        end

        else begin 
            if(ARREADY && ARVALID) begin 

                RVALID <= 1'b1; 
                ARREADY <= 1'b0; 
                case(ARADDR)  
                    ADDR_RX_ID: begin 
                        RDATA <= {14'b0, i_ide, i_rtr, 5'b00, i_id}; 
                        RRESP<= RESP_OKAY;
                    end

                    ADDR_RX_DLC: begin 
                        RDATA <= {28'b0, i_dlc};
                        RRESP<= RESP_OKAY;
                    end 

                    ADDR_RX_DATA0: begin 
                        RDATA <= i_data[31:0];
                        RRESP<= RESP_OKAY;
                    end

                    ADDR_RX_DATA1: begin 
                        RDATA<= i_data[63:32]; 
                        RRESP<= RESP_OKAY;
                    end

                    ADDR_STATUS: begin 
                        RDATA <= {27'b0, i_overrun, i_form_error, i_stuff_error, i_crc_error, i_frame_ready};
                        RRESP<= RESP_OKAY;
                    end

                    ADDR_CONTROL: begin 
                        RDATA <= {31'b0, o_enable};
                        RRESP<= RESP_OKAY;
                    end 

                    ADDR_FRAME_COUNT : begin 
                        RDATA<= i_frame_count; 
                        RRESP<= RESP_OKAY;
                    end

                    ADDR_ERROR_COUNT: begin 
                        RDATA<= i_error_count; 
                        RRESP<= RESP_OKAY;
                    end

                    default : begin 
                        RDATA<= 32'd0; 
                        RRESP<= RESP_SLVERR;
                    end
                endcase

                
            end

            if(RVALID && RREADY) begin 
                RVALID <= 1'b0; 
                ARREADY <= 1'b1; 
            end 
        end
    end


endmodule

`default_nettype wire
