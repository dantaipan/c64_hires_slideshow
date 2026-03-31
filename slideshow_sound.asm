.export __LOADADDR__: absolute = 1

.segment "LOADADDR"
    .word $0801

.segment "STARTUP"
    ; 10 SYS 2061
    .word @end
    .word 10
    .byte $9E
    .byte "2061",0
@end:
    .word 0

.segment "CODE"
    jmp _main

; --- Zero Page Bunker ---
BMP_SRC  = $20
SCR_SRC  = $22
BMP_DST  = $24
SID_PTR  = $fb
SID_TICK = $fd
SID_ROW  = $fe
SID_WRIT = $30
FRAME_CT = $32   ; New: Counts frames for the 10-second delay

_main:
    sei
    
    ; 1. Initialize Music
    jsr music_init
    
    ; 2. Setup Raster IRQ
    lda #$7f
    sta $dc0d
    lda $d01a
    ora #$01
    sta $d01a
    
    lda #$00        ; Trigger IRQ at top of screen (Line 0)
    sta $d012
    
    lda #<irq_handler
    sta $0314
    lda #>irq_handler
    sta $0315
    
    ; 3. Setup VIC
    lda #$00
    sta $d020
    lda $d011
    ora #%00100000
    sta $d011
    lda #$18
    sta $d018
    
    cli

main_loop:
    ; Image 1
    lda #<img1_bmp
    sta BMP_SRC
    lda #>img1_bmp
    sta BMP_SRC+1
    lda #<img1_scr
    sta SCR_SRC
    lda #>img1_scr
    sta SCR_SRC+1
    jsr copy_image
    jsr wait_500_frames  ; ~10 seconds on PAL, ~8 on NTSC

    ; Image 2
    lda #<img2_bmp
    sta BMP_SRC
    lda #>img2_bmp
    sta BMP_SRC+1
    lda #<img2_scr
    sta SCR_SRC
    lda #>img2_scr
    sta SCR_SRC+1
    jsr copy_image
    jsr wait_500_frames

    ; Image 3
    lda #<img3_bmp
    sta BMP_SRC
    lda #>img3_bmp
    sta BMP_SRC+1
    lda #<img3_scr
    sta SCR_SRC
    lda #>img3_scr
    sta SCR_SRC+1
    jsr copy_image
    jsr wait_500_frames

    jmp main_loop

; --- IRQ: The ONLY place music_play is called ---
irq_handler:
    asl $d019       ; Clear VIC interrupt flag
    
    jsr music_play  ; Play music tick
    
    lda FRAME_CT    ; Decrement our image timer
    beq @skip
    dec FRAME_CT
@skip:
    jmp $ea31       ; Return to main code

wait_500_frames:
    lda #250
    sta FRAME_CT
@w1:
    lda $dc01       ; Check keyboard (Spacebar column)
    cmp #$ef        ; Is Space pressed?
    beq @skip_wait
    lda FRAME_CT
    bne @w1
    
    lda #250
    sta FRAME_CT
@w2:
    lda $dc01
    cmp #$ef
    beq @skip_wait
    lda FRAME_CT
    bne @w2
    rts

@skip_wait:
    lda #0
    sta FRAME_CT    ; Clear timer so we exit immediately
    rts

copy_image:
    sei             ; Strictly disable music while banking
    lda $01
    pha
    lda #$34
    sta $01
    
    ; Copy Colors
    lda #$00
    sta BMP_DST
    lda #$04
    sta BMP_DST+1
    ldy #0
    ldx #4
@c1:
    lda (SCR_SRC),y
    sta (BMP_DST),y
    iny
    bne @c1
    inc SCR_SRC+1
    inc BMP_DST+1
    dex
    bne @c1
    
    ; Copy Bitmap
    lda #$00
    sta BMP_DST
    lda #$20
    sta BMP_DST+1
    ldy #0
    ldx #32
@c2:
    lda (BMP_SRC),y
    sta (BMP_DST),y
    iny
    bne @c2
    inc BMP_SRC+1
    inc BMP_DST+1
    dex
    bne @c2
    
    pla
    sta $01
    cli             ; Resume music
    rts

music_init:
    lda #0
    sta SID_TICK
    sta SID_ROW
    lda #<sid_pattern_0
    sta SID_PTR
    lda #>sid_pattern_0
    sta SID_PTR+1
    ldx #24
    lda #0
@cl:
    sta $d400,x
    dex
    bpl @cl
    lda #$0F
    sta $d418
    rts

music_play:
    lda SID_TICK
    beq @new_row
    dec SID_TICK
    rts

@new_row:
    lda sid_tempo
    sta SID_TICK
    
    ldy #0
    lda (SID_PTR),y 
    beq @done
    sta SID_WRIT
@loop:
    iny
    lda (SID_PTR),y ; Register
    tax
    iny
    lda (SID_PTR),y ; Value
    sta $d400,x
    dec SID_WRIT
    bne @loop

@done:
    ; 1. Advance the pointer
    iny
    tya
    clc
    adc SID_PTR
    sta SID_PTR
    lda #0
    adc SID_PTR+1
    sta SID_PTR+1
    
    ; 2. Check for Loop
    inc SID_ROW
    lda SID_ROW
    cmp #32         ; End of Pattern
    bne @ex
    
    ; --- HARD RESET SID ON LOOP ---
    ldx #$18        ; Clear all 25 registers
    lda #$00
@clear_loop:
    sta $d400,x
    dex
    bpl @clear_loop
    
    lda #$0F        ; Restore Volume
    sta $d418

    ; 3. Reset Pointers to Start
    lda #0
    sta SID_ROW
    lda #<sid_pattern_0
    sta SID_PTR
    lda #>sid_pattern_0
    sta SID_PTR+1
@ex:
    rts
    
.segment "RODATA"
.res $0700
.include "inc/music.asm"
.res $2000
.include "inc/image1.asm"
.include "inc/image2.asm"
.include "inc/image3.asm"