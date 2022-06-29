# Change Class on the Go
description, unfinished. plugin, untested. we'll see!

## Dependencies
- SourceMod 1.11 (untested on 1.10, but should work)
- [TF2Attributes](https://forums.alliedmods.net/showthread.php?t=210221)
- [morecolors](https://forums.alliedmods.net/showthread.php?t=185016) (recompile only)

Optional: [TF2 Econ Data](https://forums.alliedmods.net/showthread.php?t=315011) and [TF2Items](https://forums.alliedmods.net/showthread.php?p=1050170) to make use of `ccotg_disable_cosmetics`.

## ConVars
Most restrictive ConVars will be disabled by default for the first time, will need to see how laggy it really is

- `ccotg_enabled` (1) - Is 'Change Class on the Go' enabled?
- `ccotg_announcement_interval` (240) - Amount of time (in seconds!) taken for the main announcement message to be re-sent.
- `ccotg_cooldown` (0) - Amount of time (in seconds!) required for a player to be allowed to change classes again.
- `ccotg_disable_cosmetics` (0) - Disallows players from equipping cosmetics, to lower the toll the server takes on class change. Depends on the TF2Items and TF Econ Data extensions!
- `ccotg_only_allow_team` ("") - Only allows the specified team to make use of this plugin's functionality. Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.
- `ccotg_prevent_switching_during_bad_states` (1) - Lazy temporary beta convar - disallows switching classes if are doing following: Jetpacking (to prevent a persistent looping sound bug) and hauling a building (does some bad animation stuff)