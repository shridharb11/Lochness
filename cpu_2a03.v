//`include "alu.v"
//`include "address_mode_decoder.v"
//`include "opcode_decoder.v"
//`include "interrupt_control.v"

module cpu_2a03 (
    input  wire         cpu_clk,
    input  wire         reset,
    input  wire         clk_en,
    input  wire         nmi_in,
    input  wire         irq_in,
    input  wire         rdy,
    input  wire [7:0]   data_in,
    output wire [7:0]   data_out,
    output wire [15:0]  addr,
    output wire         rw,
    output wire         sync
);
    reg [7:0]  A;
    reg [7:0]  X;
    reg [7:0]  Y;
    reg [7:0]  SP;
    reg [15:0] PC;
    reg [7:0]  P;
    reg [7:0]  data_out_reg;
    reg [15:0] addr_reg;
    reg        rw_reg;

    assign addr     = addr_reg;
    assign data_out = data_out_reg;
    assign rw       = rw_reg;

    localparam FLAG_C = 0;
    localparam FLAG_Z = 1;
    localparam FLAG_I = 2;
    localparam FLAG_D = 3;
    localparam FLAG_B = 4;
    localparam FLAG_U = 5;
    localparam FLAG_V = 6;
    localparam FLAG_N = 7;

    // Addressing mode encodings
    localparam ACC     = 0;
    localparam IMM     = 1;
    localparam ZERO    = 2;
    localparam ZERO_X  = 3;
    localparam ZERO_Y  = 4;
    localparam ABS     = 5;
    localparam ABS_X   = 6;
    localparam ABS_Y   = 7;
    localparam IMP     = 8;
    localparam REL     = 9;
    localparam IND     = 10;
    localparam IND_X   = 11;
    localparam IND_Y   = 12;
    localparam ABS_IND = 13;

    // Decoded instruction encodings 
    localparam BRK = 0;
    localparam ORA = 1;
    localparam ASL = 2;
    localparam PHP = 3;
    localparam BPL = 4;
    localparam CLC = 5;
    localparam JSR = 6;
    localparam AND = 7;
    localparam ROL = 8;
    localparam BIT = 9;
    localparam PLP = 10;
    localparam BMI = 11;
    localparam SEC = 12;
    localparam RTI = 13;
    localparam EOR = 14;
    localparam LSR = 15;
    localparam PHA = 16;
    localparam JMP = 17;
    localparam BVC = 18;
    localparam CLI = 19;
    localparam RTS = 20;
    localparam ADC = 21;
    localparam ROR = 22;
    localparam PLA = 23;
    localparam BVS = 24;
    localparam SEI = 25;
    localparam STA = 26;
    localparam STY = 27;
    localparam STX = 28;
    localparam DEY = 29;
    localparam TXA = 30;
    localparam BCC = 31;
    localparam TYA = 32;
    localparam TXS = 33;
    localparam LDY = 34;
    localparam LDA = 35;
    localparam LDX = 36;
    localparam TAY = 37;
    localparam TAX = 38;
    localparam BCS = 39;
    localparam CLV = 40;
    localparam TSX = 41;
    localparam CPY = 42;
    localparam CMP = 43;
    localparam DEC = 44;
    localparam INY = 45;
    localparam DEX = 46;
    localparam BNE = 47;
    localparam CLD = 48;
    localparam CPX = 49;
    localparam SBC = 50;
    localparam INC = 51;
    localparam INX = 52;
    localparam NOP = 53;
    localparam BEQ = 54;
    localparam SED = 55;
    localparam EBT = 56;

    // ALU opcode encodings 
    localparam ALU_ADC = 4'd0;
    localparam ALU_SBC = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_ASL = 4'd5;
    localparam ALU_LSR = 4'd6;
    localparam ALU_ASR = 4'd7;
    localparam ALU_ROL = 4'd8;
    localparam ALU_ROR = 4'd9;

    localparam STATE_RESET   = 4'd0;
    localparam STATE_FETCH   = 4'd1;
    localparam STATE_DECODE  = 4'd2;
    localparam STATE_EXECUTE = 4'd3;
    localparam STATE_REL_1   = 4'd4;   
    localparam STATE_INT_1   = 4'd5;
    localparam STATE_INT_2   = 4'd6;
    localparam STATE_INT_3   = 4'd7;
    localparam STATE_INT_4   = 4'd8;
    localparam STATE_INT_5   = 4'd9;
    localparam STATE_INT_6   = 4'd10;
    localparam STATE_REL_2   = 4'd11;

    reg [7:0]  opcode_raw;
    reg [7:0]  operand_lo;
    reg [7:0]  operand_hi;
    reg [15:0] effective_addr;
    reg [7:0]  temp_data;
    reg [3:0]  cycle;           
    reg [3:0]  state;
    reg        page_crossed;
    reg [15:0] temp_addr;
    reg [15:0] return_addr;

    reg        serving_nmi;
    reg        serving_brk;
    reg [15:0] branch_target;  
    reg [7:0]  branch_pc_hi;    
    reg [7:0]  ind_y_lo;
    reg [7:0] result;
    
    wire branch_cond =
        (opcode == BCC && !P[FLAG_C]) ||
        (opcode == BCS &&  P[FLAG_C]) ||
        (opcode == BEQ &&  P[FLAG_Z]) ||
        (opcode == BNE && !P[FLAG_Z]) ||
        (opcode == BMI &&  P[FLAG_N]) ||
        (opcode == BPL && !P[FLAG_N]) ||
        (opcode == BVC && !P[FLAG_V]) ||
        (opcode == BVS &&  P[FLAG_V]);

    reg [8:0]  arith_sum;
    reg [8:0]  arith_diff;
    reg [8:0]  arith_cmp;
    reg  [3:0] alu_opcode;
    reg  [7:0] alu_input1;
    wire [7:0] alu_result;
    wire [7:0] alu_flags;

    wire [3:0] acc_alu_op =
        (opcode == ASL) ? ALU_ASL :
        (opcode == LSR) ? ALU_LSR :
        (opcode == ROL) ? ALU_ROL :
                          ALU_ROR;

    wire acc_carry_h = A[7];   // carry out for ASL 
    wire acc_carry_l = A[0];   // carry out for LSR 
    wire [3:0] alu_op_mux   = (address_mode == ACC) ? acc_alu_op : alu_opcode;
    wire [7:0] alu_in1_mux  = (address_mode == ACC) ? A          : alu_input1;

    alu #(.DATA_WIDTH(8), .OPCODE_WIDTH(4)) alu_inst (
        .input1   (alu_in1_mux),
        .input2   (8'h00),
        .carry_in (P[FLAG_C]),
        .opcode   (alu_op_mux),
        .result   (alu_result),
        .flags    (alu_flags)
    );

    // Interrupt controller
    wire IRQ, NMI, RESET_INT;
    reg  IRQ_CLEAR, NMI_CLEAR;
    reg  RESET_CLEAR;

    Interrupt_Control int_ctrl_inst (
        .MCLR       (reset),
        .clk        (cpu_clk),
        .IRQ_INHIBIT(P[FLAG_I]),
        .IRQ_LINE   (irq_in),
        .IRQ_CLEAR  (IRQ_CLEAR),
        .NMI_LINE   (nmi_in),
        .NMI_CLEAR  (NMI_CLEAR),
        .IRQ        (IRQ),
        .NMI        (NMI),
        .RESET_INT  (RESET_INT),
        .RESET_CLEAR(RESET_CLEAR)
    );

    wire [7:0] opcode;
    wire [3:0] address_mode;

    opcode_decoder opcode_dec_inst (
        .instr       (opcode_raw),
        .opcode      (opcode)
    );

    address_mode_decoder addr_mode_dec_inst (
        .instr       (opcode_raw),
        .address_mode(address_mode)
    );

    assign sync = (state == STATE_FETCH);

    function [7:0] update_nz;
        input [7:0] flags_in;
        input [7:0] value;
        begin
            update_nz        = flags_in;
            update_nz[FLAG_N] = value[7];
            update_nz[FLAG_Z] = (value == 8'h00);
        end
    endfunction

    function [7:0] p_after_adc;
        input [7:0] flags_in;
        input [7:0] acc;
        input [7:0] mem;
        input       carry;
        reg   [8:0] s;
        reg   [7:0] f;
        begin
            s           = {1'b0, acc} + {1'b0, mem} + {8'b0, carry};
            f           = flags_in;
            f[FLAG_C]   = s[8];
            f[FLAG_V]   = (~(acc[7] ^ mem[7])) & (acc[7] ^ s[7]);
            f[FLAG_N]   = s[7];
            f[FLAG_Z]   = (s[7:0] == 8'h00);
            p_after_adc = f;
        end
    endfunction

    function [7:0] p_after_sbc;
        input [7:0] flags_in;
        input [7:0] acc;
        input [7:0] mem;
        input       carry;
        reg   [8:0] d;
        reg   [7:0] f;
        begin
            d           = {1'b0, acc} - {1'b0, mem} - {8'b0, ~carry};
            f           = flags_in;
            f[FLAG_C]   = ~d[8];
            f[FLAG_V]   = (acc[7] ^ mem[7]) & (acc[7] ^ d[7]);
            f[FLAG_N]   = d[7];
            f[FLAG_Z]   = (d[7:0] == 8'h00);
            p_after_sbc = f;
        end
    endfunction

    function [7:0] p_after_cmp;
        input [7:0] flags_in;
        input [7:0] reg_val;
        input [7:0] mem;
        reg [7:0] result;
        begin
            result = reg_val - mem;
            
            p_after_cmp = flags_in;
            
            p_after_cmp[FLAG_N] = result[7];
            
            p_after_cmp[FLAG_Z] = (reg_val == mem);
            
            p_after_cmp[FLAG_C] = (reg_val >= mem);
        end
    endfunction

    always @(posedge cpu_clk) begin
        if (reset) begin
            A            <= 8'h00;
            X            <= 8'h00;
            Y            <= 8'h00;
            SP           <= 8'hFD;
            P            <= 8'b00100100;   
            PC           <= 16'h0000;
            IRQ_CLEAR    <= 1'b0;
            NMI_CLEAR    <= 1'b0;
            RESET_CLEAR  <= 1'b0;   
            state        <= STATE_RESET;
            cycle        <= 4'd0;
            addr_reg     <= 16'hFFFC;
            rw_reg       <= 1'b1;
            data_out_reg <= 8'h00;
            opcode_raw   <= 8'h00;
            operand_lo   <= 8'h00;
            operand_hi   <= 8'h00;
            effective_addr <= 16'h0000;
            temp_data    <= 8'h00;
            page_crossed <= 1'b0;
            serving_nmi  <= 1'b0;
            serving_brk  <= 1'b0;    
            ind_y_lo     <= 8'h00;   
            branch_pc_hi <= 8'h00;   
            alu_opcode   <= 4'd0;
            alu_input1   <= 8'h00;
        end

        else if (clk_en && rdy) begin
            IRQ_CLEAR   <= 1'b0;
            NMI_CLEAR   <= 1'b0;
            RESET_CLEAR <= 1'b0;   

            case (state)
            STATE_RESET: begin
                case (cycle)
                    4'd0: begin
                        addr_reg <= 16'hFFFC;
                        rw_reg   <= 1'b1;
                        cycle    <= 4'd1;
                    end
                    4'd1: begin
                        operand_lo <= data_in;
                        addr_reg   <= 16'hFFFD;
                        rw_reg     <= 1'b1;
                        cycle      <= 4'd2;
                    end
                    4'd2: begin
                        PC          <= {data_in, operand_lo};
                        addr_reg    <= {data_in, operand_lo};
                        RESET_CLEAR <= 1'b1;
                        state       <= STATE_FETCH;
                        cycle       <= 4'd0;
                    end
                endcase
            end

            STATE_FETCH: begin
                if (NMI) begin
                    NMI_CLEAR   <= 1'b1;
                    serving_nmi <= 1'b1;
                    serving_brk <= 1'b0;
                    cycle       <= 4'd0;
                    state       <= STATE_INT_1;
                end
                else if (IRQ) begin
                    IRQ_CLEAR   <= 1'b1;
                    serving_nmi <= 1'b0;
                    serving_brk <= 1'b0;
                    cycle       <= 4'd0;
                    state       <= STATE_INT_1;
                end
                else if (data_in == BRK)begin
                      serving_brk <= 1'b1;
                      serving_nmi <= 1'b0;
                      PC          <= PC + 16'd2;
                      addr_reg    <= PC + 16'd2;
                      rw_reg      <= 1'b1;
                      cycle       <= 4'd0;
                      state       <= STATE_INT_1;
                end else begin
                    opcode_raw <= data_in;
                    PC         <= PC + 16'd1;
                    addr_reg   <= PC + 16'd1;
                    rw_reg     <= 1'b1;
                    state      <= STATE_DECODE;
                    cycle      <= 4'd1;
                end
            end
            STATE_DECODE: begin
                case (address_mode)
                IMP, ACC: begin
                    case (opcode)
                        CLC: P[FLAG_C] <= 1'b0;
                        SEC: P[FLAG_C] <= 1'b1;
                        CLI: P[FLAG_I] <= 1'b0;
                        SEI: P[FLAG_I] <= 1'b1;
                        CLV: P[FLAG_V] <= 1'b0;
                        CLD: P[FLAG_D] <= 1'b0;
                        SED: P[FLAG_D] <= 1'b1;   

                        INX: begin X <= X + 8'd1; P <= update_nz(P, X + 8'd1); end
                        INY: begin Y <= Y + 8'd1; P <= update_nz(P, Y + 8'd1); end
                        DEX: begin X <= X - 8'd1; P <= update_nz(P, X - 8'd1); end
                        DEY: begin Y <= Y - 8'd1; P <= update_nz(P, Y - 8'd1); end

                        TAX: begin X <= A;  P <= update_nz(P, A);  end
                        TAY: begin Y <= A;  P <= update_nz(P, A);  end
                        TXA: begin A <= X;  P <= update_nz(P, X);  end
                        TYA: begin A <= Y;  P <= update_nz(P, Y);  end
                        TSX: begin X <= SP; P <= update_nz(P, SP); end
                        TXS: begin SP <= X; end    

                        ASL: if (address_mode == ACC) begin
                            A        <= {A[6:0], 1'b0};
                            P        <= update_nz({P[7:1], acc_carry_h}, {A[6:0], 1'b0});
                            addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                        end
                        LSR: if (address_mode == ACC) begin
                            A        <= {1'b0, A[7:1]};
                            P        <= update_nz({P[7:1], acc_carry_l}, {1'b0, A[7:1]});
                            addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                        end
                        ROL: if (address_mode == ACC) begin
                            A        <= {A[6:0], P[FLAG_C]};
                            P        <= update_nz({P[7:1], acc_carry_h}, {A[6:0], P[FLAG_C]});
                            addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                        end
                        ROR: if (address_mode == ACC) begin
                            A        <= {P[FLAG_C], A[7:1]};
                            P        <= update_nz({P[7:1], acc_carry_l}, {P[FLAG_C], A[7:1]});
                            addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                        end

                        PHP: begin
                            addr_reg     <= {8'h01, SP};
                            rw_reg       <= 1'b0;
                            data_out_reg <= P | 8'b00110000;
                            SP           <= SP - 8'd1;
                            state        <= STATE_EXECUTE;
                            cycle        <= 4'd2;
                        end

                        PHA: begin
                            addr_reg     <= {8'h01, SP};
                            rw_reg       <= 1'b0;
                            data_out_reg <= A;
                            SP           <= SP - 8'd1;
                            state        <= STATE_EXECUTE;
                            cycle        <= 4'd2;
                        end

                        PLP: begin
                            addr_reg <= {8'h01, SP};
                            rw_reg   <= 1'b1;
                            state    <= STATE_EXECUTE;
                            cycle    <= 4'd2;
                        end

                        PLA: begin
                            addr_reg <= {8'h01, SP};
                            rw_reg   <= 1'b1;
                            state    <= STATE_EXECUTE;
                            cycle    <= 4'd2;
                        end

                        RTS: begin
                            addr_reg <= {8'h01, SP};   
                            rw_reg   <= 1'b1;
                            state    <= STATE_EXECUTE;
                            cycle    <= 4'd2;
                        end

                        RTI: begin
                            addr_reg <= {8'h01, SP};   
                            rw_reg   <= 1'b1;
                            state    <= STATE_EXECUTE;
                            cycle    <= 4'd2;
                        end

                        BRK: begin
                            serving_brk <= 1'b1;
                            serving_nmi <= 1'b0;
                            PC          <= PC + 16'd1;
                            addr_reg    <= PC + 16'd1;
                            rw_reg      <= 1'b1;
                            cycle       <= 4'd0;
                            state       <= STATE_INT_1;
                        end

                        NOP: begin /* no operation */ end

                        default: begin /* unrecognised IMP/ACC opcode - treat as NOP */ end
                    endcase
                    if (opcode != PHP && opcode != PHA &&
                        opcode != PLP && opcode != PLA &&
                        opcode != JSR && opcode != RTS &&
                        opcode != RTI && opcode != BRK) begin

                        addr_reg <= PC;
                        rw_reg   <= 1'b1;
                        state    <= STATE_FETCH;
                    end
                end

                IMM: begin
                    PC       <= PC + 16'd1;
                    addr_reg <= PC + 16'd1;

                    case (opcode)
                        LDA: begin A <= data_in; P <= update_nz(P, data_in); end
                        LDX: begin X <= data_in; P <= update_nz(P, data_in); end
                        LDY: begin Y <= data_in; P <= update_nz(P, data_in); end
                        ADC: begin A <= ({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P <= p_after_adc(P, A, data_in, P[FLAG_C]); end
                        SBC: begin A <= ({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P <= p_after_sbc(P, A, data_in, P[FLAG_C]); end
                        AND: begin A <= A & data_in; P <= update_nz(P, A & data_in); end
                        ORA: begin A <= A | data_in; P <= update_nz(P, A | data_in); end
                        EOR: begin A <= A ^ data_in; P <= update_nz(P, A ^ data_in); end
                        CMP: P <= p_after_cmp(P, A, data_in);
                        CPX: P <= p_after_cmp(P, X, data_in);
                        CPY: P <= p_after_cmp(P, Y, data_in);
                        default: begin end
                    endcase
                    state <= STATE_FETCH;
                end

                ZERO: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo     <= data_in;
                            PC             <= PC + 16'd1;
                            effective_addr <= {8'h00, data_in};
                            addr_reg       <= {8'h00, data_in};
                            if (opcode == STA || opcode == STX || opcode == STY) begin
                                rw_reg <= 1'b0;
                                case (opcode)
                                    STA: data_out_reg <= A;
                                    STX: data_out_reg <= X;
                                    STY: data_out_reg <= Y;
                                endcase
                            end else
                                rw_reg <= 1'b1;
                            cycle <= 4'd2;
                        end
                        4'd2: begin
                            if (opcode == STA || opcode == STX || opcode == STY) begin
                                addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                            end else begin
                                temp_data <= data_in;
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDX: begin X<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDY: begin Y<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CPX: begin P<=p_after_cmp(P,X,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CPY: begin P<=p_after_cmp(P,Y,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    BIT: begin
                                        P[FLAG_N] <= data_in[7];
                                        P[FLAG_V] <= data_in[6];
                                        P[FLAG_Z] <= ((A & data_in) == 8'h00);
                                        addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                                    end
                                    ASL,LSR,ROL,ROR,INC,DEC: begin
                                        addr_reg <= effective_addr; rw_reg<=1'b1; cycle<=4'd3;
                                    end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                        4'd3: begin  
                            addr_reg <= effective_addr; rw_reg <= 1'b0;
                            case (opcode)
                                ASL: begin data_out_reg<={temp_data[6:0],1'b0};       P<=(update_nz(P,{temp_data[6:0],1'b0})      &8'hFE)|(temp_data[7]  ?8'h01:8'h00); end
                                LSR: begin data_out_reg<={1'b0,temp_data[7:1]};        P<=(update_nz(P,{1'b0,temp_data[7:1]})       &8'hFE)|(temp_data[0]  ?8'h01:8'h00); end
                                ROL: begin data_out_reg<={temp_data[6:0],P[FLAG_C]};   P<=(update_nz(P,{temp_data[6:0],P[FLAG_C]})  &8'hFE)|(temp_data[7]  ?8'h01:8'h00); end
                                ROR: begin data_out_reg<={P[FLAG_C],temp_data[7:1]};   P<=(update_nz(P,{P[FLAG_C],temp_data[7:1]})  &8'hFE)|(temp_data[0]  ?8'h01:8'h00); end
                                INC: begin data_out_reg<=temp_data+8'd1;               P<=update_nz(P,temp_data+8'd1); end
                                DEC: begin data_out_reg<=temp_data-8'd1;               P<=update_nz(P,temp_data-8'd1); end
                            endcase
                            cycle <= 4'd4;
                        end
                        4'd4: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                    endcase
                end

                ZERO_X: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= {8'h00, data_in};  // dummy read of ZP base
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd2;
                        end
                        4'd2: begin
                            effective_addr <= {8'h00, operand_lo + X};
                            addr_reg       <= {8'h00, operand_lo + X};
                            if (opcode == STA || opcode == STY) begin
                                rw_reg       <= 1'b0;
                                data_out_reg <= (opcode == STA) ? A : Y;
                                cycle        <= 4'd3;
                            end else begin
                                rw_reg <= 1'b1; cycle <= 4'd3;
                            end
                        end
                        4'd3: begin
                            if (opcode == STA || opcode == STY) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else begin
                                temp_data <= data_in;
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDY: begin Y<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CPX: begin P<=p_after_cmp(P,X,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CPY: begin P<=p_after_cmp(P,Y,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ASL,LSR,ROL,ROR,INC,DEC: begin
                                        addr_reg<=effective_addr; rw_reg<=1'b1; cycle<=4'd4;
                                    end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                        4'd4: begin  
                            addr_reg <= effective_addr; rw_reg <= 1'b0;
                            case (opcode)
                                ASL: begin data_out_reg<={temp_data[6:0],1'b0};      P<=(update_nz(P,{temp_data[6:0],1'b0})     &8'hFE)|(temp_data[7]?8'h01:8'h00); end
                                LSR: begin data_out_reg<={1'b0,temp_data[7:1]};       P<=(update_nz(P,{1'b0,temp_data[7:1]})      &8'hFE)|(temp_data[0]?8'h01:8'h00); end
                                ROL: begin data_out_reg<={temp_data[6:0],P[FLAG_C]};  P<=(update_nz(P,{temp_data[6:0],P[FLAG_C]}) &8'hFE)|(temp_data[7]?8'h01:8'h00); end
                                ROR: begin data_out_reg<={P[FLAG_C],temp_data[7:1]};  P<=(update_nz(P,{P[FLAG_C],temp_data[7:1]}) &8'hFE)|(temp_data[0]?8'h01:8'h00); end
                                INC: begin data_out_reg<=temp_data+8'd1; P<=update_nz(P,temp_data+8'd1); end
                                DEC: begin data_out_reg<=temp_data-8'd1; P<=update_nz(P,temp_data-8'd1); end
                            endcase
                            cycle <= 4'd5;
                        end
                        4'd5: begin
                            addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                        end
                    endcase
                end

                ZERO_Y: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= {8'h00, data_in};  // dummy read
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd2;
                        end
                        4'd2: begin
                            effective_addr <= {8'h00, operand_lo + Y};
                            addr_reg       <= {8'h00, operand_lo + Y};
                            if (opcode == STX) begin
                                rw_reg <= 1'b0; data_out_reg <= X; cycle <= 4'd3;
                            end else begin
                                rw_reg <= 1'b1; cycle <= 4'd3;
                            end
                        end
                        4'd3: begin
                            if (opcode == STX) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else begin
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDX: begin X<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                    endcase
                end

                ABS: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= PC + 16'd1;
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd2;
                        end
                        4'd2: begin
                            operand_hi     <= data_in;
                            PC             <= PC + 16'd1;
                            effective_addr <= {data_in, operand_lo};
                            
                            if (opcode == JMP) begin
                                PC       <= {data_in, operand_lo};
                                addr_reg <= {data_in, operand_lo};
                                state    <= STATE_FETCH;
                            end else if (opcode == JSR) begin
                                addr_reg <= {8'h01, SP};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd3;
                                return_addr <= PC;         
                            end else if (opcode == STA || opcode == STX || opcode == STY) begin
                                addr_reg <= {data_in, operand_lo};
                                rw_reg <= 1'b0;
                                case (opcode)
                                    STA: data_out_reg <= A;
                                    STX: data_out_reg <= X;
                                    STY: data_out_reg <= Y;
                                endcase
                                cycle <= 4'd3;
                            end else begin
                                addr_reg <= {data_in, operand_lo};
                                rw_reg <= 1'b1; cycle <= 4'd3;
                            end
                        end
                        4'd3: begin
                            if (opcode == JSR) begin
                                addr_reg     <= {8'h01, SP};
                                rw_reg       <= 1'b0;
                                data_out_reg <= return_addr[15:8];
                                SP           <= SP - 8'd1;
                                cycle        <= 4'd4;
                            end else if (opcode == STA || opcode == STX || opcode == STY) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else begin
                                temp_data <= data_in;
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDX: begin X<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDY: begin Y<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CPX: begin P<=p_after_cmp(P,X,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CPY: begin P<=p_after_cmp(P,Y,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    BIT: begin P[FLAG_N]<=data_in[7]; P[FLAG_V]<=data_in[6]; P[FLAG_Z]<=((A&data_in)==8'h00); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ASL,LSR,ROL,ROR,INC,DEC: begin
                                        addr_reg<=effective_addr; rw_reg<=1'b1; cycle<=4'd4;
                                    end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                        4'd4: begin
                            if (opcode == JSR) begin
                                addr_reg     <= {8'h01, SP};
                                rw_reg       <= 1'b0;
                                data_out_reg <= return_addr[7:0];
                                SP           <= SP - 8'd1;
                                cycle        <= 4'd5;
                            end else begin
                                addr_reg<=effective_addr; rw_reg<=1'b0;
                                case (opcode)
                                    ASL: begin data_out_reg<={temp_data[6:0],1'b0};      P<=(update_nz(P,{temp_data[6:0],1'b0})     &8'hFE)|(temp_data[7]?8'h01:8'h00); end
                                    LSR: begin data_out_reg<={1'b0,temp_data[7:1]};       P<=(update_nz(P,{1'b0,temp_data[7:1]})      &8'hFE)|(temp_data[0]?8'h01:8'h00); end
                                    ROL: begin data_out_reg<={temp_data[6:0],P[FLAG_C]};  P<=(update_nz(P,{temp_data[6:0],P[FLAG_C]}) &8'hFE)|(temp_data[7]?8'h01:8'h00); end
                                    ROR: begin data_out_reg<={P[FLAG_C],temp_data[7:1]};  P<=(update_nz(P,{P[FLAG_C],temp_data[7:1]}) &8'hFE)|(temp_data[0]?8'h01:8'h00); end
                                    INC: begin data_out_reg<=temp_data+8'd1; P<=update_nz(P,temp_data+8'd1); end
                                    DEC: begin data_out_reg<=temp_data-8'd1; P<=update_nz(P,temp_data-8'd1); end
                                endcase
                                cycle <= 4'd5;
                            end
                        end
                        4'd5: begin
                            if (opcode == JSR) begin
                                PC       <= {operand_hi, operand_lo};
                                addr_reg <= {operand_hi, operand_lo};
                                rw_reg   <= 1'b1;
                                state    <= STATE_FETCH;
                            end else begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end
                        end
                    endcase
                end

                ABS_X: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC <= PC + 16'd1;
                            addr_reg <= PC + 16'd1;
                            rw_reg <= 1'b1;
                            cycle <= 4'd2;
                        end
                        4'd2: begin
                            operand_hi <= data_in;
                            PC         <= PC + 16'd1;
                            {page_crossed, effective_addr[7:0]} <= {1'b0, operand_lo} + {1'b0, X};
                            effective_addr[15:8] <= data_in;
                            addr_reg <= {data_in, operand_lo + X};
                            rw_reg   <= 1'b1;
                            cycle    <= 4'd3;
                        end
                        4'd3: begin
                            if (page_crossed) begin
                                if (opcode == STA) begin
                                    addr_reg <= {operand_hi + 8'd1, effective_addr[7:0]};
                                    effective_addr[15:8] <= operand_hi + 8'd1;
                                    rw_reg       <= 1'b0;
                                    data_out_reg <= A;
                                    cycle        <= 4'd4;
                                   end else begin
                                    effective_addr[15:8] <= operand_hi + 8'd1;
                                    addr_reg <= {operand_hi + 8'd1, effective_addr[7:0]};
                                    rw_reg   <= 1'b1;
                                    cycle    <= 4'd4;
                                    end
                            end else begin
                                if (opcode == STA) begin
                                    addr_reg     <= effective_addr;
                                    rw_reg       <= 1'b0;
                                    data_out_reg <= A;
                                    cycle        <= 4'd4;
                                end else begin
                                    temp_data <= data_in;
                                    case (opcode)
                                        LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        LDY: begin Y<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ASL,LSR,ROL,ROR,INC,DEC: begin
                                            addr_reg<=effective_addr; rw_reg<=1'b1; cycle<=4'd4;
                                        end
                                        default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    endcase
                                end
                            end
                        end
                        
                        
                        
                        4'd4: begin
                            if (opcode == STA) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else if (page_crossed || opcode == ASL || opcode == LSR || opcode == ROR || opcode == ROL || opcode == INC || opcode == DEC) begin
                                temp_data <= data_in;
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDY: begin Y<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ASL,LSR,ROL,ROR,INC,DEC: begin
                                        addr_reg<=effective_addr; rw_reg<=1'b0; cycle<=4'd5;
                                        data_out_reg <= data_in;
                                        result <= data_in;
                                    end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                              end
                        end
                        4'd5: begin
                             addr_reg  <= effective_addr;
                                rw_reg    <= 1'b0;
                                case (opcode)
                                    ASL: begin data_out_reg<={result[6:0],1'b0};      P<=(update_nz(P,{result[6:0],1'b0})     &8'hFE)|(result[7]?8'h01:8'h00); end
                                    LSR: begin data_out_reg<={1'b0,result[7:1]};       P<=(update_nz(P,{1'b0,result[7:1]})      &8'hFE)|(result[0]?8'h01:8'h00); end
                                    ROL: begin data_out_reg<={result[6:0],P[FLAG_C]};  P<=(update_nz(P,{result[6:0],P[FLAG_C]}) &8'hFE)|(result[7]?8'h01:8'h00); end
                                    ROR: begin data_out_reg<={P[FLAG_C],result[7:1]};  P<=(update_nz(P,{P[FLAG_C],result[7:1]}) &8'hFE)|(result[0]?8'h01:8'h00); end
                                    INC: begin data_out_reg<=result+8'd1; P<=update_nz(P,result+8'd1); end
                                    DEC: begin data_out_reg<=result-8'd1; P<=update_nz(P,result-8'd1); end
                                endcase
                                cycle <= 4'd6;
                            end 

                        4'd6: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                    endcase
                end

                ABS_Y: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC <= PC + 16'd1;
                            addr_reg <= PC + 16'd1;
                            rw_reg <= 1'b1;
                            cycle <= 4'd2;
                        end
                        4'd2: begin
                            operand_hi <= data_in;
                            PC         <= PC + 16'd1;
                            {page_crossed, effective_addr[7:0]} <= {1'b0, operand_lo} + {1'b0, Y};
                            effective_addr[15:8] <= data_in;
                            addr_reg <= {data_in, operand_lo + Y};
                            rw_reg   <= 1'b1;
                            cycle    <= 4'd3;
                        end
                        4'd3: begin
                            if (({1'b0, operand_lo} + {1'b0, Y}) > 9'h0FF) begin
                                if (opcode == STA) begin
                                effective_addr[15:8] <= operand_hi + 8'd1;
                                addr_reg <= {operand_hi + 8'd1, effective_addr[7:0]};
                                rw_reg<=1'b0;
                                data_out_reg<=A;
                                cycle<=4'd4;
                                end else begin
                                effective_addr[15:8] <= operand_hi + 8'd1;
                                addr_reg <= {operand_hi + 8'd1, effective_addr[7:0]};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd4;
                                end
                            end else begin
                                if (opcode == STA) begin
                                    addr_reg<=effective_addr; rw_reg<=1'b0; data_out_reg<=A; cycle<=4'd4;
                                end else begin
                                    case (opcode)
                                        LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        LDX: begin X<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    endcase
                                end
                            end
                        end
                        4'd4: begin
                            if (opcode == STA) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else begin
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    LDX: begin X<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                    endcase
                end

                IND_X: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= {8'h00, data_in};  
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd2;
                        end
                        4'd2: begin
                            effective_addr[7:0] <= operand_lo + X;
                            addr_reg <= {8'h00, operand_lo + X};
                            rw_reg   <= 1'b1;
                            cycle    <= 4'd3;
                        end
                        4'd3: begin
                            operand_lo <= data_in;
                            addr_reg   <= {8'h00, effective_addr[7:0] + 8'd1};
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd4;
                        end
                        4'd4: begin
                            effective_addr <= {data_in, operand_lo};
                            addr_reg       <= {data_in, operand_lo};
                            if (opcode == STA) begin
                                rw_reg <= 1'b0; data_out_reg <= A; cycle <= 4'd5;
                            end else begin
                                rw_reg <= 1'b1; cycle <= 4'd5;
                            end
                        end
                        4'd5: begin
                            if (opcode == STA) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else begin
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                    endcase
                end

                IND_Y: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= {8'h00, data_in};  
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd2;
                        end
                        4'd2: begin
                            effective_addr[7:0] <= data_in;  
                            addr_reg <= {8'h00, operand_lo + 8'd1};  
                            rw_reg   <= 1'b1;
                            cycle    <= 4'd3;
                        end
                        4'd3: begin
                            {page_crossed, ind_y_lo} <= {1'b0, effective_addr[7:0]} + {1'b0, Y};
                            effective_addr[15:8] <= data_in;  // pointer high
                            addr_reg <= {data_in, effective_addr[7:0] + Y};
                            rw_reg   <= 1'b1;
                            cycle    <= 4'd4;   
                        end
                        4'd4: begin
                            if (page_crossed) begin
                                if (opcode == STA) begin
                                effective_addr[15:8] <= effective_addr[15:8] + 8'd1;
                                addr_reg <= {effective_addr[15:8] + 8'd1, ind_y_lo};
                                rw_reg   <= 1'b0;
                                data_out_reg <= A;
                                cycle    <= 4'd5;
                                end else begin
                                effective_addr[15:8] <= effective_addr[15:8] + 8'd1;
                                addr_reg <= {effective_addr[15:8] + 8'd1, ind_y_lo};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd5;
                                end
                            end else begin
                                if (opcode == STA) begin
                                    addr_reg     <= {effective_addr[15:8], ind_y_lo};
                                    rw_reg       <= 1'b0;
                                    data_out_reg <= A;
                                    cycle        <= 4'd5;
                                end else begin
                                    case (opcode)
                                        LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                        default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    endcase
                                end
                            end
                        end
                        4'd5: begin
                            if (opcode == STA) begin
                                addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH;
                            end else begin
                                case (opcode)
                                    LDA: begin A<=data_in; P<=update_nz(P,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ADC: begin A<=({1'b0,A}+{1'b0,data_in}+{8'b0,P[FLAG_C]}); P<=p_after_adc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    SBC: begin A<=({1'b0,A}-{1'b0,data_in}-{8'b0,~P[FLAG_C]}); P<=p_after_sbc(P,A,data_in,P[FLAG_C]); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    AND: begin A<=A&data_in; P<=update_nz(P,A&data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    ORA: begin A<=A|data_in; P<=update_nz(P,A|data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    EOR: begin A<=A^data_in; P<=update_nz(P,A^data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    CMP: begin P<=p_after_cmp(P,A,data_in); addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                    default: begin addr_reg<=PC; rw_reg<=1'b1; state<=STATE_FETCH; end
                                endcase
                            end
                        end
                    endcase
                end

                IND, ABS_IND: begin
                    case (cycle)
                        4'd1: begin
                            operand_lo <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= PC + 16'd1;
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd2;
                        end
                        4'd2: begin
                            operand_hi <= data_in;
                            PC         <= PC + 16'd1;
                            addr_reg   <= {data_in, operand_lo};
                            rw_reg     <= 1'b1;
                            cycle      <= 4'd3;
                        end
                        4'd3: begin
                            effective_addr[7:0] <= data_in;
                            addr_reg <= {operand_hi, operand_lo + 8'd1};
                            rw_reg   <= 1'b1;
                            cycle    <= 4'd4;
                        end
                        4'd4: begin
                            PC       <= {data_in, effective_addr[7:0]};
                            addr_reg <= {data_in, effective_addr[7:0]};
                            rw_reg   <= 1'b1;
                            state    <= STATE_FETCH;
                        end
                    endcase
                end

                REL: begin
                    operand_lo <= data_in;
                    PC         <= PC + 16'd1;
                    addr_reg   <= PC + 16'd1;
                    rw_reg     <= 1'b1;
                    temp_addr  <= (PC + 16'd1) + {{8{data_in[7]}}, data_in};
                    if (branch_cond) begin
                        state    <= STATE_REL_1;
                    end else begin
                        state    <= STATE_FETCH;
                        end
                    end

                default: begin
                    addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                end
                endcase   
            end   

            STATE_EXECUTE: begin
                case (opcode)                   
                    PHA: begin
                        addr_reg <= PC;
                        rw_reg   <= 1'b1;
                        state    <= STATE_FETCH;
                    end

                    PHP: begin
                        addr_reg <= PC;
                        rw_reg   <= 1'b1;
                        state    <= STATE_FETCH;
                    end

                    PLA: begin
                        case (cycle)
                            4'd2: begin
                                SP       <= SP + 8'd1;
                                addr_reg <= {8'h01, SP + 8'd1};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd3;
                            end
                            4'd3: begin
                                A        <= data_in;
                                P        <= update_nz(P, data_in);
                                addr_reg <= PC;
                                rw_reg   <= 1'b1;
                                state    <= STATE_FETCH;
                            end
                        endcase
                    end

                    // PLP - 4 cycles
                    PLP: begin
                        case (cycle)
                            4'd2: begin
                                SP       <= SP + 8'd1;
                                addr_reg <= {8'h01, SP + 8'd1};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd3;
                            end
                            4'd3: begin
                                P        <= (data_in & 8'hCF) | 8'b00100000;
                                addr_reg <= PC;
                                rw_reg   <= 1'b1;
                                state    <= STATE_FETCH;
                            end
                        endcase
                    end

                     
                    RTS: begin
                        case (cycle)
                            4'd2: begin
                                SP       <= SP + 8'd1;
                                addr_reg <= {8'h01, SP + 8'd1};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd3;
                            end
                            4'd3: begin
                                operand_lo <= data_in;
                                SP         <= SP + 8'd1;
                                addr_reg   <= {8'h01, SP + 8'd1};
                                rw_reg     <= 1'b1;
                                cycle      <= 4'd4;
                            end
                            4'd4: begin
                                // PC = {PCH, PCL} + 1  (RTI does NOT add 1)
                                PC       <= {data_in, operand_lo} + 16'd1;
                                addr_reg <= {data_in, operand_lo};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd5;
                            end
                            4'd5: begin
                                addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                            end
                        endcase
                    end

                    RTI: begin
                        case (cycle)
                            4'd2: begin
                                SP       <= SP + 8'd1;
                                addr_reg <= {8'h01, SP + 8'd1};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd3;
                            end
                            4'd3: begin
                                P    <= (data_in & 8'hCF) | 8'b00100000;
                                SP   <= SP + 8'd1;
                                addr_reg <= {8'h01, SP + 8'd1};
                                rw_reg   <= 1'b1;
                                cycle    <= 4'd4;
                            end
                            4'd4: begin
                                operand_lo <= data_in;
                                SP         <= SP + 8'd1;
                                addr_reg   <= {8'h01, SP + 8'd1};
                                rw_reg     <= 1'b1;
                                cycle      <= 4'd5;
                            end
                            4'd5: begin
                                PC       <= {data_in, operand_lo};
                                addr_reg <= {data_in, operand_lo};
                                rw_reg   <= 1'b1;
                                state    <= STATE_FETCH;
                            end
                        endcase
                    end

                    default: begin
                        addr_reg <= PC; rw_reg <= 1'b1; state <= STATE_FETCH;
                    end
                endcase
            end  

            STATE_INT_1: begin // Push PCH
                addr_reg     <= {8'h01, SP};
                rw_reg       <= 1'b0;
                data_out_reg <= PC[15:8];
                SP           <= SP - 8'd1;
                state        <= STATE_INT_2;
            end

            STATE_INT_2: begin // Push PCL
                addr_reg     <= {8'h01, SP};
                rw_reg       <= 1'b0;
                data_out_reg <= PC[7:0];
                SP           <= SP - 8'd1;
                state        <= STATE_INT_3;
            end

            STATE_INT_3: begin // Push P with B-flag
                addr_reg     <= {8'h01, SP};
                rw_reg       <= 1'b0;
                data_out_reg <= serving_brk ? (P | 8'b00110000) : (P | 8'b00100000); // BRK: B=1, U=1 ,NMI/IRQ: B=0, U=1
                SP           <= SP - 8'd1;
                P[FLAG_I]    <= 1'b1;
                state        <= STATE_INT_4;    
            end

            STATE_INT_4: begin 
                addr_reg <= serving_nmi ? 16'hFFFA : 16'hFFFE;
                rw_reg   <= 1'b1;
                state    <= STATE_INT_5;
            end

            STATE_INT_5: begin 
                operand_lo  <= data_in;
                addr_reg    <= serving_nmi ? 16'hFFFB : 16'hFFFF;
                rw_reg      <= 1'b1;
                state       <= STATE_INT_6;
            end

            STATE_INT_6: begin 
                PC          <= {data_in, operand_lo};
                addr_reg    <= {data_in, operand_lo};
                rw_reg      <= 1'b1;
                serving_nmi <= 1'b0;
                serving_brk <= 1'b0;
                state       <= STATE_FETCH;
            end


            STATE_REL_1: begin
                branch_target <= PC + {{8{operand_lo[7]}}, operand_lo};
                if (PC[15:8] != temp_addr[15:8]) begin
                    state <= STATE_REL_2;
                end else begin
                    PC       <= PC + {{8{operand_lo[7]}}, operand_lo};
                    addr_reg <= PC + {{8{operand_lo[7]}}, operand_lo};
                    rw_reg   <= 1'b1;
                    state    <= STATE_FETCH;
                end
            end
            
            
            STATE_REL_2: begin
                PC       <= branch_target;
                addr_reg <= branch_target;
                rw_reg   <= 1'b1;
                state    <= STATE_FETCH;
            end

            default: begin
                state <= STATE_FETCH;
            end

            endcase   
        end   
    end   

endmodule
