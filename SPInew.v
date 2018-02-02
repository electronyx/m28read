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


reg [47:0] output_reg;
//reg [11:0] bit_cntr=12'b000000000000;
//reg [3:0] short_counter=4'b0000;
reg [5:0] bit_cntr=6'b000000;
wire [5:0] new_counter;
assign new_counter = bit_cntr -6'b000001;



	always@(posedge CLK ) begin

		if(RST==1) begin
			stateSPI<=IDLE; 
         busy<=1'b0;		
         received_data<=16'h0000;	
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
					    stateSPI<=RECEIVE_LONG;
					    bit_cntr<=6'b101111;//47
						 //bit_cntr<=(6'b001000*InMsgByteCount)-1'b1;
						 long_dataIN<=0;
						 received_data<=received_data;
					 end
					 else begin
					    stateSPI<=RECEIVE;//transmission starts   
					    bit_cntr<=6'b001111; //16!
					    received_data<=16'h0000;	
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
					 else if(SPI_MSG_TYPE==LONG)      bit_cntr<=6'b001000*InMsgByteCount-1'b1;
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
					 received_data<=received_data;		
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
					    received_data<={32'h00000000,received_data[14:0],MOSI};
						 bit_cntr<=bit_cntr-1'b1;
					 end
	             stateSPI<=RECEIVE;
				 end
				 else begin
				    if(SCK_fallingedge)//sample the data from MOSI to register
					 begin
						 received_data<={32'h00000000,received_data[14:0],MOSI};
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
					 	 long_dataIN<={long_dataIN[46:0],MOSI};
					    bit_cntr<=bit_cntr-1'b1;
					 end begin
	                stateSPI<=RECEIVE_LONG;
						 long_dataIN<=long_dataIN;
					 end
				 end
				 else begin
				    if(SCK_fallingedge)//sample the data from MOSI to register
					 begin
						 long_dataIN<={long_dataIN[46:0],MOSI};
						 //bit_cntr<=bit_cntr-1'b1;
					    stateSPI<=IDLE;
						 received<=1'b1;
					 end
					 else begin
	                stateSPI<=RECEIVE_LONG;
						 long_dataIN<=long_dataIN;
					 end
					 
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
		/*
			case(stateSPI)
			IDLE: 
			  begin
				 if(CSEL_FallingEdge) begin //transmission starts - prepare
					 stateSPI<=RECEIVE;  
					 //bit_cntr<=4'b1111; //16!
					 if(SPI_MSG_TYPE     ==3'b000)  bit_cntr<=6'b001111;
                //else if(SPI_MSG_TYPE==3'b001)  bit_cntr<=12'b111111111111; // standard command is 2B -1 = 15 (4'b1111)
					 else if(SPI_MSG_TYPE==3'b010)  bit_cntr<=6'b010111; //send 3bytes = countr = 23
					 else if(SPI_MSG_TYPE==3'b011)  bit_cntr<=6'b101111; //send 6bytes
					 else if(SPI_MSG_TYPE==3'b100)  bit_cntr<=6'b000111; //send 1byte
					 else bit_cntr<=6'b001111;
					 //bit_cntr<=12'b000000001111;
 					 //bit_cntr<=4'b1111;
					 busy<=1'b1;	
					 rMISO<=1'b0;
					 received_data<=0;	
					 received<=1'b0;
				 end
				 else if(send_trigger&&!busy)
				 begin
				    //stateSPI<=SEND;//transmission starts   
					 stateSPI<=SEND;
					 if(SPI_MSG_TYPE     ==3'b000)  bit_cntr<=6'b001111;
                //else if(SPI_MSG_TYPE==3'b001)  bit_cntr<=12'b111111111111; // standard command is 2B -1 = 15 (4'b1111)
					 else if(SPI_MSG_TYPE==3'b010)  bit_cntr<=6'b010111; //send 3bytes = countr = 23
					 else if(SPI_MSG_TYPE==3'b011)  bit_cntr<=6'b101111; //send 6bytes
					 else if(SPI_MSG_TYPE==3'b100)  bit_cntr<=6'b000111; //send 1byte
					 else bit_cntr<=6'b001111;
					 busy<=1'b1;
					 output_reg<=output_data;
					 //rMISO<=1'b0;
					 received_data<=0;
					 received<=1'b0;
				 end
			end
            
			RECEIVE:
			  begin
            if(SCK_fallingedge) begin
				   received_data<={31'h00000000,received_data[14:0],MOSI}; 
				   if(bit_cntr!=6'b000000) begin
					   bit_cntr<=bit_cntr-1'b1;
						stateSPI<=RECEIVE;
						received<=1'b0;
					end
					else begin //LAST bit - sample the data from MOSI to register
					   stateSPI<=IDLE;
						bit_cntr<=bit_cntr;
						received<=1'b1;
						
					end
				 end
				 else begin
				    received_data<=received_data;
				    stateSPI<=RECEIVE;
					 bit_cntr<=bit_cntr;
					 received<=1'b0;
				 end	 
				 
			  end
			 SEND:
			   begin
				   if(bit_cntr!=6'b000000) begin
				      if(SCK_risingedge) begin
				         rMISO<=output_reg[bit_cntr];
				         //bit_cntr<=bit_cntr-1'b1; 
				      end
						if(SCK_fallingedge) bit_cntr<=bit_cntr-1'b1; 
						else bit_cntr<=bit_cntr; 
						stateSPI<=SEND;	
					end
					else begin
					   bit_cntr<=bit_cntr;
					   if(SCK_risingedge) begin
				         rMISO<=output_reg[bit_cntr];
				         //bit_cntr<=; 
							stateSPI<=IDLE;	
				      end
					    else stateSPI<=SEND;
					
					end
				end
				
			 endcase*/
		end

		
	end 
	
	
endmodule
