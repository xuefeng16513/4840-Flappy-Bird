/*
 * Device driver for the VGA BALL Emulator
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

/*
 * Information about our device
 */
struct vga_ball_dev {
	struct resource res; /* Resource: our registers */
	void __iomem *virtbase; /* Where registers can be accessed in memory */
	u16  segments[VGA_BALL_DIGITS];
} dev;

/*
 * Write segments of a single digit
 * Assumes digit is in range and the device information has been set up
 */
/*static void write_digit(vga_ball_arg_t temp)*/
static void write_digit(unsigned int digit, unsigned int xPillar1, unsigned int xPillar2, unsigned int xPillar3, unsigned int hPillar1, unsigned int hPillar2, unsigned int hPillar3, unsigned int score, unsigned int move, unsigned int bird, unsigned int game_info1,unsigned int game_info2)
{
	
	u8 reg;
        //unsigned int digit;

	reg = xPillar1>>8;
        iowrite8(reg, dev.virtbase + digit);
	reg = xPillar1;
        iowrite8(reg, dev.virtbase + digit+1);
	dev.segments[0] = xPillar1;
        
	reg = xPillar2>>8;
        iowrite8(reg, dev.virtbase + digit+2);
	reg = xPillar2;
        iowrite8(reg, dev.virtbase + digit+3);
	dev.segments[1] = xPillar2;
	
	reg = xPillar3>>8;
        iowrite8(reg, dev.virtbase + digit+4);
	reg = xPillar3;
        iowrite8(reg, dev.virtbase + digit+5);
	dev.segments[2] = xPillar3;
	
	reg = hPillar1;
	iowrite8(reg, dev.virtbase + digit+6);
	dev.segments[3] = hPillar1;

	reg = hPillar2;
	iowrite8(reg, dev.virtbase + digit+7);
        dev.segments[4] = hPillar2;

	reg = hPillar3;
	iowrite8(reg, dev.virtbase + digit+8);
        dev.segments[5] = hPillar3;

	reg = score>>8;
	iowrite8(reg, dev.virtbase + digit+9);
	reg = score;
	iowrite8(reg, dev.virtbase + digit+10);
        dev.segments[6]=score;

	reg = move;
	iowrite8(reg, dev.virtbase + digit+11);
        dev.segments[7] = move;

        reg = bird>>8;
	iowrite8(reg, dev.virtbase + digit+12);
	reg = bird;
	iowrite8(reg, dev.virtbase + digit+13);
        dev.segments[8]=bird;

 	reg = game_info1;
	iowrite8(reg, dev.virtbase + digit+14);
	dev.segments[9] = game_info1;

	reg = game_info2;
	iowrite8(reg, dev.virtbase + digit+15);
	dev.segments[10] = game_info2;
			

/*	digit = temp.digit;
 
	reg = temp.xPillar1>>8;
        iowrite8(reg, dev.virtbase + digit);
	reg = temp.xPillar1;
        iowrite8(reg, dev.virtbase + digit+1);
	dev.segments[0] = temp.xPillar1;
        
	reg = temp.xPillar2>>8;
        iowrite8(reg, dev.virtbase + digit+2);
	reg = temp.xPillar2;
        iowrite8(reg, dev.virtbase + digit+3);
	dev.segments[1] = temp.xPillar2;
	
	reg = temp.xPillar3>>8;
        iowrite8(reg, dev.virtbase + digit+4);
	reg = temp.xPillar3;
        iowrite8(reg, dev.virtbase + digit+5);
	dev.segments[2] = temp.xPillar3;
	
	reg = temp.hPillar1;
	iowrite8(reg, dev.virtbase + digit+6);
	dev.segments[3] = temp.hPillar1;

	reg = temp.hPillar2;
	iowrite8(reg, dev.virtbase + digit+7);
        dev.segments[4] = temp.hPillar2;

	reg = temp.hPillar3;
	iowrite8(reg, dev.virtbase + digit+8);
        dev.segments[5] = temp.hPillar3;

	reg = temp.score>>8;
	iowrite8(reg, dev.virtbase + digit+9);
        dev.segments[6] = temp.score;
	
	reg = temp.score;
	iowrite8(reg, dev.virtbase + digit+10);
        dev.segments[7] = temp.score;
*/
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
	case VGA_BALL_WRITE_DIGIT:
		if (copy_from_user(&vla, (vga_ball_arg_t *) arg,
				   sizeof(vga_ball_arg_t)))
			return -EACCES;
		if (vla.digit > 16)
			return -EINVAL;
		write_digit(vla.digit, vla.xPillar1, vla.xPillar2, vla.xPillar3,                vla.hPillar1, vla.hPillar2, vla.hPillar3, vla.score, vla.move, vla.bird, game_info1, game_info2);
		//write_digit(vla);
		break;

	case VGA_BALL_READ_DIGIT:
		if (copy_from_user(&vla, (vga_ball_arg_t *) arg,
				   sizeof(vga_ball_arg_t)))
			return -EACCES;
		if (vla.digit > 16)
			return -EINVAL;
		//vla.segments = dev.segments[vla.digit];
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
	static unsigned char  welcome_message[VGA_BALL_DIGITS] = {
		200, 200, 0x77, 0x08, 0x38, 0x79, 0x5E, 0x00};
	int i, ret;

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

	/* Display a welcome message */
	//write_digit(1, 200);
        //write_digit(3, 0x88);
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
	{ .compatible = "altr,vga_ball" },
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

/* Calball when the module is loaded: set things up */
static int __init vga_ball_init(void)
{
	pr_info(DRIVER_NAME ": init\n");
	return platform_driver_probe(&vga_ball_driver, vga_ball_probe);
}

/* Calball when the module is unloaded: release resources */
static void __exit vga_ball_exit(void)
{
	platform_driver_unregister(&vga_ball_driver);
	pr_info(DRIVER_NAME ": exit\n");
}

module_init(vga_ball_init);
module_exit(vga_ball_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Stephen A. Edwards, Columbia University");
MODULE_DESCRIPTION("VGA 7-segment BALL Emulator");
