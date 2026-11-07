graphicsMatrix = &7e00
businessMatrix = &7d00
petToAsciiLookup = &7c80
petKeyboardRow = graphicsMatrix + 0
petKeyboardColumn = graphicsMatrix + &80

\ ******************************************************************************
\
\       Name: CTRL
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard to see if CTRL is currently pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X = %10000001 (i.e. 129 or -127) if CTRL is being
\                       pressed
\
\                       X = 1 if CTRL is not being pressed
\
\   A                   Contains the same as X
\
\ ******************************************************************************

.CTRL

 LDX #1                 \ Set X to the internal key number for CTRL and fall
                        \ through to DKS4 to scan the keyboard

\ ******************************************************************************
\
\       Name: DKS4
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard to see if a specific key is being pressed
\  Deep dive: The key logger
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The internal number of the key to check (see p.142 of
\                       the Advanced User Guide for a list of internal key
\                       numbers)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   If the key in A is being pressed, A contains the
\                       original argument A, but with bit 7 set (i.e. A + 128).
\                       If the key in A is not being pressed, the value in A is
\                       unchanged
\
\   X                   Contains the same as A
\
\ ******************************************************************************

\ PET scancodes use a 0..9 row in the bottom four bits of PIA1_PA, and then
\ a 8-bit bitfield in PIA1_PB. We use two lookup tables to fetch the row and mask,
\ letting us (at the expense of having two big lookup tables) very quickly test
\ for keys.

.DKS4
 LDA PET_PIA1_PA
 AND #&f0
 ORA petKeyboardRow, X
 STA PET_PIA1_PA

 LDA PET_PIA1_PB
 EOR #&ff
 AND petKeyboardColumn, X 
 BEQ nokey

 TXA
 ORA #&80
 RTS

.nokey
 TXA
 RTS

\ LDA #%00000011         \ Set A to %00000011, so it's ready to send to SHEILA
\                        \ once interrupts have been disabled
\
\ SEI                    \ Disable interrupts so we can scan the keyboard
\                        \ without being hijacked
\
\ STA VIA+&40            \ Set 6522 System VIA output register ORB (SHEILA &40)
\                        \ to %00000011 to stop auto scan of keyboard
\
\ LDA #%01111111         \ Set 6522 System VIA data direction register DDRA
\ STA VIA+&43            \ (SHEILA &43) to %01111111. This sets the A registers
\                        \ (IRA and ORA) so that:
\                        \
\                        \   * Bits 0-6 of ORA will be sent to the keyboard
\                        \
\                        \   * Bit 7 of IRA will be read from the keyboard
\
\ STX VIA+&4F            \ Set 6522 System VIA output register ORA (SHEILA &4F)
\                        \ to X, the key we want to scan for; bits 0-6 will be
\                        \ sent to the keyboard, of which bits 0-3 determine the
\                        \ keyboard column, and bits 4-6 the keyboard row
\
\ LDX VIA+&4F            \ Read 6522 System VIA output register IRA (SHEILA &4F)
\                        \ into X; bit 7 is the only bit that will have changed.
\                        \ If the key is pressed, then bit 7 will be set,
\                        \ otherwise it will be clear
\
\ LDA #%00001011         \ Set 6522 System VIA output register ORB (SHEILA &40)
\ STA VIA+&40            \ to %00001011 to restart auto scan of keyboard
\
\ CLI                    \ Allow interrupts again
\
\ TXA                    \ Transfer X into A

 RTS                    \ Return from the subroutine

.switchToBusinessKeyboard
 ldx #0
 {
    .loop
    lda businessMatrix, x
    sta graphicsMatrix, x
    inx
    bne loop
 }
 rts