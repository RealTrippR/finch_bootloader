[private]
default:
	@just -f '{{ justfile() }}' --list

src := "./src"
out := "./bin"

build:
	#!/usr/bin/env sh
	set -ex

	SRC=$(realpath "{{src}}")
	OUT=$(realpath "{{out}}")

	mkdir -p "$OUT" && cd "$OUT" || exit

	nasm -f elf32 -g \
		-o boot.o \
		-I "$SRC" \
		"$SRC/boot.asm"

	nasm -f elf32 -g \
		-o btutil.o \
		-I "$SRC" \
		"$SRC/btutil.asm"

	i686-elf-ld -m elf_i386 \
		-o finchldr.elf \
		-T "$SRC/boot.ld" \
		boot.o btutil.o

	objcopy -O binary finchldr.elf finchldr.bin

clean:
	#!/usr/bin/env sh
	set -ex
	OUT=$(realpath "{{out}}")

	rmdir "$OUT" 
	mkdir "$OUT"