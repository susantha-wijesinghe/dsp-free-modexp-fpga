`timescale 1ns / 1ps
// =============================================================================
// Dr. W.A. Susantha Wijesinghe
// susantha@wyb.ac.lk
// Department of Electronics
// Faculty of Applied Sciences
// Wayamba University of Sri Lanka
// Date: 10 September 2026
// =============================================================================
 
module my_sarme_top#(parameter N=512, CNT_WIDTH=64)(
	input clk, reset, start,
	input[N-1:0] base, exponent, modulus,
	output[N-1:0] result,
	output[CNT_WIDTH-1:0] cycles,
	output done
	);

my_sarme4 #(.N(N)) my_sarme_0(
	.clk(clk),
	.rst(reset),
	.start(start),
	.base(base),
	.exponent(exponent),
	.modulus(modulus),
	.result_out(result),
	.done(done)
	);

cycle_counter #(.CNT_WIDTH(CNT_WIDTH)) cycle_cnt0(
	.clk      (clk),
	.reset    (reset),
	.start_cnt(start),
	.done_cnt (done),
	.cycles   (cycles)
);

endmodule
