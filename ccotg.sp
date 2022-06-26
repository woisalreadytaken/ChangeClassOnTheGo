#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <morecolors>

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#tryinclude <tf_econ_data>
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION		"0.1"

enum
{
	LoadoutSlot_Primary = 0,
	LoadoutSlot_Secondary,
	LoadoutSlot_Melee,
	LoadoutSlot_Utility,
	LoadoutSlot_Building,
	LoadoutSlot_PDA,
	LoadoutSlot_PDA2,
	LoadoutSlot_Head,
	LoadoutSlot_Misc,
	LoadoutSlot_Action,
	LoadoutSlot_Misc2
};

bool g_bTF2Items;
bool g_bTFEconData;
bool g_bHasRobotArm[MAXPLAYERS];
bool g_bInRespawnRoom[MAXPLAYERS];

float g_flLastClassChange[MAXPLAYERS];

Handle g_hAnnouncementTimer;

char g_sClassNames[view_as<int>(TFClass_Engineer)+1][] = {
	"random",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavyweapons",
	"pyro",
	"spy",
	"engineer"
};

ConVar g_cvEnabled;
ConVar g_cvAnnouncementTimer;
ConVar g_cvCooldown;
ConVar g_cvDisableCosmetics;
ConVar g_cvOnlyAllowTeam;

#include "ccotg/convars.sp"
#include "ccotg/events.sp"
#include "ccotg/sdkcalls.sp"
#include "ccotg/sdkhooks.sp"
#include "ccotg/stocks.sp"

public Plugin myinfo =
{
	name = "Change Class on the Go",
	author = "wo",
	description = "local demoknight holds m2 and can not be stopped",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/mmmwo/"
}

public void OnPluginStart()
{
	g_bTF2Items = LibraryExists("TF2Items");
	g_bTFEconData = LibraryExists("tf_econ_data");
	
	AddCommandListener(CommandListener_JoinClass, "joinclass");
	AddCommandListener(CommandListener_JoinClass, "join_class");
	
	ConVar_Init();
	Event_Init();
	SDKCall_Init();
	
	Enable();
}

public void OnMapStart()
{
	// Set respawn room sdkhooks up here instead of OnEntityCreated so they work fine if the plugin is reloaded mid-game
	int iEntity = MaxClients+1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		SDKHook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
}

public void OnClientPutInServer(int iClient)
{
	g_bHasRobotArm[iClient] = false;
	g_bInRespawnRoom[iClient] = false;
	g_flLastClassChange[iClient] = GetGameTime();
}

public void OnPluginEnd()
{
	Disable();
}

public void Enable()
{
	if (!g_cvEnabled.BoolValue)
		return;
		
	if (g_cvAnnouncementTimer.FloatValue > 0.0)
	{
		CreateTimer(0.0, Timer_MainAnnouncement); // In case the plugin was loaded mid-game, display a message immediately
		g_hAnnouncementTimer = CreateTimer(g_cvAnnouncementTimer.FloatValue, Timer_MainAnnouncement, _, TIMER_REPEAT);
	}
}

public void Disable()
{
	// Ideally we'd want to remove gunslinger viewmodels from snipers, but that still risks crashing the server (and client) if done mid-game lol!
	// ...so that won't be done. They'll be stuck with it until they rejoin or the map changes
	
	delete g_hAnnouncementTimer;
	
	// Unhook respawn rooms
	int iEntity = MaxClients+1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKUnhook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
}
	
public Action CommandListener_JoinClass(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	if (g_bInRespawnRoom[iClient] || GameRules_GetRoundState() == RoundState_Preround)
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
	
	float flTime = GetGameTime();
	float flTimeSinceLastChange = flTime - g_flLastClassChange[iClient];
	float flCooldown = g_cvCooldown.FloatValue;
	
	if (flTimeSinceLastChange < flCooldown)
	{
		CPrintToChat(iClient, "{red}You must wait {default}%.2fs {red}to change classes again.", (flCooldown - flTimeSinceLastChange));
		return Plugin_Handled;
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
		// (god damn this looks like shit)
		TFClassType nRandomClass = nCurrentClass;
		
		while (nRandomClass == nCurrentClass)
			nRandomClass = view_as<TFClassType>(GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
			
		strcopy(sClass, sizeof(sClass), g_sClassNames[view_as<int>(nRandomClass)]);
	}
	
	TFClassType nNewClass = TF2_GetClass(sClass);
	
	// Don't do anything if the same class was selected
	if (nCurrentClass == nNewClass)
		return Plugin_Handled;
	
	// i fucking hate the sniper :DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
	if (nNewClass == TFClass_Sniper)
	{
		// Give him the the "mod wrench builds minisentry" attribute (before changing classes) to prevent a server crash related to specifically the Sniper's viewmodel
		TF2Attrib_SetByName(iClient, "mod wrench builds minisentry", 1.0);
		g_bHasRobotArm[iClient] = true;
		
		CPrintToChat(iClient, "{red}Your Sniper weapons were made invisible to prevent server crashes. Apologies for the inconvenience.");
	}
	else
	{
		// (doing this doesn't have any effect on weapons with this attribute)
		TF2Attrib_RemoveByName(iClient, "mod wrench builds minisentry");
		g_bHasRobotArm[iClient] = false;
	}
	
	// Get the player's current health now so it can be set properly after changing class
	int iOldHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	
	// Change classes!
	TF2_SetPlayerClass(iClient, nNewClass, false, true);
	TF2_RegeneratePlayer(iClient);
	
	// have i told you how much i fucking hate this class?
	if (nNewClass == TFClass_Sniper)
	{
		// Hide all non-passive weapons (after changing classes), because the engi's hand is ugly to look at
		for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
		{
			int iWeapon = GetPlayerWeaponSlot(iClient, i);
			if (iWeapon > MaxClients)
			{
				SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iWeapon, _, _, _, 0);
			}
		}
	}
	
	int iNewHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	int iMaxHealth = SDKCall_GetMaxHealth(iClient);
	
	if (iOldHealth < iNewHealth) // Don't let players heal off switching classes
	{
		SetEntProp(iClient, Prop_Send, "m_iHealth", iOldHealth);
	}
	else if (iOldHealth > iMaxHealth) // Don't let players be overhealed by the previous class' higher health
	{
		SetEntProp(iClient, Prop_Send, "m_iHealth", iMaxHealth);
	}
	
	// Switching classes while taunting makes players have no active weapon, so give them one
	if (TF2_IsPlayerInCondition(iClient, TFCond_Taunting))
	{
		// Make it a melee weapon because players are supposed to always have one
		int iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
		if (iWeapon > MaxClients)
		{
			char sWeaponClassname[32];
			GetEntityClassname(iWeapon, sWeaponClassname, sizeof(sWeaponClassname));
			
			TF2_RemoveCondition(iClient, TFCond_Taunting);
			FakeClientCommand(iClient, "use %s", sWeaponClassname);
		}
	}
	
	g_flLastClassChange[iClient] = flTime;
	
	return Plugin_Handled;
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] sClassname, int iIndex, Handle &hItem)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
		
	if (!g_cvDisableCosmetics.BoolValue)
		return Plugin_Continue;
	
	// This is only used to block cosmetics, so we don't really care about class-specific slots
	int iSlot = TF2Econ_GetItemDefaultLoadoutSlot(iIndex);
	
	// I'm pretty sure only LoadoutSlot_Misc is used for cosmetics, but just in case
	if (iSlot == LoadoutSlot_Misc ||
		iSlot == LoadoutSlot_Misc2 ||
		iSlot == LoadoutSlot_Head)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Timer_MainAnnouncement(Handle timer)
{
	CPrintToChatAll("{olive}Change Class on the Go is active! You are free to change classes without respawning wherever you want.");
	
	return Plugin_Continue;
}