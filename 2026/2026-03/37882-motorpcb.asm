; ============================================================================
; Galaxy Force 2 Super Deluxe - Motor PCB Z80 Firmware
; ============================================================================
;
; Board:        839-0161 Motor Drive Board
; CPU:          Z80 @ 4MHz (4MHz oscillator on drive board)
;               Note: MAME guesses 8MHz from 16MHz/2, but actual hardware
;               has a dedicated 4MHz oscillator.
; ROM:          32KB (27C256), only $0000-$1FFF contains code/data
;               $2000-$7FFF is $FF padding (unused)
;
; Purpose:      Controls the motorized cabinet motion for the Galaxy Force 2
;               Super Deluxe arcade cabinet. Manages two motor axes:
;               - Bank motor (pitch/roll of the cabinet)
;               - Vibration motor (shaking/rumble effects)
;
; Motor Types:  Two motor configurations supported via DIP switch:
;               - 350-5133 (DIP all OFF, bit 0 = 0)
;               - 350-5134 (DIP bit 0 = 1)
;
; Communication: Receives commands from main board (68000), sends back
;                position data and status information.
;
; ============================================================================

; ============================================================================
; Memory Map
; ============================================================================
;
; $0000-$1FFF  ROM (8KB actual code/data)
; $2000-$7FFF  ROM (unused, $FF padding)
; $8000-$8003  NEC D8255AC-2 PPI (Programmable Peripheral Interface)
;   $8000      Port A - Motor direction control (output)
;              Bit 0: Bank motor forward
;              Bit 1: Bank motor reverse
;              Bit 2: Vibration motor forward
;              Bit 3: Vibration motor reverse
;              Bit 4: ADC mux select (bank=0/vibration=1)
;              Bit 5: (unused, cleared)
;              Bit 6: (unused, cleared)
;   $8001      Port B - Status output to main board / limit switch mux
;   $8002      Port C - Input from limit switches and misc signals
;   $8003      Control word register
; $8400        MB3773 Watchdog timer (read or write to pet)
; $8800        Additional status input port (limit switches, ADC busy, etc.)
;              Bit 0: Limit switch - bank CW limit
;              Bit 1: Limit switch - bank CCW limit
;              Bit 2: Limit switch - vibration CW limit
;              Bit 3: Limit switch - vibration CCW limit
;              Bit 4: ADC0804 bank conversion done (INTR)
;              Bit 5: ADC0804 vibration conversion done (INTR)
;              Bit 6: Additional limit switch input
; $8C00        Main board input port (command byte from 68000)
;              Bit 0: Motor type DIP switch (0=350-5133, 1=350-5134)
;              Bit 3: Diagnostic mode select
; $9000-$9003  NEC D71054 Timer/Counter 0 (bank motor PWM)
;   $9000      Counter 0 - Bank motor PWM duty cycle
;   $9001      Counter 1 - Bank motor speed
;   $9002      Counter 2 - Bank motor clock divider
;   $9003      Control word
; $9400-$9403  NEC D71054 Timer/Counter 1 (vibration motor PWM)
;   $9400      Counter 0 - Vibration motor PWM duty cycle
;   $9401      Counter 1 - Vibration motor speed
;   $9402      Counter 2 - Vibration motor clock divider
;   $9403      Control word
; $9800        ADC0804 bank position read (also triggers conversion)
; $9C00        ADC0804 vibration position read (also triggers conversion)
; $C000        Main board data output port
; $C001        Main board control/command output port
; $E000        Control register (ADC start conversion trigger)
; $F000-$F7FF  Working RAM (2KB)
;

; ============================================================================
; Constants / Equates
; ============================================================================

; --- I/O Ports ---
PPI_PORT_A          equ $8000       ; Motor direction control outputs
PPI_PORT_B          equ $8001       ; Status output to main board
PPI_PORT_C          equ $8002       ; Input signals
PPI_CONTROL         equ $8003       ; PPI control word register
WATCHDOG            equ $8400       ; MB3773 watchdog pet
STATUS_INPUT        equ $8800       ; Limit switches and ADC status
MAIN_BOARD_INPUT    equ $8C00       ; Command byte from main board
TIMER0_CNT0         equ $9000       ; Bank motor timer counter 0
TIMER0_CNT1         equ $9001       ; Bank motor timer counter 1 (speed)
TIMER0_CNT2         equ $9002       ; Bank motor timer counter 2 (divider)
TIMER0_CTRL         equ $9003       ; Bank motor timer control word
TIMER1_CNT0         equ $9400       ; Vibration motor timer counter 0
TIMER1_CNT1         equ $9401       ; Vibration motor timer counter 1 (speed)
TIMER1_CNT2         equ $9402       ; Vibration motor timer counter 2 (divider)
TIMER1_CTRL         equ $9403       ; Vibration motor timer control word
ADC_BANK            equ $9800       ; ADC channel 0 - bank pot position
ADC_VIBRATION       equ $9C00       ; ADC channel 1 - vibration position
MAIN_BOARD_DATA     equ $C000       ; Data output to main board
MAIN_BOARD_CTRL     equ $C001       ; Control/command output to main board
CONTROL_REG         equ $E000       ; ADC mux / conversion trigger

; --- PPI Control Word ---
PPI_MODE0_A_OUT_B_OUT_CU_IN_CL_OUT equ $89

; --- Timer Control Words ---
TIMER_CNT0_MODE2_LSB equ $24       ; Counter 0, mode 2 (rate gen), LSB only
TIMER_CNT1_MODE5_LSB equ $5A       ; Counter 1, mode 5 (hw trigger strobe), LSB only
TIMER_CNT2_MODE2_LSB equ $94       ; Counter 2, mode 2 (rate gen), LSB only

; --- RAM Variables ($F000-$F03F) ---
; Motor control parameters
cmd_code             equ $F001      ; Current command code from main board
bank_motor_cmd       equ $F002      ; Bank motor sub-command (direction index)
vibration_motor_cmd  equ $F003      ; Vibration motor sub-command
bank_motion_mode     equ $F004      ; Bank motion mode (0-3)
bank_position        equ $F005      ; Bank pot position (ADC reading)
vibration_position   equ $F006      ; Vibration pot position (ADC reading)
bank_motor_speed     equ $F008      ; Bank motor current speed
vibration_motor_speed equ $F009     ; Vibration motor current speed
bank_adc_raw         equ $F00A      ; Bank ADC raw value (for position calc)
vibration_adc_raw    equ $F00B      ; Vibration ADC raw value
bank_motor_dir       equ $F00C      ; Bank motor direction (0=stop,1=CW,2=CCW)
vibration_motor_dir  equ $F00D      ; Vibration motor direction
limit_sw_bank_cw     equ $F00E      ; Limit switch: bank CW (debounced, $FF=active)
limit_sw_bank_ccw    equ $F00F      ; Limit switch: bank CCW
limit_sw_vib_cw      equ $F010      ; Limit switch: vibration CW
limit_sw_vib_ccw     equ $F011      ; Limit switch: vibration CCW
limit_raw_0          equ $F012      ; Raw limit switch reading 0
limit_raw_1          equ $F013      ; Raw limit switch reading 1
limit_raw_2          equ $F014      ; Raw limit switch reading 2
misc_input_0         equ $F015      ; Misc input bits (from $8800)
misc_input_1         equ $F016      ; Misc input bits (from $8800)
bank_accel_thresh    equ $F019      ; Bank motor accel/PWM threshold
vibration_accel_thresh equ $F01A    ; Vibration motor accel/PWM threshold
prev_main_board_byte equ $F01B      ; Previous main board input (for change detect)
main_board_command   equ $F01C      ; Validated main board command byte
bank_speed_step      equ $F01D      ; Bank motor speed ramp step counter
vibration_speed_step equ $F01E      ; Vibration motor speed ramp step counter
bank_pos_16bit       equ $F01F      ; Bank position 16-bit (computed, 2 bytes)
vibration_pos_16bit  equ $F021      ; Vibration position 16-bit (computed, 2 bytes)
bank_target_speed    equ $F023      ; Bank motor target speed
vibration_target_speed equ $F024    ; Vibration motor target speed
bank_speed_limit     equ $F025      ; Bank motor speed limit
vibration_speed_limit equ $F026     ; Vibration motor speed limit
bank_output_status   equ $F027      ; Bank motor output status byte
vibration_output_status equ $F028   ; Vibration motor output status byte
limit_switch_bits    equ $F029      ; Combined limit switch status bits
combined_output_byte equ $F02A      ; Combined output byte for PPI port B
bank_pos_snapshot_0  equ $F02B      ; Bank position snapshot (auto-center start CW)
bank_pos_snapshot_1  equ $F02C      ; Bank position snapshot (auto-center end CW)
bank_pos_snapshot_2  equ $F02D      ; Bank position snapshot (auto-center start CCW)
bank_pos_snapshot_3  equ $F02E      ; Bank position snapshot (auto-center end CCW)
vib_pos_snapshot_0   equ $F02F      ; Vibration position snapshot (start CW)
vib_pos_snapshot_1   equ $F030      ; Vibration position snapshot (end CW)
vib_pos_snapshot_2   equ $F031      ; Vibration position snapshot (start CCW)
vib_pos_snapshot_3   equ $F032      ; Vibration position snapshot (end CCW)
bank_profile_ptr     equ $F033      ; Bank motion profile table pointer (2 bytes)
vibration_profile_ptr equ $F035     ; Vibration motion profile table pointer (2 bytes)
motion_phase_count   equ $F037      ; Motion sequence phase count
motion_bank_dir      equ $F038      ; Motion sequence bank direction
motion_target_speed  equ $F039      ; Motion sequence target speed
motion_accel_dur     equ $F03A      ; Motion sequence accel duration
motion_hold_dur      equ $F03B      ; Motion sequence hold duration

; --- Configuration Parameters ($F100-$F1FF, copied from ROM) ---
pos_calc_divisor     equ $F100      ; Position calculation divisor
pos_calc_work        equ $F101      ; Position calculation work byte
pos_calc_adc_input   equ $F110      ; Position calculation ADC input
pos_calc_result      equ $F120      ; Position calculation 16-bit result
bank_limit_fwd       equ $F130      ; Bank forward limit threshold
bank_limit_rev       equ $F131      ; Bank reverse limit threshold
vibration_limit_fwd  equ $F132      ; Vibration forward limit threshold
vibration_limit_rev  equ $F133      ; Vibration reverse limit threshold
bank_profile_thresh_0 equ $F134     ; Bank profile distance threshold 0 (16-bit)
bank_profile_thresh_1 equ $F136     ; Bank profile distance threshold 1 (16-bit)
bank_profile_thresh_2 equ $F138     ; Bank profile distance threshold 2 (16-bit)
bank_profile_thresh_3 equ $F13A     ; Bank profile distance threshold 3 (16-bit)
vib_profile_thresh_0 equ $F13C      ; Vibration profile distance threshold 0 (16-bit)
vib_profile_thresh_1 equ $F13E      ; Vibration profile distance threshold 1 (16-bit)
vib_profile_thresh_2 equ $F140      ; Vibration profile distance threshold 2 (16-bit)
vib_profile_thresh_3 equ $F142      ; Vibration profile distance threshold 3 (16-bit)
autocenter_bank_fwd_err equ $F144   ; Auto-center bank forward error threshold
autocenter_bank_rev_err equ $F145   ; Auto-center bank reverse error threshold
autocenter_vib_err_fwd equ $F146    ; Auto-center vibration error threshold fwd
autocenter_vib_range_lo equ $F148   ; Auto-center vibration range low (2 bytes)
autocenter_vib_range_hi equ $F14A   ; Auto-center vibration range high (2 bytes)
autocenter_bank_dist equ $F14C      ; Auto-center bank distance threshold (16-bit)
autocenter_vib_dist  equ $F14E      ; Auto-center vibration distance threshold (16-bit)
autocenter_vib_stop  equ $F150      ; Auto-center vibration stop threshold
bank_deadzone_lo     equ $F151      ; Bank position dead zone low bound
bank_deadzone_hi     equ $F152      ; Bank position dead zone high bound

; --- State Machine Flags ($F200-$F2FF) ---
bank_motion_state    equ $F200      ; Bank motor state (0-6)
vibration_motion_state equ $F201    ; Vibration motor state (0-6)
bank_sm_phase_a      equ $F203      ; Bank state machine phase A flag
bank_sm_init_flag    equ $F204      ; Bank state machine init flag
bank_sm_profile_flag equ $F205      ; Bank state machine profile loaded flag
bank_sm_decel_flag   equ $F206      ; Bank state machine decel phase flag
bank_sm_accel_flag_b equ $F207      ; Bank state machine accel flag B
bank_sm_decel_flag_b equ $F208      ; Bank state machine decel flag B
vib_sm_phase_a       equ $F20A      ; Vibration state machine phase A flag
vib_sm_init_flag     equ $F20B      ; Vibration state machine init flag
vib_sm_profile_flag  equ $F20C      ; Vibration state machine profile loaded flag
vib_sm_decel_flag    equ $F20D      ; Vibration state machine decel phase flag
vib_sm_accel_flag_b  equ $F20E      ; Vibration state machine accel flag B
vib_sm_decel_flag_b  equ $F20F      ; Vibration state machine decel flag B
bank_early_motion    equ $F210      ; Bank early motion phase flag (vibration)
bank_early_motion_b  equ $F211      ; Bank early motion phase flag B (bank)
bank_overcurrent     equ $F212      ; Bank motor overcurrent/stall detected
vibration_overcurrent equ $F214     ; Vibration motor overcurrent/stall detected
limit_sw_triggered   equ $F216      ; Any limit switch triggered flag
interrupt_occurred   equ $F217      ; Interrupt occurred flag (set by ISR)
bank_early_latch     equ $F218      ; Bank early motion latched flag
vibration_early_latch equ $F219     ; Vibration early motion latched flag
bank_cw_limit_active equ $F21A      ; Bank CW limit switch active (debounced)
bank_ccw_limit_active equ $F21B     ; Bank CCW limit switch active (debounced)
vib_cw_limit_active  equ $F21C      ; Vibration CW limit switch active (debounced)
vib_ccw_limit_active equ $F21D      ; Vibration CCW limit switch active (debounced)
safety_stop_flag     equ $F21E      ; Safety stop engaged flag
return_to_home_flag  equ $F21F      ; Return-to-home requested flag
autocenter_active    equ $F220      ; Auto-center mode active flag
autocenter_phase_1   equ $F221      ; Auto-center phase 1 flag
autocenter_phase_2   equ $F222      ; Auto-center phase 2 flag
autocenter_phase_3   equ $F223      ; Auto-center phase 3 flag
autocenter_phase_4   equ $F224      ; Auto-center phase 4 flag
autocenter_phase_5   equ $F225      ; Auto-center phase 5 flag
autocenter_phase_6   equ $F226      ; Auto-center phase 6 flag
autocenter_phase_7   equ $F227      ; Auto-center phase 7 flag
autocenter_phase_8   equ $F228      ; Auto-center phase 8 flag
autocenter_phase_9   equ $F229      ; Auto-center phase 9 flag
autocenter_phase_10  equ $F22A      ; Auto-center phase 10 flag
autocenter_phase_11  equ $F22B      ; Auto-center phase 11 flag
autocenter_phase_12  equ $F22C      ; Auto-center phase 12 flag
error_detected       equ $F22D      ; Error/fault detected flag
watchdog_timer_flag  equ $F22E      ; Watchdog needs petting flag
motion_seq_active    equ $F22F      ; Motion sequence active flag
motion_seq_phase_0   equ $F230      ; Motion sequence phase 0 started
motion_seq_phase_1   equ $F231      ; Motion sequence phase 1 started
motion_seq_phase_2   equ $F232      ; Motion sequence phase 2 started

; --- Counters and Timers ($F300-$F31F) ---
bank_accel_index     equ $F300      ; Bank acceleration curve index
bank_decel_index     equ $F301      ; Bank deceleration curve index
bank_accel_index_b   equ $F302      ; Bank acceleration curve index (CCW)
bank_decel_index_b   equ $F303      ; Bank deceleration curve index (CCW)
vib_accel_index      equ $F304      ; Vibration acceleration curve index
vib_decel_index      equ $F305      ; Vibration deceleration curve index
vib_accel_index_b    equ $F306      ; Vibration acceleration curve index (CCW)
vib_decel_index_b    equ $F307      ; Vibration deceleration curve index (CCW)
isr_tick_counter     equ $F308      ; ISR tick counter (counts to 10)
bank_stall_counter   equ $F309      ; Bank motor stall detection counter
vib_stall_counter    equ $F30A      ; Vibration motor stall detection counter
bank_timeout_16bit   equ $F30B      ; Bank motor timeout counter (16-bit)
vib_timeout_16bit    equ $F30D      ; Vibration motor timeout counter (16-bit)
bank_overflow_16bit  equ $F30F      ; Bank motor overflow counter (16-bit)
vib_overflow_16bit   equ $F311      ; Vibration motor overflow counter (16-bit)
autocenter_timer     equ $F313      ; Auto-center elapsed timer (16-bit)
bank_speed_overflow  equ $F315      ; Bank speed overflow counter (16-bit)
vib_speed_overflow   equ $F317      ; Vibration speed overflow counter (16-bit)
motion_phase_timer   equ $F319      ; Motion sequence phase timer
motion_hold_timer    equ $F31A      ; Motion sequence hold timer

; --- Motion Profile Data ($F400-$F7FF, copied from ROM at init) ---
; Bank motor profiles:
;   $F400-$F407  Bank speed ramp initial values (4 pairs)
;   $F410-$F413  Bank motor speed limits (per direction)
;   $F420-$F445  Bank acceleration curve (38 bytes)
;   $F450-$F46F  Bank motion profile tier 1 (32 bytes)
;   $F480-$F499  Bank motion profile tier 2 (26 bytes)
;   $F4B0-$F4C6  Bank motion profile tier 3 (23 bytes)
;   $F4D0-$F4E1  Bank motion profile tier 4 (18 bytes)
;   $F4F0-$F4FE  Bank motion profile tier 5 (15 bytes)
;   $F510-$F58F  Bank position-to-speed lookup (128 bytes)
; Vibration motor profiles:
;   $F600-$F607  Vibration speed ramp initial values (4 pairs)
;   $F610-$F613  Vibration motor speed limits (per direction)
;   $F620-$F649  Vibration acceleration curve (42 bytes)
;   $F650-$F677  Vibration motion profile tier 1 (40 bytes)
;   $F680-$F69D  Vibration motion profile tier 2 (30 bytes)
;   $F6B0-$F6CA  Vibration motion profile tier 3 (27 bytes)
;   $F6D0-$F6E7  Vibration motion profile tier 4 (24 bytes)
;   $F6F0-$F706  Vibration motion profile tier 5 (23 bytes)
;   $F710-$F78F  Vibration position-to-speed lookup (128 bytes)
;

; ============================================================================
; Motor Direction Encoding (PPI Port A bits 0-3)
; ============================================================================
; Bank motor:    bit 0 = forward, bit 1 = reverse
;   Stop:   0,0  (both off)
;   CW:     1,0  (forward on, reverse off)
;   CCW:    0,1  (forward off, reverse on)
; Vibration motor: bit 2 = forward, bit 3 = reverse
;   Stop:   0,0
;   CW:     1,0
;   CCW:    0,1
;   Brake:  1,1  (both on = dynamic braking)
;

; ============================================================================
; RESET VECTOR
; ============================================================================
    org $0000

reset:
    di                              ; Disable interrupts
    im  1                           ; Set interrupt mode 1 (RST 38h)
    ld  sp, $FFFF                   ; Initialize stack pointer
    jp  main_init                   ; Jump to main initialization

; --- Unused interrupt vector space ($0009-$0037) ---
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; $0009-$000F
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0010-$0017
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0018-$001F
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0020-$0027
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0028-$002F
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0030-$0037

; ============================================================================
; RST 38h / IM1 INTERRUPT VECTOR
; ============================================================================
    org $0038

rst38_vector:
    jp  isr_handler                 ; Jump to interrupt service routine

; --- Unused space ($003B-$0065) ---
    .db $FF, $FF, $FF, $FF, $FF    ; $003B-$003F
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0040-$0047
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0048-$004F
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0050-$0057
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $0058-$005F
    .db $FF, $FF, $FF, $FF, $FF, $FF             ; $0060-$0065

; ============================================================================
; NMI HANDLER ($0066)
; ============================================================================
; Non-maskable interrupt handler. This is an emergency stop handler that:
; 1. Resets all timers to safe values (motors off/minimal PWM)
; 2. Re-initializes the PPI
; 3. Forces all motor outputs off
; 4. Performs a warm restart via RST $00
; ============================================================================
    org $0066

nmi_handler:
    ; --- Reset Timer 0 (bank motor) ---
    ld  a, TIMER_CNT0_MODE2_LSB    ; Counter 0: mode 2, LSB only
    ld  (TIMER0_CTRL), a
    ld  a, $01                      ; Count = 1 (minimal/stopped)
    ld  (TIMER0_CNT0), a
    ld  a, TIMER_CNT1_MODE5_LSB    ; Counter 1: mode 5, LSB only
    ld  (TIMER0_CTRL), a
    ld  a, $01                      ; Count = 1 (stopped)
    ld  (TIMER0_CNT1), a
    ld  a, TIMER_CNT2_MODE2_LSB    ; Counter 2: mode 2, LSB only
    ld  (TIMER0_CTRL), a
    ld  a, $20                      ; Count = 32 (clock divider)
    ld  (TIMER0_CNT2), a

    ; --- Reset Timer 1 (vibration motor) ---
    ld  a, TIMER_CNT0_MODE2_LSB    ; Counter 0: mode 2, LSB only
    ld  (TIMER1_CTRL), a
    ld  a, $80                      ; Count = 128
    ld  (TIMER1_CNT0), a
    ld  a, TIMER_CNT1_MODE5_LSB    ; Counter 1: mode 5, LSB only
    ld  (TIMER1_CTRL), a
    ld  a, $01                      ; Count = 1 (stopped)
    ld  (TIMER1_CNT1), a
    ld  a, TIMER_CNT2_MODE2_LSB    ; Counter 2: mode 2, LSB only
    ld  (TIMER1_CTRL), a
    ld  a, $20                      ; Count = 32 (clock divider)
    ld  (TIMER1_CNT2), a

    ; --- Re-initialize PPI and kill motor outputs ---
    ld  a, PPI_MODE0_A_OUT_B_OUT_CU_IN_CL_OUT
    ld  (PPI_CONTROL), a
    ld  a, $00
    ld  (PPI_PORT_A), a             ; All motor direction bits off
    rst $00                          ; Warm restart
    retn                             ; (never reached)

; --- Unused space ($00AF-$00FF) ---
    .db $FF                          ; $00AF
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00B0-$00B7
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00B8-$00BF
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00C0-$00C7
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00C8-$00CF
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00D0-$00D7
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00D8-$00DF
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00E0-$00E7
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00E8-$00EF
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00F0-$00F7
    .db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF  ; $00F8-$00FF

; ============================================================================
; MAIN INITIALIZATION ($0100)
; ============================================================================
; Called once at power-on after reset vector. Initializes all hardware,
; clears RAM, sets up motor parameters, selects motor type from DIP switch,
; copies appropriate profile data from ROM to RAM, then enters main loop.
; ============================================================================
    org $0100

main_init:
    ; --- Initialize PPI ---
    ld  a, PPI_MODE0_A_OUT_B_OUT_CU_IN_CL_OUT
    ld  (PPI_CONTROL), a
    ld  a, $00
    ld  (PPI_PORT_A), a             ; All motor outputs off

    ; --- Initialize Timer 0 (bank motor) ---
    ld  a, TIMER_CNT0_MODE2_LSB
    ld  (TIMER0_CTRL), a
    ld  a, $01
    ld  (TIMER0_CNT0), a            ; Counter 0 = 1
    ld  a, TIMER_CNT1_MODE5_LSB
    ld  (TIMER0_CTRL), a
    ld  a, $01
    ld  (TIMER0_CNT1), a            ; Counter 1 = 1 (stopped)
    ld  a, TIMER_CNT2_MODE2_LSB
    ld  (TIMER0_CTRL), a
    ld  a, $20
    ld  (TIMER0_CNT2), a            ; Counter 2 = 32 (divider)

    ; --- Initialize Timer 1 (vibration motor) ---
    ld  a, TIMER_CNT0_MODE2_LSB
    ld  (TIMER1_CTRL), a
    ld  a, $80
    ld  (TIMER1_CNT0), a            ; Counter 0 = 128
    ld  a, TIMER_CNT1_MODE5_LSB
    ld  (TIMER1_CTRL), a
    ld  a, $01
    ld  (TIMER1_CNT1), a            ; Counter 1 = 1 (stopped)
    ld  a, TIMER_CNT2_MODE2_LSB
    ld  (TIMER1_CTRL), a
    ld  a, $20
    ld  (TIMER1_CNT2), a            ; Counter 2 = 32 (divider)

    ; --- Read and mask PPI port A (clear mux bits) ---
    ld  a, (PPI_PORT_A)
    res 4, a                         ; Clear ADC mux select
    res 5, a                         ; Clear unused bit 5
    res 6, a                         ; Clear unused bit 6
    nop                              ; Delay for hardware settling

    ; --- Clear control register ---
    ld  a, $00
    ld  (CONTROL_REG), a
    ld  (WATCHDOG), a               ; Pet watchdog

    ; --- Clear RAM $F000-$F1FF ---
    ld  hl, $F000
    ld  de, $F001
    ld  bc, $01FF
    ld  (hl), $00
    ldir
    ld  (WATCHDOG), a               ; Pet watchdog

    ; --- Clear RAM $F200-$F3FF ---
    ld  hl, $F200
    ld  de, $F201
    ld  bc, $01FF
    ld  (hl), $00
    ldir
    ld  (WATCHDOG), a               ; Pet watchdog

    ; --- Clear RAM $F400-$F5FF ---
    ld  hl, $F400
    ld  de, $F401
    ld  bc, $01FF
    ld  (hl), $00
    ldir
    ld  (WATCHDOG), a               ; Pet watchdog

    ; --- Clear RAM $F600-$F7FF ---
    ld  hl, $F600
    ld  de, $F601
    ld  bc, $01FF
    ld  (hl), $00
    ldir
    ld  (WATCHDOG), a               ; Pet watchdog

    ; --- Initialize main board communication ---
    ld  a, $00
    ld  (MAIN_BOARD_CTRL), a        ; Reset comm controller
    ld  a, $2F
    ld  (MAIN_BOARD_CTRL), a        ; Set mode
    ld  a, $D0
    ld  (MAIN_BOARD_CTRL), a        ; Configure
    ld  a, $A0
    ld  (MAIN_BOARD_CTRL), a        ; Enable

    ; --- Initialize motor parameters ---
    ld  a, $30
    ld  (bank_accel_thresh), a       ; Bank accel threshold = $30
    ld  a, $02
    ld  (bank_speed_step), a         ; Bank speed step = 2
    ld  a, (ADC_BANK)               ; Trigger initial ADC conversion (bank)
    ld  a, $30
    ld  (vibration_accel_thresh), a  ; Vibration accel threshold = $30
    ld  a, $02
    ld  (vibration_speed_step), a    ; Vibration speed step = 2
    ld  a, (ADC_VIBRATION)           ; Trigger initial ADC conversion (vibration)
    ld  a, $01
    ld  (bank_motor_speed), a        ; Bank motor initial speed = 1
    ld  (vibration_motor_speed), a   ; Vibration motor initial speed = 1
    call bank_motor_stop             ; Ensure bank motor stopped
    call vibration_motor_brake       ; Ensure vibration motor braked

; ============================================================================
; DIP SWITCH READ AND MOTOR TYPE SELECT ($01D4)
; ============================================================================
; Reads the main board input port twice to ensure a stable reading,
; then checks DIP switch bit 0 to select motor type profile data.
; ============================================================================

read_dip_switch:
    ld  a, (MAIN_BOARD_INPUT)        ; Read main board input
    ld  b, a                         ; Save for comparison
    nop                              ; Delay
    nop
    ld  (WATCHDOG), a               ; Pet watchdog
    nop                              ; Delay
    nop
    or  a                            ; (set flags)
    ld  a, (MAIN_BOARD_INPUT)        ; Read again
    cp  b                            ; Same as first read?
    jp  nz, read_dip_switch          ; Retry if unstable

    bit 0, a                         ; Test DIP switch motor type
    jp  nz, load_motor_type_b        ; Jump if motor type 350-5134

; ============================================================================
; LOAD MOTOR TYPE A (350-5133) PROFILE DATA
; ============================================================================
; DIP all OFF: Copy motor type A profile tables from ROM to RAM.
; ============================================================================

load_motor_type_a:
    ; Configuration parameters: $1B59 -> $F130 (35 bytes)
    ld  de, $F130
    ld  hl, config_params_type_a
    ld  bc, $0023
    ldir
    ld  (WATCHDOG), a

    ; Bank speed ramp: $1678 -> $F400 (8 bytes)
    ld  de, $F400
    ld  hl, bank_speed_ramp_a
    ld  bc, $0008
    ldir
    ld  (WATCHDOG), a

    ; Bank motor limits: $1680 -> $F410 (4 bytes)
    ld  de, $F410
    ld  hl, bank_motor_limits_a
    ld  bc, $0004
    ldir
    ld  (WATCHDOG), a

    ; Bank accel curve: $1684 -> $F420 (38 bytes)
    ld  de, $F420
    ld  hl, bank_accel_curve_a
    ld  bc, $0026
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 1: $16AA -> $F450 (32 bytes)
    ld  de, $F450
    ld  hl, bank_profile_tier1_a
    ld  bc, $0020
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 2: $16CA -> $F480 (26 bytes)
    ld  de, $F480
    ld  hl, bank_profile_tier2_a
    ld  bc, $001A
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 3: $16E4 -> $F4B0 (23 bytes)
    ld  de, $F4B0
    ld  hl, bank_profile_tier3_a
    ld  bc, $0017
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 4: $16FB -> $F4D0 (18 bytes)
    ld  de, $F4D0
    ld  hl, bank_profile_tier4_a
    ld  bc, $0012
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 5: $170D -> $F4F0 (15 bytes)
    ld  de, $F4F0
    ld  hl, bank_profile_tier5_a
    ld  bc, $000F
    ldir
    ld  (WATCHDOG), a

    ; Bank position-to-speed lookup: $171C -> $F510 (128 bytes)
    ld  de, $F510
    ld  hl, bank_pos_speed_lut_a
    ld  bc, $0080
    ldir
    ld  (WATCHDOG), a

    ; Vibration speed ramp: $179C -> $F600 (8 bytes)
    ld  de, $F600
    ld  hl, vib_speed_ramp_a
    ld  bc, $0008
    ldir
    ld  (WATCHDOG), a

    ; Vibration motor limits: $17A4 -> $F610 (4 bytes)
    ld  de, $F610
    ld  hl, vib_motor_limits_a
    ld  bc, $0004
    ldir
    ld  (WATCHDOG), a

    ; Vibration accel curve: $17A8 -> $F620 (42 bytes)
    ld  de, $F620
    ld  hl, vib_accel_curve_a
    ld  bc, $002A
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 1: $17D2 -> $F650 (40 bytes)
    ld  de, $F650
    ld  hl, vib_profile_tier1_a
    ld  bc, $0028
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 2: $17FA -> $F680 (30 bytes)
    ld  de, $F680
    ld  hl, vib_profile_tier2_a
    ld  bc, $001E
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 3: $1818 -> $F6B0 (27 bytes)
    ld  de, $F6B0
    ld  hl, vib_profile_tier3_a
    ld  bc, $001B
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 4: $1833 -> $F6D0 (24 bytes)
    ld  de, $F6D0
    ld  hl, vib_profile_tier4_a
    ld  bc, $0018
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 5: $184B -> $F6F0 (23 bytes)
    ld  de, $F6F0
    ld  hl, vib_profile_tier5_a
    ld  bc, $0017
    ldir
    ld  (WATCHDOG), a

    ; Vibration position-to-speed lookup: $1862 -> $F710 (128 bytes)
    ld  de, $F710
    ld  hl, vib_pos_speed_lut_a
    ld  bc, $0080
    ldir

    jp  main_loop                    ; Enter main loop

; ============================================================================
; LOAD MOTOR TYPE B (350-5134) PROFILE DATA ($02F6)
; ============================================================================
; DIP bit 0 ON: Copy motor type B profile tables from ROM to RAM.
; Same structure as type A but different ROM source addresses.
; ============================================================================

load_motor_type_b:
    ; Configuration parameters: $1B7C -> $F130 (35 bytes)
    ld  de, $F130
    ld  hl, config_params_type_b
    ld  bc, $0023
    ldir
    ld  (WATCHDOG), a

    ; Bank speed ramp: $18E2 -> $F400 (8 bytes)
    ld  de, $F400
    ld  hl, bank_speed_ramp_b
    ld  bc, $0008
    ldir
    ld  (WATCHDOG), a

    ; Bank motor limits: $18EA -> $F410 (4 bytes)
    ld  de, $F410
    ld  hl, bank_motor_limits_b
    ld  bc, $0004
    ldir
    ld  (WATCHDOG), a

    ; Bank accel curve: $18EE -> $F420 (39 bytes)
    ld  de, $F420
    ld  hl, bank_accel_curve_b
    ld  bc, $0027
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 1: $1915 -> $F450 (32 bytes)
    ld  de, $F450
    ld  hl, bank_profile_tier1_b
    ld  bc, $0020
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 2: $1935 -> $F480 (26 bytes)
    ld  de, $F480
    ld  hl, bank_profile_tier2_b
    ld  bc, $001A
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 3: $194F -> $F4B0 (23 bytes)
    ld  de, $F4B0
    ld  hl, bank_profile_tier3_b
    ld  bc, $0017
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 4: $1966 -> $F4D0 (18 bytes)
    ld  de, $F4D0
    ld  hl, bank_profile_tier4_b
    ld  bc, $0012
    ldir
    ld  (WATCHDOG), a

    ; Bank motion profile tier 5: $1978 -> $F4F0 (15 bytes)
    ld  de, $F4F0
    ld  hl, bank_profile_tier5_b
    ld  bc, $000F
    ldir
    ld  (WATCHDOG), a

    ; Bank position-to-speed lookup: $1987 -> $F510 (128 bytes)
    ld  de, $F510
    ld  hl, bank_pos_speed_lut_b
    ld  bc, $0080
    ldir
    ld  (WATCHDOG), a

    ; Vibration speed ramp: $1A07 -> $F600 (8 bytes)
    ld  de, $F600
    ld  hl, vib_speed_ramp_b
    ld  bc, $0008
    ldir
    ld  (WATCHDOG), a

    ; Vibration motor limits: $1A0F -> $F610 (4 bytes)
    ld  de, $F610
    ld  hl, vib_motor_limits_b
    ld  bc, $0004
    ldir
    ld  (WATCHDOG), a

    ; Vibration accel curve: $1A13 -> $F620 (42 bytes)
    ld  de, $F620
    ld  hl, vib_accel_curve_b
    ld  bc, $002A
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 1: $1A3D -> $F650 (40 bytes)
    ld  de, $F650
    ld  hl, vib_profile_tier1_b
    ld  bc, $0028
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 2: $1A65 -> $F680 (30 bytes)
    ld  de, $F680
    ld  hl, vib_profile_tier2_b
    ld  bc, $001E
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 3: $1A83 -> $F6B0 (27 bytes)
    ld  de, $F6B0
    ld  hl, vib_profile_tier3_b
    ld  bc, $001B
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 4: $1A9E -> $F6D0 (24 bytes)
    ld  de, $F6D0
    ld  hl, vib_profile_tier4_b
    ld  bc, $0018
    ldir
    ld  (WATCHDOG), a

    ; Vibration motion profile tier 5: $1AB6 -> $F6F0 (23 bytes)
    ld  de, $F6F0
    ld  hl, vib_profile_tier5_b
    ld  bc, $0017
    ldir
    ld  (WATCHDOG), a

    ; Vibration position-to-speed lookup: $1ACD -> $F710 (128 bytes)
    ld  de, $F710
    ld  hl, vib_pos_speed_lut_b
    ld  bc, $0080
    ldir

    jp  main_loop                    ; Enter main loop

; ============================================================================
; MAIN LOOP ($0400)
; ============================================================================
; The main program loop. Waits for the ISR to set interrupt_occurred,
; then processes commands, updates motor states, and handles all
; motion control state machines.
; ============================================================================
    org $0400

main_loop:
    ei                               ; Enable interrupts
    ld  a, (interrupt_occurred)      ; Check if ISR has fired
    or  a
    jp  z, main_loop                 ; Spin until interrupt occurs

    xor a
    ld  (interrupt_occurred), a      ; Clear interrupt flag

    ; --- Pet watchdog if needed ---
    ld  a, (watchdog_timer_flag)
    or  a
    jp  z, .skip_watchdog
    ld  (WATCHDOG), a               ; Pet watchdog
    xor a
    ld  (watchdog_timer_flag), a
.skip_watchdog:

    ; --- Check for error/fault condition ---
    ld  a, (error_detected)
    or  a
    jp  nz, handle_error             ; Jump to error handler if fault

    ; --- Check if return-to-home is active ---
    ld  a, (return_to_home_flag)
    or  a
    jp  z, .check_autocenter

    call write_ppi_port_b_c0         ; Signal homing in progress
    ld  a, (main_board_command)
    cp  $FF                          ; $FF = clear home request
    jp  nz, output_motor_status      ; Otherwise continue homing

    call write_ppi_port_b_00         ; Clear status
    xor a
    ld  (return_to_home_flag), a     ; Clear home request
    ld  (autocenter_active), a       ; Clear auto-center
    jp  output_motor_status

.check_autocenter:
    ; --- Check if auto-center is active ---
    ld  a, (autocenter_active)
    or  a
    jp  nz, autocenter_state_machine ; Jump to auto-center handler

    ; --- Check safety stop ---
    ld  a, (safety_stop_flag)
    or  a
    jp  nz, handle_safety_stop

    ; --- Check if motion sequence is running ---
    ld  a, (motion_seq_active)
    or  a
    jp  nz, motion_sequence_process  ; Jump to motion sequence handler

    ; --- Parse main board command ---
    ld  a, (main_board_command)
    bit 7, a                         ; Bit 7 = command valid flag
    jp  z, normal_position_update    ; No command: do normal tracking

; ============================================================================
; COMMAND DECODER ($045D)
; ============================================================================
; Decodes the command code and dispatches to the appropriate handler.
; ============================================================================

decode_command:
    ld  a, (cmd_code)
    or  a

    cp  $F0                          ; $F0 = auto-center command
    jp  z, cmd_autocenter

    ; Commands $90-$95: motion sequences
    cp  $90
    jp  z, cmd_motion_sequence
    cp  $91
    jp  z, cmd_motion_sequence
    cp  $92
    jp  z, cmd_motion_sequence
    cp  $93
    jp  z, cmd_motion_sequence
    cp  $94
    jp  z, cmd_motion_sequence
    cp  $95
    jp  z, cmd_motion_sequence

    ; Commands $A0-$A3: direct motor test
    cp  $A0                          ; Bank motor CW
    jp  z, cmd_bank_motor_cw
    cp  $A1                          ; Bank motor CCW
    jp  z, cmd_bank_motor_ccw
    cp  $A2                          ; Vibration motor CW
    jp  z, cmd_vibration_motor_cw
    cp  $A3                          ; Vibration motor CCW
    jp  z, cmd_vibration_motor_ccw

    ; Command $B0: all motors stop
    cp  $B0
    jp  z, cmd_all_motors_stop

    ; Unknown command: stop motors as safety measure
    jp  cmd_unknown_stop

; ============================================================================
; MOTION SEQUENCE SETUP ($04A0)
; ============================================================================
; Sets up a motion sequence based on command codes $90-$95.
; $90-$92: short sequences (3 phases, CW direction)
; $93-$95: long sequences (6 phases, CCW direction)
; Sequence parameters are loaded from ROM tables.
; ============================================================================

cmd_motion_sequence:
    ld  a, (cmd_code)
    ld  b, a
    or  a
    cp  $93
    jp  nc, .long_sequence

    ; Short sequence ($90-$92): 3 phases, CW direction
    ld  a, $90
    ld  c, a
    ld  a, b
    sub c                            ; Index = cmd - $90
    ld  c, a
    ld  a, $03
    ld  (motion_phase_count), a      ; 3 phases
    ld  a, $01
    ld  (motion_bank_dir), a         ; CW direction
    jp  .load_sequence_params

.long_sequence:
    ; Long sequence ($93-$95): 6 phases, CCW direction
    ld  a, $93
    ld  c, a
    ld  a, b
    sub c                            ; Index = cmd - $93
    ld  c, a
    ld  a, $06
    ld  (motion_phase_count), a      ; 6 phases
    ld  a, $02
    ld  (motion_bank_dir), a         ; CCW direction

.load_sequence_params:
    ; Look up target speed from table
    ld  hl, motion_speed_table
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (motion_target_speed), a

    ; Look up acceleration duration
    ld  hl, motion_accel_table
    add hl, bc
    ld  a, (hl)
    ld  (motion_accel_dur), a

    ; Look up hold duration
    ld  hl, motion_hold_table
    add hl, bc
    ld  a, (hl)
    ld  (motion_hold_dur), a

    ; Activate motion sequence
    ld  a, $FF
    ld  (motion_seq_active), a       ; Set active flag

    ; Clear phase state
    xor a
    ld  (motion_phase_timer), a
    ld  (motion_seq_phase_0), a
    ld  (motion_seq_phase_1), a
    ld  (motion_seq_phase_2), a
    jp  motion_sequence_process

; ============================================================================
; MOTION SEQUENCE PROCESSOR ($04FC)
; ============================================================================
; Three-phase motion sequence: accel -> hold -> decel
; Phase 0: Acceleration (wait for accel_duration ticks)
; Phase 1: Hold at speed (wait for hold_duration ticks)
; Phase 2: Deceleration (stop motors)
; ============================================================================

motion_sequence_process:
    ; --- Phase 0: Check if acceleration phase started ---
    ld  a, (motion_seq_phase_0)
    or  a
    jp  nz, .phase_0_started

    ; Still in accel wait phase
    ld  a, (motion_phase_timer)
    ld  b, a
    ld  a, (motion_accel_dur)
    sub b
    jp  c, .phase_0_started          ; Timer exceeded? Start phase 0

    ; Still accelerating: stop bank motor direction, clear state
    xor a
    ld  (bank_motor_dir), a
    ld  (bank_motion_state), a
    jp  .motion_seq_update

.phase_0_started:
    ld  a, $FF
    ld  (motion_seq_phase_0), a      ; Mark phase 0 started

    ; --- Phase 1: Check hold phase ---
    ld  a, (motion_seq_phase_2)
    or  a
    jp  nz, .phase_2_started         ; Already in decel?

    ld  a, (motion_seq_phase_1)
    or  a
    jp  nz, .phase_1_running

    ; Initialize hold phase timer
    xor a
    ld  (motion_hold_timer), a
    ld  a, $FF
    ld  (motion_seq_phase_1), a

.phase_1_running:
    ld  a, (motion_hold_timer)
    ld  b, a
    ld  a, (motion_hold_dur)
    sub b
    jp  c, .phase_2_started          ; Hold time exceeded? Start decel

    ; Hold phase: set direction and speed
    ld  a, (motion_bank_dir)
    ld  (bank_motor_dir), a
    ld  a, (motion_phase_count)
    ld  (bank_motion_state), a
    ld  a, (motion_target_speed)
    ld  (bank_speed_limit), a
    jp  .motion_seq_update

.phase_2_started:
    ; Deceleration: stop motors, end sequence
    ld  a, $FF
    ld  (motion_seq_phase_2), a
    xor a
    ld  (bank_motor_dir), a
    ld  (motion_seq_active), a       ; Clear active flag
    jp  .motion_seq_update

; --- Update motor state after sequence phase ---
.motion_seq_update:
    ld  hl, $0000
    ld  (bank_overflow_16bit), hl    ; Clear overflow counters
    ld  (bank_timeout_16bit), hl
    ld  (bank_speed_overflow), hl
    ld  (vib_overflow_16bit), hl
    ld  (vib_timeout_16bit), hl
    ld  (vib_speed_overflow), hl

    call check_bank_safety_limits
    call check_vibration_safety_limits
    call read_limit_switches_bank
    call compute_output_status_byte
    jp  output_motor_status

; ============================================================================
; AUTO-CENTER COMMAND HANDLER ($0587)
; ============================================================================
; Initiates the auto-center (return to neutral) sequence.
; Clears all auto-center phase flags and begins the state machine.
; ============================================================================

cmd_autocenter:
    ld  a, $FF
    ld  (autocenter_active), a       ; Enable auto-center mode

    ; Clear all auto-center phase flags
    xor a
    ld  (autocenter_phase_1), a
    ld  (autocenter_phase_2), a
    ld  (autocenter_phase_3), a
    ld  (autocenter_phase_4), a
    ld  (autocenter_phase_5), a
    ld  (autocenter_phase_6), a
    ld  (autocenter_phase_7), a
    ld  (autocenter_phase_8), a
    ld  (autocenter_phase_9), a
    ld  (autocenter_phase_10), a
    ld  (autocenter_phase_11), a
    ld  (autocenter_phase_12), a
    ld  (return_to_home_flag), a
    ld  (safety_stop_flag), a

    ; Clear timeout counters
    ld  hl, $0000
    ld  (bank_timeout_16bit), hl
    ld  (vib_timeout_16bit), hl
    ld  (autocenter_timer), hl

    jp  autocenter_state_machine     ; Enter state machine

; ============================================================================
; ERROR HANDLER ($05C6)
; ============================================================================
; Stops all motors when an error/fault is detected.
; ============================================================================

handle_error:
    xor a
    ld  (bank_motor_dir), a          ; Stop bank motor
    ld  (vibration_motor_dir), a     ; Stop vibration motor
    call bank_motor_stop
    call vibration_motor_brake
    jp  main_loop                    ; Return to main loop

; ============================================================================
; SAFETY STOP HANDLER ($05D6)
; ============================================================================
; Handles safety stop condition. Stops motors, but allows $F0 (autocenter)
; command to override.
; ============================================================================

handle_safety_stop:
    call bank_motor_stop
    call vibration_motor_brake
    ld  a, (main_board_command)
    cp  $F0                          ; Auto-center can override safety stop
    jp  z, cmd_autocenter
    jp  main_loop

; ============================================================================
; AUTO-CENTER STATE MACHINE ($05E7)
; ============================================================================
; Multi-phase auto-center sequence:
; Phase 1: Drive bank motor CW to find center
; Phase 2: Check if bank has reached center
; Phase 3: Drive bank motor CCW
; Phase 4: Check if bank CCW reached limit
; Phase 5: Start vibration CW
; Phase 6: Check vibration CW
; Phase 7: Drive vibration CCW
; Phase 8: Check vibration CCW
; Phase 9: Return vibration to center
; Phase 10: Check vibration centered
; Phase 11: Return bank to center using position lookup
; Phase 12: Final check, complete
; ============================================================================

autocenter_state_machine:
    ; --- Phase 2 check: has phase 2 started? ---
    ld  a, (autocenter_phase_2)
    or  a
    jp  nz, .ac_phase_4_check

    ; --- Phase 1: start bank CW drive ---
    ld  a, (autocenter_phase_1)
    or  a
    jp  nz, .ac_phase_1_running

    ; Initialize phase 1
    call write_ppi_port_b_40         ; Signal auto-center in progress
    ld  a, $FF
    ld  (autocenter_phase_1), a      ; Mark phase 1 started
    ld  a, $01
    ld  (bank_motor_dir), a          ; Bank motor CW
    xor a
    ld  (vibration_motor_dir), a     ; Vibration stopped
    ld  a, $C0
    ld  (bank_speed_limit), a        ; Speed limit = $C0
    ld  hl, $0000
    ld  (autocenter_timer), hl       ; Reset timer

.ac_phase_1_running:
    ; Check for errors during auto-center
    ld  a, (error_detected)
    or  a
    jp  nz, .ac_error

    ; Check if bank CW limit switch hit
    ld  a, (bank_ccw_limit_active)
    or  a
    jp  nz, .ac_phase_4_check       ; Skip to phase 4 if limit hit

    ; Check bank motion state = 3 (at speed)
    ld  a, (bank_motion_state)
    cp  $03
    jp  nz, .ac_update_motors

    ; Bank is at speed - check position for center crossing
    ld  a, (bank_pos_snapshot_0)
    ld  b, a
    ld  a, (bank_pos_snapshot_1)
    sub b
    jp  nc, .ac_check_position_diff  ; Position increased (normal)

    ; Position decreased - check overcurrent
    ld  a, (bank_overcurrent)
    or  a
    jp  nz, .ac_overcurrent_error

    ; Check auto-center timer for timeout
    ld  hl, (autocenter_timer)
    bit 6, h                         ; Bit 14 of timer = timeout (~16K ticks)
    jp  nz, .ac_timeout_error
    jp  .ac_update_motors

; --- Phase 4 check: vibration motor phases ---
.ac_phase_4_check:
    ld  a, (autocenter_phase_4)
    or  a
    jp  nz, .ac_phase_6_check

    ; Start phase 2: mark it, set bank CCW
    ld  a, $FF
    ld  (autocenter_phase_2), a

    ; Phase 3: check if started
    ld  a, (autocenter_phase_3)
    or  a
    jp  nz, .ac_phase_3_running

    ; Initialize phase 3: bank motor CCW
    ld  a, $FF
    ld  (autocenter_phase_3), a
    ld  a, $02
    ld  (bank_motor_dir), a          ; Bank motor CCW

    ; Check bank position is within valid range
    ld  a, ($F148)                   ; autocenter_vib_range_lo
    ld  b, a
    ld  a, ($F149)
    ld  c, a
    ld  a, (bank_position)
    cp  b
    jp  c, .ac_position_out_of_range
    cp  c
    jp  nc, .ac_position_out_of_range

.ac_phase_3_running:
    ld  a, (error_detected)
    or  a
    jp  nz, .ac_error_phase2

    ; Check if bank position crossed center ($80)
    ld  a, (bank_position)
    cp  $80
    jp  c, .ac_update_motors         ; Below center: keep going

    ; Check bank CW limit
    ld  a, (bank_cw_limit_active)
    or  a
    jp  nz, .ac_phase_6_check

    ; Check 16-bit position vs threshold
    or  a
    ld  de, (bank_pos_16bit)
    ld  hl, (autocenter_bank_dist)
    sbc hl, de
    jp  c, .ac_bank_distance_exceeded
    jp  .ac_update_motors

; --- Phase 6 check: vibration motor direction changes ---
.ac_phase_6_check:
    ld  a, (autocenter_phase_6)
    or  a
    jp  nz, .ac_phase_8_check

    ; Mark phase 4 started
    ld  a, $FF
    ld  (autocenter_phase_4), a

    ; Phase 5: start vibration motor CW
    ld  a, (autocenter_phase_5)
    or  a
    jp  nz, .ac_phase_5_running

    ; Initialize phase 5
    ld  a, $FF
    ld  (autocenter_phase_5), a
    ld  a, $01
    ld  (vibration_motor_dir), a     ; Vibration CW
    xor a
    ld  (bank_motor_dir), a          ; Bank stopped
    ld  a, $A0
    ld  (vibration_speed_limit), a   ; Speed limit = $A0

.ac_phase_5_running:
    ; Check for errors
    ld  a, (error_detected)
    or  a
    jp  nz, .ac_error_vib

    ; Check vibration CCW limit
    ld  a, (vib_ccw_limit_active)
    or  a
    jp  nz, .ac_phase_8_check

    ; Check vibration motion state = 3
    ld  a, (vibration_motion_state)
    cp  $03
    jp  nz, .ac_update_motors

    ; Check vibration position snapshots
    ld  a, (vib_pos_snapshot_0)
    ld  b, a
    ld  a, (vib_pos_snapshot_1)
    sub b
    jp  c, .ac_vib_check_overcurrent

    ; Check vibration overcurrent
    ld  a, (vibration_overcurrent)
    or  a
    jp  nz, .ac_vib_overcurrent_error
    jp  .ac_update_motors

; --- Phase 8 check ---
.ac_phase_8_check:
    ld  a, $FF
    ld  (autocenter_phase_6), a

    ; Phase 7 & 8: vibration reverse and return
    ld  a, (autocenter_phase_8)
    or  a
    jp  nz, .ac_phase_10_check

    ; Phase 7: vibration CCW
    ld  a, (autocenter_phase_7)
    or  a
    jp  nz, .ac_phase_7_running

    ; Initialize phase 7
    ld  a, $FF
    ld  (autocenter_phase_7), a
    ld  a, $02
    ld  (vibration_motor_dir), a     ; Vibration CCW

    ; Check vibration position range
    ld  a, ($F14A)                   ; vibration range check lo
    ld  b, a
    ld  a, ($F14B)                   ; vibration range check hi
    ld  c, a
    ld  a, (vibration_position)
    cp  b
    jp  c, .ac_vib_out_of_range
    cp  c
    jp  nc, .ac_vib_out_of_range

.ac_phase_7_running:
    ld  a, (error_detected)
    or  a
    jp  nz, .ac_error_vib2

    ; Check if vibration below center ($80)
    ld  a, (vibration_position)
    cp  $80
    jp  nc, .ac_update_motors        ; Above center: keep going

    ; Check vibration CW limit
    ld  a, (vib_cw_limit_active)
    or  a
    jp  nz, .ac_phase_10_check

    ; Check vibration 16-bit distance
    or  a
    ld  de, (vibration_pos_16bit)
    ld  hl, (autocenter_vib_dist)
    sbc hl, de
    jp  c, .ac_vib_dist_exceeded
    jp  .ac_update_motors

; --- Phase 10 check ---
.ac_phase_10_check:
    ld  a, $FF
    ld  (autocenter_phase_8), a

    ; Phase 9 & 10: return vibration to center
    ld  a, (autocenter_phase_10)
    or  a
    jp  nz, .ac_phase_12_check

    ; Phase 9: vibration CW (return)
    ld  a, (autocenter_phase_9)
    or  a
    jp  nz, .ac_phase_9_running

    ld  a, $FF
    ld  (autocenter_phase_9), a
    ld  a, $01
    ld  (vibration_motor_dir), a     ; Vibration CW (return)

.ac_phase_9_running:
    ; Check if vibration position reached $7A (near center)
    ld  a, (vibration_position)
    cp  $7A
    jp  c, .ac_update_motors         ; Not yet at center

    ; At center, stop vibration
    xor a
    ld  (vibration_motor_dir), a

    ; Check for overcurrent
    ld  a, (vibration_overcurrent)
    or  a
    jp  z, .ac_update_motors         ; No overcurrent, continue

    ; Check vibration position vs stop threshold
    ld  a, (autocenter_vib_stop)
    ld  b, a
    ld  a, (vibration_position)
    cp  b
    jp  nc, .ac_vib_stop_exceeded
    jp  .ac_phase_12_check

; --- Phase 12 check: final bank centering ---
.ac_phase_12_check:
    ld  a, $FF
    ld  (autocenter_phase_10), a

    ; Phase 12 check
    ld  a, (autocenter_phase_12)
    or  a
    jp  nz, .ac_final_check

    ; Phase 11: bank position lookup for centering
    ld  a, (autocenter_phase_11)
    or  a
    jp  nz, .ac_phase_11_running

    ld  a, $FF
    ld  (autocenter_phase_11), a

.ac_phase_11_running:
    call bank_position_to_speed_lookup

    ; Check if bank motor has stopped
    ld  a, (bank_motor_dir)
    or  a
    jp  z, .ac_final_check
    jp  .ac_update_motors

.ac_final_check:
    ; Auto-center complete
    ld  a, $FF
    ld  (autocenter_phase_12), a

    xor a
    ld  (bank_motor_dir), a          ; Stop bank
    ld  (vibration_motor_dir), a     ; Stop vibration
    ld  (safety_stop_flag), a        ; Clear safety flag

    call write_ppi_port_b_00         ; Clear status

    ; Check if command changed during auto-center
    ld  a, (main_board_command)
    cp  $FF
    jp  nz, output_motor_status

    ; Fully complete: clear all flags
    ld  hl, $0000
    ld  (bank_timeout_16bit), hl
    ld  (vib_timeout_16bit), hl
    xor a
    ld  (autocenter_active), a
    ld  (safety_stop_flag), a
    jp  output_motor_status

; --- Auto-center motor update path ---
.ac_update_motors:
    call check_motion_timeout
    call read_limit_switches_bank

    ; Check if limit switch triggered return-to-home
    ld  a, (limit_sw_triggered)
    or  a
    jp  z, output_motor_status

    ld  a, $FF
    ld  (return_to_home_flag), a     ; Engage return-to-home
    jp  output_motor_status

; --- Auto-center error handlers ---
.ac_error:
    ld  a, (autocenter_bank_fwd_err)
    ld  b, a
    ld  a, (bank_position)
    cp  b
    jp  c, .ac_set_error_87
    jp  .ac_set_error_81

.ac_check_position_diff:
    ld  a, (bank_accel_thresh)
    cp  $20
    jp  nc, .ac_set_error_82
    jp  .ac_set_error_85

.ac_position_out_of_range:
    jp  .ac_set_error_86

.ac_overcurrent_error:
    jp  .ac_set_error_84

.ac_timeout_error:
    jp  .ac_set_error_87_b

.ac_error_phase2:
    ld  a, (autocenter_bank_rev_err)
    ld  b, a
    ld  a, (bank_position)
    cp  b
    jp  nc, .ac_set_error_87_b
    jp  .ac_set_error_81

.ac_bank_distance_exceeded:
    ld  a, (bank_overcurrent)
    or  a
    jp  nz, .ac_set_error_84
    ld  a, (bank_position)
    cp  $C0
    jp  nc, .ac_set_error_87_b
    jp  .ac_set_error_83

.ac_error_vib:
    ld  a, (autocenter_vib_err_fwd)
    ld  b, a
    ld  a, (vibration_position)
    cp  b
    jp  nc, .ac_set_error_97
    jp  .ac_set_error_99

.ac_vib_check_overcurrent:
    ld  a, (bank_accel_thresh)
    cp  $15
    jp  nc, .ac_set_error_92
    jp  .ac_set_error_95

.ac_vib_out_of_range:
    jp  .ac_set_error_98

.ac_vib_overcurrent_error:
    ld  hl, (vib_timeout_16bit)
    ld  a, l
    or  a
    jp  nz, .ac_set_error_99
    jp  .ac_set_error_94

.ac_error_vib2:
    jp  .ac_set_error_91

.ac_vib_dist_exceeded:
    ld  a, (vibration_overcurrent)
    or  a
    jp  nz, .ac_set_error_94
    jp  .ac_set_error_93

.ac_vib_stop_exceeded:
    jp  .ac_set_error_9a

; --- Error code output routines ---
; Each sets PPI port B to an error code, then flags error state
.ac_set_error_87:
    ld  a, $87
    jp  .ac_report_error
.ac_set_error_81:
    ld  a, $81
    jp  .ac_report_error
.ac_set_error_82:
    ld  a, $82
    jp  .ac_report_error
.ac_set_error_85:
    ld  a, $85
    jp  .ac_report_error
.ac_set_error_86:
    ld  a, $86
    jp  .ac_report_error
.ac_set_error_84:
    ld  a, $84
    jp  .ac_report_error
.ac_set_error_83:
    ld  a, $83
    jp  .ac_report_error
.ac_set_error_87_b:
    ld  a, $87
    jp  .ac_report_error
.ac_set_error_97:
    ld  a, $97
    jp  .ac_report_error
.ac_set_error_99:
    ld  a, $99
    jp  .ac_report_error
.ac_set_error_92:
    ld  a, $92
    jp  .ac_report_error
.ac_set_error_95:
    ld  a, $95
    jp  .ac_report_error
.ac_set_error_98:
    ld  a, $98
    jp  .ac_report_error
.ac_set_error_94:
    ld  a, $94
    jp  .ac_report_error
.ac_set_error_91:
    ld  a, $91
    jp  .ac_report_error
.ac_set_error_93:
    ld  a, $93
    jp  .ac_report_error
.ac_set_error_9a:
    ld  a, $9A
    jp  .ac_report_error

.ac_report_error:
    ld  (PPI_PORT_B), a              ; Output error code to main board
    ld  a, $FF
    ld  (error_detected), a          ; Flag error
    xor a
    ld  (bank_motor_dir), a          ; Stop bank
    ld  (vibration_motor_dir), a     ; Stop vibration
    jp  output_motor_status

; ============================================================================
; DIRECT MOTOR TEST COMMANDS ($08C6-$0913)
; ============================================================================

cmd_bank_motor_cw:
    ld  a, $01
    ld  (bank_motor_dir), a          ; Bank CW
    ld  a, $90
    ld  (bank_speed_limit), a        ; Speed = $90
    call build_limit_switch_status
    jp  output_motor_status

cmd_bank_motor_ccw:
    ld  a, $02
    ld  (bank_motor_dir), a          ; Bank CCW
    ld  a, $90
    ld  (bank_speed_limit), a        ; Speed = $90
    call build_limit_switch_status
    jp  output_motor_status

cmd_vibration_motor_cw:
    ld  a, $01
    ld  (vibration_motor_dir), a     ; Vibration CW
    ld  a, $90
    ld  (vibration_speed_limit), a   ; Speed = $90
    call build_limit_switch_status
    jp  output_motor_status

cmd_vibration_motor_ccw:
    ld  a, $02
    ld  (vibration_motor_dir), a     ; Vibration CCW
    ld  a, $90
    ld  (vibration_speed_limit), a   ; Speed = $90
    call build_limit_switch_status
    jp  output_motor_status

cmd_all_motors_stop:
    xor a
    ld  (bank_motor_dir), a
    ld  (vibration_motor_dir), a
    call build_limit_switch_status
    jp  output_motor_status

cmd_unknown_stop:
    xor a
    ld  (bank_motor_dir), a
    ld  (vibration_motor_dir), a
    jp  output_motor_status

; ============================================================================
; NORMAL POSITION UPDATE ($091D)
; ============================================================================
; Called when no special command is active. Computes target positions
; and speeds based on the main board's direction commands.
; ============================================================================

normal_position_update:
    ld  a, (bank_motor_cmd)
    call compute_bank_target_position
    ld  a, (bank_motion_mode)
    cp  $03                          ; Mode 3 = position tracking
    call z, bank_position_to_speed_lookup
    ld  (bank_motor_dir), a
    call check_bank_safety_limits

    ld  a, (vibration_motor_cmd)
    cp  $03                          ; Mode 3 = position tracking
    call z, vibration_position_to_speed_lookup
    ld  (vibration_motor_dir), a
    call check_vibration_safety_limits

    call read_limit_switches_bank
    call compute_output_status_byte
    jp  output_motor_status

; ============================================================================
; OUTPUT MOTOR STATUS ($0948)
; ============================================================================
; Sends position data and status back to the main board via $C000/$C001.
; Then dispatches to bank motor and vibration motor state machines.
; ============================================================================

output_motor_status:
    ; --- Send telemetry to main board ---
    ld  a, $90
    ld  (MAIN_BOARD_CTRL), a         ; Set comm mode

    ld  a, (bank_position)
    ld  (MAIN_BOARD_DATA), a         ; Send bank position

    ld  a, (vibration_position)
    ld  (MAIN_BOARD_DATA), a         ; Send vibration position

    ; Check diagnostic mode
    ld  a, (MAIN_BOARD_INPUT)
    bit 3, a
    jp  nz, .diag_mode_output

    ; --- Normal mode output ---
    ld  a, (PPI_PORT_B)              ; Read back PPI port B status
    ld  (MAIN_BOARD_DATA), a

    ld  a, (main_board_command)
    ld  (MAIN_BOARD_DATA), a

    ld  hl, (bank_pos_16bit)
    ld  a, l
    ld  (MAIN_BOARD_DATA), a         ; Bank position low byte
    ld  a, h
    ld  (MAIN_BOARD_DATA), a         ; Bank position high byte

    ld  hl, (vibration_pos_16bit)
    ld  a, l
    ld  (MAIN_BOARD_DATA), a         ; Vibration position low byte
    ld  a, h
    ld  (MAIN_BOARD_DATA), a         ; Vibration position high byte
    jp  .dispatch_bank_motor

.diag_mode_output:
    ; --- Diagnostic mode output ---
    ld  a, (MAIN_BOARD_INPUT)
    and $0F
    ld  (MAIN_BOARD_DATA), a         ; Send DIP switch state

    bit 0, a
    jp  nz, .diag_type_b
    ld  a, $00                       ; Type A indicator
    ld  (MAIN_BOARD_DATA), a
    jp  .diag_counters
.diag_type_b:
    ld  a, $FF                       ; Type B indicator
    ld  (MAIN_BOARD_DATA), a

.diag_counters:
    ; Send timeout counters
    ld  hl, (bank_timeout_16bit)
    ld  a, l
    ld  (MAIN_BOARD_DATA), a

    ld  hl, (vib_timeout_16bit)
    ld  a, l
    ld  (MAIN_BOARD_DATA), a

    ; Send motor speeds
    ld  a, (bank_motor_speed)
    ld  (MAIN_BOARD_DATA), a
    ld  a, (vibration_motor_speed)
    ld  (MAIN_BOARD_DATA), a

; ============================================================================
; BANK MOTOR STATE MACHINE DISPATCHER ($09BA)
; ============================================================================
; Routes to bank motor sub-state based on bank_motor_dir (0,1,2,3).
; ============================================================================

.dispatch_bank_motor:
    ld  a, (bank_motor_dir)
    or  a
    jp  z, .bank_dir_stop            ; Dir 0 = stopped
    cp  $01
    jp  z, .bank_dir_cw              ; Dir 1 = CW (forward)
    cp  $02
    jp  z, .bank_dir_ccw             ; Dir 2 = CCW (reverse)
    cp  $03
    jp  z, .bank_dir_stop            ; Dir 3 = stop (same as 0)
    jp  .bank_dir_stop

; --- Bank motor stopped: dispatch on motion state ---
.bank_dir_stop:
    ld  a, (bank_motion_state)
    or  a
    jp  z, bank_state_idle           ; State 0 = idle
    cp  $01
    jp  z, bank_state_accel          ; State 1 = accelerating
    cp  $02
    jp  z, bank_state_accel          ; State 2 = accelerating (variant)
    cp  $03
    jp  z, bank_state_accel          ; State 3 = at speed
    cp  $04
    jp  z, bank_state_decel          ; State 4 = decelerating
    cp  $05
    jp  z, bank_state_decel          ; State 5 = decelerating (variant)
    cp  $06
    jp  z, bank_state_decel          ; State 6 = decelerating (variant)
    jp  bank_state_idle

; --- Bank motor CW: dispatch on motion state ---
.bank_dir_cw:
    ld  a, (bank_motion_state)
    or  a
    jp  z, bank_state_cw_start       ; State 0 = start CW
    cp  $01
    jp  z, bank_state_cw_start       ; State 1 = continue start
    cp  $02
    jp  z, bank_state_accel          ; State 2 = accelerating
    cp  $03
    jp  z, bank_state_cw_at_speed    ; State 3 = at target speed
    cp  $04
    jp  z, bank_state_decel          ; State 4 = decelerating
    cp  $05
    jp  z, bank_state_decel          ; State 5
    cp  $06
    jp  z, bank_state_decel          ; State 6
    jp  bank_state_idle

; --- Bank motor CCW: dispatch on motion state ---
.bank_dir_ccw:
    ld  a, (bank_motion_state)
    or  a
    jp  z, bank_state_ccw_start      ; State 0 = start CCW
    cp  $01
    jp  z, bank_state_accel          ; State 1
    cp  $02
    jp  z, bank_state_accel          ; State 2
    cp  $03
    jp  z, bank_state_accel          ; State 3
    cp  $04
    jp  z, bank_state_ccw_start      ; State 4 = reverse start
    cp  $05
    jp  z, bank_state_decel          ; State 5
    cp  $06
    jp  z, bank_state_ccw_at_speed   ; State 6 = at target speed (CCW)
    jp  bank_state_idle

; ============================================================================
; BANK MOTOR STATE: CW START ($0A4B)
; ============================================================================
; Initialize CW motion: set state to 1, clear flags, check early motion,
; then read acceleration curve.
; ============================================================================

bank_state_cw_start:
    ld  a, $01
    ld  (bank_motion_state), a       ; State = 1 (accelerating CW)
    xor a
    ld  (bank_sm_profile_flag), a
    ld  (bank_sm_phase_a), a
    ld  (bank_sm_accel_flag_b), a
    ld  (bank_sm_decel_flag_b), a
    ld  (bank_sm_decel_flag), a

    ; Check early motion (vibration context)
    ld  a, (bank_early_latch)
    or  a
    jp  nz, .cw_check_init

    call check_vibration_early_motion
    ld  a, (bank_early_motion)
    or  a
    jp  z, .cw_check_init
    ld  a, $02
    ld  (bank_target_speed), a       ; Slow speed during early motion
    jp  .cw_apply_speed

.cw_check_init:
    ; Check if acceleration curve init needed
    ld  a, (bank_sm_init_flag)
    or  a
    jp  nz, .cw_read_accel_curve

    ; Initialize acceleration
    ld  a, $FF
    ld  (bank_sm_init_flag), a
    ld  a, $00
    ld  (bank_accel_index), a        ; Start at index 0
    ld  a, $FF
    ld  (bank_early_latch), a        ; Latch early motion
    ld  a, (bank_position)
    ld  (bank_pos_snapshot_0), a     ; Record start position

.cw_read_accel_curve:
    ; Read speed from acceleration curve table
    ld  hl, $F420                    ; Bank accel curve (in RAM)
    ld  a, (bank_accel_index)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (bank_target_speed), a

    ; Check if curve complete (index >= $21)
    ld  a, (bank_accel_index)
    cp  $21
    jp  nc, .cw_accel_complete
    jp  .cw_apply_speed

.cw_accel_complete:
    ld  a, $03
    ld  (bank_motion_state), a       ; State = 3 (at speed)
    ld  a, (bank_position)
    ld  (bank_pos_snapshot_1), a     ; Record end-of-accel position

.cw_apply_speed:
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR STATE: ACCEL / DECEL PROFILE ($0ABC)
; ============================================================================
; Runs the speed deceleration profile. Selects the appropriate profile tier
; based on the 16-bit position distance, then reads speed from that tier.
; ============================================================================

bank_state_accel:
    ld  a, $02
    ld  (bank_motion_state), a       ; State = 2
    xor a
    ld  (bank_sm_init_flag), a
    ld  (bank_sm_phase_a), a
    ld  (bank_sm_accel_flag_b), a
    ld  (bank_sm_decel_flag_b), a
    ld  (bank_sm_decel_flag), a

    ld  hl, $0000
    ld  (bank_speed_overflow), hl

    ; Check if profile already loaded
    ld  a, (bank_sm_profile_flag)
    or  a
    jp  nz, .bank_read_profile

    ; First time: select profile tier based on distance
    ld  a, $FF
    ld  (bank_sm_profile_flag), a
    ld  a, $00
    ld  (bank_decel_index), a

    ; Compare 16-bit position against thresholds
    or  a
    ld  de, (bank_pos_16bit)

    ld  hl, (bank_profile_thresh_0)
    sbc hl, de
    jp  nc, .bank_select_tier_1

    or  a
    ld  hl, (bank_profile_thresh_1)
    sbc hl, de
    jp  nc, .bank_select_tier_2

    or  a
    ld  hl, (bank_profile_thresh_2)
    sbc hl, de
    jp  nc, .bank_select_tier_3

    or  a
    ld  hl, (bank_profile_thresh_3)
    sbc hl, de
    jp  nc, .bank_select_tier_4
    jp  .bank_select_tier_5

.bank_select_tier_1:
    ld  hl, $F450                    ; Tier 1 profile
    ld  (bank_profile_ptr), hl
    jp  .bank_read_profile
.bank_select_tier_2:
    ld  hl, $F480                    ; Tier 2 profile
    ld  (bank_profile_ptr), hl
    jp  .bank_read_profile
.bank_select_tier_3:
    ld  hl, $F4B0                    ; Tier 3 profile
    ld  (bank_profile_ptr), hl
    jp  .bank_read_profile
.bank_select_tier_4:
    ld  hl, $F4D0                    ; Tier 4 profile
    ld  (bank_profile_ptr), hl
    jp  .bank_read_profile
.bank_select_tier_5:
    ld  hl, $F4F0                    ; Tier 5 profile
    ld  (bank_profile_ptr), hl
    jp  .bank_read_profile

.bank_read_profile:
    ; Read speed from selected profile at current index
    ld  hl, (bank_profile_ptr)
    ld  a, (bank_decel_index)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (bank_target_speed), a

    ; Clamp to current speed if profile speed is higher
    ld  b, a
    ld  a, (bank_motor_speed)
    cp  b
    jp  nc, .bank_profile_clamp
    ld  (bank_target_speed), a       ; Use current (lower) speed

.bank_profile_clamp:
    ; Check if profile value = 1 (stopped)
    ld  a, b
    cp  $01
    jp  z, .bank_profile_done
    jp  bank_apply_speed_and_direction

.bank_profile_done:
    ld  a, $00
    ld  (bank_motion_state), a       ; State = idle
    xor a
    ld  (bank_early_latch), a        ; Clear early motion latch
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR STATE: CCW START ($0B6E)
; ============================================================================
; Same as CW start but for reverse direction (state 4).
; ============================================================================

bank_state_ccw_start:
    ld  a, $04
    ld  (bank_motion_state), a       ; State = 4 (accelerating CCW)
    xor a
    ld  (bank_sm_init_flag), a
    ld  (bank_sm_profile_flag), a
    ld  (bank_sm_phase_a), a
    ld  (bank_sm_decel_flag_b), a
    ld  (bank_sm_decel_flag), a

    ; Check early motion
    ld  a, (bank_early_latch)
    or  a
    jp  nz, .ccw_check_init

    call check_vibration_early_motion
    ld  a, (bank_early_motion)
    or  a
    jp  z, .ccw_check_init
    ld  a, $02
    ld  (bank_target_speed), a
    jp  .ccw_apply_speed

.ccw_check_init:
    ld  a, (bank_sm_accel_flag_b)
    or  a
    jp  nz, .ccw_read_accel

    ld  a, $FF
    ld  (bank_sm_accel_flag_b), a
    ld  a, $00
    ld  (bank_accel_index_b), a
    ld  a, $FF
    ld  (bank_early_latch), a
    ld  a, (bank_position)
    ld  (bank_pos_snapshot_2), a

.ccw_read_accel:
    ld  hl, $F420
    ld  a, (bank_accel_index_b)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (bank_target_speed), a

    ld  a, (bank_accel_index_b)
    cp  $21
    jp  nc, .ccw_accel_complete
    jp  .ccw_apply_speed

.ccw_accel_complete:
    ld  a, $06
    ld  (bank_motion_state), a       ; State = 6 (at speed, CCW)
    ld  a, (bank_position)
    ld  (bank_pos_snapshot_3), a

.ccw_apply_speed:
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR STATE: DECEL ($0BDF)
; ============================================================================
; Deceleration using profile table (same structure as accel profile).
; ============================================================================

bank_state_decel:
    ld  a, $05
    ld  (bank_motion_state), a       ; State = 5
    xor a
    ld  (bank_sm_init_flag), a
    ld  (bank_sm_profile_flag), a
    ld  (bank_sm_phase_a), a
    ld  (bank_sm_accel_flag_b), a
    ld  (bank_sm_decel_flag), a

    ld  hl, $0000
    ld  (bank_speed_overflow), hl

    ld  a, (bank_sm_decel_flag_b)
    or  a
    jp  nz, .bank_decel_read

    ld  a, $FF
    ld  (bank_sm_decel_flag_b), a
    ld  a, $00
    ld  (bank_decel_index_b), a

    ; Select profile tier (same logic as accel)
    or  a
    ld  de, (bank_pos_16bit)
    ld  hl, (bank_profile_thresh_0)
    sbc hl, de
    jp  nc, .bank_decel_tier_1

    or  a
    ld  hl, (bank_profile_thresh_1)
    sbc hl, de
    jp  nc, .bank_decel_tier_2

    or  a
    ld  hl, (bank_profile_thresh_2)
    sbc hl, de
    jp  nc, .bank_decel_tier_3

    or  a
    ld  hl, (bank_profile_thresh_3)
    sbc hl, de
    jp  nc, .bank_decel_tier_4
    jp  .bank_decel_tier_5

.bank_decel_tier_1:
    ld  hl, $F450
    ld  (bank_profile_ptr), hl
    jp  .bank_decel_read
.bank_decel_tier_2:
    ld  hl, $F480
    ld  (bank_profile_ptr), hl
    jp  .bank_decel_read
.bank_decel_tier_3:
    ld  hl, $F4B0
    ld  (bank_profile_ptr), hl
    jp  .bank_decel_read
.bank_decel_tier_4:
    ld  hl, $F4D0
    ld  (bank_profile_ptr), hl
    jp  .bank_decel_read
.bank_decel_tier_5:
    ld  hl, $F4F0
    ld  (bank_profile_ptr), hl
    jp  .bank_decel_read

.bank_decel_read:
    ld  hl, (bank_profile_ptr)
    ld  a, (bank_decel_index_b)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (bank_target_speed), a

    ld  b, a
    ld  a, (bank_motor_speed)
    cp  b
    jp  nc, .bank_decel_clamp
    ld  (bank_target_speed), a

.bank_decel_clamp:
    ld  a, b
    cp  $01
    jp  z, .bank_decel_done
    jp  bank_apply_speed_and_direction

.bank_decel_done:
    ld  a, $00
    ld  (bank_motion_state), a
    xor a
    ld  (bank_early_latch), a
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR STATE: CW AT SPEED ($0C91)
; ============================================================================
; Bank motor at target speed (CW direction). Gradually ramps speed up to the
; speed limit, or decreases if above limit.
; ============================================================================

bank_state_cw_at_speed:
    ld  a, $03
    ld  (bank_motion_state), a       ; State = 3
    xor a
    ld  (bank_sm_init_flag), a
    ld  (bank_sm_profile_flag), a
    ld  (bank_sm_accel_flag_b), a
    ld  (bank_sm_decel_flag_b), a
    ld  (bank_sm_decel_flag), a

    ; Check if phase initialized
    ld  a, (bank_sm_phase_a)
    or  a
    jp  nz, .bank_cw_running
    ld  a, $FF
    ld  (bank_sm_phase_a), a

.bank_cw_running:
    ; Compare current speed to speed limit
    ld  a, (bank_speed_limit)
    ld  b, a
    ld  a, (bank_motor_speed)
    cp  b
    jp  c, .bank_cw_speed_up         ; Below limit: increase
    jp  .bank_cw_speed_down           ; At/above limit: decrease

.bank_cw_speed_up:
    ld  a, (bank_motor_speed)
    inc a
    ld  (bank_target_speed), a

    ; Clamp to motor limit for this direction
    ld  hl, $F410
    ld  a, (bank_motor_cmd)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  b, a
    ld  a, (bank_target_speed)
    cp  b
    jp  c, .bank_cw_apply            ; Under limit: OK

    ; At hardware limit: cap speed, increment overflow counter
    ld  a, (bank_motor_speed)
    ld  (bank_target_speed), a
    ld  hl, (bank_speed_overflow)
    inc hl
    ld  (bank_speed_overflow), hl
    jp  .bank_cw_apply

.bank_cw_speed_down:
    ld  a, (bank_motor_speed)
    dec a
    ld  (bank_target_speed), a
    ld  hl, $0000
    ld  (bank_speed_overflow), hl

.bank_cw_apply:
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR STATE: CCW AT SPEED ($0CFA)
; ============================================================================
; Same as CW at speed but for CCW direction (state 6).
; ============================================================================

bank_state_ccw_at_speed:
    ld  a, $06
    ld  (bank_motion_state), a       ; State = 6
    xor a
    ld  (bank_sm_init_flag), a
    ld  (bank_sm_profile_flag), a
    ld  (bank_sm_phase_a), a
    ld  (bank_sm_accel_flag_b), a
    ld  (bank_sm_decel_flag_b), a

    ld  a, (bank_sm_decel_flag)
    or  a
    jp  nz, .bank_ccw_running
    ld  a, $FF
    ld  (bank_sm_decel_flag), a

.bank_ccw_running:
    ld  a, (bank_speed_limit)
    ld  b, a
    ld  a, (bank_motor_speed)
    cp  b
    jp  c, .bank_ccw_speed_up
    jp  .bank_ccw_speed_down

.bank_ccw_speed_up:
    ld  a, (bank_motor_speed)
    inc a
    ld  (bank_target_speed), a

    ld  hl, $F410
    ld  a, (bank_motor_cmd)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  b, a
    ld  a, (bank_target_speed)
    cp  b
    jp  c, .bank_ccw_apply

    ld  a, (bank_motor_speed)
    ld  (bank_target_speed), a
    ld  hl, (bank_speed_overflow)
    inc hl
    ld  (bank_speed_overflow), hl
    jp  .bank_ccw_apply

.bank_ccw_speed_down:
    ld  a, (bank_motor_speed)
    dec a
    ld  (bank_target_speed), a
    ld  hl, $0000
    ld  (bank_speed_overflow), hl

.bank_ccw_apply:
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR STATE: IDLE ($0D63)
; ============================================================================
; Clears all state machine flags and sets speed to minimum (1).
; ============================================================================

bank_state_idle:
    xor a
    ld  (bank_sm_init_flag), a
    ld  (bank_sm_profile_flag), a
    ld  (bank_sm_phase_a), a
    ld  (bank_sm_decel_flag), a
    ld  (bank_sm_accel_flag_b), a
    ld  (bank_sm_decel_flag_b), a

    ld  hl, $0000
    ld  (bank_speed_overflow), hl
    ld  (bank_overflow_16bit), hl

    ld  a, $00
    ld  (bank_motion_state), a       ; Idle state
    ld  a, $01
    ld  (bank_target_speed), a       ; Minimum speed
    jp  bank_apply_speed_and_direction

; ============================================================================
; BANK MOTOR: APPLY SPEED AND DIRECTION ($0D8C)
; ============================================================================
; Sets the bank motor direction (stop/CW/CCW) based on motion state,
; then updates the motor speed. After bank motor, dispatches to vibration
; motor state machine.
; ============================================================================

bank_apply_speed_and_direction:
    ld  a, (bank_motion_state)
    cp  $00
    jp  nz, .bank_not_idle
    call bank_motor_stop             ; State 0: stop motor
    jp  .bank_set_speed
.bank_not_idle:
    cp  $04
    jp  nc, .bank_reverse            ; States 4-6: CCW
    call bank_motor_forward          ; States 1-3: CW
    jp  .bank_set_speed
.bank_reverse:
    call bank_motor_reverse          ; CCW

.bank_set_speed:
    ld  a, (bank_target_speed)
    ld  (bank_motor_speed), a
    call update_bank_motor_speed

; ============================================================================
; VIBRATION MOTOR STATE MACHINE DISPATCHER ($0DB1)
; ============================================================================
; Same structure as bank motor, dispatches based on vibration_motor_dir.
; ============================================================================

    ld  a, (vibration_motor_dir)
    or  a
    jp  z, .vib_dir_stop
    cp  $01
    jp  z, .vib_dir_cw
    cp  $02
    jp  z, .vib_dir_ccw
    cp  $03
    jp  z, .vib_dir_stop
    jp  .vib_dir_stop

; --- Vibration stopped ---
.vib_dir_stop:
    ld  a, (vibration_motion_state)
    or  a
    jp  z, vib_state_idle
    cp  $01
    jp  z, vib_state_accel
    cp  $02
    jp  z, vib_state_accel
    cp  $03
    jp  z, vib_state_accel
    cp  $04
    jp  z, vib_state_decel
    cp  $05
    jp  z, vib_state_decel
    cp  $06
    jp  z, vib_state_decel
    jp  vib_state_idle

; --- Vibration CW ---
.vib_dir_cw:
    ld  a, (vibration_motion_state)
    or  a
    jp  z, vib_state_cw_start
    cp  $01
    jp  z, vib_state_cw_start
    cp  $02
    jp  z, vib_state_accel
    cp  $03
    jp  z, vib_state_cw_at_speed
    cp  $04
    jp  z, vib_state_decel
    cp  $05
    jp  z, vib_state_decel
    cp  $06
    jp  z, vib_state_decel
    jp  vib_state_idle

; --- Vibration CCW ---
.vib_dir_ccw:
    ld  a, (vibration_motion_state)
    or  a
    jp  z, vib_state_ccw_start
    cp  $01
    jp  z, vib_state_accel
    cp  $02
    jp  z, vib_state_accel
    cp  $03
    jp  z, vib_state_accel
    cp  $04
    jp  z, vib_state_ccw_start
    cp  $05
    jp  z, vib_state_decel
    cp  $06
    jp  z, vib_state_ccw_at_speed
    jp  vib_state_idle

; ============================================================================
; VIBRATION MOTOR STATE: CW START ($0E42)
; ============================================================================

vib_state_cw_start:
    ld  a, $01
    ld  (vibration_motion_state), a
    xor a
    ld  (vib_sm_profile_flag), a
    ld  (vib_sm_phase_a), a
    ld  (vib_sm_accel_flag_b), a
    ld  (vib_sm_decel_flag_b), a
    ld  (vib_sm_decel_flag), a

    ld  a, (vibration_early_latch)
    or  a
    jp  nz, .vib_cw_check_init

    call check_bank_early_motion
    ld  a, (bank_early_motion_b)
    or  a
    jp  z, .vib_cw_check_init
    ld  a, $02
    ld  (vibration_target_speed), a
    jp  .vib_cw_apply

.vib_cw_check_init:
    ld  a, (vib_sm_init_flag)
    or  a
    jp  nz, .vib_cw_read_accel

    ld  a, $FF
    ld  (vib_sm_init_flag), a
    ld  a, $00
    ld  (vib_accel_index), a
    ld  a, $FF
    ld  (vibration_early_latch), a
    ld  a, (vibration_position)
    ld  (vib_pos_snapshot_0), a

.vib_cw_read_accel:
    ld  hl, $F620
    ld  a, (vib_accel_index)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (vibration_target_speed), a

    ld  a, (vib_accel_index)
    cp  $1A
    jp  nc, .vib_cw_accel_complete
    jp  .vib_cw_apply

.vib_cw_accel_complete:
    ld  a, $03
    ld  (vibration_motion_state), a
    ld  a, (vibration_position)
    ld  (vib_pos_snapshot_1), a

.vib_cw_apply:
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR STATE: ACCEL/DECEL PROFILE ($0EB3)
; ============================================================================

vib_state_accel:
    ld  a, $02
    ld  (vibration_motion_state), a
    xor a
    ld  (vib_sm_init_flag), a
    ld  (vib_sm_phase_a), a
    ld  (vib_sm_accel_flag_b), a
    ld  (vib_sm_decel_flag_b), a
    ld  (vib_sm_decel_flag), a

    ld  hl, $0000
    ld  (vib_speed_overflow), hl
    ld  (vib_overflow_16bit), hl

    ld  a, (vib_sm_profile_flag)
    or  a
    jp  nz, .vib_read_profile

    ld  a, $FF
    ld  (vib_sm_profile_flag), a
    ld  a, $00
    ld  (vib_decel_index), a

    ; Select vibration profile tier
    or  a
    ld  de, (vibration_pos_16bit)
    ld  hl, (vib_profile_thresh_0)
    sbc hl, de
    jp  nc, .vib_select_tier_1

    or  a
    ld  hl, (vib_profile_thresh_1)
    sbc hl, de
    jp  nc, .vib_select_tier_2

    or  a
    ld  hl, (vib_profile_thresh_2)
    sbc hl, de
    jp  nc, .vib_select_tier_3

    or  a
    ld  hl, (vib_profile_thresh_3)
    sbc hl, de
    jp  nc, .vib_select_tier_4
    jp  .vib_select_tier_5

.vib_select_tier_1:
    ld  hl, $F650
    ld  (vibration_profile_ptr), hl
    jp  .vib_read_profile
.vib_select_tier_2:
    ld  hl, $F680
    ld  (vibration_profile_ptr), hl
    jp  .vib_read_profile
.vib_select_tier_3:
    ld  hl, $F6B0
    ld  (vibration_profile_ptr), hl
    jp  .vib_read_profile
.vib_select_tier_4:
    ld  hl, $F6D0
    ld  (vibration_profile_ptr), hl
    jp  .vib_read_profile
.vib_select_tier_5:
    ld  hl, $F6F0
    ld  (vibration_profile_ptr), hl
    jp  .vib_read_profile

.vib_read_profile:
    ld  hl, (vibration_profile_ptr)
    ld  a, (vib_decel_index)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (vibration_target_speed), a

    ld  b, a
    ld  a, (vibration_motor_speed)
    cp  b
    jp  nc, .vib_profile_clamp
    ld  (vibration_target_speed), a

.vib_profile_clamp:
    ld  a, b
    cp  $01
    jp  z, .vib_profile_done
    jp  vib_apply_speed_and_direction

.vib_profile_done:
    ld  a, $00
    ld  (vibration_motion_state), a
    xor a
    ld  (vibration_early_latch), a
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR STATE: CCW START ($0F68)
; ============================================================================

vib_state_ccw_start:
    ld  a, $04
    ld  (vibration_motion_state), a
    xor a
    ld  (vib_sm_init_flag), a
    ld  (vib_sm_profile_flag), a
    ld  (vib_sm_phase_a), a
    ld  (vib_sm_decel_flag_b), a
    ld  (vib_sm_decel_flag), a

    ld  a, (vibration_early_latch)
    or  a
    jp  nz, .vib_ccw_check_init

    call check_bank_early_motion
    ld  a, (bank_early_motion_b)
    or  a
    jp  z, .vib_ccw_check_init
    ld  a, $02
    ld  (vibration_target_speed), a
    jp  .vib_ccw_apply

.vib_ccw_check_init:
    ld  a, (vib_sm_accel_flag_b)
    or  a
    jp  nz, .vib_ccw_read_accel

    ld  a, $FF
    ld  (vib_sm_accel_flag_b), a
    ld  a, $00
    ld  (vib_accel_index_b), a
    ld  a, $FF
    ld  (vibration_early_latch), a
    ld  a, (vibration_position)
    ld  (vib_pos_snapshot_2), a

.vib_ccw_read_accel:
    ld  hl, $F620
    ld  a, (vib_accel_index_b)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (vibration_target_speed), a

    ld  a, (vib_accel_index_b)
    cp  $1A
    jp  nc, .vib_ccw_accel_complete
    jp  .vib_ccw_apply

.vib_ccw_accel_complete:
    ld  a, $06
    ld  (vibration_motion_state), a
    ld  a, (vibration_position)
    ld  (vib_pos_snapshot_3), a

.vib_ccw_apply:
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR STATE: DECEL ($0FD9)
; ============================================================================

vib_state_decel:
    ld  a, $05
    ld  (vibration_motion_state), a
    xor a
    ld  (vib_sm_init_flag), a
    ld  (vib_sm_profile_flag), a
    ld  (vib_sm_phase_a), a
    ld  (vib_sm_accel_flag_b), a
    ld  (vib_sm_decel_flag), a

    ld  hl, $0000
    ld  (vib_speed_overflow), hl
    ld  (vib_overflow_16bit), hl

    ld  a, (vib_sm_decel_flag_b)
    or  a
    jp  nz, .vib_decel_read

    ld  a, $FF
    ld  (vib_sm_decel_flag_b), a
    ld  a, $00
    ld  (vib_decel_index_b), a

    ; Select profile tier
    or  a
    ld  de, (vibration_pos_16bit)
    ld  hl, (vib_profile_thresh_0)
    sbc hl, de
    jp  nc, .vib_decel_tier_1

    or  a
    ld  hl, (vib_profile_thresh_1)
    sbc hl, de
    jp  nc, .vib_decel_tier_2

    or  a
    ld  hl, (vib_profile_thresh_2)
    sbc hl, de
    jp  nc, .vib_decel_tier_3

    or  a
    ld  hl, (vib_profile_thresh_3)
    sbc hl, de
    jp  nc, .vib_decel_tier_4
    jp  .vib_decel_tier_5

.vib_decel_tier_1:
    ld  hl, $F650
    ld  (vibration_profile_ptr), hl
    jp  .vib_decel_read
.vib_decel_tier_2:
    ld  hl, $F680
    ld  (vibration_profile_ptr), hl
    jp  .vib_decel_read
.vib_decel_tier_3:
    ld  hl, $F6B0
    ld  (vibration_profile_ptr), hl
    jp  .vib_decel_read
.vib_decel_tier_4:
    ld  hl, $F6D0
    ld  (vibration_profile_ptr), hl
    jp  .vib_decel_read
.vib_decel_tier_5:
    ld  hl, $F6F0
    ld  (vibration_profile_ptr), hl
    jp  .vib_decel_read

.vib_decel_read:
    ld  hl, (vibration_profile_ptr)
    ld  a, (vib_decel_index_b)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  (vibration_target_speed), a

    ld  b, a
    ld  a, (vibration_motor_speed)
    cp  b
    jp  nc, .vib_decel_clamp
    ld  (vibration_target_speed), a

.vib_decel_clamp:
    ld  a, b
    cp  $01
    jp  z, .vib_decel_done
    jp  vib_apply_speed_and_direction

.vib_decel_done:
    ld  a, $00
    ld  (vibration_motion_state), a
    xor a
    ld  (vibration_early_latch), a
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR STATE: CW AT SPEED ($108E)
; ============================================================================

vib_state_cw_at_speed:
    ld  a, $03
    ld  (vibration_motion_state), a
    xor a
    ld  (vib_sm_init_flag), a
    ld  (vib_sm_profile_flag), a
    ld  (vib_sm_accel_flag_b), a
    ld  (vib_sm_decel_flag_b), a
    ld  (vib_sm_decel_flag), a

    ld  a, (vib_sm_phase_a)
    or  a
    jp  nz, .vib_cw_running
    ld  a, $FF
    ld  (vib_sm_phase_a), a

.vib_cw_running:
    ld  a, (vibration_speed_limit)
    ld  b, a
    ld  a, (vibration_motor_speed)
    cp  b
    jp  c, .vib_cw_speed_up
    jp  .vib_cw_speed_down

.vib_cw_speed_up:
    ld  a, (vibration_motor_speed)
    inc a
    ld  (vibration_target_speed), a

    ld  hl, $F610
    ld  a, (bank_motor_cmd)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  b, a
    ld  a, (vibration_target_speed)
    cp  b
    jp  c, .vib_cw_at_speed_apply

    ld  a, (vibration_motor_speed)
    ld  (vibration_target_speed), a
    ld  hl, (vib_speed_overflow)
    inc hl
    ld  (vib_speed_overflow), hl
    jp  .vib_cw_at_speed_apply

.vib_cw_speed_down:
    ld  a, (vibration_motor_speed)
    dec a
    ld  (vibration_target_speed), a
    ld  hl, $0000
    ld  (vib_speed_overflow), hl

.vib_cw_at_speed_apply:
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR STATE: CCW AT SPEED ($10F7)
; ============================================================================

vib_state_ccw_at_speed:
    ld  a, $06
    ld  (vibration_motion_state), a
    xor a
    ld  (vib_sm_init_flag), a
    ld  (vib_sm_profile_flag), a
    ld  (vib_sm_phase_a), a
    ld  (vib_sm_accel_flag_b), a
    ld  (vib_sm_decel_flag_b), a

    ld  a, (vib_sm_decel_flag)
    or  a
    jp  nz, .vib_ccw_running
    ld  a, $FF
    ld  (vib_sm_decel_flag), a

.vib_ccw_running:
    ld  a, (vibration_speed_limit)
    ld  b, a
    ld  a, (vibration_motor_speed)
    cp  b
    jp  c, .vib_ccw_speed_up
    jp  .vib_ccw_speed_down

.vib_ccw_speed_up:
    ld  a, (vibration_motor_speed)
    inc a
    ld  (vibration_target_speed), a

    ld  hl, $F610
    ld  a, (bank_motor_cmd)
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  b, a
    ld  a, (vibration_target_speed)
    cp  b
    jp  c, .vib_ccw_at_speed_apply

    ld  a, (vibration_motor_speed)
    ld  (vibration_target_speed), a
    ld  hl, (vib_speed_overflow)
    inc hl
    ld  (vib_speed_overflow), hl
    jp  .vib_ccw_at_speed_apply

.vib_ccw_speed_down:
    ld  a, (vibration_motor_speed)
    dec a
    ld  (vibration_target_speed), a
    ld  hl, $0000
    ld  (vib_speed_overflow), hl

.vib_ccw_at_speed_apply:
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR STATE: IDLE ($1160)
; ============================================================================

vib_state_idle:
    xor a
    ld  (vib_sm_init_flag), a
    ld  (vib_sm_profile_flag), a
    ld  (vib_sm_phase_a), a
    ld  (vib_sm_decel_flag), a
    ld  (vib_sm_accel_flag_b), a
    ld  (vib_sm_decel_flag_b), a

    ld  hl, $0000
    ld  (vib_speed_overflow), hl

    ld  a, $00
    ld  (vibration_motion_state), a
    ld  a, $01
    ld  (vibration_target_speed), a
    jp  vib_apply_speed_and_direction

; ============================================================================
; VIBRATION MOTOR: APPLY SPEED AND DIRECTION ($1186)
; ============================================================================

vib_apply_speed_and_direction:
    ld  a, (vibration_motion_state)
    cp  $00
    jp  nz, .vib_not_idle
    call vibration_motor_brake       ; State 0: brake
    jp  .vib_set_speed
.vib_not_idle:
    cp  $04
    jp  nc, .vib_reverse             ; States 4-6: CCW
    call vibration_motor_forward     ; States 1-3: CW
    jp  .vib_set_speed
.vib_reverse:
    call vibration_motor_reverse     ; CCW

.vib_set_speed:
    ld  a, (vibration_target_speed)
    ld  (vibration_motor_speed), a
    call update_vibration_motor_speed
    jp  main_loop                    ; Return to main loop

; ============================================================================
; MOTOR DIRECTION CONTROL SUBROUTINES ($11AE-$11F4)
; ============================================================================

; --- Bank motor stop ---
; Clear PPI bits 0,1 (forward and reverse off), reload timer
bank_motor_stop:
    ld  hl, PPI_PORT_A
    res 0, (hl)                      ; Clear forward bit
    res 1, (hl)                      ; Clear reverse bit
    ld  a, $01
    ld  (TIMER0_CNT1), a            ; Reload timer (stopped)
    ret

; --- Bank motor forward (CW) ---
bank_motor_forward:
    ld  hl, PPI_PORT_A
    set 0, (hl)                      ; Set forward bit
    res 1, (hl)                      ; Clear reverse bit
    ret

; --- Bank motor reverse (CCW) ---
bank_motor_reverse:
    ld  hl, PPI_PORT_A
    res 0, (hl)                      ; Clear forward bit
    set 1, (hl)                      ; Set reverse bit
    ret

; --- Vibration motor stop ---
; Clear PPI bits 2,3, reload timer
vibration_motor_stop:
    ld  hl, PPI_PORT_A
    res 2, (hl)                      ; Clear forward bit
    res 3, (hl)                      ; Clear reverse bit
    ld  a, $01
    ld  (TIMER1_CNT1), a            ; Reload timer (stopped)
    ret

; --- Vibration motor forward (CW) ---
vibration_motor_forward:
    ld  hl, PPI_PORT_A
    set 2, (hl)                      ; Set forward bit
    res 3, (hl)                      ; Clear reverse bit
    ret

; --- Vibration motor reverse (CCW) ---
vibration_motor_reverse:
    ld  hl, PPI_PORT_A
    res 2, (hl)                      ; Clear forward bit
    set 3, (hl)                      ; Set reverse bit
    ret

; --- Vibration motor brake (dynamic braking) ---
; Set PPI bits 2 AND 3 (both on = brake), reload timer
vibration_motor_brake:
    ld  hl, PPI_PORT_A
    set 2, (hl)                      ; Set forward bit
    set 3, (hl)                      ; Set reverse bit
    ld  a, $01
    ld  (TIMER1_CNT1), a            ; Reload timer
    ret

; ============================================================================
; MOTOR SPEED UPDATE SUBROUTINES ($11F5-$1238)
; ============================================================================

; --- Update bank motor speed ---
; Clamps speed to range $01-$F2 and writes to timer 0 counter 1.
; If speed < 3, stops the bank motor instead.
update_bank_motor_speed:
    ld  a, (bank_motor_speed)
    cp  $03
    jp  nc, .bank_speed_in_range
    call bank_motor_stop             ; Too slow: stop motor
    jp  .bank_speed_done
.bank_speed_in_range:
    or  a
    jp  nz, .bank_speed_not_zero
    ld  a, $01                       ; Clamp to minimum 1
.bank_speed_not_zero:
    cp  $F3
    jp  c, .bank_speed_not_max
    ld  a, $F2                       ; Clamp to maximum $F2
.bank_speed_not_max:
    ld  (bank_motor_speed), a
    ld  (TIMER0_CNT1), a            ; Set timer = speed
.bank_speed_done:
    ret

; --- Update vibration motor speed ---
; Same as bank but uses timer 1 and brakes instead of stops.
update_vibration_motor_speed:
    ld  a, (vibration_motor_speed)
    cp  $03
    jp  nc, .vib_speed_in_range
    call vibration_motor_brake       ; Too slow: brake
    jp  .vib_speed_done
.vib_speed_in_range:
    or  a
    jp  nz, .vib_speed_not_zero
    ld  a, $01
.vib_speed_not_zero:
    cp  $F3
    jp  c, .vib_speed_not_max
    ld  a, $F2
.vib_speed_not_max:
    ld  (vibration_motor_speed), a
    ld  (TIMER1_CNT1), a            ; Set timer = speed
.vib_speed_done:
    ret

; ============================================================================
; CHECK BANK SAFETY LIMITS ($1239)
; ============================================================================
; Checks various timeout/overflow conditions for the bank motor.
; If any limit is exceeded, triggers safety stop.
; Also checks limit switch states and position bounds.
; ============================================================================

check_bank_safety_limits:
    ; Check bank timeout (bit 10 of 16-bit counter)
    ld  hl, (bank_timeout_16bit)
    bit 2, h
    jp  nz, .bank_safety_trigger

    ; Check bank overflow (bit 12)
    ld  hl, (bank_overflow_16bit)
    bit 4, h
    jp  nz, .bank_safety_error

    ; Check speed overflow (bit 12)
    ld  hl, (bank_speed_overflow)
    bit 4, h
    jp  nz, .bank_safety_error

    ; Check if limit switch triggered
    ld  a, (limit_sw_triggered)
    or  a
    jp  nz, .bank_safety_error

    ; Direction-specific checks
    ld  a, (bank_motor_dir)
    cp  $01
    jp  nz, .bank_check_ccw_limits

    ; CW direction checks
    ld  a, (bank_motion_state)
    cp  $03                          ; At speed?
    jp  z, .bank_cw_at_speed_check
    jp  .bank_cw_position_check

.bank_cw_at_speed_check:
    ld  a, (motion_seq_active)
    or  a
    jp  nz, .bank_cw_position_check
    ld  a, (bank_overcurrent)
    or  a
    jp  nz, .bank_safety_trigger

.bank_cw_position_check:
    ; Check bank position against forward limit
    ld  a, (bank_limit_fwd)
    ld  b, a
    ld  a, (bank_position)
    cp  b
    jp  c, .bank_safety_error        ; Position < limit (bad)

    ld  a, (bank_cw_limit_active)
    or  a
    jp  nz, .bank_safety_error       ; CW limit switch active
    jp  .bank_safety_check_overcurrent

.bank_check_ccw_limits:
    cp  $02
    jp  nz, .bank_safety_check_overcurrent

    ; CCW direction checks
    ld  a, (bank_motion_state)
    cp  $06
    jp  z, .bank_ccw_at_speed_check
    jp  .bank_ccw_position_check

.bank_ccw_at_speed_check:
    ld  a, (motion_seq_active)
    or  a
    jp  nz, .bank_ccw_position_check
    ld  a, (bank_overcurrent)
    or  a
    jp  nz, .bank_safety_trigger

.bank_ccw_position_check:
    ld  a, (bank_limit_rev)
    ld  b, a
    ld  a, (bank_position)
    cp  b
    jp  nc, .bank_safety_error       ; Position >= limit (bad)

    ld  a, (bank_cw_limit_active)
    or  a
    jp  nz, .bank_safety_error
    jp  .bank_safety_check_overcurrent

.bank_safety_check_overcurrent:
    ld  a, (bank_overcurrent)
    or  a
    jp  nz, .bank_overcurrent_status
    jp  .bank_safety_normal

.bank_safety_trigger:
    ; Safety triggered: set status and stop
    ld  a, $A0
    ld  (bank_output_status), a
    xor a
    ld  (bank_motor_dir), a
    ld  a, $FF
    ld  (safety_stop_flag), a
    jp  .bank_safety_done

.bank_overcurrent_status:
    ld  a, $00
    ld  (bank_output_status), a
    jp  .bank_safety_done

.bank_safety_normal:
    ld  a, $40
    ld  (bank_output_status), a
    jp  .bank_safety_done

.bank_safety_error:
    ld  a, $E0
    ld  (bank_output_status), a
    xor a
    ld  (bank_motor_dir), a

.bank_safety_done:
    ret

; ============================================================================
; CHECK VIBRATION SAFETY LIMITS ($12F3)
; ============================================================================
; Same structure as bank safety limits but for vibration motor.
; ============================================================================

check_vibration_safety_limits:
    ld  hl, (vib_timeout_16bit)
    bit 2, h
    jp  nz, .vib_safety_error

    ld  hl, (vib_overflow_16bit)
    bit 4, h
    jp  nz, .vib_safety_error

    ld  hl, (vib_speed_overflow)
    bit 4, h
    jp  nz, .vib_safety_error

    ld  a, (limit_sw_triggered)
    or  a
    jp  nz, .vib_safety_error

    ; Direction checks
    ld  a, (vibration_motor_dir)
    cp  $01
    jp  nz, .vib_check_ccw

    ; CW checks
    ld  a, (vibration_motion_state)
    cp  $03
    jp  z, .vib_cw_at_speed_check
    jp  .vib_cw_pos_check

.vib_cw_at_speed_check:
    ld  a, (motion_seq_active)
    or  a
    jp  nz, .vib_cw_pos_check
    ld  a, (vibration_overcurrent)
    or  a
    jp  nz, .vib_safety_error

.vib_cw_pos_check:
    ld  a, (vibration_limit_fwd)
    ld  b, a
    ld  a, (vibration_position)
    cp  b
    jp  nc, .vib_safety_error

    ld  a, (vib_ccw_limit_active)
    or  a
    jp  nz, .vib_safety_error
    jp  .vib_check_overcurrent

.vib_check_ccw:
    cp  $02
    jp  nz, .vib_check_overcurrent

    ld  a, (vibration_motion_state)
    cp  $06
    jp  z, .vib_ccw_at_speed_check
    jp  .vib_ccw_pos_check

.vib_ccw_at_speed_check:
    ld  a, (motion_seq_active)
    or  a
    jp  nz, .vib_ccw_pos_check
    ld  a, (vibration_overcurrent)
    or  a
    jp  nz, .vib_safety_error

.vib_ccw_pos_check:
    ld  a, (vibration_limit_rev)
    ld  b, a
    ld  a, (vibration_position)
    cp  b
    jp  c, .vib_safety_error

    ld  a, (vib_cw_limit_active)
    or  a
    jp  nz, .vib_safety_error
    jp  .vib_check_overcurrent

.vib_check_overcurrent:
    ld  a, (vibration_overcurrent)
    or  a
    jp  nz, .vib_overcurrent_status
    jp  .vib_safety_normal

; Note: $1382 appears to be dead code (unreachable) but is in the ROM
    ld  a, $90
    ld  (vibration_output_status), a
    xor a
    ld  (vibration_motor_dir), a
    ld  a, $FF
    ld  (safety_stop_flag), a
    jp  .vib_safety_done

.vib_overcurrent_status:
    ld  a, $00
    ld  (vibration_output_status), a
    jp  .vib_safety_done

.vib_safety_normal:
    ld  a, $40
    ld  (vibration_output_status), a
    jp  .vib_safety_done

.vib_safety_error:
    ld  a, $D0
    ld  (vibration_output_status), a
    xor a
    ld  (vibration_motor_dir), a

.vib_safety_done:
    ret

; ============================================================================
; COMPUTE BANK TARGET POSITION ($13AD)
; ============================================================================
; Reads the bank speed ramp table (8 bytes, 4 word entries) indexed by
; the motor command, and compares against the 16-bit position to determine
; if the motor should speed up or slow down.
; ============================================================================

compute_bank_target_position:
    ld  hl, $F400                    ; Bank speed ramp table
    sla a                            ; Index * 2 (word entries)
    ld  d, a                         ; Save for vibration lookup
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)                      ; Low byte of target
    ld  b, a
    inc hl
    ld  a, (hl)                      ; High byte of target
    ld  c, a

    ; Compare 16-bit position against target
    or  a
    ld  hl, (bank_pos_16bit)
    sbc hl, bc
    jp  c, .bank_target_below        ; Position < target: speed up

    ; Position >= target: speed up more
    ld  a, (bank_motor_speed)
    inc a
    or  a
    cp  $F1
    jp  c, .bank_target_set_up

    ; Speed overflow
    ld  hl, (bank_overflow_16bit)
    inc hl
    ld  (bank_overflow_16bit), hl
    ld  a, $F0
    ld  (bank_speed_limit), a
    jp  compute_vibration_target_position

.bank_target_set_up:
    ld  (bank_speed_limit), a
    xor a
    ld  h, a
    ld  l, a
    ld  (bank_overflow_16bit), hl
    jp  compute_vibration_target_position

.bank_target_below:
    ; Position below target: slow down
    ld  a, (bank_motor_speed)
    dec a
    or  a
    cp  $20
    jp  nc, .bank_target_set_down
    ld  a, $10                       ; Minimum decel speed
.bank_target_set_down:
    ld  (bank_speed_limit), a
    xor a
    ld  h, a
    ld  l, a
    ld  (bank_overflow_16bit), hl
    jp  compute_vibration_target_position

; ============================================================================
; COMPUTE VIBRATION TARGET POSITION ($1402)
; ============================================================================
; Same as bank but for vibration motor.
; ============================================================================

compute_vibration_target_position:
    ld  hl, $F600                    ; Vibration speed ramp table
    ld  a, d                         ; Use same index as bank
    ld  c, a
    xor a
    ld  b, a
    add hl, bc
    ld  a, (hl)
    ld  b, a
    inc hl
    ld  a, (hl)
    ld  c, a

    or  a
    ld  hl, (vibration_pos_16bit)
    sbc hl, bc
    jp  c, .vib_target_below

    ld  a, (vibration_motor_speed)
    inc a
    or  a
    cp  $E8
    jp  c, .vib_target_set_up

    ld  hl, (vib_overflow_16bit)
    inc hl
    ld  (vib_overflow_16bit), hl
    ld  a, $E7
    ld  (vibration_speed_limit), a
    jp  .vib_target_done

.vib_target_set_up:
    ld  (vibration_speed_limit), a
    xor a
    ld  h, a
    ld  l, a
    ld  (vib_overflow_16bit), hl
    jp  .vib_target_done

.vib_target_below:
    ld  a, (vibration_motor_speed)
    dec a
    or  a
    cp  $50
    jp  nc, .vib_target_set_down
    ld  a, $18                       ; Minimum decel speed
.vib_target_set_down:
    ld  (vibration_speed_limit), a
    xor a
    ld  h, a
    ld  l, a
    ld  (vib_overflow_16bit), hl
    jp  .vib_target_done

.vib_target_done:
    ret

; ============================================================================
; READ LIMIT SWITCHES ($1456)
; ============================================================================
; Reads debounced limit switch states and sets safety flags.
; ============================================================================

read_limit_switches_bank:
    xor a
    ld  (limit_switch_bits), a
    ld  b, a

    ; Check limit switch 0 (bank CW)
    ld  a, (limit_raw_0)
    cp  $FF
    jp  nz, .ls_check_1
    set 3, b                         ; Set bit 3

.ls_check_1:
    ld  a, (limit_raw_1)
    cp  $FF
    jp  nz, .ls_check_2
    set 2, b                         ; Set bit 2

.ls_check_2:
    ld  a, (limit_raw_2)
    cp  $FF
    jp  nz, .ls_check_result
    set 1, b                         ; Set bit 1

.ls_check_result:
    ld  a, b
    or  a
    jp  z, .ls_no_limit

    ; Limit switch activated
    ld  a, b
    ld  (limit_switch_bits), a
    ld  a, $FF
    ld  (limit_sw_triggered), a
    jp  .ls_check_both_motors

.ls_no_limit:
    ; Check if both motors are idle with overcurrent cleared
    ld  a, (bank_overcurrent)
    or  a
    jp  z, .ls_check_both_motors
    ld  a, (vibration_overcurrent)
    or  a
    jp  z, .ls_check_both_motors

    ld  a, (bank_motion_state)
    or  a
    jp  nz, .ls_check_both_motors
    ld  a, (vibration_motion_state)
    or  a
    jp  nz, .ls_check_both_motors

    ; Both motors idle: clear limit switch flag
    xor a
    ld  (limit_sw_triggered), a

.ls_check_both_motors:
    ; If limit switches active, stop both motors
    ld  a, (limit_sw_triggered)
    or  a
    jp  z, .ls_done
    xor a
    ld  (bank_motor_dir), a
    ld  (vibration_motor_dir), a

.ls_done:
    ret

; ============================================================================
; COMPUTE OUTPUT STATUS BYTE ($14B9)
; ============================================================================
; Combines bank and vibration status with limit switch info into the
; combined output byte, then writes it to PPI port B.
; ============================================================================

compute_output_status_byte:
    xor a
    ld  (combined_output_byte), a

    ld  a, (limit_sw_triggered)
    or  a
    jp  nz, .status_limit_active

    ; Check bank status
    ld  a, (bank_output_status)
    cp  $A0
    jp  z, .status_bank_a0

    ; Check vibration status
    ld  a, (vibration_output_status)
    cp  $90
    jp  z, .status_vib_90

    ; Combine all status bytes
    ld  a, (bank_output_status)
    ld  b, a
    ld  a, (vibration_output_status)
    ld  c, a
    ld  a, (limit_switch_bits)
    ld  d, a
    ld  a, (combined_output_byte)
    or  b
    or  c
    or  d
    ld  (combined_output_byte), a
    jp  .status_write

.status_bank_a0:
    ld  a, (vibration_output_status)
    cp  $90
    jp  z, .status_both_critical

    ld  a, $A0
    ld  (combined_output_byte), a
    jp  .status_write

.status_vib_90:
    ld  a, $90
    ld  (combined_output_byte), a
    jp  .status_write

.status_both_critical:
    ld  a, $B0
    ld  (combined_output_byte), a
    jp  .status_write

.status_limit_active:
    ld  a, $C0
    ld  b, a
    ld  a, (limit_switch_bits)
    or  b
    ld  (combined_output_byte), a

.status_write:
    ld  (PPI_PORT_B), a              ; Write combined status to port B
    ret

; ============================================================================
; CHECK BANK EARLY MOTION ($151A)
; ============================================================================
; Checks if bank motor is still in early acceleration phase.
; Sets bank_early_motion_b flag if early indices are below threshold.
; ============================================================================

check_bank_early_motion:
    ; Check CW init flag and accel index
    ld  a, (bank_sm_init_flag)
    or  a
    jp  z, .check_bank_early_ccw
    ld  a, (bank_accel_index)
    cp  $15
    jp  nc, .check_bank_early_ccw
    jp  .bank_early_set

.check_bank_early_ccw:
    ld  a, (bank_sm_accel_flag_b)
    or  a
    jp  z, .bank_early_clear
    ld  a, (bank_accel_index_b)
    cp  $15
    jp  nc, .bank_early_clear
    jp  .bank_early_set

.bank_early_set:
    ld  a, $FF
    ld  (bank_early_motion_b), a
    jp  .bank_early_done

.bank_early_clear:
    xor a
    ld  (bank_early_motion_b), a

.bank_early_done:
    ret

; ============================================================================
; CHECK VIBRATION EARLY MOTION ($154B)
; ============================================================================
; Same as bank but checks vibration accel indices.
; ============================================================================

check_vibration_early_motion:
    ld  a, (vib_sm_init_flag)
    or  a
    jp  z, .check_vib_early_ccw
    ld  a, (vib_accel_index)
    cp  $0F
    jp  nc, .check_vib_early_ccw
    jp  .vib_early_set

.check_vib_early_ccw:
    ld  a, (vib_sm_accel_flag_b)
    or  a
    jp  z, .vib_early_clear
    ld  a, (vib_accel_index_b)
    cp  $0F
    jp  nc, .vib_early_clear
    jp  .vib_early_set

.vib_early_set:
    ld  a, $FF
    ld  (bank_early_motion), a
    jp  .vib_early_done

.vib_early_clear:
    xor a
    ld  (bank_early_motion), a

.vib_early_done:
    ret

; ============================================================================
; BANK POSITION TO SPEED LOOKUP ($157C)
; ============================================================================
; Converts bank pot position to a speed and direction using the 128-byte
; lookup table at $F510. Position < deadzone_lo = CCW, > deadzone_hi = CW,
; in between = stopped.
; ============================================================================

bank_position_to_speed_lookup:
    ld  a, (bank_deadzone_lo)        ; $F151
    ld  b, a
    ld  a, (bank_deadzone_hi)        ; $F152
    ld  c, a
    ld  a, (bank_position)
    cp  b
    jp  c, .bank_pos_below_center    ; Below dead zone: CCW
    cp  c
    jp  c, .bank_pos_in_deadzone     ; In dead zone: stop
    jp  .bank_pos_above_center       ; Above dead zone: CW

.bank_pos_below_center:
    ; Position below center: drive CCW
    ; Table index = $80 - position + 1
    ld  b, a
    ld  a, $80
    sub b
    inc a
    ld  c, a
    xor a
    ld  b, a
    ld  hl, $F510
    add hl, bc
    ld  a, (hl)
    ld  (bank_speed_limit), a
    ld  a, $02                       ; Direction = CCW
    ld  (bank_motor_dir), a
    ret

.bank_pos_above_center:
    ; Position above center: drive CW
    ; Table index = position - $80
    ld  c, a
    ld  a, $80
    ld  b, a
    ld  a, c
    sub b
    ld  c, a
    xor a
    ld  b, a
    ld  hl, $F510
    add hl, bc
    ld  a, (hl)
    ld  (bank_speed_limit), a
    ld  a, $01                       ; Direction = CW
    ld  (bank_motor_dir), a
    ret

.bank_pos_in_deadzone:
    ; In dead zone: stop motor
    xor a
    ld  (bank_motor_dir), a
    ret

; ============================================================================
; VIBRATION POSITION TO SPEED LOOKUP ($15C4)
; ============================================================================
; Same as bank but for vibration, using $F710 lookup table.
; Dead zone: $7C-$84 (approximate center at $80).
; ============================================================================

vibration_position_to_speed_lookup:
    ld  a, (vibration_position)
    cp  $7C
    jp  c, .vib_pos_below_center
    cp  $85
    jp  c, .vib_pos_in_deadzone
    jp  .vib_pos_above_center

.vib_pos_below_center:
    ld  b, a
    ld  a, $80
    sub b
    ld  c, a
    xor a
    ld  b, a
    ld  hl, $F710
    add hl, bc
    ld  a, (hl)
    ld  (vibration_speed_limit), a
    ld  a, $01                       ; CW
    ld  (vibration_motor_dir), a
    ret

.vib_pos_above_center:
    ld  c, a
    ld  a, $80
    ld  b, a
    ld  a, c
    sub b
    ld  c, a
    xor a
    ld  b, a
    ld  hl, $F710
    add hl, bc
    ld  a, (hl)
    ld  (vibration_speed_limit), a
    ld  a, $02                       ; CCW
    ld  (vibration_motor_dir), a
    ret

.vib_pos_in_deadzone:
    xor a
    ld  (vibration_motor_dir), a
    ret

; ============================================================================
; PPI PORT B UTILITY SUBROUTINES ($1605-$1616)
; ============================================================================

; Write $40 to PPI port B (auto-center in progress status)
write_ppi_port_b_40:
    ld  a, $40
    ld  (PPI_PORT_B), a
    ret

; Write $00 to PPI port B (clear status)
write_ppi_port_b_00:
    ld  a, $00
    ld  (PPI_PORT_B), a
    ret

; Write $C0 to PPI port B (homing in progress status)
write_ppi_port_b_c0:
    ld  a, $C0
    ld  (PPI_PORT_B), a
    ret

; ============================================================================
; BUILD LIMIT SWITCH STATUS ($1617)
; ============================================================================
; Builds a status byte from the four debounced limit switch flags
; ($F00E-$F011) and writes it to PPI port B with $40 OR'd in.
; ============================================================================

build_limit_switch_status:
    ld  b, $00

    ; Bank CCW limit ($F00F)
    ld  a, (limit_sw_bank_ccw)
    cp  $FF
    jp  z, .bls_ccw_active
    res 5, b
    jp  .bls_check_cw
.bls_ccw_active:
    set 5, b

.bls_check_cw:
    ; Bank CW limit ($F00E)
    ld  a, (limit_sw_bank_cw)
    cp  $FF
    jp  z, .bls_cw_active
    res 4, b
    jp  .bls_check_vib_ccw
.bls_cw_active:
    set 4, b

.bls_check_vib_ccw:
    ; Vibration CCW limit ($F011)
    ld  a, (limit_sw_vib_ccw)
    cp  $FF
    jp  z, .bls_vib_ccw_active
    res 3, b
    jp  .bls_check_vib_cw
.bls_vib_ccw_active:
    set 3, b

.bls_check_vib_cw:
    ; Vibration CW limit ($F010)
    ld  a, (limit_sw_vib_cw)
    cp  $FF
    jp  z, .bls_vib_cw_active
    res 2, b
    jp  .bls_write
.bls_vib_cw_active:
    set 2, b

.bls_write:
    ld  a, $40
    or  b
    ld  (PPI_PORT_B), a
    ret

; ============================================================================
; CHECK MOTION TIMEOUT ($165C)
; ============================================================================
; Checks if the bank or vibration motion has timed out by examining
; the upper bits of the timeout counters.
; ============================================================================

check_motion_timeout:
    ; Bank timeout: check bit 9 of 16-bit counter
    ld  hl, (bank_timeout_16bit)
    bit 1, h
    jp  z, .timeout_check_vib
    ld  a, $FF
    ld  (error_detected), a
    ret

.timeout_check_vib:
    ; Vibration timeout: check bit 7 of low byte
    ld  hl, (vib_timeout_16bit)
    bit 7, l
    jp  z, .timeout_ok
    ld  a, $FF
    ld  (error_detected), a

.timeout_ok:
    ret

; ============================================================================
; DATA SECTION: MOTOR TYPE A (350-5133) PROFILE TABLES
; ============================================================================
; These tables are copied to RAM at initialization. The disassembler shows
; them as instructions, but they are pure data bytes.
; ============================================================================

    org $1678

; --- Bank speed ramp initial values (8 bytes: 4 word pairs) ---
; Each pair is (threshold_lo, threshold_hi) for comparing 16-bit position.
; Direction 0: threshold $0650, Direction 1: $0510
; Direction 2: $0450, Direction 3: $20C0
bank_speed_ramp_a:
    .db $06, $50, $05, $10, $04, $50, $04, $20

; --- Bank motor speed limits (4 bytes, one per direction) ---
; Maximum speed each direction can reach at constant velocity.
bank_motor_limits_a:
    .db $C0, $D0, $E0, $F0

; --- Bank acceleration curve (38 bytes) ---
; Speed values during initial acceleration, indexed by tick count.
; Starts slow, ramps up to $A0+, with a final jump to $E4-$E9.
bank_accel_curve_a:
    .db $01, $01, $03, $03, $03, $30, $30, $48
    .db $48, $58, $58, $68, $68, $78, $78, $88
    .db $88, $98, $98, $A0, $A0, $A0, $A0, $A0
    .db $A0, $A0, $A0, $A0, $A0, $A0, $A8, $A8
    .db $B0, $B8, $E4, $E6, $E8, $E9

; --- Bank motion profile tier 1 (32 bytes) ---
; Deceleration curve for shortest distance moves.
bank_profile_tier1_a:
    .db $30, $28, $18, $10, $05, $04, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $03
    .db $02, $02, $02, $02, $02, $01, $01, $01

; --- Bank motion profile tier 2 (26 bytes) ---
bank_profile_tier2_a:
    .db $30, $28, $18, $10, $05, $04, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $03
    .db $03, $03, $02, $02, $02, $02, $02, $01
    .db $01, $01

; --- Bank motion profile tier 3 (23 bytes) ---
bank_profile_tier3_a:
    .db $28, $18, $18, $10, $10, $05, $04, $03
    .db $03, $03, $03, $03, $03, $03, $03, $02
    .db $02, $02, $02, $02, $01, $01, $01

; --- Bank motion profile tier 4 (18 bytes) ---
bank_profile_tier4_a:
    .db $10, $10, $05, $04, $03, $03, $03, $03
    .db $03, $03, $03, $03, $02, $02, $02, $01
    .db $01, $01

; --- Bank motion profile tier 5 (15 bytes) ---
bank_profile_tier5_a:
    .db $10, $05, $03, $03, $03, $03, $03, $02
    .db $02, $02, $02, $02, $01, $01, $01

; --- Bank position-to-speed lookup table (128 bytes) ---
; Maps distance-from-center to motor speed for position tracking mode.
; Index 0 = at center, index 127 = max displacement.
bank_pos_speed_lut_a:
    .db $02, $02, $70, $88, $88, $88, $88, $8C
    .db $90, $9B, $9D, $A0, $A2, $A5, $A8, $AE
    .db $B0, $B2, $B4, $B6, $B8, $BA, $BC, $BE
    .db $C0, $C2, $C4, $C6, $C8, $CA, $CC, $CE
    .db $D0, $D2, $D4, $D6, $D8, $DA, $DC, $DE
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0

; --- Vibration speed ramp initial values (8 bytes) ---
vib_speed_ramp_a:
    .db $06, $40, $05, $F0, $05, $10, $04, $50

; --- Vibration motor speed limits (4 bytes) ---
vib_motor_limits_a:
    .db $BF, $CA, $DA, $E5

; --- Vibration acceleration curve (42 bytes) ---
vib_accel_curve_a:
    .db $01, $02, $02, $03, $03, $03, $03, $03
    .db $03, $03, $30, $38, $40, $48, $50, $58
    .db $60, $68, $70, $7B, $80, $83, $88, $8A
    .db $90, $90, $90, $B8, $C0, $C7, $CC, $D0
    .db $D4, $D8, $DA, $DC, $DE, $E0, $E2, $E4
    .db $E6, $E8, $E9

; --- Vibration motion profile tier 1 (40 bytes) ---
vib_profile_tier1_a:
    .db $10, $05, $04, $03, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $01, $01, $01

; Padding to reach 40 bytes
    .db $01, $01

; --- Vibration motion profile tier 2 (30 bytes) ---
vib_profile_tier2_a:
    .db $10, $05, $04, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $01, $01, $01

; Padding
    .db $01, $01

; --- Vibration motion profile tier 3 (27 bytes) ---
vib_profile_tier3_a:
    .db $05, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $01
    .db $01, $01

; Padding
    .db $01

; --- Vibration motion profile tier 4 (24 bytes) ---
vib_profile_tier4_a:
    .db $05, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $01, $01, $01

; Padding
    .db $01

; --- Vibration motion profile tier 5 (23 bytes) ---
vib_profile_tier5_a:
    .db $05, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $01, $01, $01

; Padding
    .db $01

; --- Vibration position-to-speed lookup table (128 bytes) ---
vib_pos_speed_lut_a:
    .db $02, $02, $02, $02, $18, $28, $38, $50
    .db $58, $58, $59, $5A, $5B, $5C, $5D, $5E
    .db $62, $64, $66, $68, $6A, $6C, $6D, $6F
    .db $70, $72, $74, $76, $78, $7A, $7C, $7E
    .db $80, $82, $84, $86, $88, $8A, $8C, $8E
    .db $90, $92, $94, $96, $98, $9A, $9C, $9E
    .db $A0, $A2, $A4, $A6, $A8, $AA, $AC, $AE
    .db $B0, $B2, $B4, $B6, $B8, $BA, $BC, $BE
    .db $C0, $C2, $C4, $C6, $C8, $CA, $CC, $CE
    .db $D0, $D2, $D4, $D6, $D8, $DA, $DC, $DE
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0

; ============================================================================
; DATA SECTION: MOTOR TYPE B (350-5134) PROFILE TABLES
; ============================================================================

    org $18E2

; --- Bank speed ramp initial values (8 bytes) ---
bank_speed_ramp_b:
    .db $05, $40, $04, $A0, $04, $40, $04, $00

; --- Bank motor speed limits (4 bytes) ---
bank_motor_limits_b:
    .db $C0, $D0, $E0, $E8

; --- Bank acceleration curve (39 bytes) ---
bank_accel_curve_b:
    .db $01, $01, $03, $03, $03, $30, $30, $30
    .db $48, $48, $58, $58, $68, $68, $78, $78
    .db $88, $88, $98, $98, $98, $98, $A0, $A0
    .db $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A8
    .db $A8, $B0, $B8, $E4, $E6, $E8, $E9

; --- Bank motion profile tier 1 (32 bytes) ---
bank_profile_tier1_b:
    .db $20, $18, $08, $05, $04, $03, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $03
    .db $03, $02, $02, $02, $02, $02, $01, $01
    ; (last byte is $01)

; --- Bank motion profile tier 2 (26 bytes) ---
bank_profile_tier2_b:
    .db $20, $18, $08, $05, $04, $03, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $03
    .db $03, $03, $02, $02, $02, $02, $02, $01
    .db $01, $01

; --- Bank motion profile tier 3 (23 bytes) ---
bank_profile_tier3_b:
    .db $18, $10, $08, $08, $08, $04, $03, $03
    .db $03, $03, $03, $03, $03, $03, $03, $02
    .db $02, $02, $02, $02, $01, $01, $01

; --- Bank motion profile tier 4 (18 bytes) ---
bank_profile_tier4_b:
    .db $08, $08, $04, $03, $03, $03, $03, $03
    .db $03, $03, $03, $03, $02, $02, $02, $01
    .db $01, $01

; --- Bank motion profile tier 5 (15 bytes) ---
bank_profile_tier5_b:
    .db $08, $04, $03, $03, $03, $03, $03, $02
    .db $02, $02, $02, $02, $01, $01, $01

; --- Bank position-to-speed lookup table (128 bytes) ---
bank_pos_speed_lut_b:
    .db $02, $02, $02, $02, $40, $58, $58, $60
    .db $60, $60, $60, $60, $60, $68, $68, $70
    .db $78, $80, $88, $90, $90, $90, $90, $90
    .db $A0, $A2, $A4, $A6, $A8, $AA, $AC, $AE
    .db $B0, $B2, $B4, $B6, $B8, $BA, $BC, $BE
    .db $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    .db $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    .db $C8, $C8, $C8, $C8, $C8, $C8, $C8, $C8
    .db $D0, $D0, $D0, $D0, $D0, $D0, $D0, $D0
    .db $D8, $D8, $D8, $D8, $D8, $D8, $D8, $D8
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0

; --- Vibration speed ramp initial values (8 bytes) ---
vib_speed_ramp_b:
    .db $05, $A0, $05, $80, $04, $D0, $04, $A0

; --- Vibration motor speed limits (4 bytes) ---
vib_motor_limits_b:
    .db $BF, $CA, $DA, $E5

; --- Vibration acceleration curve (42 bytes) ---
vib_accel_curve_b:
    .db $02, $03, $03, $03, $03, $03, $03, $03
    .db $23, $28, $30, $48, $40, $48, $50, $58
    .db $60, $68, $70, $7B, $80, $83, $88, $8A
    .db $90, $90, $90, $A0, $A0, $A0, $A0, $B0
    .db $B0, $B0, $B0, $B0, $B0, $B0, $B0, $C0
    .db $C0, $C0

; --- Vibration motion profile tier 1 (40 bytes) ---
vib_profile_tier1_b:
    .db $10, $05, $04, $03, $03, $03, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $01, $01, $01

; Padding
    .db $01

; --- Vibration motion profile tier 2 (30 bytes) ---
vib_profile_tier2_b:
    .db $10, $05, $04, $03, $03, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $01, $01

; --- Vibration motion profile tier 3 (27 bytes) ---
vib_profile_tier3_b:
    .db $05, $03, $03, $03, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $01, $01, $01

; --- Vibration motion profile tier 4 (24 bytes) ---
vib_profile_tier4_b:
    .db $05, $03, $03, $03, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $01, $01, $01

; --- Vibration motion profile tier 5 (23 bytes) ---
vib_profile_tier5_b:
    .db $05, $03, $03, $03, $02, $02, $02, $02
    .db $02, $02, $02, $02, $02, $02, $02, $02
    .db $02, $02, $02, $02, $01, $01, $01

; --- Vibration position-to-speed lookup table (128 bytes) ---
vib_pos_speed_lut_b:
    .db $02, $02, $02, $02, $18, $28, $38, $50
    .db $58, $58, $59, $5A, $5B, $5C, $5D, $5E
    .db $62, $64, $66, $68, $6A, $6C, $6D, $6F
    .db $70, $72, $74, $76, $78, $7A, $7C, $7E
    .db $80, $82, $84, $86, $88, $8A, $8C, $8E
    .db $90, $92, $94, $96, $98, $9A, $9C, $9E
    .db $A0, $A2, $A4, $A6, $A8, $AA, $AC, $AE
    .db $B0, $B2, $B4, $B6, $B8, $BA, $BC, $BE
    .db $C0, $C2, $C4, $C6, $C8, $CA, $CC, $CE
    .db $D0, $D2, $D4, $D6, $D8, $DA, $DC, $DE
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
    .db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0

; ============================================================================
; MOTION SEQUENCE PARAMETER TABLES ($1B4D)
; ============================================================================

    org $1B4D

; --- Motion sequence speed table (4 entries) ---
; Target speeds for sequences indexed 0-3.
motion_speed_table:
    .db $70, $80, $88, $88

; --- Motion sequence acceleration duration table (4 entries) ---
motion_accel_table:
    .db $40, $40, $40, $40

; --- Motion sequence hold duration table (4 entries) ---
motion_hold_table:
    .db $88, $A8, $B0, $B0

; ============================================================================
; MOTOR TYPE A CONFIGURATION PARAMETERS ($1B59)
; ============================================================================
; 35 bytes copied to $F130-$F152 during initialization.
; Contains limit thresholds, profile distance thresholds, auto-center
; parameters, and dead zone boundaries.
; ============================================================================

config_params_type_a:
    ; $F130-$F131: bank limit thresholds (fwd=$48, rev=$B8)
    .db $48, $B8
    ; $F132-$F133: vibration limit thresholds (fwd=$9A, rev=$65)
    .db $9A, $65
    ; $F134-$F135: bank profile threshold 0 (16-bit: $3004)
    .db $30, $04
    ; $F136-$F137: bank profile threshold 1 (16-bit: $9004)
    .db $90, $04
    ; $F138-$F139: bank profile threshold 2 (16-bit: $8005)
    .db $80, $05
    ; $F13A-$F13B: bank profile threshold 3 (16-bit: $A006)
    .db $A0, $06
    ; $F13C-$F13D: vibration profile threshold 0 (16-bit: $4004)
    .db $40, $04
    ; $F13E-$F13F: vibration profile threshold 1 (16-bit: $D004)
    .db $D0, $04
    ; $F140-$F141: vibration profile threshold 2 (16-bit: $6005)
    .db $60, $05
    ; $F142-$F143: vibration profile threshold 3 (16-bit: $8006)
    .db $80, $06
    ; $F144: auto-center bank forward error threshold
    .db $33
    ; $F145: auto-center bank reverse error threshold (split across bytes)
    .db $CD
    ; $F146: auto-center vibration forward error threshold
    .db $AD
    ; $F147: (unused/padding)
    .db $54
    ; $F148-$F149: auto-center vibration range (lo=$25, hi=$3C)
    .db $25, $3C
    ; $F14A-$F14B: auto-center vibration CCW range
    .db $9A, $C8
    ; $F14C-$F14D: auto-center bank distance threshold (16-bit: $8007)
    .db $80, $07
    ; $F14E-$F14F: auto-center vibration distance threshold (16-bit: $5006)
    .db $50, $06
    ; $F150: auto-center vibration stop threshold
    .db $8B
    ; $F151-$F152: bank position dead zone (lo=$80, hi=$83)
    .db $80, $83

; ============================================================================
; MOTOR TYPE B CONFIGURATION PARAMETERS ($1B7C)
; ============================================================================

config_params_type_b:
    ; $F130-$F131: bank limit thresholds (fwd=$45, rev=$BA)
    .db $45, $BA
    ; $F132-$F133: vibration limit thresholds (fwd=$99, rev=$66)
    .db $99, $66
    ; $F134-$F135: bank profile threshold 0 (16-bit: $5004)
    .db $50, $04
    ; $F136-$F137: bank profile threshold 1 (16-bit: $6004)
    .db $60, $04
    ; $F138-$F139: bank profile threshold 2 (16-bit: $3005)
    .db $30, $05
    ; $F13A-$F13B: bank profile threshold 3 (16-bit: $A006)
    .db $A0, $06
    ; $F13C-$F13D: vibration profile threshold 0
    .db $40, $04
    ; $F13E-$F13F: vibration profile threshold 1
    .db $D0, $04
    ; $F140-$F141: vibration profile threshold 2
    .db $60, $05
    ; $F142-$F143: vibration profile threshold 3
    .db $80, $06
    ; $F144: auto-center bank forward error threshold
    .db $1B
    ; $F145: auto-center bank reverse error threshold
    .db $E0
    ; $F146: auto-center vibration forward error threshold
    .db $AD
    ; $F147: (unused/padding)
    .db $54
    ; $F148-$F149: auto-center vibration range
    .db $18, $40
    ; $F14A-$F14B: auto-center vibration CCW range
    .db $9A, $C8
    ; $F14C-$F14D: auto-center bank distance threshold
    .db $80, $07
    ; $F14E-$F14F: auto-center vibration distance threshold
    .db $00, $08
    ; $F150: auto-center vibration stop threshold
    .db $8B
    ; $F151-$F152: bank position dead zone (lo=$7A, hi=$86)
    .db $7A, $86

; ============================================================================
; INTERRUPT SERVICE ROUTINE ($1B9F)
; ============================================================================
; Called via RST 38h (IM1 mode) on each timer interrupt.
; This is the main periodic update routine that:
; 1. Sets the watchdog and interrupt flags
; 2. Resets idle motor timers when both motors are stopped
; 3. Reads main board commands and parses bit fields
; 4. Debounces all limit switches (8-bit shift register technique)
; 5. Reads ADC position values (bank and vibration pots)
; 6. Computes 16-bit position values via fixed-point multiply
; 7. Updates ADC centering/calibration via threshold feedback
; 8. Increments stall detection counters
; 9. Increments all motion profile tick counters (every 10 ticks)
; ============================================================================

    org $1B9F

isr_handler:
    di                               ; Disable interrupts during ISR
    ex  af, af'                      ; Save main registers
    exx

    ; --- Set flags ---
    ld  a, $FF
    ld  (watchdog_timer_flag), a     ; Request watchdog pet
    ld  a, $FF
    ld  (interrupt_occurred), a      ; Signal main loop

    ; --- If both motors idle, reset timer counter 0 ---
    ld  a, (bank_motion_state)
    ld  b, a
    ld  a, (vibration_motion_state)
    or  b
    jp  nz, .isr_read_command

    ; Both idle: reload timers to minimum
    ld  a, TIMER_CNT0_MODE2_LSB
    ld  (TIMER0_CTRL), a
    ld  a, $01
    ld  (TIMER0_CNT0), a
    ld  (TIMER0_CNT1), a
    ld  (TIMER1_CNT1), a

; --- Read main board command ---
.isr_read_command:
    or  a                            ; Clear carry
    ld  a, (prev_main_board_byte)
    ld  b, a
    ld  a, (PPI_PORT_C)              ; Read PPI port C (main board data)
    ld  d, a                         ; Save raw value
    cp  b                            ; Same as last time?
    jp  nz, .isr_save_raw            ; Changed: just save, don't process

    ; Stable reading: store as command
    ld  (main_board_command), a
    bit 7, a                         ; Bit 7 = valid command flag
    jp  nz, .isr_cmd_special         ; Special command (bit 7 set)

    ; Normal command: extract bit fields
    ld  h, a
    ld  b, $03
    and b
    ld  (bank_motor_cmd), a          ; Bits 0-1: bank direction

    ld  a, h
    rrca
    rrca
    ld  b, $07
    and b
    ld  (vibration_motor_cmd), a     ; Bits 2-4: vibration command

    ld  a, h
    rrca
    rrca
    rrca
    rrca
    rrca
    ld  b, $03
    and b
    ld  (bank_motion_mode), a        ; Bits 5-6: bank motion mode
    jp  .isr_save_raw

.isr_cmd_special:
    ; Bit 7 set: this is a special command code
    ld  (cmd_code), a

.isr_save_raw:
    ld  a, d
    ld  (prev_main_board_byte), a    ; Save for next comparison

; --- Read limit switches from $8400 (watchdog port also has switch data) ---
    ld  a, (WATCHDOG)                ; Read watchdog port (has limit switch data)
    ld  b, a                         ; Save in B for all switch checks

    ; --- Debounce limit switch: bank CW ($F00E) ---
    bit 0, a                         ; Bit 0 of watchdog port
    jp  z, .isr_ls0_clear
    ld  a, (limit_sw_bank_cw)
    scf                              ; Set carry
    rla                              ; Rotate left through carry (shift in 1)
    ld  (limit_sw_bank_cw), a
    jp  .isr_ls0_done
.isr_ls0_clear:
    ld  a, (limit_sw_bank_cw)
    or  a                            ; Clear carry
    rla                              ; Rotate left through carry (shift in 0)
    ld  (limit_sw_bank_cw), a

.isr_ls0_done:
    ; Check if bank CW limit is fully latched ($FF = 8 consecutive reads)
    ld  a, (limit_sw_bank_cw)
    cp  $FF
    jp  z, .isr_ls0_active

    ; Not fully latched: check motion state for conditional clearing
    ld  a, (bank_motion_state)
    cp  $01
    jp  z, .isr_ls0_force_clear
    cp  $03
    jp  z, .isr_ls0_force_clear
    jp  .isr_ls1_check

.isr_ls0_active:
    ld  a, $FF
    ld  (bank_cw_limit_active), a
    jp  .isr_ls1_check

.isr_ls0_force_clear:
    xor a
    ld  (bank_cw_limit_active), a
    jp  .isr_ls1_check

    ; --- Debounce limit switch: bank CCW ($F00F) ---
.isr_ls1_check:
    ld  a, b                         ; Restore saved port value
    bit 1, a
    jp  z, .isr_ls1_clear
    ld  a, (limit_sw_bank_ccw)
    scf
    rla
    ld  (limit_sw_bank_ccw), a
    jp  .isr_ls1_done
.isr_ls1_clear:
    ld  a, (limit_sw_bank_ccw)
    or  a
    rla
    ld  (limit_sw_bank_ccw), a

.isr_ls1_done:
    ld  a, (limit_sw_bank_ccw)
    cp  $FF
    jp  z, .isr_ls1_active

    ld  a, (bank_motion_state)
    cp  $04
    jp  z, .isr_ls1_force_clear
    cp  $06
    jp  z, .isr_ls1_force_clear
    jp  .isr_ls2_check

.isr_ls1_active:
    ld  a, $FF
    ld  (bank_ccw_limit_active), a
    jp  .isr_ls2_check

.isr_ls1_force_clear:
    xor a
    ld  (bank_ccw_limit_active), a
    jp  .isr_ls2_check

    ; --- Debounce limit switch: vibration CW ($F010) ---
.isr_ls2_check:
    ld  a, b
    bit 2, a
    jp  z, .isr_ls2_clear
    ld  a, (limit_sw_vib_cw)
    scf
    rla
    ld  (limit_sw_vib_cw), a
    jp  .isr_ls2_done
.isr_ls2_clear:
    ld  a, (limit_sw_vib_cw)
    or  a
    rla
    ld  (limit_sw_vib_cw), a

.isr_ls2_done:
    ld  a, (limit_sw_vib_cw)
    cp  $FF
    jp  z, .isr_ls2_active

    ld  a, (vibration_motion_state)
    cp  $01
    jp  z, .isr_ls2_force_clear
    cp  $03
    jp  z, .isr_ls2_force_clear
    jp  .isr_ls3_check

.isr_ls2_active:
    ld  a, $FF
    ld  (vib_cw_limit_active), a
    jp  .isr_ls3_check

.isr_ls2_force_clear:
    xor a
    ld  (vib_cw_limit_active), a
    jp  .isr_ls3_check

    ; --- Debounce limit switch: vibration CCW ($F011) ---
.isr_ls3_check:
    ld  a, b
    bit 3, a
    jp  z, .isr_ls3_clear
    ld  a, (limit_sw_vib_ccw)
    scf
    rla
    ld  (limit_sw_vib_ccw), a
    jp  .isr_ls3_done
.isr_ls3_clear:
    ld  a, (limit_sw_vib_ccw)
    or  a
    rla
    ld  (limit_sw_vib_ccw), a

.isr_ls3_done:
    ld  a, (limit_sw_vib_ccw)
    cp  $FF
    jp  z, .isr_ls3_active

    ld  a, (vibration_motion_state)
    cp  $04
    jp  z, .isr_ls3_force_clear
    cp  $06
    jp  z, .isr_ls3_force_clear
    jp  .isr_raw_limit_check

.isr_ls3_active:
    ld  a, $FF
    ld  (vib_ccw_limit_active), a
    jp  .isr_raw_limit_check

.isr_ls3_force_clear:
    xor a
    ld  (vib_ccw_limit_active), a
    jp  .isr_raw_limit_check

    ; --- Raw limit switch reads ($F012-$F014, from $8400) ---
.isr_raw_limit_check:
    ld  a, b
    bit 4, a
    jp  z, .isr_raw0_clear
    ld  a, (limit_raw_0)
    scf
    rla
    ld  (limit_raw_0), a
    jp  .isr_raw1_check
.isr_raw0_clear:
    ld  a, (limit_raw_0)
    or  a
    rla
    ld  (limit_raw_0), a

.isr_raw1_check:
    ld  a, b
    bit 5, a
    jp  z, .isr_raw1_clear
    ld  a, (limit_raw_1)
    scf
    rla
    ld  (limit_raw_1), a
    jp  .isr_timeout_check
.isr_raw1_clear:
    ld  a, (limit_raw_1)
    or  a
    rla
    ld  (limit_raw_1), a

    ; --- Bank timeout counter (bit 6 of watchdog port) ---
.isr_timeout_check:
    ld  a, b
    bit 6, a
    jp  z, .isr_bank_timeout_skip
    ld  hl, (bank_timeout_16bit)
    inc hl
    ld  (bank_timeout_16bit), hl

.isr_bank_timeout_skip:
    ; Only increment timeout if motor is in active states (1,3,4,6)
    ld  a, (bank_motion_state)
    or  a
    cp  $01
    jp  z, .isr_bank_timeout_active
    cp  $03
    jp  z, .isr_bank_timeout_active
    cp  $04
    jp  z, .isr_bank_timeout_active
    cp  $06
    jp  z, .isr_bank_timeout_active

    ; Not in active state: clear bank timeout
    xor a
    ld  h, a
    ld  l, a
    ld  (bank_timeout_16bit), hl

.isr_bank_timeout_active:
    or  a                            ; (from previous cp)

    ; --- Vibration timeout counter (bit 7 of watchdog port) ---
    ld  a, b
    bit 7, a
    jp  z, .isr_vib_timeout_skip
    ld  hl, (vib_timeout_16bit)
    inc hl
    ld  (vib_timeout_16bit), hl

.isr_vib_timeout_skip:
    ; Only count if vibration motor is active
    ld  a, (vibration_motion_state)
    or  a
    cp  $01
    jp  z, .isr_vib_timeout_active
    cp  $03
    jp  z, .isr_vib_timeout_active
    cp  $04
    jp  z, .isr_vib_timeout_active
    cp  $06
    jp  z, .isr_vib_timeout_active

    xor a
    ld  h, a
    ld  l, a
    ld  (vib_timeout_16bit), hl

.isr_vib_timeout_active:
    nop

    ; --- Read additional status port ($8800) ---
    ld  a, (STATUS_INPUT)
    ld  b, a

    ; Debounce raw limit switch from $8800 bit 6
    bit 6, a
    jp  nz, .isr_extra_ls_clear
    ld  a, (limit_raw_2)
    scf
    rla
    ld  (limit_raw_2), a
    jp  .isr_extra_ls_done
.isr_extra_ls_clear:
    ld  a, (limit_raw_2)
    or  a
    rla
    ld  (limit_raw_2), a

.isr_extra_ls_done:
    ; Extract misc input bits from $8800
    ld  a, b
    rrca
    rrca
    and c                            ; Note: C from exx context
    ld  (misc_input_0), a

    ld  a, b
    rrca
    rrca
    rrca
    and c
    ld  (misc_input_1), a

    ; --- Read ADC positions (alternating bank/vibration) ---
    ; Uses PPI port A bit 4 as mux select.
    ; Toggles mux each interrupt to read bank and vibration alternately.
    ld  a, (PPI_PORT_A)
    bit 4, a
    jp  nz, .isr_read_vibration_pos

    ; --- Read bank position ---
    ld  a, (CONTROL_REG)             ; Read ADC result
    ld  (bank_position), a           ; Store bank position

    ; Set mux to vibration for next cycle
    ld  a, (PPI_PORT_A)
    set 4, a                         ; Select vibration channel
    res 5, a
    res 6, a
    ld  (PPI_PORT_A), a
    nop                              ; Settling delay
    nop
    nop
    nop
    ld  a, $FF
    ld  (CONTROL_REG), a             ; Start next ADC conversion
    jp  .isr_adc_calibration

.isr_read_vibration_pos:
    ; --- Read vibration position ---
    ld  a, (CONTROL_REG)             ; Read ADC result
    ld  (vibration_position), a      ; Store vibration position

    ; Set mux back to bank for next cycle
    ld  a, (PPI_PORT_A)
    res 4, a                         ; Select bank channel
    res 5, a
    res 6, a
    ld  (PPI_PORT_A), a
    nop
    nop
    nop
    nop
    ld  a, $FF
    ld  (CONTROL_REG), a             ; Start next ADC conversion

; --- ADC calibration / centering feedback ---
; If the bank speed step counter is 0, check ADC readings and adjust
; the PWM threshold to keep the ADC reading centered around $B0.
.isr_adc_calibration:
    nop

    ; --- Bank ADC calibration ---
    ld  a, (bank_speed_step)
    or  a
    jp  nz, .isr_vib_calibration

    ; Read bank ADC
    ld  a, (ADC_BANK)
    cp  $E8                          ; Too high?
    jp  nc, .isr_bank_adc_high
    or  a
    cp  $B0                          ; Too low?
    jp  c, .isr_bank_adc_low

    ; In range: save raw value, set step counter
    ld  (bank_adc_raw), a
    ld  a, $02
    ld  (bank_speed_step), a
    ld  a, (ADC_BANK)               ; Re-read (trigger next conversion)
    jp  .isr_vib_calibration

.isr_bank_adc_low:
    ; ADC too low: decrease threshold (speed up the feedback)
    ld  a, (bank_accel_thresh)
    dec a
    ld  (bank_accel_thresh), a
    ld  (TIMER0_CNT2), a            ; Update timer divider
    ld  a, $02
    ld  (bank_speed_step), a
    ld  a, (ADC_BANK)
    jp  .isr_vib_calibration

.isr_bank_adc_high:
    ; ADC too high: increase threshold (slow down the feedback)
    ld  a, (bank_accel_thresh)
    inc a
    ld  (bank_accel_thresh), a
    ld  (TIMER0_CNT2), a
    ld  a, $02
    ld  (bank_speed_step), a
    ld  a, (ADC_BANK)

; --- Vibration ADC calibration ---
.isr_vib_calibration:
    ld  a, (vibration_speed_step)
    or  a
    jp  nz, .isr_position_compute

    ld  a, (ADC_VIBRATION)
    cp  $E8
    jp  nc, .isr_vib_adc_high
    or  a
    cp  $B0
    jp  c, .isr_vib_adc_low

    ld  (vibration_adc_raw), a
    ld  a, $03
    ld  (vibration_speed_step), a
    ld  a, (ADC_VIBRATION)
    jp  .isr_position_compute

.isr_vib_adc_low:
    ld  a, (vibration_accel_thresh)
    dec a
    ld  (vibration_accel_thresh), a
    ld  (TIMER1_CNT2), a
    ld  a, $02
    ld  (vibration_speed_step), a
    ld  a, (ADC_VIBRATION)
    jp  .isr_position_compute

.isr_vib_adc_high:
    ld  a, (vibration_accel_thresh)
    inc a
    ld  (vibration_accel_thresh), a
    ld  (TIMER1_CNT2), a
    ld  a, $02
    ld  (vibration_speed_step), a
    ld  a, (ADC_VIBRATION)

; --- Compute 16-bit positions via fixed-point multiply ---
.isr_position_compute:
    nop

    ; --- Bank 16-bit position ---
    ; Multiply bank_accel_thresh * bank_adc_raw -> 16-bit result
    ld  a, (bank_accel_thresh)
    ld  (pos_calc_divisor), a
    ld  a, (bank_adc_raw)
    ld  (pos_calc_adc_input), a
    call fixed_point_multiply
    ld  hl, (pos_calc_result)
    ld  (bank_pos_16bit), hl

    ; --- Vibration 16-bit position ---
    ld  a, (vibration_accel_thresh)
    ld  (pos_calc_divisor), a
    ld  a, (vibration_adc_raw)
    ld  (pos_calc_adc_input), a
    call fixed_point_multiply
    ld  hl, (pos_calc_result)
    ld  (vibration_pos_16bit), hl

    jp  .isr_step_countdown

; ============================================================================
; FIXED-POINT MULTIPLY SUBROUTINE ($1EFA)
; ============================================================================
; Multiplies the byte at $F100 by the byte at $F110 using bit-by-bit
; shift-and-add, producing a 16-bit result at $F120.
; Uses IX->$F100 (multiplicand), IY->$F120 (accumulator).
; ============================================================================

fixed_point_multiply:
    ld  hl, $F101
    ld  (hl), $00                    ; Clear high byte of multiplicand
    ld  bc, $0000
    ld  (pos_calc_result), bc        ; Clear 16-bit result

    ld  hl, pos_calc_adc_input       ; Point to ADC value
    ld  b, $08                       ; 8 bits to process
    ld  ix, pos_calc_divisor         ; Multiplicand
    ld  iy, pos_calc_result          ; Accumulator

.fpm_loop:
    srl (hl)                         ; Shift ADC value right, bit into carry
    call c, .fpm_add                 ; If carry set, add multiplicand
    call .fpm_shift_multiplicand     ; Shift multiplicand left
    djnz .fpm_loop
    ret

; Shift multiplicand ($F100-$F101) left by 1 bit
.fpm_shift_multiplicand:
    sla (ix+$00)                     ; Shift low byte left
    jr  c, .fpm_shift_carry
    sla (ix+$01)                     ; Shift high byte left
    ret
.fpm_shift_carry:
    sla (ix+$01)
    set 0, (ix+$01)                  ; Carry into high byte bit 0
    ret

; Add multiplicand to accumulator
.fpm_add:
    ld  a, (ix+$00)
    add a, (iy+$00)
    ld  (iy+$00), a
    call c, .fpm_add_carry           ; Handle carry to high byte
    ld  a, (ix+$01)
    add a, (iy+$01)
    ld  (iy+$01), a
    ret

.fpm_add_carry:
    ld  a, $01
    add a, (iy+$01)
    ld  (iy+$01), a
    ret

; --- Continue ISR after position computation ---
.isr_step_countdown:
    nop

    ; --- Decrement speed step counters ---
    ; These count down from their initial value to 0.
    ; At 0, the ADC calibration logic runs.
    ld  a, (STATUS_INPUT)
    ld  b, a

    ; Bank speed step countdown
    bit 4, a                         ; Check ADC busy bit
    jp  nz, .isr_vib_step_check
    ld  a, (bank_speed_step)
    dec a
    or  a
    jp  z, .isr_bank_step_zero
    ld  (bank_speed_step), a
    ld  a, (ADC_BANK)               ; Trigger conversion
    jp  .isr_vib_step_check
.isr_bank_step_zero:
    ld  a, $00
    ld  (bank_speed_step), a

.isr_vib_step_check:
    ; Vibration speed step countdown
    ld  a, b
    bit 5, a
    jp  nz, .isr_stall_detect
    ld  a, (vibration_speed_step)
    dec a
    or  a
    jp  z, .isr_vib_step_zero
    ld  (vibration_speed_step), a
    ld  a, (ADC_VIBRATION)
    jp  .isr_stall_detect
.isr_vib_step_zero:
    ld  a, $00
    ld  (vibration_speed_step), a

; --- Stall detection ---
.isr_stall_detect:
    nop

    ; Save threshold values for main loop
    ld  a, (bank_accel_thresh)
    ld  ($F100), a                   ; (reusing pos_calc_divisor temp)
    ld  a, (bank_adc_raw)
    ld  ($F110), a

    ; --- Bank stall counter ---
    ld  a, (STATUS_INPUT)
    ld  b, a
    bit 4, a                         ; ADC bank busy?
    jp  nz, .isr_vib_stall

    ; Bank ADC not busy: check/increment stall counter
    ld  a, (bank_stall_counter)
    inc a
    cp  $FF
    jp  nz, .isr_bank_stall_store
    ld  a, $FE                       ; Cap at $FE
.isr_bank_stall_store:
    ld  (bank_stall_counter), a

.isr_vib_stall:
    ; --- Vibration stall counter ---
    ld  a, b
    bit 5, a
    jp  nz, .isr_stall_evaluate

    ld  a, (vib_stall_counter)
    inc a
    cp  $FF
    jp  nz, .isr_vib_stall_store
    ld  a, $FE
.isr_vib_stall_store:
    ld  (vib_stall_counter), a

; --- Evaluate stall detection results ---
.isr_stall_evaluate:
    ; Bank: if counter >= $FE, set overcurrent flag
    ld  a, (bank_stall_counter)
    cp  $FE
    jp  nc, .isr_bank_overcurrent
    xor a
    ld  (bank_overcurrent), a
    jp  .isr_vib_stall_eval

.isr_bank_overcurrent:
    ld  a, $FF
    ld  (bank_overcurrent), a
    ld  a, $30
    ld  (bank_accel_thresh), a       ; Reset threshold on overcurrent

.isr_vib_stall_eval:
    ; Vibration: same check
    ld  a, (vib_stall_counter)
    cp  $FE
    jp  nc, .isr_vib_overcurrent
    xor a
    ld  (vibration_overcurrent), a
    jp  .isr_tick_counters

.isr_vib_overcurrent:
    ld  a, $FF
    ld  (vibration_overcurrent), a
    ld  a, $30
    ld  (vibration_accel_thresh), a

; --- Tick counters ---
.isr_tick_counters:
    ; Increment auto-center timer
    ld  hl, (autocenter_timer)
    inc hl
    ld  (autocenter_timer), hl

    ; Increment ISR tick counter
    ld  a, (isr_tick_counter)
    inc a
    ld  (isr_tick_counter), a

    ; Every 10 ticks: increment all profile indices
    cp  $0A
    jp  c, .isr_tick_done

    ; Increment all 8 motion profile indices
    ld  hl, bank_accel_index         ; $F300
    inc (hl)
    ld  hl, bank_decel_index         ; $F301
    inc (hl)
    ld  hl, bank_accel_index_b       ; $F302
    inc (hl)
    ld  hl, bank_decel_index_b       ; $F303
    inc (hl)
    ld  hl, vib_accel_index          ; $F304
    inc (hl)
    ld  hl, vib_decel_index          ; $F305
    inc (hl)
    ld  hl, vib_accel_index_b        ; $F306
    inc (hl)
    ld  hl, vib_decel_index_b        ; $F307
    inc (hl)

    xor a
    ld  (isr_tick_counter), a        ; Reset tick counter

.isr_tick_done:
    ; Increment motion sequence timers
    ld  hl, motion_phase_timer       ; $F319
    inc (hl)
    ld  hl, motion_hold_timer        ; $F31A
    inc (hl)

    ; --- Restore registers and return ---
    exx
    ex  af, af'
    ei
    reti

; --- End of ISR. Remaining bytes to $1FFF ---

; Trailing bytes in ROM (filler/unused)
    .db $C7, $C7, $C7, $C7, $C7     ; $1FFB-$1FFF: RST $00 opcodes (filler)

; ============================================================================
; END OF ROM CODE/DATA ($2000)
; ============================================================================
; The remaining $2000-$7FFF (24KB) is all $FF padding and is not included
; in this source file. The ROM is a 27C256 (32KB) but only the first 8KB
; ($0000-$1FFF) contains actual firmware.
; ============================================================================
