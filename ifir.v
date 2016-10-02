/////////////////////////////////////////////////////
//
// Pipelined 4x or 8x interpolating FIR filter
//
// When Bit 1 of state is 0 we are processing I channel
// When Bit 1 of state is 1 we are processing Q channel
//
/////////////////////////////////////////////////////
module ifirold( input clk, input [5:0]state, input [15:0]i_in, input [15:0]q_in, 
              input [1:0]f_in, input [2:0]ir_in, input carrier,
              output signed [15:0]i_out, output signed [15:0]q_out );

`define FTAPS   12
`define FTAPS2  24
`define FTAPS8  96
`define FTAPSD  8'd12
`define FTAPS2D 8'd24
`define FTAPS3D 8'd36
`define FTAPS4D 8'd48
`define ITN4    8'd4
`define ITN8    8'd8

reg signed [15:0]sai[`FTAPS];//I Samples
reg signed [15:0]saq[`FTAPS];//Q Samples
reg signed [15:0]co[`FTAPS8];//Current Coefficients
reg signed [15:0]saw[`FTAPS];//Working Samples
reg signed [15:0]cow[`FTAPS];//Working Coefficients

// Memory for the various filters
reg signed [15:0]cdvbs35[`FTAPS8];//Coefficients
reg signed [15:0]cdvbs25[`FTAPS8];//Coefficients
reg signed [15:0]cdvbs20[`FTAPS8];//Coefficients
reg signed [15:0]cdvbt[`FTAPS8];//Coefficients
//
reg signed [31:0]ac[`FTAPS+3];//Accumulators
reg signed [15:0]out0_r[`FTAPS*2];

reg signed [15:0]i_out_r;
reg signed [15:0]q_out_r;
//
//
//
integer n;

initial
begin
    $readmemh("fx8dvbs_35.txt",cdvbs35);//0.35 rolloff
    $readmemh("fx8dvbs_25.txt",cdvbs25);//0.25 rolloff
    $readmemh("fx8dvbs_20.txt",cdvbs20);//0.20 rolloff
    $readmemh("fx8dvbt.txt",cdvbt);//DVB-T filter
end
//
// Sample in / out state machine
//
always @(posedge clk)
begin
   integer i;
	case(state)
		0: begin
	      // Update I and Q channel samples
			for( i = 0; i < (`FTAPS-1); i= i+1 )
			begin
	         sai[i] <= sai[i+1];
	         saq[i] <= saq[i+1];
			end
         sai[11]  <= carrier ? 16'h7FFF : i_in;
         saq[11]  <= carrier ? 16'h0000 : q_in;	
		end
		3: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[0];
	      q_out_r <= out0_r[1];
		end
		7: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[2];
	      q_out_r <= out0_r[3];
		end
		11: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[4];
	      q_out_r <= out0_r[5];
		end
		15: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[6];
	      q_out_r <= out0_r[7];
		end
		19: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[8];
	      q_out_r <= out0_r[9];
		end
		23: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[10];
	      q_out_r <= out0_r[11];
		end
		27: begin
	 		// Ouput new DAC values
	      i_out_r <= out0_r[12];
	      q_out_r <= out0_r[13];
		end
		31: begin
	  		// Ouput new DAC values
	      i_out_r <= out0_r[14];
	      q_out_r <= out0_r[15];
		end
	endcase
end
//
// Change the filter when needed
//
always @( f_in, ir_in  )
begin
	//
	// Load the coefficients for the current filter
	//
   integer i;
	if( ir_in == 2'd0 )
	begin
	   // x2 interpolating filter
	   case( f_in )
	      0 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
		         co[i]            <= cdvbs35[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*1)] <= cdvbs35[(i*(`ITN8)) + 0];
		      end
			end
	       1 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbs25[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*1)] <= cdvbs25[(i*(`ITN8)) + 0];
		      end
			end
	       2 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbs20[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*1)] <= cdvbs20[(i*(`ITN8)) + 0];
		      end
			end
	       3 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbt[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*1)] <= cdvbt[(i*(`ITN8)) + 0];
		      end
			end
	   endcase
		// Zero unused coefficients
		for( i = (`FTAPS*2); i < (`FTAPS*8); i = i+1 )
		begin
		   co[i]  <= 16'd0;
		end
	end
	else
	if( ir_in == 2'd1 )
	begin
	   // x4 interpolating filter
	   case( f_in )
	      0 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
		         co[i]            <= cdvbs35[(i*(`ITN8)) + 6];
			      co[i+(`FTAPS*1)] <= cdvbs35[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*2)] <= cdvbs35[(i*(`ITN8)) + 2];
			      co[i+(`FTAPS*3)] <= cdvbs35[(i*(`ITN8)) + 0];
		      end
			end
	      1 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbs25[(i*(`ITN8)) + 6];
			      co[i+(`FTAPS*1)] <= cdvbs25[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*2)] <= cdvbs25[(i*(`ITN8)) + 2];
			      co[i+(`FTAPS*3)] <= cdvbs25[(i*(`ITN8)) + 0];
		      end
			end
	      2 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbs20[(i*(`ITN8)) + 6];
			      co[i+(`FTAPS*1)] <= cdvbs20[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*2)] <= cdvbs20[(i*(`ITN8)) + 2];
			      co[i+(`FTAPS*3)] <= cdvbs20[(i*(`ITN8)) + 0];
		      end
			end
	      3 : begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbt[(i*(`ITN8)) + 6];
			      co[i+(`FTAPS*1)] <= cdvbt[(i*(`ITN8)) + 4];
			      co[i+(`FTAPS*2)] <= cdvbt[(i*(`ITN8)) + 2];
			      co[i+(`FTAPS*3)] <= cdvbt[(i*(`ITN8)) + 0];
		      end
			end
	    endcase
		 // Zero unused coefficients
		 for( i = (`FTAPS*4); i < (`FTAPS*8); i = i+1 )
		 begin
		   co[i]  <= 16'd0;
		 end
	end
	else 
	if( ir_in == 2'd2 )
	begin
	   // x8 interpolating filter
	   case(f_in)
	      0: begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
		         co[i]            <= cdvbs35[(i*(`ITN8))+7];
			      co[i+(`FTAPS*1)] <= cdvbs35[(i*(`ITN8))+6];
			      co[i+(`FTAPS*2)] <= cdvbs35[(i*(`ITN8))+5];
			      co[i+(`FTAPS*3)] <= cdvbs35[(i*(`ITN8))+4];
			      co[i+(`FTAPS*4)] <= cdvbs35[(i*(`ITN8))+3];
			      co[i+(`FTAPS*5)] <= cdvbs35[(i*(`ITN8))+2];
			      co[i+(`FTAPS*6)] <= cdvbs35[(i*(`ITN8))+1];
			      co[i+(`FTAPS*7)] <= cdvbs35[(i*(`ITN8))+0];
		      end
	      end
	      1: begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbs25[(i*(`ITN8))+7];
			      co[i+(`FTAPS*1)] <= cdvbs25[(i*(`ITN8))+6];
			      co[i+(`FTAPS*2)] <= cdvbs25[(i*(`ITN8))+5];
			      co[i+(`FTAPS*3)] <= cdvbs25[(i*(`ITN8))+4];
			      co[i+(`FTAPS*4)] <= cdvbs25[(i*(`ITN8))+3];
			      co[i+(`FTAPS*5)] <= cdvbs25[(i*(`ITN8))+2];
			      co[i+(`FTAPS*6)] <= cdvbs25[(i*(`ITN8))+1];
			      co[i+(`FTAPS*7)] <= cdvbs25[(i*(`ITN8))+0];
		      end
	      end
	      2: begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbs20[(i*(`ITN8))+7];
			      co[i+(`FTAPS*1)] <= cdvbs20[(i*(`ITN8))+6];
			      co[i+(`FTAPS*2)] <= cdvbs20[(i*(`ITN8))+5];
			      co[i+(`FTAPS*3)] <= cdvbs20[(i*(`ITN8))+4];
			      co[i+(`FTAPS*4)] <= cdvbs20[(i*(`ITN8))+3];
			      co[i+(`FTAPS*5)] <= cdvbs20[(i*(`ITN8))+2];
			      co[i+(`FTAPS*6)] <= cdvbs20[(i*(`ITN8))+1];
			      co[i+(`FTAPS*7)] <= cdvbs20[(i*(`ITN8))+0];
		      end
	      end
	      3: begin
		      for( i = 0; i < (`FTAPS); i = i+1 )
		      begin
			      co[i]            <= cdvbt[(i*(`ITN8))+7];
			      co[i+(`FTAPS*1)] <= cdvbt[(i*(`ITN8))+6];
			      co[i+(`FTAPS*2)] <= cdvbt[(i*(`ITN8))+5];
			      co[i+(`FTAPS*3)] <= cdvbt[(i*(`ITN8))+4];
			      co[i+(`FTAPS*4)] <= cdvbt[(i*(`ITN8))+3];
			      co[i+(`FTAPS*5)] <= cdvbt[(i*(`ITN8))+2];
			      co[i+(`FTAPS*6)] <= cdvbt[(i*(`ITN8))+1];
			      co[i+(`FTAPS*7)] <= cdvbt[(i*(`ITN8))+0];
		      end
	      end
	   endcase
	end
	else
	begin
	   // Everything else!
	   for( i = 0; i < (`FTAPS8); i = i+1 )
		begin
		   co[i]  <= 16'd0;
		end
	end
end
//
// Filter state machine
//
always @(posedge clk)
begin
	// Alternate between the I&Q samples
   integer i;
	if(state[1]==0)
	begin
		// I Samples
		for( i = 0; i < (`FTAPS); i= i+1 )
		begin
		   saw[i] <= sai[i];
		end
	end
	else
	begin
		// Q Samples
		for( i = 0; i < (`FTAPS); i= i+1 )
		begin
			saw[i] <= saq[i];
		end
	end
	//
	// Load the current working coefficients
	//	
	case(state)
		0: begin
			// 1st coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i];
			end
		end
		4: begin
			// 2nd coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS)];
			end
		end
		8: begin
			// 3rd coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*2)];
			end
		end
		12: begin
			// 4th coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*3)];
			end
		end
		16: begin
			// 5th coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*4)];
			end
		end
		20: begin
			// 6th coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*5)];
			end
		end
		24: begin
			// 7th coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*6)];
			end
		end
		28: begin
			// 8th coefficients
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*7)];
			end
		end
	endcase
   //
	//
	if(!state[0])
	begin
		//
		// Do the Mults. 1 delay, occurs on every clock cycle
		//	  
		for( i = 0; i < (`FTAPS); i= i+1 )
		begin
			ac[i] <= saw[i] * cow[i];
		end
		// Do the accumulates 1st stage, 2 delay
		ac[12] <= ac[0]+ac[1]+ac[2]+ac[3]+ac[4]+ac[5];
		ac[13] <= ac[6]+ac[7]+ac[8]+ac[9]+ac[10]+ac[11];
		// 2nd stage, 3 delay
		ac[14] <= (ac[12]+ac[13]);
		// Select the wanted bits, 4 delay. Even number of delays so IQ aligned
		out0_r[state[5:1]] <= ac[14][31-:16];
	end
end
//
// Assign the interpolated samples onto the bus which is used by the DAC
//
assign i_out = i_out_r;
assign q_out = q_out_r;

endmodule
/////////////////////////////////////////////////////
//
// Pipelined 4x or 8x interpolating FIR filter
//
// When Bit 1 of state is 0 we are processing I channel
// When Bit 1 of state is 1 we are processing Q channel
//
/////////////////////////////////////////////////////
module ifir( input clk, input [7:0]state, input [15:0]i_in, input [15:0]q_in, 
              input [1:0]f_in, input [2:0]ir_in, input carrier,
              output signed [15:0]i_out, output signed [15:0]q_out );

`define FTAPS   12
`define ITNX    8'd32
`define ITNN    8'd64

reg signed [15:0]sai[`FTAPS];//I Samples
reg signed [15:0]saq[`FTAPS];//Q Samples

reg signed [15:0]co[0:767];//Current Coefficients
reg signed [15:0]saw[0:`FTAPS-1];//Working Samples
reg signed [15:0]cow[0:`FTAPS-1];//Working Coefficients

// Memory for the various filters
reg signed [15:0]cdvbs35_384[0:383];//Coefficients
reg signed [15:0]cdvbs35_512[0:511];//Coefficients
//
reg signed [31:0]ac[0:`FTAPS+2];//Accumulators
reg signed [15:0]out0_r[3:0];

reg signed [15:0]i_out_r;
reg signed [15:0]q_out_r;
//
//
//
initial
begin
    $readmemh("fx32dvbs_35.txt",cdvbs35_384);//0.35 rolloff
    $readmemh("fx64dvbs_35.txt",cdvbs35_512);//0.35 rolloff
end

//
// Sample in / out state machine
//
always @(posedge clk)
begin
   integer i;
	if(state == 8'd0)
	begin
	   // Update I and Q channel samples
		for( i = 0; i < (`FTAPS-1); i= i+1 )
			begin
	         sai[i] <= sai[i+1];
	         saq[i] <= saq[i+1];
			end
         sai[11]  <= carrier ? 16'h7FFF : i_in;
         saq[11]  <= carrier ? 16'h0000 : q_in;	
		end
	if(state[1:0]==2'd0)
	begin
	  	// Ouput new DAC values
	   i_out_r <= out0_r[3];
	   q_out_r <= out0_r[2];
	end
end
//
// Change the filter when needed
//
always @( ir_in )
begin
	//
	// Load the coefficients for the current filter
	//
	integer i;
	integer n;

	if( ir_in == 3'd0 )
	begin
		// x2 interpolating filter
		for( i = 0; i < (`FTAPS); i = i+1 )
		begin
			co[i]            <= cdvbs35_384[(i*(`ITNX)) + 16];
			co[i+(`FTAPS*1)] <= cdvbs35_384[(i*(`ITNX)) + 0];
		end
		// Zero unused coefficients
		for( i = (`FTAPS*2); i < 768; i = i+1 )
		begin
			co[i]  <= 16'd0;
		end
	end
	else
	if( ir_in == 3'd1 )
	begin
		// x4 interpolating filter
		for( i = 0; i < (`FTAPS); i = i+1 )
		begin
			co[i]            <= cdvbs35_384[(i*(`ITNX)) + 24];
			co[i+(`FTAPS*1)] <= cdvbs35_384[(i*(`ITNX)) + 16];
			co[i+(`FTAPS*2)] <= cdvbs35_384[(i*(`ITNX)) + 8];
			co[i+(`FTAPS*3)] <= cdvbs35_384[(i*(`ITNX)) + 0];
		end
		// Zero unused coefficients
		for( i = (`FTAPS*4); i < 768; i = i+1 )
		begin
			co[i]  <= 16'd0;
		end
	end
	else 
	if( ir_in == 3'd2 )
	begin
		// x8 interpolating filter
		for( i = 0; i < (`FTAPS); i = i+1 )
		begin
			co[i]            <= cdvbs35_384[(i*(`ITNX))+28];
			co[i+(`FTAPS*1)] <= cdvbs35_384[(i*(`ITNX))+24];
			co[i+(`FTAPS*2)] <= cdvbs35_384[(i*(`ITNX))+20];
			co[i+(`FTAPS*3)] <= cdvbs35_384[(i*(`ITNX))+16];
			co[i+(`FTAPS*4)] <= cdvbs35_384[(i*(`ITNX))+12];
			co[i+(`FTAPS*5)] <= cdvbs35_384[(i*(`ITNX))+8];
			co[i+(`FTAPS*6)] <= cdvbs35_384[(i*(`ITNX))+4];
			co[i+(`FTAPS*7)] <= cdvbs35_384[(i*(`ITNX))+0];
		end
		// Zero unused coefficients
		for( i = (`FTAPS*8); i < 768; i = i+1 )
		begin
			co[i]  <= 16'd0;
		end
	end
	else
	if( ir_in == 3'd3 )
	begin
		// x16 interpolating filter
		for( i = 0; i < (`FTAPS); i = i+1 )
		begin
			co[i]             <= cdvbs35_384[(i*(`ITNX))+30];
			co[i+(`FTAPS*1)]  <= cdvbs35_384[(i*(`ITNX))+28];
			co[i+(`FTAPS*2)]  <= cdvbs35_384[(i*(`ITNX))+26];
			co[i+(`FTAPS*3)]  <= cdvbs35_384[(i*(`ITNX))+24];
			co[i+(`FTAPS*4)]  <= cdvbs35_384[(i*(`ITNX))+22];
			co[i+(`FTAPS*5)]  <= cdvbs35_384[(i*(`ITNX))+20];
			co[i+(`FTAPS*6)]  <= cdvbs35_384[(i*(`ITNX))+18];
			co[i+(`FTAPS*7)]  <= cdvbs35_384[(i*(`ITNX))+16];
			co[i+(`FTAPS*8)]  <= cdvbs35_384[(i*(`ITNX))+14];
			co[i+(`FTAPS*9)]  <= cdvbs35_384[(i*(`ITNX))+12];
			co[i+(`FTAPS*10)] <= cdvbs35_384[(i*(`ITNX))+10];
			co[i+(`FTAPS*11)] <= cdvbs35_384[(i*(`ITNX))+8];
			co[i+(`FTAPS*12)] <= cdvbs35_384[(i*(`ITNX))+6];
			co[i+(`FTAPS*13)] <= cdvbs35_384[(i*(`ITNX))+4];
			co[i+(`FTAPS*14)] <= cdvbs35_384[(i*(`ITNX))+2];
			co[i+(`FTAPS*15)] <= cdvbs35_384[(i*(`ITNX))+0];
		end
		// Zero unused coefficients
		for( i = (`FTAPS*16); i < 768; i = i+1 )
		begin
			co[i]  <= 16'd0;
		end
	end
	else
	if( ir_in == 3'd4 )
	begin
		// x32 interpolating filter
		for( i = 0; i < (`FTAPS); i = i+1 )
		begin
			co[i]             <= cdvbs35_384[(i*(`ITNX))+31];
			co[i+(`FTAPS*1)]  <= cdvbs35_384[(i*(`ITNX))+30];
			co[i+(`FTAPS*2)]  <= cdvbs35_384[(i*(`ITNX))+29];
			co[i+(`FTAPS*3)]  <= cdvbs35_384[(i*(`ITNX))+28];
			co[i+(`FTAPS*4)]  <= cdvbs35_384[(i*(`ITNX))+27];
			co[i+(`FTAPS*5)]  <= cdvbs35_384[(i*(`ITNX))+26];
			co[i+(`FTAPS*6)]  <= cdvbs35_384[(i*(`ITNX))+25];
			co[i+(`FTAPS*7)]  <= cdvbs35_384[(i*(`ITNX))+24];
			co[i+(`FTAPS*8)]  <= cdvbs35_384[(i*(`ITNX))+23];
			co[i+(`FTAPS*9)]  <= cdvbs35_384[(i*(`ITNX))+22];
			co[i+(`FTAPS*10)] <= cdvbs35_384[(i*(`ITNX))+21];
			co[i+(`FTAPS*11)] <= cdvbs35_384[(i*(`ITNX))+20];
			co[i+(`FTAPS*12)] <= cdvbs35_384[(i*(`ITNX))+19];
			co[i+(`FTAPS*13)] <= cdvbs35_384[(i*(`ITNX))+18];
			co[i+(`FTAPS*14)] <= cdvbs35_384[(i*(`ITNX))+17];
			co[i+(`FTAPS*15)] <= cdvbs35_384[(i*(`ITNX))+16];
			co[i+(`FTAPS*16)] <= cdvbs35_384[(i*(`ITNX))+15];
			co[i+(`FTAPS*17)] <= cdvbs35_384[(i*(`ITNX))+14];
			co[i+(`FTAPS*18)] <= cdvbs35_384[(i*(`ITNX))+13];
			co[i+(`FTAPS*19)] <= cdvbs35_384[(i*(`ITNX))+12];
			co[i+(`FTAPS*20)] <= cdvbs35_384[(i*(`ITNX))+11];
			co[i+(`FTAPS*21)] <= cdvbs35_384[(i*(`ITNX))+10];
			co[i+(`FTAPS*22)] <= cdvbs35_384[(i*(`ITNX))+9];
			co[i+(`FTAPS*23)] <= cdvbs35_384[(i*(`ITNX))+8];
			co[i+(`FTAPS*24)] <= cdvbs35_384[(i*(`ITNX))+7];
			co[i+(`FTAPS*25)] <= cdvbs35_384[(i*(`ITNX))+6];
			co[i+(`FTAPS*26)] <= cdvbs35_384[(i*(`ITNX))+5];
			co[i+(`FTAPS*27)] <= cdvbs35_384[(i*(`ITNX))+4];
			co[i+(`FTAPS*28)] <= cdvbs35_384[(i*(`ITNX))+3];
			co[i+(`FTAPS*29)] <= cdvbs35_384[(i*(`ITNX))+2];
			co[i+(`FTAPS*30)] <= cdvbs35_384[(i*(`ITNX))+1];
			co[i+(`FTAPS*31)] <= cdvbs35_384[(i*(`ITNX))+0];
		end
		// Zero unused coefficients
		for( i = (`FTAPS*32); i < 768; i = i+1 )
		begin
			co[i]  <= 16'd0;
		end
	end
	else
	if( ir_in == 3'd5 )
	begin
		// x64 interpolating filter, reduced filter size of 8
		for( i = 0, n = 0; i < 768; i = i + 12, n = n + 8 )
		begin
			co[i]    <= 16'd0;
			co[i+1]  <= 16'd0;
			co[i+2]  <= cdvbs35_512[n];
			co[i+3]  <= cdvbs35_512[n+1];
			co[i+4]  <= cdvbs35_512[n+2];
			co[i+5]  <= cdvbs35_512[n+3];
			co[i+6]  <= cdvbs35_512[n+4];
			co[i+7]  <= cdvbs35_512[n+5];
			co[i+8]  <= cdvbs35_512[n+6];
			co[i+9]  <= cdvbs35_512[n+7];			
			co[i+10] <= 16'd0;
			co[i+11] <= 16'd0;
		end
	end
	else
	begin
		// Everything else!
		for( i = 0; i < 768; i = i+1 )
		begin
			co[i]  <= 16'd0;
		end
	end
end
//
// Filter state machine
//
always @(posedge clk)
begin
   integer i,n;
	//
	// Load the current working coefficients
	//		
	for( n = 0; n < 256; n = n+4)
	begin
	   if(state == n)
		begin
			for( i = 0; i < (`FTAPS); i= i+1 )
			begin
				cow[i] <= co[i+(`FTAPS*(n/4))];
			end
		end
	end
	//
	// Alternate between the I&Q samples
	//
	if(state[1:0]==2'b01)
	begin
		// I Samples
		for( i = 0; i < (`FTAPS); i= i+1 )
		begin
			saw[i] <= sai[i];
		end
	end
	if(state[1:0]==2'b11)
	begin
		// Q Samples
		for( i = 0; i < (`FTAPS); i= i+1 )
		begin
			saw[i] <= saq[i];
		end
	end

	if(state[0]==1'b0)
	begin
		//
		// Do the Mults. 1 delay, occurs on every clock cycle
		//	  
		for( i = 0; i < (`FTAPS); i= i+1 )
		begin
			ac[i] <= saw[i] * cow[i];
		end
		// Do the accumulates 1st stage, 2 delay
		ac[12] <= ac[0]+ac[1]+ac[2]+ac[3]+ac[4]+ac[5];
		ac[13] <= ac[6]+ac[7]+ac[8]+ac[9]+ac[10]+ac[11];
		// 2nd stage, 3 delay
		ac[14] <= (ac[12]+ac[13]);
		// Select the wanted bits, 4 delay. Even number of delays so IQ aligned
		out0_r[0] <= ac[14][31-:16];
		out0_r[1] <= out0_r[0];
		out0_r[2] <= out0_r[1];
		out0_r[3] <= out0_r[2];
	end
end
//
// Assign the interpolated samples onto the bus which is used by the DAC
//
assign i_out  = i_out_r;
assign q_out  = q_out_r;

endmodule
