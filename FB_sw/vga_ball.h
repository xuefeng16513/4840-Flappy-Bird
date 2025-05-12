#ifndef _VGA_BALL_H
#define _VGA_BALL_H
#include <linux/ioctl.h>

/* 背景颜色结构体 */
typedef struct {
    unsigned char red, green, blue;
} vga_ball_color_t;

/* 球（鸟）位置结构体 */
typedef struct {
    unsigned short x, y;
    unsigned char radius;
} vga_ball_position_t;

/* 柱子配置结构体 */
typedef struct {
    unsigned char width;        /* 柱子宽度 */
    unsigned short gap_height;  /* 柱子间隙高度 */
    unsigned char speed;        /* 柱子移动速度 */
    unsigned char enable;       /* 启用标志 (1=启用, 0=禁用) */
} vga_ball_pipe_config_t;

/* 传递给内核的参数结构体 */
typedef struct {
    vga_ball_color_t background;     /* 背景颜色 */
    vga_ball_position_t ball;        /* 球（鸟）位置 */
    unsigned char flap;              /* Flap控制信号 */
    vga_ball_pipe_config_t pipe_config; /* 柱子配置 */
} vga_ball_arg_t;

/* IOCTL定义 */
#define VGA_BALL_MAGIC 'q'

/* ioctl命令列表 */
/* 背景颜色读写 */
#define VGA_BALL_WRITE_BACKGROUND _IOW(VGA_BALL_MAGIC, 1, vga_ball_arg_t)
#define VGA_BALL_READ_BACKGROUND _IOR(VGA_BALL_MAGIC, 2, vga_ball_arg_t)

/* 球（鸟）位置读写 */
#define VGA_BALL_WRITE_BALL _IOW(VGA_BALL_MAGIC, 3, vga_ball_arg_t)
#define VGA_BALL_READ_BALL _IOR(VGA_BALL_MAGIC, 4, vga_ball_arg_t)

/* Flap控制 */
#define VGA_BALL_WRITE_FLAP _IOW(VGA_BALL_MAGIC, 5, vga_ball_arg_t)

/* 柱子配置读写 */
#define VGA_BALL_WRITE_PIPE_CONFIG _IOW(VGA_BALL_MAGIC, 6, vga_ball_arg_t)
#define VGA_BALL_READ_PIPE_CONFIG _IOR(VGA_BALL_MAGIC, 7, vga_ball_arg_t)

#endif /* _VGA_BALL_H */