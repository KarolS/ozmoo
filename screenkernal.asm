; replacement for these C64 kernal routines and their variables:
; printchar $ffd2
; plot      $fff0
; zp_cursorswitch $cc
; zp_screenline $d1-$d2
; zp_screencolumn $d3
; zp_screenrow $d6
; zp_colorline $f3-$f4
;
; needed to be able to customize the text scrolling to
; not include status lines, especially big ones used in
; Border Zone, and Nord and Bert.
;
; usage: first call s_init, then replace
; $ffd2 with s_printchar and so on.
; s_scrollstart is set to the number of top lines to keep when scrolling
;
; Uncomment TESTSCREEN and call testscreen for a demo.

;TESTSCREEN = 1

!zone screenkernal {

s_init
    ; init cursor
    lda #0
    sta zp_screencolumn
    sta zp_screenrow
    sta .reverse
    lda #$ff
    sta .current_screenpos_row ; force recalculation first time
    ldx #0
    stx s_scrollstart ; how many top lines to protect
    rts

s_plot
    ; y=column (0-39)
    ; x=row (0-24)
    bcc +
    ; get_cursor
    ldx zp_screenrow
    ldy zp_screencolumn
    rts
+   ; set_cursor
    stx zp_screenrow
    sty zp_screencolumn
    rts

s_printchar
    ; replacement for CHROUT ($ffd2)
    ; input: A = byte to write (PETASCII)
    ; output: -
    ; used registers: -
    stx .stored_x
    sty .stored_y
    ; check if colour code
    ldx #0
-   cmp .colors,x
    bne +
    ; color <x> found
    stx .color
    jmp .printchar_end
+   inx
    cpx #16
    bne -
    cmp #20
    bne +
    ; delete
    dec zp_screencolumn ; move back
    bpl ++
    inc zp_screencolumn ; return to 0 if < 0
++  jsr .update_screenpos
    lda #$20
    ldy zp_screencolumn
    sta (zp_screenline),y
    lda .color
    sta (zp_colorline),y
    jmp .printchar_end
+   cmp #$0d
    bne +
    ; newline/enter/return
    lda #0
    sta zp_screencolumn
    inc zp_screenrow
    jsr .s_scroll
    jmp .printchar_end
+   cmp #$93 
    bne +
    ; clr (clear screen)
    lda #0
    sta zp_screencolumn
    sta zp_screenrow
    jsr s_erase_window
    jmp .printchar_end
+   cmp #$12 ; 18
    bne +
    ; reverse on
    ldx #$80
    stx .reverse
    jmp .printchar_end
+   cmp #$92 ; 146
    bne +
    ; reverse off
    ldx #0
    stx .reverse
    jmp .printchar_end
+   ; covert from pet ascii to screen code
    cmp #$40
    bcc ++    ; no change if numbers or special chars
    cmp #$60
    bpl +
    sec
    sbc #64
    bcs ++ ; always jump
+   cmp #$80
    bpl +
    sec
    sbc #32
    bne ++ ; always jump
+   sec
    sbc #128
++  ; print the char
    clc
    adc .reverse
    pha
    jsr .update_screenpos
    pla
    ldy zp_screencolumn
    sta (zp_screenline),y
    lda .color
    sta (zp_colorline),y
    iny
    sty zp_screencolumn
    cpy #40
    bcc .printchar_end
    lda #0
    sta zp_screencolumn
    inc zp_screenrow
    jsr .s_scroll
.printchar_end
    ldx .stored_x
    ldy .stored_y
    rts

s_erase_line
    ; registers: a,x,y
    lda #0
    sta zp_screencolumn
    jsr .update_screenpos
    ldy #0
-   lda #$20
    sta (zp_screenline),y
    lda .color
    sta (zp_colorline),y
    iny
    cpy #40
    bne -
    rts
    
s_erase_window
    lda #0
    sta zp_screenrow
-   jsr s_erase_line
    inc zp_screenrow
    lda zp_screenrow
    cmp #25
    bne -
    lda #0
    sta zp_screenrow
    sta zp_screencolumn
    rts

.update_screenpos
    ; set screenpos (current line) using row
    ldx zp_screenrow
    cpx .current_screenpos_row
    beq +
    ; need to recalculate zp_screenline
    stx .current_screenpos_row
    stx zp_screenline
    ; use the fact that zp_screenrow * 40 = zp_screenrow * (32+8)
    lda #0
    sta zp_screenline + 1
    asl zp_screenline ; *2 no need to rol zp_screenline + 1 since 0 < zp_screenrow < 24
    asl zp_screenline ; *4
    asl zp_screenline ; *8
    ldx zp_screenline ; store *8 for later
    asl zp_screenline ; *16
    rol zp_screenline + 1
    asl zp_screenline ; *32
    rol zp_screenline + 1  ; *32
    txa
    clc
    adc zp_screenline ; add *8
    sta zp_screenline
    sta zp_colorline
    lda zp_screenline + 1
    adc #$04 ; add screen start ($0400)
    sta zp_screenline +1
    adc #$d4 ; add color start ($d800)
    sta zp_colorline + 1
+   rts

.s_scroll
    lda zp_screenrow
    cmp #25
    bpl +
    rts
+   ldx s_scrollstart ; how many top lines to protect
    stx zp_screenrow
-   jsr .update_screenpos
    lda zp_screenline
    pha
    lda zp_screenline + 1
    pha
    inc zp_screenrow
    jsr .update_screenpos
    pla
    sta zp_colorline + 1
    pla
    sta zp_colorline
    ; move characters
    ldy #0
--  lda (zp_screenline),y ; zp_screenrow
    sta (zp_colorline),y ; zp_screenrow - 1
    iny
    cpy #40
    bne --
    ; move color info
    lda zp_screenline + 1
    pha
    clc
    adc #$d4
    sta zp_screenline + 1
    lda zp_colorline + 1
    clc
    adc #$d4
    sta zp_colorline + 1
    ldy #0
--  lda (zp_screenline),y ; zp_screenrow
    sta (zp_colorline),y ; zp_screenrow - 1
    iny
    cpy #40
    bne --
    pla
    sta zp_screenline + 1
    lda zp_screenrow
    cmp #24
    bne -
    jmp s_erase_line

.color !byte 254 ; light blue as default
.reverse !byte 0
.stored_x !byte 0
.stored_y !byte 0
.current_screenpos_row !byte $ff
.colors !byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155

!ifdef TESTSCREEN {

.testtext !pet 5,147,18,"Status Line 123         ",146,13
          !pet 28,"tesx",20,"t aA@! ",18,"Test aA@!",146,13
          !pet 155,"third",20,13
          !pet "fourth line",13
          !pet 13,13,13,13,13,13
          !pet 13,13,13,13,13,13,13
          !pet 13,13,13,13,13,13,13
          !pet "last line",1
          !pet "aaaaaaaaabbbbbbbbbbbcccccccccc",1
          !pet "d",1 ; last char on screen
          !pet "efg",1 ; should scroll here and put efg on new line
          !pet 13,"h",1; should scroll again and f is on new line
          !pet 0

testscreen
    lda #23 ; 23 upper/lower, 21 = upper/special (22/20 also ok)
    sta $d018 ; reg_screen_char_mode
    jsr s_init
    lda #1
    sta s_scrollstart
    ldx #0
-   lda .testtext,x
    bne +
    rts
+   cmp #1
    bne +
    txa
    pha
--  jsr kernel_getchar
    beq --
    pla
    tax
    bne ++
+   jsr s_printchar
++  inx
    bne -
}
}
