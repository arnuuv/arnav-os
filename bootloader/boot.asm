org 0x7C00
bits 16

%define ENDL 0x0D,0x0A
%define KERNEL_OFFSET 0x1000
%define KERNEL_32BIT_OFFSET 0x100000  ; 1MB for 32-bit kernel

; FAT12 header - must be exactly as expected by FAT12
jmp short start
nop

; BIOS Parameter Block (BPB)
bdb_oem:                      db 'MSWIN4.1'         ; 8 bytes
bdb_bytes_per_sector:         dw 512
bdb_sectors_per_cluster:      db 1
bdb_reserved_sectors:         db 1
bdb_fat_count:                db 2
bdb_dir_entries_count:        dw 0E0h
bdb_total_sectors:            dw 2880                ; 2880*512 = 1.44MB
bdb_media_descriptor_type:    db 0F0h                ; F0 = 3.5' floppy disk
bdb_sectors_per_fat:          dw 9                   ; 9 sectors/fat
bdb_sectors_per_track:        dw 18
bdb_heads:                    dw 2
bdb_hidden_sectors:           dd 0
bdb_large_sector_count:       dd 0

; Extended Boot Record
ebr_drive_number:             db 0                   ; 0x00 = floppy, 0x80 = hdd
                              db 0                   ; reserved
ebr_signature:                db 29h 
ebr_volume_id:                db 12h,34h,56h,78h     ; serial number
ebr_volume_label:             db 'KRATOS     '       ; 11 bytes, padded with space
ebr_system_id:                db 'FAT12   '          ; 8 bytes

start:
  jmp main

; 
; Prints a string to the screen.
; Params :
;     -ds:si points to a string
;
puts:
  push si
  push ax
.loop:
  lodsb
  or al,al
  jz .done
  mov ah, 0x0e
  mov bh,0
  int 0x10
  jmp .loop
.done:
  pop ax
  pop si
  ret 

; Global Descriptor Table
gdt_start:
  dq 0                    ; Null descriptor
  dw 0xFFFF,0x0000       ; Code segment
  db 0x00,10011010b,11001111b,0x00
  dw 0xFFFF,0x0000       ; Data segment
  db 0x00,10010010b,11001111b,0x00
gdt_end:

gdt_descriptor:
  dw gdt_end - gdt_start - 1
  dd gdt_start

%define CODE_SEG 0x08
%define DATA_SEG 0x10

; Disk operations
disk_read:
  push ax
  push bx
  push cx
  push dx
  push cx
  call lba_to_chs
  pop ax
  mov ch, BYTE [absoluteTrack]
  mov cl, BYTE [absoluteSector]
  mov dh, BYTE [absoluteHead]
  mov dl, BYTE [bootDrive]
  mov ah, 02h
  int 13h
  jc disk_error
  pop dx
  pop cx
  pop bx
  pop ax
  ret

disk_error:
  mov si, disk_error_msg
  call puts
  jmp $

lba_to_chs:
  push ax
  push dx
  xor dx, dx
  div WORD [bdb_sectors_per_track]
  inc dx
  mov BYTE [absoluteSector], dl
  xor dx, dx
  div WORD [bdb_heads]
  mov BYTE [absoluteTrack], al
  mov BYTE [absoluteHead], dl
  pop dx
  pop ax
  ret

load_kernel:
  mov ax, 1
  mov cl, 1
  mov dl, [bootDrive]
  mov bx, KERNEL_OFFSET
  call disk_read
  ret

enter_protected_mode:
  cli
  lgdt [gdt_descriptor]
  in al, 0x92
  or al, 2
  out 0x92, al
  mov eax, cr0
  or eax, 1
  mov cr0, eax
  jmp CODE_SEG:protected_mode_start

bits 32
protected_mode_start:
  mov ax, DATA_SEG
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov esp, 0x90000
  
  ; Clear screen
  mov edi, 0xB8000
  mov ecx, 2000
  mov ax, 0x0720
  rep stosw
  
  ; Print message
  mov esi, msg_protected
  call puts_32
  
  ; Load kernel to high memory
  call load_kernel_32
  jmp KERNEL_32BIT_OFFSET

puts_32:
  push edi
  push eax
  mov edi, 0xB8000
.loop:
  lodsb
  or al, al
  jz .done
  mov ah, 0x07
  mov [edi], ax
  add edi, 2
  jmp .loop
.done:
  pop eax
  pop edi
  ret

load_kernel_32:
  mov esi, KERNEL_OFFSET
  mov edi, KERNEL_32BIT_OFFSET
  mov ecx, 512
  rep movsb
  ret

bits 16

main: 
  mov ax,0
  mov ds,ax
  mov es,ax
  mov ss,ax
  mov sp, 0x7C00
  mov [bootDrive], dl
  
  mov si,msg_boot
  call puts
  
  mov si,msg_loading
  call puts
  
  call load_kernel
  
  mov si,msg_loaded
  call puts
  
  mov si,msg_entering_pm
  call puts
  
  call enter_protected_mode

.halt:
  jmp .halt

; Data
bootDrive: db 0
absoluteTrack: db 0
absoluteSector: db 0
absoluteHead: db 0

msg_boot: db 'Bootloader starting...',ENDL,0
msg_loading: db 'Loading kernel...',ENDL,0
msg_loaded: db 'Kernel loaded!',ENDL,0
msg_entering_pm: db 'Entering protected mode...',ENDL,0
msg_protected: db 'Protected mode active! Memory management enabled!',0
disk_error_msg: db 'Disk read error!',ENDL,0

times 510-($-$$) db 0
dw 0AA55h



