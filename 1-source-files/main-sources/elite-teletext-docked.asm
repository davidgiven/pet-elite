\ ******************************************************************************
\
\ TELETEXT ELITE DOCKED-SPECIFIC ROUTINES
\
\ Elite was written by Ian Bell and David Braben and is copyright Acornsoft 1984
\
\ The code on this site has been reconstructed from a disassembly of the version
\ released on Ian Bell's personal website at http://www.elitehomepage.org/
\
\ The commentary is copyright Mark Moxon, and any misunderstandings or mistakes
\ in the documentation are entirely my fault
\
\ The terminology and notations used in this commentary are explained at
\ https://elite.bbcelite.com/terminology
\
\ The deep dive articles referred to in this commentary can be found at
\ https://elite.bbcelite.com/deep_dives
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: PlotSixelIfEmpty
\       Type: Subroutine
\   Category: Teletext Elite
\    Summary: Plot a mode 7 sixel, but only if the character block containing
\             the sixel is empty
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Sixel x-coordinate
\
\   Y                   Sixel y-coordinate
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Z flag              Did we plot the sixel?
\
\                         * Clear if we did not plot the sixel because there is
\                           already something there or the sixel is off-screen
\
\                         * Set if we did plot the sixel
\
\ ******************************************************************************

.PlotSixelIfEmpty
{
 CPX #MODE7_HIGH_X
 BCS clip1
 CPY #MODE7_HIGH_Y
 BCS clip1

 CLC                    \ Set SC(1 0) to the screen address of the character
 LDA xSixel,X           \ block, starting with the low byte
 ADC ySixelLo,Y
 STA SC

 LDA ySixelHi,Y         \ And then the high byte
 ADC #HI(MODE7_VRAM)
 STA SCH

 STX P

 LDA ySixelChar,Y       \ Get the sixel character with the relevant row
                        \ pre-filled for the y-coordinate in Y

 AND xSixelChar,X       \ Apply the sixel character with the relevant column
                        \ pre-filled for the x-coordinate in X, so the result
                        \ is a sixel character with the sixel at (x, y) filled
 STA Q

 LDA (SC),Y
 TAX
 LDA screenToBitfield, X
 BMI nodraw
 ORA Q                  \ EOR the sixel into the screen, flipping whatever is
                        \ already there
 cmp screenToBitfield, X
 beq nothing_changed
 TAX
 LDA bitfieldToScreen, X
 STA (SC),Y

.nodraw
 LDX P

.clip1
 lda #0                 \ return with Z
 rts

.nothing_changed
 ldx P
 lda #1                 \ return with !Z
 rts
}
