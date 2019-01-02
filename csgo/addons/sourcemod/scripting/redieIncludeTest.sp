#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Diam0ndzx"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <redie>
//#include <sdkhooks>

#pragma newdecls required

EngineVersion g_Game;

public Plugin myinfo = 
{
	name = "Test for redie natives",
	author = PLUGIN_AUTHOR,
	description = "name",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	RegConsoleCmd("sm_playerInRedie", Command_isInRedie, "Checks if a player is in redie", ADMFLAG_BAN);
}

public Action Command_isInRedie(int client, int args)
{
	if(args < 1)
	{
		PrintToChat(client, "You must define a player!");
		return Plugin_Handled;
	}
	
	char name[32];
	int target = -1;
	GetCmdArg(1, name, sizeof(name));
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i))
		{
			continue;
		}
		char other[32];
		GetClientName(i, other, sizeof(other));
		if(StrEqual(name, other))
		{
			target = i;
		}
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "No player found with username %s", name);
		return Plugin_Handled;
	}
	
	if(Redie_IsInRedie(target) == true)
	{
		ReplyToCommand(client, "%s is in redie.", name);
	}else
	{
		ReplyToCommand(client, "%s is not in redie.", name);
	}
	return Plugin_Handled;
}