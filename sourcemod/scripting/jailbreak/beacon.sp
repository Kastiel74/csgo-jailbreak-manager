/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Basefuncommands Plugin
 * Provides beacon functionality
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#define BEACON_RADIUS 375.0

int g_Serial_Gen = 0;
int g_HaloSprite = -1;
int g_BeamSprite = -1;
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... };

int redColor[4] = {255, 75, 75, 255};
int blueColor[4] = {75, 75, 255, 255};
int greyColor[4] = {128, 128, 128, 255};

public void OnMapStart()
{
	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}
	
	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}
	
	delete gameConfig;
}

void CreateBeacon(int client)
{
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);	
}

void KillBeacon(int client)
{
	g_BeaconSerial[client] = 0;

	if (IsClientInGame(client))
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

void KillAllBeacons()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		KillBeacon(i);
	}
}

public Action Timer_Beacon(Handle timer, any value)
{
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client)
		|| !IsPlayerAlive(client)
		|| g_BeaconSerial[client] != serial)
	{
		KillBeacon(client);
		return Plugin_Stop;
	}
	
	int team = GetClientTeam(client);

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;
	
	if (g_BeamSprite > -1 && g_HaloSprite > -1)
	{
		TE_SetupBeamRingPoint(vec, 10.0, BEACON_RADIUS, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
		TE_SendToAll();
		
		if (team == 2)
		{
			TE_SetupBeamRingPoint(vec, 10.0, BEACON_RADIUS, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, redColor, 10, 0);
		}
		else if (team == 3)
		{
			TE_SetupBeamRingPoint(vec, 10.0, BEACON_RADIUS, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, blueColor, 10, 0);
		}
		
		TE_SendToAll();
	}
		
	return Plugin_Continue;
}