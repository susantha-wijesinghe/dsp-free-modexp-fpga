`timescale 1ns / 1ps

// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 

module clock_divider (
    input wire clk_in,   // Input clock signal
    input wire reset,    // Reset signal
    output reg clk_out   // Output clock signal (half frequency)
);

    // Clock divider process
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            clk_out <= 1'b0; // Reset the output clock
        end else begin
            clk_out <= ~clk_out; // Toggle the output clock
        end
    end

endmodule
