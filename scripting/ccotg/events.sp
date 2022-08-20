void Event_Init()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
		
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(iClient) || TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return Plugin_Continue;
	
	// Reset the player's buffered class
	Player(iClient).nBufferedClass = TFClass_Unknown;
	
	// Reset the player's class data
	Player(iClient).ResetAllClassData();
	
	// If the player hasn't switched classes yet, nag them on each spawn until they do
	if (!Player(iClient).bHasChangedClass && Player(iClient).CanTeamChangeClass())
		PrintCenterText(iClient, "%t", "ChangeClass_Main_Hint");
	
	// Make sure to add any stray buildings back to the engineer on respawn, so he can't build multiple
	if (TF2_GetPlayerClass(iClient) == TFClass_Engineer && g_cvKeepBuildings.BoolValue)
	{
		int iBuilding = MaxClients + 1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
				SDKCall_AddObject(iClient, iBuilding);
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode || g_cvMessWithArenaRoundStates.BoolValue)
		return Plugin_Continue;
		
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			// If it's arena mode and we're not messing with round states, let players know they can open the class select menu... with a different key...
			if (!Player(iClient).bHasChangedClass && Player(iClient).CanTeamChangeClass())
			{
				CPrintToChat(iClient, "%t", "ChangeClass_Arena_Hint");
				PrintKeyHintText(iClient, "%t", "ChangeClass_Arena_Controls")
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_ArenaRoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return Plugin_Continue;
	
	// If round states are being messed with, there'll be no 'cap enabled' countdown, so we have to handle it by ourselves
	int iEntity = FindEntityByClassname(-1, "tf_logic_arena");
	if (iEntity > MaxClients)
	{
		float flTime = GameRules_GetPropFloat("m_flCapturePointEnableTime") - GetGameTime();
		
		if (flTime > 5.0)
			g_hArenaCountdownTimer = CreateTimer(flTime - 5.0, Timer_CapEnabledCountdown, 5);
	}
	
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return Plugin_Continue;
		
	// Cancel the countdown once the round ends, if it's still active
	delete g_hArenaCountdownTimer;
	
	return Plugin_Continue;
}

public Action Timer_CapEnabledCountdown(Handle hTimer, int iValue)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return Plugin_Continue;
	
	char sSound[64];
	Format(sSound, sizeof(sSound), "Announcer.RoundBegins%dSeconds", iValue);
	EmitGameSoundToAll(sSound);
	iValue--;
	
	// Keep counting down every second
	if (iValue > 0)
	{
		g_hArenaCountdownTimer = CreateTimer(1.0, Timer_CapEnabledCountdown, iValue);
	}
	else
	{
		g_hArenaCountdownTimer = null;
	}
	
	return Plugin_Continue;
}