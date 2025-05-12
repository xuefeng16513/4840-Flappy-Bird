/*
 * Avalon memory-mapped peripheral for the VGA LED Emulator
 *
 * Stephen A. Edwards
 * Columbia University
 */

 
module VGA_LED(input logic        clk,
	       input logic 	  reset,
	       input logic [7:0]  writedata,
	       input logic 	  write,
	       input 		  chipselect,
	       input logic [3:0]     address,

	       output logic [7:0] VGA_R, VGA_G, VGA_B,
	       output logic 	  VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n,
	       output logic 	  VGA_SYNC_n,
			 output logic [1:0]  VGA_audio_ctrl);

	 
   logic [15:0]  center_h,center_v;


   VGA_Emulator led_emulator(.clk50(clk), .reset(reset), .VGA_R(VGA_R), 
											.VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_CLK(VGA_CLK), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), 
											.VGA_BLANK_n(VGA_BLANK_n), .VGA_SYNC_n(VGA_SYNC_n), .loc_pillar1_temp(xPillar1), .loc_pillar2_temp(xPillar2), 
											.loc_pillar3_temp(xPillar3), .len_pillars1_temp(hPillar1), .len_pillars2_temp(hPillar2), .len_pillars3_temp(hPillar3),
				                     .score_temp(score), .pos_bird_temp(bird), .start_temp(start));							
	
	
	logic [15:0] xPillar1;
	logic [15:0] xPillar2;
	logic [15:0] xPillar3;
   logic [7:0] hPillar1;
   logic [7:0] hPillar2;
   logic [7:0] hPillar3;
	logic [7:0] a;
	logic [15:0] score;
	logic [7:0]  move;
	logic [15:0] bird;
	logic [7:0] game_info1;
	logic [7:0] game_info2;
	logic start;
	logic stop;
	
	assign VGA_audio_ctrl [1:0]= game_info1[1:0];
	assign start = game_info2[0];
	
	
   always_ff @(posedge clk)
     if (reset) 
		begin
			xPillar1 <= 50;
			xPillar2 <= 300;
			xPillar3 <= 600;
			hPillar1 <= 10;
			hPillar2 <= 15;
			hPillar3 <= 20;
			score <= 16'b0000100010001000;
			move  <= 5;
			bird <= 200;
			game_info1 <=0;
			game_info2 <=0;
			//VGA_audio_ctrl <= 2'b11;
		end 
	  else if (chipselect && write)
			case (address)
          4'b0000: xPillar1[15:8] <= writedata;
          4'b0001: xPillar1[7:0]  <= writedata;
	       4'b0010: xPillar2[15:8] <= writedata;
          4'b0011: xPillar2[7:0]  <= writedata;
		    4'b0100: xPillar3[15:8] <= writedata;
          4'b0101: xPillar3[7:0]  <= writedata;
			  
	       4'b0110:  hPillar1[7:0] <= writedata;
          4'b0111:  hPillar2[7:0] <= writedata;
			 4'b1000:  hPillar3[7:0] <= writedata;
			 4'b1001:  score[15:8]   <= writedata; 
			 4'b1010:  score[7:0]    <= writedata; 
			 4'b1011:  move[7:0]     <= writedata;
			 4'b1100:  bird[15:8]    <= writedata;
			 4'b1101:  bird[7:0]     <= writedata;
			 
			 4'b1110:  game_info1   <= writedata;
			 4'b1111:  game_info2   <= writedata;
          default: a <= writedata;	
        endcase 
endmodule
