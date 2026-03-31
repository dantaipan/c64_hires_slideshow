; --- C64 Triple Slideshow (Stable Working Version) ---
.export __LOADADDR__: absolute = 1

.segment "LOADADDR"
    .word $0801

.segment "STARTUP"
    ; BASIC stub: 10 SYS 2064
    .word @end
    .word 10
    .byte $9E
    .byte "2064",0
@end:
    .word 0

.segment "CODE"
    ; Landing pad to ensure the SYS hits the start of our logic
    jmp _main

; VIC-II Registers
VIC_CTRL_1 = $d011
VIC_MEM    = $d018
BORDER     = $d020

; Target Addresses
BITMAP_RAM = $2000
SCREEN_RAM = $0400

; Zero Page Pointers (Safe Zone)
BMP_SRC = $20
SCR_SRC = $22
BMP_DST = $24

_main:
    ; 1. Setup High-Res Mode
    lda #$00
    sta BORDER
    
    lda VIC_CTRL_1
    ora #%00100000      ; Enable Bitmap Mode
    sta VIC_CTRL_1

    lda #%00011000      ; Screen $0400, Bitmap $2000
    sta VIC_MEM

slideshow_loop:
    ; --- Image 1 ---
    lda #<img1_bmp
    sta BMP_SRC
    lda #>img1_bmp
    sta BMP_SRC+1
    lda #<img1_scr
    sta SCR_SRC
    lda #>img1_scr
    sta SCR_SRC+1
    jsr do_the_copy
    jsr wait_10_seconds

    ; --- Image 2 ---
    lda #<img2_bmp
    sta BMP_SRC
    lda #>img2_bmp
    sta BMP_SRC+1
    lda #<img2_scr
    sta SCR_SRC
    lda #>img2_scr
    sta SCR_SRC+1
    jsr do_the_copy
    jsr wait_10_seconds

    ; --- Image 3 ---
    lda #<img3_bmp
    sta BMP_SRC
    lda #>img3_bmp
    sta BMP_SRC+1
    lda #<img3_scr
    sta SCR_SRC
    lda #>img3_scr
    sta SCR_SRC+1
    jsr do_the_copy
    jsr wait_10_seconds

    jmp slideshow_loop

; --- Copy Routine with Banking ---
do_the_copy:
    sei             ; Disable interrupts for safe banking
    lda $01
    pha             ; Save current memory configuration
    lda #$34        ; Bank out all ROMs to reveal RAM under $A000
    sta $01

    ; 1. Copy Screen Colors (1000 bytes)
    lda #<SCREEN_RAM
    sta BMP_DST
    lda #>SCREEN_RAM
    sta BMP_DST+1

    ldy #0
    ldx #4          ; 4 pages
copy_scr:
    lda (SCR_SRC),y
    sta (BMP_DST),y
    iny
    bne copy_scr
    inc SCR_SRC+1
    inc BMP_DST+1
    dex
    bne copy_scr

    ; 2. Copy Bitmap Data (8000 bytes)
    lda #<BITMAP_RAM
    sta BMP_DST
    lda #>BITMAP_RAM
    sta BMP_DST+1

    ldy #0
    ldx #32         ; 32 pages
copy_bmp:
    lda (BMP_SRC),y
    sta (BMP_DST),y
    iny
    bne copy_bmp
    inc BMP_SRC+1
    inc BMP_DST+1
    dex
    bne copy_bmp

    pla             ; Restore previous memory config (Restore ROMs)
    sta $01
    cli             ; Re-enable interrupts
    rts

; --- Timing Routine ---
wait_10_seconds:
    ldx #10         ; 10 Seconds
@sec:
    ldy #50         ; 50 Frames (PAL)
@frm:
    lda $d012       ; Raster Register
@sync:
    lda $d012
    bne @sync       ; Wait for Raster Line 0
    dey
    bne @frm
    dex
    bne @sec
    rts

; --- Data Section ---
.segment "RODATA"
; This places the data after the active VIC area to avoid collisions
.res $3000

.include "inc/image1.asm"
.include "inc/image2.asm"
.include "inc/image3.asm"