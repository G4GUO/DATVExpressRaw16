/////////////////////////////////////////////////////////////////////////////////////////////
//
// DAC routine
// clk = 4X sample rate 
// clkd delayed clock
// state 2 bit counter
// i_data,q_data input data
// dav data available
// dac_d dac data
// daciqwrt,daciqclk,daciqreset,daciqsel dac control lines
// 
/////////////////////////////////////////////////////////////////////////////////////////////

module dac_w( input clk, input clkd, input [1:0]state, input dav,
              input [15:0]i_data,   input [15:0]q_data, input calibrate,
				  input [15:0]i_dc_cal, input [15:0]q_dc_cal,  
              output [13:0]dac_d, output daciqwrt, output daciqclk, output daciqreset, output daciqsel ); 
reg iqclk_r;
reg iqwrt_r;
reg [15:0]idata_r[2];
reg [15:0]qdata_r[2];

always @(posedge clk )
begin
   // When state = 00 sample is valid, so save it
   if(state[1:0] == 0)
	begin
		// Data needs to be converted to differential format
      idata_r[0] <= calibrate ? i_dc_cal : i_data + i_dc_cal;
      qdata_r[0] <= calibrate ? q_dc_cal : q_data + q_dc_cal;
      idata_r[1] <= idata_r[0];
      qdata_r[1] <= qdata_r[0];
	end
end

always @(negedge clk)  iqclk_r  <= !state[0];
always @(negedge clkd) iqwrt_r  <= !state[0];
//always @(posedge state[1]) rst_r <= dav;

assign daciqclk = iqclk_r;
assign daciqwrt = iqwrt_r;// delayed version of IQCLK
assign daciqsel = state[1];

// Select data to output to DAC
assign dac_d  = state[1] ? idata_r[1][15:2] : qdata_r[1][15:2];

assign daciqreset = 1'b0;   // keep it out of reset

endmodule
