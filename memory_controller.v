`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:03:36 01/10/2018 
// Design Name: 
// Module Name:    memory_controller 
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

//memory controller to acces the Quad - Flash memory on CMOD S6 board - S25FL128SAGNFI00
//memory datasheet - http://www.cypress.com/file/177966/download
//page programming - 256B at a time

module memory_controller(CLK,SCLK,oCS,SI_IO0,SO_IO1,WP_IO2,HOLD_IO3,reset,MEMDATA,MEMCMD,MEMADDR,MEMVAL,MEMTRIG,MEMQUAD,MEM_CTRL_busy);
   input CLK;
	input SCLK;
	inout SI_IO0; //serial input
   inout SO_IO1; //serial output
   inout WP_IO2; //write protect not used
   inout HOLD_IO3; //hold not used
	input reset;
	
	output reg[47:0] MEMDATA;
   input [7:0] MEMCMD;
   input [23:0] MEMADDR;		// 3B address
	input [23:0] MEMVAL; //should be a page - 256B
	
	input MEMTRIG;
	input MEMQUAD;
	output oCS;
	output reg MEM_CTRL_busy;

  //all four IO0-3 are used for quad transfer
	
	wire trigger;
   assign trigger = MEMTRIG;


	 
	reg  [260*8-1:0] data_in;
	//reg busy; //change to output
	reg  [8:0] data_in_count;	
   reg [3:0] data_out_count;
	wire [47:0] mem_data_out;
	
	reg spi_trigger;
   wire spi_busy;

	reg [35:0] delay_counter;
	
  spi_cmd sc(.CLK(CLK),.RST(reset),.SCLK(SCLK),.CS(oCS), .SI_IO0(SI_IO0), .SO_IO1(SO_IO1), .WP_IO2(WP_IO2), .HOLD_IO3(HOLD_IO3),
        .busy(spi_busy), .trigger(spi_trigger), .data_in_count(data_in_count), .data_out_count(data_out_count),
   .data_in(data_in), .data_out(mem_data_out),.quad(MEMQUAD));
	//CLK disconnected
 /*  spi_cmd sc(.reset(reset),.SCLK(SCLK),.CS(oCS), .SI_IO0(SI_IO0), .SO_IO1(SO_IO1), .WP_IO2(WP_IO2), .HOLD_IO3(HOLD_IO3),
        .busy(spi_busy), .trigger(spi_trigger), .data_in_count(data_in_count), .data_out_count(data_out_count),
   .data_in(data_in), .data_out(mem_data_out),.quad(MEMQUAD));*/

//state machine states:
   parameter STATE_IDLE=4'b0000, STATE_WAIT=4'b0001, STATE_RDID=4'b0010,STATE_RES=4'b0011,STATE_WREN=4'b0100;
	parameter STATE_BERASE=4'b0101, STATE_POLL_RSR1=4'b0110, STATE_SERASE=4'b0111, STATE_PP=4'b1000,STATE_READ_RSR1=4'b1001;
	parameter STATE_WAIT_TRIGGEROFF=4'b1010;
//comands:   
	parameter  CMD_RDID = 8'h9F, CMD_RES = 8'hAB, CMD_WREN=8'h06, CMD_BE= 8'hC7, CMD_RSR1=8'h05, CMD_RSR2=8'h07, CMD_SE=8'hD8;
	parameter CMD_WPP = 8'h02;
	reg [3:0] MEM_CTRL_state;
	reg [3:0] MEM_CTRL_nextstate;

	always @(posedge CLK) begin
	   if(reset) begin
		
			MEM_CTRL_state <= STATE_WAIT;
			MEM_CTRL_nextstate <= STATE_WAIT_TRIGGEROFF;
			spi_trigger <= 1'b0;
			MEM_CTRL_busy <= 1'b0;
			data_in_count <= 9'h000; // 1'b1;
			data_out_count <= 4'h0;
			MEMDATA <=48'h000000000000;
			//error <= 0;
			//readout <= 0;
	   end
		else
		  case(MEM_CTRL_state)
		  //decoding of the commands
		  STATE_IDLE: begin 
			  if(trigger&&!spi_busy) begin
					MEM_CTRL_busy <= 1'b1;
					//error <= 0;
					//state <= STATE_RDID; //works for all of the comands
					case(MEMCMD)
						 CMD_RDID:
							  MEM_CTRL_state <= STATE_RDID;
					    CMD_RES:
						     MEM_CTRL_state <= STATE_RES;
					    CMD_WREN:
                       MEM_CTRL_state <= STATE_WREN;	
						 CMD_BE:
							  MEM_CTRL_state <= STATE_BERASE;
						 CMD_RSR1:	  
							  MEM_CTRL_state <= STATE_READ_RSR1;
						 CMD_SE:
							  MEM_CTRL_state <= STATE_SERASE;
						 default: begin
						     MEM_CTRL_state <=STATE_IDLE;
						 end
					endcase
			  end else begin
			      MEM_CTRL_state <=STATE_IDLE; 
					MEM_CTRL_busy <= 1'b0;
			  end
			end
			STATE_RDID: begin 
				data_in[7:0]<= CMD_RDID;
				data_in_count <= 9'h001; // 1'b1;
				data_out_count <= 4'b0110;
				spi_trigger <= 1'b1;
				MEM_CTRL_state <= STATE_WAIT;
				MEM_CTRL_nextstate <= STATE_WAIT_TRIGGEROFF;
			end
			STATE_READ_RSR1: begin
			   data_in[7:0]<= CMD_RSR1;
				data_in_count <= 9'h001; // 1'b1;
				data_out_count <= 4'b0001;
				spi_trigger <= 1'b1;
				MEM_CTRL_state <= STATE_WAIT;
				MEM_CTRL_nextstate <= STATE_WAIT_TRIGGEROFF;
			
			end
			STATE_RES: begin //read electronic signature - response 8'h17 
				data_in <= {CMD_RES,24'h010101}; //cmd + 3 dummy bytes
				data_in_count <= 9'h004;//4;
				data_out_count <= 4'b0001;
				spi_trigger <= 1'b1;
				MEM_CTRL_state <= STATE_WAIT;
				MEM_CTRL_nextstate <= STATE_WAIT_TRIGGEROFF;
			end
			STATE_WREN: begin //write enable 
				data_in <= CMD_WREN;
				data_in_count <= 9'h001;//1;
				data_out_count <= 4'b0000;
				spi_trigger <= 1'b1;
				MEM_CTRL_state <= STATE_WAIT;
				MEM_CTRL_nextstate <= STATE_WAIT_TRIGGEROFF;
				end
			STATE_BERASE:begin //bulk erase - all to 1
				data_in <= CMD_BE;
				data_in_count <= 9'h001;//1;
				data_out_count <= 4'b0000;
				spi_trigger <= 1'b1;
				MEM_CTRL_state <= STATE_WAIT;
				MEM_CTRL_nextstate <= STATE_POLL_RSR1;
				//delay_counter <= tBEmax*`input_freq;
				delay_counter <=33'h1CDEF9D80;
				end
			STATE_SERASE: begin // sector erase 3byte address - WREN needs to be set first
 			   data_in <= {CMD_SE, MEMADDR[23:0]};
				data_in_count <= 9'h004;//4; // 1 byte command + 3 bytes address
				data_out_count <= 4'b0000;
				spi_trigger <= 1'b1;
				MEM_CTRL_state <= STATE_WAIT;
				MEM_CTRL_nextstate <= STATE_POLL_RSR1;               
				delay_counter <= 28'h59682F0;
         end
			STATE_PP: begin  // Page write
			   data_in <= {CMD_WPP,  MEMADDR[23:0],  MEMVAL[23:0]}; //
			   data_in_count <= 9'h104;//260; // 256 bytes for data + 1 for command + 3 for address
			   data_out_count <= 4'b0000;
			   spi_trigger <= 1'b1;
			   MEM_CTRL_state <= STATE_WAIT;
			   MEM_CTRL_nextstate <= STATE_POLL_RSR1;               
			   delay_counter <= 20'h2625A;
			end
		
			STATE_POLL_RSR1:  // read register SR1 untill the WIP bit is 0
			begin
				if (delay_counter == 0) begin // max delay timeout
					MEM_CTRL_state <= STATE_IDLE;
					//error <= 1;
				end //if
				else begin
					if (MEMDATA[7] == 0) 
					begin // operation finished successfully WIP bit in SR1 is 0 (datasheet p.138)
						MEM_CTRL_state <= STATE_IDLE;
					end 
					else begin // go on polling
						data_in <= CMD_RSR1;
						data_in_count <= 9'h001;//1;
						data_out_count <= 4'b0001;
						spi_trigger <= 1'b1;
						delay_counter <= delay_counter - 1'b1;
						MEM_CTRL_state <= STATE_WAIT;
						MEM_CTRL_nextstate <= STATE_POLL_RSR1;
					end 
				end
			end 
	
			STATE_WAIT: begin
			   //the spi_trigger is set but the memory SPI controller did not respond yet
				if(spi_trigger&&!spi_busy) begin
				   spi_trigger <= 1'b1;
					MEM_CTRL_state<=MEM_CTRL_state;
				   MEMDATA <= MEMDATA ;
				end
				//the memory SPI controller responded with spi_busy=1, clear the spi_trigger and wait for completion of memory operation
				else if(spi_trigger&&spi_busy) begin
				   spi_trigger <= 1'b0;
					MEM_CTRL_state<=MEM_CTRL_state;
				   MEMDATA <= MEMDATA ; 
				end
				//the spi_trigger cleared but the memory SPI controller operation is not completed
				else if(!spi_trigger&&spi_busy) begin
				   spi_trigger <= 1'b0;
					MEM_CTRL_state<=MEM_CTRL_state;
				   MEMDATA <= MEMDATA ; 
				end
				//the spi_trigger cleared and memory SPI controller operation completed
				//go to the next state and copy the data
				else if(!spi_trigger&&!spi_busy) begin
				   spi_trigger <= 1'b0;
					MEM_CTRL_state <= MEM_CTRL_nextstate;
					MEMDATA <= mem_data_out;
				end

			end
		   STATE_WAIT_TRIGGEROFF:
			begin
			   MEM_CTRL_state <= STATE_IDLE;
  		   end
		default: begin
		end
		endcase
	end
	
endmodule
