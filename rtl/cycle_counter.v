
// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 

module cycle_counter #(parameter CNT_WIDTH=32)(
	input clk, reset, start_cnt, done_cnt,
	output reg[CNT_WIDTH-1:0] cycles
	);
	
	localparam [0:0] S0 = 0,
					 S1 = 1;
	reg[0:0] state, state_next;
	
	reg[CNT_WIDTH-1:0] counter_reg, counter_next;

	always@(posedge clk) begin
		if(reset) begin
			state <= S0;
			counter_reg <= 0;
		end
		else begin
			state <= state_next;
			counter_reg <= counter_next;
		end
	end

	always@(*) begin
		state_next = state;
		counter_next = counter_reg;
		case(state)
			S0: begin
				if(start_cnt==1) begin
					counter_next = 0;
					state_next = S1;
				end
			end 
			S1: begin
				if(done_cnt==1) begin
					cycles = counter_reg;
					state_next = S0;
				end
				else begin
					counter_next = counter_reg + 1'b1;
				end
			end 
			default: state_next = S0;
		endcase 
	end
endmodule 
