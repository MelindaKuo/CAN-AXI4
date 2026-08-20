`timescale 1ns / 1ps
`default_nettype none

module tb_can_crc15;

    reg clk = 1'b0; 
    reg rst_n; 
    reg i_clear; 
    reg i_bit; 
    reg i_bit_valid; 
    wire [14:0] o_crc; //output

    reg [14:0] result;
    
    
    
    
    always #5 clk = ~clk; 


    can_crc15 dut (.clk(clk), .rst_n(rst_n), .i_clear(i_clear), .i_bit(i_bit), .i_bit_valid(i_bit_valid), .o_crc(o_crc));


    // start from zero, put bit, stop, read 



    task run_crc(input integer nbits, input [255:0] bits, output [14:0] crc);

        integer i; 
        begin 
            @(negedge clk); 
            i_clear = 1'b1; 
            @(negedge clk);
            i_clear = 1'b0; 


            for(i = nbits-1; i>=0; i= i-1) begin 
                i_bit = bits[i];

                i_bit_valid = 1'b1; 
                @(negedge clk);
            end

            i_bit_valid = 1'b0; 
            crc = o_crc; 
        end

    endtask

    initial begin 
        rst_n = 1'b0; 
        repeat (4) @(negedge clk);
        rst_n = 1'b1; 
    end 

    //watchdog

    initial begin 
        #500000; 
        $display("TIMEOUT");
        $finish; 
    end

    initial begin 
        i_clear = 1'b0; 
        i_bit = 1'b0; 
        i_bit_valid = 1'b0; 

        wait (rst_n === 1'b1);

        run_crc(72, 72'h313233343536373839, result);
        $display("vector 2: got %h expect 059e", result);
        if (result !== 15'h059E) begin $display("FAIL"); $finish; end

        run_crc(59, {1'b0, 11'h222, 3'b000, 4'd5,
                     8'h00, 8'h11, 8'h22, 8'h33, 8'h44}, result);
        $display("vector 3: got %h expect 66da", result);
        if (result !== 15'h66DA) begin $display("FAIL"); $finish; end

        $display("CRC PASS");
        $finish;
    end

    initial begin 
        $dumpfile("sim/crc15.vcd");
        $dumpvars(0, tb_can_crc15);
    end


endmodule


`default_nettype wire
