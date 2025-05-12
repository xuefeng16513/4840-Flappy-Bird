#ifndef _VGA_BALL_H
#define _VGA_BALL_H

#include <linux/ioctl.h>

#define VGA_BALL_DIGITS 16

typedef struct {
  unsigned char digit;    /* 0, 1, .. , VGA_BALL_DIGITS - 1 */
  unsigned int xPillar1; /* LSB is segment a, MSB is decimal point */
  unsigned int xPillar2;
  unsigned int xPillar3;
  unsigned int hPillar1;
  unsigned int hPillar2;
  unsigned int hPillar3;
  unsigned int score;
  unsigned int move;
  unsigned int bird;
  unsigned int game_info1;
  unsigned int game_info2;

  //unsigned int otherInfo;
} vga_ball_arg_t;

#define VGA_BALL_MAGIC 'q'

/* ioctls and their arguments */
#define VGA_BALL_WRITE_DIGIT _IOW(VGA_BALL_MAGIC, 1, vga_ball_arg_t *)
#define VGA_BALL_READ_DIGIT  _IOWR(VGA_BALL_MAGIC, 2, vga_ball_arg_t *)

#endif
