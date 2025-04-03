%include "./types.asm"

section .bss
				;align	4
	tty_termios_saved	resb	ttermios_size
	tty_kbmode_saved	resd	1
	tty_termios		resb	ttermios_size
	hex_number		resd	1
	character		resb	1
	
section .data
			;align	4
	tty_state	dd	0
	cursor_up 	db 0x1b, "[1A" ; the "1" is the number of lines to move the cursor
	cursor_down 	db 0x1b, "[1B" ; the "1" is the number of lines to move the cursor
	cursor_right 	db 0x1b, "[1C" ; the "1" is the number of lines to move the cursor
	cursor_left	db 0x1b, "[1D" ; the "1" is the number of lines to move the cursor
	cursor_count	equ 2
	cursor_home	db 0x1b, "[H"
	cursor_set_pos	db 0x1b, "[1;2f" ; the "1" is the row, the "2" is the column
	cursor_pos_row	equ 2
	cursor_pos_col	equ 4
	clear_screen	db 0x1b, "[2J"
	msg	db "test", 0x0A
	hex_characters	db "0123456789ABCDEF"


section .text
	global _start

_start:
	; save keyboard and terminal state
	mov	rax, SYS_IOCTL
	mov	rdi, STDIN
	mov	rsi, KDGKBMODE
	mov	rdx, tty_kbmode_saved
	syscall
	mov byte [character], '1'
	test 	eax, 0xFFFFFFFF 
	je	handle_error
	or	dword [tty_state], STATE_KBMODE_SAVED

	mov 	rax, SYS_IOCTL
	mov 	rdi, STDIN
	mov 	rsi, TCGETS
	mov 	rdx, tty_termios_saved
	syscall
	mov byte [character], '2'
	test 	eax, eax;0xFFFFFFFF
	js	handle_error
	or	dword [tty_state], STATE_TERMIOS_SAVED

	; set keyboard and terminal state
	cld
	mov	dword ecx, ttermios_size
	mov	dword esi, tty_termios_saved
	mov	dword edi, tty_termios
	rep	movsb ; copy all the bytes from termios_saved to termios

	and	dword [tty_termios + ttermios.c_iflag], ~(ISTRIP | INLCR | ICRNL | IGNCR | IXON | IXOFF)
	and	byte [tty_termios + ttermios.c_lflag], ~(ECHO | ICANON | ISIG)
	mov	rax, SYS_IOCTL
	mov	rdi, STDIN
	mov	rsi, TCSETSW
	mov	rdx, tty_termios
	syscall
	mov	byte [character], '3'
	test	eax, eax;0xFFFFFFFF
	js	handle_error
	
	mov	rax, SYS_IOCTL
	mov	rdi, STDIN
	mov	rsi, KDSKBMODE
	mov	rdx, K_RAW
	syscall
	mov	byte [character], '4'
	test	eax, 0xFFFFFFFF
	je	handle_error
	
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rsi, clear_screen
	mov	rdx, 4
	syscall

	mov	byte [cursor_set_pos+cursor_pos_row], '2'
	mov	byte [cursor_set_pos+cursor_pos_col], '1'
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rsi, cursor_set_pos
	mov	rdx, 6
	syscall


get_input:
	mov 	rax, SYS_READ
	mov 	rdi, STDIN
	mov 	rsi, character
	mov 	rdx, 1
	syscall
	
	call	display_key

	; exit when escape is pressed
	mov	rcx, 0
	mov	byte cl, [character]
	cmp	cl, 0x1B
	je	exit

	jmp	get_input

display_key:
	; move cursor to top-left
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rsi, cursor_home
	mov	rdx, 3
	syscall
	
	; print hex value of pressed key
	mov	ecx, 0
	mov	edx, 0
	mov	byte cl, [character]
	mov	byte dl, cl
	shr	byte dl, 4
	and	byte cl, 0x0f
	mov	dword ecx, [hex_characters+ecx]
	mov	dword edx, [hex_characters+edx]
	mov	dword [hex_number], edx
	mov	byte [hex_number+1], cl ; moving a dword here would corrupt the char address
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	mov rsi, hex_number
	mov rdx, 2
	syscall

	ret 

move_cursor_up:
	mov [cursor_up+cursor_count], byte '2' ; move the cursor twice
	mov rax, 1
	mov rdi, 1
	mov rsi, cursor_up
	mov rdx, 4
	syscall

; lseek through stdout (lseek doesn't do anything when using stdout)
; mov rax, 8 ; lseek
; mov rdi, 1 ; stdout
; mov rsi, 0 ; offset
; mov rdx, 1 ; SEEK_CUR
; syscall

print_string:
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	mov rsi, hex_number
	mov rdx, 2
	syscall
	ret

restore_settings:
restore_keyboard:
	test	dword [tty_state], STATE_KBMODE_SAVED
	jz	restore_terminal
	mov	rax, SYS_IOCTL
	mov	rdi, STDIN
	mov	rsi, KDSKBMODE
	mov	rdx, [tty_kbmode_saved]
	syscall
restore_terminal:
	test	dword [tty_state], STATE_TERMIOS_SAVED
	jz	end_restore_settings
	mov	rax, SYS_IOCTL
	mov	rdi, STDIN
	mov	rsi, TCSETSW
	mov	rdx, tty_termios_saved
	syscall
end_restore_settings:
	ret

handle_error:
	call print_string

	call restore_settings
	mov rax, 60
	mov rdi, 1
	syscall ; exit error
exit:
	call restore_settings
	mov rax, 60
	mov rdi, 0
	syscall ; exit success
