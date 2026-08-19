# CSP API research

Research was performed against the current official repositories on 2026-08-19:

- `ac-custom-shaders-patch/acc-lua-sdk` (`common/ac_state.d.lua`, `common/ac_state.lua`);
- `ac-custom-shaders-patch/app-csp-defaults` (Radar manifest and UI); and
- `ac-custom-shaders-patch/acc-lua-internal` (uses of connection/race state).

The application uses `ac.getSim()`, `ac.iterateCars()`, `ac.getCar()` semantics, `ac.storage`, `ac.INIConfig.load`, and `ui.time`. For every `StateCar`, it reads the SDK/in-tree fields `index`, `racePosition`, `lapCount`, `splinePosition`, `isInPitlane`, `isInPit`, `isConnected`, `isActive`, and `speedKmh`; it uses the SDK accessors `car:id()`, `car:name()`, `car:driverName()`, and `car:driverNumber()`.

`ac.iterateCars()` is the full-grid iterator. CSP documents `ac.iterateCars.ordered()` as camera-distance ordering and `ac.iterateCars.leaderboard()` as leaderboard ordering; neither is used for relative ordering.

No standard, authoritative multiclass field was found in the current public `StateCar` SDK. Consequently, this release never pretends one exists: class assignment is override, exact mapping, conservative ID/name inference, or `UNKNOWN`.

The installed CSP SDK was not available on this development machine, and Assetto Corsa was not launched here. The app requires modern CSP with Lua apps, `ac.storage`, `ac.INIConfig`, and the documented StateCar properties above.
