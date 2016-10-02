////////////////////////////////////////////////////////////////////////////////////
//
// RAW mode code for DATV Express
//
// This varient of the FPGA code takes the input samples from the 
// host P.C and interpolates them before outputing them to the attached DAC.
//
// All internal maths is done with 16 bit precision. Output to DAC is 14 bit.
//
// The interpolation rate is set by the host, it can be x4 x8 x16
//
////////////////////////////////////////////////////////////////////////////////////
`define FX2_ASSERTED   1'b0
`define FX2_DEASSERTED 1'b1
`define MF_ASSERTED    1'b1
`define MF_DEASSERTED  1'b0

module DATVExpressRaw( input clk_48, input [15:0]fx2_fd, input fx2_flaga, input fx2_ifclk, 
								output fx2_slwr, output fx2_slrd, output [1:0]fx2_addr, output fx2_sloe, 
								input i2c_scl, inout i2c_sda,
                        input pll_lock, input pll_clk_20MHZ, input si570clk,
								input [7:0]fx2_pe,input fx2_pc0,input fx2_pc2,
								output j4_2, input reset, input txline, 
								output [5:0]pio,
                        output [13:0]dac_d, output daciqwrt, output daciqclk, output daciqreset, output daciqsel, 
								output sleep_txdis, output LED_1, output LED_2, output LED_3, output LED_5 );

// 32 bits counter
reg  [31:0] cnt_r;
reg  [7:0]  m_state_r;    // State machine for the DAC and memory fifo 
reg  [15:0] ep2_data_r;   // temporary store of ep2 data
wire [15:0] i_int_in_w;   // in phase wire out from memory fifo read to interpolator 
wire [15:0] q_int_in_w;   // q phase  wire out from memory fifo read to interpolator 
wire [15:0] i_dac_in_w;   // in phase wire to DAC module 
wire [15:0] q_dac_in_w;   // q phase  wire to DAC module
wire        clk400_w;     // clock to drive the symbol rate generator
wire clk_w,clkd_w;        // clock at 4x times the DAC rate, 32x the sym rate
wire [15:0]sample_out_w;  // Output 16 bit data from the mem fifo 
wire [63:0]phase_inc_w;    // Sets the symbol rate of the clock

reg  [15:0]sample_in_r;   // location to save EP2 contents to  
wire  sample_av_w;        // Sample available
reg  ff_wrclk_r;          // memory fifo write register
wire ff_wrreq_w;
wire ff_rdclk_w;
wire ff_dav_w;
wire ff_full_w;           // fifo full wire
wire mf_clk_w;
wire mf_rdreq_w;

reg  fx2_slrd_r;
reg  fx2_slwr_r;
reg  fx2_sloe_r;

wire [15:0]i_dc_cal_w;
wire [15:0]q_dc_cal_w;
wire led_w,bitsize_w;
wire [1:0]filter_w;
wire [2:0]interp_w;
wire si570av_w;
wire carrier_w,calibrate_w;
wire [3:0]pio_w;

////////////////////////////////////////////////////////////
// Modules created by Altera Mega Wizard
////////////////////////////////////////////////////////////

// PLL clock used for DAC state machine, clk_w 16 x symbol rate
pll dac_clk1( .inclk0(clk_48), .c0( clk400_w ));

// Symbol rate generator
srgen sgen( .clkin(clk400_w), .phase_inc(phase_inc_w), .si570av(si570av_w), .si570clk(si570clk), .clkout(clk_w), .clkoutd(clkd_w));

/////////////////////////////////////////////////////////////////
//
// This is the memory fifo, data from EP2 is written into this
// Reading is done on the rising edge of DAC clock
// Writing is done on the rising edge of the FX2 IFCLK
//
/////////////////////////////////////////////////////////////////
ramff memff( .data(sample_in_r), .q(sample_out_w), 
             .wrclk(fx2_ifclk),  .wrreq(ff_wrreq_w), .wrfull(ff_full_w), 
             .rdclk(mf_clk_w),   .rdreq(mf_rdreq_w), .rdempty(sample_av_w));

/////////////////////////////////////////////////////////////
//
// Modules created by G4GUO
//
// Timing examples are for 4Ms, scale as needed
//
// clk_w is at 128 MHz for 4M
//
/////////////////////////////////////////////////////////////

// This reads data out from the memory fifo it operates at 2x the symbol rate
mffread mffr( .clk(clk_w), .state(m_state_r), .dav(!sample_av_w), .fifo_in(sample_out_w), 
              .ir(interp_w), .bitsize(bitsize_w),
              .i_out(i_int_in_w), .q_out(q_int_in_w), .rdreq(mf_rdreq_w), .mclk(mf_clk_w));

// This interpolates the data
ifir interp( .clk(clk_w), .state(m_state_r), .i_in(i_int_in_w), .q_in(q_int_in_w), 
              .f_in(filter_w), .ir_in(interp_w), .carrier(carrier_w),
              .i_out(i_dac_in_w), .q_out(q_dac_in_w));

// This writes data to the DAC device at 1/4 clock rate
dac_w  dac( .clk(clk_w), .clkd(clkd_w), .i_data(i_dac_in_w), .q_data(q_dac_in_w), .state(m_state_r[1:0]),
            .i_dc_cal(i_dc_cal_w), .q_dc_cal(q_dc_cal_w), .calibrate(calibrate_w), 
            .dac_d(dac_d), .dav(sample_av_w), .daciqwrt(daciqwrt), .daciqclk(daciqclk), 
				.daciqsel(daciqsel), .daciqreset(daciqreset)); 

// I2c controller
i2cslave i2cs( .clk(clk_48), .clk_i2c(i2c_scl), .rstin(reset), .data_i2c(i2c_sda), 
               .srate(phase_inc_w), .bitsize(bitsize_w), .si570av(si570av_w),
					.carrier(carrier_w), .calibrate(calibrate_w), .pio(pio_w),
               .i_dc_cal(i_dc_cal_w), .q_dc_cal(q_dc_cal_w), 
					.led(led_w), .filter(filter_w), .ir(interp_w));

// PTT delay
wire pttd_w;
wire relay_w;
 
seq sequencer( .clk(clk_48), .ptt_i(txline), .relay_o(relay_w), .ptt_o(pttd_w));

always @(posedge clk_w) 
begin
    cnt_r       <= cnt_r     + 32'h1;
	 // Modulo dependant on interpolator rate
	 case(interp_w)
	 0: m_state_r   <= (m_state_r + 8'd1)&(8'h07);//x2
	 1: m_state_r   <= (m_state_r + 8'd1)&(8'h0F);//x4
	 2: m_state_r   <= (m_state_r + 8'd1)&(8'h1F);//x8
	 3: m_state_r   <= (m_state_r + 8'd1)&(8'h3F);//x16
	 4: m_state_r   <= (m_state_r + 8'd1)&(8'h7F);//x32
	 5: m_state_r   <= (m_state_r + 8'd1)&(8'hFF);//x64
	 default: m_state_r   <= (m_state_r + 8'd1)&(8'h07);//x2 messed up!
	 endcase
end

/////////////////////////////////////////////////////////////////
//
// Buffer any new samples from the EP2 interface.
//
// The FX2 is in synchronous slave mode
// Valid data is saved on rising edge of IFCLK
//
// FX2 is generally active low
// Memory fifo is active high
//
/////////////////////////////////////////////////////////////////

always @( negedge fx2_ifclk )
begin
    sample_in_r <= fx2_fd[15:0];
end  

// FX2 EP2 control lines
assign fx2_addr = 2'b00;// Perminantly select EP2
assign fx2_slwr = `FX2_DEASSERTED;// read only so disable write
// Only allow reading from fx2 when mff not full and ep2 is not empty
assign fx2_slrd = ff_full_w || !fx2_flaga ? `FX2_DEASSERTED : `FX2_ASSERTED;
// Only allow reading from fx2 when mff not full and ep2 is not empty
assign fx2_sloe = ff_full_w || !fx2_flaga ? `FX2_DEASSERTED : `FX2_ASSERTED;

// Memory fifo
// Only write to mem fifo from when fx2 is not empty and mf is not full
assign ff_wrreq_w = fx2_flaga && !ff_full_w ? `MF_ASSERTED : `MF_DEASSERTED;

// Set the symbol rate for testing
//assign phase_inc_w = 64'd2951479051793528258;    // Sets the symbol rate of the clock

// Assign Status LEDs
assign LED_1       = fx2_pc0; // USB activity
// If the fifo is empty, led off, if receive led slow flash, if transmit fast flash
assign LED_2       = sample_av_w ? 1'b0 : txline ? cnt_r[22] : cnt_r[25];
assign LED_3       = pll_lock;
assign LED_5       = 1'b1;
// State of the DAC/PLL
assign sleep_txdis = !txline;
assign j4_2        = txline;
// IO pins control from host
assign pio[0] = pio_w[0];// J6 pin 5  (pin 94)
assign pio[1] = pio_w[1];// J6 pin 6  (pin 72)
assign pio[2] = pio_w[2];// J6 pin 7  (pin 71)
assign pio[3] = pio_w[3];// J6 pin 10 (pin 67)
assign pio[4] = pttd_w;  // J6 pin 3  (pin 97)
assign pio[5] = relay_w; // J6 pin 4  (pin 96)

endmodule
