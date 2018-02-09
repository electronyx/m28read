`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:21:45 01/18/2018 
// Design Name: 
// Module Name:    CommandDecoder 
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


// - 17.XI - MK RESET ADDED
module CommandDecoder(CLK,mem_clk,
                      CMD_RST,SCK, MISO, MOSI,CSEL,           //SPI_inout
                      MEM_CS,SI_IO0,SO_IO1,WP_IO2,HOLD_IO3 //SPI_memory
);                            
                      

// -----------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------------------


    input CLK;
	 
    input CMD_RST;

//SPI
    input SCK;
    input MOSI;
    input CSEL;
    output MISO;

//MEMORY SPI
    output mem_clk;
	 output MEM_CS;
	 inout SI_IO0;
	 inout SO_IO1;
	 inout WP_IO2;
	 inout HOLD_IO3;

//Internal registers
reg [7:0] REG0;
reg [7:0] REG1;    

//reception registers
reg [3:0] CMD;
reg [3:0] ADDR;
reg [7:0] VAL;


//SPI communication
//wire [2047:0] recv_data;
wire [47:0] recv_data;
//reg [2047:0] TEST_reg ;
//reg [2047:0] send_data;
reg [127:0] send_data;
wire SPI_busy;
reg SPI_trigger;

parameter NO_BY=3'b000, ONE_BY=3'b001, STD_TWO_BY=3'b010, THREE_BY= 3'b011 ,SIX_BY=3'b110, LONG = 3'b111 ;

reg [2:0] SPI_MSG_TYPE=NO_BY;
reg [2:0] MEM_MSG_TYPE=NO_BY;

wire [6:0]InMsgByteCount;
reg LongMsgComing;

wire [127:0] long_dataSPI;
wire sent;
	SPInew SPIRaspi (
		.CLK(CLK), 
		.RST(CMD_RST), 
		.SCK(SCK), 
		.MOSI(MOSI), 
		.CSEL(CSEL), 
		.MISO(MISO), 
		.send_trigger(SPI_trigger), 
		.busy(SPI_busy), 
		.received_data(recv_data),
		.output_data(send_data),
		.received(SPIreceived),
		.SPI_MSG_TYPE(SPI_MSG_TYPE),
		.InMsgByteCount(InMsgByteCount),
	   .LongMsgComing(LongMsgComing),
		.long_dataIN(long_dataSPI)
	);
   wire [47:0] MEMDATA;
   reg [7:0] MEMCMD;
   reg [23:0] MEMADDR;		// 3B address
	wire [47:0] MEMVAL; //should be a page - 256B
	//reg [8:0] mem_wr_count;
	//reg [8:0] mem_rd_count;
	reg MEMTRIG;
	reg MEMQUAD; 
	wire MEM_busy;
   memory_controller memory_controller(.CLK(CLK),.mem_clk(mem_clk),.oCS(MEM_CS),.SI_IO0(SI_IO0),.SO_IO1(SO_IO1),.WP_IO2(WP_IO2),.HOLD_IO3(HOLD_IO3),
     .reset(CMD_RST),.MEMDATA(MEMDATA),.MEMCMD(MEMCMD),.MEMADDR(MEMADDR),
	  .MEMVAL(MEMVAL),.MEMTRIG(MEMTRIG),.MEMQUAD(MEMQUAD),.MEM_CTRL_busy(MEM_busy));

    
// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
// -------------------------------------- DECODE COMMANDS FROM SPI-----------------------------------------  
// --------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------- 

parameter             IDLE=6'b000000,     DECODE=6'b000001,    SET_REGISTERS=6'b000010,   GET_REGISTERS=6'b000011;
parameter            RESET=6'b000100,    SEND_ID=6'b000101,   SPI_TR_WAIT  =6'b000110;

//MEMORY states                                        
parameter       MEM_WRITE =6'b001000, MEM_READ     =6'b001001,    MEM_WAIT =6'b001010; 
                 //9F                
parameter       GET_MEM_ID=6'b001011, GET_MEM_STREG=6'b001100;

parameter RECEIVE_LONG_MSG=6'b001101, LONG_MSG_WAIT=6'b001110, MEM_ADRR_SET=6'b001111, MEM_WREN=6'b010000;;
reg [4:0] CMDstate;
reg [4:0] next_CMDstate;
	

//zrobic kolejke wysylanych komend po SPI ?


integer i;

// ------------------------------------- FSM
//
//state switching
always @ (posedge CLK)
begin
	if (CMD_RST)
		CMDstate <= IDLE;
	else
		CMDstate <= next_CMDstate;
end
//state transition declaration
always@(*) begin
   next_CMDstate=CMDstate;
	case(CMDstate) 
	   IDLE:
		   if(SPIreceived) next_CMDstate=DECODE;
      DECODE:
		begin
         case(CMD)		
				4'b0010: next_CMDstate=SET_REGISTERS;
				4'b0011: next_CMDstate=GET_REGISTERS;
				4'b0100: next_CMDstate=RESET;
				4'b0110: next_CMDstate=SEND_ID;
				4'b0111: next_CMDstate=GET_MEM_ID;   //get the id of the memory = 0x1, 0x20, 0x18, 0x4D, 0x1, 0x80
				4'b1000: next_CMDstate=GET_MEM_STREG;//0x80, 0x81 get memory status registers, addr0 = RDSR1 , addr1= RDSR2 
				4'b1001: next_CMDstate=RECEIVE_LONG_MSG;
				4'b1010: next_CMDstate=MEM_WRITE;
				4'b1011: next_CMDstate=MEM_ADRR_SET;
				4'b1100: next_CMDstate=MEM_READ;
				4'b1101: next_CMDstate=MEM_WREN;
				default: next_CMDstate=IDLE;
			endcase
		end
		SET_REGISTERS:
			next_CMDstate=IDLE;
		GET_REGISTERS:
	      next_CMDstate=SPI_TR_WAIT;
		RESET:
		   next_CMDstate=IDLE;
		SEND_ID:
		   next_CMDstate=SPI_TR_WAIT;
		SPI_TR_WAIT:
      begin
		   if(SPI_trigger && !SPI_busy)       next_CMDstate = SPI_TR_WAIT;//not yet registered
			//trigger registered by SPI controller and we can turn off the SPI_trigger flag
			else if(SPI_trigger && SPI_busy)   next_CMDstate = SPI_TR_WAIT;
			//memory busy flag turn of.. we're waiting
			else if (!SPI_trigger && SPI_busy) next_CMDstate = SPI_TR_WAIT;
			//flag was off and memory has finished we go to IDLE
			else if (!SPI_trigger && !SPI_busy)next_CMDstate = IDLE;
		end
		MEM_WRITE:
		   next_CMDstate = MEM_WAIT;
	   MEM_READ:
		   next_CMDstate = MEM_WAIT;
		MEM_WREN:
		   next_CMDstate = MEM_WAIT;
		MEM_WAIT:
		begin
		   if(!MEM_busy&& MEMTRIG)      next_CMDstate = MEM_WAIT;
		   //the controller responded, clear the MEMTRIG and wait for completion of memory operation
		   else if( MEM_busy&& MEMTRIG) next_CMDstate = MEM_WAIT;
		   //the trigger was cleared but the memory is still busy
         else if( MEM_busy&&!MEMTRIG) next_CMDstate = MEM_WAIT; 	 
		   //the trigger cleared and memory operation compleated
		   else if(!MEM_busy&&!MEMTRIG) begin
		      //wait for Raspi SPI to be free
		      if(SPI_busy)              next_CMDstate = MEM_WAIT;
		      else begin
			      //it's free let's send the data to Raspi SPI and go to SPI wait state
			      if(MEM_MSG_TYPE!=NO_BY) next_CMDstate = SPI_TR_WAIT;
				   else next_CMDstate = IDLE; //nothing to send
				end
		   end
		end
		MEM_ADRR_SET:
		   next_CMDstate=IDLE;
		GET_MEM_ID:
		   next_CMDstate = MEM_WAIT;
		GET_MEM_STREG:
		   next_CMDstate = MEM_WAIT;
		RECEIVE_LONG_MSG:
		   next_CMDstate=LONG_MSG_WAIT;
		LONG_MSG_WAIT:
		   if(LongMsgComing&&!SPI_busy)      next_CMDstate=LONG_MSG_WAIT;
			else if(LongMsgComing&&SPI_busy)  next_CMDstate=LONG_MSG_WAIT;
			else if(!LongMsgComing&&SPI_busy) next_CMDstate=LONG_MSG_WAIT;
			else if(!LongMsgComing&&!SPI_busy)next_CMDstate=IDLE;
			//else if(!LongMsgComing&&!SPI_busy)next_CMDstate=SPI_TR_WAIT; //send data via SPI -- just for echo test 
		default:
		   next_CMDstate=IDLE;
		endcase
end

//--------------------------------GET the decoded message
always@(posedge CLK) begin
   if(CMD_RST) begin
	   CMD <=4'b0000;
      ADDR<=4'b0000;
      VAL <=8'h00;
	end
   else if(CMDstate==IDLE && SPIreceived) begin
	   CMD  <= recv_data[15:12]; //copy the message to registers; in case there is a new one during decoding we don't lose the info.
		ADDR <= recv_data[11:8];
		VAL  <= recv_data[7:0]; 
	end
	else begin
	   CMD <=CMD;
      ADDR<=ADDR;
      VAL <=VAL;
	end
end
//-------------------------------
//--------------------------------send_data handle
always@(posedge CLK) begin
   if(CMD_RST) begin
	    send_data<={128{1'b0}};
	end
	//else if(CMDstate==IDLE) send_data<={512{1'b0}};
	else if(CMDstate==GET_REGISTERS && ADDR==4'b0001) send_data<={{112{1'b0}},CMD[3:0],ADDR[3:0],REG0[7:0]};//send the data;
   else if(CMDstate==GET_REGISTERS && ADDR==4'b0010) send_data<={{112{1'b0}},CMD[3:0],ADDR[3:0],REG1[7:0]};
	else if(CMDstate==LONG_MSG_WAIT&& !LongMsgComing&&!SPI_busy) send_data<=long_dataSPI;//just for echo test
	else if(CMDstate==SEND_ID)                        send_data<={{112{1'b0}},16'b0111100101110101};
	//                            mem val. received, trigger off, spi not busy and there is something to send..
	else if(CMDstate==MEM_WAIT && !MEM_busy&&!MEMTRIG &&!SPI_busy && MEM_MSG_TYPE!=NO_BY) send_data<={{80{1'b0}},MEMDATA[47:0]};
	
end
//-------------------------------
//--------------------------------Internal test registers
always@(posedge CLK) begin
   if(CMD_RST) begin
	   REG0[7:0]<=8'h12;
		REG1[7:0]<=8'h34;
	end
	else if (CMDstate==SET_REGISTERS) begin
	   REG0[7:0]<=VAL[7:0];
	   REG1[7:0]<=VAL[7:0];
	end
end

//--------------------------------------------------------------
//--------------------------------SPI---------------------------
//--------------------------------------------------------------

//SPI:trigger handling
always@(posedge CLK) begin
    if(CMD_RST || CMDstate==IDLE) SPI_trigger<=1'b0;
	 else if(CMDstate==GET_REGISTERS || CMDstate==SEND_ID)                     SPI_trigger<=1'b1;
	 //else if(CMDstate==LONG_MSG_WAIT && !LongMsgComing&&!SPI_busy)             SPI_trigger<=1'b1;//just for echo test
	 else if(CMDstate==MEM_WAIT && !MEM_busy&&!MEMTRIG && MEM_MSG_TYPE!=NO_BY) SPI_trigger<=1'b1;
	 else if(CMDstate==SPI_TR_WAIT) begin
	   if(SPI_trigger && !SPI_busy)       SPI_trigger<=1'b1; //keep the flag high
		//trigger registered by SPI controller and we can turn off the SPI_trigger flag
		else if(SPI_trigger && SPI_busy)   SPI_trigger<=1'b0;
		//memory busy flag turn of.. we're waiting
	   else if (!SPI_trigger && SPI_busy) SPI_trigger<=1'b0;
      //flag was off and memory has finished we go to IDLE
		else if (!SPI_trigger && !SPI_busy)SPI_trigger<=1'b0;
    end
	 else SPI_trigger<=SPI_trigger;
end

//SPI: msg type
always@(posedge CLK) begin
   if(CMD_RST) SPI_MSG_TYPE<=STD_TWO_BY;
	else if(CMDstate==GET_REGISTERS || CMDstate==SEND_ID) SPI_MSG_TYPE<=STD_TWO_BY;
	else if(CMDstate==LONG_MSG_WAIT) SPI_MSG_TYPE<=LONG;
	else if(CMDstate==GET_MEM_ID) SPI_MSG_TYPE<=SIX_BY;
	else if(CMDstate==MEM_WRITE) SPI_MSG_TYPE<=NO_BY;
	else if(CMDstate==MEM_WREN) SPI_MSG_TYPE<=NO_BY;
	else if(CMDstate==MEM_READ) SPI_MSG_TYPE<=LONG;
	else if(CMDstate==GET_MEM_STREG) begin
		if(ADDR==4'b0000) SPI_MSG_TYPE<=ONE_BY; 
		else if(ADDR==4'b0001) SPI_MSG_TYPE<=ONE_BY;
		else if(ADDR==4'b0010) SPI_MSG_TYPE<=ONE_BY;
		else if(ADDR==4'b0011) SPI_MSG_TYPE<=ONE_BY;
		else if(ADDR==4'b0100) SPI_MSG_TYPE<=NO_BY;
	end
end

//SPI: long message counter
// if(CMD_RST) InMsgByteCount=0 else if (CMDstate==RECEIVE_LONG_MSG) InMsgByteCount=ADDR;
assign InMsgByteCount= CMD_RST?6'b00000:((CMDstate==MEM_READ||CMDstate==RECEIVE_LONG_MSG||CMDstate==LONG_MSG_WAIT||SPI_TR_WAIT)?{VAL[5:0]}:6'b00000);

//SPI: long message coming flag
always@(posedge CLK) begin
   if(CMD_RST) LongMsgComing <=1'b0;
	else if(CMDstate==RECEIVE_LONG_MSG) LongMsgComing <=1'b1;
   else if(CMDstate==LONG_MSG_WAIT && LongMsgComing&&!SPI_busy) LongMsgComing<=1'b1;
	else if(CMDstate==LONG_MSG_WAIT && LongMsgComing&& SPI_busy) LongMsgComing<=1'b0;
	else LongMsgComing<=1'b0;
end

//--------------------------------------------------------------
//--------------------------------MEMORY------------------------
//--------------------------------------------------------------
//MEM:command, address, value

always@(posedge CLK)begin
   if(CMD_RST || CMDstate==IDLE) begin
	   MEMCMD <=8'b00;
	   //MEMVAL <={512{1'b0}}; 
	end
	
	else if(CMDstate==GET_MEM_ID)               //simplify and make one command to access memory!!
	   MEMCMD<=8'h9F; // MEM_ID	              //simplify and make one command to access memory!!
	else if(CMDstate==GET_MEM_STREG) begin
		if(ADDR==4'b0000)      MEMCMD<=8'h05; //SR1 status reg1
		else if(ADDR==4'b0001) MEMCMD<=8'h07; //SR2 status reg2
		else if(ADDR==4'b0010) MEMCMD<=8'hAB; //RES - electronic signature
		else if(ADDR==4'b0011) MEMCMD<=8'h35; //CR1
		else if(ADDR==4'b0100) MEMCMD<=8'hC7; //
   end
	else if(CMDstate==MEM_WRITE) begin
	   MEMCMD<=8'h11; //mem_wr command for memory controller
	  // MEMVAL <=send_data;
	end
	else if(CMDstate==MEM_READ) begin
	   MEMCMD<=8'h0B; //mem_wr command for memory controller
	end 
	else if(CMDstate==MEM_WREN) MEMCMD<=8'h06;//
end

//MEM val -saving space...
assign MEMVAL = (CMD_RST)?{48{1'b0}}:send_data[47:0];

//assign MEMTRIG = CMD_RST?1'b0:(CMDstate==GET_MEM_ID || CMDstate==GET_MEM_STREG || ((CMDstate==MEM_WAIT )&& !MEM_busy&& MEMTRIG )||
//                               CMDstate==MEM_WRITE  || CMDstate==MEM_READ)?1'b1:1'b0;
                                
//MEM: trigger
always@(posedge CLK) begin
   if(CMD_RST || CMDstate==IDLE)                                MEMTRIG<=1'b0;
   else if(CMDstate==GET_MEM_ID || CMDstate==GET_MEM_STREG)     MEMTRIG<=1'b1;
   else if(CMDstate==MEM_WAIT && !MEM_busy&& MEMTRIG) MEMTRIG<=1'b1; //keep MEMTRIG untill the MEMbusy goes high
	else if(CMDstate==MEM_WRITE) MEMTRIG<=1'b1;
	else if(CMDstate==MEM_READ) MEMTRIG<=1'b1;
	else if(CMDstate==MEM_WREN) MEMTRIG<=1'b1;
		//else if(CMDstate==MEM_WAIT && MEM_busy && MEMTRIG)	MEMTRIG=1'b0; //MEMbusy gone high, clear MEMTRIG
	else  MEMTRIG<=1'b0;
end
	
//MEM:quad
always@(posedge CLK) begin
   if(CMD_RST) MEMQUAD<=1'b0;
	else if(CMDstate==IDLE) MEMQUAD<=1'b0;

end	

//MEM:MSG type	
always@(posedge CLK) begin
   if(CMD_RST) MEM_MSG_TYPE<=NO_BY;
	else if(CMDstate==GET_MEM_ID) MEM_MSG_TYPE<=SIX_BY;
	else if(CMDstate==GET_MEM_STREG && (ADDR==4'b0000 || ADDR==4'b0001||ADDR==4'b0010))MEM_MSG_TYPE<=ONE_BY; 
   else if(CMDstate==GET_MEM_STREG &&(ADDR==4'b0011 ||ADDR==4'b0100)) MEM_MSG_TYPE<=NO_BY; 
   else if(CMDstate==MEM_WRITE) MEM_MSG_TYPE<=NO_BY; 
	else if(CMDstate==MEM_READ) MEM_MSG_TYPE<=LONG; 
	else if(CMDstate==MEM_WREN) MEM_MSG_TYPE<=NO_BY; 
	
end
//MEM:addr set
always@(posedge CLK) begin
   if(CMD_RST) MEMADDR<=24'h000000;
	else if(CMDstate==MEM_ADRR_SET && ADDR == 4'b0000) MEMADDR[7:0]  <= VAL[7:0];  
	else if(CMDstate==MEM_ADRR_SET && ADDR == 4'b0001) MEMADDR[15:8] <= VAL[7:0];  
	else if(CMDstate==MEM_ADRR_SET && ADDR == 4'b0010) MEMADDR[23:16]<= VAL[7:0];  
end
/*
//MEM: wr_count
always@(posedge CLK) begin
   if(CMD_RST) mem_wr_count<=9'h040;
   else if(CMDstate==IDLE) mem_wr_count<=9'h040;
end
//MEM: rd_count
always@(posedge CLK) begin
   if(CMD_RST) mem_rd_count<=9'h040;
   else if(CMDstate==IDLE) mem_rd_count<=9'h040;
end*/
endmodule



