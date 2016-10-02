//
// This is the I2C controller module.
//
// Data is received in memory and written out via outputs to
// the required modules.
//
// I tried implementing this using edges on the I2C lines
// but that proved problematic with clashes writing to variables
// so in the end I oversampled the lines and used that to 
// drive the state machine.
//

module i2cslave( input clk, input clk_i2c, input rstin, inout data_i2c, 
                 output bitsize, output si570av, output carrier, output calibrate,
					  output [3:0]pio, output [15:0]i_dc_cal, output [15:0]q_dc_cal, 
					  output [63:0]srate, output led, output [1:0]filter, output [2:0]ir );

// Do we need to send an ack
reg ack_r[2];
reg us_r,rw_r;
// last state of lines
reg i2c_clk_r[2];
reg i2c_dat_r[2];
// state
reg [4:0]state_r;
// receive register
reg [7:0]rx_r;

reg [3:0]i_r;
reg [7:0]data_r;
reg [7:0]addr_r;
reg [7:0]mem_r[32];// Data storage

reg [7:0]idx_r;// memory address pointer
reg [7:0]val_r;// memory value

reg [7:0]bus_timeout_r;

`define I2C_ADDRESS   8'h46
`define IC_MSB        8'h80
`define IC_LSB        8'h00
`define LOGIC_ONE     1'b1

initial 
begin
    state_r  = 5'd0;
    ack_r[0] = `LOGIC_ONE;//should be constant
    ack_r[1] = `LOGIC_ONE;//should be constant
    mem_r[0] =  8'h01;// Default 16 bits
    mem_r[1] =  8'h0C;// 0.35 rolloff filter, x8 interpolator
    mem_r[2] =  8'h80;// I offset Cal
    mem_r[3] =  8'h00;
    mem_r[4] =  8'h80;// Q offset Cal
    mem_r[5] =  8'h00;
    mem_r[8] =  8'h00;// Ancillary byte
end

// Sample at 16x the I2C clock rate
always @(posedge clk)
begin
   if(!rstin)
	begin
	   // We are in the reset condition
		state_r   <= 5'd0;// idle state
      ack_r[0]  <= 1'b1;// Hi impedance
      ack_r[1]  <= 1'b1;// Hi impedance
      us_r      <= 1'b0;// Not for us
		// May wish to add default memory values?
	end
	else
	begin
	   // remember last condition
	   i2c_clk_r[1] <= i2c_clk_r[0];
	   i2c_dat_r[1] <= i2c_dat_r[0];
	   i2c_clk_r[0] <= clk_i2c;
	   i2c_dat_r[0] <= data_i2c;

      // Must make sure we don't block the data bus 
	   if(ack_r[1]==0) 
	       if(bus_timeout_r > 0 ) bus_timeout_r <= bus_timeout_r - 1'd1;
	   else
          bus_timeout_r <= 8'd64;
		 
	   // Now see whether something has happened
	   if((i2c_dat_r[1] != i2c_dat_r[0])&&(i2c_clk_r[0]))
	   begin
         // Data should not be changing when clock is high unless it is a stop/start
	      if(!i2c_dat_r[0])
		   begin
		      // Failing edge
		      // Start condition
		      state_r   <= 5'd1;// start state
		      us_r      <= 1'b0;// assume not for us
            ack_r[0]  <= 1'b1;// Hi impedance
		   end
		   else
		   begin
		      // Rising edge
		      // Stop condition
            if((us_r)&&(!rw_r))
		      begin
		         // The message was for us so action it if write
		         mem_r[idx_r&8'h1F] <= data_r;
		      end
		      state_r  <= 5'd0;// Idle state
			   us_r     <= 1'b0;// No longer for us
            ack_r[0] <= 1'b1;// Hi impedance
		   end
      end
	   else
	   begin
	      if(i2c_clk_r[1] != i2c_clk_r[0])
		   begin
	         if(i2c_clk_r[0])
		      begin
			     // Rising clock edge
		        // New data bit
		        // Update the rx register
		        rx_r <= {rx_r[6:0],i2c_dat_r[0]};
              if( state_r > 0 ) state_r <= state_r + 5'd1;
		        // See if we need to do anything, in state 0 we don't
			     // These states will be delayed by one
              case(state_r)
			     8'd0 : ack_r[0] <= 1'b1;// bus = hi impedance
		        8'd8 : begin
			         // Check the address, we are receiving the R/W
			         if( rx_r[6:0] == `I2C_ADDRESS)
			         begin	
				         us_r     <= 1'b1;// It is for us
			            rw_r     <= i2c_dat_r[0];// Save RW flag
				         ack_r[0] <= 1'b0;// Send address ack
					   end
				      else
					   begin
				         state_r  <= 5'd0;// Stop further processing
				      end
		         end
			      // memory address data field
		         8'd17 : begin
                  idx_r     <= {rx_r[6:0],i2c_dat_r[0]};// Save the register address
				      ack_r[0]  <= 1'b0;// send data ack
				   end
			      // memory data field
		         8'd26 : begin
			         data_r   <= {rx_r[6:0],i2c_dat_r[0]};//Data to be saved
				      ack_r[0] <= 1'b0;// send data ack
				   end
               endcase
		      end
				else
				begin
				   // Falling clock edge
				   ack_r[1] <= ack_r[0];// Update the databus
               ack_r[0] <= 1'b1;// High impedance
				end
	      end
	   end
   end
end

// Send the ack bit if needed, if there is a timeout go to the high impedance state
assign data_i2c = (bus_timeout_r == 0) ? 1'bz : ack_r[1] ? 1'bz : 1'b0;

// Configuration information rat's nest
assign led       =  mem_r[0][6];
assign bitsize   =  mem_r[0][0];
assign si570av   =  mem_r[0][1];
assign filter    =  mem_r[1][1:0]; // Filter in use
assign ir        =  mem_r[2][2:0]; // Interpolator rate

// reserved for fec
assign i_dc_cal  = {mem_r[4],mem_r[5]};
assign q_dc_cal  = {mem_r[6],mem_r[7]};
assign carrier   =  mem_r[8][0];
assign calibrate = mem_r[8][1];
assign pio       =  mem_r[8][7:4];// IO control on J6
assign srate     = {mem_r[10],mem_r[11],mem_r[12],mem_r[13],mem_r[14],mem_r[15],mem_r[16],mem_r[17]};

endmodule 
