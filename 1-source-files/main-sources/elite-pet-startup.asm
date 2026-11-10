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
.sound_cpitch           skip 4  ; Pitch actually being played

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
    cmp #7
    beq osword_sound_impl
.osbyte_impl
    rts

.osword_sound_impl
    stx cmdblock+0
    sty cmdblock+1
    sei                         ; do this atomically

    ldy #0*2                    ; SOUND parameters are words
    lda (cmdblock), y           ; we only want the channel
    and #&0f                    
    tax                         ; used below

    iny
    iny
    lda (cmdblock), y
    sta sound_envelope, x
    iny
    iny
    lda (cmdblock), y
    sec
    sbc #48                     ; apply 48 bias (we can't play lower than that)
    sta sound_pitch, x
    iny
    iny
    lda (cmdblock), y
    {
        cmp #&ff
        beq skip
        lsr a                       ; 100Hz ticks to 50Hz ticks
        bne skip                    ; always at least one tick!
        lda #1
    .skip
    }
    sta sound_duration, x

    lda #0                          ; clear phase workspace
    sta sound_phase, x
    sta sound_ticks, x
    sta sound_noise, x

    ; The sound will start playing at the next timer interrupt.

.nosound
    cli
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
{
    lda PET_PIA1_PB
    
    ; Do the things the Elite core expects.

    lda #30
    sta DL

    {
        lda LASCT
        beq skip
        dec LASCT
        .skip
    }

    ; Do sound envelope processing.

    {
        ldx #3
    .loop
        jsr process_channel
        dex
        bpl loop
    }

    ; Now actually play the sound. Lower channel numbers have priority.

    {
        lda sound_envelope+0
        beq skip
        jsr play_noise
        jmp exit
    .skip
    }

    {
        ldx #1
    .loop
        lda sound_envelope, x       ; scan channels looking for a playing sound
        bne found
        inx
        cpx #4
        bne loop

        jsr stop_sound              ; oh no, nothing's playing
        beq skip
    
    .found
        lda sound_pitch, x
        jsr play_sound
    .skip
    }

.exit
    pla
    tay
    pla
    tax
    pla
    rti
}

; Processes the channel in X.
.process_channel
{
    ; If this is an envelope, do envelope processing.

    {
        lda sound_envelope, x
        beq nosound             ; skip if 0 (no sound)
        bmi solidtone           ; skip if negative (solid tone)

    .nextphase
        clc
        asl a
        asl a
        adc sound_envelope, x
        adc sound_envelope, x   ; a = sound_envelope*6
        adc sound_phase, x
        tay

        ; Fetch the pitch delta for this phase. If it's 0, go to the next phase.

        {
            lda envelope1+0, y
            bne skip

            jsr advance_to_next_phase
            jmp nextphase       ; process the next phase immediately
        .skip
        }

        ; Adjust the pitch, using modulus arithmetic to avoid pitches below 48
        ; (which we can't play).

        {
            clc
            adc sound_pitch, x
            bcs overflow
            cmp #256-48       ; rolled over?
            bcc skip
        .overflow
            sbc #256-48         ; carry is already set
        .skip
            sta sound_pitch, x
        }

        ; Check for the end of the phase.

        {
            lda sound_ticks, x
            clc
            adc #1
            sta sound_ticks, x
            cmp envelope1+3, y
            bne skip
            jsr advance_to_next_phase
        .skip
        }
    
    .solidtone
        ; Decrement the duration.

        {
            lda sound_duration, x
            bne playing
            lda #0
            sta sound_envelope, x   ; duration is 0, silence this channel

        .playing
            beq skip
            cmp #&ff                ; infinite duration
            beq skip
            dec sound_duration, x
        .skip
        }
    .nosound
    }
    rts
}

.advance_to_next_phase
{
    lda #0              ; clear phase tick count
    sta sound_ticks, x

    lda sound_phase, x
    clc
    adc #1
    cmp #3
    bne skip
    lda #0
.skip
    sta sound_phase, x
    rts
}

; Pokes the VIA to play sound of pitch A.
.play_sound
{
    ; Don't do anything unless the pitch is actually changing,
    ; or the sound system was previously turned off, or we're playing
    ; noise.

    ldx PET_VIA_ACR
    beq really_playing
    cmp sound_cpitch
    beq skip
.really_playing
    sta sound_cpitch

    ; Program the VIA with this pitch.

    jsr compute_via_sound_values
    sty PET_VIA_SHIFT
    sta PET_VIA_T2_LO

    lda #16
    sta PET_VIA_ACR
    
    .skip
    rts
}

; Pokes the VIA to stop playing sound.
.stop_sound
    lda #0
    sta PET_VIA_ACR
    sta sound_cpitch
    rts

; Pokes the VIA to play noise of pitch A.
.play_noise
{
    ldy sound_noise
    cmp sound_cpitch
    beq noinit                  ; don't initialise unless the pitch is changed

    ; Figure out the 'pitch' of the noise.

    sta sound_cpitch
    jsr compute_via_sound_values
    sta PET_VIA_T2_LO

.noinit
    ; Circulate the random number.

    tya
    beq do_eor
    asl a
    bcc no_eor
.do_eor
    eor #&1d                ; feedback polynomial
.no_eor
    sta sound_noise
    sta PET_VIA_SHIFT

    ; Make sure things are playing.

    lda #16
    sta PET_VIA_ACR
    rts
}

; Given a pitch in A, return the shift register value in Y and the timer value in A.

.compute_via_sound_values
{
    ; Compute shift register and timer values.

    {
        ldy #&0f
        cmp #96
        bcc lower
        ldy #&33
        cmp #144
        bcc lower
        ldy #&55
        .lower
    }

    tax
    lda sound_table, x
    rts
}

; Tables describing the current state of the four BBC Micro channels.

.sound_envelope         skip 4  ; BBC Micro envelope (negative for tone)
.sound_pitch            skip 4  ; BBC Micro pitch value - 48
.sound_noise            skip 4  ; random noise value
.sound_duration         skip 4  ; number of ticks in the current sound
.sound_phase            skip 4  ; when processing an envelope, this is the phase we're in
.sound_ticks            skip 4  ; tick count in the current sound
;   * Envelope 1 is the sound of our own laser firing
;
;   * Envelope 2 is the sound of lasers hitting us, or hyperspace
;
;   * Envelope 3 is the first sound in the two-part sound of us dying, or the
;     second sound in the two-part sound of us hitting or killing an enemy ship
;
;   * Envelope 4 is the sound of E.C.M. firing
;
; These are defined on the BBC Micro as:
;
;             step p1  p2   p3  d1  d2  d3   aa  ar  as ad    la   lr
; ENVELOPE 1, 1,   0,  111, -8, 4,  1,  8,   8,  -2, 0, -1,   126, 44
; ENVELOPE 2, 1,   14, -18, -1, 44, 32, 50,  6,  1,  0, -2,   120, 126
; ENVELOPE 3, 1,   1,  -1,  -3, 17, 32, 128, 1,  0,  0, -1,   1,   1
; ENVELOPE 4, 1,   4,  -8,  44, 4,  6,  8,   22, 0,  0, -127, 126, 0

.envelope1      equb 0, 111, -8, 2, 1, 4
.envelope2      equb 14, -18, -1, 22, 16, 25
.envelope3      equb 1, -1, -3, 8, 16, 64
.envelope4      equb 4, -8, 44, 2, 3, 4

; BBC Micro pitch to PET sound table. The first entry is pitch 48 (lower
; pitches can't be played on the PET).
.sound_table
    ;    T2       BBC   frequency   shift    real_freq  error   
    equb 255    ; 48    243.401     15       243.191    -1.5    
    equb 251    ; 49    246.942     15       247.036    0.66    
    equb 247    ; 50    250.533     15       251.004    3.25    
    equb 244    ; 51    254.178     15       254.065    -0.77   
    equb 240    ; 52    257.875     15       258.264    2.61    
    equb 237    ; 53    261.626     15       261.506    -0.79   
    equb 233    ; 54    265.431     15       265.957    3.43    
    equb 230    ; 55    269.292     15       269.397    0.67    
    equb 227    ; 56    273.209     15       272.926    -1.79   
    equb 223    ; 57    277.183     15       277.778    3.71    
    equb 220    ; 58    281.214     15       281.532    1.95    
    equb 217    ; 59    285.305     15       285.388    0.51    
    equb 214    ; 60    289.455     15       289.352    -0.61   
    equb 211    ; 61    293.665     15       293.427    -1.4    
    equb 208    ; 62    297.936     15       297.619    -1.84   
    equb 205    ; 63    302.27      15       301.932    -1.93   
    equb 202    ; 64    306.666     15       306.373    -1.66   
    equb 199    ; 65    311.127     15       310.945    -1.01   
    equb 196    ; 66    315.652     15       315.657    0.02    
    equb 193    ; 67    320.244     15       320.513    1.45    
    equb 190    ; 68    324.902     15       325.521    3.3     
    equb 188    ; 69    329.628     15       328.947    -3.58   
    equb 185    ; 70    334.422     15       334.225    -1.02   
    equb 182    ; 71    339.286     15       339.674    1.98    
    equb 180    ; 72    344.221     15       343.407    -4.1    
    equb 177    ; 73    349.228     15       349.162    -0.33   
    equb 174    ; 74    354.308     15       355.114    3.93    
    equb 172    ; 75    359.461     15       359.195    -1.28   
    equb 169    ; 76    364.69      15       365.497    3.83    
    equb 167    ; 77    369.994     15       369.822    -0.8    
    equb 164    ; 78    375.376     15       376.506    5.2     
    equb 162    ; 79    380.836     15       381.098    1.19    
    equb 160    ; 80    386.375     15       385.802    -2.57   
    equb 157    ; 81    391.995     15       393.082    4.79    
    equb 155    ; 82    397.697     15       398.089    1.71    
    equb 153    ; 83    403.482     15       403.226    -1.1    
    equb 151    ; 84    409.351     15       408.497    -3.61   
    equb 148    ; 85    415.305     15       416.667    5.67    
    equb 146    ; 86    421.345     15       422.297    3.91    
    equb 144    ; 87    427.474     15       428.082    2.46    
    equb 142    ; 88    433.692     15       434.028    1.34    
    equb 140    ; 89    440.0       15       440.141    0.55    
    equb 138    ; 90    446.4       15       446.429    0.11    
    equb 136    ; 91    452.893     15       452.899    0.02    
    equb 134    ; 92    459.48      15       459.559    0.3     
    equb 132    ; 93    466.164     15       466.418    0.94    
    equb 130    ; 94    472.944     15       473.485    1.98    
    equb 128    ; 95    479.823     15       480.769    3.41    
    equb 255    ; 96    486.803     51       486.381    -1.5    
    equb 251    ; 97    493.883     51       494.071    0.66    
    equb 247    ; 98    501.067     51       502.008    3.25    
    equb 244    ; 99    508.355     51       508.13     -0.77   
    equb 240    ; 100   515.749     51       516.529    2.61    
    equb 237    ; 101   523.251     51       523.013    -0.79   
    equb 233    ; 102   530.862     51       531.915    3.43    
    equb 230    ; 103   538.584     51       538.793    0.67    
    equb 227    ; 104   546.417     51       545.852    -1.79   
    equb 223    ; 105   554.365     51       555.556    3.71    
    equb 220    ; 106   562.429     51       563.063    1.95    
    equb 217    ; 107   570.609     51       570.776    0.51    
    equb 214    ; 108   578.909     51       578.704    -0.61   
    equb 211    ; 109   587.33      51       586.854    -1.4    
    equb 208    ; 110   595.872     51       595.238    -1.84   
    equb 205    ; 111   604.54      51       603.865    -1.93   
    equb 202    ; 112   613.333     51       612.745    -1.66   
    equb 199    ; 113   622.254     51       621.891    -1.01   
    equb 196    ; 114   631.305     51       631.313    0.02    
    equb 193    ; 115   640.487     51       641.026    1.45    
    equb 190    ; 116   649.804     51       651.042    3.3     
    equb 188    ; 117   659.255     51       657.895    -3.58   
    equb 185    ; 118   668.844     51       668.449    -1.02   
    equb 182    ; 119   678.573     51       679.348    1.98    
    equb 180    ; 120   688.443     51       686.813    -4.1    
    equb 177    ; 121   698.456     51       698.324    -0.33   
    equb 174    ; 122   708.616     51       710.227    3.93    
    equb 172    ; 123   718.923     51       718.391    -1.28   
    equb 169    ; 124   729.38      51       730.994    3.83    
    equb 167    ; 125   739.989     51       739.645    -0.8    
    equb 164    ; 126   750.752     51       753.012    5.2     
    equb 162    ; 127   761.672     51       762.195    1.19    
    equb 160    ; 128   772.751     51       771.605    -2.57   
    equb 157    ; 129   783.991     51       786.164    4.79    
    equb 155    ; 130   795.394     51       796.178    1.71    
    equb 153    ; 131   806.964     51       806.452    -1.1    
    equb 151    ; 132   818.701     51       816.993    -3.61   
    equb 148    ; 133   830.609     51       833.333    5.67    
    equb 146    ; 134   842.691     51       844.595    3.91    
    equb 144    ; 135   854.948     51       856.164    2.46    
    equb 142    ; 136   867.384     51       868.056    1.34    
    equb 140    ; 137   880.0       51       880.282    0.55    
    equb 138    ; 138   892.8       51       892.857    0.11    
    equb 136    ; 139   905.786     51       905.797    0.02    
    equb 134    ; 140   918.961     51       919.118    0.3     
    equb 132    ; 141   932.328     51       932.836    0.94    
    equb 130    ; 142   945.889     51       946.97     1.98    
    equb 128    ; 143   959.647     51       961.538    3.41    
    equb 255    ; 144   973.605     85       972.763    -1.5    
    equb 251    ; 145   987.767     85       988.142    0.66    
    equb 247    ; 146   1002.134    85      1004.016    3.25    
    equb 244    ; 147   1016.71     85      1016.260    -0.77   
    equb 240    ; 148   1031.499    85      1033.058    2.61    
    equb 237    ; 149   1046.502    85      1046.025    -0.79   
    equb 233    ; 150   1061.724    85      1063.830    3.43    
    equb 230    ; 151   1077.167    85      1077.586    0.67    
    equb 227    ; 152   1092.835    85      1091.703    -1.79   
    equb 223    ; 153   1108.731    85      1111.111    3.71    
    equb 220    ; 154   1124.857    85      1126.126    1.95    
    equb 217    ; 155   1141.219    85      1141.553    0.51    
    equb 214    ; 156   1157.818    85      1157.407    -0.61   
    equb 211    ; 157   1174.659    85      1173.709    -1.4    
    equb 208    ; 158   1191.745    85      1190.476    -1.84   
    equb 205    ; 159   1209.079    85      1207.729    -1.93   
    equb 202    ; 160   1226.666    85      1225.490    -1.66   
    equb 199    ; 161   1244.508    85      1243.781    -1.01   
    equb 196    ; 162   1262.61     85      1262.626    0.02    
    equb 193    ; 163   1280.975    85      1282.051    1.45    
    equb 190    ; 164   1299.607    85      1302.083    3.3     
    equb 188    ; 165   1318.51     85      1315.789    -3.58   
    equb 185    ; 166   1337.688    85      1336.898    -1.02   
    equb 182    ; 167   1357.146    85      1358.696    1.98    
    equb 180    ; 168   1376.886    85      1373.626    -4.1    
    equb 177    ; 169   1396.913    85      1396.648    -0.33   
    equb 174    ; 170   1417.231    85      1420.455    3.93    
    equb 172    ; 171   1437.846    85      1436.782    -1.28   
    equb 169    ; 172   1458.76     85      1461.988    3.83    
    equb 167    ; 173   1479.978    85      1479.290    -0.8    
    equb 164    ; 174   1501.504    85      1506.024    5.2     
    equb 162    ; 175   1523.344    85      1524.390    1.19    
    equb 160    ; 176   1545.502    85      1543.210    -2.57   
    equb 157    ; 177   1567.982    85      1572.327    4.79    
    equb 155    ; 178   1590.789    85      1592.357    1.71    
    equb 153    ; 179   1613.927    85      1612.903    -1.1    
    equb 151    ; 180   1637.402    85      1633.987    -3.61   
    equb 148    ; 181   1661.219    85      1666.667    5.67    
    equb 146    ; 182   1685.382    85      1689.189    3.91    
    equb 144    ; 183   1709.896    85      1712.329    2.46    
    equb 142    ; 184   1734.767    85      1736.111    1.34    
    equb 140    ; 185   1760.0      85      1760.563    0.55    
    equb 138    ; 186   1785.6      85      1785.714    0.11    
    equb 136    ; 187   1811.572    85      1811.594    0.02    
    equb 134    ; 188   1837.922    85      1838.235    0.3     
    equb 132    ; 189   1864.655    85      1865.672    0.94    
    equb 130    ; 190   1891.777    85      1893.939    1.98    
    equb 128    ; 191   1919.294    85      1923.077    3.41    
    equb 126    ; 192   1947.21     85      1953.125    5.25    
    equb 125    ; 193   1975.533    85      1968.504    -6.17   
    equb 123    ; 194   2004.268    85      2000.000    -3.69   
    equb 121    ; 195   2033.421    85      2032.520    -0.77   
    equb 119    ; 196   2062.998    85      2066.116    2.61    
    equb 117    ; 197   2093.005    85      2100.840    6.47    
    equb 116    ; 198   2123.448    85      2118.644    -3.92   
    equb 114    ; 199   2154.334    85      2155.172    0.67    
    equb 112    ; 200   2185.67     85      2192.982    5.78    
    equb 111    ; 201   2217.461    85      2212.389    -3.96   
    equb 109    ; 202   2249.715    85      2252.252    1.95    
    equb 108    ; 203   2282.438    85      2272.727    -7.38   
    equb 106    ; 204   2315.636    85      2314.815    -0.61   
    equb 104    ; 205   2349.318    85      2358.491    6.75    
    equb 103    ; 206   2383.49     85      2380.952    -1.84   
    equb 101    ; 207   2418.158    85      2427.184    6.45    
    equb 100    ; 208   2453.331    85      2450.980    -1.66   
    equb 98     ; 209   2489.016    85      2500.000    7.62    
    equb 97     ; 210   2525.219    85      2525.253    0.02    
    equb 96     ; 211   2561.95     85      2551.020    -7.4    
    equb 94     ; 212   2599.214    85      2604.167    3.3     
    equb 93     ; 213   2637.02     85      2631.579    -3.58   
    equb 91     ; 214   2675.377    85      2688.172    8.26    
    equb 90     ; 215   2714.291    85      2717.391    1.98    
    equb 89     ; 216   2753.771    85      2747.253    -4.1    
    equb 87     ; 217   2793.826    85      2808.989    9.37    
    equb 86     ; 218   2834.463    85      2840.909    3.93    
    equb 85     ; 219   2875.691    85      2873.563    -1.28   
    equb 84     ; 220   2917.519    85      2906.977    -6.27   
    equb 82     ; 221   2959.955    85      2976.190    9.47    
    equb 81     ; 222   3003.009    85      3012.048    5.2     
    equb 80     ; 223   3046.689    85      3048.780    1.19    
    equb 79     ; 224   3091.004    85      3086.420    -2.57   
    equb 78     ; 225   3135.963    85      3125.000    -6.06   
    equb 77     ; 226   3181.577    85      3164.557    -9.29   
    equb 75     ; 227   3227.854    85      3246.753    10.11   
    equb 74     ; 228   3274.804    85      3289.474    7.74    
    equb 73     ; 229   3322.438    85      3333.333    5.67    
    equb 72     ; 230   3370.764    85      3378.378    3.91    
    equb 71     ; 231   3419.792    85      3424.658    2.46    
    equb 70     ; 232   3469.534    85      3472.222    1.34    
    equb 69     ; 233   3520.0      85      3521.127    0.55    
    equb 68     ; 234   3571.2      85      3571.429    0.11    
    equb 67     ; 235   3623.144    85      3623.188    0.02    
    equb 66     ; 236   3675.844    85      3676.471    0.3     
    equb 65     ; 237   3729.31     85      3731.343    0.94    
    equb 64     ; 238   3783.554    85      3787.879    1.98    
    equb 63     ; 239   3838.587    85      3846.154    3.41    
    equb 62     ; 240   3894.421    85      3906.250    5.25    
    equb 61     ; 241   3951.066    85      3968.254    7.51    
    equb 60     ; 242   4008.536    85      4032.258    10.22   
    equb 59     ; 243   4066.841    85      4098.361    13.37   
    equb 59     ; 244   4125.995    85      4098.361    -11.63  
    equb 58     ; 245   4186.009    85      4166.667    -8.02   
    equb 57     ; 246   4246.896    85      4237.288    -3.92   
    equb 56     ; 247   4308.668    85      4310.345    0.67    
    equb 55     ; 248   4371.339    85      4385.965    5.78    
    equb 54     ; 249   4434.922    85      4464.286    11.42   
    equb 54     ; 250   4499.43     85      4464.286    -13.58  
    equb 53     ; 251   4564.875    85      4545.455    -7.38   
    equb 52     ; 252   4631.273    85      4629.630    -0.61   
    equb 51     ; 253   4698.636    85      4716.981    6.75    
    equb 50     ; 254   4766.98     85      4807.692    14.72   
    equb 50     ; 255   4836.317    85      4807.692    -10.28  

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
