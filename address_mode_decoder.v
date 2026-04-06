`timescale 1ns / 1ps
module address_mode_decoder(instr, address_mode);
input [7:0] instr;
output reg [3:0] address_mode;

//defining the different addressing modes
parameter ACC = 0;          //Accumulator
parameter IMM = 1;          //Immediate
parameter ZERO = 2;         //Zero Page
parameter ZERO_X = 3;       //Zero Page X
parameter ZERO_Y = 4;       //Zero Page Y
parameter ABS = 5;          //Absolute
parameter ABS_X = 6;        //Absolute X
parameter ABS_Y = 7;        //Absolute Y
parameter IMP = 8;          //Implied
parameter REL = 9;          //Relative
parameter IND = 10;         //Indirect
parameter IND_X = 11;       //Indirect X
parameter IND_Y = 12;       //Indirect Y
parameter ABS_IND = 13;     //Absolute Indirect

//assignning addressing modes
always @(*) begin 
if ( (instr == 8'h0a) || (instr == 8'h2a) || (instr == 8'h4a) 
|| (instr == 8'h6a) )
address_mode = ACC;

else if ( (instr == 8'h09) || (instr == 8'h29) || (instr == 8'h49) 
|| (instr == 8'h69) || (instr == 8'ha0) || (instr == 8'ha2) 
|| (instr == 8'ha9) || (instr == 8'hc0) || (instr == 8'hc9) 
|| (instr == 8'he0) || (instr == 8'he9) ) 
address_mode = IMM;


else if ( (instr == 8'h05) || (instr == 8'h06) || (instr == 8'h24) 
|| (instr == 8'h25) || (instr == 8'h26) || (instr == 8'h45) 
|| (instr == 8'h46) || (instr == 8'h65) || (instr == 8'h66) 
|| (instr == 8'h84) || (instr == 8'h85) || (instr == 8'h86) 
|| (instr == 8'ha4) || (instr == 8'ha5) || (instr == 8'ha6) || (instr == 8'hc4) 
|| (instr == 8'hc5) || (instr == 8'hc6) || (instr == 8'he4) 
|| (instr == 8'he5) || (instr == 8'he6) )
address_mode = ZERO;


else if ( (instr == 8'h15) || (instr == 8'h16) || (instr == 8'h35) 
|| (instr == 8'h36) || (instr == 8'h55) || (instr == 8'h56) 
|| (instr == 8'h75) || (instr == 8'h76) || (instr == 8'h94) 
|| (instr == 8'h95) || (instr == 8'hb4) || (instr == 8'hb5) 
|| (instr == 8'hd5) || (instr == 8'hd6) || (instr == 8'hf5) 
|| (instr == 8'hf6) )
address_mode = ZERO_X;


else if ( (instr == 8'h96) || (instr == 8'hb6) )
address_mode = ZERO_Y;


else if ( (instr == 8'h0d) || (instr == 8'h0e) || (instr == 8'h20) 
|| (instr == 8'h2c) || (instr == 8'h2d) || (instr == 8'h2e) 
|| (instr == 8'h4c) || (instr == 8'h4d) || (instr == 8'h4e) 
|| (instr == 8'h6d) || (instr == 8'h6e) || (instr == 8'h8c) 
|| (instr == 8'h8d) || (instr == 8'h8e) || (instr == 8'hac) 
|| (instr == 8'had) || (instr == 8'hae) || (instr == 8'hcc) 
|| (instr == 8'hcd) || (instr == 8'hce) || (instr == 8'hec) 
|| (instr == 8'hed) || (instr == 8'hee) )
address_mode = ABS;


else if ( (instr == 8'h1d) || (instr == 8'h1e) || (instr == 8'h3d) 
|| (instr == 8'h3e) || (instr == 8'h5d) || (instr == 8'h5e) 
|| (instr == 8'h7d) || (instr == 8'h7e) || (instr == 8'h9d) || (instr == 8'hbc) || (instr == 8'hbd) 
|| (instr == 8'hdd) || (instr == 8'hde) || (instr == 8'hfd) 
|| (instr == 8'hfe) )
address_mode = ABS_X;


else if ( (instr == 8'h19) || (instr == 8'h39) || (instr == 8'h59) 
|| (instr == 8'h79) || (instr == 8'hb9) || (instr == 8'hbe) 
|| (instr == 8'hd9) || (instr == 8'hf9) || (instr == 8'h99) )
address_mode = ABS_Y;


else if ( (instr == 8'h00) || (instr == 8'h08) || (instr == 8'h18) 
|| (instr == 8'h28) || (instr == 8'h38) || (instr == 8'h40) 
|| (instr == 8'h48) || (instr == 8'h58) || (instr == 8'h60) 
|| (instr == 8'h68) || (instr == 8'h78) || (instr == 8'h88) 
|| (instr == 8'h8a) || (instr == 8'h98) || (instr == 8'h9a) 
|| (instr == 8'ha8) || (instr == 8'haa) || (instr == 8'hb8) 
|| (instr == 8'hba) || (instr == 8'hc8) || (instr == 8'hca) 
|| (instr == 8'hd8) || (instr == 8'he8) || (instr == 8'hea) 
|| ( instr == 8'hf8) )
address_mode = IMP;


else if ( (instr == 8'h10) || (instr == 8'h30) || (instr == 8'h50) 
|| (instr == 8'h70) || (instr == 8'h90) || (instr == 8'hb0) 
|| (instr == 8'hd0) || (instr == 8'hf0) )
address_mode = REL;


else if (instr == 8'h6c) 
address_mode = IND;


else if ( (instr == 8'h01) || (instr == 8'h21) || (instr == 8'h41) 
|| (instr == 8'h61) || (instr == 8'h81) || (instr == 8'ha1) 
|| (instr == 8'hc1) || (instr == 8'he1) )
address_mode = IND_X;


else if ( (instr == 8'h11) || (instr == 8'h31) || (instr == 8'h51) 
|| (instr == 8'h71) || (instr == 8'h91) || (instr == 8'hb1) 
|| (instr == 8'hd1) || (instr == 8'hf1) )
address_mode = IND_Y;



else address_mode = IMP;

end

endmodule
