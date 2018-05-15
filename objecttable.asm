; object table
; see: http://inform-fiction.org/zmachine/standards/z1point1/sect12.html

; globals
num_default_properties !byte 0
default_properties_ptr !byte 0, 0

; object table opcodes
z_ins_get_sibling
    ; get_sibling object -> (result) ?(label)
    jsr fatalerror
    !pet "TODO z_ins_get_sibling", 13, 0

z_ins_get_child
    ; get_child object -> (result) ?(label)
    jsr fatalerror
    !pet "TODO z_ins_get_child", 13, 0

z_ins_get_parent
    ; get_parent object -> (result)
    jsr fatalerror
    !pet "TODO z_ins_get_parent", 13, 0

z_ins_get_prop_len
    ; get_prop_len property-address -> (result)
    jsr fatalerror
    !pet "TODO z_ins_get_prop_len", 13, 0

z_ins_remove_obj
    ; remove_obj object
    jsr fatalerror
    !pet "TODO z_ins_remove_obj", 13, 0

z_ins_print_obj
    ; print_obj object
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jmp ot_print_obj

z_ins_jin
    ; jin obj1 obj2 ?(label)
    jsr fatalerror
    !pet "TODO z_ins_jin", 13, 0

z_ins_test_attr
    ; test_attr object attribute ?(label)
    jsr fatalerror
    !pet "TODO z_ins_test_addr", 13, 0

z_ins_set_attr
    ; set_attr object attribute
    jsr fatalerror
    !pet "TODO z_ins_set_attr", 13, 0

z_ins_clear_attr
    ; clear_attr object attribute
    jsr fatalerror
    !pet "TODO z_ins_clear_attr", 13, 0

z_ins_insert_obj
    ; insert_obj object destination
    jsr fatalerror
    !pet "TODO z_ins_insert_obj", 13, 0

z_ins_get_prop
    ; get_prop object property -> (result)
    jsr fatalerror
    !pet "TODO z_ins_get_prop", 13, 0

z_ins_get_prop_addr
    ; get_prop_addr object property -> (result)
    jsr fatalerror
    !pet "TODO z_ins_prop_addr", 13, 0

z_ins_get_next_prop
    ; get_next_prop object property -> (result)
    jsr fatalerror
    !pet "TODO z_ins_next_prop", 13, 0

z_ins_put_prop
    ; put_prop object property value
    jsr fatalerror
    !pet "TODO z_ins_put_prop", 13, 0

parse_object_table
    lda story_start + header_object_table     ; high byte
    ldx story_start + header_object_table + 1 ; low byte
    jsr set_z_address
    ; property defaults table
    stx default_properties_ptr
    clc
    adc #>story_start
    sta default_properties_ptr + 1
!ifndef Z4PLUS {
    ldx #62 ; 31 words
}
!ifdef Z4PLUS {
    ldx #126 ; 63 words
}
    stx num_default_properties
    rts

ot_print_obj
    stx object_tree_ptr
    clc
    adc #>story_start
    sta object_tree_ptr + 1
!ifndef Z4PLUS {
    ldy #8
}
!ifdef Z4PLUS {
    ldy #13
}
    lda (object_tree_ptr),y ; low byte
    tax
    dey
    lda (object_tree_ptr),y ; high byte
    jsr set_z_address
    jsr read_next_byte ; length of object short name
    jsr print_addr
    rts

!ifdef DEBUG {
test_object_table
    ldx #$40
    lda #$01 ; $0140 = first object in dejavu.z3
    jmp  ot_print_obj

}