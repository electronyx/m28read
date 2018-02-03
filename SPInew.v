`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:17:41 01/19/2018 
// Design Name: 
// Module Name:    SPInew 
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
module SPInew(
   input CLK, //high speed clock
	input  RST,
	//SPI signals
	input  SCK,
	input  MOSI,
   input	CSEL,
	output MISO,
	
	input send_trigger,
	output reg busy,
	output reg [47:0] received_data,
	output reg [47:0] long_dataIN,
	input [47:0] output_data,
	output reg received,
	output reg sent,
	input [3:0] InMsgByteCount,
	input LongMsgComing,
	input [2:0] SPI_MSG_TYPE
	);

//MSG TYPE
parameter NO_BY=3'b000, ONE_BY=3'b001, STD_TWO_BY=3'b010, THREE_BY= 3'b011 ,SIX_BY=3'b110, LONG = 3'b111 ;

parameter           IDLE=5'b00000,  RECEIVE=5'b00001,   SEND=5'b00010, WAIT_FOR_START=5'b00011, RECEIVE_LONG=5'b00100;
	 
reg [4:0] stateSPI =IDLE;
reg [4:0] next_stateSPI;
//start message
reg [2:0] SSELr;  
always @(posedge CLK) SSELr <= {SSELr[1:0], CSEL};
wire CSEL_FallingEdge = (SSELr[2:1]==2'b10); //message starts

//bit sampling on SCK falling edge
reg [2:0] SCKr;  
always @(posedge CLK) SCKr <= {SCKr[1:0], SCK};
wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges



//reg [47:0] output_reg;
reg [5:0] bit_cntr=6'b000000;
wire [5:0] new_bit_cntr;
assign new_bit_cntr = bit_cntr -6'b000001;

reg rMISO;
assign MISO = CSEL? 1'b0 : output_data[bit_cntr];



//-------------------------------------------- main FSM
//----------------------

//-- initialize main FSM 

always @ (posedge CLK)
begin
	if (RST)
		stateSPI <= IDLE;
	else
		stateSPI <= next_stateSPI;
end

always@(*) begin

    next_stateSPI=stateSPI;
    
    case(stateSPI)
		 IDLE:
			 begin   
				if(CSEL_FallingEdge)        next_stateSPI=RECEIVE; //doesn't matter if long or short
				else if(send_trigger&&!busy)next_stateSPI=SEND;
				else                        next_stateSPI=IDLE;
			 end 
		 RECEIVE:
			 begin
				 if(received&&bit_cntr==4'b0000) next_stateSPI=IDLE;
				 else next_stateSPI=RECEIVE;
			 end
		 SEND:
			 begin
				 if(sent&&bit_cntr==4'b0000)  next_stateSPI=IDLE;
				 else next_stateSPI=SEND;
			 end  

       default:
		    next_stateSPI=IDLE;
	 endcase
    
end

//bitcounter handling value---------------------------------------
always@(posedge CLK ) begin
   if(stateSPI==IDLE) begin
		if(CSEL_FallingEdge&&!send_trigger) begin
			if(LongMsgComing) bit_cntr<=6'b001000*InMsgByteCount-1'b1;
			else bit_cntr<=6'b001111;
		end
		else if(send_trigger&&!busy) begin
			if(SPI_MSG_TYPE     ==ONE_BY)    bit_cntr<=6'b000111;
			else if(SPI_MSG_TYPE==STD_TWO_BY)bit_cntr<=6'b001111; //send 2bytes = countr = 23
			else if(SPI_MSG_TYPE==THREE_BY)  bit_cntr<=6'b010111; //send 3bytes
			else if(SPI_MSG_TYPE==SIX_BY)    bit_cntr<=6'b101111; //send 6bytes
			else if(SPI_MSG_TYPE==LONG)      bit_cntr<=6'b001000*InMsgByteCount-1'b1;
			else                             bit_cntr<=6'b001111;
		end
	end
	else if(stateSPI==RECEIVE && SCK_fallingedge && bit_cntr!=6'b000000) bit_cntr<=new_bit_cntr;
	else if(stateSPI==SEND && SCK_risingedge) bit_cntr<=new_bit_cntr;
end

//--------------------RECEIVED flag
always@(posedge CLK) begin //should be clocked so the received will be 1 for whole CLK period??
	if(RST) received<=1'b0;
   else if(stateSPI==RECEIVE && bit_cntr==6'b000000 && SCK_fallingedge) received<=1'b1;
   else received<=1'b0; 
end

//--------------------SENT flag
always@(posedge CLK) begin //should be clocked so the received will be 1 for whole CLK period??
	if(RST) sent<=1'b0;
   else if(stateSPI==SEND && bit_cntr==6'b000000) sent<=1'b1;
   else sent<=1'b0; 
end
//--------------------BUSY flag
always@(*) begin
   if(stateSPI==RECEIVE || stateSPI==SEND) busy=1'b1;
	else busy=1'b0;	
end

//-------------------- RECEIVE DATA
always@(negedge SCK or posedge RST)begin
   if(RST) received_data<=48'h000000000000;
   //if(stateSPI==RECEIVE) received_data<={32'h00000000,received_data[14:0],MOSI};
   else if(stateSPI==RECEIVE) received_data<={received_data[46:0],MOSI};	
end

	
endmodule
