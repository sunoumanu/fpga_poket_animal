# Poket Animal on the Tang Nano 20K

Hardware prototype of the Tiny Tapeout submission on a Sipeed Tang Nano 20K
(GW2AR-LV18QN88C8/I7). The Tiny Tapeout core (`src/project.v` at the repo root)
is instantiated **unchanged**; `src/top.v` here only adapts it to the board
(clock, buttons, LEDs, reset) — so what you see on the board is what the ASIC
will do, just 2.7× faster (27 MHz crystal vs. the recommended 10 MHz; all of
the pet's time constants are clock-proportional).

## Building

With the Gowin IDE (Education edition works, no license needed for GW2AR-18):
open `tangnano20k.gprj` and run Synthesize → Place & Route. If the IDE asks for
a top module, it is `top`.

From the command line:

```sh
cd fpga/tangnano20k
gw_sh build.tcl        # e.g. C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe
```

The bitstream lands in `impl/pnr/poket_animal.fs`.

## Programming

Either of:

- **Gowin Programmer** (installed next to the IDE): scan USB, pick
  *SRAM Program* (volatile, for trying it out) or *embFlash Erase, Program*
  (survives power cycles), point it at `impl/pnr/poket_animal.fs`.
- **openFPGALoader**: `openFPGALoader -b tangnano20k impl/pnr/poket_animal.fs`
  (add `-f` to write flash instead of SRAM).

## Controls (on-board)

| Control            | Action                                                    |
| ------------------ | --------------------------------------------------------- |
| S1                 | feed (one press = one meal)                               |
| S2                 | pet (the pet wiggles happily)                             |
| S1 + S2 held ~1.2 s | reset — revives a dead pet (released only after you let go of both buttons, so the fresh pet doesn't get force-fed) |

## Status LEDs (on-board, lit = active)

| LED  | Meaning              |
| ---- | -------------------- |
| LED0 | alive                |
| LED1 | heartbeat (speeds up with hunger, stops when dead) |
| LED2 | sick                 |
| LED3 | wiggle (being petted) |
| LED4 | hunger bit 0         |
| LED5 | hunger bit 1         |

## The face: external 7-segment digit

Wire a **common-cathode** 7-segment digit to header J6 (pin numbers are printed
on the board silkscreen). Put a ~330 Ω resistor in series with each segment;
common cathode goes to any GND pin.

| Board pin (J6) | Signal | Board pin (J6) | Signal |
| -------------- | ------ | -------------- | ------ |
| 25             | seg a  | 29             | seg e  |
| 26             | seg b  | 30             | seg f  |
| 27             | seg c  | 31             | seg g  |
| 28             | seg d  | 77             | dp     |

Faces: chasing segment = content/playing, `-` = peckish, blinking `H` = hungry,
fast-blinking `F` = starving, `b` + queasy dp = sick (overfed), `d` + steady
dp = dead. The dp blips when the pet noms a meal.

The board is usable without the display — the LEDs tell you everything except
which face it's making.

## Speed select and debug pins

| Board pin | Signal      | Default                          |
| --------- | ----------- | -------------------------------- |
| 48 (J5)   | speed bit 0 | 1 (internal pull-up)             |
| 41 (J5)   | speed bit 1 | 0 (internal pull-down)           |
| 42 (J5)   | reset       | short to GND to reset/revive     |
| 85 (J6)   | tick        | one-clock pulse per hunger tick (scope) |
| 80 (J5)   | cause of death | 0 = starved, 1 = overfed (valid when dead) |

Default speed is `01` (needy pet). Timings at the board's 27 MHz clock:

| speed (bit1, bit0) | Jumpers               | Hunger tick | Mode      |
| ------------------ | --------------------- | ----------- | --------- |
| `00`               | pin 48 → GND          | ~42 min     | real pet  |
| `01`               | none (default)        | ~9.9 s      | needy pet |
| `10`               | 41 → 3V3, 48 → GND    | ~155 ms     | lifecycle demo (blink and you miss it) |
| `11`               | 41 → 3V3              | 64 clocks   | **simulation only — don't use**: it shrinks the button debounce to 2 clocks, so real switch bounce will stuff the pet to death |

**Do not move inputs onto pins 13, 71–76 or 86.** Those header pins double as
the HSPI link to the on-board BL616 USB/JTAG MCU, whose firmware can actively
drive them — strong enough to defeat the FPGA's internal pull resistors. (The
first revision of this port had the speed jumpers on 71/72; the BL616 drove
the speed select to a fast mode and the pet starved to death within
microseconds of power-up.) Pins 41/42/48 only reach the unpopulated LCD
connector, and 80/85 only the empty microSD slot, so they float cleanly.

Button debounce at 27 MHz is ~2.4 ms (vs ~6.6 ms at the ASIC's 10 MHz) —
still plenty for real switches.

## Board facts baked into the port

From the Tang Nano 20K v1.2 schematic (`Tang_Nano_20K_3921`):

- 27 MHz oscillator → FPGA pin 4.
- S1 = pin 88, S2 = pin 87 (the MODE0/MODE1 config pins). Both buttons switch
  the pin to +3V3 through 330 Ω → **active high**; the constraints enable
  internal pull-downs. If buttons ever appear dead or inverted on a different
  board revision, revisit the `PULL_MODE` on pins 87/88 in
  `src/tangnano20k.cst` and the polarity in `src/top.v`.
- The six orange LEDs (pins 15–20) have their anodes at +3V3 through 510 Ω →
  **active low**; `top.v` inverts them.

## Build results (Gowin 1.9.11.03, this repo)

Fmax 162 MHz against the 27 MHz constraint, zero setup/hold violations;
284 LUTs, 144 registers (~2% of the GW2AR-18). The PR1014 warning about
generic routing on `clk_d` is the hop from pin 4 (not a dedicated clock pad)
onto the global clock network — benign at this margin.
