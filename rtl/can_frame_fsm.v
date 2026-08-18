
`default_nettype none

module can_frame_fsm (
    input  wire        clk,
    input  wire        rst_n,

// from destuffer
    input  wire        i_bit,
    input  wire        i_bit_valid,
    input  wire        i_stuff_error,   // sticky flag from can_destuffer

// to destuffer
    output reg         o_stuffing_en,
    output reg         o_flush,

// to crc
    output reg         o_crc_clear,     // pulse at SOF
    output reg         o_crc_bit,
    output reg         o_crc_bit_valid, // high only for SOF..DATA
    input  wire [14:0] i_crc,           // running remainder from can_crc15

// decoded frame
    output reg  [10:0] o_id,
    output reg         o_rtr,
    output reg         o_ide,
    output reg         o_r0,
    output reg  [3:0]  o_dlc,           // RAW received value, not clamped
    output reg  [63:0] o_data,          // byte 0 in bits [7:0]


    // res
    output reg         o_frame_done,    // one-cycle pulse at end of frame
    output reg         o_frame_valid,   // no error flags set
    output reg         o_crc_error,
    output reg         o_form_error
);

    localparam [3:0] IDLE  = 4'd0; 
    localparam [3:0] SOF = 4'd1; 
    localparam [3:0] ID = 4'd2; 
    localparam [3:0] RTR = 4'd3; 
    localparam [3:0] IDE = 4'd4; 
    localparam [3:0] R0  = 4'd5; 
    localparam [3:0] DLC  = 4'd6; 
    localparam [3:0] DATA = 4'd7; 
    localparam [3:0] CRC = 4'd8; 
    localparam [3:0] CRC_DELIM = 4'd9; 
    localparam [3:0] ACK = 4'd10; 
    localparam [3:0] ACK_DELIM = 4'd11; 
    localparam [3:0] EOF = 4'd12; 
    localparam [3:0] IFS = 4'd13; 

    reg [3:0]  state;
    reg [6:0]  bit_count;    
    reg [3:0]  data_len;    
    reg [4:0]  idle_count;  
    reg [7:0]  byte_sr;      
    reg [14:0] crc_rx;      


    wire [3:0] dlc_now  = {o_dlc[2:0], i_bit};
    wire [3:0] len_now  = o_rtr ? 4'd0 : (dlc_now > 4'd8 ? 4'd8 : dlc_now);
    wire [7:0] byte_now = {byte_sr[6:0], i_bit};

  
    wire [6:0] last_data_bit = {data_len, 3'b000} - 7'd1;


    wire [6:0] byte_base = {bit_count[6:3], 3'b000};

    wire form_bad = o_form_error | (i_bit != 1'b1);


    wire crc_bad = (i_crc != crc_rx);

    always @(posedge clk) begin
        if (!rst_n) begin
            state           <= IDLE;
            idle_count      <= 5'd0;
            bit_count       <= 7'd0;
            data_len        <= 4'd0;
            byte_sr         <= 8'd0;
            crc_rx          <= 15'd0;

            o_stuffing_en   <= 1'b0;
            o_flush         <= 1'b1;   // hold the destuffer clear while idle
            o_crc_clear     <= 1'b0;
            o_crc_bit       <= 1'b0;
            o_crc_bit_valid <= 1'b0;

            o_id            <= 11'd0;
            o_rtr           <= 1'b0;
            o_ide           <= 1'b0;
            o_r0            <= 1'b0;
            o_dlc           <= 4'd0;
            o_data          <= 64'd0;

            o_frame_done    <= 1'b0;
            o_frame_valid   <= 1'b0;
            o_crc_error     <= 1'b0;
            o_form_error    <= 1'b0;
        end

        else begin
            
            o_crc_clear <= 1'b0;
            o_crc_bit_valid <= 1'b0;
            o_frame_done <= 1'b0;

            o_flush <= (state == IDLE) || (state == SOF);

            if (i_bit_valid) begin
                case (state)

                IDLE: begin
                    if (i_bit) begin
                        if (idle_count == 5'd9) begin
                            idle_count  <= 5'd10;
                            o_crc_clear <= 1'b1;   // zero the CRC before SOF
                            state       <= SOF;
                        end
                        else if (idle_count < 5'd10) begin
                            idle_count  <= idle_count + 1'b1;
                        end
                    end
                    else begin
                        idle_count <= 5'd0;        // dominant: not idle yet
                    end
                end

              
                SOF: begin
                    if (!i_bit) begin
                        o_stuffing_en   <= 1'b1;
                        o_crc_bit       <= i_bit;
                        o_crc_bit_valid <= 1'b1;

                        o_id            <= 11'd0;
                        o_dlc           <= 4'd0;
                        o_data          <= 64'd0;
                        byte_sr         <= 8'd0;
                        crc_rx          <= 15'd0;
                        o_crc_error     <= 1'b0;
                        o_form_error    <= 1'b0;

                        bit_count       <= 7'd0;
                        state           <= ID;
                    end
                end

                ID: begin
                    o_id            <= {o_id[9:0], i_bit};
                    o_crc_bit       <= i_bit;
                    o_crc_bit_valid <= 1'b1;
                    if (bit_count == 7'd10) begin
                        bit_count <= 7'd0;
                        state     <= RTR;
                    end
                    else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                RTR: begin
                    o_rtr           <= i_bit;
                    o_crc_bit       <= i_bit;
                    o_crc_bit_valid <= 1'b1;
                    state           <= IDE;
                end

                IDE: begin
                    o_ide           <= i_bit;
                    o_crc_bit       <= i_bit;
                    o_crc_bit_valid <= 1'b1;
                    state           <= R0;
                end

                R0: begin
                    o_r0            <= i_bit;
                    o_crc_bit       <= i_bit;
                    o_crc_bit_valid <= 1'b1;
                    state           <= DLC;
                end
                DLC: begin
                    o_dlc           <= dlc_now;
                    o_crc_bit       <= i_bit;
                    o_crc_bit_valid <= 1'b1;
                    if (bit_count == 7'd3) begin
                        bit_count <= 7'd0;
                        data_len  <= len_now;
                        state     <= (len_now == 4'd0) ? CRC : DATA;
                    end
                    else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end
                DATA: begin
                    byte_sr         <= byte_now;
                    o_crc_bit       <= i_bit;
                    o_crc_bit_valid <= 1'b1;

                    if (bit_count[2:0] == 3'd7) begin
                        o_data[byte_base +: 8] <= byte_now;
                    end

                    if (bit_count == last_data_bit) begin
                        bit_count <= 7'd0;
                        state     <= CRC;
                    end
                    else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

            
                CRC: begin
                    crc_rx <= {crc_rx[13:0], i_bit};
                    if (bit_count == 7'd14) begin
                        bit_count <= 7'd0;
                        state     <= CRC_DELIM;
                    end
                    else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                CRC_DELIM: begin
                    o_stuffing_en <= 1'b0;
                    if (!i_bit) o_form_error <= 1'b1;
                    state         <= ACK;
                end

                ACK: begin
                    state <= ACK_DELIM;
                end

                ACK_DELIM: begin
                    if (!i_bit) o_form_error <= 1'b1;
                    bit_count <= 7'd0;
                    state     <= EOF;
                end

                EOF: begin
                    if (!i_bit) o_form_error <= 1'b1;

                    if (bit_count == 7'd6) begin
                        o_crc_error   <= crc_bad;
                        o_frame_valid <= !(crc_bad || form_bad || i_stuff_error);
                        o_frame_done  <= 1'b1;

                        bit_count <= 7'd0;
                        state     <= IFS;
                    end
                    else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                IFS: begin
                    if (bit_count == 7'd2) begin
                        bit_count   <= 7'd0;
                        idle_count  <= 5'd10;
                        o_crc_clear <= 1'b1;
                        state       <= SOF;
                    end
                    else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                default: begin
                    idle_count <= 5'd0;
                    state      <= IDLE;
                end

                endcase
            end
        end
    end

endmodule

`default_nettype wire
