///////////////////////////////////////////////////////////////////////////////////////
//
// Asynchronously read memory FIFO
//
// The number of clock cycles depends on the interpolator rate
// It has 2 modes, mode 0 where the samples are 8 bits and are packed into a 
// single 16 bit value. Mode1 1 where the samples are 15 bits, bit 0 determins
// whether the sample is an I sample or a Q sample.
//
// It blindly reads the memory FIFO as the FIFO must be kept full 
// by the host otherwise samples will be dropped in the transmitted signal. 
//
// One version for each interpolator rate
//
// In 16 bit mode the modules self sychronises to the bitstream.
// In 8 bit mode it does not so the signal can get swapped, most receivers
// will cope with that though. 
//
///////////////////////////////////////////////////////////////////////////////////////

module mffreadold( input clk, input [5:0]state, input dav, input [15:0]fifo_in, input [2:0]ir,
                input bitsize,
                output [15:0]i_out, output [15:0]q_out, 
					 output rdreq, output mclk );
// Storage
reg [63:0]s_mem_r;
reg [15:0]i_mem_r[2];
reg [15:0]q_mem_r[2];
reg rdreq_r;
reg mclk_r;
reg [1:0]idx_r;

always @( posedge clk ) 
begin
   if(dav)
	begin
		case( state )
			0 : begin
				rdreq_r <= `MF_ASSERTED;
			end
			2 : begin
				if(bitsize)
				begin
					// 15 bit samples, the LSB of the I channel will always be a 1
					// 16 bit mode
					s_mem_r <= {s_mem_r[47:0],fifo_in}; // Read 16 bits from the memory fifo 
				end
				else
				begin
					// 8 bit mode
					s_mem_r[63:48] <= {fifo_in[15:8],8'h01}; // Read 8 bits from the memory fifo
					s_mem_r[47:32] <= {fifo_in[7:0], 8'h00}; // Read 8 bits from the memory fifo
					idx_r <= 2'd0;
				end
				rdreq_r <= `MF_DEASSERTED;
			end
			4: if(bitsize) rdreq_r <= `MF_ASSERTED;
			6: if(bitsize)
			begin
				// 16 bit mode
				s_mem_r <= {s_mem_r[47:0],fifo_in}; // Read 16 bits from the memory fifo 
			   rdreq_r <= `MF_DEASSERTED;
			end			
			7: begin
			   case(idx_r)
				0: begin
					i_mem_r[0] <= s_mem_r[63:48];
					q_mem_r[0] <= s_mem_r[47:32];
					if(!s_mem_r[48]) idx_r <= idx_r + 2'd1;// Not properly aligned, adjust
				end
				1: begin
					i_mem_r[0] <= s_mem_r[55:40];
					q_mem_r[0] <= s_mem_r[39:24];
					if(!s_mem_r[40]) idx_r <= idx_r + 2'd1;// Not properly aligned, adjust
				end
				2: begin
					i_mem_r[0] <= s_mem_r[47:32];
					q_mem_r[0] <= s_mem_r[31:16];
					if(!s_mem_r[32]) idx_r <= idx_r + 2'd1;// Not properly aligned, adjust
				end
				3: begin
					i_mem_r[0] <= s_mem_r[39:24];
					q_mem_r[0] <= s_mem_r[23:8];
					if(!s_mem_r[24]) idx_r <= idx_r + 2'd1;// Not properly aligned, adjust
				end
				endcase
			   if( ir == 2'd0 ) // x2 Interpolation
			   begin
				   //
				   // Must be available on state 0, precise timing
				   // Written the clock cycle before it is needed.
				   //
				   // The state varies depending on the interpolation rate.
				   //
				   i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				   q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			   end
			end
			15: if( ir == 2'd1 ) // x4 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			31: if( ir == 2'd2 ) // x8 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			63: if( ir == 2'd3 ) // x16 Interpolation, not implemented yet
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
		endcase
	end
	else
	begin
		// No data is available, clear all
		//s_mem_r    <= 64'h0000000000000000; 
		//i_mem_r[0] <= 16'h0000;
		//q_mem_r[0] <= 16'h0000;
		//i_mem_r[1] <= 16'h0000;
		//q_mem_r[1] <= 16'h0000;
		//idx_r      <= 2'd0;
	end
end

// Assign the I and Q output which is used by the Interpolating filter
assign i_out = i_mem_r[1];
assign q_out = q_mem_r[1];

// Update the read request which is used to read from the memory fifo
assign rdreq = rdreq_r;
assign mclk  = state[1];

endmodule

///////////////////////////////////////////////////////////////////////////////////////
//
// Asynchronously read memory FIFO
//
// The number of clock cycles depends on the interpolator rate
// It has 2 modes, mode 0 where the samples are 8 bits and are packed into a 
// single 16 bit value. Mode1 1 where the samples are 15 bits, bit 0 determins
// whether the sample is an I sample or a Q sample.
//
// It blindly reads the memory FIFO as the FIFO must be kept full 
// by the host otherwise samples will be dropped in the transmitted signal. 
//
// One version for each interpolator rate
//
// In 16 bit mode the modules self sychronises to the bitstream.
// In 8 bit mode it does not so the signal can get swapped, most receivers
// will cope with that though. 
//
///////////////////////////////////////////////////////////////////////////////////////

module mffread( input clk, input [7:0]state, input dav, input [15:0]fifo_in, input [2:0]ir,
                input bitsize,
                output [15:0]i_out, output [15:0]q_out, 
					 output rdreq, output mclk );
// Storage
reg [15:0]i_mem_r[2];
reg [15:0]q_mem_r[2];
reg [15:0]i_last_r;
reg [15:0]q_last_r;

reg rdreq_r;

always @( posedge clk ) 
begin
   if(dav)
	begin
		case( state )
			0 : begin
				rdreq_r <= `MF_ASSERTED;
			end
			2 : begin
				if(bitsize)
				begin
					// 15 bit samples, the LSB of the I channel will always be a 1
					// 16 bit mode
					if(fifo_in[0])
					begin
					    i_mem_r[0] <= fifo_in;
					end
					else
					begin
					    q_last_r   <= fifo_in;
					    i_mem_r[0] <= i_last_r;
					end
				end
				else
				begin
					// 8 bit mode
					i_mem_r[0] <= {fifo_in[15:8],8'h01}; // Read 8 bits from the memory fifo
					q_mem_r[0] <= {fifo_in[7:0], 8'h00}; // Read 8 bits from the memory fifo
				end
				rdreq_r <= `MF_DEASSERTED;
			end
			4: if(bitsize) rdreq_r <= `MF_ASSERTED;
			6: if(bitsize)
			begin
				// 16 bit mode
				if( fifo_in[0])
				begin 
				   i_last_r   <= fifo_in;
				   q_mem_r[0] <= q_last_r;
				end
				else
				begin
				    q_mem_r[0] <= fifo_in;
				end
			   rdreq_r <= `MF_DEASSERTED;
			end			
			7: if( ir == 3'd0 ) // x2 Interpolation
			begin
				   //
				   // Must be available on state 0, precise timing
				   // Written the clock cycle before it is needed.
				   //
				   // The state varies depending on the interpolation rate.
				   //
			   i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			15: if( ir == 3'd1 ) // x4 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			31: if( ir == 3'd2 ) // x8 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			63: if( ir == 3'd3 ) // x16 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			127: if( ir == 3'd4 ) // x32 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
			255: if( ir == 3'd5 ) // x64 Interpolation
			begin
				i_mem_r[1] <= {i_mem_r[0][15:1],1'b0};
				q_mem_r[1] <= {q_mem_r[0][15:1],1'b0};
			end
		endcase
	end
end

// Assign the I and Q output which is used by the Interpolating filter
assign i_out = i_mem_r[1];
assign q_out = q_mem_r[1];

// Update the read request which is used to read from the memory fifo
assign rdreq = rdreq_r;
assign mclk  = state[1];

endmodule
