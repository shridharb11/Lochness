module alu #(parameter DATA_WIDTH = 8, OPCODE_WIDTH = 4)(
  input      [DATA_WIDTH-1:0]	      input1,
  input      [DATA_WIDTH-1:0]	      input2,	
  input                             carry_in,
  input      [OPCODE_WIDTH-1:0]	    opcode, 
  output reg [DATA_WIDTH-1:0]       result, 
  output reg [7:0]                  flags  
);
    //Parameters
    parameter ADC = 0;
    parameter SBC = 1;
    parameter AND = 2;
    parameter OR = 3;
    parameter XOR = 4;
    parameter ASL = 5;
    parameter LSR = 6;
    parameter ASR = 7;
    parameter ROL = 8;
    parameter ROR = 9;

  reg carry, overflow ; 
  
  always @(*) begin 

    result = {DATA_WIDTH{1'b0}}; 
    flags = 8'b0000;
    carry = 1'b0;
    overflow = 1'b0;

  	case(opcode)
    ADC: begin 
      {carry, result} = {1'b0,input1} + {1'b0,input2} + {8'b0,carry_in};
      if(input1[DATA_WIDTH-1] == input2[DATA_WIDTH-1] && result[DATA_WIDTH-1] != input1[DATA_WIDTH-1]) overflow = 1;
    end 
    
    SBC: begin 
      {carry, result} = {1'b0,input1} + {1'b0,~input2} + {8'b0,carry_in};
      if((input1[DATA_WIDTH-1] != input2[DATA_WIDTH-1]) && (input1[DATA_WIDTH-1] != result[DATA_WIDTH-1])) overflow = 1;
    end
    
    AND: begin 
     result = input1 & input2 ;
    end
    
    OR: begin 
     result = input1 | input2 ; 
    end
        
    XOR: begin 
     result = input1 ^ input2 ;
    end
       
    ASL: begin 
      carry = input1[DATA_WIDTH-1];
      result = input1 << 1;
    end
        
    LSR: begin 
      carry = input1[0];
      result = input1 >> 1;
    end
        
    ASR: begin
      carry  = input1[0];
      result = {input1[DATA_WIDTH-1], input1[DATA_WIDTH-1:1]};
    end
        
    ROL: begin
      carry  = input1[DATA_WIDTH-1];
      result = {input1[DATA_WIDTH-2:0], carry_in};
    end

    ROR: begin
      carry  = input1[0];
      result = {carry_in, input1[DATA_WIDTH-1:1]};
    end

    default: result = {DATA_WIDTH{1'b0}};    
    endcase

    //State Register Updates 
    flags[3] = result[DATA_WIDTH-1];      //Negative 
    flags[2] = (result == 0);             //Zero
    flags[1] = carry;                     //Carry
    flags[0] = overflow;                  //Overflow 
    
  end 
endmodule
