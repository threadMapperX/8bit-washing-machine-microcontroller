; Test group 5 : safety interlock (motor requested, door opened, no automatic restart)
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

            LDI  R7, ACT
            LDI  R1, 0x24          ; LOCK | MOTOR_EN request
            ST   R1, [R7]
            LDI  R6, IN_STAT
run:        LD   R2, [R6]
            LDI  R1, B_TRIP
            AND  R1, R2
            BEQZ R1, run           ; keep requesting until TRIP
            LDI  R1, A_LOCK
            ST   R1, [R7]          ; software clears motor request
wait_rearm: LD   R2, [R6]
            LDI  R1, B_TRIP
            AND  R1, R2
            BNEZ R1, wait_rearm    ; TRIP clears only on explicit safe re-arm
            LDI  R1, 0x24
            ST   R1, [R7]          ; request motor again
            JMP  run
