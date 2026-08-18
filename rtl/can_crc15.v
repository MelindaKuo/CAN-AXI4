//recompute

`default_nettype none

module can_crc15 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        i_clear,     
    input  wire        i_bit,       
    input  wire        i_bit_valid, 
                                    
                                    

    output wire [14:0] o_crc        
                                    
);

    localparam [14:0] POLY = 15'h4599;

    reg [14:0] r; 
    wire fits = i_bit ^ r[14];

    integer c; 

    always @(posedge clk) begin 
        if(!rst_n || i_clear) begin 
            r <= 0; 
        end 

        else begin
            if (i_bit_valid) begin
                r <=fits ? ((r<<1)^POLY) : (r <<1);
            end
        end
    end


    assign o_crc = r; 


endmodule

`default_nettype wire
