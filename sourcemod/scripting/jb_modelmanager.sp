#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new g_PlayerModel[MAXPLAYERS][2]
new g_OldPlayerModel[MAXPLAYERS][2]

new Handle:g_cOnlyVIP

new String:g_Path[PLATFORM_MAX_PATH]
new String:g_DownloadPath[PLATFORM_MAX_PATH]

native bool:IsClientVIP(client)

public Plugin:myinfo = 
{
	name = "Jailbreak Model Manager",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_models", CmdModelsMenu)
	
	HookEvent("player_spawn", Event_PlayerSpawn)
	
	BuildPath(Path_SM, g_Path, sizeof(g_Path), "configs/jailbreak/player_models.cfg")
	BuildPath(Path_SM, g_DownloadPath, sizeof(g_DownloadPath), "configs/jailbreak/models_downloads.txt")
	
	g_cOnlyVIP = CreateConVar("jb_vip_models", "1", "Models only for VIP Players? [1 = Yes | 0 = No]", _, true, 0.0, true, 1.0)
}

public OnMapStart()
{
	PrecacheModels()
	DownloadModels()
}

public OnClientPostAdminCheck(client)
{
	g_PlayerModel[client][0] = 0
	g_PlayerModel[client][1] = 1
	
	if(GetConVarBool(g_cOnlyVIP))
	{
		if(HasVIPAccess(client))
		{
			new String:szSteamID[32]
			GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
			
			new String:szPath[PLATFORM_MAX_PATH]
			BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
			
			new Handle:kv
			kv = CreateKeyValues("Data")
			
			FileToKeyValues(kv, szPath)
			
			g_PlayerModel[client][0] = KvGetNum(kv, "t_model", 0)
			g_PlayerModel[client][1] = KvGetNum(kv, "ct_model", 1)
			
			CloseHandle(kv)
		}
	}
	else
	{
		new String:szSteamID[32]
		GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
		
		new String:szPath[PLATFORM_MAX_PATH]
		BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
		
		new Handle:kv
		kv = CreateKeyValues("Data")
		
		FileToKeyValues(kv, szPath)
		
		g_PlayerModel[client][0] = KvGetNum(kv, "t_model", 0)
		g_PlayerModel[client][1] = KvGetNum(kv, "ct_model", 1)
		
		CloseHandle(kv)
	}
	
	g_OldPlayerModel[client][0] = g_PlayerModel[client][0]
	g_OldPlayerModel[client][1] = g_PlayerModel[client][1]
}

public OnClientDisconnect(client)
{
	if(!HasSameModels(client))
	{
		if(GetConVarBool(g_cOnlyVIP))
		{
			if(HasVIPAccess(client))
			{
				new String:szSteamID[32]
				GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
				
				new String:szPath[PLATFORM_MAX_PATH]
				BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
				
				new Handle:kv
				kv = CreateKeyValues("Data")
				
				FileToKeyValues(kv, szPath)
				
				KvSetNum(kv, "t_model", g_PlayerModel[client][0])
				KvSetNum(kv, "ct_model", g_PlayerModel[client][1])
				
				KvRewind(kv)
				KeyValuesToFile(kv, szPath)
				
				CloseHandle(kv)
			}
		}
		else
		{
			new String:szSteamID[32]
			GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
			
			new String:szPath[PLATFORM_MAX_PATH]
			BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
			
			new Handle:kv
			kv = CreateKeyValues("Data")
			
			FileToKeyValues(kv, szPath)
			
			KvSetNum(kv, "t_model", g_PlayerModel[client][0])
			KvSetNum(kv, "ct_model", g_PlayerModel[client][1])
			
			KvRewind(kv)
			KeyValuesToFile(kv, szPath)
			
			CloseHandle(kv)
		}
	}
}

public Action:CmdModelsMenu(client, args)
{
	if(GetConVarBool(g_cOnlyVIP) && !HasVIPAccess(client))
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	new Handle:kv
	kv = CreateKeyValues("Models")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvGotoFirstSubKey(kv))
	{
		new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
		SetMenuTitle(menu, "Choose Model:")
		
		do
		{
			if(GetClientTeam(client) == KvGetNum(kv, "team"))
			{
				new id = KvGetNum(kv, "id")
				
				new String:szItem[32]
				IntToString(id, szItem, sizeof(szItem))
				
				new String:szName[MAX_NAME_LENGTH]
				KvGetSectionName(kv, szName, sizeof(szName))
				
				AddMenuItem(menu, szItem, szName)
			}
		}
		while(KvGotoNextKey(kv))
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER)
	}
	
	CloseHandle(kv)
	
	return Plugin_Handled
}

public menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:szItem[64]
			GetMenuItem(menu, param2, szItem, sizeof(szItem))
			
			new id = StringToInt(szItem)
			
			if(GetClientTeam(client) == CS_TEAM_T)
			{
				g_PlayerModel[client][0] = id
				PrintToChat(client, "%s Your model selection saved", g_Tag)
			}
			else if(GetClientTeam(client) == CS_TEAM_CT)
			{
				g_PlayerModel[client][1] = id
				PrintToChat(client, "%s Your model selection saved", g_Tag)
			}
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	SetModel(client)
}

public JB_OnSimonRemove(client)
{
	SetModel(client)
}

SetModel(client)
{
	new Handle:kv
	kv = CreateKeyValues("Models")
	
	FileToKeyValues(kv, g_Path)
	
	new String:szModel[128]
	
	new team = GetClientTeam(client)
	
	if(team > 1)
	{
		team -= 2
		
		if(KvGotoFirstSubKey(kv))
		{
			do
			{
				new id = KvGetNum(kv, "id")
				
				if(id == g_PlayerModel[client][team])
				{
					KvGetString(kv, "model", szModel, sizeof(szModel))
					SetEntityModel(client, szModel)
					
					break
				}
			}
			while(KvGotoNextKey(kv))
		}
		
		CloseHandle(kv)
	}
}

PrecacheModels()
{
	new Handle:kv
	kv = CreateKeyValues("Models")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			new String:szModel[128]
			KvGetString(kv, "model", szModel, sizeof(szModel))
			
			PrecacheModel(szModel)
		}
		while(KvGotoNextKey(kv))
	}
	
	CloseHandle(kv)
}

DownloadModels()
{
	new Handle:file = OpenFile(g_DownloadPath, "r")
	
	if(file != INVALID_HANDLE)
	{
		new String:szLine[256]
		
		while(!IsEndOfFile(file))
		{
			ReadFileLine(file, szLine, sizeof(szLine))
			TrimString(szLine)
			
			if(szLine[0] != ';' && szLine[0] != '\0' && szLine[0] != '/' && szLine[1] != '/')
			{
				AddFileToDownloadsTable(szLine)
			}
		}
		
		CloseHandle(file)
	}
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

bool:HasSameModels(client)
{
	if(g_OldPlayerModel[client][0] == g_PlayerModel[client][0] && g_OldPlayerModel[client][1] == g_PlayerModel[client][1])
	{
		return true
	}
	else
	{
		return false
	}
}