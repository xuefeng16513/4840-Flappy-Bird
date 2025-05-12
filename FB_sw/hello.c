#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <time.h>
#include <signal.h>
#include "usbkeyboard.h"
#include "vga_ball.h"

#define FLAP_KEY 0x2C  // USB keycode for spacebar
#define DEVICE_FILE "/dev/vga_ball"

// 游戏参数
#define GRAVITY 1                // 重力加速度
#define FLAP_FORCE -12           // 跳跃力度
#define SCREEN_WIDTH 640         // 屏幕宽度
#define SCREEN_HEIGHT 480        // 屏幕高度
#define INITIAL_PIPE_SPEED 2     // 初始管道速度
#define GAME_TICK_MS 20          // 游戏刷新率（毫秒）

// 全局变量用于信号处理
static int running = 1;
static int vga_fd = -1;
static struct libusb_device_handle *keyboard = NULL;

// 处理Ctrl+C信号
void handle_sigint(int sig) {
    printf("\nReceived SIGINT, cleaning up...\n");
    running = 0;
}

int main() {
    struct usb_keyboard_packet packet;
    uint8_t endpoint_address;
    int transferred;
    vga_ball_arg_t vla;
    
    // 游戏状态变量
    int bird_velocity = 0;
    int score = 0;
    int game_over = 0;
    time_t last_score_time;
    
    // 设置信号处理
    signal(SIGINT, handle_sigint);
    
    // 随机数种子初始化
    srand(time(NULL));

    // 打开USB键盘
    printf("Opening USB keyboard...\n");
    keyboard = openkeyboard(&endpoint_address);
    if (!keyboard) {
        fprintf(stderr, "Could not find a USB keyboard.\n");
        return 1;
    }

    // 打开VGA设备
    printf("Opening VGA Ball device...\n");
    vga_fd = open(DEVICE_FILE, O_RDWR);
    if (vga_fd < 0) {
        perror("Failed to open /dev/vga_ball");
        libusb_close(keyboard);
        return 1;
    }
    
    // 初始化游戏 - 设置天空蓝背景
    vla.background.red = 0x87;
    vla.background.green = 0xCE;
    vla.background.blue = 0xEB;
    if (ioctl(vga_fd, VGA_BALL_WRITE_BACKGROUND, &vla) == -1) {
        perror("ioctl(VGA_BALL_WRITE_BACKGROUND) failed");
        goto cleanup;
    }
    
    // 初始化鸟的位置
    vla.ball.x = 100;
    vla.ball.y = 240;
    vla.ball.radius = 15;
    if (ioctl(vga_fd, VGA_BALL_WRITE_BALL, &vla) == -1) {
        perror("ioctl(VGA_BALL_WRITE_BALL) failed");
        goto cleanup;
    }
    
    // 初始化柱子配置
    vla.pipe_config.width = 50;        // 柱子宽度
    vla.pipe_config.gap_height = 150;  // 柱子间隙高度
    vla.pipe_config.speed = INITIAL_PIPE_SPEED;  // 初始速度
    vla.pipe_config.enable = 1;        // 启用柱子移动
    
    if (ioctl(vga_fd, VGA_BALL_WRITE_PIPE_CONFIG, &vla) == -1) {
        perror("ioctl(VGA_BALL_WRITE_PIPE_CONFIG) failed");
        goto cleanup;
    }
    
    printf("\n===== FLAPPY BIRD GAME =====\n");
    printf("Press SPACE to flap the bird.\n");
    printf("Avoid the pipes and survive as long as possible!\n");
    printf("Press ESC to quit the game.\n");
    
    // 初始化计分器
    last_score_time = time(NULL);
    
    // 主游戏循环
    while (running && !game_over) {
        // 读取键盘输入 (非阻塞)
        int r = libusb_interrupt_transfer(
            keyboard, 
            endpoint_address,
            (unsigned char *)&packet, 
            sizeof(packet),
            &transferred, 
            1  // 1毫秒超时，实现非阻塞
        );
        
        // 处理按键
        if (r == 0 && transferred == sizeof(packet)) {
            uint8_t code = packet.keycode[0];
            
            if (code == FLAP_KEY) {
                // 鸟跳跃
                bird_velocity = FLAP_FORCE;
                
                // 发送flap信号到FPGA
                vla.flap = 1;
                if (ioctl(vga_fd, VGA_BALL_WRITE_FLAP, &vla) == -1) {
                    perror("ioctl(VGA_BALL_WRITE_FLAP) failed");
                }
                
                // 重置flap信号（下次准备）
                vla.flap = 0;
            }
            
            if (code == 0x29) {  // ESC键
                printf("Game terminated by user.\n");
                break;
            }
        }
        
        // 更新鸟的位置
        ioctl(vga_fd, VGA_BALL_READ_BALL, &vla);
        
        // 应用重力
        bird_velocity += GRAVITY;
        vla.ball.y += bird_velocity;
        
        // 边界检查
        if (vla.ball.y < vla.ball.radius) {
            vla.ball.y = vla.ball.radius;
            bird_velocity = 0;
        } else if (vla.ball.y > SCREEN_HEIGHT - vla.ball.radius) {
            vla.ball.y = SCREEN_HEIGHT - vla.ball.radius;
            bird_velocity = 0;
            game_over = 1;  // 碰到地面，游戏结束
            printf("Game over! Bird hit the ground.\n");
        }
        
        // 更新鸟的位置
        ioctl(vga_fd, VGA_BALL_WRITE_BALL, &vla);
        
        // 计分 - 每秒增加分数
        time_t current_time = time(NULL);
        if (current_time > last_score_time) {
            score++;
            printf("Score: %d\n", score);
            last_score_time = current_time;
            
            // 每10分增加一次难度（加快柱子速度）
            if (score % 10 == 0 && score > 0) {
                ioctl(vga_fd, VGA_BALL_READ_PIPE_CONFIG, &vla);
                if (vla.pipe_config.speed < 10) {  // 限制最大速度
                    vla.pipe_config.speed++;
                    ioctl(vga_fd, VGA_BALL_WRITE_PIPE_CONFIG, &vla);
                    printf("Level up! Pipe speed increased to %d\n", vla.pipe_config.speed);
                }
                
                // 随机调整间隙高度（增加游戏变化）
                int gap_adjust = -20 + (rand() % 41);  // -20到+20的随机调整
                vla.pipe_config.gap_height = 150 + gap_adjust;
                if (vla.pipe_config.gap_height < 100) vla.pipe_config.gap_height = 100;
                if (vla.pipe_config.gap_height > 200) vla.pipe_config.gap_height = 200;
                ioctl(vga_fd, VGA_BALL_WRITE_PIPE_CONFIG, &vla);
            }
        }
        
        // 游戏循环延迟
        usleep(GAME_TICK_MS * 1000);
    }
    
    // 游戏结束 - 停止柱子移动
    ioctl(vga_fd, VGA_BALL_READ_PIPE_CONFIG, &vla);
    vla.pipe_config.enable = 0;
    ioctl(vga_fd, VGA_BALL_WRITE_PIPE_CONFIG, &vla);
    
    printf("\n===== GAME SUMMARY =====\n");
    printf("Final score: %d\n", score);
    printf("Thank you for playing!\n");

cleanup:
    // 清理资源
    if (vga_fd >= 0)
        close(vga_fd);
    if (keyboard)
        libusb_close(keyboard);
    return 0;
}