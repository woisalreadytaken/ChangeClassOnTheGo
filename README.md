# Change Class on the Go
Scuffed pseudo-gamemode that allows everyone to change classes at will, anywhere.

It has not been tested yet and may be super crusty. It also has planned features that are missing, such as ammo and charge meter management.

## Dependencies
- SourceMod 1.11 (untested on 1.10, but should work)
- [TF2Attributes](https://forums.alliedmods.net/showthread.php?t=210221)
- [TF2 Econ Data](https://forums.alliedmods.net/showthread.php?t=315011)
- [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) (compile only)

Optional: [TF2Items](https://forums.alliedmods.net/showthread.php?p=1050170) to make use of `ccotg_disable_cosmetics`.

## ConVars
Most restrictive ConVars will be disabled by default for the first time, will need to see how laggy it really is

- `ccotg_enabled` (1) - Is 'Change Class on the Go' enabled?
- `ccotg_announcement_interval` (240.0) - Amount of time (in seconds!) taken for the main announcement message to be re-sent.
- `ccotg_cooldown` (0.0) - Amount of time (in seconds!) required for a player to be allowed to change classes again.
- `ccotg_disable_cosmetics` (0) - Disallows players from equipping cosmetics, to lower the toll the server takes on class change. Depends on the TF2Items extension!
- `ccotg_only_allow_team` ("") - Only allows the specified team to make use of this plugin's functionality. Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.
- `ccotg_prevent_switching_during_bad_states` (1) - Lazy temporary beta convar - disallows switching classes if players are doing the following: Jetpacking (to prevent a persistent looping sound bug) and hauling a building (does some bad animation stuff).
- `ccotg_arena_change_round_states` (0) - Changes the round state in arena mode so players can use the default changeclass key mid round. Breaks the central Control Point! Disabling will let players change classes with their 'dropitem' key instead.