org 0x7C00
bits 16

%define ENDL 0x0D,0x0A



; FAT12 header
jmp short start
nop

bdb_oem:                      db 'MSWIN4.1'         ;8bytes
bdb_bytes_per_sector:         dw 512
bdb_sectors_per_cluster:      db 1
bdb_reserved_sectors:         db 1
bdb_fat_count:                db 2
bdb_dir_entries_count:        dw 0E0h
bdb_total_sectors:            dw 2880                ;2880*512 =1.44MB
bdb_media_descriptor_type:    db 0F0h                ;F0 = 3.5' floppy disk
bdb_sectors_per_fat:          dw 9                   ;9 sectors/fat
bdb_sectors_per_track:        dw 18
bdb_heads:                    dw 2
bdb_hidden_sectors:           dd 0
bdb_large_sector_count:       dd 0

; extended boot record
ebr_drive_number:             db 0                   ;0x00 = floppy, 0x80 hdb, useless 
                              db 0                   ;reserved
ebr_signature:                db 29h 
ebr_volume_id:                db 12h,34h,56h,78h     ;serial number
ebr_volume_label:             db 'KRATOS       ' ;11 bytes, padded with space
ebr_system_id:                db 'FAT12        '     ;8 bytes






start:
  jmp main

; 
; Prints a string to the screen.
; Params :
;     -ds:si points to a string
;
;
puts:
  ;save reisters we will modify
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



main: 
  ;setup data segments
  mov ax,0    ;cant write directly to ds/es
  mov ds,ax
  mov es,ax

  ;setup stack
  mov ss,ax
  mov sp, 0x7C00   ;stack grows downwards from where loaded in memory

  ;print message
  mov si,msg_hello
  call puts



  hlt

.halt:
  jmp .halt

msg_hello: db 'Hello world',ENDL,0

times 510-($-$$) db 0
dw 0AA55h



