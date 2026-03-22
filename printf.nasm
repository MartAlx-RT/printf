default	rel

%define	OFFSET(lbl)	lbl-spec_jmptbl
;---------------------------------------
BUF_SIZE	equ	0x400
;---------------------------------------
section .rodata
align 8

spec_jmptbl:
		dq	OFFSET(printf.dflt)	; %a

		dq	OFFSET(printf.spec_b)	; %b
		dq	OFFSET(printf.spec_c)	; %c
		dq	OFFSET(printf.spec_d)	; %d

times('o'-'d')	dq	OFFSET(printf.dflt)

		dq	OFFSET(printf.spec_p)	; %p

times('r'-'p')	dq	OFFSET(printf.dflt)

		dq	OFFSET(printf.spec_s)	; %s

times('w'-'s')	dq	OFFSET(printf.dflt)

		dq	OFFSET(printf.spec_x)	; %x

times('z'-'x')	dq	OFFSET(printf.dflt)

section .data   	

;-----------------------------------------------------
dgt:		db	"0123456789abcdef"
s:		db	"Hello!!!", 0x0
fmt:		db	"%c, my pointer = %p, my str = {%s}, my bits = %b, my decimal = %d", 0xa, 0x0
;fmt:		db	"%d", 0xa, 0x0

; -1, "love", 3802, 100, 31, 33
; fmt:	"%d %s  %x %d%%%b%c"

;-----------------------------------------------------

;=====================================================
printf_err_msg:		db	"printf: unexpected specificator", 0xa, 0x0
ERR_MSG_LEN:		equ	$-printf_err_msg

buf:	times BUF_SIZE	db	0
;=====================================================



section .text
global printf


;_start:
;	lea	rdi, fmt
;	;mov	rsi, -12345
;	mov	rsi, 'A'
;	mov	rdx, 0xdeadbeef
;	lea	rcx, s
;	mov	r8, 0xf
;	mov	r9, -1
;	call	printf
;
;	xor	rdi, rdi
;	mov	rax, 0x3c
;	syscall
;; end _start












;=====================================================
;	PRINTF:	print format strs
;-----------------------------------------------------
; EXPECTED:	!!stdcall convention!!
; 1st arg	format str
; 2, 3, ...	printing arguments

; RETURNS:	0 in case normal terminating
;		1 if any errors occured

; DESTROYS:	rax, rbx, rcx, rdx, rsi, rdi, rbp,
;		r8, r9, r15
;=====================================================

printf:
	xor	r15, r15	; printf ret val (initial=0)
	mov	rbp, rsp	; save rsp
	push	r9
	push	r8
	push	rcx		; push stdcall registers
	push	rdx
	push	rsi

	mov	rsi, rdi
	lea	rdi, buf	; rsi -> fmt, rdi -> buf
	mov	rcx, BUF_SIZE	; rcx = max buf size
	xor	rax, rax

	cld
.loop:
	lodsb
	test	al, al
	jz	.exit		; '\0' => exit

	cmp	al, '%'
	jne	.str		; not '%' => just write to buf
	lodsb

	cmp	al, '%'
	je	.str		; "%%" => write '%'

	cmp	al, 'z'		; max avalible symbol
	ja	.dflt

.crnt_adr:
	lea	rbx, spec_jmptbl	; %rbx = absolute jmptbl addr
	and	rax, 0xff
	mov	rax, [rbx + 8*(rax-'a')]
	;mov	rax, spec_jmptbl[8*(rax-'a')]
	add	rax, rbx
	jmp	rax


;	SPECIFICATOR CHOICE
;-----------------------------------------------------
.spec_b:
	pop	rdx
	call	print_b
	jmp	.continue

.spec_c:
	pop	rax
	stosb
	jmp	.continue

.spec_d:
	pop	rax
	push	rdx
	call	print_d
	pop	rdx
	jmp	.continue

.spec_p:
	pop	rdx
	push	rcx
	call	print_p
	pop	rcx
	sub	rcx, 16+2-1	; 16 digits + "0x"
	jmp	.continue

.spec_s:
	pop	rdx
	call	print_s
	jmp	.continue

.spec_x:
	pop	rdx
	call	print_x
	jmp	.continue

.str:
	stosb

.continue:
	loop	.loop

.dflt:
	mov	r15, 1		; ret val = 1 (error)
	mov	rdi, 1
	lea	rsi, printf_err_msg
	mov	rdx, ERR_MSG_LEN
	mov	rax, 0x1
	syscall

;	EXIT
;-----------------------------------------------------
.exit:
	mov	rdi, 1
	lea	rsi, buf
	mov	rdx, BUF_SIZE
	sub	rdx, rcx
	mov	rax, 0x1
	syscall

	cmp	rsp, rbp
	jae	.stack_ok
	mov	rsp, rbp

.stack_ok:

	mov	rax, r15	; rax = ret val
ret
;=====================================================




;=====================================================
;	print_p - prints 64-bit pointer
;-----------------------------------------------------
; EXPECTED:
;		rdx	number
;		rdi	dest str (buf)

; RETURNS:	none

; DESTROYS:	rax, rcx, rdx, rdi
;=====================================================
print_p:
	mov	ax, 'x'*0x100 + '0'	; > "0x"
	stosw

	mov	rcx, 16
	cld
.loop:
	rol	rdx, 4
	mov	rax, rdx
	and	rax, 0xf

	lea	rbx, dgt
	mov	al, byte [rbx+rax]
	stosb
	loop	.loop

ret
;=====================================================


print_x:
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

	lea	rbx, dgt
	mov	al, byte [rbx+rax]
	stosb
	dec	rcx
	rol	rdx, 4

	test	rdx, rdx
	jnz	.loop
ret
;=====================================================


;=====================================================
;	print_s - prints str
;-----------------------------------------------------
; EXPECTED:
;		rsi	source str
;		rdi	dest str (buf)

; RETURNS:	none

; DESTROYS:	rax, rcx, rdx, rdi, rsi
;=====================================================
print_s:
	push	rsi
	mov	rsi, rdx

.loop:
	lodsb
	test	al, al
	jz	.exit
	stosb
	loop	.loop

.exit:
	pop	rsi
ret
;=====================================================



;=====================================================
;	print_b - prints binary
;-----------------------------------------------------
; EXPECTED:
;		rdx	number
;		rdi	dest str (buf)

; RETURNS:	none

; DESTROYS:	rax, rcx, rdx, rdi
;=====================================================
print_b:
	push	rcx
	mov	rcx, 64

.skip_lead0:
	rol	rdx, 1
	mov	al, dl
	and	al, 1
	test	al, al
	jnz	.done
	loop	.skip_lead0

.done:
	pop	rcx
	cld
.loop:
	mov	rax, rdx
	and	rdx, 0xfffffffffffffffe

	and	rax, 1
	add	al, '0'
	stosb

	dec	rcx
	rol	rdx, 1

	test	rdx, rdx
	jnz	.loop
ret
;=====================================================





;=====================================================
;	print_d - prints decimal
;-----------------------------------------------------
; EXPECTED:
;		rax	number
;		rdi	dest str (buf)

; RETURNS:	none

; DESTROYS:	rax, rbx, rcx, rdx, rdi, r8
;=====================================================
print_d:
	cmp	rax, 0
	jge	.unsigned
	neg	rax

	mov	byte [rdi], '-'
	inc	rdi
	dec	rcx

.unsigned:
	mov	r8, rcx
	mov	rbx, 10
	xor	rcx, rcx

	xor	rdx, rdx
.push_digit:
	div	rbx

	add	rdx, '0'
	push	rdx
	xor	rdx, rdx

	inc	rcx
	test	rax, rax
	jnz	.push_digit

	sub	r8, rcx

	cld
.print_digit:
	pop	rax
	stosb
	loop	.print_digit

	mov	rcx, r8
ret
;=====================================================

