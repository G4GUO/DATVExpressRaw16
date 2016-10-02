//
// Symbol rate generator
//
// The input clock is at 400 MHz
//
// PH is the phase offset
module srgensub #(parameter PH = 0)( input clkin, input [63:0]phase_inc, input en, output clkout );

reg [63:0]counter = PH;

always @(posedge clkin ) 
begin
   if(en) counter <= counter + phase_inc;
end

assign clkout  = counter[63];

endmodule

//
// Generate sample clock 
// 
module srgen( input clkin, input [63:0]phase_inc, input si570clk, input si570av, output clkout, output clkoutd );

srgensub #(64'h0000000000000000) sub0( .clkin(clkin), .phase_inc(phase_inc), .en(!si570av), .clkout(clk_0_w));
//srgensub #(64'h4000000000000000) sub90(.clkin(clkin), .phase_inc(phase_inc), .clkout(clk_90_w));

wire clk_0_w, clk_90_w;

reg d_r[2];

always @(posedge clkin ) 
begin
	d_r[1] <= clk_0_w;
	d_r[0] <= d_r[1];
end

assign clkout  = si570av ? si570clk : d_r[1];
assign clkoutd = si570av ? si570clk : d_r[0];

endmodule
