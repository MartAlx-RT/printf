default	rel

%define	OFFSET(lbl)	lbl-spec_jmptbl
;---------------------------------------
BUF_SIZE	equ	20
;---------------------------------------
section .rodata
align 8

spec_jmptbl:
		dq	OFFSET(printf.dflt)	; %a

		dq	OFFSET(printf.spec_b)	; %b
		dq	OFFSET(printf.spec_c)	; %c
		dq	OFFSET(printf.spec_d)	; %d

		dq	OFFSET(printf.dflt)	; %e

		dq	OFFSET(printf.spec_f)	; %f

times('n'-'f')	dq	OFFSET(printf.dflt)

		dq	OFFSET(printf.spec_o)	; %o
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
PREC		dd	100000.0
;fmt:		db	"%c, my pointer = %p, my str = {%s}, my bits = %b, my decimal = %d", 0xa, 0x0
;-----------------------------------------------------

;=====================================================
reg_cnt:		dq	0
xmm_cnt:		dq	0

reg:	times(5)	dq	0xbadf00dd
xmm:	times(8)	dd	0xbaadf00d
printf_err_msg:		db	"printf: unexpected specifier", 0xa, 0x0
ERR_MSG_LEN:		equ	$-printf_err_msg

buf:	times BUF_SIZE	db	0
;=====================================================











section .text
global printf
;=====================================================
;	PRINTF:	print format strs
;-----------------------------------------------------
; EXPECTED:	!!stdcall convention!!
; 1st arg	format str
; 2, 3, ...	printing arguments

; RETURNS:	0 in case normal terminating
;		1 if any errors occured

; DESTROYS:	according stdcall convention
;=====================================================

printf:
	; regs
	mov	[reg], rsi
	mov	[reg+1*8], rdx
	mov	[reg+2*8], rcx
	mov	[reg+3*8], r8
	mov	[reg+4*8], r9

	; floats
	vmovss	[xmm], xmm0
	vmovss	[xmm+1*4], xmm1
	vmovss	[xmm+2*4], xmm2
	vmovss	[xmm+3*4], xmm3
	vmovss	[xmm+4*4], xmm4		; TODO not working, unfortunately
	vmovss	[xmm+5*4], xmm5
	vmovss	[xmm+6*4], xmm6
	vmovss	[xmm+7*4], xmm7

	push	rbp
	mov	rbp, rsp	; rbp -> first fastcall arg
	add	rbp, 2*8

	lea	r9, [buf+BUF_SIZE-0x10]	; -16 just in case

	mov	rsi, rdi
	lea	rdi, buf	; rsi -> fmt, rdi -> buf
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
	cmp	al, 'a'		; min avalible symbol
	jb	.dflt


	lea	r8, spec_jmptbl	; %rbx = absolute jmptbl addr
	and	rax, 0xff
	mov	rax, [r8 + 8*(rax-'a')]
	add	rax, r8
	jmp	rax



;	SPECIFICATOR CHOICE
;-----------------------------------------------------
.spec_b:
	call	get_int
	call	print_b
	jmp	.continue

.spec_c:
	call	get_int
	movsx	rax, edx
	stosb
	jmp	.continue

.spec_d:
	call	get_int
	movsx	rax, edx
	call	print_d
	jmp	.continue

.spec_f:
	call	get_flt
	call	print_f
	jmp	.continue

.spec_o:
	call	get_int
	call	print_o
	jmp	.continue

.spec_p:
	call	get_int
	call	print_p
	jmp	.continue

.spec_s:
	call	get_int
	call	print_s
	jmp	.continue

.spec_x:
	call	get_int
	call	print_x
	jmp	.continue

.str:
	stosb

.continue:
	cmp	rdi, r9
	jb	.loop
	call	write
	jmp	.loop

.dflt:
	push	r10
	mov	rdi, 1
	lea	rsi, printf_err_msg
	mov	rdx, ERR_MSG_LEN
	mov	rax, 0x1
	syscall
	pop	r10
	mov	rax, 1		; ret val = 1 (error)
	jmp	.exit

;	EXIT
;-----------------------------------------------------
.exit:
	call	write
	pop	rbp
;	add	rsp, 4*8
;	mov	[rsp], r10
ret
;=====================================================




write:
	push	rsi
	lea	rsi, buf
	mov	rdx, rdi
	sub	rdx, rsi
	mov	rdi, 1
	mov	rax, 0x1
	syscall
	pop	rsi

	lea	rdi, buf
	cmp	rax, 0
	setl	al
	movzx	rax, al
ret



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
	lea	r8, dgt
	mov	al, byte [r8+rax]
	stosb

	loop	.loop

ret
;=====================================================


print_x:
	mov	rcx, 16

.skip_lead0:
	rol	rdx, 4
	test	dl, 0xf
	jnz	.done
	loop	.skip_lead0

.done:
	cld
.loop:
	mov	rax, rdx
	and	rax, 0xf
	lea	r8, dgt
	mov	al, byte [r8+rax]
	stosb

	and	rdx, ~(0xf)
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

	cmp	rdi, r9
	jb	.loop
	call	write
	jmp	.loop

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
	mov	rcx, 64

.skip_lead0:
	rol	rdx, 1
	test	dl, 1
	jnz	.done
	loop	.skip_lead0

.done:
	cld
.loop:
	test	dl, 1
	setnz	al
	add	al, '0'
	stosb

	and	rdx, ~(1)
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

; DESTROYS:	rax, r8, rcx, rdx, rdi, r8
;=====================================================
print_d:
	cmp	rax, 0
	jge	.unsigned
	neg	rax

	mov	byte [rdi], '-'
	inc	rdi

.unsigned:
	mov	r8, 10

	xor	rcx, rcx
	xor	rdx, rdx
.push_digit:
	div	r8

	add	rdx, '0'
	push	rdx
	xor	rdx, rdx
	inc	rcx

	test	rax, rax
	jnz	.push_digit

	cld
.print_digit:
	pop	rax
	stosb
	loop	.print_digit
ret
;=====================================================





;=====================================================
;	print_o - prints octal
;-----------------------------------------------------
; EXPECTED:
;		rdx	number
;		rdi	dest str (buf)

; RETURNS:	none

; DESTROYS:	rax, rcx, rdx, rdi
;=====================================================
print_o:
	mov	rcx, 21		; max num of oct digit

	rol	rdx, 1		; check high bit
	test	dl, 1
	jz	.skip_lead0	; 0 => check by triplets

	mov	al, '1'		; 1 => write '1'
	stosb
	rol	rdx, 3
	jmp	.loop

.skip_lead0:
	rol	rdx, 3
	test	dl, 0o7
	jnz	.done
	loop	.skip_lead0

.done:
	cld
.loop:
	mov	al, dl
	and	al, 0o7
	add	al, '0'
	stosb

	and	rdx, ~(0o7)
	rol	rdx, 3

	test	rdx, rdx
	jnz	.loop
ret
;=====================================================





; gets int argument
;
; %rbp 	must point to stack arg
; %rdx	ret val
get_int:
	mov	r8, [reg_cnt]
	cmp	r8, 5
	jae	.stk

	lea	rdx, reg
	mov	rdx, [rdx+8*r8]
	inc	qword [reg_cnt]
ret	; if arg is register
.stk:
	mov	rdx, [rbp]
	add	rbp, 8
ret



; gets float argument
;
; %rbp	must point to stk arg
; %xmm0	ret val
get_flt:
	mov	r8, [xmm_cnt]
	cmp	r8, 8
	jae	.stk

	lea	rdx, xmm
	vmovss	xmm0, [rdx+8*r8]
	inc	qword [xmm_cnt]
ret	; if not stk
.stk:
	vmovss	xmm0, [rbp]
	add	rbp, 8
ret



; TODO fix printing fractial part & check how fastcall pushed xmm
; expected: %xmm0
print_f:
	vcvttss2si	rax, xmm0	; %rax = (int) %xmm0
	call	print_d
	vcvtsi2ss	xmm1, xmm1, rax	; %xmm1 = (float) %rax
	vsubss		xmm0, xmm1	; %xmm0 -= %xmm1 (%xmm0 = 0.___)

	mov	al, '.'
	stosb

	vmovss		xmm1, [PREC]
	vmulss		xmm0, xmm0, xmm1; %xmm0 *= 10^6
	vcvttss2si	rax, xmm0

	call	print_d
ret

