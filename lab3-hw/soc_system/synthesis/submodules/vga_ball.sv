/*
 * Avalon memory-mapped peripheral for Flappy Bird game
 * Fixed version
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

   // Constants for game mechanics
   parameter BIRD_X = 100;
   parameter BIRD_WIDTH = 34;
   parameter BIRD_HEIGHT = 24;
    
   parameter GRAVITY = 1;
   parameter FLAP_STRENGTH = -16;
	
   parameter PIPE_WIDTH = 52;
   parameter PIPE_HEIGHT = 320;
   parameter GAP_HEIGHT = 100;
   parameter NUM_PIPES = 3;
   parameter PIPE_SPACING = 200; // horizontal space between pipes
	
   // VGA timing signals
   logic [10:0]    hcount;
   logic [9:0]     vcount;

   // Bird state
   logic [9:0] bird_y;
   logic signed [9:0] bird_velocity;
   logic [1:0] bird_frame;  // 2-bit index for animation frame (0,1,2)
   logic [7:0] animation_counter;
   logic vsync_reg;
   logic game_started;

   // Sprite addresses and colors
   logic [18:0] bg_addr;
   logic [7:0] bg_color;

   logic [11:0] bird_addr;
   logic [7:0] bird_color;
   logic [7:0] bird_color0, bird_color1, bird_color2;
	
   logic [14:0] pipe_addr;
   logic [7:0]  pipe_color;
	
   // Pipe state
   logic [9:0] pipe_x[NUM_PIPES];     // x-position of each pipe pair
   logic [9:0] pipe_gap_y[NUM_PIPES]; // y-position of the top of the gap
	logic [9:0] top_offset;
	logic [9:0] bot_offset;
   logic [9:0] lfsr = 10'h3FF;        // Non-zero initial value for LFSR
   logic pixel_drawn;
   
   // Input handling
   logic flap_latched;
   logic flap_from_keyboard; // Signal from keyboard input

   // Instantiate modules
   vga_counters counters(.clk50(clk), .*);
    
   bg_rom bg_rom_inst (.address(bg_addr), .clock(clk), .data(8'b0), .wren(1'b0), .q(bg_color));
     
   // Bird sprite ROMs (one per frame)
   bird_rom0 bird0 (.address(bird_addr), .clock(clk), .q(bird_color0));
   bird_rom1 bird1 (.address(bird_addr), .clock(clk), .q(bird_color1));
   bird_rom2 bird2 (.address(bird_addr), .clock(clk), .q(bird_color2));
	
   pipe_rom pipe_inst (.address(pipe_addr), .clock(clk), .data(8'b0), .wren(1'b0), .q(pipe_color));

   // Bird animation frame selection
   always_comb begin
     case (bird_frame)
        2'd0: bird_color = bird_color0;
        2'd1: bird_color = bird_color1;
        2'd2: bird_color = bird_color2;
        default: bird_color = bird_color0;
     endcase
   end
   
   // Process input from keyboard through register 8
   always_ff @(posedge clk) begin
     if (reset) begin
        flap_from_keyboard <= 0;
     end else if (chipselect && write && address == 4'h8) begin
        // Receive flap command from software
        flap_from_keyboard <= writedata[0];
     end else if (VGA_VS && !vsync_reg) begin
        // Reset after vertical sync (frame update)
        flap_from_keyboard <= 0;
     end
   end
   
   // Combined flap signal - either from keyboard or auto-flap for testing
   // USE THIS FOR NORMAL GAMEPLAY WITH KEYBOARD
   always_comb begin
      flap_latched = flap_from_keyboard;
   end
   
   // AUTO-FLAP FOR TESTING - UNCOMMENT THIS SECTION AND COMMENT OUT THE ABOVE SECTION
   /*
   logic [31:0] test_counter;
   parameter TEST_INTERVAL = 50000000; // About 1 second at 50 MHz
   
   always_ff @(posedge clk) begin
      if (reset) begin
         test_counter <= 0;
      end else begin
         test_counter <= test_counter + 1;
         if (test_counter >= TEST_INTERVAL) begin
            test_counter <= 0;
            flap_latched <= 1;
         end else if (VGA_VS && !vsync_reg) begin
            flap_latched <= 0;
         end
      end
   end
   */
    
   // Initialize and update pipe positions
   always_ff @(posedge clk) begin
      if (reset) begin
         // Initialize pipe positions
         for (int i = 0; i < NUM_PIPES; i++) begin
            pipe_x[i] <= 640 + i * PIPE_SPACING;  // Start pipes off-screen to the right
            pipe_gap_y[i] <= 150 + i * 50;        // Stagger gap heights
         end
         lfsr <= 10'h3FF;  // Non-zero initial value
         
         // CRITICAL FIX: Force game to start immediately for testing
         // game_started <= 1;  // This makes pipes move immediately
      end
      else if (VGA_VS && !vsync_reg && game_started) begin
         // Only move pipes when game has started
         for (int i = 0; i < NUM_PIPES; i++) begin
            if (pipe_x[i] <= 0) begin
               // Move pipe to right side of screen when it goes off left edge
               pipe_x[i] <= 640 + ((NUM_PIPES - 1) * PIPE_SPACING);
               
               // Update random number generator
               lfsr <= {lfsr[8:0], lfsr[9] ^ lfsr[6]};
               
               // Set new gap position with some constraints to keep it on screen
               pipe_gap_y[i] <= 80 + (lfsr % (480 - GAP_HEIGHT - 160));
            end
            else begin
               // Move pipe left by 2 pixels per frame (faster movement is easier to see)
               pipe_x[i] <= pipe_x[i] - 2;
            end
         end
      end
   end
    
   // Calculate sprite addresses
   always_comb begin
      // Background address
      bg_addr = vcount * 640 + hcount[10:1];

      // Bird sprite address
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
         // Note: game_started is set in pipe initialization block
      end else if (VGA_VS && !vsync_reg) begin
         // Update animation frame
         animation_counter <= animation_counter + 1;
         if (animation_counter == 10) begin
            animation_counter <= 0;
            bird_frame <= (bird_frame == 2) ? 0 : bird_frame + 1;
         end
         
         if (!game_started) begin
            // Waiting for first flap to start game
            if (flap_latched) begin
               game_started <= 1;
               bird_velocity <= FLAP_STRENGTH;
            end
         end else begin
            // Game is running - apply physics
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
   end

   // Rendering logic
   always_comb begin
      {VGA_R, VGA_G, VGA_B} = 24'h000000;
      pixel_drawn = 0;
      pipe_addr = 15'd0;
      top_offset = '0;
      bot_offset = '0;
      
      if (VGA_BLANK_n) begin
         // Draw bird (highest priority)
         if (hcount[10:1] >= BIRD_X && hcount[10:1] < BIRD_X + BIRD_WIDTH &&
             vcount >= bird_y && vcount < bird_y + BIRD_HEIGHT &&
             bird_color != 8'h00) begin
             // Bird pixel (non-transparent)
             VGA_R = {bird_color[7:5], 5'b00000};
             VGA_G = {bird_color[4:2], 5'b00000};
             VGA_B = {bird_color[1:0], 6'b000000};
             pixel_drawn = 1;
         end else begin
            // Check if we need to draw a pipe
            for (int i = 0; i < NUM_PIPES; i++) begin
               if ((hcount[10:1] >= pipe_x[i]) && (hcount[10:1] < pipe_x[i] + PIPE_WIDTH)) begin
                  // Current pixel is within this pipe's x-range
                  
                  // Top pipe: from top of screen to top of gap
                  if (vcount < pipe_gap_y[i]) begin
                     // FIXED: Simply use modulo to wrap within sprite height
                     top_offset = vcount % PIPE_HEIGHT;
                     pipe_addr = (top_offset * PIPE_WIDTH) + (hcount[10:1] - pipe_x[i]);
                     
                     // Only draw if pipe color isn't transparent
                     if (pipe_color != 8'h00) begin
                        VGA_R = {pipe_color[7:5], 5'b00000};
                        VGA_G = {pipe_color[4:2], 5'b00000};
                        VGA_B = {pipe_color[1:0], 6'b000000};
                        pixel_drawn = 1;
                     end
                  end
                  // Bottom pipe: from bottom of gap to bottom of screen
                  else if (vcount > (pipe_gap_y[i] + GAP_HEIGHT)) begin
                     // FIXED: Use modulo to wrap within sprite height
                     bot_offset = (vcount - (pipe_gap_y[i] + GAP_HEIGHT)) % PIPE_HEIGHT;
                     
                     // Flip sprite vertically for bottom pipe
                     pipe_addr = ((PIPE_HEIGHT - 1 - bot_offset) * PIPE_WIDTH) + (hcount[10:1] - pipe_x[i]);
                     
                     // Only draw if pipe color isn't transparent
                     if (pipe_color != 8'h00) begin
                        VGA_R = {pipe_color[7:5], 5'b00000};
                        VGA_G = {pipe_color[4:2], 5'b00000};
                        VGA_B = {pipe_color[1:0], 6'b000000};
                        pixel_drawn = 1;
                     end
                  end
               end
            end
         end
         
         // Draw background if no other pixel was drawn
         if (!pixel_drawn) begin
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