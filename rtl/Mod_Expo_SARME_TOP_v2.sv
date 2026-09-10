`timescale 1ns / 1ps

// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 

module Mod_Expo_SARME_TOP_v2 (
    input clk100MHz,
    input reset,
    input rx,   // UART receive line
    output tx,   // UART transmit line
    output[15:0] led
);

    parameter N = 64; // Bit width of operands
    parameter M_BYTE = N/8;  // Number of bytes per operand
    parameter CNT_WIDTH = 64; // for Cycles
    parameter CNT_BYTE = CNT_WIDTH/8; 
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD_RATE = 115200;
    
    reg [N-1:0] A_reg, B_reg, C_reg;
    wire [N-1:0] result;
    wire [CNT_WIDTH-1:0] cycles;
    wire mod_expo_done;
    
    reg mod_expo_start;
    
    // Clock divider
    wire clk;
    clock_divider clk_inst(
        .clk_in(clk100MHz),
        .reset(reset),
        .clk_out(clk)
    );
    
    // UART Receiver Instance
    wire rx_ready;
    wire [7:0] rx_data;
    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data(rx_data),
        .ready(rx_ready)
    );


    // UART Transmitter Instance
    wire tx_busy;
    reg tx_start;
    reg [7:0] tx_data_reg; // Renamed to avoid confusion with rx_data
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk),
        .reset(reset),
        .data(tx_data_reg),
        .start(tx_start),
        .tx(tx),
        .busy(tx_busy)
    );

    // my_sarme_top Instance
    my_sarme_top #(.N(N), .CNT_WIDTH(CNT_WIDTH)) my_sarme_top_0(
        .clk     (clk),
        .reset   (reset),
        .start   (mod_expo_start),
        .base    (A_reg),
        .exponent(B_reg),
        .modulus (C_reg),
        .result  (result),
        .cycles(cycles),
        .done    (mod_expo_done)
    );

    // State Machine States
    typedef enum reg [4:0] {
        IDLE           = 5'd0,
        RECEIVE_A      = 5'd1,
        RECEIVE_B      = 5'd2,
        RECEIVE_C      = 5'd3,
        SEND_C         = 5'd4,
        SEND_C_WAIT    = 5'd5,
        SEND_B         = 5'd6,
        SEND_B_WAIT    = 5'd7,
        SEND_A         = 5'd8,
        SEND_A_WAIT    = 5'd9,
        COMPUTE        = 5'd10,
        COMPUTE_END    = 5'd11,
        SEND_RESULT    = 5'd12,
        SEND_RESULT_WAIT = 5'd13,
        SEND_CYCLES     = 5'd14,
        SEND_CYCLES_WAIT = 5'd15
    } state_t;

    reg [4:0] state;



    // Byte Counters
    localparam BYTE_COUNT_WIDTH = (M_BYTE >= CNT_BYTE) ? $clog2(M_BYTE) : $clog2(CNT_BYTE);
    reg [BYTE_COUNT_WIDTH:0] byte_count;
    //reg [BYTE_COUNT_WIDTH-1:0] send_byte_count;


    // Edge detection
    reg mod_expo_done_prev;
    wire mod_expo_done_posedge;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mod_expo_done_prev <= 0;
        end else begin
            mod_expo_done_prev <= mod_expo_done;
        end
    end
    
    assign mod_expo_done_posedge = mod_expo_done && !mod_expo_done_prev;


    // State Transition and Data Handling
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers and state
            state           <= IDLE;
            A_reg           <= 0;
            B_reg           <= 0;
            C_reg           <= 0;
            byte_count      <= 0;
            tx_start        <= 0;
            tx_data_reg     <= 8'd0;
            mod_expo_start  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_start <= 0; // Ensure tx_start is low
                    if (rx_ready) begin
                        // Start receiving Operand A
                        A_reg           <= {A_reg[N-9:0], rx_data}; // Corrected line
                        byte_count      <= 1;
                        state           <= RECEIVE_A;
                    end
                end

                RECEIVE_A: begin
                    tx_start <= 0;
                    if (rx_ready) begin
                        A_reg <= {A_reg[N-9:0], rx_data}; // Corrected line
                        if (byte_count == M_BYTE-1) begin
                            // Finished receiving Operand A
                            byte_count <= 0;
                            state           <= RECEIVE_B;
                        end else begin
                            byte_count <= byte_count + 1;
                        end
                    end
                end

                RECEIVE_B: begin
                    tx_start <= 0;
                    if (rx_ready) begin
                        B_reg <= {B_reg[N-9:0], rx_data}; // Corrected line
                        if (byte_count == M_BYTE-1) begin
                            // Finished receiving Operand B
                            byte_count <= 0;
                            state           <= RECEIVE_C;
                        end else begin
                            byte_count <= byte_count + 1;
                        end
                    end
                end

                RECEIVE_C: begin
                    tx_start <= 0;
                    if (rx_ready) begin
                        C_reg <= {C_reg[N-9:0], rx_data}; // Corrected line
                        if (byte_count == M_BYTE-1) begin
                            // Finished receiving Operand C, start sending C
                            byte_count <= 0;
                            state           <= COMPUTE;
                        end else begin
                            byte_count <= byte_count + 1;
                        end
                    end
                end

                COMPUTE: begin
                    mod_expo_start <= 1'b1;
                    state <= COMPUTE_END;
                end

                COMPUTE_END: begin
                    mod_expo_start <= 1'b0;
                    if(mod_expo_done_posedge) begin
                        byte_count <= 0;
                        state <= SEND_C;
                    end 
                end

                SEND_C: begin
                    if (!tx_busy && byte_count < M_BYTE) begin
                        // Load byte from Operand C for transmission
                        tx_data_reg <= C_reg[(M_BYTE - 1 - byte_count)*8 +: 8];
                        tx_start    <= 1; // Trigger UART transmission
                        state       <= SEND_C_WAIT;
                    end else begin
                        tx_start <= 0;
                    end
                end

                SEND_C_WAIT: begin
                    tx_start <= 0; // Release tx_start
                    if (!tx_busy) begin
                        if (byte_count < M_BYTE-1) begin
                            // Send next byte of Operand C
                            byte_count <= byte_count + 1;
                            state           <= SEND_C;
                        end else begin
                            // Finished sending Operand C, start sending B
                            byte_count <= 0;
                            state           <= SEND_B;
                        end
                    end else begin
                        state <= SEND_C_WAIT; // Wait until transmission is complete
                    end
                end

                SEND_B: begin
                    if (!tx_busy && byte_count < M_BYTE) begin
                        // Load byte from Operand B for transmission
                        tx_data_reg <= B_reg[(M_BYTE - 1 - byte_count)*8 +: 8];
                        tx_start    <= 1; // Trigger UART transmission
                        state       <= SEND_B_WAIT;
                    end else begin
                        tx_start <= 0;
                    end
                end

                SEND_B_WAIT: begin
                    tx_start <= 0; // Release tx_start
                    if (!tx_busy) begin
                        if (byte_count < M_BYTE-1) begin
                            // Send next byte of Operand B
                            byte_count <= byte_count + 1;
                            state           <= SEND_B;
                        end else begin
                            // Finished sending Operand B, start sending A
                            byte_count <= 0;
                            state           <= SEND_A;
                        end
                    end else begin
                        state <= SEND_B_WAIT; // Wait until transmission is complete
                    end
                end

                SEND_A: begin
                    if (!tx_busy && byte_count < M_BYTE) begin
                        // Load byte from Operand A for transmission
                        tx_data_reg <= A_reg[(M_BYTE - 1 - byte_count)*8 +: 8];
                        tx_start    <= 1; // Trigger UART transmission
                        state       <= SEND_A_WAIT;
                    end else begin
                        tx_start <= 0;
                    end
                end

                SEND_A_WAIT: begin
                    tx_start <= 0; // Release tx_start
                    if (!tx_busy) begin
                        if (byte_count < M_BYTE-1) begin
                            // Send next byte of Operand A
                            byte_count <= byte_count + 1;
                            state           <= SEND_A;
                        end else begin
                            // Finished sending all operands, return to IDLE
                            byte_count <= 0;
                            state           <= SEND_RESULT;
                        end
                    end else begin
                        state <= SEND_A_WAIT; // Wait until transmission is complete
                    end
                end

                SEND_RESULT: begin
                    if (!tx_busy && byte_count < M_BYTE) begin
                        // Load byte from result for transmission
                        tx_data_reg <= result[(M_BYTE - 1 - byte_count)*8 +: 8];
                        tx_start    <= 1; // Trigger UART transmission
                        state       <= SEND_RESULT_WAIT;
                    end else begin
                        tx_start <= 0;
                    end
                end

                SEND_RESULT_WAIT: begin
                    tx_start <= 0; // Release tx_start
                    if (!tx_busy) begin
                        if (byte_count < M_BYTE-1) begin
                            // Send next byte of result
                            byte_count <= byte_count + 1;
                            state           <= SEND_RESULT;
                        end else begin
                            byte_count <= 0;
                            state           <= SEND_CYCLES;
                        end
                    end else begin
                        state <= SEND_RESULT_WAIT; // Wait until transmission is complete
                    end
                end

                SEND_CYCLES: begin
                    if (!tx_busy && byte_count < CNT_BYTE) begin
                        // Load byte from cycles for transmission
                        tx_data_reg <= cycles[(CNT_BYTE - 1 - byte_count)*8 +: 8];
                        tx_start    <= 1; // Trigger UART transmission
                        state       <= SEND_CYCLES_WAIT;
                    end else begin
                        tx_start <= 0;
                    end
                end 

                SEND_CYCLES_WAIT: begin
                    tx_start <= 0; // Release tx_start
                    if (!tx_busy) begin
                        if (byte_count < CNT_BYTE-1) begin
                            // Send next byte of cycles
                            byte_count <= byte_count + 1;
                            state           <= SEND_CYCLES;
                        end else begin
                            // Finished sending all operands, return to IDLE
                            byte_count <= 0;
                            state           <= IDLE;
                        end
                    end else begin
                        state <= SEND_CYCLES_WAIT; // Wait until transmission is complete
                    end
                end 

                default: begin
                    // Default to IDLE state on undefined states
                    state    <= IDLE;
                    tx_start <= 0;
                end
            endcase
        end
    end
    //assign led = {11'b00000000000, state};
    assign led = result[15:0];
endmodule
