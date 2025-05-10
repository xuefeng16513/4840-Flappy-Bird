#ifndef VGA_FLAPPY_H
#define VGA_FLAPPY_H

// VGA Controller Register Offsets (from base address)
#define BIRD_Y_OFFSET     0x00
#define PILLAR_X_OFFSET   0x04
#define SCORE_OFFSET      0x08
#define GAME_OVER_OFFSET  0x0C

// game info
#define SCREEN_HEIGHT     480
#define SCREEN_WIDTH      640
#define GRAVITY           1
#define JUMP_STRENGTH     10
#define PILLAR_SPEED      2
#define FRAME_DELAY       30000   // ms

// bird size
#define BIRD_WIDTH        30
#define BIRD_HEIGHT       20
#define BIRD_X            100     // bird pos

// pillar size
#define PILLAR_WIDTH      50
#define PILLAR_GAP_HEIGHT 150     // gap size
#define PILLAR_GAP_TOP    150     
#define PILLAR_GAP_BOTTOM (PILLAR_GAP_TOP + PILLAR_GAP_HEIGHT)

// check collision
bool checkCollision(int pillar_x, int bird_y);

#endif