#include <stdio.h>

extern int asm_printf(const char *fmt, ...);

//-1, "love", 3802, 100, 31, 33
//fmt:  "%d %s  %x %d%%%b%c"

const char *fmt_nums = "my decimal = %d, my hex = %x, my oct = %o, my bits = %b\n"
							"%d %s  %x %d%%%b%c\n";
const char *fmt_empty= "";
const char *fmt_d = "%d\n";
const char *fmt_x = "%x\n";
const char *fmt_o = "%o\n";
const char *fmt_b = "%b\n";
const char *fmt_s = "%s\n";


int main(void)
{
	asm_printf("NULL fmt ptr test:\n");
	asm_printf(NULL);

	asm_printf("Empty test (my printf):\n");
	asm_printf(fmt_empty);
	asm_printf("Empty test (std printf):\n");
	printf(fmt_empty);

	asm_printf("dec test (expected -4):\n");
	asm_printf(fmt_d, -4);

	asm_printf("dec test (expected 0):\n");
	asm_printf(fmt_d, 0);

	asm_printf("hex test (expected deadfeed): \n");
	asm_printf(fmt_x, 0xdeadfeed);

	asm_printf("hex test (expected 0): \n");
	asm_printf(fmt_x, 0);
	
	asm_printf("oct test (expected 12345):\n");
	asm_printf(fmt_o, 012345);

	asm_printf("oct test (expected 0):\n");
	asm_printf(fmt_o, 0);

	asm_printf("bin test (expected 10110011100011110000):\n");
	asm_printf(fmt_b, 0b10110011100011110000);

	asm_printf("bin test (expected 0):\n");
	asm_printf(fmt_b, 0);

	asm_printf("null str test:\n");
	asm_printf(

	asm_printf("Ded test (my printf):\n");
	asm_printf(fmt_nums, 1234, 0xdeadbeef, 04321, 0b1011011101111011110, -1, "love", 3802, 100, 31, 33);
	asm_printf("Ded test (std printf):\n");
	    printf(fmt_nums, 1234, 0xdeadbeef, 04321, 0b1011011101111011110, -1, "love", 3802, 100, 31, 33);
	return 0;
}
