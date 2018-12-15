
!ifdef ALLRAM {
vmem_cache_cnt !byte 0         ; current execution cache
vmem_cache_index !byte 0,0,0,0,0,0,0,0
}

!ifndef VMEM {
; Non-virtual memory

!ifndef ALLRAM {
read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; x,y (high, low) contains address.
    ; Returns: value in a
    sty mempointer ; low byte unchanged
    ; same page as before?
    cpx zp_pc_l
    bne .read_new_byte
    ; same 256 byte segment, just return
-	ldy #0
	lda (mempointer),y
	rts
.read_new_byte
	txa
    sta zp_pc_l
	clc
	adc #>story_start
	sta mempointer + 1
	bne - ; Always branch
} else {
; No vmem, but ALLRAM 

read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
    sty mempointer ; low byte unchanged
    ; same page as before?
    cpx zp_pc_l
    bne .read_new_byte
    ; same 256 byte segment, just return
.return_result
	ldy #0
	lda (mempointer),y
	rts
.read_new_byte
	txa
    sta zp_pc_l
	clc
	adc #>story_start
	sta mempointer + 1
	cmp #first_banked_memory_page
	bcc .return_result ; Always branch
; swapped memory
	; ; Carry is already clear
	; adc #>story_start
	; sta vmap_c64_offset
	; cmp #first_banked_memory_page
    ; bcc .unswappable
    ; this is swappable memory
    ; update vmem_cache if needed
	; Check if this page is in cache
    ldx #vmem_cache_count - 1
-   cmp vmem_cache_index,x
    beq .cache_updated
    dex
    bpl -
	; The requested page was not found in the cache
    ; copy vmem to vmem_cache (banking as needed)
    sta .copy_from_vmem_to_cache + 2
	ldx vmem_cache_cnt
	; Protect page held in z_pc_mempointer + 1
	pha
	txa
	clc
	adc #>vmem_cache_start
	cmp z_pc_mempointer + 1
	bne +
	inx
	cpx #vmem_cache_count
	bcc ++
	ldx #0
++	stx vmem_cache_cnt

+	pla
	sta vmem_cache_index,x
    lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta .copy_from_vmem_to_cache + 5
    sei
    +set_memory_all_ram
-   ldy #0
.copy_from_vmem_to_cache
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_from_vmem_to_cache
    +set_memory_no_basic
    cli
    ; set next cache to use when needed
	inx
	txa
	dex
	cmp #vmem_cache_count
	bcc ++
	lda #0
++	sta vmem_cache_cnt
.cache_updated
    ; x is now vmem_cache (0-4) where we want to read
    txa
    clc
    adc #>vmem_cache_start
    sta mempointer + 1
	bne .return_result 
    ; ldy #0
    ; lda (mempointer),y
    ; rts
} ; End of block for ALLRAM=1
	
} else {
; virtual memory

; virtual memory address space
; Z1-Z3: 128 kB (0 - $1ffff)
; Z4-Z5: 256 kB (0 - $3ffff)
; Z6-Z8: 512 kB (0 - $7ffff)
;
; map structure: one entry for each block (512 bytes) of available virtual memory
; each map entry is:
; 1 byte: ZMachine offset high byte (bitmask: $80=used, $40=dynamic (rw), $20=referenced)
; 1 byte: ZMachine offset low byte
; 1 byte: C64 offset ($30 - $cf for $3000-$D000)
;
; needs 102*2=204 bytes for $3400-$FFFF
; will store in datasette_buffer
;

!ifdef SMALLBLOCK {
	vmem_blocksize = 512
} else {
	vmem_blocksize = 1024
}

vmem_blockmask = 255 - (>(vmem_blocksize - 1))
vmem_block_pagecount = vmem_blocksize / 256
vmap_max_length  = (vmem_end-vmem_start) / vmem_blocksize
vmap_z_h = datasette_buffer_start
vmap_z_l = vmap_z_h + vmap_max_length

vmap_clock_index !byte 0        ; index where we will attempt to load a block next time

vmap_c64_offset !byte 0
vmap_index !byte 0              ; current vmap index matching the z pointer
vmap_first_swappable_index !byte 0 ; first vmap index which can be used for swapping in static/high memory
vmem_1kb_offset !byte 0         ; 256 byte offset in 1kb block (0-3)
vmem_all_blocks_occupied !byte 0
; vmem_temp !byte 0

!ifdef DEBUG {
!ifdef PREOPT {
print_optimized_vm_map
	jsr printchar_flush
	lda #0
	sta streams_output_selected + 2
	sta is_buffered_window
	jsr newline
	jsr dollar
	jsr dollar
	jsr dollar
	jsr print_following_string
	!pet "clock",13,0
	ldx #0
-	lda vmap_z_h,x
	beq +++
	jsr print_byte_as_hex
	lda vmap_z_l,x
	jsr print_byte_as_hex
	jsr colon
	inx
	cpx #vmap_max_length
	bcc -

	; Print block that was just to be read
-	lda zp_pc_h
	ora #$80 ; Mark as used
	jsr print_byte_as_hex
	lda zp_pc_l
	and #vmem_blockmask
	jsr print_byte_as_hex
	jsr colon
	
+++	jsr newline
	jsr dollar
	jsr dollar
	jsr dollar
	jsr newline
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
}

!ifdef TRACE_VM {
print_vm_map
!zone {
    ; print caches
    jsr space
    lda #66
    jsr streams_print_output
    jsr space
    lda vmem_cache_cnt
    jsr printa
    jsr space
    jsr dollar
    lda vmem_cache_index
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmem_cache_index + 1
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmem_cache_index + 2
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmem_cache_index + 3
    jsr print_byte_as_hex
    jsr newline
    ldy #0
-   ; don't print empty entries
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #$f0
    beq .next_entry
    ; not empty, print
    cpy #10
    bcs +
    jsr space ; alignment when <10
+   jsr printy
    jsr space
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #%11100000
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #%00011111
    jsr printa
    lda vmap_z_l,y ; zmachine mem offset ($0 - 
    jsr print_byte_as_hex
    lda #0 ; add 00
    jsr print_byte_as_hex
    jsr space
	tya
	asl
!ifndef SMALLBLOCK {
	asl
}
	adc #>story_start
    jsr print_byte_as_hex
    lda #$30
    jsr streams_print_output
    lda #$30
    jsr streams_print_output
    jsr newline
.next_entry
    iny 
    cpy #vmap_max_length
    bne -
    rts
}
}
}

load_blocks_from_index
    ; vmap_index = index to load
    ; side effects: a,y,x,status destroyed
!ifdef TRACE_FLOPPY {
	jsr dollar
	jsr dollar
	lda vmap_index
	jsr print_byte_as_hex
	jsr comma
	tax
	lda vmap_z_h,x
	jsr print_byte_as_hex
	lda vmap_z_l,x
	jsr print_byte_as_hex
}

	lda vmap_index
	asl
!ifndef SMALLBLOCK {
	asl
}
	; Carry is already clear
	adc #>story_start

!ifdef TRACE_FLOPPY {
	jsr comma
	jsr print_byte_as_hex
}
	tay ; Store in y so we can use it later.
;	cmp #$e0
;	bcs +
    cmp #first_banked_memory_page
    bcs load_blocks_from_index_using_cache
+	lda #vmem_block_pagecount ; number of blocks
	sta readblocks_numblocks
	sty readblocks_mempos + 1
	lda vmap_z_l,x ; start block
	sta readblocks_currentblock
	lda vmap_z_h,x ; start block
	and #$07
	sta readblocks_currentblock + 1
	jsr readblocks
!ifdef TRACE_VM {
    jsr print_following_string
    !pet "load_blocks (normal) ",0
    jsr print_vm_map
}
    rts

load_blocks_from_index_using_cache
    ; vmap_index = index to load
    ; vmem_cache_cnt = which 256 byte cache use as transfer buffer
	; y = first c64 memory page where it should be loaded
    ; side effects: a,y,x,status destroyed
    ; initialise block copy function (see below)

	; Protect buffer which z_pc points to
	lda vmem_cache_cnt
	tax
	clc
	adc #>vmem_cache_start
	cmp z_pc_mempointer + 1
	bne +
	inx
	cpx #vmem_cache_count
	bcc ++
	ldx #0
++	stx vmem_cache_cnt
+
    ldx vmap_index
    lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta .copy_to_vmem + 2
    sty .copy_to_vmem + 5
    ldx #0 ; Start with page 0 in this 1KB-block
    ; read next into vmem_cache
-   lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta readblocks_mempos + 1
    txa
    pha
    ldx vmap_index
    ora vmap_z_l,x ; start block
    sta readblocks_currentblock
    lda vmap_z_h,x ; start block
    and #$07
    sta readblocks_currentblock + 1
    jsr readblock
    ; copy vmem_cache to block (banking as needed)
    sei
    +set_memory_all_ram
    ldy #0
.copy_to_vmem
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_to_vmem
;    inc .copy_to_vmem + 2
    inc .copy_to_vmem + 5
    +set_memory_no_basic
    cli
    pla
    tax
    inx
	cpx #vmem_block_pagecount ; read 4 blocks (1 kb) in total
    bcc -

	ldx .copy_to_vmem + 5
	dex
	txa
	ldx vmem_cache_cnt
    sta vmem_cache_index,x
    rts

read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
    sty mempointer ; low byte unchanged
    ; same page as before?
    cpx zp_pc_l
    bne .read_new_byte
    cmp zp_pc_h
    bne .read_new_byte
    ; same 256 byte segment, just return
-	ldy #0
	lda (mempointer),y
	rts
.read_new_byte
	cmp #0
	bne .non_dynmem
	cpx nonstored_blocks
	bcs .non_dynmem
	; Dynmem access
	sta zp_pc_h
	txa
    sta zp_pc_l
	adc #>story_start
	sta mempointer + 1
	bne - ; Always branch
.non_dynmem
	sta zp_pc_h
	ora #$80
	sta vmem_temp + 1
	lda #0
	sta vmap_quick_index_match
    txa
    sta zp_pc_l
    and #255 - vmem_blockmask ; keep index into kB chunk
    sta vmem_1kb_offset
	txa
	and #vmem_blockmask
	sta vmem_temp
!ifdef TRACE_VM_PC {
	pha
    lda zp_pc_l
    cmp #$10
    bcs +
    cmp #$08
    bcc +
    jsr print_following_string
    !pet "pc: ", 0
    lda zp_pc_h
    jsr print_byte_as_hex
    lda zp_pc_l
    jsr print_byte_as_hex
    lda mempointer
    jsr print_byte_as_hex
    jsr newline
+
	pla
}
	; Check quick index first
	ldx #vmap_quick_index_length - 1
-	ldy vmap_quick_index,x
    cmp vmap_z_l,y ; zmachine mem offset ($0 -
	beq .quick_index_candidate
	dex
	bpl -
	bmi .no_quick_index_match
.quick_index_candidate
	tya
	tax
	lda vmap_z_h,x
    and #$87
	cmp vmem_temp + 1
	bne .no_quick_index_match
	sta vmap_quick_index_match
	beq .correct_vmap_index_found
.no_quick_index_match
	lda vmem_temp

    ; is there a block with this address in map?
    ldx #vmap_max_length - 1
-   ; compare with low byte
    cmp vmap_z_l,x ; zmachine mem offset ($0 - 
    beq +
.check_next_block
	dex
	cpx vmap_first_swappable_index
    bcs -
	bmi .no_such_block
	; is the block active and the highbyte correct?
+   lda vmap_z_h,x
    and #$87
	cmp vmem_temp + 1
	beq .correct_vmap_index_found
    lda vmem_temp
    jmp .check_next_block ; next entry if used bit not set
.correct_vmap_index_found
    ; vm index for this block found
    stx vmap_index

	lda vmap_z_h,x
	ora #%00100000 		; Set referenced flag
    sta vmap_z_h,x
	ldy vmap_quick_index_match
	bne ++ ; This is already in the quick index, don't store it again
	txa
	ldx vmap_next_quick_index
	sta vmap_quick_index,x
	inx
	cpx #vmap_quick_index_length
	bcc +
	ldx #0
+	stx vmap_next_quick_index
++	jmp .index_found

; no index found, add last
.no_such_block

	; Load 1 KB block into RAM
	ldx vmap_clock_index
-	lda vmap_z_h,x
	bpl .block_chosen
!ifdef DEBUG {
!ifdef PREOPT {
	jmp print_optimized_vm_map
}	
}
	tay
	and #$20
	beq .block_maybe_chosen
	tya
	and #%11011111 ; Turn off referenced flag
	sta vmap_z_h,x
--	inx
	cpx #vmap_max_length
	bcc -
	ldx vmap_first_swappable_index
	bne - ; Always branch
.block_maybe_chosen
	; Protect block where z_pc currently points
	tya
	and #%111
	cmp z_pc
	bne .block_chosen
	lda z_pc + 1
	and #vmem_blockmask
	cmp vmap_z_l,x
	beq -- ; This block is protected, keep looking
.block_chosen
	txa
	tay
	asl
!ifndef SMALLBLOCK {
	asl
}
	; Carry is already clear
	adc #>story_start
	sta vmap_c64_offset
	; Pick next index to use
	iny
	cpy #vmap_max_length
	bcc .not_max_index
	ldy vmap_first_swappable_index
.not_max_index
	sty vmap_clock_index

	; We have now decided on a map position where we will store the requested block. Position is held in x.
!ifdef DEBUG {
!ifdef PRINT_SWAPS {
	lda streams_output_selected + 2
	beq +
	lda #20
	jsr $ffd2
	lda #64
	jsr $ffd2
	lda #20
	jsr $ffd2
	jmp ++
+	jsr space
	jsr dollar
	txa
	jsr print_byte_as_hex
	jsr colon
	lda vmap_c64_offset
	jsr dollar
	jsr print_byte_as_hex
	jsr colon
    lda vmap_z_h,x
	bpl .printswaps_part_2
	and #$7
	jsr dollar
	jsr print_byte_as_hex
    lda vmap_z_l,x
	jsr print_byte_as_hex
.printswaps_part_2
	jsr arrow
	jsr dollar
	lda zp_pc_h
	jsr print_byte_as_hex
    lda zp_pc_l
	and #vmem_blockmask
	jsr print_byte_as_hex
	jsr space
++	
}
}
	
	; Forget any cache pages belonging to the old block at this position.
	lda vmap_c64_offset
	cmp #first_banked_memory_page
	bcc .cant_be_in_cache
	ldy #vmem_cache_count - 1
-	lda vmem_cache_index,y
	and #vmem_blockmask
	cmp vmap_c64_offset
	bne +
	lda #0
	sta vmem_cache_index,y
+	dey
	bpl -
.cant_be_in_cache	

	; Store address of 1 KB block to load, then load it
	lda zp_pc_h
    ora #%10000000 ; mark as used
    sta vmap_z_h,x
    lda zp_pc_l
    and #vmem_blockmask ; skip bit 0,1 since kB blocks
    sta vmap_z_l,x
    stx vmap_index
    jsr load_blocks_from_index
.index_found
    ; index x found
    lda vmap_index
	tax
	asl
!ifndef SMALLBLOCK {
	asl
}
	; Carry is already clear
	adc #>story_start
	sta vmap_c64_offset
	cmp #first_banked_memory_page
    bcc .unswappable
    ; this is swappable memory
    ; update vmem_cache if needed
    clc
    adc vmem_1kb_offset
	; Check if this page is in cache
    ldx #vmem_cache_count - 1
-   cmp vmem_cache_index,x
    beq .cache_updated
    dex
    bpl -
	; The requested page was not found in the cache
    ; copy vmem to vmem_cache (banking as needed)
    sta .copy_from_vmem_to_cache + 2
	ldx vmem_cache_cnt
	; Protect page held in z_pc_mempointer + 1
	pha
	txa
	clc
	adc #>vmem_cache_start
	cmp z_pc_mempointer + 1
	bne +
	inx
	cpx #vmem_cache_count
	bcc ++
	ldx #0
++	stx vmem_cache_cnt

+	pla
	sta vmem_cache_index,x
    lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta .copy_from_vmem_to_cache + 5
    sei
    +set_memory_all_ram
-   ldy #0
.copy_from_vmem_to_cache
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_from_vmem_to_cache
    +set_memory_no_basic
    cli
    ; set next cache to use when needed
	inx
	txa
	dex
	cmp #vmem_cache_count
	bcc ++
	lda #0
++	sta vmem_cache_cnt
.cache_updated
    ; x is now vmem_cache (0-3) where current z_pc is
    txa
    clc
    adc #>vmem_cache_start
    sta mempointer + 1
    ldx vmap_index
    bne .return_result ; always true
.unswappable
    ; update memory pointer
    lda vmem_1kb_offset
    clc
    adc vmap_c64_offset
    sta mempointer + 1
.return_result
    ldy #0
    lda (mempointer),y
    rts
}
