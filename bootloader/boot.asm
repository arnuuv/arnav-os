org 0x7C00
bits 16

%define ENDL 0x0D,0x0A
%define KERNEL_OFFSET 0x1000

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
  ;save registers we will modify
  push si
  push ax

.loop:
  lodsb       ;loads character into al
  or al,al    ;verify if next character is null
  jz .done
  
  mov ah, 0x0e    ;call bios interrupt
  mov bh,0
  int 0x10
  jmp .loop

.done:
  pop ax
  pop si
  ret 

;
; Disk operations
;

; Reads sectors from disk
; Params:
;   - ax: LBA address
;   - cl: number of sectors to read
;   - dl: drive number
;   - es:bx: memory address to store sectors
disk_read:
  push ax
  push bx
  push cx
  push dx
  push di

  push cx                     ; Save sector count
  call lba_to_chs            ; Convert LBA to CHS
  pop ax                      ; AL = number of sectors to read
  
  mov ch, BYTE [absoluteTrack]    ; cylinder
  mov cl, BYTE [absoluteSector]   ; sector
  mov dh, BYTE [absoluteHead]     ; head
  mov dl, BYTE [bootDrive]        ; drive
  
  mov ah, 02h
  int 13h
  jc disk_error
  
  pop di
  pop dx
  pop cx
  pop bx
  pop ax
  ret

disk_error:
  mov si, disk_error_msg
  call puts
  jmp $

; Convert LBA to CHS
; Params:
;   - ax: LBA address
; Returns:
;   - absoluteTrack, absoluteSector, absoluteHead
lba_to_chs:
  push ax
  push dx
  
  xor dx, dx                          ; dx = 0
  div WORD [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                      ; dx = LBA % SectorsPerTrack
  inc dx                              ; dx = (LBA % SectorsPerTrack) + 1 = sector
  mov BYTE [absoluteSector], dl
  xor dx, dx                          ; dx = 0
  div WORD [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / NumHeads = cylinder
                                      ; dx = (LBA / SectorsPerTrack) % NumHeads = head
  mov BYTE [absoluteTrack], al
  mov BYTE [absoluteHead], dl
  
  pop dx
  pop ax
  ret

; Load kernel from FAT12 filesystem
load_kernel:
  ; For now, just load from sector 1 (where kernel.bin is stored)
  ; In a real implementation, you'd parse the FAT12 directory and FAT
  mov ax, 1                    ; Start from sector 1 (after bootloader)
  mov cl, 1                    ; Read 1 sector
  mov dl, [bootDrive]
  mov bx, KERNEL_OFFSET
  call disk_read
  ret

main: 
  ;setup data segments
  mov ax,0    ;can't write directly to ds/es
  mov ds,ax
  mov es,ax

  ;setup stack
  mov ss,ax
  mov sp, 0x7C00   ;stack grows downwards from where loaded in memory

  ;save boot drive
  mov [bootDrive], dl

  ;print boot message
  mov si,msg_boot
  call puts

  ;load kernel
  mov si,msg_loading
  call puts

  call load_kernel

  ;print success message
  mov si,msg_loaded
  call puts

  ;jump to kernel
  jmp KERNEL_OFFSET

.halt:
  jmp .halt

; Data
bootDrive: db 0
absoluteTrack: db 0
absoluteSector: db 0
absoluteHead: db 0

msg_boot: db 'Bootloader starting...',ENDL,0
msg_loading: db 'Loading kernel...',ENDL,0
msg_loaded: db 'Kernel loaded! Jumping to kernel...',ENDL,0
disk_error_msg: db 'Disk read error!',ENDL,0

; Boot signature - must be at the end
times 510-($-$$) db 0
dw 0AA55h



