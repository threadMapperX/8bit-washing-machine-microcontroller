; Test group 4 : timer count, sticky MATCH, clear/re-arm over two intervals, wraparound
; ---------------- memory map (see memory_map.pdf) ----------------
.equ IN_STAT, 0xF0      ; R  : [1:0] MODE, [2] START, [3] DOOR_CLOSED, [4] TRIP, [5] MOTOR_ACTUAL
.equ LEVEL,   0xF1      ; R  : WATER_LEVEL[7:0] (unsigned)
.equ TEMP,    0xF2      ; R  : TEMP[7:0]
.equ RPM,     0xF3      ; R  : DRUM_RPM[7:0]
.equ ACT,     0xF4      ; RW : [0] VALVE_IN [1] HEATER [2] MOTOR_EN [3] MOTOR_DIR [4] PUMP_OUT [5] DOOR_LOCK [6] BUZZER
.equ DISP,    0xF5      ; RW : DISPLAY[7:0]
.equ TCOUNT,  0xF6      ; R  : TIMER_COUNT
.equ TLIMIT,  0xF7      ; RW : TIMER_LIMIT (0 = compare disabled)
.equ TCTRL,   0xF8      ; RW : [0] EN (R/W) ; [1] CLR (write-1 pulse, reads 0)
.equ TSTAT,   0xF9      ; R  : [0] MATCH (sticky)
; IN_STAT bits
.equ M_MODE,  0x03
.equ B_START, 0x04
.equ B_DOOR,  0x08
.equ B_TRIP,  0x10
.equ B_MACT,  0x20
; ACT bits
.equ A_VALVE, 0x01
.equ A_HEAT,  0x02
.equ A_MOTOR, 0x04
.equ A_DIR,   0x08
.equ A_PUMP,  0x10
.equ A_LOCK,  0x20
.equ A_BUZZ,  0x40

            LDI  R7, TLIMIT
            LDI  R1, 5
            ST   R1, [R7]          ; LIMIT = 5 (no retroactive MATCH)
            LDI  R7, TSTAT
            LD   R0, [R7]          ; MATCH = 0 after writing LIMIT
            LDI  R7, TCTRL
            LDI  R1, 0x03
            ST   R1, [R7]          ; CLR + EN  -> interval 1
            LDI  R7, TSTAT
w1:         LD   R1, [R7]          ; LD -> BEQZ : one load-use stall per iteration
            BEQZ R1, w1            ;   (timer keeps ticking through the bubbles)
            LDI  R7, TCOUNT
            LD   R2, [R7]          ; COUNT has moved past LIMIT
            NOP
            NOP
            NOP
            NOP
            LDI  R7, TSTAT
            LD   R3, [R7]          ; MATCH still 1 (sticky)
            LDI  R7, TLIMIT
            LDI  R1, 3
            ST   R1, [R7]          ; LIMIT = 3
            LDI  R7, TCTRL
            LDI  R1, 0x03
            ST   R1, [R7]          ; CLR + EN -> interval 2 (re-arm)
            LDI  R7, TSTAT
            LD   R4, [R7]          ; 0 right after the clear
w2:         LD   R1, [R7]
            BEQZ R1, w2
            LDI  R7, TLIMIT
            LDI  R1, 0
            ST   R1, [R7]          ; LIMIT = 0 : comparison disabled
            LDI  R7, TCTRL
            LDI  R1, 0x03
            ST   R1, [R7]          ; CLR + EN, free run through 0xFF -> 0x00
            LDI  R5, 0x50          ; 80 x 4-cycle loop = 320 cycles > 256
dly:        ADDI R5, 0xFF
            BNEZ R5, dly
            LDI  R7, TSTAT
            LD   R5, [R7]          ; MATCH stays 0 with LIMIT = 0
            LDI  R7, TCOUNT
            LD   R6, [R7]          ; count wrapped (small value)
            LDI  R7, 0x60
            ST   R0, [R7]
            ADDI R7, 1
            ST   R2, [R7]
            ADDI R7, 1
            ST   R3, [R7]
            ADDI R7, 1
            ST   R4, [R7]
            ADDI R7, 1
            ST   R5, [R7]
            ADDI R7, 1
            ST   R6, [R7]
            HALT
