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
module CommandDecoder(CLK,
                      CMD_RST,SCK, MISO, MOSI,CSEL,           //SPI_inout
                      MEM_SCK,MEM_CS,SI_IO0,SO_IO1,WP_IO2,HOLD_IO3 //SPI_memory
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
    input MEM_SCK;
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
reg [63:0] send_data;
wire SPI_busy;
reg SPI_trigger;

parameter NO_BY=3'b000, ONE_BY=3'b001, STD_TWO_BY=3'b010, THREE_BY= 3'b011 ,SIX_BY=3'b110, LONG = 3'b111 ;

reg [2:0] SPI_MSG_TYPE=NO_BY;
reg [2:0] MEM_MSG_TYPE=NO_BY;

wire [3:0]InMsgByteCount;
reg LongMsgComing;

wire [63:0] long_dataSPI;
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
	reg [23:0] MEMVAL; //should be a page - 256B
	
	reg MEMTRIG;
	reg MEMQUAD; 
	wire MEM_busy;
 //  memory_controller memory_controller(.CLK(CLK),.SCLK(MEM_SCK),.oCS(MEM_CS),.SI_IO0(SI_IO0),.SO_IO1(SO_IO1),.WP_IO2(WP_IO2),.HOLD_IO3(HOLD_IO3),
	//.reset(CMD_RST),.MEMDATA(MEMDATA),.MEMCMD(MEMCMD),.MEMADDR(MEMADDR),.MEMVAL(MEMVAL),.MEMTRIG(MEMTRIG),.MEMQUAD(MEMQUAD),.MEM_CTRL_busy(MEM_busy));

    
// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
// -------------------------------------- DECODE COMMANDS FROM SPI-----------------------------------------  
// --------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------- 

parameter             IDLE=5'b00000,     DECODE=5'b00001,    SET_REGISTERS=5'b00010,   GET_REGISTERS=5'b00011;
parameter            RESET=5'b00100,    SEND_ID=5'b00101,   SPI_TR_WAIT  =5'b00110;

//MEMORY states                                        
parameter       WRITE_MEM =5'b01000, READ_MEM=5'b01001, MEM_WAIT =5'b01010; 
                 //9F                
parameter       GET_MEM_ID=5'b01011, GET_MEM_STREG=5'b01100;

parameter       RECEIVE_LONG_MSG=5'b01101, LONG_MSG_WAIT=5'b01110;
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
		//WRITE_MEM:
		//READ_MEM:
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
			else if(!LongMsgComing&&!SPI_busy)next_CMDstate=SPI_TR_WAIT; //send data via SPI
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
	    send_data<=0;
	end
	else if(CMDstate==IDLE) send_data<=63'h0000000000000000;
	else if(CMDstate==GET_REGISTERS && ADDR==4'b0001) send_data<={48'h000000000000,CMD[3:0],ADDR[3:0],REG0[7:0]};//send the data;
   else if(CMDstate==GET_REGISTERS && ADDR==4'b0010) send_data<={48'h000000000000,CMD[3:0],ADDR[3:0],REG1[7:0]};
	else if(CMDstate==LONG_MSG_WAIT&& !LongMsgComing&&!SPI_busy) send_data<=long_dataSPI;
	else if(CMDstate==SEND_ID)                        send_data<={48'h000000000000,16'b0111100101110101};
	//                            mem val. received, trigger off, spi not busy and there is something to send..
	else if(CMDstate==MEM_WAIT && !MEM_busy&&!MEMTRIG &&!SPI_busy && MEM_MSG_TYPE!=NO_BY) send_data<={16'h0000,MEMDATA[47:0]};
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
	 else if(CMDstate==LONG_MSG_WAIT && !LongMsgComing&&!SPI_busy)             SPI_trigger<=1'b1;
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
	else if(LONG_MSG_WAIT) SPI_MSG_TYPE<=LONG;
   else if(CMDstate==GET_MEM_STREG) begin
		if(ADDR==4'b0000) SPI_MSG_TYPE<=ONE_BY; 
		else if(ADDR==4'b0001) SPI_MSG_TYPE<=ONE_BY;
		else if(ADDR==4'b0010) SPI_MSG_TYPE<=ONE_BY;
		else if(ADDR==4'b0011) SPI_MSG_TYPE<=NO_BY;
		else if(ADDR==4'b0100) SPI_MSG_TYPE<=NO_BY;
	end
	else SPI_MSG_TYPE=SPI_MSG_TYPE;
end

//SPI: long message counter
// if(CMD_RST) InMsgByteCount=0 else if (CMDstate==RECEIVE_LONG_MSG) InMsgByteCount=ADDR;
assign InMsgByteCount= CMD_RST?4'b0000:((CMDstate==RECEIVE_LONG_MSG||CMDstate==LONG_MSG_WAIT)?ADDR:4'b0000);

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

always@(*)begin
   if(CMD_RST || CMDstate==IDLE) begin
	   MEMCMD =8'b00;
      MEMADDR=24'b000000;		// 3B address
	   MEMVAL =24'b000000; 
	end
	
	else if(CMDstate==GET_MEM_ID)               //simplify and make one command to access memory!!
	   MEMCMD=8'h9F; // MEM_ID	              //simplify and make one command to access memory!!
	else if(CMDstate==GET_MEM_STREG) begin
		if(ADDR==4'b0000)      MEMCMD=8'h05; //SR1 status reg1
		else if(ADDR==4'b0001) MEMCMD=8'h07; //SR2 status reg2
		else if(ADDR==4'b0010) MEMCMD=8'hAB; //RES - electronic signature
		else if(ADDR==4'b0011) MEMCMD=8'h06; //WREN
		else if(ADDR==4'b0100) MEMCMD=8'hC7; //bulk erase - all to 1
   end
end

//MEM: trigger
always@(*) begin
   if(CMD_RST || CMDstate==IDLE)                                MEMTRIG=1'b0;
   else if(CMDstate==GET_MEM_ID || CMDstate==GET_MEM_STREG)     MEMTRIG=1'b1;
   else if(CMDstate==MEM_WAIT && !MEM_busy&& MEMTRIG) MEMTRIG=1'b1; //keep MEMTRIG untill the MEMbusy goes high
	//else if(CMDstate==MEM_WAIT && MEM_busy && MEMTRIG)	MEMTRIG=1'b0; //MEMbusy gone high, clear MEMTRIG
	else  MEMTRIG=1'b0;
end
	
endmodule
/*


always@(posedge CLK )
begin

// ------------------------------------------- ASYNC RESET  -----------------------
  if(CMD_RST==1)
  begin
      CMD <=4'b0000;
      ADDR<=4'b0000;
      VAL <=8'h00;
      
		//send_data<=48'h000000000000; 
      send_data<=0;
		
		CMDstate<=IDLE;
		SPI_trigger <= 1'b0;
		SPI_MSG_TYPE<=3'b000;

	//MEMORY
	   
      MEMCMD <=8'b00;
      MEMADDR<=24'b000000;		// 3B address
	   MEMVAL <=24'b000000; //should be a page - 256B
	
	   MEMTRIG<=1'b0;
	   MEMQUAD<=1'b0;
		
	//long data
	  InMsgByteCount<=4'b000;
     LongMsgComing<=1'b0;
  end  
// -------------------------------------------/ ASYNC RESET  -----------------------

// ------------------------------------------- STATE MACHINE -----------------------
  else 
  begin
    if(CMDstate==IDLE)
    begin 
		 if(SPIreceived) begin
			CMD  <= recv_data[15:12]; //copy the message to registers; in case there is a new one during decoding we don't lose the info.
			ADDR <= recv_data[11:8];
			VAL  <= recv_data[7:0]; 
			CMDstate<=DECODE;
		 end 
		 else begin
          SPI_trigger <= 1'b0;
		    SPI_MSG_TYPE<=SPI_MSG_TYPE;

	       //MEMORY
	       MEMCMD <=8'b00;
          MEMADDR<=24'b000000;		// 3B address
	       MEMVAL <=24'b000000; //should be a page - 256B
	
	       MEMTRIG<=1'b0;
	       MEMQUAD<=1'b0;
		
			
			 CMD <=4'b0000; //clear between
			 ADDR<=4'b0000;
			 VAL <=8'h00; 
          SPI_MSG_TYPE<=STD_TWO_BY;
			 //send_data<=48'h000000000000;
			 send_data<=0;
			 CMDstate<=IDLE;
		 end
    end
// ------------------------------------------- DECODING COMMAND -----------------------
    else if (CMDstate==DECODE) begin
        case(CMD)
				4'b0010: CMDstate<=SET_REGISTERS;
				4'b0011: CMDstate<=GET_REGISTERS;
				4'b0100: CMDstate<=RESET;
				4'b0110: CMDstate<=SEND_ID;
				4'b0111: CMDstate<=GET_MEM_ID;   //get the id of the memory = 0x1, 0x20, 0x18, 0x4D, 0x1, 0x80
				4'b1000: CMDstate<=GET_MEM_STREG;//0x80, 0x81 get memory status registers, addr0 = RDSR1 , addr1= RDSR2 
				4'b1001: CMDstate<=RECEIVE_LONG_MSG;
				default: CMDstate<=IDLE;   
			endcase	
    end
// ------------------------------------------- WAIT FOR SPI TR to finish ---------------------
	 else if(CMDstate==SPI_TR_WAIT)
	 begin
	 
	   if(SPI_trigger && !SPI_busy) begin
		   CMDstate <= SPI_TR_WAIT;//not yet registered
         SPI_trigger<=1'b1; //keep the flag high
		end
		else if(SPI_trigger && SPI_busy) begin //trigger registered by SPI controller and we can turn off the SPI_trigger flag
		   CMDstate <= SPI_TR_WAIT;
			SPI_trigger<=1'b0;
		end
		else if (!SPI_trigger && SPI_busy) begin //memory busy flag turn of.. we're waiting
			CMDstate <= SPI_TR_WAIT;
			SPI_trigger<=1'b0;
		end
		else if (!SPI_trigger && !SPI_busy)begin //flag was off and memory has finished we go to IDLE
		   CMDstate<= IDLE;
			SPI_trigger<=1'b0;
		end
	 end
	 
// ------------------------------------------- SET INTERNAL REGISTERS ---------------------
    else if (CMDstate==SET_REGISTERS)
    begin
    //decode the address
           if(ADDR==4'b0001) REG0[7:0]<=VAL[7:0];
      else if(ADDR==4'b0010) REG1[7:0]<=VAL[7:0];
      CMDstate<=IDLE;
    //
    end
// -------------------------------------------GET DAQ REGISTERS -----------------------------
    else if (CMDstate==GET_REGISTERS)
    begin
      //decode the address
      if(ADDR==4'b0001) begin
		   send_data<={32'h00000000,CMD[3:0],ADDR[3:0],REG0[7:0]};//send the data;
   	end		  
      else if(ADDR==4'b0010) begin
 	      send_data<={32'h00000000,CMD[3:0],ADDR[3:0],REG1[7:0]};
      end	
      else begin
         send_data<={32'h00000000,CMD[3:0],12'h123};
      end		
		SPI_trigger<=1'b1;
		SPI_MSG_TYPE<=STD_TWO_BY;
		CMDstate<=SPI_TR_WAIT;
    end
	 	 
// -------------------------------------------LONG MSG COMMING ----------------------------------
    else if(CMDstate==RECEIVE_LONG_MSG)
	 begin
	    InMsgByteCount<=ADDR;
       LongMsgComing <=1'b1;
	    CMDstate<=LONG_MSG_WAIT;
	 end
	 

// -------------------------------------------LONG MSG WAIT ----------------------------------
	 else if(CMDstate==LONG_MSG_WAIT) 
	 begin
	 
	    if(LongMsgComing&&!SPI_busy)  begin
		    CMDstate<=LONG_MSG_WAIT;
			 LongMsgComing<=1'b1;
		 end
		 else if(LongMsgComing&&SPI_busy) begin
		    CMDstate<=LONG_MSG_WAIT;
			 LongMsgComing<=1'b0;
		 end
		 else if(!LongMsgComing&&SPI_busy) begin
		    CMDstate<=LONG_MSG_WAIT;
			 LongMsgComing<=1'b0;
		 end
		 else if(!LongMsgComing&&!SPI_busy) begin //finished
		 ///ZLE!!!!  CMDstate<=LONG_MSG_WAIT;
			 LongMsgComing<=1'b0;
			
			 SPI_MSG_TYPE<=LONG;
			 send_data<=long_dataSPI;
          SPI_trigger<=1'b1;
			 CMDstate<=SPI_TR_WAIT;
		 end
	 end
	 
// -------------------------------------------RESET ----------------------------------
    else if (CMDstate==RESET) //set all the registers to default values;
    begin 		 
       REG0<=8'h12;
       REG1<=8'h34;
		 CMDstate<=IDLE;
    end 

// -------------------------------------------SEND ID --------------------------------
    else if (CMDstate==SEND_ID)
    begin
      send_data<={32'h00000000,16'b0111100101110101};//SEND command+795 - 79<='O' 75<='K'
      SPI_trigger<=1;
      CMDstate<=SPI_TR_WAIT;
		SPI_MSG_TYPE<=STD_TWO_BY; ///standard msg 2Bytes
    end

//------------------------------------------MEMORY states ----------------------------
//GET MEM ID

    else if(CMDstate==GET_MEM_ID)
	 begin
      MEMCMD<=8'h9F; // MEM_ID	
	   MEMTRIG<=1'b1;
	   MEM_MSG_TYPE<=SIX_BY;
	   CMDstate<=MEM_WAIT;
	 end
	 else if(CMDstate==GET_MEM_STREG)
	 begin
			if(ADDR==4'b0000) begin
				MEMCMD<=8'h05; //SR1 status reg1
				MEM_MSG_TYPE<=ONE_BY; 
			end
			else if(ADDR==4'b0001) begin
				MEMCMD<=8'h07; //SR2 status reg2
				MEM_MSG_TYPE<=ONE_BY;
			end
		   else if(ADDR==4'b0010) begin 
			   MEMCMD<=8'hAB; //RES - electronic signature
				MEM_MSG_TYPE<=ONE_BY;
			end
		   else if(ADDR==4'b0011) begin
		    MEMCMD<=8'h06; //WREN
		    MEM_MSG_TYPE<=NO_BY;
		    end
		 else if(ADDR==4'b0100)begin
		    MEMCMD<=8'hC7; //bulk erase - all to 1
			 MEM_MSG_TYPE<=NO_BY;
		 end
		 //else if(ADDR==4'b0101) begin          //sector erase 
		 //                       MEMCMD<=8'hD8 
	    //                       MEMADDR<=sector_address;
		 //end
		 //else if(ADDR==4'b0100) begin 
		 //MEMCMD<=8'h02;//page write
		 //MEMADDR<=page_address;
		 //MEMVAL<=value_to_write;
		 
		 
		 MEMTRIG<=1'b1;
	    CMDstate<=MEM_WAIT;
	 end     
	 else if(CMDstate==MEM_WAIT) 
	 begin
	    //the memory controller did not respond yet
		      if(!MEM_busy&& MEMTRIG) CMDstate<=MEM_WAIT;
		 //the controller responded, clear the MEMTRIG and wait for completion of memory operation
		 else if( MEM_busy&& MEMTRIG)	begin
		    MEMTRIG<=1'b0;
			 CMDstate<=MEM_WAIT;
		 end
		 //the trigger was cleared but the memory is still busy
       else if( MEM_busy&&!MEMTRIG) CMDstate<=MEM_WAIT; 	 
		 //the trigger cleared and memory operation compleated
		 
		  
		 else if(!MEM_busy&&!MEMTRIG) begin
		    //wait for Raspi SPI to be free
		    if(SPI_busy) CMDstate<=MEM_WAIT;
		    else begin
			    //it's free let's send the data to Raspi SPI and go to SPI wait state
			    if(MEM_MSG_TYPE!=NO_BY)  begin
				    SPI_MSG_TYPE<=MEM_MSG_TYPE;
			       send_data[47:0]<=MEMDATA[47:0];
                SPI_trigger<=1'b1;
			       CMDstate<=SPI_TR_WAIT;
				 end
				 else begin
				    SPI_MSG_TYPE<=NO_BY;
				    CMDstate<=IDLE; //nothing to send
					 send_data<=send_data;
					 SPI_trigger<=1'b0;
				 end
			 end
		 end
	 
	 end
	 
  end //else if(CLK==1)
end //always@
endmodule
*/

