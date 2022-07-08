void ConVar_Init()
{
	// Most restriction ConVars will be disabled for initial testing, and may be enabled on the fly
	g_cvEnabled = CreateConVar("ccotg_enabled", "1", "Is 'Change Class on the Go' enabled?", _, true, 0.0, true, 1.0);
	g_cvEnabled.AddChangeHook(ConVar_EnabledChanged);
	g_cvAnnouncementTimer = CreateConVar("ccotg_announcement_interval", "240.0", "Amount of time (in seconds!) taken for the main announcement message to be re-sent.");
	g_cvAnnouncementTimer.AddChangeHook(ConVar_AnnouncementTimerChanged);
	g_cvCooldown = CreateConVar("ccotg_cooldown", "0.0", "Amount of time (in seconds!) required for a player to be allowed to change classes again.");
	g_cvDisableCosmetics = CreateConVar("ccotg_disable_cosmetics", "0", "Disallows players from equipping cosmetics, to lower the toll the server takes on class change. Depends on the TF2Items extension!");
	g_cvDisableCosmetics.AddChangeHook(ConVar_DisableCosmeticsChanged);
	g_cvOnlyAllowTeam = CreateConVar("ccotg_only_allow_team", "", "Only allows the specified team to make use of this plugin's functionality. Accepts 'red' and 'blu(e)', anything else means we'll assume you're fine with both teams.");
	g_cvOnlyAllowTeam.AddChangeHook(ConVar_OnlyAllowTeamChanged);
	g_cvPreventSwitchingDuringBadStates = CreateConVar("ccotg_prevent_switching_during_bad_states", "1", "Lazy temporary beta convar - disallows switching classes if are doing following: Jetpacking (to prevent a persistent looping sound bug) and hauling a building (does some bad animation stuff)");
	g_cvMessWithArenaRoundStates = CreateConVar("ccotg_arena_change_round_states", "0", "Changes the round state in arena mode so players can use the default changeclass key mid round. Breaks the central Control Point! Disabling will let players change classes with their 'dropitem' key instead.");
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

void ConVar_AnnouncementTimerChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_hAnnouncementTimer;
	
	if (convar.FloatValue > 0.0)
		g_hAnnouncementTimer = CreateTimer(g_cvAnnouncementTimer.FloatValue, Timer_MainAnnouncement, _, TIMER_REPEAT);
}

void ConVar_DisableCosmeticsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
		return;
	
	if (!g_bTF2Items)
	{
		PrintToServer("The 'ccotg_disable_cosmetics' ConVar DEPENDS on the TF2Items extension which does not exist in this server. It has been AUTOMATICALLY DISABLED.");
		g_cvDisableCosmetics.SetInt(0);
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
	
	// this doesn't even work, will do something about it later
	if (convar.BoolValue)
	{
		SendProxy_HookGameRules("m_iRoundState", Prop_Int, SendProxy_ArenaRoundState);
	}
	else
	{
		SendProxy_UnhookGameRules("m_iRoundState", SendProxy_ArenaRoundState);
	}
}