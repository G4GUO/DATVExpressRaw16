//
// Input clock 48 MHz
//
module seq( input clk, input ptt_i, output relay_o, output ptt_o );

reg [9:0]prescaler_r;
reg [1:0]state_r;
reg [15:0]timer_r;
reg relay_r;
reg ptt_r;

always @(posedge clk) prescaler_r <= prescaler_r + 10'd1;

always @(posedge prescaler_r[9])
begin
	case(state_r)
	2'd0 : begin
		// Receiving
		if(ptt_i)
		begin
			state_r <= 2'd1;
			relay_r <= 1'b1;
			timer_r <= 16'd9375;
		end
		else
		begin
			relay_r <= 1'b0;
			ptt_r   <= 1'b0;
		end
	end
	2'd1 : begin
		// Going to transmit
		if(ptt_i)
		begin
			if(timer_r == 0)
			begin
				state_r <= 2'd2;
				ptt_r   <= 1'b1;
			end
			else
			begin
				timer_r <= timer_r - 16'd1;
			end
		end
		else
		begin
			// PTT has been released
			state_r <= 2'd0;
			relay_r <= 1'b0;
			ptt_r   <= 1'b0;
		end
	end
	2'd2 : begin
		// Transmitting
		if(!ptt_i)
		begin
			state_r <= 2'd3;
			timer_r <= 16'd9375;
			ptt_r   <= 1'b0;
		end
	end
	2'd3 : begin
		// Going to receive
		if(timer_r == 0)
		begin
			state_r <= 2'd0;
			relay_r <= 1'b0;
		end
		else
		begin
			timer_r <= timer_r - 16'd1;
		end
	end
	endcase
end
assign relay_o = relay_r;
assign ptt_o   = ptt_r;

endmodule
