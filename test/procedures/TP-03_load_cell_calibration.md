# TP-03: Load cell calibration (bench rig)

**Purpose:** find the grams-per-count slope of the thrust stand's load cell, and check its linearity,
hysteresis and zero return, before any thrust number from the rig is trusted.

**Status:** procedure written 2026-11-13. **Not yet performed.** The pass limits below are targets chosen
before the first run; revise them once real data exists.

**Equipment:** bench rig with the calibration pan fitted in place of the motor, 5 kg bar load cell, HX711,
Arduino Nano running `firmware/thrust_stand`, a serial terminal at 115200 baud (line ending: Newline),
calibration masses, a kitchen or pocket scale to check the masses.

## Masses

Thrust expected at full throttle is about 1,980 g (datasheet value, not measured), so calibrate to 2,500 g.

| Buy | Makes these steps |
|---|---|
| 1 x 200 g, 1 x 500 g, 2 x 1000 g | 0, 200, 500, 1000, 1500, 2000, 2500 g |

Weigh each mass on a scale first and use the weighed value in the `c` command, not the nominal one.
Seven steps up and six back down is 13 points; the firmware holds 16.

## Safety

- Battery disconnected from the ESC. Motor and prop removed (the pan is in their place).
- The rig stands on its end for this. Clamp or brace it so 2.5 kg on the pan cannot tip it over.

## Setup

1. Stand the rig so the thrust axis is vertical and the masses push the bracket **the same way thrust
   will** (thrust acts on the motor opposite to the direction the air leaves). The pan must load the
   bracket on the motor axis.
2. Check the load-cell bolts and bracket bolts are tight. Nothing may touch the cell or bracket except
   its own mounts; route the cable so it hangs slack.
3. Power the Nano and leave it on for 10 minutes before taking readings.
4. Send `r`. Record the sample rate. About 80 Hz means the RATE jumper is cut; about 10 Hz means it is not.

## Procedure

1. `h` to stop the stream. `x` to clear old points.
2. Empty pan, rig still: `t` to tare.
3. `c 0`.
4. Load up. For each step: place the mass gently, wait 5 s, send `c <total grams on the pan>`.
5. At 2,500 g, do the creep check: `g` to start the stream, note `grams` straight away and again after
   60 s, then `h`. (Before the first calibration is saved the column reads `nan`; note `raw` instead.)
6. Load down. Remove masses in reverse order, waiting 5 s and sending `c <total>` at each step, finishing
   with `c 0` on the empty pan.
7. `p`. Copy the whole printout into the record sheet or save it as text next to the sheet.
8. If the results pass, `s` to save the slope.
9. Check: `t`, then `g`, place the 1000 g mass and note `grams`. Remove it and note the zero reading.

## Working out the results

- **Linearity:** the worst `residual_g` in the `p` printout. The firmware fits one straight line through
  all points, up and down.
- **Hysteresis at each mass:** residual on the way down minus residual on the way up.
- **Zero return:** residual of the final `c 0` minus residual of the first `c 0`.
- **Creep:** change in reading over 60 s at 2,500 g.
- **Check error:** (reading with 1000 g on the pan minus the weighed mass) / weighed mass x 100 %.

To convert to force: thrust in N = grams x 9.81 / 1000.

## Pass limits (targets)

| Check | Limit |
|---|---|
| Sample rate | 75 to 85 Hz |
| Worst residual | 5 g or less (0.2 % of 2,500 g) |
| Worst hysteresis | 5 g or less |
| Zero return | 2 g or less |
| Creep in 60 s at 2,500 g | 3 g or less |
| 1000 g check after saving | within 1 % |

If a check fails: look for something touching the cell, a loose bolt, a taut cable or the rig rocking,
fix it, and repeat from step 1. Do not save a failing calibration.

## When to repeat

- Full calibration: after the load cell, block or bracket is removed or re-bolted, and before each test
  campaign.
- Quick check (step 9 only): at the start of every test session. If it is off by more than 1 %, do the
  full calibration.

---

## Record sheet

Copy this section into `test/reports/` as `CAL_<date>.md` and fill it in.

| | |
|---|---|
| Date | |
| Operator | |
| Rig parts and revision | |
| Load cell / HX711 | SEN-14729 / SEN-13879 |
| Firmware commit | |
| Room temperature (°C) | |
| Warm-up time (min) | |
| Sample rate from `r` (Hz) | |
| Scale used to weigh the masses | |

**Points** (from the `p` printout)

| # | Direction | Mass on pan, weighed (g) | raw | residual (g) |
|---|---|---|---|---|
| 1 | up | 0 | | |
| 2 | up | | | |
| 3 | up | | | |
| 4 | up | | | |
| 5 | up | | | |
| 6 | up | | | |
| 7 | up | | | |
| 8 | down | | | |
| 9 | down | | | |
| 10 | down | | | |
| 11 | down | | | |
| 12 | down | | | |
| 13 | down | 0 | | |

**Hysteresis**

| Mass (g) | Residual up (g) | Residual down (g) | Down minus up (g) |
|---|---|---|---|
| 0 | | | |
| 200 | | | |
| 500 | | | |
| 1000 | | | |
| 1500 | | | |
| 2000 | | | |

**Results**

| Check | Value | Limit | Pass / fail |
|---|---|---|---|
| Slope, g per count | | n/a | n/a |
| Worst residual (g) | | 5 | |
| Worst hysteresis (g) | | 5 | |
| Zero return (g) | | 2 | |
| Creep, 60 s at 2,500 g (g) | | 3 | |
| 1000 g check (%) | | 1 | |

Saved to EEPROM (`s`): yes / no

Notes:
