; Routines to handle memory

; !ifndef VMEM {
; !zone {
; read_byte_at_z_address
	; ; Subroutine: Read the contents of a byte address in the Z-machine
	; ; a,x,y (high, mid, low) contains address.
	; ; Returns: value in a
	; sty mempointer
	; txa
	; clc
	; adc #>story_start
	; sta mempointer + 1
	; ldy #0
	; lda (mempointer),y
	; rts
; .too_high
    ; lda #ERROR_MEMORY_OVER_64KB
	; jsr fatalerror

; }
; }

inc_z_pc_page
!zone {
	pha
	inc z_pc_mempointer + 1
	inc z_pc + 1
!ifdef VMEM {
	bne +
	inc z_pc
+	lda z_pc + 1
	and #255-vmem_blockmask
	beq get_page_at_z_pc_did_pha
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcc get_page_at_z_pc_did_pha
} else {
; No vmem
	lda z_pc + 1
	cmp #(first_banked_memory_page - (>story_start))
	bcs get_page_at_z_pc_did_pha
}
; safe
	pla
	rts

}

get_page_at_z_pc
!zone {
	pha
get_page_at_z_pc_did_pha
	stx mem_temp
!ifdef ALLRAM {
	lda z_pc
}
	ldx z_pc + 1
	ldy z_pc + 2
	jsr read_byte_at_z_address
	ldy mempointer + 1
	sty z_pc_mempointer + 1
	ldy #0 ; Important: y should always be 0 when exiting this routine!
	ldx mem_temp
	pla
	rts
}


set_z_pc
; Sets new value of z_pc, and makes sure z_pc_mempointer points to the right memory
; Parameters: New value of z_pc in a,x,y
!zone {
	sty z_pc + 2
!ifdef VMEM {
	cmp z_pc
	bne .unsafe_1
}
	cpx z_pc + 1
	beq .same_page 
	; Different page.
!ifdef VMEM {	
	; Let's find out if it's the same vmem block.
	txa
	eor z_pc + 1
	and #vmem_blockmask
	bne .unsafe_2
	; z_pc is in same vmem_block unless it's in vmem_cache
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcc .unsafe_2
	; z_pc is in same vmem_block, but different page.
	stx z_pc + 1
!ifdef SMALLBLOCK {
	lda z_pc_mempointer + 1
	eor #1
	sta z_pc_mempointer + 1
} else {
	txa
	and #255-vmem_blockmask
	sta mem_temp
	lda z_pc_mempointer + 1
	and #vmem_blockmask
	clc
	adc mem_temp
	sta z_pc_mempointer + 1
}
} else {
; No vmem 
	cpx #(first_banked_memory_page - (>story_start))
	bcs .unsafe_2
	stx z_pc + 1
	txa
	clc
	adc #>story_start
	sta z_pc_mempointer + 1
}
.same_page
	rts
.unsafe_1
	sta z_pc
.unsafe_2
	stx z_pc + 1
	jsr get_page_at_z_pc
	rts
}

