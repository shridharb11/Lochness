module Interrupt_Control(
    input MCLR,
    input clk,

    // IRQ
    input IRQ_INHIBIT,
    input IRQ_LINE,
    input IRQ_CLEAR,

    // NMI
    input NMI_LINE,
    input NMI_CLEAR,

    // Reset
    input RESET_CLEAR,

    // Outputs
    output reg  IRQ,
    output reg  NMI,
    output reg  RESET_INT
);

    reg NMI_A, NMI_B;  // two-stage pipeline for edge detection

    // NMI: falling edge triggered (active low)
    always @(posedge clk) begin
        if (MCLR) begin
            NMI_A <= 1'b1;
            NMI_B <= 1'b1;
            NMI   <= 1'b0;
        end else begin
            // shift the pipeline
            NMI_B <= NMI_A;
            NMI_A <= NMI_LINE;

            // falling edge: NMI_A was high last cycle, now low
            if (~NMI_A && NMI_B)
                NMI <= 1'b1;
            else if (NMI_CLEAR)
                NMI <= 1'b0;
            else 
                NMI <= NMI;
        end
    end

    //IRQ: level triggered, maskable 
    always @(posedge clk) begin
        if (MCLR)
            IRQ <= 1'b0;
        else if (IRQ_CLEAR)             // clear takes priority
            IRQ <= 1'b0;
        else if (~IRQ_LINE && ~IRQ_INHIBIT)
            IRQ <= 1'b1;
        // else hold
    end

    //RESET: asserts on MCLR, held until CPU clears
    always @(posedge clk) begin
        if (MCLR)
            RESET_INT <= 1'b1;
        else if (RESET_CLEAR)
            RESET_INT <= 1'b0;
        else 
            RESET_INT <= RESET_INT;
    end

endmodule
