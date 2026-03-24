default	rel
global main

section .rodata
s:	db	"love", 0x0
fmt:	db	"%d %s  %x %d%%%b%c", 0xa, 0x0

section	.text

extern	getchar

; printf(fmt, -1, "love", 3802, 100, 31, 33);
main:
	lea	rdi, fmt
	mov	esi, -1
	lea	rdx, s
	mov	rcx, 3802
	mov	r8, 100
	mov	r9, 31
	;push	33

	call	getchar	wrt ..plt	

	xor	rax, rax
ret
; end main
