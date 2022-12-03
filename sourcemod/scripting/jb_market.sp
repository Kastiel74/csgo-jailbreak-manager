#include <sourcemod>
#include <sdktools>
#include <jailbreak>

#define MAX_MARKET_ITEMS 6
#define MAX_ITEM_LENGTH 64

#define HEALTH_ITEM 0
#define LONGJUMP_ITEM 1
#define MULTIJUMP_ITEM 2
#define NINJA_ITEM 3
#define BFPROTECTION_ITEM 4
#define JUGGERNAUT_ITEM 5

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new g_Market[MAXPLAYERS + 1]

new g_MarketListPrices[MAX_MARKET_ITEMS]
new String:g_MarketList[MAX_MARKET_ITEMS][MAX_ITEM_LENGTH]

new String:g_Path[PLATFORM_MAX_PATH]

new bool:g_ItemUsed[MAX_MARKET_ITEMS]

new Handle:g_cEnableMarket

public Plugin:myinfo = 
{
	name = "Jailbreak Market",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_market", CmdMarket)
	
	RegAdminCmd("jb_reloadmarket", CmdReloadMarket, ADMFLAG_ROOT)
	
	HookEvent("player_spawn", Event_PlayerSpawn)
	
	g_cEnableMarket = CreateConVar("jb_enable_market", "0", "Enable Market? [1 = Yes | 0 = No]", _, true, 0.0, true, 1.0)
	
	BuildPath(Path_SM, g_Path, sizeof(g_Path), "configs/jailbreak/market.txt")
	
	CheckMarket()
	LoadMarket()
}

public OnMapStart()
{
	CheckMarket()
	LoadMarket()
}

public OnClientPostAdminCheck(client)
{
	g_Market[client] = -1
	
	new String:szSteamID[32]
	GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	new Handle:kv
	kv = CreateKeyValues("Data")
	
	FileToKeyValues(kv, szPath)
	
	g_Market[client] = KvGetNum(kv, "item", -1)
	
	CloseHandle(kv)
}

public Action:CmdMarket(client, args)
{
	if(!GetConVarBool(g_cEnableMarket))
	{
		PrintToChat(client, "%s Market is disabled", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Market[client] > -1 && g_Market[client] < 99)
	{
		PrintToChat(client, "%s You can buy only one item from the Market", g_Tag)
		return Plugin_Handled
	}
	
	new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Jailbreak Market: %d$", JB_GetClientDollars(client))
	
	new String:szItem[32]
	
	for(new i = 0; i < MAX_MARKET_ITEMS; i++)
	{
		IntToString(i, szItem, sizeof(szItem))
		
		if(!g_ItemUsed[i])
		{
			AddMenuItem(menu, szItem, g_MarketList[i])
		}
		else
		{
			AddMenuItem(menu, szItem, g_MarketList[i], ITEMDRAW_DISABLED)
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
			
			new i = StringToInt(item)
			
			if(JB_GetClientDollars(client) >= g_MarketListPrices[i])
			{
				JB_SetClientDollars(client, JB_GetClientDollars(client) - g_MarketListPrices[i])
				
				BuyItem(client, i)
			}
			else
			{
				ClientCommand(client, "play buttons/weapon_cant_buy")
				PrintToChat(client, "%s You don't have enough money", g_Tag)
			}
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
	
	if(g_Market[client] > -1)
	{
		CreateTimer(1.0, GiveMarketItem, GetEventInt(event, "userid"))
	}
}

public Action:GiveMarketItem(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid)
	
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		switch(g_Market[client])
		{
			case HEALTH_ITEM:
			{
				JB_SetRegeneration(client)
				SetEntityHealth(client, 150)
			}
			case LONGJUMP_ITEM:
			{
				JB_SetLongJump(client)
			}
			case MULTIJUMP_ITEM:
			{
				JB_SetMultiJump(client, 3)
			}
			case NINJA_ITEM:
			{
				GivePlayerItem(client, "weapon_flashbang")
				GivePlayerItem(client, "weapon_smokegrenade")
				SetEntityRenderMode(client, RENDER_TRANSCOLOR)
				SetEntityRenderColor(client, 0, 0, 0, 50)
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.3)
			}
			case BFPROTECTION_ITEM:
			{
				JB_SetBFProtection(client)
				GivePlayerItem(client, "weapon_molotov")
				GivePlayerItem(client, "weapon_hegrenade")
			}
			case JUGGERNAUT_ITEM:
			{
				SetEntityHealth(client, 255)
				GivePlayerItem(client, "item_assaultsuit")
				GivePlayerItem(client, "weapon_tagrenade")
			}
			case 99:
			{
				JB_SetLongJump(client)
				JB_SetRegeneration(client)
				SetEntityHealth(client, 150)
				JB_SetMultiJump(client, 9999)
				GivePlayerItem(client, "item_assaultsuit")
			}
		}
	}
}

BuyItem(client, item)
{
	new String:szSteamID[32]
	GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID))
	
	SetClientItem(client, szSteamID, item)
	
	new Handle:kv
	kv = CreateKeyValues("Market")
	
	FileToKeyValues(kv, g_Path)
	
	new time = GetTime() + 604800
	
	if(KvGotoFirstSubKey(kv))
	{
		new i
		
		do
		{
			if(i == item)
			{
				KvSetNum(kv, "time", time)
				KvSetString(kv, "steamid", szSteamID)
				KvRewind(kv)
				KeyValuesToFile(kv, g_Path)
			}
			
			i++
		}
		while(KvGotoNextKey(kv))
	}
	
	CloseHandle(kv)
	
	LoadMarket()
}

CheckMarket()
{
	new Handle:kv
	kv = CreateKeyValues("Market")
	
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
					new String:szSteamID[32]
					KvGetString(kv, "steamid", szSteamID, sizeof(szSteamID))
					
					DeleteClientItem(szSteamID)
					
					KvSetNum(kv, "time", 0)
					KvSetString(kv, "steamid", "none")
					
					KvRewind(kv)
					KeyValuesToFile(kv, g_Path)
				}
			}
		}
		while(KvGotoNextKey(kv))
	}
	
	CloseHandle(kv)
}

public Action:CmdReloadMarket(client, args)
{
	LoadMarket()
}

LoadMarket()
{
	new Handle:kv
	kv = CreateKeyValues("Market")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvGotoFirstSubKey(kv))
	{
		new i
		new price
		new String:szItem[32]
		
		do
		{
			KvGetSectionName(kv, szItem, sizeof(szItem))
			
			if(KvGetNum(kv, "time") == 0)
			{
				g_ItemUsed[i] = false
				price = KvGetNum(kv, "price")
				g_MarketListPrices[i] = price
				
				FormatEx(g_MarketList[i], MAX_ITEM_LENGTH, "%s [%d$] [7 Days]", szItem, price)
			}
			else
			{
				g_ItemUsed[i] = true
				
				new String:szTime[64]
				FormatTime(szTime, sizeof(szTime), "%d/%m/%Y", KvGetNum(kv, "time"))
				
				FormatEx(g_MarketList[i], MAX_ITEM_LENGTH, "%s [Free at %s]", szItem, szTime)
			}
			
			i++
		}
		while(KvGotoNextKey(kv))
	}
	
	CloseHandle(kv)
}

SetClientItem(client, const String:szSteamID[], item)
{
	g_Market[client] = item
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	new Handle:kv
	kv = CreateKeyValues("Data")
	
	FileToKeyValues(kv, szPath)
	
	KvSetNum(kv, "item", item)
	
	KvRewind(kv)
	KeyValuesToFile(kv, szPath)
	
	CloseHandle(kv)
}

DeleteClientItem(const String:szSteamID[])
{
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	new Handle:kv
	kv = CreateKeyValues("Data")
	
	FileToKeyValues(kv, szPath)
	
	KvSetNum(kv, "item", -1)
	
	KvRewind(kv)
	KeyValuesToFile(kv, szPath)
	
	CloseHandle(kv)
}