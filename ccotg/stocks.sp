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