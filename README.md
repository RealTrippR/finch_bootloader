**FINCH BOOTLOADER**

The Finch bootloader is a compact 16-bit bootloader, designed as part of the Finch-8086 IBM PC/XT/AT compatible operating system.

<hr>

**Usage**

The Finch bootloader reads the master boot record and will list any partition marked as bootable.
The first 24 bytes of the first sector in a bootable partition must contain the boot header, which contains the name of the partition and information about where to load and jump to the partiton.

**Contributing**
