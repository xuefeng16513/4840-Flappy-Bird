/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Modified for Flappy Bird game with moving pipes
 *
 * Register map:
 * 
 * Byte Offset  7 ... 0   Meaning
 *        0    |  Red  |  Red component of background color (0-255)
 *        1    | Green |  Green component
 *        2    | Blue  |  Blue component
 *        3    |  X[7:0]|  Ball X position (low 8 bits)
 *        4    |  X[9:8]|  Ball X position (high 2 bits)
 *        5    |  Y[7:0]|  Ball Y position (low 8 bits)
 *        6    |  Y[9:8]|  Ball Y position (high 2 bits)
 *        7    | Radius |  Ball radius (in pixels)
 */

module vga_ball(input logic        clk,
	        input logic 	   reset,
		input logic [7:0]  writedata,
		input logic 	   write,
		input 		   chipselect,
		input logic [2:0]  address,

		output logic [7:0] VGA_R, VGA_G, VGA_B,
		output logic 	   VGA_CLK, VGA_HS, VGA_VS,
		                   VGA_BLANK_n,
		output logic 	   VGA_SYNC_n);

   logic [10:0]	   hcount;
   logic [9:0]     vcount;

   logic [7:0] 	   background_r, background_g, background_b;

   // Ball position and properties
   logic [9:0]     ball_x, ball_y;
   logic [7:0]     ball_radius;
   
   // For anti-tearing
   logic [9:0]     display_ball_x, display_ball_y;
   logic [7:0]     display_ball_radius;
   logic           vsync_reg;
   
   // Simplified square drawing
   logic [21:0]    squared_distance; // (x-x0)² + (y-y0)²
   logic           is_ball;
   
   // Pipe parameters
   parameter NUM_PIPES = 3;              // Number of pipes on screen at once
   parameter PIPE_WIDTH = 70;            // Width of pipes in pixels
   parameter PIPE_GAP_MIN = 120;         // Minimum gap between top and bottom pipes
   parameter PIPE_GAP_MAX = 200;         // Maximum gap between top and bottom pipes
   parameter PIPE_SPEED = 2;             // Pixels per frame the pipes move left
   parameter PIPE_SPAWN_X = 640;         // X position where pipes spawn
   parameter PIPE_DISTANCE = 250;        // Distance between consecutive pipes
   
   // Pipe state variables
   logic [9:0] pipe_x[NUM_PIPES];        // X positions of pipes
   logic [9:0] pipe_gap_y[NUM_PIPES];    // Y position of the center of each gap
   logic [9:0] pipe_gap_height[NUM_PIPES]; // Height of the gap for each pipe
   logic pipe_active[NUM_PIPES];         // Whether each pipe is currently active
   
   // Random number generation for gap heights
   logic [15:0] random_counter;
   logic is_pipe;  // Signal if current pixel is part of a pipe
	
   vga_counters counters(.clk50(clk), .*);

   // Function to generate pseudo-random number
   function [9:0] get_random;
      input [15:0] seed;
      begin
         // Simple LFSR-style random function
         get_random = ((seed ^ (seed >> 7) ^ (seed >> 13)) & 10'h3FF);
      end
   endfunction

   always_ff @(posedge clk)
     if (reset) begin
	background_r <= 8'h0;
	background_g <= 8'h0;
	background_b <= 8'h80;
        ball_x <= 10'd320;
        ball_y <= 10'd240;
        ball_radius <= 8'd10;
        
        // Initialize random counter
        random_counter <= 16'h1234;
        
        // Initialize pipes
        for (int i = 0; i < NUM_PIPES; i++) begin
            pipe_x[i] <= PIPE_SPAWN_X + i * PIPE_DISTANCE;
            pipe_gap_height[i] <= PIPE_GAP_MIN + (get_random(16'h1234 + i) % (PIPE_GAP_MAX - PIPE_GAP_MIN));
            pipe_gap_y[i] <= 100 + (get_random(16'h5678 + i) % 280); // Between 100-380
            pipe_active[i] <= 1;
        end
     end else if (chipselect && write)
       case (address)
	 3'h0 : background_r <= writedata;
	 3'h1 : background_g <= writedata;
	 3'h2 : background_b <= writedata;
         3'h3 : ball_x[7:0] <= writedata;
         3'h4 : ball_x[9:8] <= writedata[1:0];
         3'h5 : ball_y[7:0] <= writedata;
         3'h6 : ball_y[9:8] <= writedata[1:0];
         3'h7 : ball_radius <= writedata;
       endcase

   // Anti-tearing: Update display coordinates only during vertical blanking
   always_ff @(posedge clk) begin
       vsync_reg <= VGA_VS;
       
       if (VGA_VS && !vsync_reg) begin // Rising edge of vsync
         // Update bird position
         display_ball_x <= ball_x;
         display_ball_y <= ball_y;
         display_ball_radius <= ball_radius;
         
         // Update random seed
         random_counter <= random_counter + 1;
         
         // Update pipe positions
         for (int i = 0; i < NUM_PIPES; i++) begin
            if (pipe_active[i]) begin
               // Move pipe to the left
               pipe_x[i] <= pipe_x[i] - PIPE_SPEED;
               
               // If pipe moves off screen, reset it with new random gap
               if (pipe_x[i] <= 0) begin
                  pipe_x[i] <= PIPE_SPAWN_X;
                  // Use random values for gap height and position
                  pipe_gap_height[i] <= PIPE_GAP_MIN + (get_random(random_counter + i) % (PIPE_GAP_MAX - PIPE_GAP_MIN));
                  pipe_gap_y[i] <= 100 + (get_random(random_counter + i + 100) % 280); // Between 100-380
               end
            end
         end
       end
     end

   // Calculate squared distance for circle equation
   always_comb begin
     // Use hcount[10:1] for proper pixel column
     squared_distance = ({1'b0, hcount[10:1]} - {1'b0, display_ball_x}) * ({1'b0, hcount[10:1]} - {1'b0, display_ball_x}) + 
                        (vcount - display_ball_y) * (vcount - display_ball_y);
     is_ball = (squared_distance <= display_ball_radius * display_ball_radius);
     
     // Check if current pixel is part of a pipe
     is_pipe = 0;
     for (int i = 0; i < NUM_PIPES; i++) begin
        if (pipe_active[i]) begin
           // If within horizontal bounds of pipe
           if (hcount[10:1] >= pipe_x[i] && hcount[10:1] < pipe_x[i] + PIPE_WIDTH) begin
              // If NOT within the gap
              if (vcount < pipe_gap_y[i] - pipe_gap_height[i]/2 || 
                  vcount > pipe_gap_y[i] + pipe_gap_height[i]/2) begin
                 is_pipe = 1;
              end
           end
        end
     end
   end

   always_comb begin
      {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
      if (VGA_BLANK_n) begin
        if (is_pipe)
          // Pure green for pipes
          {VGA_R, VGA_G, VGA_B} = {8'h00, 8'hC0, 8'h00};
        else if (is_ball)
	      // White for ball/bird
	      {VGA_R, VGA_G, VGA_B} = {8'hff, 8'hff, 8'hff};
	    else
	      // Background color
	      {VGA_R, VGA_G, VGA_B} = {background_r, background_g, background_b};
      end
   end
	       
endmodule

module vga_counters(
 input logic 	     clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic 	     VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

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
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600
   
   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

   logic endOfLine;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else  	         hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;
       
   logic endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) &
		      !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
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
   assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
endmodule