# Bench rig firmware

`thrust_stand/thrust_stand.ino` reads the load cell through the HX711 and streams CSV over USB.

**Status (2026-11-13):** compiles for the Arduino Nano (arduino:avr core 1.8.7, 9006 bytes). **Not yet run on
hardware.** Sample rate, noise and calibration accuracy are unknown until it is.

## Wiring

| HX711 board (SparkFun SEN-13879) | Goes to |
|---|---|
| VCC and VDD | Nano 5V |
| GND | Nano GND |
| DAT | Nano D3 |
| CLK | Nano D2 |
| RED / BLK / WHT / GRN | load cell red / black / white / green |

Cut the RATE jumper on the HX711 board for 80 samples/s. Uncut, it runs at 10.

## Upload

Arduino IDE: open the sketch, Tools > Board > Arduino Nano, Processor ATmega328P, pick the port, Upload.
No libraries to install.

## Use

Open the port at 115200 baud with line ending set to Newline. The Nano resets when the port opens,
tares for about 1 s (keep the rig still), then streams:

```
t_s,raw,grams,mark
12.3456,84213,0.02,0
```

- `t_s`: seconds since the Nano started, 0.1 ms resolution.
- `raw`: HX711 counts.
- `grams`: (raw - tare) x calibration slope. Prints `nan` until a calibration is saved.
- `mark`: a counter you bump with `m` to flag an event.
- Lines starting with `#` are messages. Skip them when parsing.

| Command | What it does |
|---|---|
| `t` | Tare |
| `c 500` | Add a calibration point with 500 g on the pan |
| `p` | Print the points, the fit and each point's residual |
| `s` | Apply the fit and save it to EEPROM |
| `x` | Clear the points |
| `g` / `h` | Start / stop the stream |
| `m` | Bump the mark column |
| `r` | Measure the sample rate (confirms the RATE jumper is cut) |
| `?` | Help |

## Calibrating

1. Fit the calibration pan in place of the motor and stand the rig so gravity loads the cell in the
   thrust direction.
2. `h` to stop the stream, `x` to clear old points, `t` to tare with the empty pan.
3. `c 0`, then add each mass in turn going up (`c 200`, `c 500`, ...), then the same masses coming back down.
4. `p` and read the residuals. Up and down residuals at the same mass show hysteresis; the worst residual
   shows linearity.
5. `s` to save. The slope survives power-off. Tare does not; it is redone at every start.

The sign of `grams` follows the calibration, so thrust reads positive if the masses load the cell the
same way thrust does.

## Safety

Calibrate with the motor removed or the prop off. Do not have a battery connected to the ESC while
handling the rig.
