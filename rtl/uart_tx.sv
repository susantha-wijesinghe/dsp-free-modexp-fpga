`timescale 1ns / 1ps
// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 
module uart_tx #(
    parameter CLK_FREQ   = 50_000_000, // System Clock Frequency in Hz
    parameter BAUD_RATE  = 9600         // Desired Baud Rate in bps
)(
    input clk,            // System Clock
    input reset,          // Asynchronous Reset
    input [7:0] data,     // Data Byte to Transmit
    input start,          // Start Transmission Signal
    output reg tx,        // UART Transmit Line
    output reg busy       // Transmitter Busy Flag
);

    // Calculate the number of clock cycles per baud
    localparam integer CLK_PER_BAUD = CLK_FREQ / BAUD_RATE;

    // State Machine States
    typedef enum reg [3:0] {
        IDLE_TX,         // Idle State
        START_BIT,       // Transmitting Start Bit
        DATA_BITS,       // Transmitting Data Bits
        STOP_BIT,        // Transmitting Stop Bit
        CLEANUP          // Finalizing Transmission
    } state_t;

    state_t state = IDLE_TX;

    // Counter to track baud timing
    reg [$clog2(CLK_PER_BAUD)-1:0] baud_cnt = 0;

    // Bit index (0 to 7)
    reg [2:0] bit_cnt = 0;

    // Shift Register for Transmission
    reg [7:0] shift_reg = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE_TX;
            baud_cnt <= 0;
            bit_cnt  <= 0;
            tx       <= 1; // Idle state of UART TX line is high
            busy     <= 0;
            shift_reg <= 0;
        end else begin
            case (state)
                IDLE_TX: begin
                    tx   <= 1; // Ensure TX line is high when idle
                    busy <= 0;
                    if (start) begin
                        state     <= START_BIT;
                        shift_reg <= data; // Load data into shift register
                        baud_cnt  <= 0;
                        busy      <= 1;
                    end
                end

                START_BIT: begin
                    tx <= 0; // Start bit is low
                    if (baud_cnt < (CLK_PER_BAUD - 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        state     <= DATA_BITS;
                        bit_cnt  <= 0;
                    end
                end

                DATA_BITS: begin
                    tx <= shift_reg[bit_cnt]; // Transmit LSB first
                    if (baud_cnt < (CLK_PER_BAUD - 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    tx <= 1; // Stop bit is high
                    if (baud_cnt < (CLK_PER_BAUD - 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        state     <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    busy <= 0;
                    state <= IDLE_TX;
                end

                default: begin
                    state <= IDLE_TX;
                end
            endcase
        end
    end

endmodule
