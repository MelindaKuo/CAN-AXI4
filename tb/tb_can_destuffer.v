`timescale 1ns / 1ps
`default_nettype none

module tb_can_destuffer;

    reg clk  = 1'b0; 
    reg rst_n; 
    reg i_bit; 
    reg i_bit_valid; 
    reg i_stuffing_en; 
    reg i_flush; 

    wire o_bit; 
    wire o_bit_valid; 
    wire o_stuff_error; 


    always #5 clk = ~clk;

    localparam MAX_BITS = 4096; 

    reg stim [0: MAX_BITS-1];

    integer bit_index; 
    integer n; 
    integer fd;


//clk a reset
// falling edge 
    initial begin 
        rst_n = 1'b0; 
        repeat (4) @(negedge clk);
        rst_n = 1'b1; 
    end

// dut samples rising edges 

    can_destuffer dut (.clk(clk), .rst_n(rst_n), .i_bit(i_bit), .i_bit_valid(i_bit_valid), .i_stuffing_en(i_stuffing_en), .i_flush(i_flush), .o_bit(o_bit), .o_bit_valid(o_bit_valid), .o_stuff_error(o_stuff_error));

//

    always @(posedge clk) begin 
        if(o_bit_valid) begin 
            $fwrite(fd, "%b\n", o_bit);

        end
    end

    integer i; 

    initial begin 
        for(i = 0; i< MAX_BITS; i = i+1) 
            stim[i] = 1'bx; 


        $readmemb("sim/destuff_stim.txt", stim);

        if(stim[0] === 1'bx) begin 
            $display("ERROR: stimulus file did not load");
            $finish; 
        end 
        

        n = 0; 

        while(stim[n] !== 1'bx)
            n = n +1; 

        $display("loaded %0d bits", n); 

        fd = $fopen("sim/destuff_actual.txt", "w"); 

        if(fd == 0) begin 
            $display("ERROR: can't open output file");
            $finish; 
        end 

        i_bit       = 1'b0;
        i_bit_valid = 1'b0;
        i_flush     = 1'b0;

        wait (rst_n === 1'b1);
        @(negedge clk);

        i_stuffing_en = 1'b1;
        i_flush       = 1'b1;
        @(negedge clk);
        i_flush = 1'b0; 
        

        for(i = 0; i< n; i= i+1) begin 
            @(negedge clk); 
            i_bit = stim[i]; 
            i_bit_valid = 1'b1; 

        end

        @(negedge clk); 
        i_bit_valid = 1'b0; 
        repeat (5) @(negedge clk); 

        $fclose(fd);
        $finish; 
    end

    initial begin 

        $dumpfile("sim/tb_can_destuffer.vcd");
        $dumpvars(0, tb_can_destuffer); 
    end 

    initial begin 
        #1000000; 
        $display ("ERROR :TIMEOUT");
        $finish; 
    end

endmodule

`default_nettype wire
