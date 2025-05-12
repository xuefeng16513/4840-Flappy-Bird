/* * Device driver for the VGA video generator
 *
 * A Platform device implemented using the misc subsystem
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * References:
 * Linux source: Documentation/driver-model/platform.txt
 *               drivers/misc/arm-charlcd.c
 * http://www.linuxforu.com/tag/linux-device-drivers/
 * http://free-electrons.com/docs/
 *
 * "make" to build
 * insmod vga_ball.ko
 *
 * Check code style with
 * checkpatch.pl --file --no-tree vga_ball.c
 */

 #include <linux/module.h>
 #include <linux/init.h>
 #include <linux/errno.h>
 #include <linux/version.h>
 #include <linux/kernel.h>
 #include <linux/platform_device.h>
 #include <linux/miscdevice.h>
 #include <linux/slab.h>
 #include <linux/io.h>
 #include <linux/of.h>
 #include <linux/of_address.h>
 #include <linux/fs.h>
 #include <linux/uaccess.h>
 #include "vga_ball.h"
 
 #define DRIVER_NAME "vga_ball"
 
 /* Device registers */
 #define BG_RED(x) (x)
 #define BG_GREEN(x) ((x)+1)
 #define BG_BLUE(x) ((x)+2)
 #define BALL_X_LOW(x) ((x)+3)
 #define BALL_X_HIGH(x) ((x)+4)
 #define BALL_Y_LOW(x) ((x)+5)
 #define BALL_Y_HIGH(x) ((x)+6)
 #define BALL_RADIUS(x) ((x)+7)
 #define FLAP_CONTROL(x) ((x)+8)
 #define PIPE_WIDTH(x) ((x)+9)
 #define PIPE_GAP_HEIGHT_LOW(x) ((x)+10)
 #define PIPE_GAP_HEIGHT_HIGH(x) ((x)+11)
 #define PIPE_SPEED(x) ((x)+12)
 #define PIPE_ENABLE(x) ((x)+13)
 
 /*
  * Information about our device
  */
 struct vga_ball_dev {
	 struct resource res; /* Resource: our registers */
	 void __iomem *virtbase; /* Where registers can be accessed in memory */
	 vga_ball_color_t background;
	 vga_ball_position_t ball;
	 uint8_t pipe_width;
	 uint16_t pipe_gap_height;
	 uint8_t pipe_speed;
	 uint8_t pipe_enable;
 } dev;
 
 /*
  * Write background color
  */
 static void write_background(vga_ball_color_t *background)
 {
	 iowrite8(background->red, BG_RED(dev.virtbase));
	 iowrite8(background->green, BG_GREEN(dev.virtbase));
	 iowrite8(background->blue, BG_BLUE(dev.virtbase));
	 dev.background = *background;
 }
 
 /*
  * Write ball position
  */
 static void write_ball_position(vga_ball_position_t *ball)
 {
	 // Write X position (low 8 bits and high 2 bits)
	 iowrite8(ball->x & 0xff, BALL_X_LOW(dev.virtbase));
	 iowrite8((ball->x >> 8) & 0x03, BALL_X_HIGH(dev.virtbase));
	 
	 // Write Y position (low 8 bits and high 2 bits)
	 iowrite8(ball->y & 0xff, BALL_Y_LOW(dev.virtbase));
	 iowrite8((ball->y >> 8) & 0x03, BALL_Y_HIGH(dev.virtbase));
	 
	 // Write ball radius
	 iowrite8(ball->radius, BALL_RADIUS(dev.virtbase));
	 
	 dev.ball = *ball;
 }
 
 /*
  * Write pipe configuration
  */
 static void write_pipe_config(vga_ball_pipe_config_t *config)
 {
	 iowrite8(config->width, PIPE_WIDTH(dev.virtbase));
	 iowrite8(config->gap_height & 0xff, PIPE_GAP_HEIGHT_LOW(dev.virtbase));
	 iowrite8((config->gap_height >> 8) & 0x03, PIPE_GAP_HEIGHT_HIGH(dev.virtbase));
	 iowrite8(config->speed, PIPE_SPEED(dev.virtbase));
	 iowrite8(config->enable, PIPE_ENABLE(dev.virtbase));
	 
	 dev.pipe_width = config->width;
	 dev.pipe_gap_height = config->gap_height;
	 dev.pipe_speed = config->speed;
	 dev.pipe_enable = config->enable;
 }
 
 /*
  * Handle flap input
  */
 static void write_flap(unsigned char flap)
 {
	 iowrite8(flap, FLAP_CONTROL(dev.virtbase));
 }
 
 /*
  * Handle ioctl() calls from userspace:
  * Read or write the segments on single digits.
  * Note extensive error checking of arguments
  */
 static long vga_ball_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
 {
	 vga_ball_arg_t vla;
 
	 switch (cmd) {
	 case VGA_BALL_WRITE_BACKGROUND:
		 if (copy_from_user(&vla, (vga_ball_arg_t *) arg,
					sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 write_background(&vla.background);
		 break;
 
	 case VGA_BALL_READ_BACKGROUND:
		 vla.background = dev.background;
		 if (copy_to_user((vga_ball_arg_t *) arg, &vla,
				  sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 break;
 
	 case VGA_BALL_WRITE_BALL:
		 if (copy_from_user(&vla, (vga_ball_arg_t *) arg,
					sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 write_ball_position(&vla.ball);
		 break;
 
	 case VGA_BALL_READ_BALL:
		 vla.ball = dev.ball;
		 if (copy_to_user((vga_ball_arg_t *) arg, &vla,
				  sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 break;
 
	 case VGA_BALL_WRITE_FLAP:
		 if (copy_from_user(&vla, (vga_ball_arg_t *) arg, 
					sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 write_flap(vla.flap);
		 break;
 
	 case VGA_BALL_WRITE_PIPE_CONFIG:
		 if (copy_from_user(&vla, (vga_ball_arg_t *) arg,
					sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 write_pipe_config(&vla.pipe_config);
		 break;
		 
	 case VGA_BALL_READ_PIPE_CONFIG:
		 vla.pipe_config.width = dev.pipe_width;
		 vla.pipe_config.gap_height = dev.pipe_gap_height;
		 vla.pipe_config.speed = dev.pipe_speed;
		 vla.pipe_config.enable = dev.pipe_enable;
		 if (copy_to_user((vga_ball_arg_t *) arg, &vla,
				  sizeof(vga_ball_arg_t)))
			 return -EACCES;
		 break;
 
	 default:
		 return -EINVAL;
	 }
 
	 return 0;
 }
 
 /* The operations our device knows how to do */
 static const struct file_operations vga_ball_fops = {
	 .owner		= THIS_MODULE,
	 .unlocked_ioctl = vga_ball_ioctl,
 };
 
 /* Information about our device for the "misc" framework -- like a char dev */
 static struct miscdevice vga_ball_misc_device = {
	 .minor		= MISC_DYNAMIC_MINOR,
	 .name		= DRIVER_NAME,
	 .fops		= &vga_ball_fops,
 };
 
 /*
  * Initialization code: get resources (registers) and display
  * a welcome message
  */
 static int __init vga_ball_probe(struct platform_device *pdev)
 {
	 vga_ball_color_t sky_blue = { 0x87, 0xCE, 0xEB }; // 天空蓝背景
	 vga_ball_position_t initial_ball = { 100, 240, 15 }; // 初始球位置
	 vga_ball_pipe_config_t initial_pipe_config = { 50, 120, 2, 1 }; // 初始柱子配置
	 int ret;
 
	 /* Register ourselves as a misc device: creates /dev/vga_ball */
	 ret = misc_register(&vga_ball_misc_device);
 
	 /* Get the address of our registers from the device tree */
	 ret = of_address_to_resource(pdev->dev.of_node, 0, &dev.res);
	 if (ret) {
		 ret = -ENOENT;
		 goto out_deregister;
	 }
 
	 /* Make sure we can use these registers */
	 if (request_mem_region(dev.res.start, resource_size(&dev.res),
					DRIVER_NAME) == NULL) {
		 ret = -EBUSY;
		 goto out_deregister;
	 }
 
	 /* Arrange access to our registers */
	 dev.virtbase = of_iomap(pdev->dev.of_node, 0);
	 if (dev.virtbase == NULL) {
		 ret = -ENOMEM;
		 goto out_release_mem_region;
	 }
		 
	 /* Set initial values */
	 write_background(&sky_blue);
	 write_ball_position(&initial_ball);
	 write_pipe_config(&initial_pipe_config);
 
	 return 0;
 
 out_release_mem_region:
	 release_mem_region(dev.res.start, resource_size(&dev.res));
 out_deregister:
	 misc_deregister(&vga_ball_misc_device);
	 return ret;
 }
 
 /* Clean-up code: release resources */
 static int vga_ball_remove(struct platform_device *pdev)
 {
	 iounmap(dev.virtbase);
	 release_mem_region(dev.res.start, resource_size(&dev.res));
	 misc_deregister(&vga_ball_misc_device);
	 return 0;
 }
 
 /* Which "compatible" string(s) to search for in the Device Tree */
 #ifdef CONFIG_OF
 static const struct of_device_id vga_ball_of_match[] = {
	 { .compatible = "csee4840,vga_ball-1.0" },
	 {},
 };
 MODULE_DEVICE_TABLE(of, vga_ball_of_match);
 #endif
 
 /* Information for registering ourselves as a "platform" driver */
 static struct platform_driver vga_ball_driver = {
	 .driver	= {
		 .name	= DRIVER_NAME,
		 .owner	= THIS_MODULE,
		 .of_match_table = of_match_ptr(vga_ball_of_match),
	 },
	 .remove	= __exit_p(vga_ball_remove),
 };
 
 /* Called when the module is loaded: set things up */
 static int __init vga_ball_init(void)
 {
	 pr_info(DRIVER_NAME ": init\n");
	 return platform_driver_probe(&vga_ball_driver, vga_ball_probe);
 }
 
 /* Called when the module is unloaded: release resources */
 static void __exit vga_ball_exit(void)
 {
	 platform_driver_unregister(&vga_ball_driver);
	 pr_info(DRIVER_NAME ": exit\n");
 }
 
 module_init(vga_ball_init);
 module_exit(vga_ball_exit);
 
 MODULE_LICENSE("GPL");
 MODULE_AUTHOR("Stephen A. Edwards, Columbia University");
 MODULE_DESCRIPTION("VGA ball driver");