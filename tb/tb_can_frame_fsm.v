

`timescale 1ns / 1ps
`default_nettype none

module tb_can_frame_fsm;

    reg clk = 1'b0; 
    reg rst_n; 

    localparam MAX_BITS = 65536; 

    reg stim [0: MAX_BITS-1];

    reg i_bit; 
    reg i_bit_valid; 


    // from destuffer to fsm 

    wire ds_bit; 
    wire ds_bit_valid; 
    wire ds_stuff_error; 


    //fsm to destuffer 

    wire stuffing_en; 
    wire flush; 


    //fsm to crc

    wire crc_clear; 
    wire crc_bit; 
    wire crc_bit_valid; 


    //from crc to fsm 

    wire [14:0] crc_out;

    //out fsm 

    wire [10:0] id; 
    wire rtr, ide, r0; 
    wire [3:0] dlc; 
    wire [63:0] data; 
    wire frame_done, frame_valid, crc_error, form_error; 

    integer i, n, fd, frame_count; 

    always #5 clk = ~clk; 


    can_destuffer u_destuff (.clk(clk), .rst_n(rst_n), .i_bit(i_bit), .i_bit_valid(i_bit_valid), .i_stuffing_en(stuffing_en), .i_flush(flush), .o_bit(ds_bit), .o_bit_valid(ds_bit_valid), .o_stuff_error(ds_stuff_error));


    can_frame_fsm dut (.clk(clk), .rst_n(rst_n), .i_bit(ds_bit), .i_bit_valid(ds_bit_valid), .i_stuff_error(ds_stuff_error), .o_crc_clear(crc_clear), .o_crc_bit(crc_bit), .o_crc_bit_valid(crc_bit_valid), .i_crc(crc_out), .o_stuffing_en(stuffing_en), .o_flush(flush), .o_id(id), .o_rtr(rtr), .o_ide(ide), .o_r0(r0), .o_dlc(dlc), .o_data(data), .o_frame_done(frame_done), .o_frame_valid(frame_valid), .o_crc_error(crc_error), .o_form_error(form_error));

    can_crc15 u_crc (.clk(clk), .rst_n(rst_n), .i_clear(crc_clear), .i_bit(crc_bit), .i_bit_valid(crc_bit_valid), .o_crc(crc_out));


    initial begin 
        rst_n = 1'b0; 
        repeat (4) @(negedge clk);
        rst_n = 1'b1; 

    end 


    initial frame_count = 0; 

    always @(posedge clk) begin 
        if(frame_done) begin 
            // Must match model/gen_frame_stim.py's format_expected() exactly:
            //   id rtr dlc <8 bytes> crc <crc><stuff><form>
            // Byte 0 lives in o_data[7:0]
            // crc_rx is internal to the FSM 
            $fwrite(fd, "%03X %0d %0X %02X%02X%02X%02X%02X%02X%02X%02X %04X %0d%0d%0d\n",
                    id, rtr, dlc,
                    data[7:0],   data[15:8],  data[23:16], data[31:24],
                    data[39:32], data[47:40], data[55:48], data[63:56],
                    dut.crc_rx, crc_error, ds_stuff_error, form_error);
            frame_count = frame_count +1; 
        end

    end

    initial begin 
        $readmemb("sim/frame_stim.txt", stim);
        fd =$fopen("sim/frame_actual.txt", "w");

        frame_count = 0; 
        i_bit = 1'b0; 
        i_bit_valid = 1'b0; 

        if(stim[0] === 1'bx) begin 
            $display("ERROR: STIM didn't load");
            $finish;
        end

        if(stim[MAX_BITS-1] !== 1'bx) begin 
            $display("ERROR: stim array full");
            $finish; 
        end 

        n=0; 
        while(stim[n] !== 1'bx) begin 
            n = n+1; 
        end 

        $display("LOADED: %0d bits", n);

        if (fd == 0) begin
            $display("ERROR: can't load file"); 
            $finish; 
        end


        wait(rst_n === 1'b1);

        for(i = 0; i< n; i= i+1) begin
            @(negedge clk);
            i_bit = stim[i];
            i_bit_valid = 1'b1;
            @(negedge clk); 
            i_bit_valid = 1'b0; 
            repeat (2) @(negedge clk);
        end


        i_bit_valid = 1'b0; 
        repeat (400) @(negedge clk);
        $fclose(fd);
        $display("decoded %0d frames", frame_count); 
        $finish; 
    end 


    initial begin 
        #2000000; 
        $display("Timeout");
        $finish; 
    end

    initial begin 
        $dumpfile("sim/frame_fsm.vcd");
        #500000;
        $dumpvars(0, tb_can_frame_fsm);
        #200000; 
        $dumpoff; 
    end 

endmodule

`default_nettype wire
