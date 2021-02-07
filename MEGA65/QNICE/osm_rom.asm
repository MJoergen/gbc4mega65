; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; QNICE ROM: GBC Boot-ROM loader and On-Screen-Menu
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

#include "../../QNICE/dist_kit/sysdef.asm"
#include "../../QNICE/dist_kit/monitor.def"
#include "gbc.asm"

                .ORG    0x8000                  ; start at 0x8000

                ; initialize variables
                MOVE    SD_DEVHANDLE, R8        ; invalidate device handle
                MOVE    0, @R8
                MOVE    FILEHANDLE, R8          ; ditto file handle
                MOVE    0, @R8
                MOVE    CUR_X, R8               ; cursor X = 0
                MOVE    0, @R8
                MOVE    CUR_Y, R8               ; ditto cursor Y
                MOVE    0, @R8

                ; set visibility parameters and print frame
                MOVE    GBC$CSR, R0             ; R0: GBC control & status reg
                MOVE    0, @R0
                OR      GBC$CSR_RESET, @R0      ; put machine in reset state 
                OR      GBC$CSR_OSM, @R0        ; show on-screen-menu
                RSUB    CLRSCR, 1               ; clear VRAM
                XOR     R8, R8                  ; x|y for frame = (0, 0)
                XOR     R9, R9                  
                MOVE    GBC$OSM_COLS, R10       ; full screen size
                MOVE    GBC$OSM_ROWS, R11
                RSUB    PRINTFRAME, 1           ; show frame

                MOVE    STR_TITLE, R8           ; welcome message
                RSUB    PRINTSTR, 1
                RSUB    WAIT_2S, 1

                ; Mount SD card and load original ROMs, if available.
                RSUB    CHKORMNT, 1             ; mount SD card partition #1 
                CMP     0, R9
                RBRA    MOUNT_OK, Z
                HALT                            ; TODO: replace by retry
MOUNT_OK        MOVE    FN_GBC_ROM, R8          ; full path to ROM
                MOVE    MEM_BIOS, R9            ; MMIO location of "ROM RAM"
                RSUB    LOAD_ROM, 1
                RSUB    WAIT_2S, 1

                ; Load Tetris
                MOVE    STR_CART_LOAD, R8
                RSUB    PRINTSTR, 1
                MOVE    TMP_KWIRK, R8
                RSUB    PRINTSTR, 1
                MOVE    MEM_CARTRIDGE_WIN, R9
                MOVE    GBC$CART_SEL, R10  
                RSUB    LOAD_CART, 1
                CMP     0, R11
                RBRA    CART_OK, Z
                MOVE    ERR_LOAD_CART, R8
                RSUB    PRINTSTR, 1
                HALT                            ; TODO

CART_OK         MOVE    STR_CART_DONE, R8
                RSUB    PRINTSTR, 1

                MOVE    GBC$CSR, R0             ; R0 = control & status reg.

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR1, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                AND     GBC$CSR_UN_RESET, @R0   ; un-reset => system runs now
                AND     GBC$CSR_UN_OSM, @R0     ; hide OSM

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR2, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                ; pause
                OR      GBC$CSR_PAUSE, @R0      ; pause
                OR      GBC$CSR_OSM, @R0        ; show OSM

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR3, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                ; un-pause
                AND     GBC$CSR_UN_PAUSE, @R0   ; un-pause
                AND     GBC$CSR_UN_OSM, @R0     ; hide OSM

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR4, R8
                RSUB    PRINTSTR, 1

                SYSCALL(exit, 1)

TEST_STR1       .ASCII_W "GBC is reset and paused\n"
TEST_STR2       .ASCII_W "GBC is running\n"
TEST_STR3       .ASCII_W "GBC is paused\n"
TEST_STR4       .ASCII_W "GBC is running\n"

TMP_TETRIS      .ASCII_W "/gbc/tetris.gb"
TMP_KWIRK       .ASCII_W "/gbc/kwirk.gb"

STR_TITLE       .ASCII_W "Game Boy Color for MEGA65\nMiSTer port done by sy2002 in 2021\n\n"

STR_ROM_FF      .ASCII_W " found. Using this ROM.\n\n"
STR_ROM_FNF     .ASCII_W " NOT FOUND!\n\nWill use built-in open source ROM instead.\n\n"
STR_CART_LOAD   .ASCII_W "Loading cartridge: "
STR_CART_DONE   .ASCII_W "\nDone.\n"

FN_DMG_ROM      .ASCII_W "/gbc/dmg_boot.bin"
FN_GBC_ROM      .ASCII_W "/gbc/cgb_bios.bin"
FN_START_DIR    .ASCII_W "/gbc"

ERR_MNT         .ASCII_W "Error mounting device: SD Card. Error code: "
ERR_LOAD_ROM    .ASCII_W "Error loading ROM: Illegal file: File too long.\n"
ERR_LOAD_CART   .ASCII_W "  ERROR!\n"

; ----------------------------------------------------------------------------
; SD Card / file system functions
; ----------------------------------------------------------------------------

; Check, if we have a valid device handle and if not, mount the SD Card
; as the device. For now, we are using partition 1 hardcoded. This can be
; easily changed in the following code, but then we need an explicit
; mount/unmount mechanism, which is currently done automatically.
; Returns the device handle in R8, R9 = 0 if everything is OK,
; otherwise errorcode in R9 and R8 = 0
CHKORMNT        XOR     R9, R9
                MOVE    SD_DEVHANDLE, R8
                CMP     0, @R8                  ; valid handle?
                RBRA    _CHKORMNT_RET, !Z       ; yes: leave
                MOVE    1, R9                   ; partition #1
                SYSCALL(f32_mnt_sd, 1)
                CMP     0, R9                   ; mounting worked?
                RBRA    _CHKORMNT_RET, Z        ; yes: leave
                MOVE    ERR_MNT, R8             ; print error message
                RSUB    PRINTSTR, 1
                MOVE    R9, R8                  ; print error code
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1
                MOVE    SD_DEVHANDLE, R8        ; invalidate device handle
                XOR     @R8, @R8 
                XOR     R8, R8                  ; return 0 as device handle                   
_CHKORMNT_RET   RET

; Check, if original ROM is available and load it.
;  R8: full path to file to be loaded
;  R9: MMIO address of "ROM RAM"
; R10: 0 = file found, using ROM from file
;      1 = file not found, using Open Source ROM
;      2 = load error, corrupt state, system should halt
LOAD_ROM        INCRB
                MOVE    R9, R7                  ; R7: MMIO addr. of "ROM RAM"
                RSUB    PRINTSTR, 1             ; print full file path
                MOVE    R8, R10                 ; R10: full path to file
                MOVE    SD_DEVHANDLE, R8        ; R8: device handle
                MOVE    FILEHANDLE, R9          ; R9: file handle
                XOR     R11, R11                ; 0 = "/" is path separator
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; file open worked?
                RBRA    _LR_FOPEN_OK, Z         ; yes: process
                MOVE    STR_ROM_FNF, R8         ; no: print msg and use ..
                RSUB    PRINTSTR, 1             ; .. Open Source ROM instead
                MOVE    1, R10                  ; return with code 1
                RBRA    _LOAD_ROM_RET, 1

_LR_FOPEN_OK    MOVE    STR_ROM_FF, R8
                RSUB    PRINTSTR, 1
                MOVE    R9, R8                  ; R8: valid file handle
                MOVE    R7, R0                  ; R0: MMIO BIOS "ROM RAM"
                MOVE    R0, R1                  ; R1: maximum length
                ADD     MEM_BIOS_MAXLEN, R1                

_LR_LOAD_LOOP   SYSCALL(f32_fread, 1)           ; read one byte
                CMP     FAT32$EOF, R10          ; EOF?
                RBRA    _LR_LOAD_OK, Z          ; yes: close file and end
                MOVE    R9, @R0++               ; no: store byte in "ROM RAM"
                CMP     R0, R1                  ; maximum length reached?
                RBRA    _LR_LOAD_LOOP, !Z       ; no: continue with next byte
                MOVE    2, R10                  ; yes: illegal/corrupt file
                MOVE    ERR_LOAD_ROM, R8
                RBRA    PRINTSTR, 1
                RBRA    _LR_FCLOSE, 1           ; end with code 2

_LR_LOAD_OK     XOR     R10, R10                ; R10 = 0: file load OK                
_LR_FCLOSE      MOVE    FILEHANDLE, R8          ; close file
                MOVE    0, @R8
_LOAD_ROM_RET   DECRB
                RET

; Check, if original ROM is available and load it.
;  R8: full path to file to be loaded
;  R9: MMIO address of "ROM RAM"
; R10: MMIO address of window selector
; R11: 0 = OK
;      1 = file not found
LOAD_CART       INCRB
                MOVE    R9, R0                  ; R0: MMIO addr. of 4k win.
                MOVE    R10, R1                 ; R1: MMIO of win. selector
                MOVE    R8, R10                 ; R9: full path to cart. file
                XOR     R11, R11                ; 0 = "/" is path separator
                MOVE    SD_DEVHANDLE, R8        ; R8: device handle
                MOVE    FILEHANDLE, R9          ; R9: file handle
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; file open worked?
                RBRA    _LC_FOPEN_OK, Z         ; yes: process
                MOVE    1, R11                  ; end with code 1
                RBRA    _LC_FCLOSE, 1

_LC_FOPEN_OK    MOVE    R9, R8                  ; R8: valid file handle
                MOVE    0, @R1                  ; start with 0 as win. sel.
                MOVE    R0, R3                  ; window boundary + 1
                ADD     MEM_CARTWIN_MAXLEN, R3
_LC_LOAD_LOOP1  MOVE    R0, R2                  ; R2: write pointer to 4k win.
_LC_LOAD_LOOP2  SYSCALL(f32_fread, 1)
                CMP     FAT32$EOF, R10          ; EOF?
                RBRA    _LC_LOAD_OK, Z          ; yes: close file and end  
                MOVE    R9, @R2++               ; store byte in cart. mem.
                CMP     R3, R2                  ; window boundary reached?
                RBRA    _LC_LOAD_LOOP2, !Z      ; no: continue with next byte
                ADD     1, @R1                  ; next cart. mem. window
                RBRA    _LC_LOAD_LOOP1, 1

_LC_LOAD_OK     XOR     R11, R11                ; end with code 0
_LC_FCLOSE      MOVE    FILEHANDLE, R8          ; close file
                MOVE    0, @R8            
                DECRB
                RET

; ----------------------------------------------------------------------------
; Screen and Serial IO functions
; ----------------------------------------------------------------------------

; Print the string in R8 on the current cursor position on the screen
; and in parallel to the UART
PRINTSTR        RSUB    ENTER, 1

                SYSCALL(puts, 1)                ; output on serial console

                MOVE    R8, R0                  ; R0: string to be printed
                MOVE    CUR_X, R1               ; R1: running x-cursor
                MOVE    CUR_Y, R2               ; R2: running y-cursor
                MOVE    INNER_X, R3             ; R3: inner-left x-coord for..
                MOVE    @R3, R3                 ; ..not printing outside frame                                                

                RSUB    CALC_VRAM, 1            ; R8: VRAM addr of curs. pos.

_PS_L1          MOVE    @R0++, R4               ; read char
                CMP     0x000D, R4              ; is it a CR?
                RBRA    _PS_L2, Z               ; yes: process
                CMP     0, R4                   ; no: end-of-string?
                RBRA    _PS_RET, Z              ; yes: leave
                MOVE    R4, @R8++               ; no: print char
                ADD     1, @R1                  ; x-cursor + 1
                RBRA    _PS_L1, 1               ; next char

_PS_L2          MOVE    @R0++, R5               ; next char
                CMP     0x000A, R5              ; is it a LF?
                RBRA    _PS_L3, Z               ; yes: process
                MOVE    0x000D, @R8++           ; no: print original chard
                MOVE    R5, @R8++
                RBRA    _PS_L1, 1

_PS_L3          MOVE    R3, @R1                 ; inner-left start x-coord
                ADD     1, @R2                  ; new line
                RSUB    CALC_VRAM, 1
                RBRA    _PS_L1, 1

_PS_RET         RSUB    LEAVE, 1
                RET

; Print the number in R8 in hexadecimal
PRINTHEX        INCRB
                SYSCALL(puthex, 1)
                DECRB
                RET

; Move the cursor to the next line
PRINTCRLF       INCRB
                SYSCALL(crlf, 1)
                DECRB
                RET

; Calculates the VRAM address for the current cursor pos in CUR_X & CUR_Y
; R8: VRAM address
CALC_VRAM       RSUB    ENTER, 1

                MOVE    MEM_VRAM, R0            ; video ram address equals ..    
                MOVE    CUR_Y, R8               ; .. CUR_Y x GBC$OSM_COLS ..
                MOVE    @R8, R8
                MOVE    GBC$OSM_COLS, R9
                SYSCALL(mulu, 1)                ; R10 = R8 x R9
                MOVE    CUR_X, R8
                MOVE    @R8, R8
                ADD     R8, R10                 ; .. + CUR_X
                ADD     R10, R0                 ; R0 = video RAM addr

                MOVE    R0, @--SP
                RSUB    LEAVE, 1
                MOVE    @SP++, R8
                RET

; clear screen (VRAM) by filling it with 0 which is an empty char in our font
CLRSCR          INCRB
                MOVE    MEM_VRAM, R0
                MOVE    4096, R1
_CLRSCR_L       MOVE    0, @R0++
                SUB     1, R1
                RBRA    _CLRSCR_L, !Z                 
                DECRB
                RET

; Sets the visibility registers and draws a frame
; R8/R9:   start x/y coordinates
; R10/R11: dx/dy sizes, both need to be larger than 3
PRINTFRAME      RSUB    ENTER, 1

                ; set x/y coordinates
                MOVE    GBC$OSM_XY, R0
                MOVE    R8, @R0
                AND     0xFFFD, SR              ; clear X-flag (shift in '0')
                SHL     8, @R0
                ADD     R9, @R0

                ; set dx/dy sizes
                MOVE    GBC$OSM_DXDY, R0
                MOVE    R10, @R0
                AND     0xFFFD, SR
                SHL     8, @R0
                ADD     R11, @R0

                ; calculate VRAM start position and set the cursor to the
                ; first free inner position (the cursor is not needed for
                ; the rest of this routine but afterwards)
                MOVE    CUR_X, R0
                MOVE    R8, @R0
                MOVE    CUR_Y, R1
                MOVE    R9, @R1
                RSUB    CALC_VRAM, 1
                ADD     1, @R0                  ; first free inner pos for x
                ADD     1, @R1                  ; ditto y
                MOVE    INNER_X, R2
                MOVE    @R0, @R2

                ; calculate delta to next line in VRAM
                MOVE    R10, R0                 ; R10: dx
                SUB     1, R0              
                MOVE    GBC$OSM_COLS, R1
                SUB     R0, R1                  ; R1: delta = cols - (dx - 1)

                ; draw loop for top line
                MOVE    CHR_FC_TL, @R8++        ; draw top/left corner
                MOVE    R10, R0
                SUB     2, R0                   ; net dx
                MOVE    R0, R2
_PF_DL1         MOVE    CHR_FC_SH, @R8++        ; horizontal line
                SUB     1, R2
                RBRA    _PF_DL1, !Z
                MOVE    CHR_FC_TR, @R8          ; draw top/right corner

                ; draw horizontal border
                MOVE    R11, R3
                SUB     2, R3
                MOVE    R3, R2
_PF_DL2         ADD     R1, R8                  ; next line
                MOVE    CHR_FC_SV, @R8++
                ADD     R0, R8                  ; net dx
                MOVE    CHR_FC_SV, @R8
                SUB     1, R2
                RBRA    _PF_DL2, !Z

                ; draw loop for bottom line
                ADD     R1, R8                  ; next line
                MOVE    CHR_FC_BL, @R8++        ; draw bottom/left corner
                MOVE    R0, R2
_PF_DL3         MOVE    CHR_FC_SH, @R8++        ; horizontal line
                SUB     1, R2
                RBRA    _PF_DL3, !Z
                MOVE    CHR_FC_BR, @R8          ; draw bottom/right corner                   

                RSUB    LEAVE, 1
                RET

; ----------------------------------------------------------------------------
; Misc helper functions
; ----------------------------------------------------------------------------

; Alternative to a pure INCRB that also saves R8 .. R12
ENTER           INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4
                INCRB
                RET

; Alternative to a pure DECRB that also restores R8 .. R12
LEAVE           DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12
                DECRB
                RET

; Wait for about 2 seconds
WAIT_2S         INCRB
                MOVE    200, R0
_WAITLOOP2      MOVE    0xFFFF, R1
_WAITLOOP1      SUB     1, R1
                RBRA    _WAITLOOP1, !Z
                SUB     1, R0
                RBRA    _WAITLOOP2, !Z
                DECRB
                RET

; ----------------------------------------------------------------------------
; Variables (need to be located in RAM)
; ----------------------------------------------------------------------------

SD_DEVHANDLE   .BLOCK  FAT32$DEV_STRUCT_SIZE   ; SD card device handle
FILEHANDLE     .BLOCK  FAT32$FDH_STRUCT_SIZE   ; File handle
CUR_X          .BLOCK  1                       ; OSD cursor x coordinate
CUR_Y          .BLOCK  1                       ; ditto y
INNER_X        .BLOCK  1                       ; first x-coord within frame