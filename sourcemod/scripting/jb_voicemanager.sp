#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new bool:g_Muted[MAXPLAYERS + 1]

native bool:IsClientVIP(client)

public Plugin:myinfo = 
{
	name = "Jailbreak Voice Manager",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_voice", CmdVoiceMenu)
	
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_death", Event_PlayerDeath)
}

public Action:CmdVoiceMenu(client, args)
{
	if(client != JB_GetSimon())
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	new String:szUserID[32]
	new String:szFormat[64]
	new String:szName[MAX_NAME_LENGTH]
	
	new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Mute/Unmute Prisoner:")
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T && !HasVoiceAccess(i))
		{
			GetClientName(i, szName, sizeof(szName))
			
			if(g_Muted[i])
			{
				FormatEx(szFormat, sizeof(szFormat), "%s [Muted]", szName)
			}
			else
			{
				FormatEx(szFormat, sizeof(szFormat), "%s [Unmuted]", szName)
			}
			
			IntToString(GetClientUserId(i), szUserID, sizeof(szUserID))
			AddMenuItem(menu, szUserID, szFormat)
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER)
	
	return Plugin_Handled
}

public menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new target = GetClientOfUserId(StringToInt(item))
			
			if(g_Muted[target])
			{
				g_Muted[target] = false
				
				SetClientListeningFlags(target, VOICE_NORMAL)
				PrintToChatAll("%s \x0E%N\x01 unmuted \x07%N", g_Tag, client, target)
			}
			else
			{
				g_Muted[target] = true
				
				SetClientListeningFlags(target, VOICE_MUTED)
				PrintToChatAll("%s \x0E%N\x01 muted \x07%N", g_Tag, client, target)
			}
			
			FakeClientCommand(client, "sm_voice")
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(GetClientTeam(client) == CS_TEAM_T)
	{
		if(!HasVoiceAccess(client))
		{
			g_Muted[client] = true
			SetClientListeningFlags(client, VOICE_MUTED)
		}
		else
		{
			SetClientListeningFlags(client, VOICE_NORMAL)
		}
	}
	else if(GetClientTeam(client) == CS_TEAM_CT)
	{
		SetClientListeningFlags(client, VOICE_NORMAL)
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(!HasVoiceAccess(client))
	{
		SetClientListeningFlags(client, VOICE_MUTED)
	}
}

bool:HasVoiceAccess(client)
{
	if(IsClientVIP(client) || GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		return true
	}
	else
	{
		return false
	}
}