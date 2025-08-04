org 0x1000
bits 16

%define ENDL 0x0D,0x0A

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

main: 
  ;setup data segments
  mov ax,0    ;can't write directly to ds/es
  mov ds,ax
  mov es,ax

  ;setup stack
  mov ss,ax
  mov sp, 0x7C00   ;stack grows downwards from where loaded in memory

  ;print message
  mov si,msg_hello
  call puts

  ;print another message to show kernel is running
  mov si,msg_kernel
  call puts

  hlt

.halt:
  jmp .halt

msg_hello: db 'Hello from kernel!',ENDL,0
msg_kernel: db 'Kernel loaded successfully!',ENDL,0



