# SpeedUAS: High-Speed Quadcopter (Iteration 1, 6S)

A 5-inch, 6S quadcopter with a streamlined rocket-geometry fuselage, designed from scratch to
validate the airframe and set a performance baseline for an 8S Iteration 2.

![SpeedUAS wireframe](cad/images/assembly_wireframe.png)

| | |
|---|---|
| **Status** | Design v4.1 · fit-check printing · CFD set up (not yet solved) · not yet flown |
| **Target (PR-02)** | 160–175 km/h in calm air |
| **Predicted** | ~240 km/h (thrust = drag model, [analysis/](analysis/)) · pitch speed 251 km/h |
| **Tools** | SolidWorks · Ansys Fluent · Bambu Studio |
| **Power** | 4× AOS Supernova 2207 1980KV · T-Motor F7 + F55A Pro II · 6S 1300 mAh HV · HQ 5×4.5×3 |

## Repository map

| Folder | What's in it |
|---|---|
| [`docs/`](docs/) | Requirements (QUAD-REQ-001), proposed Rev D changes, design log, architecture, BOM |
| [`cad/`](cad/) | CAD images of the assembly and parts, with captions |
| [`analysis/`](analysis/) | Top-speed (PR-09 / DOC-02) and thrust-to-weight (DOC-03) calculations |
| [`cfd/`](cfd/) | Ansys Fluent setup: geometry prep, mesh, boundary conditions, run log |
| [`test/`](test/) | Test procedures (written before testing, DOC-04) and test reports (DOC-05) |
| [`manufacturing/`](manufacturing/) | Print orientations and slicer settings |
| [`media/`](media/) | Renders and figures |

## Design at a glance

- **Fuselage:** Myring body of revolution, D 62 mm, ~300 mm long (L/D ≈ 4.8). Nose (bayonet, camera),
  one-piece center tube, screw-on tail (M3 into heat-set inserts).
- **Arms:** four integral NACA 0024 arms, 38 mm chord, 105 mm to motor axis, 5 mm root fillets,
  4 mm CF spar; airfoil-shaped internal wire channels.
- **Nacelles:** sized to the 27.6 mm motor, 7 mm motor plate (16 mm bolt circle), screw-on tail caps.
- **Inside:** caged battery (loads through the nose), FC/ESC stack on M3 insert columns (reached by
  removing the tail), two NACA flush inlets for ESC cooling, RX/VTX pockets in the tail.
- **Printing:** every part prints without supports (center tube stands on its aft face).

## Key findings so far

1. Top speed is **pitch-speed limited**: ±25 % drag moves it ±4 km/h, ±8 % pitch speed moves it ±17 km/h.
2. Motors + nacelles are ~50 % of the estimated drag area, the biggest aero lever.
3. At ~55 A per motor the pack sees ~220 A: **PR-05 (3 min full throttle) can't be met** with 1300 mAh.
   See [docs/requirements/RevD_proposed_changes.md](docs/requirements/RevD_proposed_changes.md).
4. First fit print: battery measured larger than the datasheet-based model; motor bolt pattern misread.
   See [test/reports/TR-01](test/reports/TR-01_fit_print_1.md).
