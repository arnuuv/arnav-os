org 0x100000
bits 32

; Kernel entry point
start:
  ; Set up segment registers
  mov ax, 0x10      ; Data segment selector
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  
  ; Set up stack
  mov esp, 0x90000  ; Stack at 576KB
  
  ; Clear screen
  call clear_screen
  
  ; Print welcome message
  mov esi, msg_welcome
  call puts
  
  ; Print memory info
  mov esi, msg_memory
  call puts
  
  ; Print kernel location
  mov esi, msg_kernel_loc
  call puts
  
  ; Print status
  mov esi, msg_status
  call puts
  
  ; Halt the system
  hlt

; Clear the screen
clear_screen:
  push eax
  push ecx
  push edi
  
  mov edi, 0xB8000  ; Video memory address
  mov ecx, 2000     ; 80x25 characters
  mov ax, 0x0720    ; White space on black background
  rep stosw
  
  pop edi
  pop ecx
  pop eax
  ret

; Print a string to the screen
; Params:
;   - esi: pointer to null-terminated string
puts:
  push eax
  push edi
  
  mov edi, 0xB8000  ; Start at top of screen
  
  ; Find current cursor position (simple approach - just start from top)
  ; In a real OS, you'd maintain cursor position
  
.loop:
  lodsb              ; Load character
  or al, al          ; Check if null
  jz .done
  
  mov ah, 0x07      ; White on black attribute
  mov [edi], ax      ; Write character and attribute
  
  add edi, 2         ; Next character position
  
  ; Check if we need to scroll (simple line wrapping)
  cmp edi, 0xB8000 + 160  ; End of first line
  jb .loop
  
  ; Move to next line
  add edi, 160 - 2        ; Next line, adjust for character width
  
  jmp .loop
  
.done:
  pop edi
  pop eax
  ret

; Data
msg_welcome: db 'Welcome to ArnavOS!', 0
msg_memory: db 'Memory management initialized', 0
msg_kernel_loc: db 'Kernel running at 1MB+', 0
msg_status: db 'System ready for GUI development!', 0



