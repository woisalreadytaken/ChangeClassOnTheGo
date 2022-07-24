# Change Class on the Go
Scuffed pseudo-gamemode that allows everyone to change classes at will, anywhere.

It is currently missing some planned features, such as ammo and charge meter management.

## Dependencies
- SourceMod 1.11
- [TF2Attributes](https://forums.alliedmods.net/showthread.php?t=210221)
- [TheByKotik's SendProxy Manager extension fork](https://github.com/TheByKotik/sendproxy)
- [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) (compile only)

## ConVars
- `ccotg_enabled` (1) - Is 'Change Class on the Go' enabled?
- `ccotg_cooldown` (0.0) - Amount of time (in seconds!) required for a player to be allowed to change classes again.
- `ccotg_only_allow_team` ("") - Only allows the specified team to make use of this plugin's functionality. Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.
- `ccotg_keep_buildings` (1) - Lets buildings stay on the map if a player switches from Engineer. Disabling makes them get destroyed instead.
- `ccotg_prevent_switching_during_bad_states` (1) - Lazy temporary beta convar - disallows switching classes if players are doing the following: Jetpacking (to prevent a persistent looping sound bug) and hauling a building (does some bad animation stuff).
- `ccotg_arena_change_round_states` (1) - Pretend to change the round state in arena mode so players can use the default 'changeclass' key mid round. Visually, slightly breaks the central Control Point! Disabling will let players change classes with their 'dropitem' key as a fallback instead.
- `ccotg_health_mode` (1) - How should health be handled upon changing classes?
	- 1: Don't change health
	- 2: Keep the ratio of health to max health the same
	- Any other value: Full heal
- `ccotg_health_max_overheal` (1.5) - Max amount of overheal (multiplier of max health) that players are allowed to keep upon changing classes.