ENTRY(_entry)

SECTIONS
{
	. = 0x7C00;
	.boot : AT(0x7C00) SUBALIGN(4) {
		boot.o(.text)
	}

	. = 0x7DFE;
	.bootsig : {
		SHORT(0xAA55);
	}

	. = 0x7E00;
	.btutil : AT(0x7E00) SUBALIGN(4) {
		btutil.o(.text);
	}
}
