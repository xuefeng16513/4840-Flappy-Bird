#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdint.h>
#include "usbkeyboard.h"

#define FLAP_KEY 0x2C  // USB keycode for spacebar
#define ESC_KEY  0x29  // USB keycode for ESC
#define DEVICE_FILE "/dev/vga_ball"

int main() {
    struct libusb_device_handle *keyboard;
    struct usb_keyboard_packet packet;
    uint8_t endpoint_address;
    int transferred;
    int vga_fd;

    // Open USB keyboard
    printf("Opening USB keyboard...\n");
    keyboard = openkeyboard(&endpoint_address);
    if (!keyboard) {
        fprintf(stderr, "Could not find a USB keyboard.\n");
        return 1;
    }

    // Open memory-mapped peripheral
    printf("Opening VGA Ball device...\n");
    vga_fd = open(DEVICE_FILE, O_RDWR);
    if (vga_fd < 0) {
        perror("Failed to open /dev/vga_ball");
        libusb_close(keyboard);
        return 1;
    }

    printf("Press SPACE to flap the bird. Press ESC to quit.\n");

    // Main loop
    while (1) {
        libusb_interrupt_transfer(keyboard, endpoint_address,
            (unsigned char *)&packet, sizeof(packet),
            &transferred, 0);

        if (transferred == sizeof(packet)) {
            uint8_t code = packet.keycode[0];

            if (code == FLAP_KEY) {
                // Write to register 7 (flap trigger)
                uint8_t flap = 1;
                if (lseek(vga_fd, 7, SEEK_SET) == -1 ||
                    write(vga_fd, &flap, sizeof(flap)) != sizeof(flap)) {
                    perror("write to reg 7 failed");
                } else {
                    printf("Flap triggered!\n");
                }
            }

            if (code == ESC_KEY) {
                printf("Exiting...\n");
                break;
            }
        }

        usleep(10000);  // Avoid CPU hogging
    }

    close(vga_fd);
    libusb_close(keyboard);
    return 0;
}
