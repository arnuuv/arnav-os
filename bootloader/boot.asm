org 0x7C00
bits 16

%define ENDL 0x0D,0x0A
%define KERNEL_OFFSET 0x1000

; FAT12 header
jmp short start
nop

; BPB
bdb_oem: db 'MSWIN4.1'
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: db 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0F0h
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; EBR
ebr_drive_number: db 0,0
ebr_signature: db 29h
ebr_volume_id: db 12h,34h,56h,78h
ebr_volume_label: db 'KRATOS     '
ebr_system_id: db 'FAT12   '

start:
  jmp main

puts:
  push si
  push ax
.loop:
  lodsb
  or al,al
  jz .done
  mov ah,0x0e
  mov bh,0
  int 0x10
  jmp .loop
.done:
  pop ax
  pop si
  ret

; GDT
gdt_start:
  dq 0
  dw 0xFFFF,0x0000,0x0000,10011010b,11001111b,0x00
  dw 0xFFFF,0x0000,0x0000,10010010b,11001111b,0x00
gdt_end:

gdt_desc:
  dw gdt_end-gdt_start-1
  dd gdt_start

%define CODE_SEG 0x08
%define DATA_SEG 0x10

disk_read:
  push ax
  push bx
  push cx
  push dx
  push cx
  call lba_to_chs
  pop ax
  mov ch,[absoluteTrack]
  mov cl,[absoluteSector]
  mov dh,[absoluteHead]
  mov dl,[bootDrive]
  mov ah,02h
  int 13h
  jc disk_error
  pop dx
  pop cx
  pop bx
  pop ax
  ret

disk_error:
  mov si,disk_error_msg
  call puts
  jmp $

lba_to_chs:
  push ax
  push dx
  xor dx,dx
  div word [bdb_sectors_per_track]
  inc dx
  mov [absoluteSector],dl
  xor dx,dx
  div word [bdb_heads]
  mov [absoluteTrack],al
  mov [absoluteHead],dl
  pop dx
  pop ax
  ret

load_kernel:
  mov ax,1
  mov cl,1
  mov dl,[bootDrive]
  mov bx,KERNEL_OFFSET
  call disk_read
  ret

enter_pm:
  cli
  lgdt [gdt_desc]
  in al,0x92
  or al,2
  out 0x92,al
  mov eax,cr0
  or eax,1
  mov cr0,eax
  jmp CODE_SEG:pm_start

bits 32
pm_start:
  mov ax,DATA_SEG
  mov ds,ax
  mov es,ax
  mov fs,ax
  mov gs,ax
  mov ss,ax
  mov esp,0x90000
  
  mov edi,0xB8000
  mov ecx,2000
  mov ax,0x0720
  rep stosw
  
  mov esi,msg_pm
  call puts_32
  
  call load_kernel_32
  jmp 0x100000

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

load_kernel_32:
  mov esi,KERNEL_OFFSET
  mov edi,0x100000
  mov ecx,512
  rep movsb
  ret

bits 16

main:
  mov ax,0
  mov ds,ax
  mov es,ax
  mov ss,ax
  mov sp,0x7C00
  mov [bootDrive],dl
  
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

bootDrive: db 0
absoluteTrack: db 0
absoluteSector: db 0
absoluteHead: db 0

msg_boot: db 'Bootloader starting...',ENDL,0
msg_loading: db 'Loading kernel...',ENDL,0
msg_loaded: db 'Kernel loaded!',ENDL,0
msg_pm_enter: db 'Entering protected mode...',ENDL,0
msg_pm: db 'Protected mode active! Memory management enabled!',0
disk_error_msg: db 'Disk read error!',ENDL,0

times 510-($-$$) db 0
dw 0AA55h 