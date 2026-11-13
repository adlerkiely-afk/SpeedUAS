# TR-xx: Static thrust, <configuration>

**Procedure:** TP-02.  **Date:**  **Operator:**

Label every number: **measured** (from this test), **calculated** (derived from measured values) or
**datasheet**. Leave blanks blank; do not fill gaps with estimates.

## Configuration

| | |
|---|---|
| Motor | |
| Prop (and condition) | |
| Spinner (revision, material, mass) | none / |
| ESC and firmware version | |
| Flight controller and Betaflight version | |
| Battery (and number of packs used) | |
| Rig parts and revision | |
| Nano firmware commit | |
| Load cell calibration record | `CAL_<date>.md`, slope |
| Current scale and how it was calibrated | |
| ESC temperature source | telemetry wire / extended DShot / by hand |
| Data files | `test/data/` |

## Conditions

| | |
|---|---|
| Air temperature (°C) | |
| Pressure (Pa) | |
| Air density (kg/m^3), calculated | |
| Idle current, motors stopped (A) | |
| USB-loss check result | |

## Run A: staircase (mean of three sweeps)

| Slider | Thrust (g) | Spread (%) | Current (A) | Voltage (V) | Power (W) | g/W | rpm | CT |
|---|---|---|---|---|---|---|---|---|
| 1125 | | | | | | | | |
| 1250 | | | | | | | | |
| 1375 | | | | | | | | |
| 1500 | | | | | | | | |
| 1625 | | | | | | | | |
| 1750 | | | | | | | | |
| 1875 | | | | | | | | |
| 2000 | | | | | | | | |

Steps not run, and why:

## Run B: thermal hold

| Slider | Duration (s) | Current (A) | ESC temperature start / end (°C) | Rise (°C) |
|---|---|---|---|---|
| | | | | |

## Run C: full-power hold

| Slider | Duration (s) | Thrust start / end (g) | Current (A) | Voltage start / end (V) | ESC temperature end (°C) |
|---|---|---|---|---|---|
| | | | | | |

## Against the design values

| Quantity | Design value | Source of design value | Measured | Difference |
|---|---|---|---|---|
| Full-throttle static thrust per motor | 1,980 g | datasheet | | |
| Full-throttle current per motor | 54 to 61 A | datasheet | | |
| Throttle at 55 A | unknown | n/a | | n/a |
| Full-throttle rpm, static | unknown | n/a | | n/a |

## Spinner qualification (Run S), if run

| Check | Result |
|---|---|
| Spinner mass before / after (g) | |
| Balance check done, and how | |
| Inspection after step 4 | |
| Inspection after step 6 | |
| Inspection after step 8 | |
| Inspection after each endurance hold | |
| Final inspection, spinner removed | |
| Highest rpm reached (qualification limit) | |

| Slider | Vibration at rotor frequency, bare prop | With spinner | Ratio | Thrust change at same rpm (%) |
|---|---|---|---|---|
| | | | | |

**Verdict:** pass / fail, qualified to ____ rpm static. Not qualified for flight rpm above that.

## Aborts and anomalies

## Photos

Label each as a photo of real hardware, with the date.

## Conclusions

What was measured, what it changes in the design or the top-speed model, and what is still unknown.
