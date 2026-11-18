# QUAD-REQ-001 Rev D: proposed changes

| ID | Rev C text (summary) | Proposed | Reason |
|---|---|---|---|
| PR-05 | ≥3 min at full throttle | ≥3 min mixed flight with full-throttle bursts ≤30 s | Datasheet: ~55 A/motor at 24 V → ~220 A total ≈ 170C on 1300 mAh; ~21 s static at full throttle |
| PS-04 | 6S 1000–1300 mAh, ≥100C | Keep, note the full-throttle draw exceeds 100C | Same current figure |
| AF-01 | Designed in Fusion 360 | Designed in SolidWorks, original | Tool actually used |
| AF-04 | Drag quantified in SimScale | Drag quantified in Ansys Fluent against a flat-plate-stack baseline | Tool actually used; a baseline is needed to state a reduction |
| AF-09 | Arms replaceable | Arms integral; nacelle tail caps replaceable | Integral arms chosen for stiffness and printability (design log v3) |
| EL-03 | Vibration isolation | Keep; add: motor plate ≥7 mm, M3 × 10 + washers | Stiffer mount (v4.1) |
| SG-01 | FPV stretch goal | Keep; VTX selected (TBS Unify Pro32 Nano), pockets in tail | |
