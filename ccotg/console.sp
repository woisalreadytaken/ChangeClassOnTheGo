void Console_Init()
{
	AddCommandListener(CommandListener_ChangeClass, "dropitem");
	AddCommandListener(CommandListener_JoinClass, "joinclass");
	AddCommandListener(CommandListener_JoinClass, "join_class");
}

public Action CommandListener_ChangeClass(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode)
		return Plugin_Continue;
	
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
		
	char sVGUIMenu[16];
	TFTeam nTeam = TF2_GetClientTeam(iClient);
	
	if (nTeam == TFTeam_Blue)
	{
		strcopy(sVGUIMenu, sizeof(sVGUIMenu), "class_blue");
	}
	else // If for some god forsaken reason non-blu and non-red team members get here (clueless), show them the red screen anyway
	{
		strcopy(sVGUIMenu, sizeof(sVGUIMenu), "class_red");
	}
	
	ShowVGUIPanel(iClient, sVGUIMenu);
	
	return Plugin_Continue;
}
	
public Action CommandListener_JoinClass(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	if (Player(iClient).bIsInRespawnRoom || GameRules_GetRoundState() == RoundState_Preround)
		return Plugin_Continue;
	
	TFTeam nTeam = TF2_GetClientTeam(iClient);
	char sTeam[4];
	g_cvOnlyAllowTeam.GetString(sTeam, sizeof(sTeam));
	
	if (StrContains(sTeam, "red", false) != -1 && nTeam != TFTeam_Red)
	{
		return Plugin_Continue;
	}
	else if (StrContains(sTeam, "blu", false) != -1 && nTeam != TFTeam_Blue)
	{
		return Plugin_Continue;
	}
	
	char sClass[16];
	GetCmdArg(1, sClass, sizeof(sClass));
	StrToLower(sClass);
	
	// Check if the class typed is valid
	bool bValidClass = false;
	for (int i = view_as<int>(TFClass_Unknown); i <= view_as<int>(TFClass_Engineer); i++)
	{
		if (StrEqual(sClass, g_sClassNames[i]))
		{
			bValidClass = true;
			break;
		}
	}
	
	if (!bValidClass)
		return Plugin_Continue;
	
	TFClassType nCurrentClass = TF2_GetPlayerClass(iClient);
	
	if (StrEqual(sClass, "random"))
	{
		// Don't allow randomness to pass the same class the player already is
		TFClassType nRandomClass = nCurrentClass;
		
		while (nRandomClass == nCurrentClass)
			nRandomClass = view_as<TFClassType>(GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
			
		strcopy(sClass, sizeof(sClass), g_sClassNames[view_as<int>(nRandomClass)]);
	}
	
	TFClassType nNewClass = TF2_GetClass(sClass);
	bool bSameClass = nNewClass == nCurrentClass;
	
	// Check for cooldown if the convar is set
	if (Player(iClient).IsInCooldown(!bSameClass))
	{
		Player(iClient).nBufferedClass = nNewClass;
			
		g_hBufferTimer[iClient] = CreateTimer(0.1, Timer_DealWithBuffer, iClient);
		return Plugin_Handled;
	}
	
	// Check for bad class switch state if the convar is set
	if (Player(iClient).IsInBadState(!bSameClass))
	{
		Player(iClient).nBufferedClass = nNewClass;
		
		g_hBufferTimer[iClient] = CreateTimer(0.1, Timer_DealWithBuffer, iClient);
		return Plugin_Handled;
	}
	
	// Don't do anything if the same class was re-selected
	if (bSameClass)
		return Plugin_Handled;
	
	Player(iClient).SetClass(nNewClass);
	return Plugin_Handled;
}
