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
/*
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
parameter           SEND_LAST=5'b00101, RECEIVE_LAST=5'b00110, SEND_WAIT_CSEL=5'b00111;


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



reg [47:0] output_reg;
reg [5:0] bit_cntr;


reg rMISO;
assign MISO = CSEL? 1'b0 : output_reg[bit_cntr];



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
				else if(send_trigger&&!busy)next_stateSPI=SEND_WAIT_CSEL;
				else                        next_stateSPI=IDLE;
			 end 
		 RECEIVE:
			 begin
				 if(bit_cntr==4'b0000) next_stateSPI=RECEIVE_LAST;
				 else next_stateSPI=RECEIVE;
			 end
		 RECEIVE_LAST: 
		    if(received) next_stateSPI=IDLE;
			  else next_stateSPI=RECEIVE_LAST;
		 SEND_WAIT_CSEL:
		    if(CSEL) next_stateSPI=SEND;
			 else next_stateSPI=SEND_WAIT_CSEL;
		 SEND:
			 begin
			 	 if(bit_cntr==4'b0000)  next_stateSPI=SEND_LAST;
				 else next_stateSPI=SEND;
			 end  
       SEND_LAST:
		     if(sent&&CSEL) next_stateSPI=IDLE;
			  else next_stateSPI=SEND_LAST;
       default:
		    next_stateSPI=IDLE;
	 endcase
    
end

reg [5:0] new_bit_cntr;

reg [5:0] bit_counter_init;

always@(posedge CLK) begin
   if(RST) new_bit_cntr <=6'b000000;
   else if(!CSEL && SCK_risingedge) 
	   if(bit_cntr!=6'b000000) new_bit_cntr <= bit_cntr -6'b000001;
		else new_bit_cntr <= bit_cntr;
	else if(CSEL) new_bit_cntr <= bit_counter_init;
   //else      new_bit_cntr <= bit_counter_init;
end


//bitcounter handling value---------------------------------------
always@(posedge CLK) begin
   if(stateSPI==IDLE) begin
		//if(CSEL_FallingEdge&&!send_trigger) begin
		if(!send_trigger) begin
			if(LongMsgComing) bit_counter_init<=6'b001000*InMsgByteCount-1'b1;
			else bit_counter_init<=6'b001111;
		end
		else if(send_trigger&&!busy) begin
			if(SPI_MSG_TYPE     ==ONE_BY)    bit_counter_init<=6'b000111;
			else if(SPI_MSG_TYPE==STD_TWO_BY)bit_counter_init<=6'b001111; //send 2bytes = countr = 23
			else if(SPI_MSG_TYPE==THREE_BY)  bit_counter_init<=6'b010111; //send 3bytes
			else if(SPI_MSG_TYPE==SIX_BY)    bit_counter_init<=6'b101111; //send 6bytes
			else if(SPI_MSG_TYPE==LONG)      bit_counter_init<=6'b001000*InMsgByteCount-1'b1;
			else                             bit_counter_init<=6'b001111;
		end
		else bit_counter_init<=bit_counter_init;
	end
	else bit_counter_init<=bit_counter_init;
end
always@(posedge CLK) begin
   if(RST) bit_cntr<=6'b000000;
   else if(CSEL)  bit_cntr<=bit_counter_init;
	//else if(stateSPI==RECEIVE && SCK_fallingedge && bit_cntr!=6'b000000) bit_cntr<=new_bit_cntr;
	//else if(stateSPI==SEND && SCK_risingedge) bit_cntr<=new_bit_cntr;
	else if(stateSPI==RECEIVE &&SCK_fallingedge&& bit_cntr!=6'b000000) bit_cntr<=new_bit_cntr;
	else if(stateSPI==SEND && SCK_fallingedge && bit_cntr!=6'b000000) bit_cntr<=new_bit_cntr;
	else bit_cntr<=bit_cntr;
end

//--------------------RECEIVED flag
always@(posedge CLK) begin //should be clocked so the received will be 1 for whole CLK period??
	if(RST) received<=1'b0;
   else if(stateSPI==RECEIVE_LAST && bit_cntr==6'b000000 && SCK_fallingedge) received<=1'b1;
   else received<=1'b0; 
end

//--------------------SENT flag
always@(posedge CLK) begin //should be clocked so the received will be 1 for whole CLK period??
	if(RST) sent<=1'b0;
   else if(stateSPI==SEND_LAST && bit_cntr==6'b000000) sent<=1'b1;
   else sent<=1'b0; 
end
//--------------------BUSY flag
always@(posedge CLK) begin
   if(RST) busy<=1'b0;
   else if(stateSPI==RECEIVE || stateSPI==RECEIVE_LAST || stateSPI==SEND_WAIT_CSEL || stateSPI==SEND || stateSPI==SEND_LAST) busy<=1'b1;
	else busy<=1'b0;	
end

//-------------------- RECEIVE DATA
//always@(negedge SCK or posedge RST)begin
always@(posedge CLK)begin
   if(RST) received_data<=48'h000000000000;
   //if(stateSPI==RECEIVE) received_data<={32'h00000000,received_data[14:0],MOSI};
   else if((stateSPI==RECEIVE || stateSPI==RECEIVE_LAST) && SCK_fallingedge) received_data<={received_data[46:0],MOSI};	
end

always@(posedge CLK) begin
   if(RST) output_reg<=48'h000000000000;
   else if(CSEL) output_reg<=output_data;
	else output_reg<=output_reg;
end

endmodule	
*/






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
	output reg [63:0] long_dataIN,
	input [63:0] output_data,
	output reg received,
	input [3:0] InMsgByteCount,
	input LongMsgComing,
	input [2:0] SPI_MSG_TYPE
	);

//MSG TYPE
parameter NO_BY=3'b000, ONE_BY=3'b001, STD_TWO_BY=3'b010, THREE_BY= 3'b011 ,SIX_BY=3'b110, LONG = 3'b111 ;

parameter           IDLE=5'b00000,  RECEIVE=5'b00001,   SEND=5'b00010, WAIT_FOR_START=5'b00011, RECEIVE_LONG=5'b00100;
	 
reg [2:0] stateSPI =IDLE;

//start message
reg [2:0] SSELr;  
always @(posedge CLK) SSELr <= {SSELr[1:0], CSEL};
wire CSEL_FallingEdge = (SSELr[2:1]==2'b10); //message starts

//bit sampling on SCK falling edge
reg [2:0] SCKr;  
always @(posedge CLK) SCKr <= {SCKr[1:0], SCK};
wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

reg rMISO;
assign MISO = CSEL? 1'b0 : rMISO;


reg [63:0] output_reg;
//reg [11:0] bit_cntr=12'b000000000000;
//reg [3:0] short_counter=4'b0000;
reg [5:0] bit_cntr=6'b000000;
wire [5:0] new_counter;
assign new_counter = bit_cntr -6'b000001;



	always@(posedge CLK ) begin

		if(RST==1) begin
			stateSPI<=IDLE; 
         busy<=1'b0;		
         received_data<=48'h000000000000;	
         received<=1'b0;
			output_reg<=48'h000000000000;	
			//output_reg<=0;
         bit_cntr<=6'b000000;	
         long_dataIN<=0;			
		end
		else 
		begin
		
      case(stateSPI)
			IDLE: 
			  begin
				 if(CSEL_FallingEdge&&!send_trigger) begin
					 if(LongMsgComing) begin
					    //bit_cntr<=6'b101111;//47
					    stateSPI<=RECEIVE_LONG;
						 bit_cntr<=(InMsgByteCount<<3)-1'b1;
						 long_dataIN<=0;
					 end
					 else begin
					    stateSPI<=RECEIVE;//transmission starts   
					    bit_cntr<=6'b001111; //16!
					    received_data<=48'h0000;	
					 end
					 busy<=1'b1;	
					 received<=1'b0;
				 end
				 else if(send_trigger&&!busy)
				 begin
				    stateSPI<=SEND;//transmission starts 
					 if(SPI_MSG_TYPE     ==ONE_BY)    bit_cntr<=6'b000111;
                //else if(SPI_MSG_TYPE==3'b001)  bit_cntr<=12'b111111111111; // standard command is 2B -1 = 15 (4'b1111)
					 else if(SPI_MSG_TYPE==STD_TWO_BY)bit_cntr<=6'b001111; //send 2bytes = countr = 23
					 else if(SPI_MSG_TYPE==THREE_BY)  bit_cntr<=6'b010111; //send 3bytes
					 else if(SPI_MSG_TYPE==SIX_BY)    bit_cntr<=6'b101111; //send 6bytes
					 else if(SPI_MSG_TYPE==LONG)      bit_cntr<=(InMsgByteCount<<8)-1'b1;
					 else                             bit_cntr<=6'b001111;
					 busy<=1'b1;
					 output_reg<=output_data;
					 //rMISO<=0;
					 received_data<=48'h000000000000;
					 received<=1'b0;
				 end
				 else begin
			       stateSPI<=IDLE;
					 bit_cntr<=6'b000000;
					 busy<=1'b0;
					 //rMISO<=0;
					 received<=1'b0;					 
				    output_reg<=48'h000000000000;	
			       //output_reg<=0;
         
				 end
			  end
			RECEIVE:
			  begin
				 if(bit_cntr>6'b000000) begin
					 if(SCK_fallingedge)//sample the data from MOSI to register
					 begin
					    received_data<={received_data[46:0],MOSI};
						 bit_cntr<=bit_cntr-1'b1;
					 end
	             stateSPI<=RECEIVE;
				 end
				 else begin
				    if(SCK_fallingedge)//sample last element from MOSI to register
					 begin
						 received_data<={received_data[46:0],MOSI};
						 //bit_cntr<=bit_cntr-1'b1;
					    stateSPI<=IDLE;
						 received<=1'b1;
					 end
					 else stateSPI<=RECEIVE;
					 
				 end
			  end
			 RECEIVE_LONG:
			  begin
				 if(bit_cntr>6'b000000) begin
					 if(SCK_fallingedge)//sample the data from MOSI to register
					 begin
					 	 long_dataIN<={long_dataIN[62:0],MOSI};
					    bit_cntr<=bit_cntr-1'b1;
					 end
					 stateSPI<=RECEIVE_LONG;
				 end
				 else begin
				    if(SCK_fallingedge)//sample the last data from MOSI to register
					 begin
						 long_dataIN<={long_dataIN[62:0],MOSI};
						 //bit_cntr<=bit_cntr-1'b1;
					    stateSPI<=IDLE;
						 received<=1'b1;
					 end
					 else stateSPI<=RECEIVE_LONG;			 
				 end
			  end 
			 SEND:
			   begin
				  
				  if(bit_cntr>6'b000000) begin
				 	 
					 if(SCK_risingedge)//send the data to  MISO 
					 begin
					    rMISO<=output_reg[bit_cntr];
						 //bit_cntr<=bit_cntr-1'b1;
						 bit_cntr<=new_counter;
					 end
					 else begin 
					    bit_cntr<=bit_cntr;
						 rMISO<=rMISO;
					 end
	             stateSPI<=SEND;
				  end
				  else begin
				    bit_cntr<=bit_cntr;
				    if(SCK_risingedge)//send the last bit 
					 begin
						 rMISO<=output_reg[bit_cntr];
						 stateSPI<=IDLE;
					 end
					 else begin 
					    stateSPI<=SEND;
						 rMISO<=rMISO;
					 end
				  end
				end
			 endcase

		end

		
	end 
	
	
endmodule