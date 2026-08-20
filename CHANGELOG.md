# Changelog

All notable changes to this project will be documented in this file.

## [0.1.3] - 2026-08-20

### Added

- Persistent relative font-size setting (12–32 px), with row height and driver truncation adapting to the chosen size.

## [0.1.2] - 2026-08-20

### Fixed

- Sort relative rows by circular spline proximity rather than total race progress, so lapping traffic approaching from behind appears below the player.

## [0.1.1] - 2026-08-19

### Added

- Persistent per-class colour pickers and custom transparent background colour.
- Faster-class closing warning with configurable range, threshold, and warning colour.

### Fixed

- Persist gap smoothing between incoming telemetry snapshots.

## [0.1.0] - 2026-08-19

### Added

- Physical relative ordering based on lap-aware spline progress.
- Interpolated, history-based relative time gaps with smoothing and bounded history.
- Multiclass detection, class positions, persistent overrides, and editable exact mappings.
- CSP settings/debug windows, pit indicators, deterministic timing tests, CI, and installation package.
