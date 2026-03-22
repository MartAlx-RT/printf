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

times('n'-'d')	dq	OFFSET(printf.dflt)

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
fmt:		db	"%c, my pointer = %p, my str = {%s}, my bits = %b, my decimal = %d", 0xa, 0x0
;fmt:		db	"%d", 0xa, 0x0

; -1, "love", 3802, 100, 31, 33
; fmt:	"%d %s  %x %d%%%b%c"

;-----------------------------------------------------

;=====================================================
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
	mov	r10, [rsp]	; %r10 = ret adr
	sub	rsp, 5*8

	mov	[rsp], rbp	; save %rbp
	mov	[rsp+1*8], rsi
	mov	[rsp+2*8], rdx
	mov	[rsp+3*8], rcx
	mov	[rsp+4*8], r8
	mov	[rsp+5*8], r9
	lea	rbp, [rsp+8]

;	lea	r9, buf
;	add	r9, BUF_SIZE	; %r9 = max avaliable %rdi
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

	mov	rdx, [rbp]
	add	rbp, 8

	lea	r8, spec_jmptbl	; %rbx = absolute jmptbl addr
	and	rax, 0xff
	mov	rax, [r8 + 8*(rax-'a')]
	add	rax, r8
	jmp	rax



;	SPECIFICATOR CHOICE
;-----------------------------------------------------
.spec_b:
	call	print_b
	jmp	.continue

.spec_c:
	movsx	rax, edx
	stosb
	jmp	.continue

.spec_d:
	movsx	rax, edx
	call	print_d
	jmp	.continue

.spec_o:
	call	print_o
	jmp	.continue

.spec_p:
	call	print_p
	jmp	.continue

.spec_s:
	call	print_s
	jmp	.continue

.spec_x:
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
;.write:
;	push	r10
;	lea	rsi, buf
;	mov	rdx, rdi
;	sub	rdx, rsi	; %rdx = %rdi - buf
;	mov	rdi, 1
;	mov	rax, 0x1
;	syscall
;	pop	r10
;	xor	rax, rax	; ret val = 0 (ok)
;
.exit:
	call	write
	pop	rbp
	add	rsp, 4*8
	mov	[rsp], r10
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







