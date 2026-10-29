# MOPPE GARAGE 3.0 — REALISTIC PHYSICS, WHEELIES & FULL CUSTOMIZATION

You are modifying my existing playable 3D moped game, MOPPE GARAGE.
Do not start over. Inspect the existing code and improve the current game directly. Preserve the existing 3D scene, vehicle selection, engine tuning, RPM system, performance graphs, and other working features.

The two main objectives are:

1. Implement a convincing physics-based riding system with wheelies, realistic steering, leaning, traction, suspension, and controlled tipping.
2. Build a complete visual customization system where individual body panels, mirrors, handlebars, covers, wheels, and other components can be removed, installed, painted, and customized independently.

The result must feel like riding and building a real lightweight 50cc scooter, not controlling a rigid toy model.

Prioritize working physics and actual, verified behaviour over visual polish or feature count. A smaller feature that works and is tested beats a large one that is half-done. Every milestone below must be run and checked before the next one starts.

---

## 0. Hard constraints (from the existing project)

- One file, `moppe/index.html`. Three.js **r128** from cdnjs. No build step, no new libraries. The game must still work when opened by double-clicking the file.
- All UI text is in Swedish.
- Do not remove working features: the three mopeds, tuning (kit, exhaust, carburettor, jet, port timing, rollers), the dyno graph and reference curve, kick-start and engine off, gears on the DT, sound, garage camera (orbit/zoom/pan/presets), save/load, and the existing controls.
- No dead buttons. A control that cannot do anything right now is disabled and says why (for example "Finns inte på den här modellen").
- No invented numbers in the UI. Keep **measured** values (dyno, test ride, 0–60 timer) separate from **calculated** ones. Physical constants that are game tuning rather than real data are named constants in one block at the top of the physics code, with a comment saying they are tuning values.
- No Yamaha logo or other brand marks.
- When you report back, state exactly what was verified (and how) and what was not.

## 1. Facts about the current code that the work must respect

- Physics lives in `step(dt)`. Forward is **+z**, turning right **decreases** `S.h`. `dt` is capped at 0.05 s, so the game runs in slow motion below 20 fps.
- Lean (`S.lean`) is visual only. Nothing has lateral dynamics, grip, suspension or collisions. The world is clamped to ±140 m.
- The wheelie is a pitch `S.pitch` around the rear axle via the compensating offset `S.off`. It is triggered by Ctrl/Shift or automatically when `S.acc > 2 m/s²`. That auto threshold is a hack and makes stock mopeds lift.
- Braking is one constant 6.5 m/s² deceleration.
- Vehicle data (`MOP`): mass 85/98/80 kg plus a 75 kg rider, wheelbase 1.2/1.3/1.3 m, wheel radius 0.17/0.26/0.22 m.
- Models: the Jogga is procedural (`buildScooter`), with symmetric extruded panels and no part names. The Aerox comes from an OBJ blob in which `tools/embed_aerox.py` **merges** its 269 groups into a few material classes (paint/seat/dark/metal/ex/wheels). Individual Aerox panels therefore cannot be removed until the blob keeps groups separate. The DT is simple boxes.
- Save key `moppe_v1`: `{cur, cfgs:{jog,rok,dt}}` with `col, seat, rim, fin, num, mir` as the only styling fields.

## 2. Controls (complete mapping)

Keep every existing key. Changes and additions are marked.

| Key | Action |
|---|---|
| W / ↑ | Throttle. Analog feel: throttle opens over ~0.15 s and closes over ~0.08 s, scaled by the existing gas response `P.resp` |
| S / ↓ | **Rear brake** (changed: was "brake") |
| Space | **Front brake** (changed: was "brake") |
| S + Space | Both brakes (combined) |
| A / ← , D / → | Steering input (see §3.2). Not a direct yaw command |
| Shift | **Rider weight back** (wheelie aid). Moves the rider's centre of gravity backwards and up |
| Ctrl | **Rider weight forward** (tuck). Moves the CG forward. Helps on hard braking and in corners |
| Q / E | Gear down/up (DT only, as now) |
| K | Kick-start (as now) |
| X | Engine off (as now) |
| R | Reset to start (as now). Also picks the bike up after a crash |
| M | Sound on/off (as now) |
| Tab | Garage / ride (as now) |
| **F3** | **New:** physics debug overlay (see §3.9) |
| **H** | **New:** cycle the assist level Nybörjare / Normal / Realistisk (see §3.8) |

Ctrl must no longer trigger the browser's Ctrl shortcuts while riding (keep the existing `preventDefault`). Text fields still keep all keys to themselves.

## 3. Riding physics

### 3.1 Fixed timestep
- Run physics at a fixed **120 Hz** with an accumulator, at most 8 substeps per frame. The game must run at real speed at 20–144 fps. If more than 8 substeps would be needed, drop the remainder (slow motion) instead of spiralling.
- Rendering interpolates between the last two physics states.
- **Acceptance:** stock Jogga 0–30 km/h differs by less than 5 % between simulating at 30 fps and at 144 fps.

### 3.2 State
Per vehicle: position, heading, longitudinal speed `v`, lateral velocity, yaw rate, lean angle φ and lean rate, steer angle δ, pitch θ and pitch rate (wheelie/stoppie/suspension), front and rear suspension compression and velocity, and front and rear wheel angular speeds. Keep the existing engine state (`rpm`, `thr`, `gear`, `ratio`, `temp`, `on`) and engine model (`calc`, `torque`, `target`) unchanged.

### 3.3 Steering and leaning
- Input sets a target steer angle. The maximum steer angle falls with speed: **30° at 0–5 km/h, linearly down to 6° at 50 km/h**, and stays at 6° above that. The steer rate is limited to 120°/s.
- Yaw rate comes from the bicycle model, `v · tan(δ) / wheelbase`, applied to the effective steer angle.
- The equilibrium lean for the current turn is `φ_eq = atan(v² · tan(δ) / (wheelbase · g))`. The actual lean follows it as a damped second-order system with a time constant of about **0.25 s**, so the bike visibly leans in *before* it turns hard and stands up after.
- Maximum lean (ground clearance), tuning values: **Jogga 38°, Aerox 42°, DT 45°**. Beyond that, see §3.7.
- The camera follows the heading and rolls about 30 % of the bike's lean.
- Below 2 m/s the rider puts a foot down: lean is forced towards 0 and the bike cannot fall over sideways.
- **Acceptance:** at 30 km/h with full steering input the bike settles at a steady lean below its maximum and drives a stable circle with a radius of 6–15 m. Releasing the steering brings the lean back to under 2° within 1 s.

### 3.4 Load, traction and sliding
- CG height with the rider is **0.55 m** (Jogga, Aerox) and **0.65 m** (DT). Static weight split is **45 % front / 55 % rear** with the rider seated. These are tuning values.
- Longitudinal load transfer: `ΔN = m · a · h_cg / wheelbase`. Shift and Ctrl move the CG ±0.12 m horizontally (and Shift +0.05 m up), which changes the split.
- Friction coefficient μ by surface: **asphalt 0.9, grass 0.55**. Surface comes from the existing track geometry (ring 38–50 m, dragstrip x 90–100, the connecting road, everything else grass). Grass also adds rolling resistance (×3).
- Each tyre has a friction circle with radius `μ · N`. Longitudinal force (drive or brake) and lateral force share it.
- If the rear drive force exceeds the remaining grip, the rear wheel spins up (wheel speed > road speed). Excess slip means the rear steps out (yaw added toward the slide), and the engine revs up (the CVT reacts to wheel speed, not road speed).
- If a brake force exceeds grip, that wheel locks. A locked rear wheel slides and skids. A locked **front** wheel while leaning more than 10° causes a front-end washout (crash, §3.7).
- **"Lagom sladd":** at the Normal assist level, a rear slide up to 25° slip angle can be held and caught by countersteering. Above **35°** it is a crash.
- **Acceptance:** a stock bike cannot spin the rear wheel on asphalt from a standstill. A race build (≥10 hp) can spin it on grass. Braking hard with the front brake only while straight up stops the bike from 40 km/h in less distance than with the rear brake only.

### 3.5 Brakes
- Front brake maximum (before grip limits) **7 m/s²**, rear **4 m/s²**. Both use the friction circle above, so the real deceleration depends on load transfer.
- The front brake compresses the fork (dive, §3.6). Front brake during a wheelie brings the front down quickly. The rear brake during a wheelie is the controlled way down.
- Engine braking on the DT stays as it is now.

### 3.6 Suspension
- Spring-damper per axle. Travel: **front 80 mm, rear 70 mm**. Natural frequency about **2.0 Hz**, damping ratio about **0.5**. These are tuning values.
- The body visibly dives under braking and squats under acceleration. The wheels stay on the ground and the body moves; the bike is not a rigid block.
- The front landing after a wheelie compresses the fork and shows a short bounce.
- **Acceptance:** braking from 40 km/h shows a fork compression of at least 30 mm on the debug overlay. The body pitch is visible in the garage camera at rest after Tab from riding (no leftover offset).

### 3.7 Wheelies, tipping and crashes
Replace the current auto-wheelie threshold with a moment balance around the rear contact patch.

- **Lift condition:** the front wheel's normal force reaches 0, that is when the drive acceleration `a ≥ g · b / h`, where `b` is the horizontal distance from the rear axle to the CG (affected by Shift/Ctrl) and `h` is the CG height. Pitch then follows from the net moment with pitch inertia `I ≈ m · (h² + b²)`.
- **Clutch pop:** releasing throttle and reopening it fully within 0.3 s, below 15 km/h, gives a short torque spike of +40 % for 0.2 s (CVT) or +60 % (DT, clutch dump). This is the main way to get a wheelie on a low-powered bike, together with Shift.
- **Balance point:** `θ_bp = atan(b / h)`. Past the balance point, gravity rotates the bike backwards. Above `θ_bp + 8°` it is a loop-out crash.
- Throttle modulation and the rear brake are the tools for holding a wheelie. At the Normal assist level a held wheelie should be possible after some practice on a tuned bike.
- **Expected behaviour:** a stock Jogga on asphalt with only W does **not** lift. Stock with Shift and a clutch pop lifts briefly (roughly 5–15°) and falls back. A race build with Shift can hold a wheelie with throttle control and can loop out if you overdo it.
- **Crash triggers:**
  - lean beyond the bike's maximum + 5°
  - front washout (§3.4)
  - rear slip angle above 35°
  - loop-out (above)
  - hitting a house or tree above 15 km/h (add simple box/cylinder colliders for the existing houses and tree trunks; under 15 km/h the bike just stops)
- **Crash sequence:** the engine stalls. The bike falls over around its ground contact line in 0.6–0.8 s and slides to a stop with ground friction. Message "Vält!" with the reason (for example "Vält! (framhjulet släppte)"). R or 2 s automatically raises it upright where it stopped. No damage model.
- Below 2 m/s, the bike never falls over sideways (foot down), but a loop-out is still possible.

### 3.8 Assist levels (H)
| | Nybörjare | Normal (default) | Realistisk |
|---|---|---|---|
| Traction control | rear slip capped at 10 % | off | off |
| Front brake | anti-lock | normal | normal |
| Lean | auto-countersteer, max lean −5° | as specified | as specified |
| Wheelie | loop-out prevented, the bike drops the front at θ_bp | as specified | as specified |
| Crash on slide | above 45° | above 35° | above 30° |

The current level is shown in the HUD and saved.

### 3.9 Debug overlay (F3)
Shows live: speed, rpm, gear/ratio, throttle, front/rear normal force (N), front/rear slip (% longitudinal, ° lateral), μ for the current surface, lean (actual and equilibrium), steer angle, pitch and θ_bp, suspension compression (mm), physics steps per frame, and fps. This is required: it is how the behaviour is verified.

### 3.10 What must not change
The engine model and dyno must give the same numbers as now for the same build. Top speed for each bike/build must stay within ±5 % of the current value (now: stock Jogga ≈54 km/h). Launch times may change because of grip and load transfer, but a stock bike's 0–30 km/h time must stay within ±15 % of now (Jogga ≈4.1 s) unless I ask for a change.

## 4. Customization system

### 4.1 Part data model
Every vehicle has a list of parts. Each part has:

- `id`, Swedish name, category (Kåpor, Styre & speglar, Hjul, Ljus, Motor & avgas, Sadel, Dekaler)
- `meshes`: the actual meshes it consists of
- `removable`, `paintable` (flags)
- `requires` / `blocks`: for example, mirrors need the handlebar. The handlebar cover cannot be installed without the headlight. Removing a part that others depend on asks first and then removes those too.
- state: `installed` (bool), `paint {color, finish}` where finish is one of Blank / Matt / Metallic / Krom / Pärlemor, and `variant` where the part has variants (exhaust already has five, keep the existing tuning link)

### 4.2 Parts per vehicle (minimum)
- **Jogga** (procedural): front fender, leg shield, headlight cover, handlebar cover, handlebar, mirrors left/right, floorboard, side panel left/right, rear body, seat, rear fender, variator cover, air filter, exhaust, front wheel (rim + tyre), rear wheel (rim + tyre), turn signals, tail light, number plate. Where `buildScooter` now builds one symmetric extruded shape for both sides, split it into a left and a right part.
- **Aerox** (OBJ): change `tools/embed_aerox.py` so the blob keeps each OBJ group's index range and stores a `part` id per group, through a `PARTS` mapping table in the script. The mapping is a guess from shape and position, the same as the current classes, so say so in the code and in CLAUDE.md. Groups without a part stay in a non-removable "Ram/övrigt" part. The material-class grouping for rendering stays. `index.html` must stay under 2 MB. Also make the existing **mirror checkbox work on the Aerox** (now it does nothing there).
- **DT**: rebuild the boxes as separate named parts: tank, side panels left/right, front fender, rear fender, seat, handlebar, headlight, number plate holder, exhaust, frame, engine.

### 4.3 What removing a part looks like
- Removing a part hides it and shows what is behind it. If there is nothing behind it (hollow shells), add **simple** underlying structure: frame tubes, an engine/variator block, a fuel tank and a battery box on the Jogga and DT. For the Aerox, show what the OBJ actually contains. Do not fake detail that is not there.
- Removed parts are listed as "Avmonterad" and can be reinstalled with one click.
- Cosmetic parts have **no performance effect** (no invented bonuses). The exhaust keeps its existing tuning effect. If total mass is shown, mark it as estimated.

### 4.4 Paint
- Paint per part, or "Lacka alla kåpor" for every paintable body panel at once.
- Colour picker plus 8 presets. A finish per part. Copy and paste paint between parts.
- Colours are sRGB-correct (keep the existing `setHex`/`setStyle` fix).
- The existing body/seat/rims colours and finish become shortcuts that write to the corresponding parts, so the old controls keep working.

### 4.5 Customization UI
- Click a part in the 3D view (raycast) to select it, or select it in a list grouped by category.
- The selected part is highlighted (emissive pulse or outline) and the camera eases to frame it.
- Buttons for the selection: Ta bort / Montera, Lacka, Finish, Återställ del. Buttons that do not apply are disabled with a reason.
- "Återställ moped" restores every part and paint to the bike's defaults (it already exists, extend it).
- The panel must still fit at 350 px width and work at phone width.

### 4.6 Riding with parts removed
- The bike must be rideable with any combination of removed cosmetic parts.
- Removing a wheel, the handlebar or the engine makes **"Åk ut"** disabled with the reason ("Framhjulet saknas").
- Optional: a "Ej besiktningsgodkänd" badge when lights, mirrors or fenders are missing. No gameplay effect.

## 5. Saving
- New key `moppe_v2`: `{cur, cfgs, parts:{jog:{...}, rok:{...}, dt:{...}}, assist}`.
- Migrate `moppe_v1` on load: `col` goes to every paintable panel, `seat` to the seat, `rim` to both rims, `fin` to all panels, and `mir` to the mirrors. Do not delete the v1 data.
- Validate everything loaded (unknown part ids are ignored, colours must be `#rrggbb`), the same way v1 is validated now.

## 6. Milestones (in this order, each one tested before the next)

1. **Fixed timestep and state refactor**, no behaviour change. Verify that the 0–30, top speed and dyno numbers match the current game.
2. **Steering, leaning, load transfer, grip, brakes, suspension.** Add the debug overlay first.
3. **Wheelie moment balance and clutch pop.** Remove the auto-wheelie hack.
4. **Crashes, colliders, assist levels.**
5. **Part data model and customization UI on the Jogga.**
6. **Aerox part groups** (`embed_aerox.py` and blob format) and the Aerox mirror checkbox.
7. **DT rebuilt as parts.**
8. **Save v2 with migration.** Update CLAUDE.md.

## 7. Verification (required for every milestone)
Run the game in headless Chromium (Playwright) with no console errors. Drive it through `step()` at a fixed timestep with scripted input, and report the numbers for:

- 0–20/30/40 km/h and top speed for stock and race builds of all three bikes, compared with the current values
- steady lean and turning radius at 30 km/h with full steering
- stopping distance from 40 km/h: front only, rear only, both
- stock bike with W only: maximum pitch (must be 0). Stock with Shift and a clutch pop: maximum pitch. Race build: hold a wheelie for 3 s with a scripted throttle controller.
- each crash trigger fires, and R raises the bike
- remove every part one by one: no errors, and screenshots of each bike with all removable panels off
- save → reload → the same parts, paint and assist level. A v1 save migrates correctly.

Then list clearly what was **verified**, what was only **simulated**, and what was **not tested** (sound, touch, other browsers, real feel on a real screen).
