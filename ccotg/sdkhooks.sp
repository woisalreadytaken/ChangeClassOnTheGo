public Action SDKHook_FuncRespawnRoom_StartTouch(int iEntity, int iClient)
{
	if (IsValidClient(iClient) && GetClientTeam(iClient) == GetEntProp(iEntity, Prop_Send, "m_iTeamNum"))
		g_bInRespawnRoom[iClient] = true;
	
	return Plugin_Continue;
}

public Action SDKHook_FuncRespawnRoom_EndTouch(int iEntity, int iClient)
{
	if (IsValidClient(iClient) && GetClientTeam(iClient) == GetEntProp(iEntity, Prop_Send, "m_iTeamNum"))
		g_bInRespawnRoom[iClient] = false;
	
	return Plugin_Continue;
}