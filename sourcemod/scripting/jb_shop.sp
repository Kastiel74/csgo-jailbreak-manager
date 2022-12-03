#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

#define MAX_GUARD_ITEMS 8
#define MAX_PRISONER_ITEMS 20
#define MAX_ITEM_LENGTH 32

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new String:g_Path[PLATFORM_MAX_PATH]

new g_PrisonerShopPrices[MAX_PRISONER_ITEMS]
new String:g_PrisonerShopList[MAX_PRISONER_ITEMS][MAX_ITEM_LENGTH]

new g_GuardShopPrices[MAX_GUARD_ITEMS]
new String:g_GuardShopList[MAX_GUARD_ITEMS][MAX_ITEM_LENGTH]

new Handle:g_cEnableShop

public Plugin:myinfo = 
{
	name = "Jailbreak Shop",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_shop", CmdShop)
	
	AddCommandListener(Hook_BuyAmmo, "buyammo1")
	
	RegAdminCmd("jb_reloadshop", CmdReloadShop, ADMFLAG_ROOT, "Reloads item names and prices")
	
	BuildPath(Path_SM, g_Path, sizeof(g_Path), "configs/jailbreak/shop.cfg")
	
	g_cEnableShop = CreateConVar("jb_enable_shop", "1", "Enable Shop? [1 = Yes | 0 = No]", _, true, 0.0, true, 1.0)
	
	LoadShop()
}

public Action:CmdShop(client, args)
{
	if(!GetConVarBool(g_cEnableShop))
	{
		PrintToChat(client, "%s Shop is disabled", g_Tag)
		return Plugin_Handled
	}
	
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s You are not alive", g_Tag)
		return Plugin_Handled
	}
	
	if(JB_IsSpecialDay() || JB_IsLastRequest())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	switch(GetClientTeam(client))
	{
		case CS_TEAM_T:
		{
			PrisonerShop(client)
		}
		case CS_TEAM_CT:
		{
			GuardShop(client)
		}
	}
	
	return Plugin_Handled
}

public Action:Hook_BuyAmmo(client, const String:command[], args)
{
	FakeClientCommand(client, "sm_shop")
}

PrisonerShop(client)
{
	new Handle:menu = CreateMenu(t_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Jailbreak Shop: %d$", JB_GetClientDollars(client))
	
	new String:szItem[32]
	
	for(new i = 0; i < MAX_PRISONER_ITEMS; i++)
	{
		IntToString(i, szItem, sizeof(szItem))
		AddMenuItem(menu, szItem, g_PrisonerShopList[i])
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public t_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new i = StringToInt(item)
			
			if(JB_GetClientDollars(client) >= g_PrisonerShopPrices[i])
			{
				JB_SetClientDollars(client, JB_GetClientDollars(client) - g_PrisonerShopPrices[i])
				
				switch(i)
				{
					case 0:
					{
						GivePlayerItem(client, "weapon_flashbang")
					}
					case 1:
					{
						GivePlayerItem(client, "weapon_smokegrenade")
					}
					case 2:
					{
						GivePlayerItem(client, "weapon_hegrenade")
					}
					case 3:
					{
						GivePlayerItem(client, "weapon_molotov")
					}
					case 4:
					{
						GivePlayerItem(client, "weapon_hegrenade")
						GivePlayerItem(client, "weapon_molotov")
						GivePlayerItem(client, "weapon_flashbang")
						GivePlayerItem(client, "weapon_smokegrenade")
					}
					case 5:
					{
						GivePlayerItem(client, "weapon_tagrenade")
					}
					case 6:
					{
						SetEntityHealth(client, 100)
					}
					case 7:
					{
						GivePlayerItem(client, "weapon_healthshot")
					}
					case 8:
					{
						SetEntityHealth(client, 150)
						GivePlayerItem(client, "item_kevlar")
						ClientCommand(client, "play items/smallmedkit1")
					}
					case 9:
					{
						GivePlayerItem(client, "weapon_taser")
					}
					case 10:
					{
						GiveWeapon(client, "weapon_deagle", CS_SLOT_SECONDARY)
					}
					case 11:
					{
						GiveWeapon(client, "weapon_ssg08", CS_SLOT_PRIMARY)
					}
					case 12:
					{
						SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.3)
					}
					case 13:
					{
						SetEntityGravity(client, 0.5)
					}
					case 14:
					{
						JB_SetMultiJump(client, 2)
					}
					case 15:
					{
						JB_SetLongJump(client)
					}
					case 16:
					{
						SetEntityRenderMode(client, RENDER_TRANSCOLOR)
						SetEntityRenderColor(client, 255, 255, 255, 50)
						ClientCommand(client, "play ui/achievement_earned")
					}
					case 17:
					{
						GiveWeapon(client, "weapon_awp", CS_SLOT_PRIMARY)
					}
					case 18:
					{
						TryYourLuck(client)
					}
					case 19:
					{
						GivePlayerItem(client, "weapon_breachcharge")
					}
				}
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

GuardShop(client)
{
	new Handle:menu = CreateMenu(ct_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Jailbreak Shop: %d$", JB_GetClientDollars(client))
	
	new String:szItem[32]
	
	for(new i = 0; i < MAX_GUARD_ITEMS; i++)
	{
		IntToString(i, szItem, sizeof(szItem))
		AddMenuItem(menu, szItem, g_GuardShopList[i])
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public ct_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new i = StringToInt(item)
			
			if(JB_GetClientDollars(client) >= g_GuardShopPrices[i])
			{
				JB_SetClientDollars(client, JB_GetClientDollars(client) - g_GuardShopPrices[i])
				
				switch(i)
				{
					case 0:
					{
						GivePlayerItem(client, "weapon_tagrenade")
					}
					case 1:
					{
						GivePlayerItem(client, "weapon_hegrenade")
					}
					case 2:
					{
						GivePlayerItem(client, "weapon_molotov")
					}
					case 3:
					{
						GivePlayerItem(client, "weapon_healthshot")
					}
					case 4:
					{
						SetEntityHealth(client, 150)
						GivePlayerItem(client, "item_kevlar")
						ClientCommand(client, "play items/smallmedkit1")
					}
					case 5:
					{
						JB_SetRegeneration(client)
						SetEntityHealth(client, 150)
					}
					case 6:
					{
						GivePlayerItem(client, "weapon_breachcharge")
					}
					case 7:
					{
						JB_SetBFProtection(client)
						SetEntityHealth(client, 255)
						GivePlayerItem(client, "item_assaultsuit")
					}
				}
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

TryYourLuck(client)
{
	new num = GetRandomInt(1, 100)
	
	if(num < 50)
	{
		if(num < 30)
		{
			GivePlayerItem(client, "weapon_molotov")
			PrintToChat(client, "%s You won a \x07Molotov", g_Tag)
		}
		else
		{
			SetEntityHealth(client, 150)
			GivePlayerItem(client, "item_kevlar")
			ClientCommand(client, "play items/smallmedkit1")
			PrintToChat(client, "%s You won \x07150HP + Armor", g_Tag)
		}
	}
	else if(num < 80)
	{
		if(num < 60)
		{
			GivePlayerItem(client, "weapon_breachcharge")
			PrintToChat(client, "%s You won \x073 Breachcharges", g_Tag)
		}
		else if(num < 75)
		{
			JB_SetLongJump(client)
			PrintToChat(client, "%s You won \x07Longjump", g_Tag)
		}
		else
		{
			JB_SetRegeneration(client)
			SetEntityHealth(client, 150)
			PrintToChat(client, "%s You won \x07Health Regeneration", g_Tag)
		}
	}
	else if(num < 95)
	{
		num = GetRandomInt(1, 4)
		
		switch(num)
		{
			case 1:
			{
				GiveWeapon(client, "weapon_revolver", CS_SLOT_SECONDARY)
				PrintToChat(client, "%s You won a \x07Revolver\x01 with \x071\x01 bullet", g_Tag)
			}
			case 2:
			{
				GiveWeapon(client, "weapon_deagle", CS_SLOT_SECONDARY)
				PrintToChat(client, "%s You won a \x07Deagle\x01 with \x071\x01 bullet", g_Tag)
			}
			case 3:
			{
				GiveWeapon(client, "weapon_ssg08", CS_SLOT_PRIMARY)
				PrintToChat(client, "%s You won a \x07SSG\x01 with \x071\x01 bullet", g_Tag)
			}
			case 4:
			{
				GiveWeapon(client, "weapon_g3sg1", CS_SLOT_PRIMARY)
				PrintToChat(client, "%s You won a \x07G3SG1\x01 with \x071\x01 bullet", g_Tag)
			}
		}
	}
	else
	{
		GiveWeapon(client, "weapon_awp", CS_SLOT_PRIMARY)
		PrintToChat(client, "%s You won an \x07AWP\x01 with \x071\x01 bullet", g_Tag)
	}
}

GiveWeapon(client, const String:szWeapon[], slot)
{
	new ent
	
	if((ent = GetPlayerWeaponSlot(client, slot)) != -1)
	{
		RemovePlayerItem(client, ent)
		AcceptEntityInput(ent, "Kill")
	}
	
	new weapon = GivePlayerItem(client, szWeapon)
	
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0)
	SetEntProp(weapon, Prop_Send, "m_iClip1", 1)
}

public Action:CmdReloadShop(client, args)
{
	LoadShop()
}

LoadShop()
{
	new Handle:kv
	kv = CreateKeyValues("Shop")
	
	FileToKeyValues(kv, g_Path)
	
	if(KvJumpToKey(kv, "Prisoner Shop"))
	{
		if(KvGotoFirstSubKey(kv, false))
		{
			new i
			new price
			new String:szItem[32]
			
			do
			{
				KvGetSectionName(kv, szItem, sizeof(szItem))
				
				price = KvGetNum(kv, NULL_STRING)
				g_PrisonerShopPrices[i] = price
				
				FormatEx(g_PrisonerShopList[i], MAX_ITEM_LENGTH, "%s [%d$]", szItem, price)
				
				i++
			}
			while(KvGotoNextKey(kv, false))
		}
	}
	
	KvRewind(kv)
	
	if(KvJumpToKey(kv, "Guard Shop"))
	{
		if(KvGotoFirstSubKey(kv, false))
		{
			new i
			new price
			new String:szItem[32]
			
			do
			{
				KvGetSectionName(kv, szItem, sizeof(szItem))
				
				price = KvGetNum(kv, NULL_STRING)
				g_GuardShopPrices[i] = price
				
				FormatEx(g_GuardShopList[i], MAX_ITEM_LENGTH, "%s [%d$]", szItem, price)
				
				i++
			}
			while(KvGotoNextKey(kv, false))
		}
	}
	
	CloseHandle(kv)
}