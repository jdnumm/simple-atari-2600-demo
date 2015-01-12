
   processor 6502
   include vcs.h

   seg.u $80
   org $80

framecount:
   ds.b 1

   seg
   org $f000
   rorg $f000

TIMER_VBLANK   = $2a ;  ~2688 cycles
TIMER_SCREEN   = $13 ; ~77824 cycles
TIMER_OVERSCAN = $14 ;  ~1280 cycles

; load data for sinus table
   include sinustab.asm

; load graphics data
   include images/logo.asm

; jumptable of demoparts
demoparts:
   dc.w showlogo,reset

; load in the framework code
code   include framework.asm

; main code
showlogo:
   inc framecount   ; increment frame counter
   ldx framecount   ; load frame counter
   lda sinustab,x   ; get sinus value
   tax              ; move to x
   lda #$04         ; \ PF over sprites
   sta CTRLPF       ; /
   lda #$f0         ; \
   sta HMP1         ;  \ move sprite one to the right
   sta WSYNC        ;  /
   sta HMOVE        ; /
   lda #$02         ; \ create a simple sound effect:
   sta AUDC0        ; / low running rumble/motor-like noise
   txa              ; \
   lsr              ;  \
   lsr              ;   \  set frequency divider to $10-$1f
   lsr              ;    > according to value from sinus table
   clc              ;   /  
   adc #$10         ;  /  
   sta AUDF0        ; / 

   lda #$0e
   sta COLUPF       ; 3= 9
   
   jsr waitvblank   ; wait for the vblank area to complete

.waitloop1:
   sta WSYNC        ; wait until start of next line
   dex              ; decrement sinus value
   dex              ; decrement sinus value
   bpl .waitloop1   ; loop until index register is zero

   ldy #(logo1-logo0-1) ; number of image lines
   lda #$0e         ; \ set player1 color for "highlight effect"
   sta COLUP1       ; /
   lda #$ff         ; \
   sta PF0          ;  \ reverse playfield to hide sprite
   sta PF1          ;  /
   sta PF2          ; /
   lda SWCHB        ; \
   and #$08         ;  \  test for b/w
   eor #$08         ;   >
   ;beq .skip        ;  /  bw -> show sprite / color -> sprite off
   lda #%01011010   ; /
.skip:
   sta GRP1         ; write data to sprite to either show or hide
   sta AUDV0        ; set audio volume
.dataloop:
   ldx #$07         ; 2=69 set lines counter to 6 iterations
.showloop:
   sta WSYNC        ; 3=72 wait until start of next line
   ;txa              ; 2= 2
   ;asl              ; 2= 4
   ;adc #$d0         ; 2= 6
   nop
   lda #$e0
   sta COLUBK       ; 3= 9
   lda logo0,y      ; 5=14
   sta PF0          ; 3=17
   lda logo1,y      ; 5=22
   sta PF1          ; 3=25
   lda logo2,y      ; 5=30
   sta PF2          ; 3=33
   lda logo3,y      ; 5=38
   sta PF0          ; 3=41
   lda logo4,y      ; 5=46
   sta PF1          ; 3=49
   lda logo5,y      ; 5=54
   sta PF2          ; 3=57
   dex              ; 2=59
   bne .showloop    ; 2=62/63
   dey              ; 2=64
   bpl .dataloop    ; 3=67

   sta WSYNC        ; 
   stx PF0          ; clear out PF0
   stx PF1          ; clear out PF1
   stx PF2          ; clear out PF2
   stx GRP1         ; clear out sprite

   ldx #$0e
   stx COLUBK       ; index register now is 0: set color to black
   jsr waitscreen   ; wait until screen area is finished
   jmp waitoverscan ; wait until overscan area is finished and run sync of
                    ; new frame

   VECTORS reset,reset
