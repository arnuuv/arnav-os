org 0x7C00
bits 16

%define ENDL 0x0D,0x0A
%define KERNEL_OFFSET 0x1000   ; where we load kernel in real mode

; FAT12 Boot Sector -------------------------------------------------

jmp short start
nop

; BIOS Parameter Block (BPB)
bdb_oem:                db 'MSWIN4.1'
bdb_bytes_per_sector:   dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors:   dw 1
bdb_fat_count:          db 2
bdb_dir_entries_count:  dw 0E0h
bdb_total_sectors:      dw 2880
bdb_media_descriptor:   db 0F0h
bdb_sectors_per_fat:    dw 9
bdb_sectors_per_track:  dw 18
bdb_heads:              dw 2
bdb_hidden_sectors:     dd 0
bdb_large_sector_count: dd 0

; Extended BPB (FAT12)
ebr_drive_number:       db 0
                        db 0
ebr_signature:          db 29h
ebr_volume_id:          db 12h,34h,56h,78h
ebr_volume_label:       db 'KRATOS     '
ebr_system_id:          db 'FAT12   '

; ------------------------------------------------------------------

start:
    jmp main

; ------------------------------------------------------------------
; 16-bit printing routine (BIOS teletype, int 10h/ah=0Eh)
; ------------------------------------------------------------------
puts:
    push si
    push ax
.loop:
    lodsb
    or al,al
    jz .done
    mov ah,0x0E
    mov bh,0
    int 0x10
    jmp .loop
.done:
    pop ax
    pop si
    ret

; ------------------------------------------------------------------
; GDT for protected mode
; ------------------------------------------------------------------
gdt_start:
    dq 0                          ; null descriptor

    ; code segment descriptor
    dw 0xFFFF                     ; limit low
    dw 0x0000                     ; base low
    db 0x00                       ; base middle
    db 10011010b                  ; access (code, readable, exec)
    db 11001111b                  ; granularity (4K, 32-bit)
    db 0x00                       ; base high

    ; data segment descriptor
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b                  ; access (data, writable)
    db 11001111b
    db 0x00
gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

%define CODE_SEG 0x08
%define DATA_SEG 0x10

; ------------------------------------------------------------------
; BIOS Disk Read
; Reads 1 sector from LBA -> ES:BX
; ------------------------------------------------------------------
disk_read:
    push ax
    push bx
    push cx
    push dx

    ; Convert LBA in AX -> CHS
    call lba_to_chs

    mov ah, 0x02        ; BIOS read sector
    mov al, 1           ; number of sectors
    mov ch,[absoluteTrack]
    mov cl,[absoluteSector]
    mov dh,[absoluteHead]
    mov dl,[bootDrive]
    int 0x13
    jc disk_error       ; carry set = error

    pop dx
    pop cx
    pop bx
    pop ax
    ret

disk_error:
    mov si, disk_error_msg
    call puts
    jmp $

; ------------------------------------------------------------------
; LBA to CHS conversion (for floppy)
; Input: AX = LBA
; Output: absoluteSector, absoluteHead, absoluteTrack
; ------------------------------------------------------------------
lba_to_chs:
    push ax
    push dx
    xor dx, dx
    div word [bdb_sectors_per_track]
    inc dx
    mov [absoluteSector], dl
    xor dx, dx
    div word [bdb_heads]
    mov [absoluteTrack], al
    mov [absoluteHead], dl
    pop dx
    pop ax
    ret

; ------------------------------------------------------------------
; Load kernel into memory at 0x1000
; ------------------------------------------------------------------
load_kernel:
    mov ax,1                 ; sector LBA = 1 (immediately after boot)
    mov bx,KERNEL_OFFSET
    xor ax, ax
    mov es, ax               ; ES = 0x0000
    mov ax,1                 ; reload AX = 1 (for LBA)
    call disk_read
    ret

; ------------------------------------------------------------------
; Switch to Protected Mode
; ------------------------------------------------------------------
enter_pm:
    cli
    lgdt [gdt_desc]

    ; enable A20
    in al,0x92
    or al,2
    out 0x92,al

    ; set PE bit in CR0
    mov eax,cr0
    or eax,1
    mov cr0,eax

    jmp CODE_SEG:pm_start

; ------------------------------------------------------------------
; 32-bit Protected Mode
; ------------------------------------------------------------------
bits 32
pm_start:
    mov ax,DATA_SEG
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov esp,0x90000          ; new stack

    ; clear screen
    mov edi,0xB8000
    mov ecx,2000
    mov ax,0x0720
    rep stosw

    mov esi,msg_pm
    call puts_32

    ; copy kernel to 1MB (0x100000)
    call load_kernel_32

    ; jump to kernel entry point
    jmp CODE_SEG:0x100000

; ------------------------------------------------------------------
; Protected-mode print (VGA text buffer)
; ------------------------------------------------------------------
puts_32:
    push edi
    push eax
    mov edi,0xB8000
.loop:
    lodsb
    or al,al
    jz .done
    mov ah,0x07
    mov [edi],ax
    add edi,2
    jmp .loop
.done:
    pop eax
    pop edi
    ret

; ------------------------------------------------------------------
; Copy kernel (from 0x1000 -> 0x100000)
; ------------------------------------------------------------------
load_kernel_32:
    mov esi,KERNEL_OFFSET
    mov edi,0x100000
    mov ecx,512              ; one sector = 512 bytes
    rep movsb
    ret

; ------------------------------------------------------------------
; 16-bit entry point
; ------------------------------------------------------------------
bits 16
main:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000           ; safe stack

    mov [bootDrive], dl      ; save BIOS drive

    mov si,msg_boot
    call puts

    mov si,msg_loading
    call puts

    call load_kernel

    mov si,msg_loaded
    call puts

    mov si,msg_pm_enter
    call puts

    call enter_pm

.halt:
    jmp .halt

; ------------------------------------------------------------------
; Data
; ------------------------------------------------------------------
bootDrive:       db 0
absoluteTrack:   db 0
absoluteSector:  db 0
absoluteHead:    db 0

msg_boot:        db 'Bootloader starting...',ENDL,0
msg_loading:     db 'Loading kernel...',ENDL,0
msg_loaded:      db 'Kernel loaded!',ENDL,0
msg_pm_enter:    db 'Entering protected mode...',ENDL,0
msg_pm:          db 'Protected mode active! Memory management enabled!',0
disk_error_msg:  db 'Disk read error!',ENDL,0

; Boot sector signature
times 510-($-$$) db 0
dw 0AA55h
