#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new Handle:g_GuardList

new Handle:g_cRatio
new Handle:g_cLockTeams
new Handle:g_cIgnoreRatio

new bool:g_Banned[MAXPLAYERS + 1]

new String:g_Path[PLATFORM_MAX_PATH]

public Plugin:myinfo = 
{
	name = "Jailbreak Team Manager",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_team", CmdTeamMenu)
	RegConsoleCmd("sm_guard", CmdJoinGuard)
	
	RegAdminCmd("sm_ctbanlist", CmdCTBanList, ADMFLAG_GENERIC)
	RegAdminCmd("sm_ctban", CmdCTBan, ADMFLAG_GENERIC, "sm_ctban <name> <minutes>")
	RegAdminCmd("sm_addctban", CmdAddCTBan, ADMFLAG_GENERIC, "sm_addctban <steamid> <minutes>")
	RegAdminCmd("sm_removectban", CmdRemoveCTBan, ADMFLAG_GENERIC, "sm_removectban <steamid>")
	
	HookEvent("round_end", Event_RoundEnd)
	HookEvent("player_team", Event_PlayerTeam)
	
	AddCommandListener(Hook_ChangeTeam, "jointeam")
	HookUserMessage(GetUserMessageId("VGUIMenu"), Team_MenuHook, true)
	
	g_cRatio = CreateConVar("jb_ratio", "3.0", "How many Prisoners for 1 Guard", _, true, 1.0)
	g_cLockTeams = CreateConVar("jb_lockteams", "0", "Lock Teams? [1 = Yes | 0 = No]", _, true, 0.0, true, 1.0)
	g_cIgnoreRatio = CreateConVar("jb_ignore_ratio", "0", "Ignore Ratio? [1 = Yes | 0 = No]", _, true, 0.0, true, 1.0)
	
	BuildPath(Path_SM, g_Path, sizeof(g_Path), "data/jailbreak/bans.txt")
	
	LoadTranslations("common.phrases")
	
	g_GuardList = CreateArray()
	
	CheckCTBans()
}

public OnMapEnd()
{
	ClearArray(g_GuardList)
}

public OnClientPostAdminCheck(client)
{
	new String:szSteamID[32]
	GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
	
	CheckCTBan(client, szSteamID)
}

public Action:CmdTeamMenu(client, args)
{
	if(GetConVarBool(g_cLockTeams))
	{
		PrintToChat(client, "%s Team Change is locked", g_Tag)
		return Plugin_Handled
	}
	
	new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Choose Team:")
	
	AddMenuItem(menu, "1", "Prisoners")
	AddMenuItem(menu, "2", "Guards")
	AddMenuItem(menu, "3", "Spectators")
	
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
			
			switch(StringToInt(item))
			{
				case 1:
				{
					if(GetClientTeam(client) != CS_TEAM_T)
					{
						ChangeClientTeam(client, CS_TEAM_T)
					}
					else
					{
						PrintToChat(client, "%s You are already a \x07Prisoner", g_Tag)
					}
				}
				case 2:
				{
					FakeClientCommand(client, "sm_guard")
				}
				case 3:
				{
					if(GetClientTeam(client) != CS_TEAM_SPECTATOR)
					{
						ChangeClientTeam(client, CS_TEAM_SPECTATOR)
					}
					else
					{
						PrintToChat(client, "%s You are already a Spectator", g_Tag)
					}
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

public Action:CmdJoinGuard(client, args)
{
	if(g_Banned[client])
	{
		PrintToChat(client, "%s You are \x07CT Banned", g_Tag)
		return Plugin_Handled
	}
	
	if(GetConVarBool(g_cLockTeams))
	{
		PrintToChat(client, "%s Team Change is locked", g_Tag)
		return Plugin_Handled
	}
	
	if(!GetConVarBool(g_cIgnoreRatio))
	{
		new guards = GetTeamClientCount(CS_TEAM_CT)
		new prisoners = GetTeamClientCount(CS_TEAM_T)
		
		if(guards == 0)
		{
			ChangeClientTeam(client, CS_TEAM_CT)
		}
		else if((1.0*prisoners/(guards + 1)) > GetConVarFloat(g_cRatio))
		{
			ChangeClientTeam(client, CS_TEAM_CT)
		}
		else
		{
			PrintToChat(client, "%s You can't join as a \x0CGuard\x01 now", g_Tag)
		}
	}
	else
	{
		ChangeClientTeam(client, CS_TEAM_CT)
	}
	
	return Plugin_Handled
}

public Action:CmdCTBanList(client, args)
{
	new Handle:kv
	kv = CreateKeyValues("CTBans")
	
	FileToKeyValues(kv, g_Path)
	
	PrintToConsole(client, "========== CT Banlist ==========")
	
	if(KvGotoFirstSubKey(kv))
	{
		new time = GetTime()
		
		do
		{
			new timeleft = KvGetNum(kv, "time")
			
			new String:szSteamID[32]
			KvGetSectionName(kv, szSteamID, sizeof(szSteamID))
			
			if(timeleft != 0)
			{
				timeleft -= time
				PrintToConsole(client, "SteamID: %s | Minute(s) left: %d", szSteamID, timeleft/60)
			}
			else
			{
				PrintToConsole(client, "SteamID: %s | Permanent Ban", szSteamID)
			}
		}
		while(KvGotoNextKey(kv))
	}
	
	PrintToConsole(client, "==============================")
	
	CloseHandle(kv)
}

public Action:CmdCTBan(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: sm_ctban <name> <minutes>")
		return Plugin_Handled
	}
	
	new String:szName[MAX_NAME_LENGTH]
	GetCmdArg(1, szName, sizeof(szName))
	
	new target = FindTarget(client, szName)
	
	if(target > 0 && IsClientInGame(target))
	{
		new String:szSteamID[32]
		GetClientAuthId(target, AuthId_Steam2, szSteamID, sizeof(szSteamID))
		
		new String:szMinutes[32]
		GetCmdArg(2, szMinutes, sizeof(szMinutes))
		
		new minutes = StringToInt(szMinutes)
		
		CTBan(client, target, szSteamID, minutes)
	}
	else
	{
		ReplyToCommand(client, "Could not find a player with that name")
	}
	
	return Plugin_Handled
}

public Action:CmdAddCTBan(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: sm_addctban <steamid> <minutes>")
		return Plugin_Handled
	}
	
	new String:szSteamID[32]
	GetCmdArg(1, szSteamID, sizeof(szSteamID))
	
	ReplaceString(szSteamID, sizeof(szSteamID), "STEAM_0", "STEAM_1")
	
	if(StrEqual(szSteamID, "STEAM_1") || !(StrContains(szSteamID, "STEAM_1") != -1))
	{
		ReplyToCommand(client, "This SteamID is not valid")
		return Plugin_Handled
	}
	
	new String:szMinutes[32]
	GetCmdArg(2, szMinutes, sizeof(szMinutes))
	
	new minutes = StringToInt(szMinutes)
	
	CTBan(client, -1, szSteamID, minutes)
	
	return Plugin_Handled
}

public Action:CmdRemoveCTBan(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_removectban <steamid>")
		return Plugin_Handled
	}
	
	new String:szSteamID[32]
	GetCmdArg(1, szSteamID, sizeof(szSteamID))
	
	ReplaceString(szSteamID, sizeof(szSteamID), "STEAM_0", "STEAM_1")
	
	if(StrEqual(szSteamID, "STEAM_1") || !(StrContains(szSteamID, "STEAM_1") != -1))
	{
		ReplyToCommand(client, "This SteamID is not valid")
		return Plugin_Handled
	}
	
	new Handle:kv
	kv = CreateKeyValues("CTBans")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvJumpToKey(kv, szSteamID))
	{
		KvDeleteThis(kv)
		
		KvRewind(kv)
		KeyValuesToFile(kv, g_Path)
		
		PrintToConsole(client, "%s successfully unbanned", szSteamID)
		
		CheckCTBans()
	}
	else
	{
		PrintToConsole(client, "%s is not banned", szSteamID)
	}
	
	CloseHandle(kv)
	
	return Plugin_Handled
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetConVarInt(FindConVar("mp_death_drop_gun"), 1)
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 0)
	
	if(!GetConVarBool(g_cIgnoreRatio))
	{
		new guards = GetTeamClientCount(CS_TEAM_CT)
		new prisoners = GetTeamClientCount(CS_TEAM_T)
		
		if(guards > 1)
		{
			if((1.0*prisoners/guards) < GetConVarFloat(g_cRatio))
			{
				new client = GetArrayCell(g_GuardList, (GetArraySize(g_GuardList) - 1))
				
				ChangeClientTeam(client, CS_TEAM_T)
				PrintToChatAll("%s \x0C%N\x01 has been moved to \x07Prisoners\x01 for balance", g_Tag, client)
			}
		}
	}
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	new new_team = GetEventInt(event, "team")
	new old_team = GetEventInt(event, "oldteam")
	
	if(old_team == CS_TEAM_CT)
	{
		RemoveFromArray(g_GuardList, FindValueInArray(g_GuardList, client))
	}
	else if(new_team == CS_TEAM_CT)
	{
		PushArrayCell(g_GuardList, client)
	}
}

public Action:Hook_ChangeTeam(client, const String:command[], args)
{
	return Plugin_Stop
}

public Action:Team_MenuHook(UserMsg:msg_id, Handle:msg, const players[], playersNum, bool:reliable, bool:init)
{
	new String:buffermsg[64]
	PbReadString(msg, "name", buffermsg, sizeof(buffermsg))
	
	if(StrEqual(buffermsg, "team", true))
	{
		new client = players[0]
		
		CreateTimer(0.1, ForceJoinPrisoner, GetClientUserId(client))
	}
	
	return Plugin_Continue
}

public Action:ForceJoinPrisoner(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid)
	
	if(client > 0 && IsClientInGame(client))
	{
		ChangeClientTeam(client, CS_TEAM_T)
	}
}

CTBan(client, target, const String:szSteamID[], minutes)
{
	new Handle:kv
	kv = CreateKeyValues("CTBans")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvJumpToKey(kv, szSteamID))
	{
		PrintToConsole(client, "This player is already banned")
	}
	else
	{
		KvJumpToKey(kv, szSteamID, true)
		
		if(minutes != 0)
		{
			KvSetNum(kv, "time", (GetTime() + minutes*60))
		}
		else
		{
			KvSetNum(kv, "time", 0)
		}
		
		if(target != -1)
		{
			g_Banned[target] = true
			ChangeClientTeam(target, CS_TEAM_T)
		}
		
		KvRewind(kv)
		KeyValuesToFile(kv, g_Path)
		
		PrintToConsole(client, "%s successfully banned", szSteamID)
	}
	
	CloseHandle(kv)
}

CheckCTBan(client, const String:szSteamID[])
{
	new Handle:kv
	kv = CreateKeyValues("CTBans")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvJumpToKey(kv, szSteamID))
	{
		g_Banned[client] = true
	}
	else
	{
		g_Banned[client] = false
	}
	
	CloseHandle(kv)
}

CheckCTBans()
{
	new Handle:kv
	kv = CreateKeyValues("CTBans")
	
	FileToKeyValues(kv, g_Path)
	
	new time = GetTime()
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			new timeleft = KvGetNum(kv, "time")
			
			if(timeleft != 0)
			{
				if(timeleft <= time)
				{
					KvDeleteThis(kv)
					
					KvRewind(kv)
					KeyValuesToFile(kv, g_Path)
				}
			}
		}
		while(KvGotoNextKey(kv))
	}
	
	CloseHandle(kv)
}