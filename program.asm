; =====================================================================
;  Washing-machine control program  (5-stage pipelined 8-bit MCU)
;  Register use:  R6 = latched MODE (0..3)   R3 = display base for mode
;                 R4 = current parameter     R7 = I/O / RAM address
;                 R1, R2, R5 = scratch
;  Parameter table in data RAM (initialised by this program):
;    0x10+m target fill level  0x14+m wash ticks  0x18+m spin ticks
;    0x1C+m display base       (m = MODE)
;  Low-water (drain) threshold: 10 for every mode.
; =====================================================================
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

.equ DRAIN_TH, 10
.equ T_TARGET, 0x10
.equ T_WASH,   0x14
.equ T_SPIN,   0x18
.equ T_DISP,   0x1C

reset:      LDI  R7, ACT
            LDI  R1, 0x00
            ST   R1, [R7]          ; all actuator requests off
            LDI  R7, TCTRL
            LDI  R1, 0x02
            ST   R1, [R7]          ; timer: clear, disabled
            LDI  R7, DISP
            LDI  R1, 0x01
            ST   R1, [R7]          ; DISPLAY = 01 (idle / waiting)
; ---- parameter table -------------------------------------------------
            LDI  R7, T_TARGET
            LDI  R1, 100           ; mode 0 NORMAL   target 100
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 60            ; mode 1 QUICK    target 60
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 160           ; mode 2 HEAVY    target 160
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 80            ; mode 3 DELICATE target 80
            ST   R1, [R7]
            ADDI R7, 1             ; R7 = 0x14 : wash ticks
            LDI  R1, 120
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 48
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 200
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 64
            ST   R1, [R7]
            ADDI R7, 1             ; R7 = 0x18 : spin ticks
            LDI  R1, 60
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 32
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 90
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 20
            ST   R1, [R7]
            ADDI R7, 1             ; R7 = 0x1C : display base
            LDI  R1, 0x10
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 0x20
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 0x30
            ST   R1, [R7]
            ADDI R7, 1
            LDI  R1, 0x40
            ST   R1, [R7]
; ---- 1. wait for START=1 and DOOR_CLOSED=1, latch MODE, lock -----------
            LDI  R7, IN_STAT
wait_start: LD   R1, [R7]          ; one snapshot of START/MODE/DOOR
            LDI  R2, 0x0C          ; START | DOOR_CLOSED
            AND  R2, R1
            ADDI R2, 0xF4          ; -12 : zero only if both bits set
            BNEZ R2, wait_start
            LDI  R6, M_MODE
            AND  R6, R1            ; R6 = MODE from the accepting snapshot
            LDI  R7, ACT
            LDI  R1, A_LOCK
            ST   R1, [R7]          ; request door lock
            LDI  R7, IN_STAT
door_chk:   LD   R1, [R7]          ; lock is only a request: re-check door
            LDI  R2, B_DOOR
            AND  R2, R1
            BEQZ R2, door_chk
            LDI  R5, T_DISP
            ADD  R5, R6
            LD   R3, [R5]          ; R3 = display base of this mode
; ---- 2. fill until WATER_LEVEL >= target (unsigned) -----------------------
            MOV  R1, R3
            ADDI R1, 2
            LDI  R7, DISP
            ST   R1, [R7]          ; DISPLAY = m2 (filling)
            LDI  R5, T_TARGET
            ADD  R5, R6
            LD   R4, [R5]          ; R4 = target level
            LDI  R7, ACT
            LDI  R1, 0x21          ; LOCK | VALVE_IN
            ST   R1, [R7]
            LDI  R7, LEVEL
fill_loop:  LD   R1, [R7]
            SLTU R1, R4            ; R1 = (level < target)
            BNEZ R1, fill_loop     ; exits on any level >= target (overshoot safe)
            LDI  R7, ACT
            LDI  R1, A_LOCK
            ST   R1, [R7]          ; valve closed
; ---- 3. wash: motor on, direction alternates every 16 timer ticks --------
            MOV  R1, R3
            ADDI R1, 3
            LDI  R7, DISP
            ST   R1, [R7]          ; DISPLAY = m3 (washing)
            LDI  R5, T_WASH
            ADD  R5, R6
            LD   R4, [R5]          ; R4 = wash interval
            LDI  R7, TLIMIT
            ST   R4, [R7]
            LDI  R7, TCTRL
            LDI  R1, 0x03          ; CLR + EN : count from 0
            ST   R1, [R7]
wash_loop:  LDI  R7, TCOUNT
            LD   R1, [R7]
            LDI  R2, 0x10
            AND  R2, R1            ; direction = COUNT bit 4
            LDI  R1, 0x24          ; LOCK | MOTOR_EN
            BEQZ R2, wash_dir
            LDI  R1, 0x2C          ; LOCK | MOTOR_EN | MOTOR_DIR
wash_dir:   LDI  R7, ACT
            ST   R1, [R7]
            LDI  R7, IN_STAT
            LD   R2, [R7]
            LDI  R1, B_TRIP
            AND  R1, R2
            BNEZ R1, wash_fault
            LDI  R7, TSTAT
            LD   R1, [R7]
            BEQZ R1, wash_loop     ; until sticky MATCH
            LDI  R7, ACT
            LDI  R1, A_LOCK
            ST   R1, [R7]          ; motor off
            LDI  R7, TCTRL
            LDI  R1, 0x02
            ST   R1, [R7]          ; timer cleared and stopped
            JMP  drain
wash_fault: LDI  R7, ACT
            LDI  R1, A_LOCK
            ST   R1, [R7]          ; drop motor request (needed for re-arm)
            LDI  R7, TCTRL
            LDI  R1, 0x00
            ST   R1, [R7]          ; pause timer
            LDI  R7, DISP
            LDI  R1, 0xE3
            ST   R1, [R7]          ; DISPLAY = E3 (door fault while washing)
            LDI  R7, IN_STAT
wf_wait:    LD   R2, [R7]
            LDI  R1, B_TRIP
            AND  R1, R2
            BNEZ R1, wf_wait       ; hardware clears TRIP on safe re-arm
            LDI  R7, TCTRL
            LDI  R1, 0x01
            ST   R1, [R7]          ; resume timer
            MOV  R1, R3
            ADDI R1, 3
            LDI  R7, DISP
            ST   R1, [R7]
            JMP  wash_loop
; ---- 4. drain until WATER_LEVEL <= threshold (unsigned) ------------------
drain:      MOV  R1, R3
            ADDI R1, 4
            LDI  R7, DISP
            ST   R1, [R7]          ; DISPLAY = m4 (draining)
            LDI  R7, ACT
            LDI  R1, 0x30          ; LOCK | PUMP_OUT
            ST   R1, [R7]
            LDI  R7, LEVEL
            LDI  R4, DRAIN_TH
drain_loop: LD   R2, [R7]
            MOV  R1, R4
            SLTU R1, R2            ; R1 = (threshold < level)
            BNEZ R1, drain_loop    ; exits on any level <= threshold
; ---- 5. spin: clear + re-arm timer, motor on (one direction), pump on ----
            MOV  R1, R3
            ADDI R1, 5
            LDI  R7, DISP
            ST   R1, [R7]          ; DISPLAY = m5 (spinning)
            LDI  R5, T_SPIN
            ADD  R5, R6
            LD   R4, [R5]          ; R4 = spin interval
            LDI  R7, TLIMIT
            ST   R4, [R7]
            LDI  R7, TCTRL
            LDI  R1, 0x03
            ST   R1, [R7]          ; CLR + EN (re-arm)
            LDI  R7, ACT
            LDI  R1, 0x3C          ; LOCK | PUMP | MOTOR_EN | MOTOR_DIR
            ST   R1, [R7]
spin_loop:  LDI  R7, IN_STAT
            LD   R2, [R7]
            LDI  R1, B_TRIP
            AND  R1, R2
            BNEZ R1, spin_fault
            LDI  R7, TSTAT
            LD   R1, [R7]
            BEQZ R1, spin_loop
            JMP  finish
spin_fault: LDI  R7, ACT
            LDI  R1, 0x30          ; motor request off, keep pump
            ST   R1, [R7]
            LDI  R7, TCTRL
            LDI  R1, 0x00
            ST   R1, [R7]
            LDI  R7, DISP
            LDI  R1, 0xE5
            ST   R1, [R7]          ; DISPLAY = E5 (door fault while spinning)
            LDI  R7, IN_STAT
sf_wait:    LD   R2, [R7]
            LDI  R1, B_TRIP
            AND  R1, R2
            BNEZ R1, sf_wait
            LDI  R7, TCTRL
            LDI  R1, 0x01
            ST   R1, [R7]
            LDI  R7, ACT
            LDI  R1, 0x3C
            ST   R1, [R7]
            MOV  R1, R3
            ADDI R1, 5
            LDI  R7, DISP
            ST   R1, [R7]
            JMP  spin_loop
; ---- 6. stop everything, unlock only when the motor is off, buzzer -------
finish:     LDI  R7, ACT
            LDI  R1, A_LOCK
            ST   R1, [R7]          ; motor + pump off, door still locked
            LDI  R7, TCTRL
            LDI  R1, 0x02
            ST   R1, [R7]          ; timer stopped
            LDI  R7, IN_STAT
fin_mact:   LD   R1, [R7]
            LDI  R2, B_MACT
            AND  R2, R1
            BNEZ R2, fin_mact      ; physical motor enable must be off
            LDI  R7, RPM
fin_rpm:    LD   R1, [R7]
            BNEZ R1, fin_rpm       ; drum stopped (DRUM_RPM = 0)
            LDI  R7, ACT
            LDI  R1, A_BUZZ
            ST   R1, [R7]          ; unlock + BUZZER
            MOV  R1, R3
            ADDI R1, 6
            LDI  R7, DISP
            ST   R1, [R7]          ; DISPLAY = m6 (done)
            HALT
