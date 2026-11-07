\ ******************************************************************************
\
\ TELETEXT ELITE SIXEL ROUTINES
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
\ ------------------------------------------------------------------------------
\
\ The code in this section is mostly taken from the Bitshifters' sixel-plotting
\ routines here:
\
\ https://github.com/bitshifters/teletextr/blob/master/lib/mode7_plot_pixel.asm
\
\ It has been reformatted and has been tweaked to work with Teletext Elite (to
\ support EOR plotting, screen indents and so on), but the core routines are
\ mostly unchanged from the original.
\
\ ******************************************************************************

 MODE7_VRAM = &8000     \ The start of video RAM for the PET

 MODE7_INDENT = 3       \ Width of the left indent in characters to apply to the
                        \ entire space view (so it gets centred)

 MODE7_LOW_X = 0        \ The first sixel x-coordinate we can draw sixels in

 MODE7_HIGH_X = 2*40    \ The last sixel x-coordinate we can draw sixels in + 1,
                        \ less 2 to compensate for the first character on each
                        \ row being a graphics control code

 MODE7_LOW_Y = 0        \ The first sixel y-coordinate we can draw sixels in (so
                        \ we not draw on the first character row)

 MODE7_HIGH_Y = 2*25    \ The last sixel y-coordinate we can draw sixels in + 1

 MESSAGE_ROW = 17       \ The character row containing the in-flight message bar

\ ******************************************************************************
\
\       Name: ySixelLo
\       Type: Variable
\   Category: Teletext Elite
\    Summary: Lookup table to convert a sixel y-coordinate into a mode 7 screen
\             address (low byte)
\
\ ******************************************************************************

.ySixelLo

 FOR i, 0, MODE7_HIGH_Y-1

  y = (i DIV 2) * 40 + 1 + MODE7_INDENT \ Add 1 to skip the graphics character
                                        \ in column 0, and then add the screen
                                        \ indent

  EQUB LO(y-i)          \ Adjust for (ZP),Y style addressing, where Y will be
                        \ the y-coordinate

 NEXT

\ ******************************************************************************
\
\       Name: ySixelHi
\       Type: Variable
\   Category: Teletext Elite
\    Summary: Lookup table to convert a sixel y-coordinate into a mode 7 screen
\             address (high byte)
\
\ ******************************************************************************

.ySixelHi

 FOR i, 0, MODE7_HIGH_Y-1

  y = (i DIV 2) * 40 + 1 + MODE7_INDENT \ Add 1 to skip the graphics character
                                        \ in column 0, and then add the screen
                                        \ indent

  EQUB HI(y-i)          \ Adjust for (ZP),Y style addressing, where Y will be
                        \ the y-coordinate

 NEXT

\ ******************************************************************************
\
\       Name: xSixel
\       Type: Variable
\   Category: Teletext Elite
\    Summary: Lookup table to convert a sixel x-coordinate into a mode 7 screen
\             address, as a row offset
\
\ ******************************************************************************

.xSixel

 FOR i, 0, MODE7_HIGH_X-1

  y = i>>1
  EQUB LO(y)

 NEXT 

\ ******************************************************************************
\
\       Name: xSixelChar
\       Type: Variable
\   Category: Teletext Elite
\    Summary: Lookup table to return a sixel character containing the relevant
\             three-sixel column containing that x-coordinate, pre-filled with
\             all three sixels populated
\
\ ******************************************************************************

.xSixelChar

 FOR n, 0, MODE7_HIGH_X-1

  IF (n AND 1) == 0
   EQUB 1+4
   \EQUB 32+1+4+16       \ Left column mask (i.e. all three left sixels set)
  ELSE
   EQUB 2+8
   \EQUB 32+2+8+64       \ Right column mask (i.e. all three rights sixel set)
  ENDIF

 NEXT

\ ******************************************************************************
\
\       Name: ySixelChar
\       Type: Variable
\   Category: Teletext Elite
\    Summary: Lookup table to return a sixel character containing the relevant
\             two-sixel row containing that y-coordinate, pre-filled with both
\             sixels populated
\
\ ******************************************************************************

.ySixelChar

 FOR n, 0, MODE7_HIGH_Y-1

  IF (n AND 1) == 0
   EQUB 1+2
  ELSE
   EQUB 4+8
  ENDIF

 NEXT

\ ******************************************************************************
\
\       Name: charRowAddress
\       Type: Variable
\   Category: Teletext Elite
\    Summary: Lookup table to return the screen address of the start of a mode 7
\             character row, for printing text
\
\ ******************************************************************************

.charRowAddress

 FOR n, 0, 25

  EQUW MODE7_VRAM + MODE7_INDENT + (n*&28)

 NEXT

\ ******************************************************************************
\
\       Name: divideBySix
\       Type: Variable
\   Category: PET Elite
\    Summary: Divides a pixel coordinate by 6 and shifts down.
\
\ ******************************************************************************

.divideBySix

FOR n, 0, 255
    EQUB (n+3)/6 + 2
NEXT

\ ******************************************************************************
\
\       Name: screenToBitfield
\       Type: Variable
\   Category: PET Elite
\    Summary: Given a screencode, returns the sixel bitfield for it.
\
\ ******************************************************************************

.screenToBitfield

FOR n, 0, 255
    IF n = &60
        EQUB 0               ; space
    ELIF n = &7E
        EQUB 1               ; ▘
    ELIF n = &7C
        EQUB 2               ; ▝
    ELIF n = &E2
        EQUB 1+2             ; ▀
    ELIF n = &7B
        EQUB 4               ; ▖
    ELIF n = &61
        EQUB 1+4             ; ▌
    ELIF n = &FF
        EQUB 2+4             ; ▞
    ELIF n = &EC
        EQUB 1+2+4           ; ▛
    ELIF n = &6C
        EQUB 8               ; ▗
    ELIF n = &7F
        EQUB 1+8             ; ▚
    ELIF n = &E1
        EQUB 2+8             ; ▐
    ELIF n = &FB
        EQUB 1+2+8           ; ▜
    ELIF n = &62
        EQUB 4+8             ; ▄
    ELIF n = &FC
        EQUB 1+4+8           ; ▙
    ELIF n = &FE
        EQUB 2+4+8           ; ▟
    ELIF n = &E0
        EQUB 1+2+4+8         ; █
    ELSE
        EQUB &80
    ENDIF
NEXT

\ ******************************************************************************
\
\       Name: bitfieldToScreen
\       Type: Variable
\   Category: PET Elite
\    Summary: Given a bitfield value, returns the screencode for it.
\
\ ******************************************************************************

.bitfieldToScreen
    EQUB &60     ; ....  space
    EQUB &7E     ; ▘ top-left
    EQUB &7C     ; ▝ top-right
    EQUB &E2     ; ▀ top half
    EQUB &7B     ; ▖ bottom-left
    EQUB &61     ; ▌ left half
    EQUB &FF     ; ▞ diagonal
    EQUB &EC     ; ▛
    EQUB &6C     ; ▗ bottom-right
    EQUB &7F     ; ▚ diagonal
    EQUB &E1     ; ▐ right half
    EQUB &FB     ; ▜
    EQUB &62     ; ▄ bottom half
    EQUB &FC     ; ▙
    EQUB &FE     ; ▟
    EQUB &E0     ; █ full block

\ ******************************************************************************
\
\       Name: PlotSixelClipped
\       Type: Subroutine
\   Category: Teletext Elite
\    Summary: Plot a mode 7 sixel
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Sixel x-coordinate
\
\   Y                   Sixel y-coordinate
\
\ ******************************************************************************

.PlotSixelClipped

IF NOT(_DOCKED) AND NOT(_LOADER)

\ CPY #MESSAGE_ROW*3     \ In flight, do not draw on the message row
\ BEQ clip1
\ CPY #MESSAGE_ROW*3+1
\ BEQ clip1
\ CPY #MESSAGE_ROW*3+2
\ BEQ clip1

ENDIF

\ CPX #MODE7_LOW_X       \ If the sixel is off-screen, jump to clip1 to return
\ BCC clip1              \ from the subroutine
\ CPY #MODE7_LOW_Y
\ BCC clip1
 CPX #MODE7_HIGH_X
 BCS clip1
 CPY #MODE7_HIGH_Y
 BCS clip1

IF _LOADER

 CLC                    \ Set ZP(1 0) to the screen address of the character
 LDA xSixel,X           \ block, starting with the low byte
 ADC ySixelLo,Y
 STA ZP

 LDA ySixelHi,Y         \ And then the high byte
 ADC #HI(MODE7_VRAM)
 STA ZP+1

ELSE

 CLC                    \ Set SC(1 0) to the screen address of the character
 LDA xSixel,X           \ block, starting with the low byte
 ADC ySixelLo,Y
 STA SC

 LDA ySixelHi,Y         \ And then the high byte
 ADC #HI(MODE7_VRAM)
 STA SCH

ENDIF

 STX P

 LDA ySixelChar,Y       \ Get the sixel character with the relevant row
                        \ pre-filled for the y-coordinate in Y

 AND xSixelChar,X       \ Apply the sixel character with the relevant column
                        \ pre-filled for the x-coordinate in X, so the result
                        \ is a sixel character with the sixel at (x, y) filled
 STA Q

IF _LOADER

 LDA (ZP),Y
 TAX
 LDA screenToBitfield, X
.sixelLogic
 ORA Q
 TAX
 LDA bitfieldToScreen, X
 STA (ZP),Y

ELSE

 LDA (SC),Y
 TAX
 LDA screenToBitfield, X
 BMI nodraw
.sixelLogic
 EOR Q                  \ EOR the sixel into the screen, flipping whatever is
                        \ already there
 TAX
 LDA bitfieldToScreen, X
 STA (SC),Y

ENDIF
.nodraw

 LDX P

.clip1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ConvertAscii
\       Type: Subroutine
\   Category: PET Elite
\    Summary: Convert ASCII to PET screencode
\
\ ******************************************************************************

.ConvertAscii
    CMP #&60
    BCC done           ; ASCII @ A-Z [\]^_

    SEC
    SBC #&60           ; a-z -> &01-&1A
.done
    RTS
