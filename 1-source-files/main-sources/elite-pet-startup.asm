INCLUDE "1-source-files/main-sources/elite-pet.inc"

; OSWORD emulation zero page (lives in MOS' filesystem area, which Elite doesn't use).

    org &90
.irqv                   skip 2  ; address of our interrupt handler; PET OS

    org &b0
.cmdblock               skip 2  ; address of MOSE parameter block
.oscli_file             skip 1  ; file index of file being worked on
.ptr                    skip 2  ; address of file being worked on
.ieee_has_buffered_char skip 1  ; whether the IEEE layer has a buffered char
.ieee_buffered_char     skip 1  ; the actual buffered char

; Used internally by the decompressor
.zx0_offset             skip 2
.zx0_bits               skip 2
.zx0_length             skip 2
.zx0_dstptr             skip 2

DL = &8b        ; used to find out if a refresh has happened
BRKMSG = &fd    ; address of error messages
CHPR = &11e9
BRKHANDLER = &11ee ; BRK handler
LASCT = &346    ; laser timeout

HIMEM = &7b00   ; last available memory location

basic_start = &03ff
    
; BASIC stub

    org basic_start
    equw P%+2
    equw _entry_string_end, 1
    equb &9e        ; SYS
    equs "1037"     ; decimal address of _start
    equb 0
._entry_string_end
    equw 0

; Startup and relocation code

._start
    ; Set uppercase mode.

    jsr cls
    lda #&ac
    sta PET_VIA_PCR

    ; Draw the logo.

    ldx #0
    {
        .loop
        lda logo, x
        sta &8000, x
        lda logo+&100, x
        sta &8100, x
        lda logo+&200, x
        sta &8200, x
        lda logo+&300, x
        sta &8300, x
        dex
        bne loop
    }

    ; Copy the relocated code to its final address.

    ldx #0
    {
    .loop
        src = P%+1
        lda _relocated_code, x
        dst = P%+1
        sta _mose_start, x
        inx
        bne loop

        inc src+1
        inc dst+1

        lda dst+1
        cmp #hi(HIMEM)
        bne loop
    }

    lda #0
    sta ieee_has_buffered_char
    sta ieee_buffered_char

    ; Set up the interrupt handler.

    sei
    lda #%01111111
    sta PET_VIA_IER                 ; disable external interrupt generation
    sta PET_VIA_IFR                 ; clear pending interrupt flags

    lda PET_PIA1_CA
    and #%11111110
    sta PET_PIA1_CA

    lda PET_PIA1_CB
    and #%11111111
    sta PET_PIA1_CB

    lda PET_PIA2_CA
    and #%11111110
    sta PET_PIA2_CA

    lda PET_PIA2_CB
    and #%11111110
    sta PET_PIA2_CB

    lda #lo(irq)
    sta irqv+0
    lda #hi(irq)
    sta irqv+1
    cli                             ; it's now safe to enable interrupts

    ; Load the second stage loader.

    ldx #lo(elite2_oscli)
    ldy #hi(elite2_oscli)
    jsr oscli

    ; Set lowercase mode.

    jsr cls
    lda #&ae
    sta PET_VIA_PCR

    jmp (elite4_exec)

.elite2_oscli
    equs "L.ELITE4", &0d

.cls
    ldx #0
    lda #&60
    {
        .loop
        sta &8000, x
        sta &8100, x
        sta &8200, x
        sta &8300, x
        dex
        bne loop
    }
    rts

; Initialises the IEEE488 library.

.io_init
    rts
    
.logo
    INCBIN "1-source-files/images/pet-acornsoft-logo.bin"

._relocated_code

 ; OSFILE emulation

    org &7000
    guard &7b00
._mose_start
.oscli jmp oscli_impl
.osword jmp osword_impl
.osfile jmp osfile_impl
.osbyte jmp osbyte_impl

.osfile_impl
    stx cmdblock+0
    sty cmdblock+1

    cmp #&ff
    beq osfile_load
    cmp #0
    beq osfile_save
    rts

.osfile_load
    lda #0
    jsr osfile_setup_file_transfer

    ; Get the load address from command block.

    ldy #2
    lda (cmdblock), y
    sta ptr+0
    iny
    lda (cmdblock), y
    sta ptr+1

    ; Now read the file.

    lda #&60        ; READ channel 0
    jsr ieee_talk
    ldy #0
    {
        .loop
        jsr ieee_getb
        bcs eoi

        sta (ptr), y
        inc ptr+0
        bne P%+4
        inc ptr+1

        jmp loop
        .eoi
    }
    jsr ieee_untalk

    lda #&e0        ; CLOSE channel 0
    jsr ieee_listen
    jmp ieee_unlisten

.osfile_save
    lda #1
    jsr osfile_setup_file_transfer

    ; Get the save address and end address from the command block.

    ldy #&a
    lda (cmdblock), y
    sta ptr+0
    iny
    lda (cmdblock), y
    sta ptr+1

    ; Now write the file.

    lda #&61        ; WRITE channel 1
    jsr ieee_listen
    {
        .loop

        ldy #0
        lda (ptr), y
        jsr ieee_write

        inc ptr+0
        bne P%+4
        inc ptr+1

        ldy #&e
        lda ptr+0
        cmp (cmdblock), y
        bne loop
        iny
        lda ptr+1
        cmp (cmdblock), y
        bne loop
    }
    jsr ieee_unlisten

    lda #&e1        ; CLOSE channel 1
    jsr ieee_listen
    jmp ieee_unlisten

; On entry: A = channel number
.osfile_setup_file_transfer
    ; Setup.

    pha
        ldy #0                  ; copy the filename ptr into ptr
        lda (cmdblock), y
        sta ptr+0
        iny
        lda (cmdblock), y
        sta ptr+1
    pla

    ; Open the output channel and send the name.

    pha
        ora #&f0        ; OPEN channel
        jsr ieee_listen
    pla

    {
        ror a
        bcc notsave

        lda #'@'        ; this is a save; tell the drive to overwrite
        jsr ieee_write
        lda #'0'
        jsr ieee_write
        lda #':'
        jsr ieee_write

        .notsave
    }

    ldy #3
    {
    .loop
        lda (ptr), y
        cmp #&0d
        beq endloop
        jsr ieee_write
        iny
        bne loop    ; Always taken
    .endloop
    }
    jsr ieee_unlisten
    ; falls through into checkerror

; Reads the command channel to check for an error.
.checkerror
{
    ; Read the error string into errorbuffer+1.

    lda #&6f                ; OPEN command channel
    jsr ieee_talk
    ldx #0
    {
        .loop
        jsr ieee_getb
        bcs endloop

        sta errorbuffer+1, x
        inx
        bne loop            ; always taken
        .endloop
    }
    jsr ieee_untalk

    ; Check the first two bytes. They will be 0 if there is no error.

    lda errorbuffer+1
    cmp #'0'
    bne error
    lda errorbuffer+2
    cmp #'0'
    bne error
    rts

    ; An error has occurred!

    .error
    lda #lo(errorbuffer)
    sta BRKMSG+0
    lda #hi(errorbuffer)
    sta BRKMSG+1
    jmp BRKHANDLER
    jmp ieee_untalk
}

.errorbuffer
    brk
    skip 40

.osword_impl
.osbyte_impl
    rts

.oscli_delete
    ; Open the command channel.

    lda #&ff        ; OPEN channel 2
    jsr ieee_listen

    ; Send the "S0:E." command prefix.

    ldy #(delete_cmd_end - delete_cmd - 1)
    {
        .loop
        lda delete_cmd, y
        jsr ieee_write
        dey
        bpl loop
    }

    ; Send the filename. 

    ldy #6
    {
        .loop
        lda (cmdblock), y
        cmp #13
        beq endloop
        jsr ieee_write
        iny
        jmp loop
        .endloop
    }

    jsr ieee_unlisten
    jmp checkerror

.delete_cmd
    equs ".E:0S" ; backwards!
.delete_cmd_end

.oscli_impl
    stx cmdblock+0
    sty cmdblock+1

    ldy #0
    lda (cmdblock), y
    cmp #'R'
    beq oscli_run
    cmp #'L'
    beq oscli_load
    cmp #'.'
    beq oscli_cat
    cmp #'D'
    beq oscli_delete
    rts

.oscli_run
    jsr oscli_load

    ; Run the program.

    ldx oscli_file
    lda filetable+3, x
    sta zx0_dstptr+0
    lda filetable+4, x
    sta zx0_dstptr+1
    jmp (zx0_dstptr)

.jmp_elite4_seq
    jmp &197b

.oscli_load
    jsr lookup_file
    stx oscli_file

    ; Send the filename

    lda #&f2        ; OPEN channel 2
    jsr ieee_listen
    ldy #2
    {
    .loop
        lda (cmdblock), y
        cmp #&0d
        beq endloop
        jsr ieee_write
        iny
        bne loop    ; Always taken
    .endloop
    }
    jsr ieee_unlisten

    ; Get the load address from the file table.

    ldx oscli_file
    lda filetable+1, x
    sta zx0_dstptr+0
    lda filetable+2, x
    sta zx0_dstptr+1

    ; Now read the file.

    lda #&62        ; READ channel 2
    jsr ieee_talk
    jsr zx0_unpack
    jsr ieee_untalk

    lda #&e2        ; CLOSE channel 2
    jsr ieee_listen
    jmp ieee_unlisten

; Show the disk catalogue. This is gruesomely hacky. 
; It only shows commander files, which start "E.".

.oscli_cat
    ; Ask to read $.

    lda #&f0        ; OPEN channel 0
    jsr ieee_listen
    lda #'$'
    jsr ieee_write
    jsr ieee_unlisten

    ; Start reading the 'Basic' program.

    lda #&60        ; READ channel 0
    jsr ieee_talk

    jsr ieee_getb2  ; skip the address
    {
        .loop
        jsr ieee_getb4  ; skip next-line pointer, line number
        {
            .skiploop       ; skip to the first "
            jsr ieee_getb
            bcs endloop     ; exit if EOI
            cmp #'"'
            bne skiploop
        }

        jsr ieee_getb       ; first letter of filename
        cmp #'E'
        bne skip_to_eol

        jsr ieee_getb       ; second letter of filename
        cmp #'.'
        bne skip_to_eol

        {
            .printloop      ; print to the next "
            jsr ieee_getb
            cmp #'"'
            beq endloop
            jsr CHPR
            jmp printloop
            .endloop
        }

        lda #13
        jsr CHPR            ; print a CR
        lda #10
        jsr CHPR            ; print a LF

    .skip_to_eol
        jsr ieee_getb
        bne skip_to_eol
        beq loop            ; always taken

        .endloop
    }

    jsr ieee_untalk

    lda #&e0        ; CLOSE channel 2
    jsr ieee_listen
    jmp ieee_unlisten

; Given a OSCLI string in (mose_addr), looks up which file it's trying to load
; and return an offset into filetable for it in x.

.lookup_file
    ldx #0
    {
        .loop
        ldy #4
        lda (cmdblock), y          ; get char 5 of oscli string
        cmp filetable, x
        beq match

        txa
        clc
        adc #5
        tax
        lda filetable, x
        bne loop
        jmp P%                      ; no match
        .match
    }
    rts

.filetable
    equb "I" ; ELITE4
    equw &1900
.elite4_exec
    equw &1900
    equb "C" ; D.CODE, T.CODE
    equw &11e3
    equw &11e3
    equb "M" ; D.MO*
    equw &5600
    equw &5600
    equb 0

macro set1 port, bit
    lda port
    ora #bit
    sta port
endmacro

macro set0 port, bit
    lda port
    and #(bit eor &ff) and &ff
    sta port
endmacro

.ieee_computer_atn
    set0 PET_VIA_PB, PET_VIA_PB_ATN_OUT
    rts

.ieee_computer_idle
.ieee_computer_talking
    set1 PET_VIA_PB, PET_VIA_PB_ATN_OUT
    rts

.ieee_computer_listening
    set1 PET_VIA_PB, PET_VIA_PB_ATN_OUT
    rts

.ieee_puteoib
    pha
    set0 PET_PIA1_CA, PET_PIA1_CA_EOI_OUT
    pla
    ; fall through
.ieee_putb
    ; Deassert our own NRFD and NDAC and wait for NRFD=0 (i.e. ready for data)

    pha
    set1 PET_VIA_PB, PET_VIA_PB_NRFD_OUT
    set1 PET_PIA2_CA, PET_PIA2_CA_NDAC_OUT
    {
    .loop
        lda PET_VIA_PB
        and #PET_VIA_PB_NRFD_IN
        beq loop
    }
    pla

    ; Send data, inverted.

    eor #&ff
    sta PET_PIA2_PB

    ; Set DAV to 0 (i.e. data is available)

    set0 PET_PIA2_CB, PET_PIA2_CB_DAV_OUT

    ; Wait for acknowledgement.

    {
    .loop
        lda PET_VIA_PB
        and #PET_VIA_PB_NDAC_IN
        beq loop
    }

    ; Release DAV, EOI, and the data bus.

    set1 PET_PIA2_CB, PET_PIA2_CB_DAV_OUT
    set1 PET_PIA1_CA, PET_PIA1_CA_EOI_OUT
    lda #&ff
    sta PET_PIA2_PB

    rts

; Receives a byte into A. Sets C on EOI.
; Preserves X and Y.

.ieee_getb4
    jsr ieee_getb2
.ieee_getb2
    jsr ieee_getb
.ieee_getb
    ; Set NRFD = 1 (indicating we are ready for data).
    ; Set NDAC = 0 (no data acknowledgement).

    set1 PET_VIA_PB, PET_VIA_PB_NRFD_OUT
    set0 PET_PIA2_CA, PET_PIA2_CA_NDAC_OUT

    ; Wait for DAV.

    {
    .loop
        lda PET_VIA_PB
        and #PET_VIA_PB_DAV_IN
        bne loop
    }

    ; Not ready for data.

    set0 PET_VIA_PB, PET_VIA_PB_NRFD_OUT

    ; Get the data.

    lda PET_PIA2_PA
    eor #&ff
    pha

    ; Check for EOI.

    lda PET_PIA1_PA
    and #PET_PIA1_PA_EOI_IN
    clc
    {
        bne skip
        sec
        .skip
    }

    ; Acknowledge the data.

    set1 PET_PIA2_CA, PET_PIA2_CA_NDAC_OUT

    ; Wait for !DAV.

    {
    .loop
        lda PET_VIA_PB
        and #PET_VIA_PB_DAV_IN
        beq loop
    }

    ; Release NDAC and the data bus.

    set0 PET_PIA2_CA, PET_PIA2_CA_NDAC_OUT

    pla
    rts


; Writes a single character in A with buffering.
; Preserves X and Y.

.ieee_write
    pha
    txa
    pha
    lda ieee_has_buffered_char
    {
        beq skip
        lda ieee_buffered_char
        jsr ieee_putb
        .skip
    }
    lda #1
    sta ieee_has_buffered_char
    pla
    tax
    pla
    sta ieee_buffered_char
    rts

; Flushes the last character with EOI asserted.
; Preserves X and Y.

.ieee_flush
    lda ieee_has_buffered_char
    {
        beq skip
        lda ieee_buffered_char
        jsr ieee_puteoib
        lda #0
        sta ieee_has_buffered_char
        .skip
    }
    rts

; See http://www.6502.org/users/andre/petindex/local/pet-io-2.txt
; https://www.pagetable.com/?p=1023
; http://www.primrosebank.net/computers/pet/documents/PET_and_the_IEEE488_Bus_text.pdf
; (appendix E)

; A is the secondary address (0xfX for OPEN).

.ieee_talk
    pha
    jsr ieee_computer_atn
    lda #&48               ; TALK device 8
    jsr ieee_putb
    pla
    ora #&60               ; SECOND
    jsr ieee_putb
    jmp ieee_computer_listening

.ieee_untalk
    jsr ieee_computer_atn
    lda #&5f               ; UNTALK
    jsr ieee_putb
    jmp ieee_computer_idle

; A is the secondary address.

.ieee_listen
    pha
    jsr ieee_computer_atn
    lda #&28               ; LISTEN device 8
    jsr ieee_putb
    pla
    ora #&60               ; SECOND
    jsr ieee_putb
    jmp ieee_computer_talking

.ieee_unlisten
    jsr ieee_flush
    jsr ieee_computer_atn
    lda #&3f               ; UNLISTEN
    jsr ieee_putb
    jmp ieee_computer_idle

.irq
    lda PET_PIA1_PB
    
    lda #30
    sta DL

    lda LASCT
    beq skip
    dec LASCT
.skip

    pla
    tay
    pla
    tax
    pla
    rti

; ==============================================================================
; ZX0 6502 Direct Disk-Streaming Decompressor (Forward Layout)
; Modified from John Brandwood's original routine
; ==============================================================================

.zx0_unpack
{
                ldy     #$FF                    ; Initialize default offset.
                sty     zx0_offset+0
                sty     zx0_offset+1
                iny                             ; Initialize source index.
                sty     zx0_length+1           ; Initialize length to 1.

                ldx     #$40                    ; Initialize empty buffer.

.zx0_next_cmd   lda     #1                      ; Initialize length back to 1.
                sta     zx0_length + 0

                txa                             ; Restore bit-buffer.

                asl a                           ; Copy from literals or new offset?
                bcc     zx0_cp_literal

                ;
                ; Copy bytes from new offset.
                ;

.zx0_new_offset jsr     zx0_gamma_flag          ; Get offset MSB, returns CS.

                tya                             ; Negate offset MSB and check
                sbc     zx0_length + 0         ; for zero (EOF marker).
                bcs     zx0_got_eof

                sec
                ror a
                sta     zx0_offset + 1         ; Save offset MSB.

                php
                jsr ieee_getb
                plp

                ror     a                       ; Last offset bit starts gamma.
                sta     zx0_offset + 0         ; Save offset LSB.

                lda     #(-2 and &ff)                     ; Minimum length of 2?
                bcs     zx0_get_lz_dst

                lda     #1                      ; Initialize length back to 1.
                sta     zx0_length + 0

                txa                             ; Restore bit-buffer.

                jsr     zx0_gamma_data          ; Get length, returns CS.

                lda     zx0_length + 0         ; Negate lo-byte of (length+1).
                eor     #$FF

;               bne     zx0_get_lz_dst          ; N.B. Optimized to do nothing!
;
;               inc     zx0_length + 1         ; Increment from (length+1).
;               dec     zx0_length + 1         ; Decrement because lo-byte=0.

.zx0_get_lz_dst tay                             ; Calc address of partial page.
                eor     #$FF                    ; Always CS from previous SBC.
                adc     zx0_dstptr + 0
                sta     zx0_dstptr + 0
                bcs     zx0_get_lz_win

                dec     zx0_dstptr + 1

.zx0_get_lz_win clc                             ; Calc address of match.
                adc     zx0_offset + 0         ; N.B. Offset is negative!
                sta     zx0_winptr + 0
                lda     zx0_dstptr + 1
                adc     zx0_offset + 1
                sta     zx0_winptr + 1

zx0_winptr      =       P%+1

.zx0_lz_page    lda     $1234,y                 ; Self-modifying zx0_winptr.
                sta     (zx0_dstptr),y
                iny
                bne     zx0_lz_page
                inc     zx0_dstptr + 1

                lda     zx0_length + 1         ; Any full pages left to copy?
                beq     zx0_next_cmd

                dec     zx0_length + 1         ; This is rare, so slower.
                inc     zx0_winptr + 1
                bne     zx0_lz_page             ; Always true.

.zx0_got_eof    rts                             ; Finished decompression.

                ;
                ; Copy bytes from compressed source.
                ;

.zx0_cp_literal jsr     zx0_gamma_flag          ; Get length, returns CS.

                pha                             ; Preserve bit-buffer.

                ldx     zx0_length + 0         ; Check the lo-byte of length
                bne     zx0_cp_byte             ; without effecting CS.

.zx0_cp_page    dec     zx0_length + 1         ; Decrement # of pages to copy.

.zx0_cp_byte    php
                jsr     ieee_getb              ; CS throughout the execution of
                plp
                sta     (zx0_dstptr),y         ; of this .cp_page loop.

.zx0_cp_skip1   inc    zx0_dstptr + 0
                beq     zx0_inc_cp_dst

.zx0_cp_skip2   dex                             ; Any bytes left to copy?
                bne     zx0_cp_byte

                lda     zx0_length + 1         ; Any full pages left to copy?
                bne     zx0_cp_page             ; Optimized for branch-unlikely.

                inx                             ; Initialize length back to 1.
                stx     zx0_length + 0

                pla                             ; Restore bit-buffer.

                asl     a                       ; Copy from last offset or new offset?
                bcs     zx0_new_offset

                ;
                ; Copy bytes from last offset (rare so slower).
                ;

.zx0_old_offset jsr     zx0_gamma_flag          ; Get length, returns CS.

                tya                             ; Negate the lo-byte of length.
                sbc     zx0_length + 0
                sec                             ; Ensure CS before zx0_get_lz_dst!
                bne     zx0_get_lz_dst

                dec     zx0_length + 1         ; Decrement because lo-byte=0.
                bcs     zx0_get_lz_dst          ; Always true!

.zx0_inc_cp_dst inc     zx0_dstptr + 1
                bcs     zx0_cp_skip2            ; Always true.

                ;
                ; Get 16-bit interlaced Elias gamma value.
                ;

.zx0_gamma_data asl     a                       ; Get next bit.
                rol     zx0_length + 0
.zx0_gamma_flag asl     a
                bcc     zx0_gamma_data          ; Loop until finished or empty.
                bne     zx0_gamma_done          ; Bit-buffer empty?

.zx0_gamma_load php
                jsr     ieee_getb              ; Reload the empty bit-buffer
                plp
                rol a
                bcs     zx0_gamma_done          ; Finished?

.zx0_gamma_word asl     a                       ; Get next bit.
                rol     zx0_length + 0
                rol     zx0_length + 1
                asl     a
                bcc     zx0_gamma_word          ; Loop until finished or empty.
                beq     zx0_gamma_load          ; Bit-buffer empty?

.zx0_gamma_done tax                             ; Preserve bit-buffer.
                rts
}
._mose_end
copyblock _mose_start, _mose_end, _relocated_code
basic_end = _relocated_code + (_mose_end - _mose_start)

 PRINT "ELITE.PRG ", ~basic_start, " ", ~basic_end, " ", ~basic_start, " ", ~basic_start
 SAVE "3-assembled-output/elite.prg", basic_start, basic_end, basic_start
