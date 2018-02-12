`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:59:51 02/09/2018 
// Design Name: 
// Module Name:    ram_controll 
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
module ram_controll(
    input clk,
	 input we,
	 input [9:0] mem_addr,
	 input [15:0] mem_din,
	 output reg [15:0] mem_dout
	 
	 );
	 
//memory
reg [15:0] mem [(2**10)-1:0];

// Port A
always @(posedge clk) begin
    mem_dout      <= mem[mem_addr];
    if(we) begin
        mem_dout      <= mem_din;
        mem[mem_addr] <= mem_din;
    end
end
 
//// Port B
//always @(posedge b_clk) begin
//    b_dout      <= mem[b_addr];
//    if(b_wr) begin
//        b_dout      <= b_din;
//        mem[b_addr] <= b_din;
//    end
//end

endmodule
