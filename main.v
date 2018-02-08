`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:56:54 01/18/2018 
// Design Name: 
// Module Name:    main 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module main(
    input CLKin, //fpga input clock
    input CLK_LFC,
	 //slaveSPI to communicate with Raspberry Pi	 
	 input SCLK,
	 input MOSI, 
	 input CSEL,
	 output MISO,
	 output reg rgLed0,
	 output reg rgLed1,
	 
	
	//masterQuadSPI to communicate with the FlashMemory
	 inout SI_IO0, //serial input
    inout SO_IO1, //serial output
    inout WP_IO2, //write protect not used - but used for quad
    inout HOLD_IO3, //hold not used- but used for quad
	 output oSCK,
	 output CS,

    //second reset - from button
	 input RESETbutton,
	 
	 
	 //just for testing on the scope
	 output SCOPE_SI_IO0,
	 output SCOPE_SO_IO1,
	 output SCOPE_WP_IO2,
	 output SCOPE_HOLD_IO3,
	 output SCOPE_CS

	 );
///////////////////////////////////////////////////////////////////////////////////////
//    RESET

	 wire RESETBut;
	 reg [15:0] regRESET=16'h7FFF;
	 wire RESET ;
 	 assign RESET = regRESET[15] | RESETBut;
	 
	 always@(posedge mclk) regRESET[15:0]<={regRESET[14:0],1'b0};	 
	 
	 
	 
	 always@(posedge CLK_LFC) begin
	 	 rgLed0<=!rgLed0;
       rgLed1<=!rgLed1;
	 end
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
wire rCS;
wire rSI_IO0;
wire rSO_IO1;
wire rWP_IO2;
wire rHOLD_IO3;


assign rCS =       RESET?1'b0:CS;
assign rSI_IO0   = RESET?1'b0:SI_IO0;
assign rSO_IO1   = RESET?1'b0:SO_IO1;
assign rWP_IO2   = RESET?1'b0:WP_IO2;
assign rHOLD_IO3 = RESET?1'b0:HOLD_IO3;

	 
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
// MODULES


CommandDecoder cmddec(mclk,mem_clk,RESET,bufSCLK, MISO, MOSI,CSEL,CS,SI_IO0,SO_IO1,WP_IO2,HOLD_IO3);
//140MHz
   DCM_CLKGEN #(
      .CLKFXDV_DIVIDE(8),       // CLKFXDV divide value (2, 4, 8, 16, 32)
      .CLKFX_DIVIDE(1),         // Divide value - D - (1-256)
      .CLKFX_MD_MAX(0.0),       // Specify maximum M/D ratio for timing anlysis
      .CLKFX_MULTIPLY(150),       // Multiply value - M - (2-256)
      .CLKIN_PERIOD(125),       // Input clock period specified in nS
      .SPREAD_SPECTRUM("NONE"), // Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
                                // "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2" 
      .STARTUP_WAIT("FALSE")    // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
   )
   DCM_CLKGEN_inst1 (
      .CLKFX(),         // 1-bit output: Generated clock output
      .CLKFX180(),   // 1-bit output: Generated clock output 180 degree out of phase from CLKFX.
      .CLKFXDV(mclk),     // 1-bit output: Divided clock output
      .LOCKED(),       // 1-bit output: Locked output
      .PROGDONE(),   // 1-bit output: Active high output to indicate the successful re-programming
      .STATUS(),       // 2-bit output: DCM_CLKGEN status
      .CLKIN(clk_8MHzbuf25),         // 1-bit input: Input clock
      .FREEZEDCM(), // 1-bit input: Prevents frequency adjustments to input clock
      .PROGCLK(),     // 1-bit input: Clock input for M/D reconfiguration
      .PROGDATA(),   // 1-bit input: Serial data input for M/D reconfiguration
      .PROGEN(),       // 1-bit input: Active high program enable
      .RST(1'b0)              // 1-bit input: Reset input pin
   );
/*
//80MHz
   DCM_CLKGEN #(
      .CLKFXDV_DIVIDE(2),       // CLKFXDV divide value (2, 4, 8, 16, 32)
      .CLKFX_DIVIDE(1),         // Divide value - D - (1-256)
      .CLKFX_MD_MAX(0.0),       // Specify maximum M/D ratio for timing anlysis
      .CLKFX_MULTIPLY(20),       // Multiply value - M - (2-256)
      .CLKIN_PERIOD(125),       // Input clock period specified in nS
      .SPREAD_SPECTRUM("NONE"), // Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
                                // "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2" 
      .STARTUP_WAIT("FALSE")    // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
   )
   DCM_CLKGEN_inst2 (
      .CLKFX(none1),         // 1-bit output: Generated clock output
      .CLKFX180(none),   // 1-bit output: Generated clock output 180 degree out of phase from CLKFX.
      .CLKFXDV(SCK),     // 1-bit output: Divided clock output
      .LOCKED(LOCKED2),       // 1-bit output: Locked output
      .PROGDONE(PROGDONE2),   // 1-bit output: Active high output to indicate the successful re-programming
      .STATUS(STATUS2),       // 2-bit output: DCM_CLKGEN status
      .CLKIN(clk_8MHzbuf100),         // 1-bit input: Input clock
      .FREEZEDCM(FREEZEDCM2), // 1-bit input: Prevents frequency adjustments to input clock
      .PROGCLK(PROGCLK2),     // 1-bit input: Clock input for M/D reconfiguration
      .PROGDATA(PROGDATA2),   // 1-bit input: Serial data input for M/D reconfiguration
      .PROGEN(PROGEN2),       // 1-bit input: Active high program enable
      .RST(1'b0)              // 1-bit input: Reset input pin
   );
  */                 
 /*
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
/////////////////////////    PLL block                            /////////////////////
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
   // PLL_BASE: Phase Locked Loop (PLL) Clock Management Component
   //           Spartan-6
   // Xilinx HDL Language Template, version 14.7

   PLL_BASE #(
      .BANDWIDTH("OPTIMIZED"),             // "HIGH", "LOW" or "OPTIMIZED" 
      .CLKFBOUT_MULT(25),                   // Multiply value for all CLKOUT clock outputs (1-64)
      .CLKFBOUT_PHASE(0.0),                // Phase offset in degrees of the clock feedback output (0.0-360.0).
      .CLKIN_PERIOD(50),                  // Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                           // MHz).
      // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
		//clk0 -mclk- 200MHz
		//clk1 - unused
		//clk2 -memory clock - 50MHz
		//
      .CLKOUT0_DIVIDE(1),       .CLKOUT1_DIVIDE(8),
      .CLKOUT2_DIVIDE(8),       .CLKOUT3_DIVIDE(1),
      .CLKOUT4_DIVIDE(1),       .CLKOUT5_DIVIDE(1),
      // CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      .CLKOUT0_DUTY_CYCLE(0.5),      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT2_DUTY_CYCLE(0.5),      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT4_DUTY_CYCLE(0.5),      .CLKOUT5_DUTY_CYCLE(0.5),
      // CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      .CLKOUT0_PHASE(0.0),      .CLKOUT1_PHASE(0.0),
      .CLKOUT2_PHASE(180.0),    .CLKOUT3_PHASE(0.0),
      .CLKOUT4_PHASE(0.0),      .CLKOUT5_PHASE(0.0),
      .CLK_FEEDBACK("CLKFBOUT"),           // Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      .COMPENSATION("SYSTEM_SYNCHRONOUS"), // "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      .DIVCLK_DIVIDE(1),                   // Division value for all output clocks (1-52)
      .REF_JITTER(0.1),                    // Reference Clock Jitter in UI (0.000-0.999).
      .RESET_ON_LOSS_OF_LOCK("FALSE")      // Must be set to FALSE
   )
   PLL_BASE_inst (
      .CLKFBOUT(feedCLK), // 1-bit output: PLL_BASE feedback output
      // CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
      .CLKOUT0(PLLOutCLK),
      .CLKOUT1(SCKMEMCTRKnoB),// SPI Memory clock - 50MHz = 8*50/8
      .CLKOUT2(SCKMEMnoB),    // SPI Memory clock - 50MHz = brougth to the output
      .CLKOUT3(), 
      .CLKOUT4(),
      .CLKOUT5(),
      .LOCKED(),     // 1-bit output: PLL_BASE lock status output
      .CLKFBIN(feedCLK_buf),   // 1-bit input: Feedback clock input
      .CLKIN(bufCLK8MHz),       // 1-bit input: Clock input
      .RST(1'b0)            // 1-bit input: Reset input
   );
	assign feedCLK_buf = feedCLK;
	*/
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
////////////////////////      BUFFERS                     /////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////
wire CLK8MHz_int;
//IBUFG #(.IOSTANDARD("DEFAULT")) IBUF_2 (.O(CLK8MHz_int),.I(CLKin));
BUFG BUFCLK (.O(CLK8MHz_int),.I(CLKin));
BUF BUF_25 (.I(CLK8MHz_int),.O(clk_8MHzbuf25));
//BUF BUF_100(.I(CLK8MHz_int),.O(clk_8MHzbuf100));

IBUFG #(.IOSTANDARD("DEFAULT")) IBUF_1 (.O(bufSCLK),.I(SCLK));

//BUFG BUF_2 (.O(mclk),.I(PLLOutCLK));
//BUF BUF_3 (.O(SCK),.I(SCKMEMCTRKnoB));

//BUFG BUF_4 (.O(oSCKBuff),.I(SCK));

IBUF BUF_5 (.O(RESETBut),.I(RESETbutton));

OBUF BUF_SPI1 (.O(SCOPE_SI_IO0),.I(rSI_IO0));
OBUF BUF_SPI2 (.O(SCOPE_SO_IO1),.I(rSO_IO1));
OBUF BUF_SPI3 (.O(SCOPE_WP_IO2),.I(rWP_IO2));
OBUF BUF_SPI4 (.O(SCOPE_HOLD_IO3),.I(rHOLD_IO3));

OBUF BUF_SPI6 (.O(SCOPE_CS),.I(rCS));

OBUF BUF_MEM_CLK (.I(mem_clk), .O(oSCK));
/*
//BUFG BUF_6 (.O(oMISO),.I(MISO));
//special buffer to output the PLL generated clock
ODDR2 #(
	.DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
	.INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
	.SRTYPE("SYNC") // Specifies "SYNC" or "ASYNC" set/reset
) clock_forward_inst (
	.Q(oSCK),     // 1-bit DDR output data
	.C0(oSCKBuff),  // 1-bit clock input
	.C1(!oSCKBuff), // 1-bit clock input
	.CE(1'b1),      // 1-bit clock enable input
	.D0(1'b0), // 1-bit data input (associated with C0)
	.D1(1'b1), // 1-bit data input (associated with C1)
	.R(1'b0),   // 1-bit reset input
	.S(1'b0)   // 1-bit set input
);
*/
endmodule
