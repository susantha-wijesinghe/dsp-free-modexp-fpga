`timescale 1ns / 1ps
// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 
module uart_rx #(
    parameter CLK_FREQ   = 50_000_000, // System Clock Frequency in Hz
    parameter BAUD_RATE  = 9600         // Desired Baud Rate in bps
)(
    input clk,          // System Clock
    input reset,        // Asynchronous Reset
    input rx,           // UART Receive Line
    output reg [7:0] data,   // Received Byte
    output reg ready    // Data Ready Signal
);

    // Calculate the number of clock cycles per baud
    localparam integer CLK_PER_BAUD = CLK_FREQ / BAUD_RATE;

    // State Machine States
    typedef enum reg [2:0] {
        IDLE,          // Waiting for Start Bit
        START,         // Confirming Start Bit
        DATA,          // Receiving Data Bits
        STOP           // Receiving Stop Bit
    } state_t;

    state_t state = IDLE;

    // Counter to track baud timing
    reg [$clog2(CLK_PER_BAUD)-1:0] baud_cnt = 0;

    // Bit index (0 to 7)
    reg [2:0] bit_cnt = 0;

    // Shift Register to assemble received bits
    reg [7:0] shift_reg = 0;

    // Sampling the middle of the bit period
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            baud_cnt  <= 0;
            bit_cnt   <= 0;
            shift_reg <= 0;
            ready     <= 0;
            data      <= 0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 0;
                    if (rx == 0) begin // Detect Start Bit (logic low)
                        state    <= START;
                        baud_cnt <= 0;
                    end
                end

                START: begin
                    if (baud_cnt < (CLK_PER_BAUD/2 - 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        // Sample the Start Bit in the middle
                        if (rx == 0) begin
                            state    <= DATA;
                            baud_cnt <= 0;
                            bit_cnt  <= 0;
                        end else begin
                            // False Start Bit detected, return to IDLE
                            state    <= IDLE;
                            baud_cnt <= 0;
                        end
                    end
                end

                DATA: begin
                    if (baud_cnt < (CLK_PER_BAUD - 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        // Sample Data Bit
                        shift_reg[bit_cnt] <= rx;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (baud_cnt < (CLK_PER_BAUD - 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        // Sample Stop Bit
                        if (rx == 1) begin
                            data  <= shift_reg;
                            ready <= 1;
                        end
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
