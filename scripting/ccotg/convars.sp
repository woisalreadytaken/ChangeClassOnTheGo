void ConVar_Init()
{
	g_cvEnabled = CreateConVar("ccotg_enabled", "1", "Is 'Change Class on the Go' enabled?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnabledChanged);
	g_cvCooldown = CreateConVar("ccotg_cooldown", "0.0", "Amount of time (in seconds!) required for a player to be allowed to change classes again.");
	g_cvOnlyAllowTeam = CreateConVar("ccotg_only_allow_team", "", "Only allows the specified team to make use of this plugin's functionality. Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.");
	g_cvOnlyAllowTeam.AddChangeHook(ConVar_OnlyAllowTeamChanged);
	g_cvKeepBuildings = CreateConVar("ccotg_keep_buildings", "1", "Lets buildings stay on the map if a player switches from Engineer. Disabling makes them get destroyed instead.");
	g_cvHealthMode = CreateConVar("ccotg_health_mode", "1", "How should health be handled upon changing classes?\n1: Don't change health\n2: Keep the ratio of health to max health the same\nAny other value: Full heal");
	g_cvHealthMaxOverheal = CreateConVar("ccotg_health_max_overheal", "1.5", "Max amount of overheal (multiplier of max health) that players are allowed to keep upon changing classes.");
	g_cvPreventSwitchingDuringBadStates = CreateConVar("ccotg_prevent_switching_during_bad_states", "1", "Lazy temporary beta convar - disallows switching classes if are doing following: Jetpacking (to prevent a persistent looping sound bug) and hauling a building (does some bad animation stuff)");
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