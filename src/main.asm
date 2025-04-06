%include "./types.asm"

section .bss
				;align	4
	tty_termios_saved	resb	ttermios_size
	tty_kbmode_saved	resd	1
	tty_termios		resb	ttermios_size
	hex_number		resd	1
	character		resb	1
	cursor			resb	tcursor_size
	int_string		resb	10
	cursor_pos_string	resb	24
	cursor_pos_string_len	resb	1	

section .data
			;align	4
	tty_state	dd	0
	cursor_up 	db 	0x1b, "[1A" ; the "1" is the number of lines to move the cursor
	cursor_down 	db 	0x1b, "[1B" ; the "1" is the number of lines to move the cursor
	cursor_right 	db 	0x1b, "[1C" ; the "1" is the number of lines to move the cursor
	cursor_left	db 	0x1b, "[1D" ; the "1" is the number of lines to move the cursor
	cursor_count	equ 	2
	cursor_home	db 	0x1b, "[H"
	cursor_set_pos	db 	0x1b, "[1;2f" ; the "1" is the row, the "2" is the column
	cursor_pos_row	equ 	2
	cursor_pos_col	equ 	4
	clear_screen	db 	0x1b, "[2J"
	msg		db 	"test", 0x0A
	hex_characters	db 	"0123456789ABCDEF"
	int_string_len	db 	0


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
	
	mov	byte [cursor_pos_string], 0x1B
	mov	byte [cursor_pos_string+1], '['

	mov	dword [cursor + tcursor.row], 2
	mov	dword [cursor + tcursor.col], 1

	jmp get_input


int_to_string:
	push	rbx
	mov	dword esi, 9
	mov	dword ebx, 10
	.loop:
	xor	edx, edx
	div	dword ebx
	add	byte dl, '0'
	mov	byte [int_string + esi], dl
	dec	dword esi
	test	eax, eax
	jnz	.loop	

	mov	byte [int_string_len], sil
	sub	byte bl, [int_string_len]
	dec	byte bl
	mov	byte [int_string_len], bl
	pop	rbx
	ret

add_cursor_coord_to_string:
	call	int_to_string
	
	cld
	xor	dword ecx, ecx
	xor	dword edi, edi
	mov	byte cl, [int_string_len]
	add	dword esi, int_string
	inc	dword esi
	mov	byte dil, [cursor_pos_string_len]
	add	dword edi, cursor_pos_string
	rep	movsb

	mov	byte cl, [int_string_len]
	add	byte cl, [cursor_pos_string_len]
	ret

mov_cursor:
	mov	byte [cursor_pos_string_len], 2
	mov	dword eax, [cursor + tcursor.row]
	call	add_cursor_coord_to_string

	mov	byte [cursor_pos_string+ecx], ';'
	inc	byte cl
	mov	byte [cursor_pos_string_len], cl

	mov	dword eax, [cursor + tcursor.col]
	call	add_cursor_coord_to_string
	
	mov	byte [cursor_pos_string+ecx], 'H'
	inc	byte cl
	mov	byte [cursor_pos_string_len], cl

	;write the cursor pos
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rsi, cursor_pos_string
	mov	dword edx, ecx
	syscall

	ret

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
	
	call	mov_cursor
	mov	rsi, character
	mov	rdx, 1
	call	print_string

	inc	dword [cursor + tcursor.col]

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
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rsi, hex_number
	mov	rdx, 2
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

; params: rsi (string pointer), rdx (int)
print_string:
	mov rax, SYS_WRITE
	mov rdi, STDOUT
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
