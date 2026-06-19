#ifndef USBHID_H
#define USBHID_H

#define USBHID_PORTS 2

#define USBHIDBASE 0x0fffff60

#define HW_USBHID(x) *(volatile unsigned short *)(USBHIDBASE+x)

#define REG_USBHID_STATUS 2
#define REG_USBHID_DATA 6
#define REG_USBHID_JOYKEYS 10

#define USBHID_STATUS_ATN 1

enum hidtype { NONE, KEYBOARD, MOUSE, GAMEPAD };

struct usbhidport {
	unsigned char pkt[8];
	int ptr;
	int serial;
	int flags;
	enum hidtype type;
};

extern struct usbhidport usbhid_ports[USBHID_PORTS];

void usbhid_init();
void usbhid_handle();

#endif

