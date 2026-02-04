[BITS 16]

; LABELS ------------------
extern putstr
extern booterr
extern hang
extern errd_msg
extern nl
extern ldsys

; arg: base addr in bx
; ret:
;   ;bx = bx+2
putchs:
    mov ax, 0
    mov al, [bx]
    push bx
    call putax
    pop bx

    mov al, ':'
    call putc

    mov ax, 0

    inc bx
    mov al, [bx]
    and al, 0x3F
    push bx
    call putax
    pop bx

    mov al, ':'
    call putc

    mov ax, 0
    mov al, [bx]
    mov cl, 2
    shl ax, cl
    inc bx
    mov al, [bx]
    push bx
    call putax
    pop bx

    ret

; c in al
; preserves all
putc:
    pusha
    mov ah, 0x0E
    int 0x10
    popa
    ret

; preserves ax
global putax
putax:
    pusha
    mov dx,0
    push dx
.s:
    ; MOD. DX, AX, BX
    mov dx, 0
    mov bx, 10
    div bx
    add dx, 48
    push dx

    cmp ax,0
    jne .s
.p:
    pop dx
    cmp dx,0
    je .r
    mov al, dl
    mov ah, 0x0E
    int 0x10
    jmp .p
.r:
    popa
    ret


; indx. in ax
; start of CHS in bx
; ret:
;   dh:h
;   cl:c-s
;   ch:c
getchs:
    mov cx, 16
    mul cx
    add bx, ax

    mov al, [bx]
    inc bx ;h

    mov cl, [bx]
    inc bx ;c-s

    mov ch, [bx];c

    ret

;mbr idx in ax
;ret:
;   str: bp
;   len: cx
getkrnlname:

    ;push ax
    ;mov ah, 0
    ;mov al, cl

    ;pop ax

    mov bx, 0x7DBF
    call getchs

    ;uncomment to inspect chs elements
    ;mov ah, 0
    ;mov al,dh
    ;call putax
    ;jmp hang

    ; get start
    mov ax, 0
    mov es, ax
    mov bx, 0x8000

    mov ah, 0x2
    mov al, 1 ;sec cnt
    mov dl, [0x7C00]
    int 0x13 ;rd

    mov bx, errd_msg
    jc booterr

    mov bp, 0x8002
    mov ch, 0
    mov cl, [0x8001]

    ret

global mbr_scr
mbr_scr:
    mov bp, sctr_hdr
    mov cx, 33
    call putstr

    mov bl, 0x80
    cmp bl, [0x7DBE]
    jne sk1
    mov ax, 1
    call putax
    mov bx, 0x7DBF
    call addpartopt
sk1:
    mov bl, 0x80
    cmp bl, [0x7DCE]
    jne sk2
    mov ax, 2
    call putax
    mov bx, 0x7DCF
    call addpartopt
sk2:
    mov bl, 0x80
    cmp bl, [0x7DDE]
    jne sk3
    mov ax, 3
    call putax
    mov bx, 0x7DDF
    call addpartopt
sk3:
    mov bl, 0x80
    cmp bl, [0x7DEE]
    jne sk4
    mov ax, 4
    call putax
    mov bx, 0x7DEF
    call addpartopt
sk4:
    mov bp, sel_msg
    mov cx, 4
    call putstr
    ; wait for sel
    xor ax, ax
    .wait:
    int 0x16

    cmp ah,0
    je .wait

    ret

;ax:idx
;bx:offset
addpartopt:

    mov [0x7C04], ax

    push bx
    mov bx, 0x0
    mov ah, 0x03
    int 0x10 ; get cur
    mov [0x7C02], dh

    mov ah, 0x02 ;set cursor
    mov bx, 0x0
    mov dl, 0x2
    int 0x10

    pop bx
    call putchs
    push bx

    mov ah, 0x02 ;set cur
    mov bx, 0x0
    mov dh, [0x7C02]
    mov dl, 0x0D
    int 0x10

    pop bx
    inc bx
    inc bx
    call putchs

    mov ah, 0x02 ;set cur
    mov bx, 0x0
    mov dh, [0x7C02]
    mov dl, 0x17
    int 0x10

    mov al, '>'
    call putc

    mov ax, [0x7C04]
    mov ah, 0
    dec ax
    call getkrnlname

    call putstr


    mov bp, nl
    mov cx, 2
    call putstr
    ret

; ax: MBR idx
global ldsysi
ldsysi:
    ;krnl_size: 0x800E
    ;ld_seg:    0x8010
    ;ld_offset: 0x8012
    ;ep_seg:    0x8014
    ;ep_offset: 0x8016

;start:
    ;c: 0x7C04-5
    ;h: 0x7C06
    ;s: 0x7C07
;end:
    ;c: 0x7C08-9
    ;h: 0x7C0A
    ;s: 0x7C0B
;---- CHS
    ;START:
    mov bx, 0x7DBF
    call getchs

    mov [0x7C04], cx
    and cl, 0x3F
    mov [0x7C07], cl ;s

    mov [0x7C06], dh ;h

    mov ax, [0x7C04]
    mov al,ah
    mov ah, [0x7C04+1]
    shr ah, 6
    mov [0x7C04], ax ;c

; END:
    mov bx, 0x7DC3
    call getchs

    mov [0x7C08], cx
    and cl, 0x3F
    mov [0x7C0B], cl ;s

    mov [0x7C0A], dh ;h

    mov ax, [0x7C08]
    mov al,ah
    mov ah, [0x7C08+1]
    shr ah, 6
    mov [0x7C08], ax ;c


    mov bx, 0x7DBF
    call getchs
    ; load OS header
    xor ax,ax
    mov es,ax
    mov bx, 0x8000 ;es:bx = ld. addr.
    mov di,0
    mov ah, 02h
    mov dl, [0x7C00]
    mov al, 1
    int 0x13

    mov bx, errd_msg
    jc booterr

    cmp al, 1
    jne booterr

    mov ah, 08h
    mov dl, [0x7C00]
    jmp ldsys

; DATA ------------------------------------------
sctr_hdr: db "N",0xBA,"START[hsc]",0xBA,"END  [hsc]",0xC9,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,0xCD,13,10
sel_msg: db "sel:"
