#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new g_Dollars[MAXPLAYERS + 1]

new Handle:g_cGuardsWin
new Handle:g_cPrisonersWin
new Handle:g_cPrisonerKill
new Handle:g_cGuardKill
new Handle:g_cMinPlayers
new Handle:g_cMaxDollars

native bool:IsClientVIP(client)

public Plugin:myinfo = 
{
	name = "Jailbreak Money System",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_dollars", CmdShowDollars, "sm_dollars <name>")
	
	RegAdminCmd("sm_adddollars", CmdAddDollars, ADMFLAG_ROOT, "sm_adddollars <steamid> <amount>")
	RegAdminCmd("sm_givedollars", CmdGiveDollars, ADMFLAG_ROOT, "sm_givedollars <name> <amount>")
	
	HookEvent("round_end", Event_RoundEnd)
	HookEvent("player_death", Event_PlayerDeath)
	
	g_cGuardsWin = CreateConVar("jb_dollars_guards_win", "50", "Guards win round dollars", _, true, 0.0)
	g_cPrisonersWin = CreateConVar("jb_dollars_prisoners", "10", "Prisoners win round dollars", _, true, 0.0)
	g_cPrisonerKill = CreateConVar("jb_dollars_prisoners_kill", "50", "Prisoners kill dollars", _, true, 0.0)
	g_cGuardKill = CreateConVar("jb_dollars_guards_kill", "1", "Guards kill dollars", _, true, 0.0)
	g_cMinPlayers = CreateConVar("jb_dollars_min_players", "6", "Minimum Players to get rewards", _, true, 0.0)
	g_cMaxDollars = CreateConVar("jb_max_dollars", "20000", "Maximum dollars a Player can get", _, true, 0.0, true, 20000.0)
	
	LoadTranslations("common.phrases")
}

public OnClientPostAdminCheck(client)
{
	g_Dollars[client] = 0
	
	new String:szSteamID[32]
	GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	new Handle:kv
	kv = CreateKeyValues("Data")
	
	FileToKeyValues(kv, szPath)
	
	g_Dollars[client] = KvGetNum(kv, "dollars")
	
	CloseHandle(kv)
}

public OnClientDisconnect(client)
{
	new String:szSteamID[32]
	GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	new Handle:kv
	kv = CreateKeyValues("Data")
	
	FileToKeyValues(kv, szPath)
	
	KvSetNum(kv, "dollars", g_Dollars[client])
	
	KvRewind(kv)
	KeyValuesToFile(kv, szPath)
	
	CloseHandle(kv)
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("JB_GetClientDollars", Native_GetDollars)
	CreateNative("JB_SetClientDollars", Native_SetDollars)

	RegPluginLibrary("jailbreak")
	
	return APLRes_Success
}

public Native_GetDollars(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	
	return g_Dollars[client]
}

public Native_SetDollars(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	new amount = GetNativeCell(2)
	
	g_Dollars[client] = amount
}

public Action:CmdShowDollars(client, args)
{
	if(args < 1)
	{
		PrintToConsole(client, "You have %d$", g_Dollars[client])
		PrintToChat(client, "%s You have \x04%d$", g_Tag, g_Dollars[client])
	}
	else
	{
		new String:szName[MAX_NAME_LENGTH]
		GetCmdArg(1, szName, sizeof(szName))
		
		new target = FindTarget(client, szName, true, false)
		
		if(target > 0 && IsClientInGame(target))
		{
			PrintToConsole(client, "Player %N has %d$", target, g_Dollars[target])
			PrintToChat(client, "%s Player \x0E%N\x01 has \x04%d$", g_Tag, target, g_Dollars[target])
		}
	}
	
	return Plugin_Handled
}

public Action:CmdAddDollars(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: sm_adddollars <steamid> <amount>")
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
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	if(FileExists(szPath))
	{
		new Handle:kv
		kv = CreateKeyValues("Data")
		
		FileToKeyValues(kv, szPath)
		
		new String:szDollars[32]
		GetCmdArg(2, szDollars, sizeof(szDollars))
	
		new dollars = StringToInt(szDollars)
		
		KvSetNum(kv, "dollars", KvGetNum(kv, "dollars") + dollars)
		
		PrintToConsole(client, "%s successfully got %d", szSteamID, dollars)
		
		KvRewind(kv)
		KeyValuesToFile(kv, szPath)
		
		CloseHandle(kv)
	}
	else
	{
		PrintToConsole(client, "%s not found", szSteamID)
	}
	
	return Plugin_Handled
}

public Action:CmdGiveDollars(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: sm_givedollars <name> <amount>")
		return Plugin_Handled
	}
	
	new String:szTarget[32]
	GetCmdArg(1, szTarget, sizeof(szTarget))
	
	new String:szDollars[32]
	GetCmdArg(2, szDollars, sizeof(szDollars))
	
	new dollars = StringToInt(szDollars)
	
	if(StrEqual(szTarget, "@t"))
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(client) == CS_TEAM_T)
			{
				g_Dollars[i] += dollars
			}
		}
		
		PrintToChatAll("%s \x0E%N\x01 gave \x04%d$\x01 to \x07Prisoners", g_Tag, client, dollars)
	}
	else if(StrEqual(szTarget, "@ct"))
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(client) == CS_TEAM_CT)
			{
				g_Dollars[i] += dollars
			}
		}
		
		PrintToChatAll("%s \x0E%N\x01 gave \x04%d$\x01 to \x0CGuards", g_Tag, client, dollars)
	}
	else
	{
		new target = FindTarget(client, szTarget)
		
		if(target > 0 && IsClientInGame(target))
		{
			g_Dollars[target] += dollars
			PrintToChatAll("%s \x0E%N\x01 gave \x04%d$\x01 to \x07%N", g_Tag, client, dollars, target)
		}
	}
	
	return Plugin_Handled
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(CountConnectedPlayers() >= GetConVarInt(g_cMinPlayers) && !JB_IsSpecialDay())
	{
		new dollars
		new winner = GetEventInt(event, "winner")
		new max_dollars = GetConVarInt(g_cMaxDollars)
		
		if(winner == CS_TEAM_T)
		{
			dollars = GetConVarInt(g_cPrisonersWin)
		}
		else if(winner == CS_TEAM_CT)
		{
			dollars = GetConVarInt(g_cGuardsWin)
		}
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == winner)
			{
				if(!HasVIPAccess(i))
				{
					if(max_dollars > g_Dollars[i] + dollars)
					{
						g_Dollars[i] += dollars
						PrintToChat(i, "%s You got \x04%d$\x01 for winning the round", g_Tag, dollars)
					}
				}
				else
				{
					if(max_dollars > g_Dollars[i] + 2*dollars)
					{
						g_Dollars[i] += 2*dollars
						PrintToChat(i, "%s You got \x04%d$\x01 for winning the round", g_Tag, 2*dollars)
					}
				}
			}
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(CountConnectedPlayers() >= GetConVarInt(g_cMinPlayers) && !JB_IsSpecialDay())
	{
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"))
		new victim = GetClientOfUserId(GetEventInt(event, "userid"))
		
		if(attacker != victim && attacker > 0 && IsClientInGame(attacker))
		{
			new max_dollars = GetConVarInt(g_cMaxDollars)
			
			SetHudTextParams(-1.0, 0.6, 3.0, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0)
			
			if(GetClientTeam(attacker) == CS_TEAM_CT && GetClientTeam(victim) == CS_TEAM_T)
			{
				new dollars = GetConVarInt(g_cGuardKill)
				
				if(HasVIPAccess(attacker))
				{
					dollars *= 2
				}
				
				if(max_dollars > g_Dollars[attacker] + dollars)
				{
					g_Dollars[attacker] += dollars
					ShowHudText(attacker, 1, "+%d$", dollars)
				}
			}
			else if(GetClientTeam(attacker) == CS_TEAM_T && GetClientTeam(victim) == CS_TEAM_CT)
			{
				new dollars = GetConVarInt(g_cPrisonerKill)
				
				if(HasVIPAccess(attacker))
				{
					dollars *= 2
				}
				
				if(max_dollars > g_Dollars[attacker] + dollars)
				{
					g_Dollars[attacker] += dollars
					ShowHudText(attacker, 1, "+%d$", dollars)
				}
			}
		}
	}
}

CountConnectedPlayers()
{
	new count
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			count++
		}
	}
	
	return count
}

bool:HasVIPAccess(client)
{
	if(IsClientVIP(client))
	{
		return true
	}
	else
	{
		return false
	}
}