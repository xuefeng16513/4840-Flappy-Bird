#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <time.h>
#include "usbkeyboard.h"
#include "vga_ball.h"

#define FLAP_KEY 0x2C  // USB keycode for spacebar
#define DEVICE_FILE "/dev/vga_ball"
#define GRAVITY_INTERVAL 50000 // Microseconds, controls gravity update frequency

int main() {
    struct libusb_device_handle *keyboard;
    struct usb_keyboard_packet packet;
    uint8_t endpoint_address;
    int transferred;
    int vga_fd;
    struct timespec last_update, current_time;
    long elapsed_us;

    // Initialize time
    clock_gettime(CLOCK_MONOTONIC, &last_update);

    // Open USB keyboard
    printf("Opening USB keyboard...\n");
    keyboard = openkeyboard(&endpoint_address);
    if (!keyboard) {
        fprintf(stderr, "Could not find a USB keyboard.\n");
        return 1;
    }

    // Open VGA device
    printf("Opening VGA Ball device...\n");
    vga_fd = open(DEVICE_FILE, O_RDWR);
    if (vga_fd < 0) {
        perror("Failed to open /dev/vga_ball");
        return 1;
    }

    // Initialize/reset game
    if (ioctl(vga_fd, VGA_BALL_RESET_GAME, NULL) == -1) {
        perror("ioctl(VGA_BALL_RESET_GAME) failed");
        return 1;
    }

    printf("Flappy Bird Game Started!\n");
    printf("Press SPACE to flap the bird. Press ESC to quit.\n");

    // Main game loop
    while (1) {
        // Process keyboard input
        libusb_interrupt_transfer(keyboard, endpoint_address,
            (unsigned char *)&packet, sizeof(packet),
            &transferred, 0);

        if (transferred == sizeof(packet)) {
            uint8_t code = packet.keycode[0];

            if (code == FLAP_KEY) {
                // Trigger the flap command to FPGA
                if (ioctl(vga_fd, VGA_BALL_FLAP, NULL) == -1) {
                    perror("ioctl(VGA_BALL_FLAP) failed");
                } else {
                    printf("Flap triggered!\n");
                }
            }

            if (code == 0x29) {  // ESC key
                printf("Exiting...\n");
                break;
            }
        }

        // Get current time
        clock_gettime(CLOCK_MONOTONIC, &current_time);
        
        // Calculate elapsed microseconds
        elapsed_us = (current_time.tv_sec - last_update.tv_sec) * 1000000 +
                    (current_time.tv_nsec - last_update.tv_nsec) / 1000;
        
        // If enough time has passed, update game state (apply gravity)
        if (elapsed_us >= GRAVITY_INTERVAL) {
            if (ioctl(vga_fd, VGA_BALL_UPDATE_GAME, NULL) == -1) {
                perror("ioctl(VGA_BALL_UPDATE_GAME) failed");
            }
            last_update = current_time;
        }

        usleep(10000);  // Avoid hogging CPU
    }

    close(vga_fd);
    return 0;
}