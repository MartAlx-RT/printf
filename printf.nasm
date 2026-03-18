global _start

;---------------------------------------
section .data

msg:	db	"Hello, nasm!!", 0x0a
msg_len	equ	$-msg
;---------------------------------------

;---------------------------------------
section .text

_start:
	mov	rdi, 1
	lea	rsi, msg
	mov	rdx, msg_len
	mov	rax, 0x01
	syscall

	xor	rdi, rdi
	mov	rax, 0x3c
	syscall

