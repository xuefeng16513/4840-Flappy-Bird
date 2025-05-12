

GS = -Wall

OBJECTS = bouncing_ball.o  usbkeyboard.o

TARFILES = Makefile bouncing_ball.c \
	usbkeyboard.h usbkeyboard.c

bouncing_ball : $(OBJECTS)
	cc $(CFLAGS) -o bouncing_ball $(OBJECTS) -lusb-1.0 -pthread
bouncing_ball.o : bouncing_ball.c  usbkeyboard.h
usbkeyboard.o : usbkeyboard.c usbkeyboard.h

.PHONY : clean
clean :
	#rm -rf *.o bouncing_ball
