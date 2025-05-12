/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Modified for Flappy Bird game implementation
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
 *        8    |  FLAP  |  Bird flap trigger (bit 0)
 */

module vga_ball(input logic        clk,
                input logic        reset,
                input logic [7:0]  writedata,
                input logic        write,
                input              chipselect,
                input logic [3:0]  address,

                output logic [7:0] VGA_R, VGA_G, VGA_B,
                output logic       VGA_CLK, VGA_HS, VGA_VS,
                                   VGA_BLANK_n,
                output logic       VGA_SYNC_n);

   logic [10:0]    hcount;
   logic [9:0]     vcount;

   logic [9:0] bird_y;
   logic signed [9:0] bird_velocity;
   logic [1:0] bird_frame;  // 2-bit index for animation frame (0,1,2)
   logic [7:0] animation_counter;
   logic vsync_reg;
   logic game_started;

   logic [18:0] bg_addr;
   logic [7:0] bg_color;

   logic [11:0] bird_addr;
   logic [7:0] bird_color;
   logic flap_latched;

   parameter BIRD_X = 100;
   parameter BIRD_WIDTH = 34;
   parameter BIRD_HEIGHT = 24;
    
   parameter GRAVITY = 1;
   parameter FLAP_STRENGTH = -16;
    
   // TEST MODE ADDITIONS
   logic [31:0] test_counter;
   parameter TEST_INTERVAL = 50000000; // About 1 second at 50 MHz
    
   vga_counters counters(.clk50(clk), .*);
    
   bg_rom bg_rom_inst (.address(bg_addr), .clock(clk), .data(8'b0), .wren(1'b0), .q(bg_color));
     
   // Bird sprite ROMs (one per frame)
   bird_rom0 bird0 (.address(bird_addr), .clock(clk), .q(bird_color0));
   bird_rom1 bird1 (.address(bird_addr), .clock(clk), .q(bird_color1));
   bird_rom2 bird2 (.address(bird_addr), .clock(clk), .q(bird_color2));

   logic [7:0] bird_color0, bird_color1, bird_color2;
   always_comb begin
     case (bird_frame)
        2'd0: bird_color = bird_color0;
        2'd1: bird_color = bird_color1;
        2'd2: bird_color = bird_color2;
        default: bird_color = bird_color0;
     endcase
   end
    
   // === TEST MODE - Auto flap timer ===
   always_ff @(posedge clk) begin
     if (reset) begin
        test_counter <= 0;
        flap_latched <= 0;
        game_started <= 1; // Start game immediately for testing
     end else begin
        // Auto-flap timer - triggers flap every TEST_INTERVAL cycles
        test_counter <= test_counter + 1;
        if (test_counter >= TEST_INTERVAL) begin
           test_counter <= 0;
           flap_latched <= 1;
        end else if (VGA_VS && !vsync_reg) begin
           flap_latched <= 0; // Reset flap after consumed during vsync
        end
     end
   end
    
   // Address calculation
   always_comb begin
       bg_addr = vcount * 640 + hcount[10:1];

       if (hcount[10:1] >= BIRD_X && hcount[10:1] < BIRD_X + BIRD_WIDTH &&
           vcount >= bird_y && vcount < bird_y + BIRD_HEIGHT) begin
           bird_addr = (vcount - bird_y) * BIRD_WIDTH + (hcount[10:1] - BIRD_X);
       end else begin
           bird_addr = 0;  // outside bird → address 0 (transparent)
       end
   end

   // Bird physics and animation
   always_ff @(posedge clk) begin
     vsync_reg <= VGA_VS;

     if (reset) begin
        bird_y <= 240;
        bird_velocity <= 0;
        bird_frame <= 0;
        animation_counter <= 0;
     end else if (VGA_VS && !vsync_reg) begin
        animation_counter <= animation_counter + 1;
        if (animation_counter == 10) begin
           animation_counter <= 0;
           bird_frame <= (bird_frame == 2) ? 0 : bird_frame + 1;
        end
        
        // TEST MODE - Always in game state
        // Apply flap if flap_latched is set
        if (flap_latched) begin
           bird_velocity <= FLAP_STRENGTH;
        end else begin
           bird_velocity <= bird_velocity + GRAVITY;
        end

        // Update bird position
        bird_y <= bird_y + bird_velocity;
        
        // Boundary checks
        if (bird_y < 0) bird_y <= 0;
        if (bird_y > 480 - BIRD_HEIGHT) bird_y <= 480 - BIRD_HEIGHT;
     end
   end

   // Output color
   always_comb begin
      {VGA_R, VGA_G, VGA_B} = 24'h000000;
      if (VGA_BLANK_n) begin
         if (hcount[10:1] >= BIRD_X && hcount[10:1] < BIRD_X + BIRD_WIDTH &&
             vcount >= bird_y && vcount < bird_y + BIRD_HEIGHT &&
             bird_color != 8'h00) begin
             // Bird pixel, apply R3 G3 B2 unpack
             VGA_R = {bird_color[7:5], 5'b00000};
             VGA_G = {bird_color[4:2], 5'b00000};
             VGA_B = {bird_color[1:0], 6'b000000};
         end else begin
             // Background pixel, apply B3 G3 R2 unpack
             VGA_B = {bg_color[7:5], 5'b00000};
             VGA_G = {bg_color[4:2], 5'b00000};
             VGA_R = {bg_color[1:0], 6'b000000};
         end
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