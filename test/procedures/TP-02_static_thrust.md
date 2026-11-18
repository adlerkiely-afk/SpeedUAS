# TP-02: Static thrust, current and spinner qualification (bench rig)

**Purpose:**
1. Measure static thrust, current, voltage, RPM and ESC temperature for one motor and prop.
2. Compare full-throttle thrust with the 1,980 g per motor design value (datasheet, not measured).
3. Find the throttle at which one motor draws 55 A, the ESC's continuous rating.
4. Qualify the printed spinner on the bench before it is ever flown.

**Status:** rewritten 2026-11-13. **Not yet performed.** Hold times, limits and pass criteria are targets
chosen before any data exists.

**Configuration under test:** AOS Supernova 2207 1980KV, HQ 5x4.5x3 V1S, T-Motor F55A Pro II + F7,
GNB 1300 mAh 6S HV.

## Before the first run

| Prerequisite | Where |
|---|---|
| Load cell calibrated and passed, same rig assembly | TP-03, `CAL_<date>.md` |
| Betaflight checklist complete | `docs/betaflight-bench-setup.md` |
| Current reading calibrated against a meter | same |
| Nano log saving to a file on the laptop | `firmware/README.md` |
| **USB-loss check done (below)** | this page |

**USB-loss check (props off, once per firmware version).** Run the bench motor at low throttle from the
Motors tab and pull the USB cable. Record whether the motor stops. If it keeps running, the battery
connector is the only stop, and every run needs a second person at the battery lead.

## Safety

A 5 inch prop at full throttle on 6S turns at roughly 30,000 rpm or more (calculated). A blade or a printed
part that lets go leaves **in the plane of the prop**.

- Rig clamped to the bench in two places. Pull on it by hand before every session.
- Nobody stands in the prop plane, ever. Operator and laptop are behind the rig or well to the side of
  the plane. For spinner runs, put a solid barrier between the prop plane and anyone in the room.
- Eye protection for everyone in the room. Hearing protection for the operator.
- New or undamaged prop only. Check the blades for nicks and the nut for tightness before every run.
- Wires, sleeves and cables tied down. Nothing loose on the bench that prop wash can move.
- The battery lead is reachable without crossing the prop plane. Disconnect the battery before touching
  the motor, prop or spinner, every time.
- LiPo on a non-flammable surface, never left connected unattended. Sand or a suitable extinguisher
  within reach.
- Do not raise or disable any ESC, Betaflight or battery protection.

## Abort limits

Slider to zero at once, then disconnect the battery, if any of these happens:

| Limit | Value |
|---|---|
| Current, sustained in a hold | 55 A. Do not step higher; record the throttle |
| Pack voltage under load | 21.0 V (3.5 V per cell) |
| ESC temperature | 80 °C |
| Thrust | 4,500 g (load cell is rated 5 kg) |
| Anything else | New noise or vibration, rig moving, smell, smoke, a log stopping |

## Throttle profile

Throttle is the Motors tab slider value for the bench motor only (1000 = stopped, 2000 = full). Move the
slider fast and then leave it; the blackbox records the value actually commanded.

**Sync blip (start of every run):** 1000 → 1250 for 1 s → 1000 for 2 s. This gives both logs one clean
edge to line up on.

**Run A, staircase:** 4 s at each of

| Step | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Slider | 1125 | 1250 | 1375 | 1500 | 1625 | 1750 | 1875 | 2000 |

then straight to 1000. About 35 s in total. Estimated charge used: under 200 mAh (calculated from
datasheet current, cube-law assumption).

**Run B, thermal hold:** 30 s at the step in Run A that drew closest to 30 A.

**Run C, full-power hold:** 10 s at the highest step that stayed at or under 55 A in Run A.

## Procedure

1. Record air temperature and pressure. Air density rho = pressure in Pa / (287.05 x temperature in K).
2. Record the pack's resting voltage. Start each run above 25.0 V (4.17 V per cell); if only one pack is
   available, rest it 2 minutes between runs and record the starting voltage each time.
3. Erase the blackbox flash. Start the Nano log to a new file. Send `t` with the motor stopped.
4. Motors tab: tick the safety box (logging starts). Send `m` to the Nano.
5. Sync blip, then the run profile, watching current, voltage and temperature against the abort limits.
6. Slider to 1000, untick the box, **disconnect the battery**.
7. Stop the Nano log. Download the blackbox log.
8. Name both files `<date>_<config>_<run><n>` (for example `2026-11-20_bareprop_A1`) and put them in
   `test/data/` with the Betaflight `dump` for the session.
9. Check the thrust reading returned to within 5 g of zero. If not, find out why before the next run.
10. Run A three times. Then Run B once and Run C once.

## Data reduction

For each hold, discard the first 1.5 s and the last 0.25 s and average the rest.

| Quantity | From | Formula |
|---|---|---|
| Thrust T (N) | Nano | grams x 9.81 / 1000 |
| Current I (A) | blackbox | reading minus the idle current with motors stopped |
| Voltage V (V) | blackbox | |
| Electrical power P (W) | | V x I |
| Efficiency (g/W) | | grams / P |
| Speed n (rev/s) | blackbox eRPM | logged value x 100 / 7 / 60 |
| Thrust coefficient CT | | T / (rho x n^2 x D^4), D = 0.127 m |
| Voltage sag (V) | | resting voltage minus V in the hold |
| ESC temperature rise (°C) | blackbox debug | end of hold minus start of run |
| Vibration | blackbox gyro | amplitude spectrum per hold; note the peak at the rotor frequency n |

Repeatability target: thrust at each step within 3 % across the three Run A sweeps.

## Spinner qualification (Run S)

**Do not start until** the threaded shaft length above the prop hub has been measured and the spinner is
confirmed to engage it as designed, and the spinner is printed in the flight material.

**What this does and does not cover.** A static run reaches a lower rpm than the same throttle in fast
forward flight, where the prop unloads. Passing Run S qualifies the spinner up to the highest rpm
recorded on the bench, and no further. Report that rpm. Covering flight rpm needs its own overspeed
test and procedure, which does not exist yet.

1. **Baseline.** Run A with the bare prop, same prop, same day. This is the vibration and thrust reference.
2. **Inspect and weigh** the spinner parts. Record mass. Look for layer gaps, cracks and warping under
   a bright light. Reject on any doubt.
3. **Fit** the spinner. Turn the motor by hand: no rub, no visible wobble, screws and nut tight.
   If a prop balancer is available, check the balance of prop plus spinner and record what was done.
4. **Barrier in place.** Everyone out of the prop plane and behind the barrier.
5. **Stepped run with inspections.** Run the Run A staircase in three parts, stopping after steps 4, 6
   and 8. At each stop: slider to 1000, disconnect the battery, wait for the prop to stop, inspect the
   spinner for cracks, layer separation, movement on the hub and loose screws.
6. **Endurance.** Three 10 s holds at the Run C throttle, with the same inspection after each.
7. **Final inspection** with the spinner removed: inside faces, screw bosses, the backplate around the
   shaft hole. Weigh it again.

| Pass criterion (targets) | Limit |
|---|---|
| Cracks, layer separation, loosening, rub marks | None at any inspection |
| Mass change | 0.05 g or less |
| Vibration at the rotor frequency, each step | No more than 1.5 x the bare-prop baseline |
| Thrust at the same rpm | Within 3 % of the bare prop |
| Highest rpm reached | Recorded and stated as the qualification limit |

A spinner that fails any line is not flown. A spinner that passes is qualified only to the recorded rpm.

## Report

Fill in `test/reports/TR-template_static_thrust.md` and save it as the next TR number.
