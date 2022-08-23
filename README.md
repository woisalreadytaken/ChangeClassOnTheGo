# Change Class on the Go
Scuffed pseudo-gamemode that allows everyone to change classes at will, anywhere.

## Dependencies
- SourceMod 1.11
- [SlidyBat's SendProxy Manager extension fork](https://github.com/SlidyBat/sendproxy)
- [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) (compile only)

## ConVars
|ConVar|Default Value|Description|
|-|:-:|-|
|`ccotg_enabled`|1|Is 'Change Class on the Go' enabled?|
|`ccotg_cooldown`|0.0|Amount of time (in seconds!) required for a player to be allowed to change classes again.|
|`ccotg_particle`|1|Adds a team-coloured particle effect for switching classes.|
|`ccotg_only_allow_team`|""|Only allows the specified team to make use of this plugin's functionality.<br>Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.|
|`ccotg_keep_buildings`|1|Lets buildings stay on the map if a player switches from Engineer.<br>Disabling makes them get destroyed instead.|
|`ccotg_keep_momentum`|1|Players keep momentum after switching classes.|
|`ccotg_restrict_broken_conditions`|1|Disallows switching classes if players are jetpacking (to prevent a persistent looping sound bug) or hauling a building (does some bad animation stuff).|
|`ccotg_arena_change_round_states`|1|Pretends to change the round state in arena mode so players can use the default 'changeclass' key mid round.<br>Visually, slightly breaks the central Control Point!<br>Disabling will let players change classes with their 'dropitem' key as a fallback instead.|
|`ccotg_health_mode`|1|How should health be handled upon changing classes?<br>- 1: Don't change health<br>- 2: Keep the ratio of health to max health the same<br>- Any other value: Full heal|
|`ccotg_health_max_overheal`|1.5|Max amount of overheal (multiplier of max health) that players are allowed to keep upon changing classes.|
|`ccotg_ammo_management`|1|Saves ammo, charge meters, heads and similar things separately for each class until death.|

## Thanks To
* [42](https://github.com/FortyTwoFortyTwo), [Mikusch](https://github.com/Mikusch) & [Red Sun Over Paradise](https://redsun.tf) for helping me out with public playtesting and providing feedback.