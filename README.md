# Multiclass Relative

A retro-industrial multiclass relative timing app for Assetto Corsa powered by Custom Shaders Patch (CSP).

It is designed for endurance traffic: the rows nearest the player are selected by their **physical, lap-aware track progress**, not by the race leaderboard. A Hypercar in overall P2 that is lapping a GT3 can therefore correctly appear directly behind that GT3.

## Features

- Configurable 1–10 cars ahead and behind (default 3/3), with a highlighted player row.
- Relative ordering from `lapCount + splinePosition`, including start/finish wrap.
- History/interpolation-based time deltas instead of instantaneous distance ÷ speed.
- Bounded 90-second history, responsive exponential gap smoothing, teleport invalidation.
- Independently configurable overall position, class position/text, car number, driver, gap, pit marker, and lap-difference fields.
- All-cars and same-class modes; offline/online-aware inactive/disconnected car filtering.
- Persistent CSP settings and in-app per-car class override cycling.
- Persistent per-class colour pickers, a configurable class-colour stripe, custom background colour/opacity, and a `FAST` closing-traffic highlight.
- Retro-engineering visual language: warm instrument palette, amber-on-graphite rows, and compact timing columns.
- Editable exact class map in `classes.ini`; safe `UNKNOWN` fallback.
- Optional compact debug telemetry view.

## Screenshot

The app is intentionally self-rendered with CSP Lua UI. Its compact default layout uses a warm paper/amber-on-graphite treatment, with class identity in a narrow coloured stripe at the left of every row:

```text
RELATIVE

 POS   # DRIVER                 GAP
 15  42 Driver B               -1.8
 16  91 Driver C               -0.7
>17  27 A piece of toast        0.0
  5   8 Driver D               +0.9
 18  55 Driver E               +2.4
```

The player row also has a bright background and `>` marker, so its identity does not depend on the player class colour.

## Requirements

- Assetto Corsa (original PC release).
- A modern Custom Shaders Patch installation with Lua apps, `ac.storage`, and `ac.INIConfig`.
- Content Manager is recommended for installation and enabling the app.

## Installation

1. Download `MulticlassRelative-v0.1.4.zip` from the release assets.
2. Drag the ZIP into Content Manager and accept installation.
3. Enable **Multiclass Relative** in the in-game CSP app sidebar.
4. Open its settings through the app’s gear icon.

Manual installation: extract the ZIP into the Assetto Corsa root. It contains exactly `apps/lua/MulticlassRelative`, so the resulting manifest path is `assettocorsa/apps/lua/MulticlassRelative/manifest.ini`.

## Usage and relative modes

`All cars` is the default and is recommended for traffic awareness. `Same class` filters the nearby physical traffic to the player’s detected class.

Negative gaps identify cars ahead in race direction; positive gaps identify cars behind. For lap-separated traffic the optional lap-difference indicator appears beside the physical gap: `-1L` is one lap ahead of the player and `+1L` is one lap behind.

Cars in pit lane remain visible by default and get `PIT`. **Show pit indicator** controls that marker without filtering cars; **Show cars in pits** controls filtering independently. Disconnected entries are excluded when CSP marks them disconnected, and stale timing states expire after five seconds.

## Multiclass support

Assetto Corsa/CSP does not provide a standardized class property in the currently public `StateCar` API. Detection therefore deliberately follows this order:

1. Persistent in-app override.
2. Exact car-ID mapping in `classes.ini`.
3. Conservative ID/name patterns (`hypercar`, `lmdh`, `lmh`, `lmp1/2/3`, `gt3/4`, `gte`, `tcr`, `touring`, `cup`).
4. `UNKNOWN`.

Available built-ins are `HY`, `LMP1`, `LMP2`, `LMP3`, `GT3`, `GT4`, `GTE`, `TCR`, `TC`, `CUP`, and `UNKNOWN`. No unsupported server metadata is invented or presented as authoritative.

Hiding class text or class position is presentation-only. Detection continues to drive class colours, class-position calculation, same-class filtering, multiclass behavior, and faster-class approach warnings.

### Custom class mappings

Edit `apps/lua/MulticlassRelative/classes.ini` after installation (or the installed equivalent):

```ini
[EXACT]
cf_corvette_callaway_gt3 = GT3
example_hypercar = HY
```

The key is the Assetto Corsa car folder ID, visible in Content Manager’s car page/folder or in the app debug logging. In the settings window, clicking a car’s class cycles and persists an override; it takes priority over this file. Reload the app/session after editing the INI.

## Settings

Cars ahead/behind, mode, columns, pit display, title/header, decimal precision, maximum gap, smoothing, automatic detection, and debug mode persist via `ac.storage`. CSP stores that state under its per-app Lua state folder.

The default columns are **overall position**, **car number**, **driver name**, and **gap**. **Class position** and **class text** default to off; both remain available independently. Pit and lap-difference indicators default to on and appear only when applicable. Every field can be toggled separately in the **Columns** settings section.

The **Appearance** section includes a persistent 12–32 px **Relative font size** control (18 px by default), a 2–8 px **Class marker width** control (4 px by default), a background colour/opacity, and an independent picker for every class colour. Row height and driver truncation adapt with the font size. **Faster-class approach warning** highlights a row in a configurable warning colour and appends `FAST` when a car is behind, is in a class faster than the player's, is within the configured time range, and its filtered relative gap is reducing faster than the selected rate. Defaults are 8.0 s and 0.20 seconds of gap closed per second. It is deliberately not a flashing alert.

## Timing algorithm

Every 0.1 s, each active car gets monotonic race progress `lapCount + splinePosition`. The app uses the **shortest circular delta of `splinePosition`** to decide if a car is physically ahead or behind; it never uses `racePosition` or total race progress for that decision. This distinction is crucial for lapping: a car one lap ahead but physically approaching from behind is shown below the player.

For a car ahead, it interpolates the time at which that car crossed the player’s current progress. For a car behind, it interpolates when the player crossed the trailing car’s current progress. Those crossings produce a time delta at the same point on the track, which remains useful through different speeds and classes. The short initial-history fallback uses average player progress rate and is replaced as soon as a crossing exists. A 0.40 s exponential filter smooths displayed gaps without changing row order.

Start/finish is continuous because laps participate in progress. A large backwards movement on the same lap is treated as a teleport/pit reset and clears only that car’s stale history. Pit-lane spline behavior remains track-dependent, a CSP/track limitation rather than a guessed correction.

## Online support

The app uses CSP’s full-grid iterator and `isConnected`/`isActive` state, so it can be used in multiplayer. Network latency, server timing, AI/remote spline fidelity, and pit geometry can affect what CSP exposes; this app makes no server-side timing claims.

## Troubleshooting

- **No rows:** verify CSP Lua apps are enabled and that the session has started producing race telemetry.
- **Unknown class:** add an exact mapping or set an in-app override.
- **Early `…` gaps:** let the 90-second timing history warm up; the app avoids pretending an unobserved crossing is precise.
- **Odd pit placement:** enable debug mode and report the track, layout, and CSP version with a screenshot.

## Development

Run the deterministic core tests with Lua 5.1:

```powershell
lua tests/timing_spec.lua
.\tools\build-package.ps1
```

See [CSP API research](docs/CSP_API_RESEARCH.md) and the [manual validation plan](docs/TESTING.md). GitHub Actions performs syntax validation and runs the deterministic timing test.

## Contributing

Issues and pull requests are welcome. Please keep commits in Conventional Commits form, add a fixture for timing changes where practical, and never rely on leaderboard position for relative ordering.

## License

[MIT](LICENSE).
