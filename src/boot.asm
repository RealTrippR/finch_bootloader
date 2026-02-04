%include "def.i.asm"

[BITS 16]

; UTILITY ------------------

extern putchs
extern putc
extern putax
extern getchs
extern mbr_scr
extern ldsysi

; MAIN ---------------
; org 0x7C00
global _entry
_entry:
    mov ax, 0
    mov es, ax
    mov bx, 0x7E00 ;es:bx = ld. addr.

    mov byte [0x7E02], 3; check IBM manual, int disk ah=read preserves bx, cx, dx

irr:
    ; read boot utils
    mov ah, DSK_READ_SECTORS
    mov al, 1 ;sec cnt
    mov cl, 2 ;sec no
    mov ch, 0 ;cyl
    mov dh, 0 ;head

    mov [0x7C00], dl ;dl has boot drive
    int INT_DSK ; read krnl
    jnc irs

    dec byte [0x7E02]
    cmp byte [0x7E02], 0
    jne skir
    mov bx, errd_msg
    jc booterr

skir:
    jmp irr

irs:
    cmp al, 1
    mov bx, errs_msg
    jne booterr

    ;set vid. mode - IBM 41
    mov ax, 0x0007 ; 80x25 mono
    int 0x10

    mov bp, boot_msg
    mov cx, 29
    call putstr

    call mbr_scr

    ; sel is in ax (as ASCII CHAR)

    sub ax, 48
    mov ah,0
    pusha
    call putax
    popa
    dec ax
    jmp ldsysi
    ;ldsys_ret:
    ;jmp ax

    ; msg: bx

global booterr
booterr:

    mov cx, 2
    mov bp, nl
    call putstr


    pusha
    xor al,al
    mov ah,1
    int 0x13 ;get bios err
    call putax
    popa


    mov cx, 7
    mov bp, errp_msg
    call putstr


    mov cx, 4
    mov bp, bx
    call putstr

global hang
hang:
    cli
    hlt
    jmp hang

global putstr
putstr:
    pusha
    ;args:
        ;bp: str
        ;cx: len
    push cx

    mov ax, 0
    mov es, ax

    mov ah, 0x03
    mov bh, 0
    int 0x10 ; get cur

    ; str- es:bp
    mov ax, 0x1301 ;write str,update cur on write
    mov bx, 0x000F ;page no,color
    pop cx

    int 0x10
    popa
    ret


; DATA ---------------------
global nl
nl: db 13,10
boot_msg: db "FINCH LDR (C) TRIPP R, 2025", 13, 10
errp_msg: db ":errdsk"
global errd_msg
errd_msg: db "read"
errs_msg: db "size"
erri_msg: db "info"

; drive info
dr_sectr: equ 0x7C0D ; sector cnt
dr_head: equ 0x7C0C ; head cnt
dr_cyl: equ 0x7C0E ; cyl cnt

cur_cyl equ 0x7C04
cur_head equ 0x7C06
cur_sctr  equ 0x7C07

end_cyl equ 0x7C08
end_head equ 0x7C0A
end_sctr equ 0x7C0B

; LDSYS --------------------
global ldsys
ldsys:
    ; query drive info (state for int. is setup in ldsysi)
    int 0x13
    ;ch: low 8 bits of max cyl idx.
    ;cl: bits 0-5 contain the bits of the max sector number (NOTE THAT SECTOR INDEXING STARTS AT 1)
    ;    bits 6-7 (lowk tuffy af) contain bits 8-9 of the cyl idx.
    ;dh: number of drive heads

    mov bx, erri_msg
    jc booterr

    inc dh ;idx to cnt
    mov [dr_head], dh

    mov al, cl
    and al, 0x3F
    mov [dr_sectr], al

    mov al, ch
    mov ah, cl
    shr ah, 6

    mov [dr_cyl], ax

    ;krnl_size: 0x800E
    ;ld_seg:    0x8010
    ;ld_offset: 0x8012
    ;ep_seg:    0x8014
    ;ep_offset: 0x8016


    mov ax, [0x800E]
    mov [0x7C10], ax ;krnl size
    mov ax, [0x8010]
    mov [0x7C12], ax ;ld segment
    mov ax, [0x8012]
    mov [0x7C14], ax ;ld offset
    mov ax, [0x8014]
    mov [0x7C16], ax ;entry segment
    mov ax, [0x8016]
    mov [0x7C18], ax ;entry offset

    ;start:
        ;c: 0x7C04-5
        ;h: 0x7C06
        ;s: 0x7C07
    ;end:
        ;c: 0x7C08-9
        ;h: 0x7C0A
        ;s: 0x7C0B

    ; 0x7C10 -- krnl size <i16>
    ; 0x7C12 -- load segment <i16>
    ; 0x7C14 -- load offset <i16>
    ; 0x7C16 -- entry segment <i16>
    ; 0x7C18 -- entry offset <i16>


    ;inc sector
    ;if sector wrap, inc head
    ;if head wrap, inc track
.rd:
    mov al,0
    ; cmp c
    mov bx,[end_cyl]
    cmp [cur_cyl], bx
    jne .b1
    inc al
.b1:
    mov bl,[end_head]
    cmp [cur_head], bl
    jne .b2
    inc al
.b2:
    mov bl,[end_sctr]
    cmp [cur_sctr], bl
    jne .b3

    cmp al,2
    je .done
.b3:

    mov ax, [0x7C12]
    mov es, ax
    mov bx, [0x7C14]

    mov byte [0x7C30], 3
.rrtry:
    ;es:bx = ld. addr.
    ; http://www.ctyme.com/intr/rb-0607.htm
    mov cl, [cur_sctr]
    mov ch, [cur_cyl]
    mov dh, [cur_head]
    mov dl, [0x7C00]
    mov ah, DSK_READ_SECTORS
    mov al, 1
    int 0x13
    jnc .skrtry
    dec byte [0x7C30]
    cmp byte [0x7C30], 0
    je booterr
    jmp .rrtry
.skrtry:

    ; inc s
    inc byte [cur_sctr]
    mov al, [dr_sectr]
    cmp byte [cur_sctr], al
    jl .sk_hinc

    inc byte [cur_head]
    mov byte [cur_sctr], 1 ; SECTOR INDEXING STARTS AT 1!!! DO NOT FORGET THAT!!!!

    .sk_hinc:
    ; inc h
    mov al, [dr_head]
    cmp byte [cur_head], al
    jl .sk_cinc

    ; inc c
    inc word [cur_cyl]
    mov byte [cur_head], 0

    .sk_cinc:

    ; inc load addr.
    mov ax, [0x7C12];segment
    mov bx, [0x7C14];offset
    cmp bx, 65023
    jbe .sk_seginc
    add ax, 1
    mov [0x7C12], ax
    .sk_seginc:
    add bx, 512
    mov [0x7C14], bx

    jmp .rd
.done:
    push word [0x7C16]   ; s
    push word [0x7C18]   ; o

    retf ;ret far is the same as jmp far (but uses stack params)