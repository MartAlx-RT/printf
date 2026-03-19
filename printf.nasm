global _start

;---------------------------------------
BUF_SIZE	equ	0x400
;---------------------------------------
section .rodata
align 8

spec_choice:
	dq	printf.spec_a	; %a
	dq	printf.spec_b	; %b
	dq	printf.spec_c	; %c
	dq	printf.spec_d	; %d
	dq	printf.spec_e	; %e
	dq	printf.spec_f	; %f
	dq	printf.spec_g	; %g
	dq	printf.spec_h	; %h
	dq	printf.spec_i	; %i
	dq	printf.spec_j	; %j
	dq	printf.spec_k	; %k
	dq	printf.spec_l	; %l
	dq	printf.spec_m	; %m
	dq	printf.spec_n	; %n
	dq	printf.spec_o	; %o
	dq	printf.spec_p	; %p
	dq	printf.spec_q	; %q
	dq	printf.spec_r	; %r
	dq	printf.spec_s	; %s
	dq	printf.spec_t	; %t
	dq	printf.spec_u	; %u
	dq	printf.spec_v	; %v
	dq	printf.spec_w	; %w
	dq	printf.spec_x	; %x
	dq	printf.spec_y	; %y
	dq	printf.spec_z	; %z

section .data

dgt:		db	"0123456789abcdef"

fmt:		db	"my pointer = %p", 0xa, 0x0

buf:		times BUF_SIZE db	0
;---------------------------------------

;---------------------------------------
section .text

_start:
	lea	rdi, fmt
	mov	rsi, 0xdeadbeef
	call	printf

	xor	rdi, rdi
	mov	rax, 0x3c
	syscall
; end _start

; specifications:
;	%b
;	%c
;	%d
;	%s


;---------------------------------------
; STDCALL: rdi, rsi, rdx, rcx, r8, r9, stack

;           %rdi         %rsi, %rdx, ...
; printf(const char *fmt, varargs)
;---------------------------------------

printf:
	mov	rbp, rsp	; save rsp
	push	r9
	push	r8
	push	rcx
	push	rdx
	push	rsi

	mov	rsi, rdi
	lea	rdi, buf
	mov	rcx, BUF_SIZE
	xor	rax, rax

	cld
.loop:
	lodsb
	test	al, al
	jz	.exit

	cmp	al, '%'
	jne	.str

	lodsb
	cmp	al, '%'
	je	.str

	sub	rax, 'a'
	jmp	spec_choice[rax*8]
	; jmp table ...

.spec_a:
.spec_b:
.spec_c:
.spec_d:
.spec_e:
.spec_f:
.spec_g:
.spec_h:
.spec_i:
.spec_j:
.spec_k:
.spec_l:
.spec_m:
.spec_n:
.spec_o:
.spec_p:
	pop	rdx
	push	rcx
	call	hex_to_aptr
	pop	rcx
	sub	rcx, 16+2
	jmp	.continue
.spec_q:
.spec_r:
.spec_s:
.spec_t:
.spec_u:
.spec_v:
.spec_w:
.spec_x:
	pop	rdx
	call	hex_to_a
	jmp	.continue
.spec_y:
.spec_z:

.str:
	stosb
.continue:
	loop	.loop

.exit:
	mov	rdi, 1
	lea	rsi, buf
	mov	rdx, BUF_SIZE
	sub	rdx, rcx
	mov	rax, 0x1
	syscall

;	pop	rsi
;	pop	rdx
;	pop	rcx
;	pop	r8
;	pop	r9


	cmp	rsp, rbp
	jge	.stack_ok

	mov	rsp, rbp

.stack_ok:
ret




; %rdx - input
; %rdi - dest string
hex_to_aptr:
	mov	ax, 'x'*0x100 + '0'	; > "0x"
	stosw

	mov	rcx, 16
	cld
.loop:
	rol	rdx, 4
	mov	rax, rdx
	and	rax, 0xf

	mov	al, byte dgt[rax]
	stosb
	loop	.loop

ret


hex_to_a:
	push	rcx
	mov	rcx, 16

.skip_lead0:
	rol	rdx, 4
	mov	al, dl
	and	al, 0x0f
	test	al, al
	jnz	.done
	loop	.skip_lead0

.done:
	pop	rcx
	cld
.loop:
	mov	rax, rdx
	and	rdx, 0xfffffffffffffff0
	and	rax, 0xf

	mov	al, byte dgt[rax]
	stosb
	dec	rcx
	rol	rdx, 4

	test	rdx, rdx
	jnz	.loop
ret
