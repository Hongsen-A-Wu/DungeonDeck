// 为 deck_manager.v 提供伪随机数，实现 FPGA 上的随机抽卡
// Zicheng
module lfsr_fib_16 #(parameter INITIAL_SEED = 16'hBEEF) (input wire reset, input wire clk,output reg [15:0] seed);
    
	 wire next_bit;
    assign next_bit = ((seed[15] ^ seed[13]) ^ seed[12]) ^ seed[10];
	 
    always @(posedge clk) begin
        if (reset) begin
            seed <= INITIAL_SEED;
        end else begin
            seed <= {seed[14:0], next_bit};
				
        end
    end
endmodule

//BEEF → 7DDE → FBBD → F77B → ...
// actually  LFSR (Linear Feedback Shift Register) ,it is a fake random,