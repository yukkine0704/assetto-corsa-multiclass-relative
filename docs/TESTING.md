# Test plan

Automated deterministic coverage checks interpolated ahead/behind gaps, spline wrap at start/finish, same-lap teleport history invalidation, same-class filtering, and independent relative columns. Run `lua tests/timing_spec.lua` and `lua tests/display_spec.lua` with Lua 5.1; CI performs the same checks and syntax validation.

Manual validation still required in Assetto Corsa:

- Offline: practice, qualifying, race start, AI, pit entry/exit, teleport to pits, session restart.
- Online: join, disconnect/reconnect, 50–80 car grid, lapped traffic, and one-or-more-lap differences.
- Tracks: Spa, Le Mans, Nordschleife, and a short circuit.
- Fields: single class, two/three classes, and at least one unknown car.

For the key multiclass case, place a GT3 player near a Hypercar that is higher in the leaderboard but physically behind. The Hypercar must appear below the player: the app sorts by normalized race progress, never by `racePosition`.
