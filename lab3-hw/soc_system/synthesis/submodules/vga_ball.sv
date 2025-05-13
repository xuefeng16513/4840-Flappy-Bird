/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Modified for lab 3: Displays a movable square instead of a circle
 * to simplify debugging
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
module vga_counters(
    input  logic        clk50, reset,
    output logic [10:0] hcount,
    output logic [9:0]  vcount,
    output logic        VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n
);
    parameter HACTIVE      = 11'd1280,
              HFRONT_PORCH = 11'd32,
              HSYNC        = 11'd192,
              HBACK_PORCH  = 11'd96,
              HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC + HBACK_PORCH;

    parameter VACTIVE      = 10'd480,
              VFRONT_PORCH = 10'd10,
              VSYNC        = 10'd2,
              VBACK_PORCH  = 10'd33,
              VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC + VBACK_PORCH;

    logic endOfLine, endOfField;

    always_ff @(posedge clk50 or posedge reset)
        if (reset)
            hcount <= 0;
        else if (endOfLine)
            hcount <= 0;
        else
            hcount <= hcount + 1;

    assign endOfLine = hcount == HTOTAL - 1;

    always_ff @(posedge clk50 or posedge reset)
        if (reset)
            vcount <= 0;
        else if (endOfLine)
            if (endOfField)
                vcount <= 0;
            else
                vcount <= vcount + 1;

    assign endOfField = vcount == VTOTAL - 1;

    assign VGA_HS      = !( (hcount[10:8] == 3'b101) & !(hcount[7:5] == 3'b111) );
    assign VGA_VS      = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2 );
    assign VGA_SYNC_n  = 1'b0;
    assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
                         !( vcount[9] | (vcount[8:5] == 4'b1111) );
    assign VGA_CLK = hcount[0];
endmodule

module vga_ball(
    input logic        clk,
    input logic        reset,
    input logic [7:0]  writedata,
    input logic        write,
    input              chipselect,
    input logic [2:0]  address,

    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic       VGA_CLK, VGA_HS, VGA_VS,
                       VGA_BLANK_n,
    output logic       VGA_SYNC_n
);

    logic [10:0] hcount;
    logic [9:0]  vcount;

    logic [9:0] bird_y;
	 logic [9:0] new_y;
    logic [1:0] bird_frame;
    logic [7:0] animation_counter;

    logic [18:0] bg_addr;
    logic [7:0]  bg_color;

    logic [11:0] bird_addr;
    logic [7:0]  bird_color;

    logic [9:0] scroll_offset;
    logic [23:0] scroll_counter;

    logic [7:0] bird_color_reg;
    logic collision;
	 
	 logic [15:0] score;


    parameter BIRD_X = 100;
    parameter BIRD_WIDTH = 34;
    parameter BIRD_HEIGHT = 24;
	 
	 parameter GRAVITY = 1;
	 parameter FLAP_STRENGTH = -16;
	 parameter TEST_INTERVAL = 50_000_000;
	 
	 logic signed [9:0] bird_velocity;
	 logic        vsync_reg, flap_latched;
    logic [31:0] test_counter;

    vga_counters counters (
        .clk50(clk),
        .reset(reset),
        .hcount(hcount),
        .vcount(vcount),
        .VGA_CLK(VGA_CLK),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_n(VGA_BLANK_n),
        .VGA_SYNC_n(VGA_SYNC_n)
    );

    bg_rom    bg_rom_inst (.address(bg_addr), .clock(clk), .data(8'b0), .wren(1'b0), .q(bg_color));
    bird_rom0 bird0       (.address(bird_addr), .clock(clk), .q(bird_color0));
    bird_rom1 bird1       (.address(bird_addr), .clock(clk), .q(bird_color1));
    bird_rom2 bird2       (.address(bird_addr), .clock(clk), .q(bird_color2));

    logic [7:0] bird_color0, bird_color1, bird_color2;

    always_ff @(posedge clk) begin
        case (bird_frame)
            2'd0: bird_color_reg <= bird_color0;
            2'd1: bird_color_reg <= bird_color1;
            2'd2: bird_color_reg <= bird_color2;
            default: bird_color_reg <= bird_color0;
        endcase
    end

    always_comb begin
        logic [9:0] bg_col;
        bg_col = (hcount[10:1] + scroll_offset);
        if(bg_col < 640)
            bg_addr = vcount * 640 + bg_col;
        else
            bg_addr = vcount * 640 + (bg_col - 640);

        if (hcount[10:1] >= BIRD_X && hcount[10:1] < BIRD_X + BIRD_WIDTH &&
            vcount >= bird_y && vcount < bird_y + BIRD_HEIGHT)
            bird_addr = (vcount - bird_y) * BIRD_WIDTH + (hcount[10:1] - BIRD_X);
        else
            bird_addr = 0;
    end

    //管道结构参数（周日晚调试，左侧柱子左边触边缘 就立刻消失）
    parameter PIPE_WIDTH = 52;
    parameter GAP_HEIGHT = 90;      
    parameter PIPE_COUNT = 5;
    parameter PIPE_SPACING = 127; //前一条柱子最左边到前一条柱子最右边，实际间隔127-52 = 75

    typedef struct packed {
        logic [9:0] x; 
        logic [8:0] gap_y;
    } pipe_t;

    pipe_t pipes[PIPE_COUNT];

    integer i;
    logic [9:0] max_pipe_x;

    // === LFSR 随机数生成 ===
    logic [7:0] lfsr;
    logic       lfsr_enable;
	 

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 8'h5A;
        else if (lfsr_enable)
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            bird_y <= 240;
				bird_velocity <= 0;
				vsync_reg <= 1'b0;
				flap_latched <= 1'b0;
				test_counter <= 32'd0;
				
            bird_frame <= 0;
            animation_counter <= 0;
            scroll_offset <= 0;
            scroll_counter <= 0;
				score <= 16'd0;

            for (i = 0; i < PIPE_COUNT; i = i + 1) begin
                pipes[i].x <= 440 + i * PIPE_SPACING;
                pipes[i].gap_y <= 100 + i * 40;
            end
        end else begin
		      // —— 垂直同步沿检测 —— 
            vsync_reg <= VGA_VS;

            // —— 自动测试扇动计时 —— 
				
            test_counter <= test_counter + 1;
            if (test_counter >= TEST_INTERVAL) begin
                test_counter <= 0;
                flap_latched <= 1;
            end else if (VGA_VS && !vsync_reg) begin
                flap_latched <= 0;
            end

            // —— 每个 VSYNC 帧到来时，更新鸟的速度和位置 —— 
            if (VGA_VS && !vsync_reg) begin
                // 扇动时直接给一个向上初速度，否则累加重力
                if (flap_latched)
                    bird_velocity <= FLAP_STRENGTH;
                else
                    bird_velocity <= bird_velocity + GRAVITY;

                // 速度作用到位置
                bird_y <= bird_y + bird_velocity;

                // 边界钳位
                if (bird_y <= 0)
                    new_y <= 0;
                if (bird_y >= 440 - BIRD_HEIGHT)
                    new_y <= 440 - BIRD_HEIGHT;
				    bird_y <= new_y;
            end
				
            animation_counter <= animation_counter + 1;
            if (animation_counter == 24'd10_000_00 - 1) begin
                animation_counter <= 0;
                if(bird_frame == 2)
                    bird_frame <= 0;
                else
                    bird_frame <= bird_frame + 1;
            end else begin
                animation_counter <= animation_counter + 1;
            end
            
            if (!collision) begin
                scroll_counter <= scroll_counter + 1;
                if(scroll_counter == 24'd1_000_000) begin
                    scroll_offset <= scroll_offset + 1;
                    scroll_counter <= 0;
                    lfsr_enable <= 1;

                // 找出最右边的柱子
                    max_pipe_x = 0;
                    for (i = 0; i < PIPE_COUNT; i = i + 1)
                        if (pipes[i].x > max_pipe_x)
                            max_pipe_x = pipes[i].x;

						  for(i = 0; i < PIPE_COUNT; i = i + 1) begin
						      if(pipes[i].x + PIPE_WIDTH == BIRD_X) begin
								    score <= score + 1;
							   end
						  end

                    for (i = 0; i < PIPE_COUNT; i = i + 1) begin
                        if (pipes[i].x <= 1) begin
                            pipes[i].x <= max_pipe_x + PIPE_SPACING;
                            pipes[i].gap_y <= 80 + (lfsr % (440 - GAP_HEIGHT - 80));
                        end else begin
                            pipes[i].x <= pipes[i].x - 1;
                        end
                    end
                end else begin
                    lfsr_enable <= 0;
                end
            end    
        end
    end

    logic [15:0] ground_addr;
    logic [7:0]  ground_color;

    base_rom ground_inst (.address(ground_addr), .clock(clk), .q(ground_color));

    always_comb begin
        if (vcount >= 440 && vcount < 480)
            ground_addr = (vcount - 440) * 640 + ((hcount[10:1] + scroll_offset) % 640);
        else
            ground_addr = 0;
    end

    logic pipe_pixel;

    always_comb begin
        pipe_pixel = 0;
        for (i = 0; i < PIPE_COUNT; i = i + 1) begin
            if (hcount[10:1] >= pipes[i].x && hcount[10:1] < pipes[i].x + PIPE_WIDTH) begin
                if ((vcount < pipes[i].gap_y || vcount > pipes[i].gap_y + GAP_HEIGHT) &&
                    vcount < 440)
                    pipe_pixel = 1;
            end
        end
    end

    always_comb begin
        collision = 0; 
    //上边界碰撞
        if (bird_y < 0)
            collision = 1;
    //地面碰撞
        if (bird_y + BIRD_HEIGHT > 440)
            collision = 1;
    //柱子碰撞
        for (i = 0; i < PIPE_COUNT; i = i + 1) begin
        // 判断是否和这根柱子在 X 方向上有重叠
            if (BIRD_X + BIRD_WIDTH > pipes[i].x &&
                BIRD_X < pipes[i].x + PIPE_WIDTH) begin

            // 如果小鸟完全不在 gap 区间内 ⇒ 撞柱子
                if (bird_y < pipes[i].gap_y ||
                    bird_y + BIRD_HEIGHT > pipes[i].gap_y + GAP_HEIGHT)
                    collision = 1;
            end
        end
    end
  

    always_comb begin
        {VGA_R, VGA_G, VGA_B} = 24'h000000;

        if (VGA_BLANK_n) begin
            if (hcount[10:1] >= BIRD_X && hcount[10:1] < BIRD_X + BIRD_WIDTH &&
                vcount >= bird_y && vcount < bird_y + BIRD_HEIGHT &&
                bird_color_reg != 8'h00) begin
                VGA_R = {bird_color_reg[7:5], 5'b00000};
                VGA_G = {bird_color_reg[4:2], 5'b00000};
                VGA_B = {bird_color_reg[1:0], 6'b000000};
            end else if (pipe_pixel) begin
                VGA_R = 8'h00;
                VGA_G = 8'hFF;
                VGA_B = 8'h00;
            end else if (vcount >= 440 && vcount < 480) begin
                VGA_R = ground_color;
                VGA_G = ground_color;
                VGA_B = ground_color;
            end else begin
                VGA_B = {bg_color[7:5], 5'b00000};
                VGA_G = {bg_color[4:2], 5'b00000};
                VGA_R = {bg_color[1:0], 6'b000000};
            end
        end
    end
endmodule