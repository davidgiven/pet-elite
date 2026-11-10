\ ******************************************************************************
\
\       Name: NLIN
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a horizontal line at pixel row 23 to box in a title
\
\ ------------------------------------------------------------------------------
\
\ Draw a horizontal line at pixel row 23 and move the text cursor down one
\ line.
\
\ ******************************************************************************

.NLIN

 LDA #23                \ Set A = 23 so NLIN2 below draws a horizontal line at
                        \ pixel row 23

 INC YC                 \ Move the text cursor down one line

                        \ Fall through into NLIN2 to draw the horizontal line
                        \ at row 23

\ ******************************************************************************
\
\       Name: NLIN2
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a screen-wide horizontal line at the pixel row in A
\
\ ------------------------------------------------------------------------------
\
\ This draws a line from (2, A) to (254, A), which is almost screen-wide and
\ fits in nicely between the white borders without clashing with it.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The pixel row on which to draw the horizontal line
\
\ ******************************************************************************

.NLIN2

 STA Y1                 \ Set Y1 = A

 LDX #2                 \ Set X1 = 2, so (X1, Y1) = (2, A)
 STX X1

 LDX #254               \ Set X2 = 254, so (X2, Y2) = (254, A)
 STX X2

                        \ --- Mod: Code removed for Teletext Elite: ----------->

\BNE HLOIN              \ Call HLOIN to draw a horizontal line from (2, A) to
\                       \ (254, A) and return from the subroutine (this BNE is
\                       \ effectively a JMP as A will never be zero)

                        \ --- And replaced by: -------------------------------->

 RTS                    \ Return from the subroutine

                        \ --- End of replacement ------------------------------>
\ ******************************************************************************
\
\       Name: NLIN3
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Print a title and draw a horizontal line at row 19 to box it in
\
\ ------------------------------------------------------------------------------
\
\ This routine print a text token at the cursor position and draws a horizontal
\ line at pixel row 19. It is used for the Status Mode screen, the Short-range
\ Chart, the Market Price screen and the Equip Ship screen.
\
\ ******************************************************************************

.NLIN3

 JSR TT27               \ Print the text token in A

                        \ Fall through into NLIN4 to draw a horizontal line at
                        \ pixel row 19

\ ******************************************************************************
\
\       Name: NLIN4
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a horizontal line at pixel row 19 to box in a title
\
\ ------------------------------------------------------------------------------
\
\ This routine is used on the Inventory screen to draw a horizontal line at
\ pixel row 19 to box in the title.
\
\ ******************************************************************************

.NLIN4
{

                        \ --- Mod: Code removed for Teletext Elite: ----------->

\LDA #19                \ Jump to NLIN2 to draw a horizontal line at pixel row
\BNE NLIN2              \ 19, returning from the subroutine with using a tail
\                       \ call (this BNE is effectively a JMP as A will never
\                       \ be zero)

                        \ --- And replaced by: -------------------------------->

    lda #64
    ldx #0
.loop
    sta MODE7_VRAM + 1*40, x
    inx
    cpx #40
    bne loop

 RTS                    \ Return from the subroutine

                        \ --- End of replacement ------------------------------>
}