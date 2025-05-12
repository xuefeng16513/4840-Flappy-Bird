/*
 * Userspace program that communicates with the ball_vga device driver
 * primarily through ioctls
 *
 * Stephen A. Edwards
 * Columbia University
 */

#include <stdio.h>
#include "vga_ball.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include "usbkeyboard.h"
#include <stdlib.h> // for rand number generation
#include <stdio.h>
#include <pthread.h>

struct libusb_device_handle *keyboard;
uint8_t endpoint_address;
int vga_ball_fd;

pthread_t keyboard_thread;
void *keyboard_thread_f(void *);

  float bird_y=200;
  float y=200;
  int g=250;
  float v0=-150.0;
  float v=0;
  float t=0;;
  float count_1,count_2;
  int count_3=0;
  int judge=0;
  int begin=0;
  int clk_state=0;//1:jump 0:fall
  void jump(void);
  void fall(void);
  void judg(void);
  vga_ball_arg_t vla;
   struct usb_keyboard_packet packet;
  int transferred;
  char keystate[12];
  int scoretemp=0;

int main()
{ 
  if ( (keyboard = openkeyboard(&endpoint_address)) == NULL )
    {
        fprintf(stderr, "Did not find a keyboard\n");
        exit(1);
  	}

  struct usb_keyboard_packet packet;
  //int transferred;
 // char keystate[12];

  //int count=0;
//  int scoretemp=0;
  int s3,s2,s1=0;

  vla.digit = 0; 
  vla.xPillar1 =  770;
  vla.xPillar2 =  1028;
  vla.xPillar3 =  1284;
  vla.hPillar1 = 20;
  vla.hPillar2 = 5;
  vla.hPillar3 = 8;
  vla.score = 0;
  vla.move = 0; 
  vla.bird = 200;
  vla.game_info1 =0x0 ; 
  vla.game_info2 =0x0 ;
  static const char filename[] = "/dev/vga_ball"; 
    
  printf("VGA BALL Userspace program started\n");
  if ( (vga_ball_fd = open(filename, O_RDWR)) == -1) {
    fprintf(stderr, "could not open %s\n", filename);
    return -1;
  } 
  
  //start the keyboard thread
  pthread_create(&keyboard_thread, NULL, keyboard_thread_f, NULL);

  while(1)
  {  
      printf("aa\n");
    /* libusb_interrupt_transfer(keyboard, endpoint_address,
			      (unsigned char *) &packet, sizeof(packet),
				 &transferred, 10);

	if (transferred == sizeof(packet)) {
	    printf("aa\n");
            if(packet.keycode[0] == 0x29){
		 printf("fuck\n");
            	 v=v0;
	         clk_state=0;
		 begin=1;	
	    }
            if(packet.keycode[0] == 0x28){
        
		 vla.xPillar1 =  770;
  		 vla.xPillar2 =  1028;
  		 vla.xPillar3 =  1284;
 	         vla.score = 0;
		 scoretemp = 0;
  		 vla.move = 0; 
  		 bird_y = 100;
		 vla.bird=100;
                 judge=0;
                 v=v0;
		 clk_state=0;
		 begin=0;
            }
        	 printf("%s\n", keystate);
 	    }
      */
      if (begin){
         vla.game_info2=0x01;
      if( (v<0)&&(!judge))
         jump(); 
      else
         fall();
      }
   

      judg();

    /* if (judge)
	{
          vla.score=998;
          count_1=0;
          count_2=0;
          y=vla.bird;
        
        if(vla.bird<400)
        {
            ++count_2;
            t=(count_2-count_1)/150;

            bird_y=y+0.5*g*t*t;
            vla.bird=(unsigned int)bird_y;
        }
        }*/
      if ((!judge) && (begin)){
        vla.xPillar1 = vla.xPillar1 - 2;
        vla.xPillar2 = vla.xPillar2 - 2;
        vla.xPillar3 = vla.xPillar3 - 2;
       // vla.move = vla.move + 2;
      }
      if ((!judge) && (!begin)){
       // vla.move = vla.move+2;
      }
      if(((vla.xPillar1==356)||(vla.xPillar2==356)||(vla.xPillar3==356)) && (!judge) && (begin)){ 
      if(scoretemp==1000) {scoretemp=0;}   
      scoretemp++;
      s3=scoretemp/100;
      s2=(scoretemp-s3*100)/10;
      s1=(scoretemp-s3*100-s2*10);
      vla.score=(s3<<8)+(s2<<4)+s1;
     }
     

     if( ioctl(vga_ball_fd, VGA_BALL_WRITE_DIGIT,&vla))
     { 
       perror("ioctl(VGA_BALL_WRITE_DIGIT) faiball");
       return;
     }

     
     if (vla.xPillar1 <=1){
	   vla.xPillar1 = 780;
	}

      if (vla.xPillar1==770){
	   vla.hPillar1 = (rand() % 40)+5;
	}


     if (vla.xPillar2<=1){		 
	   vla.xPillar2 = 780;  
	}
     if (vla.xPillar2==770){
	   vla.hPillar2 =  (rand() % 40)+5;
	}

     if (vla.xPillar3<=1){
	vla.xPillar3 = 780;
	}
     if (vla.xPillar3==770){
	   vla.hPillar3 =  (rand() % 40)+5;
	}
     if (vla.move==40)
	vla.move = 0;
     if (vla.score==1900)
	vla.score = 0;
     if (judge==1)
      vla.game_info1=0x02;
     count_3++;
    if (count_3%10==1)
     vla.game_info1=0x00; 
     usleep(10000);	
  }
  // terminate the keyboard thread
  pthread_cancel(keyboard_thread);
  // wait for the keyboard thread to finish
  pthread_join(keyboard_thread,NULL); 
  return 0;
}

void *keyboard_thread_f(void *ignored)
{
   while(1){
   libusb_interrupt_transfer(keyboard, endpoint_address,
			      (unsigned char *) &packet, sizeof(packet),
				 &transferred, 0);

	if (transferred == sizeof(packet)) {
	    printf("aa\n");
            if(packet.keycode[0] == 0x2C){
		 printf("fuck\n");
            	 v=v0;
	         clk_state=0;
		 begin=1;	
	    }
            if(packet.keycode[0] == 0x28){
        
		 vla.xPillar1 =  770;
  		 vla.xPillar2 =  1028;
  		 vla.xPillar3 =  1284;
 	         vla.score = 0;
		 scoretemp = 0;
  		 vla.move = 0; 
  		 bird_y = 200;
		 vla.bird=200;
                 judge=0;
                 v=v0;
		 clk_state=0;
		 begin=0;
                 vla.game_info2= 0x00;
             }
             printf("%s\n", keystate);
 	 }
   }
  return NULL;
}

void jump(){
           vla.game_info1=0x1;
            if (clk_state==0)
            {
                v=v0;
                count_1=0;
                count_2=0;
                clk_state=1;
                y=bird_y;
            }

            //printf("get in to here 1\n");
            if(v<=0 && bird_y>=0)
            {
                ++count_2;
                t=(count_2-count_1)/30;

                bird_y=y+v0*t+0.5*g*t*t;
                v=v0+g*t;
                vla.bird=(unsigned int)bird_y;
            }
}

void fall(){

        if (clk_state==1)
        {
                count_1=0;
                count_2=0;
                clk_state=0;
                y=bird_y;
        }
        if (bird_y<400)
        {
                ++count_2;
                t=(count_2-count_1)/55;

                bird_y=y+0.5*g*t*t;
                vla.bird=(unsigned int)bird_y;
        }
        /*printf("fall(y,t)=(%f,%f)\n",bird_y,t);
        printf("c1=%f,c2=%f,c2-c1=%f\n",count_1,count_2,count_2-count_1);*/      

}


void judg(){
        if (
	   (vla.bird>=400 || vla.bird<=0)
           || ((vla.xPillar1<=357 && vla.xPillar1>=220)&&(vla.bird<=vla.hPillar1*5+25||vla.bird>=vla.hPillar1*5+145))          
           || ((vla.xPillar2<=357 && vla.xPillar2>=220)&&(vla.bird<=vla.hPillar2*5+25||vla.bird>=vla.hPillar2*5+145))
           || ((vla.xPillar3<=357 && vla.xPillar3>=220)&&(vla.bird<=vla.hPillar3*5+25||vla.bird>=vla.hPillar3*5+145))
           || (((vla.xPillar1>=357 && vla.xPillar1<=367)||(vla.xPillar1<=220 &&
           vla.xPillar1>=210))&&((vla.bird<=vla.hPillar1*5+25 && vla.bird>=
           vla.hPillar1*5-30)||(vla.bird<=vla.hPillar1*5+200 && vla.bird>=
           vla.hPillar1*5+145)))
           || (((vla.xPillar2>=357 && vla.xPillar2<=367)||(vla.xPillar2<=220 &&
           vla.xPillar2>=210))&&((vla.bird<=vla.hPillar2*5+25 && vla.bird>=
           vla.hPillar2*5-30)||(vla.bird<=vla.hPillar2*5+200 && vla.bird>=
           vla.hPillar2*5+145)))
 	   || (((vla.xPillar3>=357 && vla.xPillar3<=367)||(vla.xPillar3<=220 &&
           vla.xPillar3>=210))&&((vla.bird<=vla.hPillar3*5+25 && vla.bird>=
           vla.hPillar3*5-30)||(vla.bird<=vla.hPillar3*5+280 && vla.bird>=
           vla.hPillar3*5+145))))
          {   
	    judge=1;
             vla.game_info2=0x03;
        }
}

