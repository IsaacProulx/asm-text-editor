%assign SYS_READ	0
%assign SYS_WRITE	1
%assign SYS_OPEN	2
%assign SYS_CLOSE	3
%define SYS_IOCTL	16

%assign	TCGETS		0x5401
%assign TCSETSW		0x5403 ; get current keyboard mode
%assign	KDGKBMODE	0x4B44 ; set current keyboard mode
%assign KDSKBMODE	0x4B45
%assign K_RAW		0

%assign ISTRIP		0x0020
%assign INLCR		0x0040
%assign IGNCR		0x0080
%assign ICRNL		0x0100
%assign IXON		0x0400
%assign IXOFF		0x1000

%assign ISIG		0x00001
%assign ICANON		0x00002
%assign ECHO		0x00008

%assign STDIN		0
%assign STDOUT		1

%assign O_RDWR		0x00000002

; if the terminal settings have been saved
%assign STATE_TERMIOS_SAVED	0x01
; if the keyboard settings have been saved
%assign STATE_KBMODE_SAVED	0x02

struc	ttermios
;alignb	4
	.c_iflag	resd	1
	.c_oflag	resd	1
	.c_cflag	resd	1
	.c_lflag	resd	1
	.c_line		resb	1
	.c_cc		resb	64
endstruc

struc	tcursor
	.row		resd	1
	.col		resd	1
endstruc
