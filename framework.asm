
schedule    = $ff
demopartshi = demoparts+1
demopartslo = demoparts+0

   MAC VECTORS
.RESET SET {1}
.IRQ   SET {2}

   IF * > $F000
      ECHO "ROM:", ($FFFC - *), "bytes left"
   ENDIF

   org $FFFC
   rorg $FFFC

   dc.w .RESET
   dc.w .IRQ
   
   ENDM

; basic setup routine initializing hardware and ram
reset: subroutine
   cld                  ; clear decimal flag
   sei                  ; set interrupt disable
   lda #$00             ; \ 
   tax                  ;  > clear out registers
   tay                  ; / 
.loop:
   sta $00,x            ; \ 
   inx                  ;  > write $00 to entire zero page (tia & ram)
   bne .loop            ; /
   sta TIM64TI          ; set timer to immediate time-out
   ldx #$fe             ; set stack pointer and protect $ff (schedule)
   txs                  ; from being overwritten
                        ; slip through

; wait for the beam to finish travelling over the overscan area and set the
; timer for the next phase: beam travelling over the vblank area (next frame)
waitoverscan: subroutine
   lda #TIMER_VBLANK    ; default value for vblank time-out
   pha                  ; save the timer value on the stack
   php                  ; \ transfer the cpuflags to akku by pushing them onto
   pla                  ; / stack and pulling them back using the akku
   and #%00000100       ; check for irq disabled flag
   bne .nonextpart      ; skip if set

   inc schedule         ; change to next part
   ldx #$82             ; \    
.clrloop:               ;  \  clear out memory $80-$fe
   sta $fe,x            ;   >
   inx                  ;  /  leave TIA untouched
   bne .clrloop         ; /
   
.nonextpart:
   bit TIMINT           ; \ wait until interrupt flag of riot of been set
   bpl .nonextpart      ; / -> timer time-out

   lda #%00001110       ; each '1' bits generate a VSYNC ON line (bits 1..3)
.syncloop:
   sta WSYNC            ; wait for new line
   sta VSYNC            ; 1st '0' bit resets VSYNC, 2nd '0' bit exit loop
   lsr                  ; shift bits through
   bne .syncloop        ; branch until VSYNC has been reset
   pla                  ; pull the timer value from the stack
   sta TIM64TI          ; set timeout to TIMER_VBLANK * 64

   lda schedule         ; load index of the part to run
   asl                  ; shift one bit for correct access of jump table
   tax                  ; move to index register
   lda demopartshi,x    ; load high byte from jump table
   pha                  ; push on stack
   lda demopartslo,x    ; load low byte from jump table
   pha                  ; push on stack
   lda #%00000100       ; set cpuflags: irq disabled, everything else clear
   pha                  ; push on stack
   rti                  ; pull cpuflags from stack and jump to pushed address

; wait for the beam to finish travelling over the vblank area and set the
; timer for the next phase: beam travelling over the screen area
waitvblank: subroutine
   lda #TIMER_SCREEN    ; default value for screen time-out
.loop:
   bit TIMINT           ; \ wait until interrupt flag of riot of been set
   bpl .loop            ; / -> timer time-out
   sta T1024TI          ; set timeout to TIMER_SCREEN * 1024
   lda #$00             ; \ clear out vblank
   sta VBLANK           ; /
   rts                  ; 
   
; wait for the beam to finish travelling over the screen area and set the
; timer for the next phase: beam travelling over the overscan area
waitscreen: subroutine
   lda #TIMER_OVERSCAN  ; default value for overscan time-out
.loop:
   bit TIMINT           ; \ wait until interrupt flag of riot of been set
   bpl .loop            ; / -> timer time-out
   sta TIM64TI          ; set timeout to TIMER_OVERSCAN * 64
   lda #$02             ; \ enable blank
   sta VBLANK           ; /
delay12:                ; small hack: a jsr to an rts takes 12 cycles
   rts                  ; 
