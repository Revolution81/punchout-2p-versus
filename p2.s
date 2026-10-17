; =====================================================================
; Mike Tyson's Punch-Out!! (USA Rev A) - Player 2 controls the opponent
; Assembled with ca65, placed in unused space of the fixed bank at $F900.
;
; Hooks (patched by build.py):
;   $A69F  jsr $C291  -> jsr DefHook   (opponent defense AI, every fight frame)
;   $A6A2  jsr $B196  -> jsr AtkHook   (opponent behavior script, every fight frame)
; =====================================================================

; ---- game RAM ----
OPPNUM   = $01      ; opponent number 0-13
BEHAV_ON = $38      ; behavior scripts enabled (fight is live, nobody down)
ANIM     = $90      ; opponent animation: write $80|id to request
ANIMTMR  = $92
PAD2     = $D1      ; debounced controller 2 buttons (A B Sel St U D L R)
GUARD    = $04FF    ; opponent guard: 0 = low (body), 1 = high (face); bit7 = change pending
SFX      = $F0      ; sound effect request
MACPUNCH = $99      ; set when Mac throws a punch (read by the AI)
ANIMSYNC = $91      ; opponent animation sync state ($83 = waiting for Mac)
MACSYNC  = $51      ; Mac's animation sync state (bit7 = in the middle of a move)
MACANIM  = $50      ; Mac's animation ($01 = idle)
CLOCKCTL = $0301    ; bit0 = clock stopped
OPP_IDLE = $B651    ; puts the opponent back to idle
MACFRESH = $BC      ; 0 while Mac is tired (pink, out of hearts)
DODGE_CREDIT = $05A0 ; recovery credit for dodging a punch (negative)
MAC_RECOVER = $84B9 ; (bank 7) add A to Mac's tiredness, recover at 0
BANK7    = $AA3C    ; map bank 7 at $8000
BANK_OPP = $AA48    ; map the opponent's bank back

; ---- RAM used by this hack (unused by the original game) ----
P2FLAG   = $2A      ; bit7 = player 2 controls the opponent
P2PREV   = $2B      ; pad 2 last frame
P2NEW    = $2C      ; pad 2 buttons newly pressed this frame
P2CD     = $2D      ; cooldown frames before next move
P2Q      = $2E      ; position in SeqData of the next combo move (0 = none)
P2TMP    = $2F
P2BUF    = $29      ; buffered move slot+1 (pressed while busy)
P2BUFT   = $28      ; frames left on the buffer
P2IDLE   = $27      ; frames both boxers idle with the clock stopped
P2QOPP   = $26      ; opponent the queued move belongs to
P2DWAIT  = $25      ; frames the dodge has been waiting for Mac
P2TIRED  = $24      ; quiet frames while Mac is tired
P2LAST   = $23      ; last move started by player 2

BTN_A = $80
BTN_B = $40
BTN_SEL = $20
BTN_ST = $10
BTN_U = $08
BTN_D = $04
BTN_L = $02
BTN_R = $01

ORIG_DEF = $C291
ORIG_BEH = $B196

.include "tuning.inc"

.export DefHook, AtkHook, MoveTbl, NextTbl
.segment "CODE"

; ---------------------------------------------------------------------
; DefHook - runs every fight frame in place of the defense/guard AI.
; ---------------------------------------------------------------------
DefHook:
        lda PAD2                ; edge-detect controller 2
        tay
        eor P2PREV
        sta P2TMP
        tya
        and P2TMP
        sta P2NEW
        sty P2PREV

        lda P2NEW               ; Start on controller 2 toggles 2P mode
        and #BTN_ST
        beq @nostart
        lda P2FLAG
        eor #$80
        sta P2FLAG
        ldx #SFX_ON
        bit P2FLAG
        bmi :+
        ldx #SFX_OFF
:       stx SFX
        lda #0
        sta P2Q
        sta P2BUF
@nostart:
        bit P2FLAG
        bmi @p2
        jmp ORIG_DEF            ; 1P: original AI

@p2:    lda #0
        sta MACPUNCH            ; AI reaction event (unused in 2P mode)
        jsr Unstick
        lda ANIM                ; only while the opponent is standing idle
        cmp #$01
        bne @rts
        lda BEHAV_ON
        beq @rts

        ; ---- dodge: Left / Right ----
        lda P2NEW
        and #(BTN_L|BTN_R)
        beq @guard
        lda P2CD
        cmp #DODGE_LOCK         ; can't dodge right after a move
        bcs @guard
        lda #$83
        sta ANIM
        lda #$01
        sta ANIMTMR
        lda #CD_DODGE
        sta P2CD
        lda #0
        sta P2Q
        sta P2BUF
@rts:   rts

        ; ---- guard: hold Up = high guard, otherwise low guard ----
@guard: ldx #0
        lda PAD2
        and #BTN_U
        beq :+
        inx
:       stx P2TMP
        lda GUARD
        and #$7F
        cmp P2TMP
        beq @rts
        txa
        ora #$80
        sta GUARD
        rts

; ---------------------------------------------------------------------
; AtkHook - runs every fight frame in place of the behavior script.
; ---------------------------------------------------------------------
AtkHook:
        bit P2FLAG
        bmi @p2
        jmp ORIG_BEH

@p2:    ; remember a move pressed while busy, for a few frames
        jsr ReadMove
        bcc @nopress
        stx P2BUF
        lda #BUF_FRAMES
        sta P2BUFT
@nopress:
        lda P2BUFT
        beq :+
        dec P2BUFT
        bne :+
        lda #0
        sta P2BUF
:
        lda BEHAV_ON
        bne :+
        sta P2Q                 ; fight not live: forget queued moves
        sta P2BUF
        rts
:       lda ANIM                ; anything but our own move (a hit, a
        and #$7F                ; knockdown...) cancels the rest of a combo
        cmp #$01
        beq :+
        cmp P2LAST
        beq :+
        lda #0
        sta P2Q
:       lda ANIM
        cmp #$01
        bne @rts

        ldx P2Q                 ; next move of a combo plays right away
        beq @cd
        lda P2QOPP              ; ...but only against the same opponent
        cmp OPPNUM
        bne @qend
        lda SeqData,x
        beq @qend
        inc P2Q
        jmp @play
@qend:  lda #0
        sta P2Q

@cd:    lda P2CD
        beq @ready
        dec P2CD
@rts:   rts

@ready: ldx P2BUF
        beq @rts
        lda #0
        sta P2BUF
        sta P2BUFT
        dex
        stx P2TMP
        lda OPPNUM
        cmp #14
        bcs @rts
        asl a
        asl a
        asl a
        ora P2TMP
        tax
        lda NextTbl,x
        sta P2Q
        lda OPPNUM
        sta P2QOPP
        lda MoveTbl,x
        beq @rts
@play:  sta P2LAST
        ora #$80
        sta ANIM
        lda #$01
        sta ANIMTMR
        lda #CD_ATTACK
        sta P2CD
        rts

; ---------------------------------------------------------------------
; Unstick - things the opponent's behavior scripts normally take care of.
; ---------------------------------------------------------------------
Unstick:
        ; A dodge ends by waiting for Mac's punch to finish. The CPU only dodges
        ; when Mac punches, but player 2 can dodge any time, so let it go back
        ; to idle once Mac is standing idle.
        lda ANIM
        and #$7F
        cmp #$03
        beq :+
        cmp #$04
        bne @nododge
:       inc P2DWAIT             ; frames spent in the dodge
        lda P2DWAIT
        cmp #DODGE_HARDMAX      ; never stay in a dodge forever
        bcs @release
        lda MACSYNC             ; Mac in the middle of a move? let it finish
        bmi @clock
        lda ANIMSYNC            ; dodge finished and waiting for Mac
        cmp #$83
        beq @release
        lda P2DWAIT             ; dodge still running after the normal length
        cmp #DODGE_MAXWAIT      ; (some wait on things Mac never does)
        bcc @clock
@release:
        jsr OPP_IDLE
@nododge:
        lda #0
        sta P2DWAIT
@clock: ; The clock is sometimes stopped until the opponent's next taunt
        ; restarts it. Restart it if both boxers stand idle for a while.
        lda CLOCKCTL
        cmp #$01
        bne @reset
        lda ANIM
        cmp #$01
        bne @reset
        lda MACANIM
        cmp #$01
        bne @reset
        lda BEHAV_ON
        beq @reset
        inc P2IDLE
        lda P2IDLE
        cmp #CLOCK_RESTART
        bcc @done
        lda #$00
        sta CLOCKCTL
@reset: lda #$00
        sta P2IDLE
@done:
        ; Mac recovers from being tired by dodging or blocking the opponent's
        ; punches. The CPU always throws some; player 2 might not. While both
        ; boxers stand around, count the quiet time as a dodge now and then.
        lda MACFRESH            ; 0 = Mac is tired
        bne @trst
        lda BEHAV_ON
        beq @trst
        lda ANIM
        cmp #$01
        bne @trst
        lda MACSYNC
        bmi @trst
        inc P2TIRED
        lda P2TIRED
        cmp #TIRED_RECOVER
        bcc @tdone
        jsr BANK7
        lda DODGE_CREDIT        ; same credit as dodging a punch
        jsr MAC_RECOVER
        jsr BANK_OPP
@trst:  lda #0
        sta P2TIRED
@tdone: rts

; ReadMove: carry set and X = slot+1 if an attack button was just pressed.
; slots: 0 B, 1 A, 2 Up+B, 3 Up+A, 4 Down+B, 5 Down+A, 6 Select
ReadMove:
        lda P2NEW
        and #(BTN_A|BTN_B|BTN_SEL)
        beq @none
        ldx #7
        and #BTN_SEL
        bne @got
        ldx #1
        lda P2NEW
        and #BTN_A
        beq :+
        inx
:       lda PAD2
        and #BTN_U
        beq :+
        inx
        inx
        bne @got
:       lda PAD2
        and #BTN_D
        beq @got
        inx
        inx
        inx
        inx
@got:   sec
        rts
@none:  clc
        rts

.include "moves.inc"
