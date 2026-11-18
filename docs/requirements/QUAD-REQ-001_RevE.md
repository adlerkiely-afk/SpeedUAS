# QUAD-REQ-001 Rev E — SpeedUAS system reqs (Iteration 1, 6S)

Author: A. Kiely · Rev E · 2026-11-17
Supersedes Rev D (3/16/2026). Rev C retired 11/9.

What changed from D: design moved to SolidWorks, arms integral (not replaceable), drag
check moved to Ansys Fluent vs a flat-plate stack baseline, endurance + hover reqs
rewritten after the current-draw numbers, parts list updated to what's actually bought/picked.

Status key: MET / PRED (analysis only, not measured) / OPEN (no data yet) / TBD

## Performance

| ID | Req | Verif | Status / notes |
|---|---|---|---|
| PR-01 | Top speed >= 140 km/h, calm air | Test (GPS log) | OPEN, not flown |
| PR-02 | Target top speed 160-175 km/h, calm air | Test (GPS log) | PRED ~240 km/h from thrust=drag model. not measured |
| PR-03 | 185-200 km/h ground speed downwind (20-30 km/h tailwind) | Test | OPEN |
| PR-04 | T/W > 10:1 full throttle on 6S | Analysis + thrust stand | TBD, need every part weighed first |
| PR-05 | >= 2 min mixed flight, full throttle bursts <= 30 s | Analysis + flight test | Rev D said 3 min at full throttle. datasheet ~55 A/motor = ~220 A total, ~20 s on 1300 mAh. not possible, rewritten |
| PR-06 | >= 5 min at 60% throttle cruise | Flight test | OPEN |
| PR-07 | Stable controlled flight up to >= 120 km/h | Flight test | OPEN |
| PR-08 | Stable hover, no pilot correction, >= 3 min | Flight test | OPEN. was 5 s in Rev D |
| PR-09 | Predicted top speed done before 1st flight, compared to GPS speed in test report | Analysis + test | Prediction done (~240 km/h calc). GPS compare pending |

## Airframe / structure

| ID | Req | Verif | Status / notes |
|---|---|---|---|
| AF-01 | Airframe designed from scratch in SolidWorks, no templates / downloaded STLs | Inspection | MET |
| AF-02 | Flight parts PAHT-CF. nose in ASA/ABS (CF kills GPS). PLA for fit checks only | Inspection | nose still set to PAHT-CF in CAD, fix |
| AF-03 | Streamlined fuselage, less drag than flat-plate center stack | Analysis (CFD, Fluent) | OPEN, case set up + meshing, not solved |
| AF-04 | Shaping rationale documented | Inspection | design log (not in repo yet) |
| AF-05 | Arm geometry sized for aero + motor torque loads at max speed | Analysis | OPEN |
| AF-06 | Print orientation lines up layers with main load direction | Inspection | print orientation table kept with the CAD notes |
| AF-07 | CG within 5 mm of geometric center (X, Y) | Measurement | OPEN, not built |
| AF-08 | Motor mount matches MEASURED motor (4x M3, 16 mm bolt circle) | Inspection | MET, fixed after measuring (first drawn as 16 mm square) |
| AF-09 | Arms integral w/ airframe, nacelle tail caps replaceable | Inspection | MET. changed from Rev D (stiffness + printability) |
| AF-10 | Mass of each printed part recorded before printing | Inspection | partial, mass table started |
| AF-11 | Battery bay fits MEASURED pack 34.9 x 38.7 x 80.7 mm | Inspection (fit print) | MET, fit-checked w/ calipers |
| AF-12 | All parts print with no supports | Inspection | MET, motor plate bridge redone |

## Propulsion / power

| ID | Req | Verif | Status / notes |
|---|---|---|---|
| PS-01 | Motors AOS Supernova 2207 1980KV | Inspection | selected |
| PS-02 | ESC >= 35 A continuous on 6S | Inspection | F55A, 55 A cont. full-throttle draw may be above that, check on stand |
| PS-03 | Props HQ 5x4.5x3 V1S | Inspection | selected |
| PS-04 | 6S LiPo 1000-1300 mAh, >= 100C | Inspection | GNB 1300 mAh 6S HV. full throttle draw is ~170C, see PR-05 |
| PS-05 | Thrust at full throttle predicted from datasheet / published test data | Analysis | done (datasheet). stand test TP-02 not run |
| PS-06 | Pitch speed calc for theoretical max speed | Analysis | done, ~251 km/h geometric pitch speed |
| PS-07 | All-up mass calc to check PR-04 | Analysis | TBD, waiting on weighed parts |

## Electronics

| ID | Req | Verif | Status / notes |
|---|---|---|---|
| EL-01 | F7 flight controller | Inspection | T-Motor F7 (stack w/ F55A) |
| EL-02 | ELRS 2.4 GHz RX w/ failsafe | Demo | RadioMaster RP4TD-M + Boxer ELRS. failsafe not set up yet |
| EL-03 | Electronics vibration isolated, motor plate >= 7 mm, M3x10 + washers | Inspection | in CAD |
| EL-04 | Blackbox logs IMU, motor outputs, GPS speed every flight | Demo | config notes + logger written, not run |
| EL-05 | Wiring inside / flush with fuselage | Inspection | internal channels in arms |
| EL-06 | FPV cam Caddx Ratel 2 (analog) | Inspection | selected |
| EL-07 | VTX in tail wall pocket | Inspection | TBS Unify Pro32 Nano (planned, replaced Rush Tank Mini) |
| EL-08 | GPS logging speed at 10 Hz | Demo | HGLRC M100 Mini (planned), 45 deg cradle in nose |

## Docs

| ID | Req | Verif | Status / notes |
|---|---|---|---|
| DOC-01 | Design decisions written down when made | Inspection | design log kept, not in repo yet |
| DOC-02 | Top speed calc in repo before 1st flight | Inspection | calc done, script not committed yet |
| DOC-03 | T/W calc w/ actual weights in repo before 1st flight | Inspection | script written (not committed), won't output T/W until masses measured |
| DOC-04 | Test procedures written before any test | Inspection | MET, TP-01 / TP-02 / TP-03 |
| DOC-05 | Every flight test gets a report vs predictions | Inspection | OPEN, template in test/reports |
| DOC-07 | Iter 1 lessons learned report at the end | Inspection | OPEN |

DOC-06 (commit as you go) and DOC-08 (LaTeX report) dropped.

## Selected parts (Iter 1)

| Part | Pick | Notes |
|---|---|---|
| Motors (x4) | AOS Supernova 2207 1980KV | 31 g ea (listing) |
| FC + ESC | T-Motor F7 + F55A Pro II stack | 30.5 mm holes |
| Props | HQ 5x4.5x3 V1S | 4 + spares |
| Battery | Gaoneng GNB 6S 1300 mAh HV | measured 34.9 x 38.7 x 80.7 mm |
| Receiver | RadioMaster RP4TD-M | ELRS 2.4 GHz |
| Transmitter | RadioMaster Boxer ELRS | |
| FPV camera | Caddx Ratel 2 | analog |
| VTX | TBS Unify Pro32 Nano | planned |
| GPS | HGLRC M100 Mini (u-blox M10) | planned |
| Cap | Nichicon ES/UHE 1000 uF 35 V | on main power |
| Spar | 4 mm OD CF tube | ~90 mm x 2 |
| Hardware | M3 heat-set inserts, M3x10 + washers, M3 flat head | |
| Filament | PAHT-CF flight, ASA/ABS nose, PLA Tough+ fit checks | |

Iteration 2 (later): 8S, AOS Supernova 1570KV, target 200+ km/h calm air. not started.
