# Mike Tyson's Punch-Out!! 2P Versus hack

This hack lets a second player control the opponent boxer.

**Base ROM:** Mike Tyson's Punch-Out!! (Japan, USA) (Rev A)
- SHA-1 `0f0c2c2e294ff8ce255a618964728c935fd8963b`
- iNES file with a 16-byte header, mapper 9 (MMC2)

## Turning on 2-player mode

- Plug in a second controller.
- During a fight, press **Start on controller 2**. A short tone confirms that player 2 now controls the opponent.
- Press Start on controller 2 again to give the opponent back to the computer. It plays a different tone.
- 2-player mode stays on from fight to fight until it is toggled off or the console is reset.
- If nobody presses Start on controller 2, the game plays exactly like the original.

## Player 2 controls

| Input | Action |
|---|---|
| B | Punch 1 (usually a jab) |
| A | Punch 2 (usually a hook) |
| Up + B / Up + A | Alternate punches (uppercut, smash, etc.) |
| Down + B / Down + A | More punches, for boxers that have them |
| Select | Special move (see below) |
| Left or Right | Dodge |
| Hold Up | High guard: blocks Mac's face punches, leaves the body open |
| Up not held | Low guard: blocks body punches, leaves the face open |

These rules apply to player 2's moves:

- Moves start only when the opponent is standing idle, the same way the computer's moves do. A button pressed slightly early is remembered for 8 frames.
- Every punch keeps its original animation, wind-up, hit timing, damage and weak spots. Mac can dodge, block and counter as usual.
- A dodge works only with good timing. Press it within about 10 frames of Mac starting a punch.

## Special moves (Select)

| Boxer | Select |
|---|---|
| Glass Joe | Backs up, then lunges with a jab |
| Von Kaiser | (none) |
| Piston Honda 1 and 2 | Honda Rush: backs up, then 4 alternating punches |
| Don Flamenco 1 and 2 | Taunt |
| King Hippo | Taunt |
| Great Tiger | Tiger punch. It knocks Mac down if it lands. |
| Bald Bull 1 and 2 | Bull Charge. It knocks Mac down if it lands. |
| Soda Popinski | Taunt |
| Mr. Sandman | Dreamland Express uppercut (also on Down+B) |
| Super Macho Man | Spinning punch |
| Mike Tyson | Uppercut. It knocks Mac down if it lands. |

The move names come from what each animation does in the game: how much damage it deals and how it looks in captured frames. Some labels, especially the taunts, may not match the official names.

## How it works

The opponent's behavior is normally driven by "behavior scripts". These choose which animation to play next (jab, hook, taunt, pause, and so on). Separately, a defense routine decides when to dodge and which guard to hold. The hack changes two `JSR`s in the fight loop:

| Address | Original | New |
|---|---|---|
| `$A69F` | `JSR $C291` (defense AI) | `JSR DefHook` |
| `$A6A2` | `JSR $B196` (behavior script) | `JSR AtkHook` |

In 1-player mode, both hooks jump straight to the original routines.

In 2-player mode, the hooks work like this:

- **`AtkHook`** reads controller 2 and asks for the matching animation through the game's normal request byte (`$90 = $80 | anim`). Only idle opponents can start a move.
- **`DefHook`** sets the guard with the game's own guard-switch flag (`$04FF`). It also starts the dodge animation (`$83`) on Left/Right.
- **`Unstick`** covers two jobs the behavior scripts would normally do:
  - It returns a dodge to idle when Mac never punched, or when the dodge runs too long (some dodges wait for Mac to do something a tired Mac never does).
  - It restarts the round clock when both boxers have been standing idle with the clock stopped.

- **Tired Mac:** Mac normally recovers from being tired (pink, out of hearts) by dodging or blocking the opponent's punches. Player 2 might never punch, so each 2 seconds that both boxers stand idle counts as one dodge. Mac recovers after about 2–8 seconds, depending on the opponent.

**Free space and RAM used:**
- Code and tables sit at `$F900–$FBA5` of the fixed bank, which was all zeros.
- RAM `$23–$2F` is used; the original game never writes it after boot.

**Move tables:** `moves.py` holds the move tables. Each opponent has 8 slots: B, A, U+B, U+A, D+B, D+A, Select, and one unused. Each slot holds an opponent animation ID. Multi-part moves (Glass Joe's lunge, the Honda Rush) are listed in `SEQ`. If Mac lands a hit, the rest of the sequence is cancelled. Edit the table and rebuild to remap moves.

**Tuning values** are also in `moves.py`:
- `CD_ATTACK`: idle frames required between moves
- `CD_DODGE`: idle frames after a dodge
- `DODGE_LOCK`: how long after a move before dodging is allowed
- `BUF_FRAMES`: how long an early button press is remembered
- `SFX_ON` / `SFX_OFF`: the toggle sounds
- `CLOCK_RESTART`: idle frames before the stopped clock restarts
- `TIRED_RECOVER`: quiet frames (both boxers idle) that count as one dodge for a tired Mac
- `DODGE_MAXWAIT` / `DODGE_HARDMAX`: longest a dodge can last while Mac isn't punching / at all

## Building

You need cc65 (ca65 and ld65) and Python 3.

```
CC65BIN=/path/to/cc65/bin python3 build.py original.nes output.nes
python3 mkips.py original.nes output.nes patch.ips
```

## Known limits

- A few computer-only behaviors are skipped in 2-player mode. Examples are scripted pauses, some star-punch openings, and special patterns tied to the clock, such as Tyson's first 90 seconds. Every animation still works normally.
- The pre-fight intro and the knockdown get-up rules are unchanged.
- Testing was done in an emulator, using scripted inputs on both controllers for all 14 fights. It has not been tested on real hardware yet.

## Changes

- **v1.3:** Piston Honda's Select is now the full Honda Rush, as in the original game: he backs up, then throws 4 alternating punches. Moves can now be sequences of any length.
- **v1.2:** A tired Mac now recovers on his own if both boxers stand idle. Before, he stayed pink forever when player 2 didn't punch.
- **v1.1:** Fixed a freeze where a dodge could hang forever while Mac was tired (pink). When this happened, Start on controller 2 seemed to stop working, because neither player 2 nor the computer can act until the dodge ends. Dodges now always end.
- **v1.0:** First release.

## Passwords

The hack doesn't change how passwords work.
- Entering the well-known codes gives the same result as in the original, for example 007 373 5963 (Tyson) and 005 737 5423.
- With the same fight record, the original, the hack in 1-player mode and the hack in 2-player mode all give the same password. In my test that was 069 733 5423 after a 1-0, 1 KO record.

The password the game shows encodes Mac's career wins, losses and KOs. The codes in guides assume a perfect record (every fight won by KO). Any loss, decision win or TKO, which happens a lot in 2-player fights, gives a different code. That code still works and restores that exact record.
