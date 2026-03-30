default	rel

%define	OFFSET(lbl)	lbl-spec_jmptbl
;---------------------------------------
BUF_SIZE	equ	1024
;---------------------------------------
section .rodata
align 8

spec_jmptbl:
		dq	OFFSET(asm_printf.dflt)		; %a

		dq	OFFSET(asm_printf.spec_b)	; %b
		dq	OFFSET(asm_printf.spec_c)	; %c
		dq	OFFSET(asm_printf.spec_d)	; %d

		dq	OFFSET(asm_printf.dflt)		; %e

		dq	OFFSET(asm_printf.spec_f)	; %f

times('n'-'f')	dq	OFFSET(asm_printf.dflt)

		dq	OFFSET(asm_printf.spec_o)	; %o
		dq	OFFSET(asm_printf.spec_p)	; %p

times('r'-'p')	dq	OFFSET(asm_printf.dflt)

		dq	OFFSET(asm_printf.spec_s)	; %s

times('w'-'s')	dq	OFFSET(asm_printf.dflt)

		dq	OFFSET(asm_printf.spec_x)	; %x

times('z'-'x')	dq	OFFSET(asm_printf.dflt)

section .data   	

;-----------------------------------------------------
dgt:		db	"0123456789abcdef"
s:		db	"Hello!!!", 0x0

neg_flt		db	0		; 1 if flt number is negative
PREC		dq	1000000.0
inf_val		dq	0x7ff0000000000000
;-----------------------------------------------------

;=====================================================
reg_cnt:		dq	0
xmm_cnt:		dq	0

reg:	times(5)	dq	0xbadf00dd
xmm:	times(8)	dq	0xbaadf00d

unxp_spec:		db	"printf: unexpected specifier", 0xa, 0x0
UNXP_SPEC_LEN:		equ	$-unxp_spec

null_s:			db	"(null)", 0xa, 0x0
nan_s:			db	"nan", 0xa, 0x0
inf_s:			db	"inf", 0xa, 0x0

buf:	times BUF_SIZE	db	0
;=====================================================

















section .text
global asm_printf
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

asm_printf:
	test	rdi, rdi
	jnz	.fmt_ok
	ret

.fmt_ok:
	mov	qword [xmm_cnt], 0
	mov	qword [reg_cnt], 0
	; regs
	mov	[reg], rsi
	mov	[reg+1*8], rdx
	mov	[reg+2*8], rcx
	mov	[reg+3*8], r8
	mov	[reg+4*8], r9

	; floats
	vmovsd	[xmm], xmm0
	vmovsd	[xmm+1*8], xmm1
	vmovsd	[xmm+2*8], xmm2
	vmovsd	[xmm+3*8], xmm3
	vmovsd	[xmm+4*8], xmm4		; TODO not working, unfortunately
	vmovsd	[xmm+5*8], xmm5
	vmovsd	[xmm+6*8], xmm6
	vmovsd	[xmm+7*8], xmm7

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
	test	rdx, rdx
	jnz	.s_ok
	lea	rdx, null_s
	
.s_ok:
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
	push	rdi
	mov	rdi, 1
	lea	rsi, unxp_spec
	mov	rdx, UNXP_SPEC_LEN
	mov	rax, 0x1
	syscall
	pop	rdi
	mov	rax, 1		; ret val = 1 (error)
	jmp	.exit

;	EXIT
;-----------------------------------------------------
.exit:
	call	write

	pop	rbp
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

	test	rcx, rcx
	jnz	.loop
	mov	rcx, 1

.loop:
	test	dl, 1
	setnz	al
	add	al, '0'
	stosb

	and	rdx, ~(1)
	rol	rdx, 1

	loop	.loop
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
	vmovsd	xmm0, [rdx+8*r8]
	inc	qword [xmm_cnt]
ret	; if not stk
.stk:
	vmovsd	xmm0, [rbp]
	add	rbp, 8
ret



; TODO fix printing fractial part & check how fastcall pushed xmm
; expected: %xmm0
print_f:
	vucomisd	xmm0, xmm0
	jnp	.not_nan
	lea	rdx, nan_s
	call	print_s
	jmp	.exit

.not_nan:
	vucomisd	xmm0, qword[inf_val]
	jne	.not_inf
	lea	rdx, inf_s
	call	print_s
	jmp	.exit

.not_inf:
	mov	byte [neg_flt], 0

	vcvttsd2si	rax, xmm0	; %rax = (int) %xmm0
	cmp	rax, 0
	jg	.positive_flt
	mov	byte [neg_flt], 1

.positive_flt:
	vcvtsi2sd	xmm1, xmm1, rax	; %xmm1 = (float) %rax
	call	print_d
	vsubsd	xmm0, xmm1	; %xmm0 -= %xmm1 (%xmm0 = 0.___)

	mov	al, '.'
	stosb

	vmovsd	xmm1, [PREC]
	vmulsd	xmm0, xmm0, xmm1; %xmm0 *= 10^6
	vcvttsd2si	rax, xmm0
	cmp	byte [neg_flt], 0
	je	.next
	mov	rdx, 1000000
	sub	rdx, rax
	xchg	rdx, rax
.next:

	call	print_nd

.exit:
ret



print_nd:
	mov	r8, 10

	mov	rcx, 6
	xor	rdx, rdx
.push_digit:
	div	r8

	add	rdx, '0'
	push	rdx
	xor	rdx, rdx

	loop	.push_digit

	mov	rcx, 6
	cld
.print_digit:
	pop	rax
	stosb
	loop	.print_digit
ret
