
// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 


module modulus #(parameter N = 32) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [N-1:0] A,
    input wire [N-1:0] B,
    output reg [N-1:0] result,
    output reg done
);

parameter [2:0] IDLE = 0,
                ALIGN = 1,
                SUBTRACT = 2,
                FINISH = 3,
                DONE = 4;

reg [2:0] state_reg, state_next;
reg [N-1:0] dividend_reg, dividend_next;
reg [N-1:0] divisor_reg, divisor_next;
reg [$clog2(N):0] shift_reg, shift_next;
reg [$clog2(N):0] state_counter_reg, state_counter_next;
reg done_reg;

// State register
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state_reg <= IDLE;
        dividend_reg <= 0;
        divisor_reg <= 0;
        shift_reg <= 0;
        state_counter_reg <= 0;
    end else begin
        state_reg <= state_next;
        dividend_reg <= dividend_next;
        divisor_reg <= divisor_next;
        shift_reg <= shift_next;
        state_counter_reg <= state_counter_next;
    end
end

// Next-state logic
always @(*) begin
    // Default assignments
    state_next = state_reg;
    dividend_next = dividend_reg;
    divisor_next = divisor_reg;
    shift_next = shift_reg;
    done_reg = 1'b0;
    state_counter_next = state_counter_reg;

    case (state_reg)
        IDLE: begin
            //$display("Mod State=%d\n",state_reg);
            if (start) begin
                dividend_next = A;
                divisor_next = B;
                shift_next = 0;
                state_counter_next = 0;
                state_next = ALIGN;
            end
        end
        ALIGN: begin
            //$display("Mod State=%d\n",state_reg);
            if (divisor_reg <= dividend_reg && !divisor_reg[N-1] && state_counter_reg < N) begin
                divisor_next = divisor_reg << 1;
                shift_next = shift_reg + 1;
                state_counter_next = state_counter_reg + 1;
            end else begin
                state_next = SUBTRACT;
                state_counter_next = 0;
            end
        end
        SUBTRACT: begin
            //$display("Mod State=%d\n",state_reg);
            if (dividend_reg >= divisor_reg) begin
                dividend_next = dividend_reg - divisor_reg;
            end
            divisor_next = divisor_reg >> 1;
            shift_next = shift_reg - 1;
            state_counter_next = state_counter_reg + 1;
            if (dividend_reg < B || shift_reg == 0 || state_counter_reg >= N) begin
                state_next = FINISH;
            end
        end
        FINISH: begin
            //$display("Mod State=%d\n",state_reg);
            result = dividend_reg;
            state_next = DONE;
        end
        DONE: begin
            //$display("Mod State=%d\n",state_reg);
            done_reg = 1'b1;
            state_next = IDLE;
        end 
        default: begin
            state_next = IDLE;
        end 
    endcase
end
always@(posedge clk) begin
    if(reset)
        done <= 1'b0;
    else
        done <= done_reg;
end

endmodule
