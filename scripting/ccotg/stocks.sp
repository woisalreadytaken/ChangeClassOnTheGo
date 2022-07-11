stock bool IsValidClient(int iClient)
{
	return 0 < iClient <= MaxClients && IsClientInGame(iClient);
}

stock void StrToLower(char[] sBuffer)
{
	int iLength = strlen(sBuffer);
	for (int i = 0; i < iLength; i++)
		sBuffer[i] = CharToLower(sBuffer[i]);
}

stock int ShowParticle(char[] sParticle, float flDuration, float vecPos[3], float vecAngles[3] = NULL_VECTOR)
{
	// should probably use temp ents later?
	
	int iParticle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(iParticle))
	{
		TeleportEntity(iParticle, vecPos, vecAngles, NULL_VECTOR);
		DispatchKeyValue(iParticle, "effect_name", sParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "start");
		CreateTimer(flDuration, Timer_RemoveParticle, iParticle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
		return -1;
	}
	
	return iParticle;
}

public Action Timer_RemoveParticle(Handle hTimer, int iParticle)
{
	if (iParticle >= 0 && IsValidEntity(iParticle))
	{
		char sClassname[32];
		GetEdictClassname(iParticle, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "info_particle_system", false))
		{
			AcceptEntityInput(iParticle, "stop");
			RemoveEntity(iParticle);
			iParticle = -1;
		}
	}
	
	return Plugin_Continue;
}