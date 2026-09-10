// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 


module my_sarme4 #(parameter N=32)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [N-1:0] base,
    input wire [N-1:0] exponent,
    input wire [N-1:0] modulus,
    output reg [N-1:0] result_out,
    output reg done 
);

// State parameters
localparam [4:0] IDLE = 0,
                 MOD_CAL1 = 1,
                 MOD_CAL1_WAIT = 2,
                 WHILE_1 = 3,
                 MOD_CAL2 = 4,
                 MOD_CAL2_WAIT = 5,
                 WHILE_2 = 6,
                 PREP1 = 7, 
                 SQUARE = 8,
                 MOD_CAL3 = 9,
                 MOD_CAL3_WAIT = 10,
                 PREP2 = 11,
                 PREP3 = 12,
                 MOD_CAL4 = 13,
                 MOD_CAL4_WAIT = 14,
                 WHILE_3 = 15,
                 PREP4 = 16,
                 MOD_CAL5 = 17,
                 MOD_CAL5_WAIT = 18,
                 PREP5 = 19,
                 PREP6 = 20,
                 MOD_CAL6 = 21,
                 MOD_CAL6_WAIT = 22,
                 FINISH = 23,
                 DONE = 24;

// Registers
reg [4:0] state, next_state;
reg [N-1:0] base_reg, next_base;
reg [N-1:0] exponent_reg, next_exponent;
reg [N-1:0] modulus_reg, next_modulus;
reg [N-1:0] result_reg, next_result;
//reg [N-1:0] temp_reg, next_temp;
//reg [N-1:0] a_reg, next_a;
// AFTER
reg [N:0] temp_reg, next_temp;
reg [N:0] a_reg, next_a;

reg [N-1:0] b_reg, next_b;
//reg [N-1:0] mod_A, next_mod_A;
//reg [N-1:0] mod_B, next_mod_B;
// AFTER
reg [N:0] mod_A, next_mod_A;
reg [N:0] mod_B, next_mod_B;

reg mod_start, next_mod_start;
reg next_done;

// Wires
//wire [N-1:0] mod_result;
wire [N:0] mod_result;

wire mod_done;

// Modulus instance
modulus #(.N(N+1)) modulus_inst(
    .clk(clk),
    .reset(rst),
    .start(mod_start),
    .A(mod_A),
    .B(mod_B),
    .result(mod_result),
    .done(mod_done)
);

// Sequential logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        base_reg <= 0;
        exponent_reg <= 0;
        modulus_reg <= 0;
        a_reg <= 0;
        b_reg <= 0;
        result_reg <= 0;
        temp_reg <= 0;
        mod_A <= 0;
        mod_B <= 0;
        mod_start <= 0;
        done <= 0;
        result_out <= 0;
    end else begin
        state <= next_state;
        base_reg <= next_base;
        exponent_reg <= next_exponent;
        modulus_reg <= next_modulus;
        a_reg <= next_a;
        b_reg <= next_b;
        result_reg <= next_result;
        temp_reg <= next_temp;
        mod_A <= next_mod_A;
        mod_B <= next_mod_B;
        mod_start <= next_mod_start;
        done <= next_done;
        result_out <= (state == FINISH) ? result_reg : result_out;
    end
end

// Combinational logic
always @(*) begin
    // Default values
    next_state = state;
    next_base = base_reg;
    next_exponent = exponent_reg;
    next_modulus = modulus_reg;
    next_a = a_reg;
    next_b = b_reg;
    next_result = result_reg;
    next_temp = temp_reg;
    next_mod_A = mod_A;
    next_mod_B = mod_B;
    next_mod_start = 1'b0;
    next_done = 1'b0;

    case(state)
        IDLE: begin
            if (start) begin
                //next_result = 1;
                next_result = (modulus == 1) ? 0 : 1;
                next_base = base;
                next_exponent = exponent;
                next_modulus = modulus;
                next_mod_A = base;
                next_mod_B = modulus;
                next_state = MOD_CAL1;
            end
        end

        MOD_CAL1: begin
            next_mod_start = 1'b1;
            next_state = MOD_CAL1_WAIT;
        end

        MOD_CAL1_WAIT: begin
            if (mod_done) begin
                next_base = mod_result;
                next_state = WHILE_1;
            end
        end

        WHILE_1: begin
            if (exponent_reg > 0) begin
                if (exponent_reg[0]) begin
                    next_mod_A = result_reg;
                    next_mod_B = modulus_reg;
                    next_temp = 0;
                    next_state = MOD_CAL2;
                end else begin
                    next_state = SQUARE;
                end
            end else begin
                next_state = FINISH;
            end
        end

        MOD_CAL2: begin
            next_mod_start = 1'b1;
            next_state = MOD_CAL2_WAIT;
        end

        MOD_CAL2_WAIT: begin
            if (mod_done) begin
                next_a = mod_result;
                next_b = base_reg;
                next_state = WHILE_2;
            end
        end

        WHILE_2: begin
            if (b_reg > 0) begin
                if (b_reg[0]) begin
                    next_temp = temp_reg + a_reg;
                    next_state = PREP1;
                end else begin
                    next_state = PREP2;
                end
            end else begin
                next_result = temp_reg;
                next_state = SQUARE;
            end
        end

        PREP1: begin
            next_mod_A = temp_reg;
            next_mod_B = modulus_reg;
            next_state = MOD_CAL3;
        end

        MOD_CAL3: begin
            next_mod_start = 1'b1;
            next_state = MOD_CAL3_WAIT;
        end

        MOD_CAL3_WAIT: begin
            if (mod_done) begin
                next_temp = mod_result;
                next_state = PREP2;
            end
        end

        PREP2: begin
            next_a = {a_reg[N-1:0], 1'b0}; // Left shift by 1
            next_b = {1'b0, b_reg[N-1:1]}; // Right shift by 1
            next_state = PREP3;
        end

        PREP3: begin
            next_mod_A = next_a;
            next_mod_B = modulus_reg;
            next_state = MOD_CAL4;
        end

        MOD_CAL4: begin
            next_mod_start = 1'b1;
            next_state = MOD_CAL4_WAIT;
        end

        MOD_CAL4_WAIT: begin
            if (mod_done) begin
                next_a = mod_result;
                next_state = WHILE_2;
            end
        end

        SQUARE: begin
            next_temp = 0;
            next_a = base_reg;
            next_b = base_reg;
            next_state = WHILE_3;
        end

        WHILE_3: begin
            if (b_reg > 0) begin
                if (b_reg[0]) begin
                    next_temp = temp_reg + a_reg;
                    next_state = PREP4;
                end else begin
                    next_state = PREP5;
                end
            end else begin
                next_base = temp_reg;
                next_exponent = {1'b0, exponent_reg[N-1:1]}; // Right shift by 1
                next_state = WHILE_1;
            end
        end

        PREP4: begin
            next_mod_A = temp_reg;
            next_mod_B = modulus_reg;
            next_state = MOD_CAL5;
        end

        MOD_CAL5: begin
            next_mod_start = 1'b1;
            next_state = MOD_CAL5_WAIT;
        end

        MOD_CAL5_WAIT: begin
            if (mod_done) begin
                next_temp = mod_result;
                next_state = PREP5;
            end
        end

        PREP5: begin
            next_a = {a_reg[N-1:0], 1'b0}; // Left shift by 1
            next_b = {1'b0, b_reg[N-1:1]}; // Right shift by 1
            next_state = PREP6;
        end

        PREP6: begin
            next_mod_A = next_a;
            next_mod_B = modulus_reg;
            next_state = MOD_CAL6;
        end

        MOD_CAL6: begin
            next_mod_start = 1'b1;
            next_state = MOD_CAL6_WAIT;
        end

        MOD_CAL6_WAIT: begin
            if (mod_done) begin
                next_a = mod_result;
                next_state = WHILE_3;
            end
        end

        FINISH: begin
            next_state = DONE;
        end

        DONE: begin
            next_done = 1'b1;
            next_state = IDLE;
        end 

        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule