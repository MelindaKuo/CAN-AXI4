
`default_nettype none

module can_destuffer (

    input wire clk, 
    input wire rst_n, // reset

    input wire i_bit, 
    input wire i_bit_valid, 

    input wire i_stuffing_en, // stuffing rules apply
    input wire i_flush, // clear counter

    output reg o_bit, // the bit
    output reg o_bit_valid, 

    output reg o_stuff_error

);
    reg [2:0] run_len; 
    reg prev; 


    always @(posedge clk) begin
        if(!rst_n) begin
            run_len <= 3'd0; 
            prev <= 1'b0; 
            o_stuff_error <= 1'b0; 
            o_bit_valid <= 1'b0;
        end

        else begin 
            o_bit_valid <= 1'b0; 
            if(i_flush) begin
                o_stuff_error <= 1'b0;
                if(i_bit_valid) begin
                    o_bit <= i_bit;
                    o_bit_valid <= 1'b1;
                    prev <= i_bit;
                    run_len <= 3'd1;
                end
            end

            else if(i_bit_valid) begin
                if(!i_stuffing_en) begin 
                    o_bit <= i_bit;
                    o_bit_valid <= 1'b1;
                end
                else if(run_len == 3'd5) begin 
                    if(i_bit == prev) begin 
                        o_stuff_error <= 1'b1;
                    end

                    prev <= i_bit; 
                    run_len <= 3'd1; 
                end

                else begin 
                    o_bit <= i_bit; 
                    o_bit_valid <= 1'b1; 
                    if (i_bit == prev) begin 
                        run_len <= run_len + 1'b1; 
                        prev <= i_bit;
                    end

                    else begin 
                        run_len <= 3'd1; 
                        prev <= i_bit;
                    end

                end
            end
        end
    end
endmodule

        







     
