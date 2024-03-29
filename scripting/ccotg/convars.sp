#pragma semicolon 1
#pragma newdecls required

void ConVar_Init()
{
	g_cvEnabled = CreateConVar("ccotg_enabled", "1", "Is 'Change Class on the Go' enabled?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnabledChanged);
	g_cvCooldown = CreateConVar("ccotg_cooldown", "0.0", "Amount of time (in seconds!) required for a player to be allowed to change classes again.");
	g_cvParticle = CreateConVar("ccotg_particle", "1", "Adds a team-coloured particle effect for switching classes.");
	g_cvOnlyAllowTeam = CreateConVar("ccotg_only_allow_team", "", "Only allows the specified team to make use of this plugin's functionality. Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.");
	g_cvOnlyAllowTeam.AddChangeHook(ConVar_OnlyAllowTeamChanged);
	g_cvKeepBuildings = CreateConVar("ccotg_keep_buildings", "1", "Lets buildings stay on the map if a player switches from Engineer. Disabling makes them get destroyed instead.");
	g_cvKeepMomentum = CreateConVar("ccotg_keep_momentum", "1", "Players keep momentum after switching classes.");
	g_cvHealthMode = CreateConVar("ccotg_health_mode", "1", "How should health be handled upon changing classes?\n1: Don't change health\n2: Keep the ratio of health to max health the same\nAny other value: Full heal");
	g_cvHealthMaxOverheal = CreateConVar("ccotg_health_max_overheal", "1.5", "Max amount of overheal (multiplier of max health) that players are allowed to keep upon changing classes.");
	g_cvAmmoManagement = CreateConVar("ccotg_ammo_management", "1", "Saves ammo, charge meters, heads and similar things separately for each class until death.");
	g_cvPreventSwitchingDuringBadStates = CreateConVar("ccotg_restrict_broken_conditions", "1", "Disallows switching classes if players are jetpacking (to prevent a persistent looping sound bug) or hauling a building (does some bad animation stuff)");
	g_cvMessWithArenaRoundStates = CreateConVar("ccotg_arena_change_round_states", "1", "Pretend to change the round state in arena mode so players can use the default 'changeclass' key mid round. Visually, slightly breaks the central Control Point! Disabling will let players change classes with their 'dropitem' key as a fallback instead.");
	g_cvMessWithArenaRoundStates.AddChangeHook(ConVar_MessWithArenaRoundStatesChanged);
}

void ConVar_EnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue)
	{
		Enable();
		Map_Enable();
	}
	else
	{
		Disable();
	}
}

void ConVar_OnlyAllowTeamChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrContains(newValue, "red", false) != -1)
	{
		g_nTeamThatIsAllowedToChangeClass = TFTeam_Red;
	}
	else if (StrContains(newValue, "blu", false) != -1)
	{
		g_nTeamThatIsAllowedToChangeClass = TFTeam_Blue;
	}
	else
	{
		g_nTeamThatIsAllowedToChangeClass = TFTeam_Unassigned;
	}
}

void ConVar_MessWithArenaRoundStatesChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (!g_bArenaMode)
		return;
	
	// If disabled, forget that players have changed classes so they know they'll need to press a different key to do so from now on
	if (!convar.BoolValue)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
				Player(iClient).bHasChangedClass = false;
		}
	}
}