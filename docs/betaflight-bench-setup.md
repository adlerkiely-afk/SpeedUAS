# Betaflight setup for the thrust stand

How to configure the T-Motor F7 and F55A Pro II so a bench run produces a blackbox log with RPM, current,
voltage, ESC temperature and gyro data, without arming.

**Status:** written 2026-11-13 from Betaflight knowledge and a short web check. **Nothing here has been
tried on this hardware.** Items marked *verify* are the ones most likely to differ on your firmware
version; each has a command that settles it. The flight controller's Betaflight version and the ESC's
firmware (BLHeli_32 or AM32; this ESC was sold with both) are unknown.

## Safety

- **Props off** for every step in this document. The prop goes on only for a TP-02 run, with the rig
  clamped and nobody in the prop plane.
- First power-up of the stack on a battery: use a smoke stopper or a current-limited supply.
- LiPo: charge and store in a fire-safe place, never leave a connected pack unattended, stop a run at
  3.5 V per cell under load (21.0 V on 6S).
- Do not raise or disable any ESC or Betaflight protection to get a number.

## 1. Record what you have

In the CLI tab:

```
version
dump
```

Save the `dump` output to `test/data/` as `bf_dump_<date>.txt` before changing anything. It is the
record of the configuration every log was taken with.

Read the ESC firmware name and version with the matching ESC configurator and write it in the test report.

## 2. Motor protocol and RPM (bidirectional DShot)

```
set motor_pwm_protocol = DSHOT300
set dshot_bidir = ON
set motor_poles = 14
save
```

- DSHOT300 is the usual choice at an 8 kHz gyro / 4 kHz PID loop; DSHOT600 at 8 kHz / 8 kHz.
- `motor_poles = 14` is the magnet count of a 2207 motor with 12 stator slots. *Verify* by counting the
  magnets on the bell.
- **Check:** Motors tab, battery connected, props off. Each motor should show an RPM value and an error
  rate near 0 %. If RPM stays at 0, the ESC firmware is too old or bidirectional DShot is not enabled on it.

RPM in the log: the blackbox stores eRPM / 100. Mechanical rpm = logged value x 100 / (motor_poles / 2)
= logged value x 100 / 7. Rev per second n = rpm / 60. *Verify* once by comparing a log value against
the Motors tab reading at the same throttle.

## 3. Voltage

```
get vbat_scale
```

Measure the pack with a multimeter at the XT60 and compare with the voltage Betaflight shows. If they
differ by more than 0.1 V: new scale = old scale x (multimeter volts / Betaflight volts).

## 4. Current

The F55A Pro II has one shunt for all four motors and gives the flight controller an analog current
signal. It does not report per-motor current over telemetry (forum report of T-Motor support's advice,
not confirmed by a datasheet). So:

```
set current_meter = ADC
get ibata_scale
```

- A scale of **200** is reported for this ESC (same forum source; a T-Motor listing for a related ESC
  also gives 200). Treat it as a starting value, **not a calibration**.
- With one motor running, the reading is that motor plus the idle draw of everything else on the pack.
  Record the reading with all motors stopped and subtract it.
- **Calibrate** before trusting any current number. Either:
  - put a wattmeter or clamp meter in the battery lead and compare at two or three steady throttle
    points: new scale = old scale x (Betaflight amps / meter amps); or
  - run a pack down, note the mAh Betaflight counted and the mAh the charger puts back:
    new scale = old scale x (Betaflight mAh / charger mAh).
- One user reported inconsistent current readings from this ESC and flight controller pair, so do the
  meter comparison at more than one current.

## 5. ESC temperature

Bidirectional DShot on its own carries RPM only. Temperature needs one of:

**A. ESC telemetry wire (try this first).** The ESC's telemetry pad goes to a spare UART RX on the flight
controller; in a matched stack the harness usually carries it already.
- Ports tab: on that UART, set Sensor Input to ESC.
- Configuration tab: enable ESC_SENSOR.
- Leave `current_meter = ADC` (section 4).
- **Check:** add "ESC temperature" to the OSD or watch the Sensors/Motors tab; a value near room
  temperature that rises when a motor runs means it works.

**B. Extended DShot telemetry.** Sends temperature over the motor signal wire. Needs ESC firmware that
supports it and `set dshot_edt = ON`. *Verify* the setting exists with `get dshot_edt`.

**Getting it into the log.** Temperature is not a standard blackbox field; it is logged through a debug
mode. *Verify* the name on your version:

```
get debug_mode
```

That prints the allowed values. Look for `ESC_SENSOR_TMP` (telemetry wire) or a DShot telemetry mode
(option B), then `set debug_mode = <name>` and `save`. The four debug channels are then the ESC
temperatures in °C.

If neither route works, the fallback is a thermocouple or IR thermometer on the ESC, read by hand at the
end of each hold. Say so in the report.

## 6. Blackbox logging without arming

```
get blackbox_mode
```

*Verify* the allowed values. On current Betaflight they are `NORMAL` (log while armed), `MOTOR_TEST` and
`ALWAYS`. Older versions use `blackbox_on_motor_test = ON` instead.

```
set blackbox_mode = MOTOR_TEST
set blackbox_sample_rate = 1/2
save
```

- `MOTOR_TEST` logs whenever the Motors tab test is switched on, so the PID loop never tries to "fly" a
  clamped motor. Do not arm on the bench.
- A higher log rate gives a usable vibration spectrum (the spectrum reaches half the log rate). Onboard
  flash fills quickly at this rate: erase it before every session and download after every run.
- Leave the default logged fields on. Gyro, motor command, battery voltage, current and eRPM are needed.

## 7. Running a throttle step from the Motors tab

1. Battery connected, USB connected, rig clamped, Nano logger streaming to a file.
2. Motors tab, tick the safety box. Logging starts.
3. Move **only the bench motor's slider**. The other three motors stay at zero.
4. Step and hold as TP-02 says. The sharp edges of each step are what the analysis uses to line up the
   Nano log with the blackbox log, so move the slider quickly and then leave it alone.
5. Slider to zero, untick the box, disconnect the battery, download the log.

Find out which slider is the bench motor at low throttle with the prop off before the first real run.

## 8. Current limit

The ESC is rated 55 A continuous and 75 A burst per channel. The motor datasheet shows 54 to 61 A at
full throttle (datasheet values, not measured).

- **On the bench:** `motor_output_limit` acts on armed flight output, and probably not on the Motors tab
  sliders (*verify*: set it to 50 and see whether a slider at full still reaches full RPM, prop off).
  Assume the operator is the limit: step up through the throttle points, watch the current, and **stop
  stepping at the first hold that reaches 55 A.** Record that throttle value.
- **For flight:** if the bench shows more than 55 A below full throttle, set `motor_output_limit` (in the
  PID profile) to the percentage that held 55 A on the bench, less a margin. Four motors at that current
  also exceed the 1300 mAh pack's discharge rating on paper, so the flight limit may need to be lower
  still; decide that from the bench data.
- The ESC firmware has its own current and temperature protection settings. Leave them at their
  defaults or tighter.

## Checklist before the first TP-02 run

| Item | Done | Value / note |
|---|---|---|
| `dump` saved | | |
| Betaflight version | | |
| ESC firmware and version | | |
| Magnet count confirmed 14 | | |
| RPM shows in Motors tab, error rate | | |
| Voltage checked against multimeter | | |
| `ibata_scale` calibrated against a meter | | |
| Idle current with motors stopped (A) | | |
| ESC temperature source (A, B or by hand) | | |
| `debug_mode` used | | |
| `blackbox_mode` used | | |
| Log rate | | |
| Bench motor slider number | | |
| `motor_output_limit` effect on sliders | | |

## Sources for the unverified items

- Current scale 200 and "analog current only": IntoFPV forum thread quoting T-Motor support,
  https://intofpv.com/archive/index.php/thread-13673.html
- Scale 200 on a related ESC listing: https://www.getfpv.com/t-motor-ultra-mini-f55a-pro-ii-3-6s-blheli-32-4-in-1-esc.html
- Inconsistent current readings report: https://intofpv.com/t-current-sensor-readings-suddenly-inconsistent
- Logging through motor test: https://intofpv.com/t-enable-blackbox-logging-whilst-not-flying
- ESC telemetry setup: https://oscarliang.com/esc-telemetry-betaflight
