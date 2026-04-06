`timescale 1ns / 1ps
module opcode_decoder(instr, opcode);
input [7:0] instr;
output reg [7:0] opcode;

//defining the different opcodes
parameter BRK = 0;
parameter ORA = 1;
parameter ASL = 2;
parameter PHP = 3;
parameter BPL = 4;
parameter CLC = 5;
parameter JSR = 6;
parameter AND = 7;
parameter ROL = 8;
parameter BIT = 9;
parameter PLP = 10;
parameter BMI = 11;
parameter SEC = 12;
parameter RTI = 13;
parameter EOR = 14;
parameter LSR = 15;
parameter PHA = 16;
parameter JMP = 17;
parameter BVC = 18;
parameter CLI = 19;
parameter RTS = 20;
parameter ADC = 21;
parameter ROR = 22;
parameter PLA = 23;
parameter BVS = 24;
parameter SEI = 25;
parameter STA = 26;
parameter STY = 27;
parameter STX = 28;
parameter DEY = 29;
parameter TXA = 30;
parameter BCC = 31;
parameter TYA = 32;
parameter TXS = 33;
parameter LDY = 34;
parameter LDA = 35;
parameter LDX = 36;
parameter TAY = 37;
parameter TAX = 38;
parameter BCS = 39;
parameter CLV = 40;
parameter TSX = 41;
parameter CPY = 42;
parameter CMP = 43;
parameter DEC = 44;
parameter INY = 45;
parameter DEX = 46;
parameter BNE = 47;
parameter CLD = 48;
parameter CPX = 49;
parameter SBC = 50;
parameter INC = 51;
parameter INX = 52;
parameter NOP = 53;
parameter BEQ = 54;
parameter SED = 55;
parameter EBT = 56;


//assigning opcodes
always @(*) begin
case (instr)
    8'h00 : opcode = BRK;
    8'h01 : opcode = ORA;
    8'h05 : opcode = ORA;
    8'h06 : opcode = ASL;
    8'h08 : opcode = PHP;
    8'h09 : opcode = ORA;
    8'h0a : opcode = ASL;
    8'h0d : opcode = ORA;
    8'h0e : opcode = ASL;
    
    
    8'h10 : opcode = BPL;
    8'h11 : opcode = ORA;
    8'h15 : opcode = ORA;
    8'h16 : opcode = ASL;
    8'h18 : opcode = CLC;
    8'h19 : opcode = ORA;
    8'h1d : opcode = ORA;
    8'h1e : opcode = ASL;
    
    
    8'h20 : opcode = JSR;
    8'h21 : opcode = AND;
    8'h24 : opcode = BIT;
    8'h25 : opcode = AND;
    8'h26 : opcode = ROL;
    8'h28 : opcode = PLP;
    8'h29 : opcode = AND;
    8'h2a : opcode = ROL;
    8'h2c : opcode = BIT;
    8'h2d : opcode = AND;
    8'h2e : opcode = ROL;
    
    
    8'h30 : opcode = BMI;
    8'h31 : opcode = AND;
    8'h35 : opcode = AND;
    8'h36 : opcode = ROL;
    8'h38 : opcode = SEC;
    8'h39 : opcode = AND;
    8'h3d : opcode = AND;
    8'h3e : opcode = ROL;
    
    
    8'h40 : opcode = RTI;
    8'h41 : opcode = EOR;
    8'h45 : opcode = EOR;
    8'h46 : opcode = LSR;
    8'h48 : opcode = PHA;
    8'h49 : opcode = EOR;
    8'h4a : opcode = LSR;
    8'h4c : opcode = JMP;
    8'h4d : opcode = EOR;
    8'h4e : opcode = LSR;
    
    
    8'h50 : opcode = BVC;
    8'h51 : opcode = EOR;
    8'h55 : opcode = EOR;
    8'h56 : opcode = LSR;
    8'h58 : opcode = CLI;
    8'h59 : opcode = EOR;
    8'h5d : opcode = EOR;
    8'h5e : opcode = LSR;
    
    
    8'h60 : opcode = RTS;
    8'h61 : opcode = ADC;
    8'h65 : opcode = ADC;
    8'h66 : opcode = ROR;
    8'h68 : opcode = PLA;
    8'h69 : opcode = ADC;
    8'h6a : opcode = ROR;
    8'h6c : opcode = JMP;
    8'h6d : opcode = ADC;
    8'h6e : opcode = ROR;
    
    
    8'h70 : opcode = BVS;
    8'h71 : opcode = ADC;
    8'h75 : opcode = ADC;
    8'h76 : opcode = ROR;
    8'h78 : opcode = SEI;
    8'h79 : opcode = ADC;
    8'h7d : opcode = ADC;
    8'h7e : opcode = ROR;
    
    
    8'h81 : opcode = STA;
    8'h84 : opcode = STY;
    8'h85 : opcode = STA;
    8'h86 : opcode = STX;
    8'h88 : opcode = DEY;
    8'h8a : opcode = TXA;
    8'h8c : opcode = STY;
    8'h8d : opcode = STA;
    8'h8e : opcode = STX;
    
    
    8'h90 : opcode = BCC;
    8'h91 : opcode = STA;
    8'h94 : opcode = STY;
    8'h95 : opcode = STA;
    8'h96 : opcode = STX;
    8'h98 : opcode = TYA;
    8'h99 : opcode = STA;
    8'h9a : opcode = TXS;
    8'h9d : opcode = STA;
    
    
    8'ha0 : opcode = LDY;
    8'ha1 : opcode = LDA;
    8'ha2 : opcode = LDX;
    8'ha4 : opcode = LDY;
    8'ha5 : opcode = LDA;
    8'ha6 : opcode = LDX;
    8'ha8 : opcode = TAY;
    8'ha9 : opcode = LDA;
    8'haa : opcode = TAX;
    8'hac : opcode = LDY;
    8'had : opcode = LDA;
    8'hae : opcode = LDX;
    
    
    8'hb0 : opcode = BCS;
    8'hb1 : opcode = LDA;
    8'hb4 : opcode = LDY;
    8'hb5 : opcode = LDA;
    8'hb6 : opcode = LDX;
    8'hb8 : opcode = CLV;
    8'hb9 : opcode = LDA;
    8'hba : opcode = TSX;
    8'hbc : opcode = LDY;
    8'hbd : opcode = LDA;
    8'hbe : opcode = LDX;
    
    
    8'hc0 : opcode = CPY;
    8'hc1 : opcode = CMP;
    8'hc4 : opcode = CPY;
    8'hc5 : opcode = CMP;
    8'hc6 : opcode = DEC;
    8'hc8 : opcode = INY;
    8'hc9 : opcode = CMP;
    8'hca : opcode = DEX;
    8'hcc : opcode = CPY;
    8'hcd : opcode = CMP;
    8'hce : opcode = DEC;
    
    
    8'hd0 : opcode = BNE;
    8'hd1 : opcode = CMP;
    8'hd5 : opcode = CMP;
    8'hd6 : opcode = DEC;
    8'hd8 : opcode = CLD;
    8'hd9 : opcode = CMP;
    8'hdd : opcode = CMP;
    8'hde : opcode = DEC;
    
      
    8'he0 : opcode = CPX;
    8'he1 : opcode = SBC;
    8'he4 : opcode = CPX;
    8'he5 : opcode = SBC;
    8'he6 : opcode = INC;
    8'he8 : opcode = INX;
    8'he9 : opcode = SBC;
    8'hea : opcode = NOP;
    8'hec : opcode = CPX;
    8'hed : opcode = SBC;
    8'hee : opcode = INC;
    
    
    8'hf0 : opcode = BEQ;
    8'hf1 : opcode = SBC;
    8'hf5 : opcode = SBC;
    8'hf6 : opcode = INC;
    8'hf8 : opcode = SED;
    8'hf9 : opcode = SBC;
    8'hfd : opcode = SBC;
    8'hfe : opcode = INC;
    8'hff : opcode = EBT;
    default: opcode = NOP;
endcase
end
endmodule
