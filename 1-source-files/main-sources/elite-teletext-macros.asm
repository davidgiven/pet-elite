\ ******************************************************************************
\
\ TELETEXT ELITE MACROS
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

SIXELW = 4
SIXELH = 4

\ ******************************************************************************
\
\       Name: SCALE_SIXEL_X
\       Type: Macro
\   Category: Teletext Elite
\    Summary: Scale a pixel x-coordinate to a sixel x-coordinate
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The pixel x-coordinate
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The sixel x-coordinate
\
\ ******************************************************************************

MACRO SCALE_SIXEL_X

IF _LOADER

 TAX
 LDA divideBySix, X

ELSE

 LSR A                  \ Set A = A / 4, rounded to the nearest integer
 LSR A
 ADC #0

ENDIF

ENDMACRO

\ ******************************************************************************
\
\       Name: SCALE_SIXEL_Y
\       Type: Macro
\   Category: Teletext Elite
\    Summary: Scale a pixel y-coordinate to a sixel y-coordinate, moving it down
\             a row to skip the border row along the top of the screen
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The pixel y-coordinate
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The sixel y-coordinate
\
\ ******************************************************************************

MACRO SCALE_SIXEL_Y

IF _LOADER

 TAY
 LDA divideBySix, Y

ELSE

 LSR A                  \ Set A = A / 4, rounded to the nearest integer
 LSR A
 ADC #0

ENDIF

ENDMACRO

MACRO SCALE_SIXEL_Y_6

 TAY
 LDA divideBySix, Y

ENDMACRO
