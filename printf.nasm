global _start

;---------------------------------------
section .data

BUF_SIZE:	equ	100

buf:		times BUF_SIZE db	0
;---------------------------------------

;---------------------------------------
section .text

_start:
	xor	rdi, rdi
	lea	rsi, buf
	mov	rdx, BUF_SIZE
	xor	rax, rax
	syscall

	mov	rdi, 1
	lea	rsi, buf
	mov	rdx, BUF_SIZE
	mov	rax, 0x1
	syscall

	xor	rdi, rdi
	mov	rax, 0x3c
	syscall

