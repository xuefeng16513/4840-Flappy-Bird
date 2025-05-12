/*
 * Seven-segment LED emulator
 *
 * Stephen A. Edwards, Columbia University
 */

 
module VGA_Emulator(
 input logic 	    clk50, reset,
 input logic [15:0] loc_pillar1_temp, loc_pillar2_temp, loc_pillar3_temp,
 input logic [15:0] score_temp,
 input logic [7:0]  len_pillars1_temp, len_pillars2_temp, len_pillars3_temp,
 input logic [7:0]  move_temp,
 input logic [15:0] pos_bird_temp,
 input logic  start_temp,
 output logic [7:0] VGA_R, VGA_G, VGA_B,
 output logic 	    VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC + HBACK_PORCH; // 1600
   
   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC + VBACK_PORCH; // 525

   logic [10:0]			     hcount; // Horizontal counter
                                             // Hcount[10:1] indicates pixel column (0-639)
   logic 			     endOfLine;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else  	         hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;

   // Vertical counter
   logic [9:0] 			     vcount;
   logic 			     endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) & !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1; // For adding sync to video signals; not used for VGA
   
   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   // 101 0000 0000  1280	       01 1110 0000  480
   // 110 0011 1111  1599	       10 0000 1100  524
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
			!( vcount[9] | (vcount[8:5] == 4'b1111) );   

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
   assign VGA_CLK = hcount[0]; // 25 MHz clock: pixel latched on rising edge
	
	
	
	////////////////////////////////////////////////////////////
	//////////////////////////////////////////////////////////
	///////assign the new data when V count>= 10'd480///////////
	/////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////
	
 logic [15:0] loc_pillar1, loc_pillar2, loc_pillar3;
 logic [15:0] score;
 logic [7:0]  len_pillars1;
 logic [7:0]  len_pillars2, len_pillars3;
 logic [7:0]  move;
 logic [15:0] pos_bird;
 logic start;
 
	always_ff @(posedge clk50)
		begin
			if(vcount > 10'd480)
				begin
					loc_pillar1 <= loc_pillar1_temp;
					loc_pillar2 <= loc_pillar2_temp;
					loc_pillar3 <= loc_pillar3_temp;
					score       <= score_temp;
					
					len_pillars1 <= len_pillars1_temp;
					len_pillars2 <= len_pillars2_temp;
					len_pillars3 <= len_pillars3_temp;
					move <= move_temp;
					pos_bird <= pos_bird_temp;
					start <= start_temp;
				end
			else
				begin
					loc_pillar1 <= loc_pillar1;
					loc_pillar2 <= loc_pillar2;
					loc_pillar3 <= loc_pillar3;
					score       <= score;
					
					len_pillars1 <= len_pillars1;
					len_pillars2 <= len_pillars2;
					len_pillars3 <= len_pillars3;
					move <= move;
					pos_bird <= pos_bird;
					start <= start;		
				end
		end
	

	//-----------------------------address of sprite block roms
	logic [14:0] adr_start;
	
	logic [14:0] adr_bgHouse;
	logic [10:0] adr_bgBrick;
	
	logic [12:0]adr_bird;
	logic [11:0]adr_pillar1;
	logic [11:0]adr_pillar2;
	logic [11:0] adr1_1, adr1_2, adr1_3, adr2_1, adr2_2, adr2_3; //????????????????????
	
	logic [13:0] adr_star1;
	logic [13:0] adr_star2;


	logic [11:0] adr_num; //adr of score number
	
	//----------------------------- data of sprite block roms
	logic[23:0] data_start;
	logic[23:0] data_stop;
	
	logic[23:0] data_bgHouse;
	logic[23:0] data_bgBrick;
	
	logic[23:0] data_bg;
	
	logic[23:0] data_bird;
	
	logic[23:0] data_star1;
	logic[23:0] data_star2;
	
	logic[23:0] data_pillar1;
	logic[23:0] data_pillar2;
	
	logic[23:0] data_num0;
	logic[23:0] data_num1;
	logic[23:0] data_num2;
	logic[23:0] data_num3;
	logic[23:0] data_num4;
	logic[23:0] data_num5;
	logic[23:0] data_num6;
	logic[23:0] data_num7;
	logic[23:0] data_num8;
	logic[23:0] data_num9;
	
	// sprite_on flag
	logic start_on;
	
	logic bgHouse_on;
	logic bgBrick_on;
	
	logic bird_on;
	
	logic star1_on;
	logic star2_on;
	
	logic pillar1_on;
	logic pillar2_on;
	
	logic numHundreds_on;  // 100
	logic numTen_on;   //10
	logic num_on;  //1
	logic pillar1_1on, pillar1_2on, pillar1_3on, pillar2_1on, pillar2_2on, pillar2_3on;
	
	
	//------------------------------block rom for sprites-----------------------
	tStart tStart(.address(adr_start), .clock(clk50), .q(data_start));
	tStop tStop(.address(adr_stop), .clock(clk50), .q(data_stop));
	
	backGround bgHouse (.clock(clk50), .address(adr_bgHouse), .q(data_bgHouse)); // read data from ROM BackGround
	bgBrick bgBrick (.clock(clk50), .address(adr_bgBrick), .q(data_bgBrick));
	
	bird   bird (.clock(clk50), .address(adr_bird), .q(data_bird));  //read data from ROM bird
	pillar_1 pillar_1(.address(adr_pillar1),.clock(clk50),.q(data_pillar1));//read data from ROM pillar_1(main pillar)
   pillar_2 pillar_2(.address(adr_pillar2),.clock(clk50),.q(data_pillar2));//read data from ROM pillar_2(edge of pillar)
	
	star1 star1(.clock(clk50), .address(adr_star1), .q(data_star1));
	star2 star2(.clock(clk50), .address(adr_star2), .q(data_star2));
	
	
	num0 num0(.address(adr_num),.clock(clk50),.q(data_num0));  // read data from ROM num
	num1 num1(.address(adr_num),.clock(clk50),.q(data_num1));
	num2 num2(.address(adr_num),.clock(clk50),.q(data_num2));
	num3 num3(.address(adr_num),.clock(clk50),.q(data_num3));
	num4 num4(.address(adr_num),.clock(clk50),.q(data_num4));
	num5 num5(.address(adr_num),.clock(clk50),.q(data_num5));
	num6 num6(.address(adr_num),.clock(clk50),.q(data_num6));
	num7 num7(.address(adr_num),.clock(clk50),.q(data_num7));
	num8 num8(.address(adr_num),.clock(clk50),.q(data_num8));
	num9 num9(.address(adr_num),.clock(clk50),.q(data_num9));

	
//-------------------------------score controller-----------------------
	
	logic [23:0] numHundreds;
	logic [23:0] numTen;
	logic [23:0] num;
	//logic s4=0,s7=0;
	
	always_comb
		begin
			case(score[11:8])
			4'h9: numHundreds <= data_num9;		
			4'h8: numHundreds <= data_num8;
			4'h7: numHundreds <= data_num7;
			4'h6: numHundreds <= data_num6;
			4'h5: numHundreds <= data_num5;
			4'h4: numHundreds <= data_num4;
			4'h3: numHundreds <= data_num3;
			4'h2: numHundreds <= data_num2;
			4'h1: numHundreds <= data_num1;				
			4'h0: numHundreds <= data_num0;
			default: numHundreds <= data_num0;
			endcase
			
			case(score[7:4])
			4'h9: numTen<= data_num9;			
			4'h8: numTen <= data_num8;
			4'h7: numTen <= data_num7;
			4'h6: numTen <= data_num6;
			4'h5: numTen <= data_num5;
			4'h4: numTen <= data_num4;
			4'h3: numTen <= data_num3;
			4'h2: numTen <= data_num2;
			4'h1: numTen<= data_num1;				
			4'h0: numTen <= data_num0;
			default:numTen <= data_num0;
			endcase
			
			case(score[3:0])
			4'h9: num<= data_num9;			
			4'h8: num<= data_num8;
			4'h7: num<= data_num7;
			4'h6: num <= data_num6;
			4'h5: num <= data_num5;
			4'h4: num <= data_num4;
			4'h3: num <= data_num3;
			4'h2: num <= data_num2;
			4'h1: num<= data_num1;				
			4'h0: num <= data_num0;
			default:num <= data_num0;
			endcase
			
		end
		
	always_comb    // control the number of digits displyed
		begin
			if(score[11:8] != 4'b0000 & hcount[10:1]>= 200 & hcount[10:1] <= 232 & vcount >= 100 & vcount <= 150) //& (((!s4) & (!s7)) || (s4 & (!(hcount[10:1]<=220 & vcount>=140))) || (s7 & (!(hcount[10:1]<=220 & vcount>=130)))))  // add position condition here
				begin
					numHundreds_on <= 1;
					numTen_on <= 0;
					num_on <= 0;
					adr_num <= (hcount[10:1] -200) + (vcount-100)*33; 
				end
			else if( (score[7:4] != 4'b0000 | score[11:8] != 4'b0000 ) & hcount[10:1]>= 240 & hcount[10:1] <= 272 & vcount >= 100 & vcount <= 150) //& (((!s4) & (!s7)) || (s4 & (!(hcount[10:1]<=260 & vcount>=140))) || (s7 & (!(hcount[10:1]<=260 & vcount>=130)))))
				begin
					numHundreds_on <= 0;
					numTen_on <= 1;
					num_on <= 0;
					adr_num <= (hcount[10:1] -240) + (vcount-100)*33; 
				end  
			else if(hcount[10:1]>= 280 & hcount[10:1] <= 312 & vcount >= 100 & vcount <= 150)// & (((!s4) & (!s7)) || (s4 & (!(hcount[10:1]<=300 & vcount>=140))) || (s7 & (!(hcount[10:1]<=300 & vcount>=130)))))
				begin
					numHundreds_on <= 0;
					numTen_on <= 0;
					num_on <= 1;
					adr_num <= (hcount[10:1] -280) + (vcount-100)*33; 
				end	
			else
				begin
					numHundreds_on <= 0;
					numTen_on <= 0;
					num_on <= 0;
					adr_num <= 0;
				end
		 end
	
	//-------------------------------sprite controller----------------------
	// game start module
	always_comb
		begin
		if (hcount[10:1]>=240 & hcount[10:1]<400 & vcount>=80 & vcount<160 & start==0)
		     begin
			  adr_start <= (hcount[10:1]-240) + (vcount-80)*160;
			  start_on  <=1;
			  end
	   else
			  begin
			  adr_start <=0;
			  start_on  <=0;
			  end
		end
	
  	// backGround Module for House and Brick
	always_comb 
		begin
			if(vcount >= 329 & vcount <= 456)
				   begin
					bgHouse_on <= 1;
					bgBrick_on <= 0;
					adr_bgHouse <= (hcount[10:1])%64 + (vcount - 329) *64;
					adr_bgBrick <= 0;
					end
			else 
				begin
					bgHouse_on <= 0;
					bgBrick_on <= 0;
					adr_bgHouse <= 0;
					adr_bgBrick <= 0;
				end
		end
		
   //star Module
		always_comb
			begin
				if(vcount >= 100 & vcount <= 149 & hcount[10:1] >= 100 & hcount[10:1] <= 149)
					begin
						adr_star1 =  (hcount[10:1]- 100) + (vcount - 100)* 50;
						star1_on = 1;
						adr_star2 = 0;
						star2_on = 0;
					end
				else if(vcount >= 335 & vcount <= 374 & hcount[10:1] >= 400 & hcount[10:1] <= 479)
					begin
						adr_star2 = (hcount[10:1]- 400) + (vcount - 335)* 80;
						star2_on = 1;
						adr_star1 = 0;
						star1_on = 0;
					end
				else
					begin
						adr_star1 = 0;
						adr_star2 = 0;
						star1_on = 0;
						star2_on = 0;
					end
			end
	
   // backGround Module
		always_comb 
		begin
			if(vcount >= 0 & vcount <= 345)
				data_bg <= {8'h73, 8'he0, 8'hff};
			 else 
				data_bg <= {8'h84, 8'hcb, 8'h53};
		end
		
		
		
	// bird Module	
	always_comb 
		begin
			if( hcount[10:1]>= 200 & hcount[10:1] <= 239 & vcount >= pos_bird & vcount <= pos_bird+39)
					begin
						bird_on <= 1;
						adr_bird <= (hcount[10:1]- 200) + ( vcount-pos_bird)* 40;
					end
			else
					begin
						bird_on <= 0;
						adr_bird <= 0;
					end
		end	
	
	
	always_comb//sprite of the main pillar 1
		begin
		   if (loc_pillar1>120 & loc_pillar1<660)//in the middle of the screen
			begin
			  if (hcount[10:1]>=(loc_pillar1-120) & hcount[10:1]<(loc_pillar1-20) & vcount>=0 & vcount<len_pillars1*5)//top part of the first pillar
                begin
                adr1_1<=hcount[10:1]-(loc_pillar1-120)+(vcount%5)*100;
                pillar1_1on<=1;
                end
           else if (hcount[10:1]>=(loc_pillar1-120) & hcount[10:1]<(loc_pillar1-20) & vcount<=435 & vcount>len_pillars1*5+200)//bot part of the first pillar
                begin
                adr1_1<=hcount[10:1]-(loc_pillar1-120)+((vcount-(len_pillars1*5+200))%5)*100;
                pillar1_1on<=1;
                end
           else
                begin
                adr1_1<=0;
                pillar1_1on<=0;
                end
			end		 
			else if (loc_pillar1<=120 & loc_pillar1>=20)//in the left side of the screen
			begin
			  if (hcount[10:1]>=0 & hcount[10:1]<(loc_pillar1-20) & vcount>=0 & vcount<len_pillars1*5)//top part of the first pillar
                begin
                adr1_1<=hcount[10:1]-(loc_pillar1-120)+(vcount%5)*100;
                pillar1_1on<=1;
                end
           else if (hcount[10:1]>=0 & hcount[10:1]<(loc_pillar1-20) & vcount<=435 & vcount>len_pillars1*5+200)//bot part of the first pillar
                begin
                adr1_1<=hcount[10:1]-(loc_pillar1-120)+((vcount-(len_pillars1*5+200))%5)*100;
                pillar1_1on<=1;
                end
           else
                begin
                adr1_1<=0;
                pillar1_1on<=0;
                end
			end		 
			else if (loc_pillar1>=660 & loc_pillar1<=760)//in the right side of the screen
			begin
		     if (hcount[10:1]>=(loc_pillar1-120) & hcount[10:1]<=640 & vcount>=0 & vcount<len_pillars1*5)//top part of the first pillar
                begin
                adr1_1<=hcount[10:1]-(loc_pillar1-120)+(vcount%5)*100;
                pillar1_1on<=1;
                end
           else if (hcount[10:1]>=(loc_pillar1-120) & hcount[10:1]<=640 & vcount<=435 & vcount>len_pillars1*5+200)//bot part of the first pillar
                begin
                adr1_1<=hcount[10:1]-(loc_pillar1-120)+((vcount-(len_pillars1*5+200))%5)*100;
                pillar1_1on<=1;
                end
           else
                begin
                adr1_1<=0;
                pillar1_1on<=0;
                end
			end		 
         else//default  					 
			       begin
                adr1_1<=0;
                pillar1_1on<=0;
                end
		end
		
   always_comb//sprite of the edge of the pillar 1
		begin
		   if (loc_pillar1>130 & loc_pillar1<650)//in the middle of the screen
			begin
		    if (hcount[10:1]>=loc_pillar1-130 & hcount[10:1]<loc_pillar1-10 & vcount>=len_pillars1*5 & vcount<len_pillars1*5+25)
              begin
              adr2_1<=hcount[10:1]-(loc_pillar1-130)+(vcount-len_pillars1*5)*120;
              pillar2_1on<=1;
              end
           else if(hcount[10:1]>=loc_pillar1-130 & hcount[10:1]<loc_pillar1-10 & vcount>len_pillars1*5+175 & vcount<=len_pillars1*5+200)
              begin
              adr2_1<=hcount[10:1]-(loc_pillar1-130)+(vcount-(len_pillars1*5+175))*120;
              pillar2_1on<=1;
              end
           else
              begin
              adr2_1<=0;
              pillar2_1on<=0;
				  end
			end
         else if (loc_pillar1>=10 & loc_pillar1<=130)//in the left side of the screen
			begin
			  if (hcount[10:1]>=0 & hcount[10:1]<loc_pillar1-10 & vcount>=len_pillars1*5 & vcount<len_pillars1*5+25)
              begin
              adr2_1<=hcount[10:1]-(loc_pillar1-130)+(vcount-len_pillars1*5)*120;
              pillar2_1on<=1;
              end
           else if(hcount[10:1]>=0 & hcount[10:1]<loc_pillar1-10 & vcount>len_pillars1*5+175 & vcount<=len_pillars1*5+200)
              begin
              adr2_1<=hcount[10:1]-(loc_pillar1-130)+(vcount-(len_pillars1*5+175))*120;
              pillar2_1on<=1;
              end
           else
              begin
              adr2_1<=0;
              pillar2_1on<=0;
			     end
			end	  
			else if (loc_pillar1>=650 & loc_pillar1<=770)//in the right side of the screen
			begin
			  if (hcount[10:1]>=loc_pillar1-130 & hcount[10:1]<=640 & vcount>=len_pillars1*5 & vcount<len_pillars1*5+25)
              begin
              adr2_1<=hcount[10:1]-(loc_pillar1-130)+(vcount-len_pillars1*5)*120;
              pillar2_1on<=1;
              end
           else if(hcount[10:1]>=loc_pillar1-130 & hcount[10:1]<=640 & vcount>len_pillars1*5+175 & vcount<=len_pillars1*5+200)
              begin
              adr2_1<=hcount[10:1]-(loc_pillar1-130)+(vcount-(len_pillars1*5+175))*120;
              pillar2_1on<=1;
              end
           else
              begin
              adr2_1<=0;
              pillar2_1on<=0;
				  end
			end
			else  
			     begin
              adr2_1<=0;
              pillar2_1on<=0;
				  end
       end
		 
		 
   always_comb//sprite of the main pillar 2
		begin
		   if (loc_pillar2>120 & loc_pillar2<660)
			  begin
			  if (hcount[10:1]>=(loc_pillar2-120) & hcount[10:1]<(loc_pillar2-20) & vcount>=0 & vcount<len_pillars2*5)//top part of the second pillar
                begin
                adr1_2<=hcount[10:1]-(loc_pillar2-120)+(vcount%5)*100;
                pillar1_2on<=1;
                end
           else if (hcount[10:1]>=(loc_pillar2-120) & hcount[10:1]<(loc_pillar2-20) & vcount<=435 & vcount>len_pillars2*5+200)//bot part of the second pillar
                begin
                adr1_2<=hcount[10:1]-(loc_pillar2-120)+((vcount-(len_pillars2*5+200))%5)*100;
                pillar1_2on<=1;
                end
           else
                begin
                adr1_2<=0;
                pillar1_2on<=0;
                end
			   end
			else if (loc_pillar2<=120 & loc_pillar2>=20)
			  begin
			  if (hcount[10:1]>=0 & hcount[10:1]<(loc_pillar2-20) & vcount>=0 & vcount<len_pillars2*5)//top part of the second pillar
                begin
                adr1_2<=hcount[10:1]-(loc_pillar2-120)+(vcount%5)*100;
                pillar1_2on<=1;
                end
           else if (hcount[10:1]>=0 & hcount[10:1]<(loc_pillar2-20) & vcount<=435 & vcount>len_pillars2*5+200)//bot part of the second pillar
                begin
                adr1_2<=hcount[10:1]-(loc_pillar2-120)+((vcount-(len_pillars2*5+200))%5)*100;
                pillar1_2on<=1;
                end
           else
                begin
                adr1_2<=0;
                pillar1_2on<=0;
                end
				end	 
			else if (loc_pillar2>=660 & loc_pillar2<=760)
			  begin
		     if (hcount[10:1]>=(loc_pillar2-120) & hcount[10:1]<=640 & vcount>=0 & vcount<len_pillars2*5)//top part of the second pillar
                begin
                adr1_2<=hcount[10:1]-(loc_pillar2-120)+(vcount%5)*100;
                pillar1_2on<=1;
                end
           else if (hcount[10:1]>=(loc_pillar2-120) & hcount[10:1]<=640 & vcount<=435 & vcount>len_pillars2*5+200)//bot part of the second pillar
                begin
                adr1_2<=hcount[10:1]-(loc_pillar2-120)+((vcount-(len_pillars2*5+200))%5)*100;
                pillar1_2on<=1;
                end
           else
                begin
                adr1_2<=0;
                pillar1_2on<=0;
                end
				end	 
         else  					 
			       begin
                adr1_2<=0;
                pillar1_2on<=0;
                end
		end
		
   always_comb//sprite of the edge of the pillar 2
		begin
		   if (loc_pillar2>130 & loc_pillar2<650)
			begin
		    if (hcount[10:1]>=loc_pillar2-130 & hcount[10:1]<loc_pillar2-10 & vcount>=len_pillars2*5 & vcount<len_pillars2*5+25)
              begin
              adr2_2<=hcount[10:1]-(loc_pillar2-130)+(vcount-len_pillars2*5)*120;
              pillar2_2on<=1;
              end
           else if(hcount[10:1]>=loc_pillar2-130 & hcount[10:1]<loc_pillar2-10 & vcount>len_pillars2*5+175 & vcount<=len_pillars2*5+200)
              begin
              adr2_2<=hcount[10:1]-(loc_pillar2-130)+(vcount-(len_pillars2*5+175))*120;
              pillar2_2on<=1;
              end
           else
              begin
              adr2_2<=0;
              pillar2_2on<=0;
				  end
			end
         else if (loc_pillar2>=10 & loc_pillar2<=130)
			begin
			  if (hcount[10:1]>=0 & hcount[10:1]<loc_pillar2-10 & vcount>=len_pillars2*5 & vcount<len_pillars2*5+25)
              begin
              adr2_2<=hcount[10:1]-(loc_pillar2-130)+(vcount-len_pillars2*5)*120;
              pillar2_2on<=1;
              end
           else if(hcount[10:1]>=0 & hcount[10:1]<loc_pillar2-10 & vcount>len_pillars2*5+175 & vcount<=len_pillars2*5+200)
              begin
              adr2_2<=hcount[10:1]-(loc_pillar2-130)+(vcount-(len_pillars2*5+175))*120;
              pillar2_2on<=1;
              end
           else
              begin
              adr2_2<=0;
              pillar2_2on<=0;
			     end
			end
			else if (loc_pillar2>=650 & loc_pillar2<=770)
			begin
			  if (hcount[10:1]>=loc_pillar2-130 & hcount[10:1]<=640 & vcount>=len_pillars2*5 & vcount<len_pillars2*5+25)
              begin
              adr2_2<=hcount[10:1]-(loc_pillar2-130)+(vcount-len_pillars2*5)*120;
              pillar2_2on<=1;
              end
           else if(hcount[10:1]>=loc_pillar2-130 & hcount[10:1]<640 & vcount>len_pillars2*5+175 & vcount<=len_pillars2*5+200)
              begin
              adr2_2<=hcount[10:1]-(loc_pillar2-130)+(vcount-(len_pillars2*5+175))*120;
              pillar2_2on<=1;
              end
           else
              begin
              adr2_2<=0;
              pillar2_2on<=0;
				  end
			 end
			 else
			     begin
              adr2_2<=0;
              pillar2_2on<=0;
				  end
       end
		 
   always_comb//sprite of the main pillar 3
		begin
		   if (loc_pillar3>120 & loc_pillar3<660)
			begin
			  if (hcount[10:1]>=(loc_pillar3-120) & hcount[10:1]<(loc_pillar3-20) & vcount>=0 & vcount<len_pillars3*5)//top part of the second pillar
                begin
                adr1_3<=hcount[10:1]-(loc_pillar3-120)+(vcount%5)*100;
                pillar1_3on<=1;
                end
           else if (hcount[10:1]>=(loc_pillar3-120) & hcount[10:1]<(loc_pillar3-20) & vcount<=435 & vcount>len_pillars3*5+200)//bot part of the second pillar
                begin
                adr1_3<=hcount[10:1]-(loc_pillar3-120)+((vcount-(len_pillars3*5+200))%5)*100;
                pillar1_3on<=1;
                end
           else
                begin
                adr1_3<=0;
                pillar1_3on<=0;
                end
			end
			else if (loc_pillar3<=120 & loc_pillar3>=20)
			begin
			  if (hcount[10:1]>=0 & hcount[10:1]<(loc_pillar3-20) & vcount>=0 & vcount<len_pillars3*5)//top part of the second pillar
                begin
                adr1_3<=hcount[10:1]-(loc_pillar3-120)+(vcount%5)*100;
                pillar1_3on<=1;
                end
           else if (hcount[10:1]>=0 & hcount[10:1]<(loc_pillar3-20) & vcount<=435 & vcount>len_pillars3*5+200)//bot part of the second pillar
                begin
                adr1_3<=hcount[10:1]-(loc_pillar3-120)+((vcount-(len_pillars3*5+200))%5)*100;
                pillar1_3on<=1;
                end
           else
                begin
                adr1_3<=0;
                pillar1_3on<=0;
                end
			end
			else if (loc_pillar3>=660 & loc_pillar3<=760)
			begin
		     if (hcount[10:1]>=(loc_pillar3-120) & hcount[10:1]<=640 & vcount>=0 & vcount<len_pillars3*5)//top part of the second pillar
                begin
                adr1_3<=hcount[10:1]-(loc_pillar3-120)+(vcount%5)*100;
                pillar1_3on<=1;
                end
           else if (hcount[10:1]>=(loc_pillar3-120) & hcount[10:1]<=640 & vcount<=435 & vcount>len_pillars3*5+200)//bot part of the second pillar
                begin
                adr1_3<=hcount[10:1]-(loc_pillar3-120)+((vcount-(len_pillars3*5+200))%5)*100;
                pillar1_3on<=1;
                end
           else
                begin
                adr1_3<=0;
                pillar1_3on<=0;
                end
			end		 
         else  					 
			       begin
                adr1_3<=0;
                pillar1_3on<=0;
                end
		end
		
   always_comb//sprite of the edge of the pillar 3
		begin
		   if (loc_pillar3>130 & loc_pillar3<650)
			begin
		    if (hcount[10:1]>=loc_pillar3-130 & hcount[10:1]<loc_pillar3-10 & vcount>=len_pillars3*5 & vcount<len_pillars3*5+25)
              begin
              adr2_3<=hcount[10:1]-(loc_pillar3-130)+(vcount-len_pillars3*5)*120;
              pillar2_3on<=1;
              end
           else if(hcount[10:1]>=loc_pillar3-130 & hcount[10:1]<loc_pillar3-10 & vcount>len_pillars3*5+175 & vcount<=len_pillars3*5+200)
              begin
              adr2_3<=hcount[10:1]-(loc_pillar3-130)+(vcount-(len_pillars3*5+175))*120;
              pillar2_3on<=1;
              end
           else
              begin
              adr2_3<=0;
              pillar2_3on<=0;
				  end
			end	  
         else if (loc_pillar3>=10 & loc_pillar3<=130)
			begin
			  if (hcount[10:1]>=0 & hcount[10:1]<loc_pillar3-10 & vcount>=len_pillars3*5 & vcount<len_pillars3*5+25)
              begin
              adr2_3<=hcount[10:1]-(loc_pillar3-130)+(vcount-len_pillars3*5)*120;
              pillar2_3on<=1;
              end
           else if(hcount[10:1]>=0 & hcount[10:1]<loc_pillar3-10 & vcount>len_pillars3*5+175 & vcount<=len_pillars3*5+200)
              begin
              adr2_3<=hcount[10:1]-(loc_pillar3-130)+(vcount-(len_pillars3*5+175))*120;
              pillar2_3on<=1;
              end
           else
              begin
              adr2_3<=0;
              pillar2_3on<=0;
			     end
			end	  
			else if (loc_pillar3>=650 & loc_pillar3<=770)
			begin
			  if (hcount[10:1]>=loc_pillar3-130 & hcount[10:1]<=640 & vcount>=len_pillars3*5 & vcount<len_pillars3*5+25)
              begin
              adr2_3<=hcount[10:1]-(loc_pillar3-130)+(vcount-len_pillars3*5)*120;
              pillar2_3on<=1;
              end
           else if(hcount[10:1]>=loc_pillar3-130 & hcount[10:1]<=640 & vcount>len_pillars3*5+175 & vcount<=len_pillars3*5+200)
              begin
              adr2_3<=hcount[10:1]-(loc_pillar3-130)+(vcount-(len_pillars3*5+175))*120;
              pillar2_3on<=1;
              end
           else
              begin
              adr2_3<=0;
              pillar2_3on<=0;
				  end
			 end
			 else
              begin
              adr2_3<=0;
              pillar2_3on<=0;
				  end			  
       end	
		
	always_comb
	begin
	   if(adr1_1)
		   begin
		   adr_pillar1<=adr1_1;
			pillar1_on<=pillar1_1on;
			end
		else if (adr1_2)
		   begin
	      adr_pillar1<=adr1_2;
			pillar1_on<=pillar1_2on;
			end
		else if (adr1_3)
		   begin
	      adr_pillar1<=adr1_3;
			pillar1_on<=pillar1_3on;
			end
		else  
		   begin
	      adr_pillar1<=0;
			pillar1_on<=0;
			end
	end	

	
	always_comb
	begin
	   if(adr2_1)
		   begin
		   adr_pillar2<=adr2_1;
			pillar2_on<=pillar2_1on;
			end
		else if (adr2_2)
		   begin
	      adr_pillar2<=adr2_2;
			pillar2_on<=pillar2_2on;
			end
		else if (adr2_3)
		   begin
	      adr_pillar2<=adr2_3;
			pillar2_on<=pillar2_3on;
			end
		else  
		   begin
	      adr_pillar2<=0;
			pillar2_on<=0;
			end
	end
//----------------------priority--------------------------
//	
   always_comb 
	begin 
	   if(start_on)
		   {VGA_R, VGA_G, VGA_B} = data_start;
		else if(bird_on & data_bird!={8'h73, 8'he0, 8'hff})
			{VGA_R, VGA_G, VGA_B} = data_bird;
		else if(numHundreds_on & start == 1 & numHundreds != {8'h70, 8'hc5, 8'hce})
		   begin
			{VGA_R, VGA_G, VGA_B} = numHundreds;
			end				
		else if(numTen_on & start == 1 & numTen != {8'h70, 8'hc5, 8'hce})
		   begin
			{VGA_R, VGA_G, VGA_B} = numTen;
			end				
		else if(num_on & start == 1 & num!= {8'h70, 8'hc5, 8'hce})
			begin
			{VGA_R, VGA_G, VGA_B} = num;
			end				
		else if(pillar1_on)
		   {VGA_R, VGA_G, VGA_B} = data_pillar1;
		else if(pillar2_on)
		   {VGA_R, VGA_G, VGA_B} = data_pillar2;
		/*else if (star2_on)
			{VGA_R, VGA_G, VGA_B} = data_star2;*/
		else if(bgHouse_on)
			{VGA_R, VGA_G, VGA_B} = data_bgHouse;
		else if (star1_on)
			{VGA_R, VGA_G, VGA_B} = data_star1;
		else	
			{VGA_R, VGA_G, VGA_B} = data_bg;
	end 
	

endmodule // VGA_LED_Emulator
