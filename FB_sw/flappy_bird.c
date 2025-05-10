#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdbool.h>
#include "vga_flappy.h"
#include "usbkeyboard.h"

#define MAP_SIZE 4096UL
#define HW_REGS_BASE 0xFF200000  // LW bridge base address

// space key
#define USB_SPACE_KEY 0x2C

int main() {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open");
        return -1;
    }

    void *h2p_lw_virtual_base = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE,
                                     MAP_SHARED, fd, HW_REGS_BASE);
    if (h2p_lw_virtual_base == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return -1;
    }

    // initial keyboard
    uint8_t endpoint_address;
    struct libusb_device_handle *keyboard = openkeyboard(&endpoint_address);
    if (!keyboard) {
        fprintf(stderr, "Error: Could not find USB keyboard\n");
        munmap(h2p_lw_virtual_base, MAP_SIZE);
        close(fd);
        return -1;
    }

    volatile int *bird_y    = (int *)(h2p_lw_virtual_base + BIRD_Y_OFFSET);
    volatile int *pillar_x  = (int *)(h2p_lw_virtual_base + PILLAR_X_OFFSET);
    volatile int *score     = (int *)(h2p_lw_virtual_base + SCORE_OFFSET);
    volatile int *game_over = (int *)(h2p_lw_virtual_base + GAME_OVER_OFFSET);

    int y = SCREEN_HEIGHT / 2;    // initial pos
    int velocity = 0;             // initial speed 
    int x = SCREEN_WIDTH;         
    int current_score = 0;        // game score
    bool is_game_over = false;    // game state
    
    struct usb_keyboard_packet packet;
    int transferred;

    printf("Game started! Press SPACE to jump.\n");

    while (!is_game_over) {
        // read keyboard
        libusb_interrupt_transfer(keyboard, endpoint_address,
                                 (unsigned char *) &packet, sizeof(packet),
                                 &transferred, 1);
        
        // check if press space 
        bool space_pressed = false;
        for (int i = 0; i < 6; i++) {
            if (packet.keycode[i] == USB_SPACE_KEY) {
                space_pressed = true;
                break;
            }
        }
        
        velocity += GRAVITY;
        
        if (space_pressed) {
            velocity = -JUMP_STRENGTH;
            printf("Jump!\n");
        }

        // update bird pos
        y += velocity;
        
        // prevent bird out of screen
        if (y < 0) y = 0;
        if (y > SCREEN_HEIGHT - BIRD_HEIGHT) y = SCREEN_HEIGHT - BIRD_HEIGHT;

        // update pillar pos
        x -= PILLAR_SPEED;
        if (x < -PILLAR_WIDTH) {
            x = SCREEN_WIDTH;  // reset pillar pos
            current_score++;
        }
        
        // check collision
        if (checkCollision(x, y)) {
            is_game_over = true;
            printf("Game Over! Final Score: %d\n", current_score);
        }

        // update reg
        *bird_y = y;
        *pillar_x = x;
        *score = current_score;
        *game_over = is_game_over ? 1 : 0;

        usleep(FRAME_DELAY);
    }

    libusb_release_interface(keyboard, 0);
    libusb_close(keyboard);
    libusb_exit(NULL);
    
    munmap(h2p_lw_virtual_base, MAP_SIZE);
    close(fd);
    return 0;
}

bool checkCollision(int pillar_x, int bird_y) {
    if (pillar_x <= BIRD_X + BIRD_WIDTH && pillar_x + PILLAR_WIDTH >= BIRD_X) {
        if (bird_y <= PILLAR_GAP_TOP || bird_y + BIRD_HEIGHT >= PILLAR_GAP_BOTTOM) {
            return true;
        }
    }
    return false;
}