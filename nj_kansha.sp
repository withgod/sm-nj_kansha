/**
* vim: set ts=4 
* Author: withgod <noname@withgod.jp>
* GPL 2.0
* 
**/
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <steamtools>
#include <dbi>

#define STRING_MAX 256
#define SAVE_THRESHOLD 10
#define PLUGIN_VERSION "0.1.1"
#define URL_PREFIX "http://fps.withgod.jp/kansha/"

new String:_err[STRING_MAX];
new Handle:g_njKanshaEnable;
new Handle:g_njKanshaTag;
new Handle:db;
new jumpCounter[STRING_MAX];
new maxclients;
new g_currentMapID = 0;

public Plugin:myinfo = 
{
	name = "nj_kansha",
	author = "withgod",
	description = "Kansha no JUMP!",
	version = PLUGIN_VERSION,
	url = "http://github.com/withgod/sm-nj_kansha"
};

public OnPluginStart()
{
	g_njKanshaEnable = CreateConVar("nj_kansha", "1", "kansha plugin Enable/Disable (0 = disabled | 1 = enabled)", 0, true, 0.0, true, 1.0);
	g_njKanshaTag    = CreateConVar("nj_kansha_tag", "default", "kansha plugin tag cvar");

	CreateConVar("nj_kansha_version", PLUGIN_VERSION, "Kansha no Jump Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	RegConsoleCmd("kansha", ShowStatusInBrowser);

	maxclients = GetMaxClients();


	HookEvent("player_changeclass", OnChangeClass, EventHookMode_Pre);

	db = SQL_DefConnect(_err, sizeof(_err));
	if (db == INVALID_HANDLE)
	{
		PrintToServer("[nj][kansha] can't connect db %s [code=00]", _err);
	}
	else
	{
		SQL_FastQuery(db, "SET NAMES \"UTF8\""); //fuck hack mysql
		CountUpAllStart();
	}
}

public Action:OnChangeClass(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	PrintToChat(client, "[nj]detect change or start class. countup restart.");
	CountUpEnd(client);
	CountUpStart(client);
}

public OnPluginEnd()
{
	if (db != INVALID_HANDLE)
	{
		CountUpAllEnd();
		CloseHandle(db);
	}
}

public OnMapStart()
{
	g_currentMapID = 0;
	maxclients = GetMaxClients();
	UpdateMaps();
	CountUpAllStart();
}

public OnMapEnd()
{
	CountUpAllEnd();
}

public OnClientPutInServer(client)
{
	UpdateSteamid(client);
	CountUpStart(client);
	ShowPluginMsg(client);
}

public OnClientDisconnect(client)
{
	CountUpEnd(client);
}

public ShowPluginMsg(client)
{
	if (GetConVarBool(g_njKanshaEnable))
	{
		decl String:steamcomid[STRING_MAX];
		Steam_GetCSteamIDForClient(client, steamcomid, STRING_MAX);
		PrintToChat(client, "[nj]kansha no plugin %s", URL_PREFIX);
		PrintToChat(client, "[nj]your stats %suser/%s", URL_PREFIX, steamcomid);
		PrintToChat(client, "[nj]your stats show in steambrowser !kansha");
	}
}

public Action:ShowStatusInBrowser(client, args)
{
	decl String:steamcomid[STRING_MAX], String:url[STRING_MAX];
	Steam_GetCSteamIDForClient(client, steamcomid, STRING_MAX);
	Format(url, STRING_MAX, "%suser/%s", URL_PREFIX, steamcomid);
	//PrintToServer("[nj]open in [%s]", url);
	ShowMOTDPanel(client, "Kansha no Plugin Status", url, MOTDPANEL_TYPE_URL);
}

public GetSteamidId(client)
{
	new steamid_id = 0;
	new Handle:hSelectQuery = INVALID_HANDLE;
	decl String:steamcomid[STRING_MAX], String:steamid[STRING_MAX];
	Steam_GetCSteamIDForClient(client, steamcomid, STRING_MAX);
	GetClientAuthString(client, steamid, STRING_MAX);
	hSelectQuery = SQL_PrepareQuery(db, "select id from nj_steamids where steamid = ? and steamcomid = ? limit 1", _err, sizeof(_err));
	if (hSelectQuery == INVALID_HANDLE)
	{
		PrintToServer("[nj][kansha] can't create prepare statent[code=31][%s]", _err);
	}
	else
	{
		SQL_BindParamString(hSelectQuery, 0, steamid, false);
		SQL_BindParamString(hSelectQuery, 1, steamcomid, false);
		if (!SQL_Execute(hSelectQuery))
		{
			SQL_GetError(hSelectQuery, _err, STRING_MAX);
			PrintToServer("[nj][kansha] can't execute prepare statent[code=32][%s]", _err);
		}
		else
		{
			while (SQL_FetchRow(hSelectQuery))
			{
				steamid_id = SQL_FetchInt(hSelectQuery, 0);
			}
			//PrintToServer("[nj][kansha] UpdateSteamid steamid_id[%i]", steamid_id);
		}
	}
	if (hSelectQuery != INVALID_HANDLE)
		CloseHandle(hSelectQuery);

	return steamid_id;
}

public GetMapId()
{
	new String:currentMap[STRING_MAX];
	GetCurrentMap(currentMap, STRING_MAX);
	new Handle:hSelectQuery = INVALID_HANDLE;

	hSelectQuery = SQL_PrepareQuery(db, "select id from nj_maps where mapname = ? limit 1", _err, sizeof(_err));
	if (hSelectQuery == INVALID_HANDLE)
	{
		PrintToServer("[nj][kansha] can't create prepare statent[code=41][%s]", _err);
	}
	else
	{
		SQL_BindParamString(hSelectQuery, 0, currentMap, false);
		if (!SQL_Execute(hSelectQuery))
		{
			SQL_GetError(hSelectQuery, _err, STRING_MAX);
			PrintToServer("[nj][kansha] can't execute prepare statent[code=42][%s]", _err);
		}
		else
		{
			while (SQL_FetchRow(hSelectQuery))
			{
				g_currentMapID = SQL_FetchInt(hSelectQuery, 0);
			}
		}
	}
	if (hSelectQuery != INVALID_HANDLE)
		CloseHandle(hSelectQuery);
}

public UpdateSteamid(client)
{
	if (GetConVarBool(g_njKanshaEnable) && db != INVALID_HANDLE)
	{
		new steamid_id = GetSteamidId(client);
		new Handle:hInsertQuery = INVALID_HANDLE;
		new Handle:hSelectQuery = INVALID_HANDLE;
		decl String:steamcomid[STRING_MAX], String:nickname[STRING_MAX], String:steamid[STRING_MAX];
		Steam_GetCSteamIDForClient(client, steamcomid, STRING_MAX);
		GetClientName(client, nickname, STRING_MAX);
		GetClientAuthString(client, steamid, STRING_MAX);
		if (steamid_id == 0) {
			PrintToServer("[nj][kansha] UpdateSteamid nickname[%s]steamid[%s]steamcomid[%s]", nickname, steamid, steamcomid);

			hInsertQuery = SQL_PrepareQuery(db, "insert into nj_steamids(steamid, steamcomid, created_at) values(?, ?, now())", _err, sizeof(_err));
			if (hInsertQuery == INVALID_HANDLE)
			{
				PrintToServer("[nj][kansha] can't create prepare statent[code=21][%s]", _err);
			}
			else
			{
				SQL_BindParamString(hInsertQuery, 0, steamid, false);
				SQL_BindParamString(hInsertQuery, 1, steamcomid, false);
				if (!SQL_Execute(hInsertQuery))
				{
					SQL_GetError(hInsertQuery, _err, STRING_MAX);
					PrintToServer("[nj][kansha] can't execute prepare statent[code=22][%s] if duplicate entry ignore this", _err);
				}
			}
			steamid_id = GetSteamidId(client);
		}

		if (steamid_id)
		{
			hInsertQuery = SQL_PrepareQuery(db, "insert into nj_steam_nicknames(nj_steamid_id, nickname, created_at) values(?, ?, now())", _err, sizeof(_err));
			if (hInsertQuery == INVALID_HANDLE)
			{
				PrintToServer("[nj][kansha] can't create prepare statent[code=25][%s]", _err);
			}
			else
			{
				SQL_BindParamInt(hInsertQuery, 0, steamid_id, false);
				SQL_BindParamString(hInsertQuery, 1, nickname, false);
				if (!SQL_Execute(hInsertQuery))
				{
					SQL_GetError(hInsertQuery, _err, STRING_MAX);
					//lazy fix commentout
					//PrintToServer("[nj][kansha] can't execute prepare statent[code=26][%s] if duplicate entry ignore this", _err);
				}
			}
		}

		if (hInsertQuery != INVALID_HANDLE)
			CloseHandle(hInsertQuery);
		if (hSelectQuery != INVALID_HANDLE)
			CloseHandle(hSelectQuery);
	}
}

public UpdateMaps()
{
	if (GetConVarBool(g_njKanshaEnable) && db != INVALID_HANDLE)
	{
		GetMapId();
		if (!g_currentMapID)
		{
			new Handle:hInsertQuery = INVALID_HANDLE;
			new String:currentMap[STRING_MAX];
			GetCurrentMap(currentMap, STRING_MAX);
			PrintToServer("[nj][kansha] UpdateMaps mapname[%s]", currentMap);
			hInsertQuery = SQL_PrepareQuery(db, "insert into nj_maps(mapname, created_at) values(?, now())", _err, sizeof(_err));
			if (hInsertQuery == INVALID_HANDLE)
			{
				PrintToServer("[nj][kansha] can't create prepare statent[code=11][%s]", _err);
			}
			else
			{
				SQL_BindParamString(hInsertQuery, 0, currentMap, false);
				if (!SQL_Execute(hInsertQuery))
				{
					SQL_GetError(hInsertQuery, _err, STRING_MAX);
					PrintToServer("[nj][kansha] can't execute prepare statent[code=12][%s] if duplicate entry ignore this", _err);
				}
			}
			CloseHandle(hInsertQuery);
		}
		GetMapId();
	}
}

public UpdateStats(client)
{
	if (GetConVarBool(g_njKanshaEnable) && db != INVALID_HANDLE && jumpCounter[client] > SAVE_THRESHOLD)
	{
		new TFClassType:theClass = TF2_GetPlayerClass(client);
		new Handle:hInsertQuery = INVALID_HANDLE;
		decl String:steamcomid[STRING_MAX], String:steamid[STRING_MAX], String:nickname[STRING_MAX], String:tags[STRING_MAX];
		GetConVarString(g_njKanshaTag, tags, STRING_MAX);
		Steam_GetCSteamIDForClient(client, steamcomid, STRING_MAX);
		GetClientName(client, nickname, STRING_MAX);
		GetClientAuthString(client, steamid, STRING_MAX);
		/*
		decl String:currentMap[STRING_MAX];
		GetCurrentMap(currentMap, STRING_MAX);
		PrintToServer(
		"client[%i]nickname[%s]class[%i]steamid[%s]steamcomid[%s]jumpcount[%i]mapname[%s]mapid[%i]",
		client, nickname, theClass, steamid, steamcomid, jumpCounter[client], currentMap, g_currentMapID
		);
		*/
		new steamid_id = GetSteamidId(client);

		if (steamid_id)
		{
			hInsertQuery = SQL_PrepareQuery(
			db,
			"insert into nj_kansha_results(jump_count, nj_class_id, nj_steamid_id, nj_map_id, tags, created_at) values(?, ?, ?, ?, ?, now())",
			_err, sizeof(_err)
			);
			if (hInsertQuery == INVALID_HANDLE)
			{
				PrintToServer("[nj][kansha] can't create prepare statent[code=01][%s]", _err);
			}
			else
			{
				SQL_BindParamInt(hInsertQuery, 0, jumpCounter[client], false);
				switch (theClass)
				{
					case TFClass_DemoMan:
					{
						SQL_BindParamInt(hInsertQuery, 1, 4, false);
					}
					case TFClass_Soldier:
					{
						SQL_BindParamInt(hInsertQuery, 1, 3, false);
					}
				}
				SQL_BindParamInt(hInsertQuery, 2, steamid_id, false);
				SQL_BindParamInt(hInsertQuery, 3, g_currentMapID, false);
				SQL_BindParamString(hInsertQuery, 4, tags, false);
				if (!SQL_Execute(hInsertQuery))
				{
					SQL_GetError(hInsertQuery, _err, STRING_MAX);
					PrintToServer("[nj][kansha] can't execute prepare statent[code=02][%s]", _err);
					PrintToServer("[nj][kansha]client[%i]class[%i]steamid_id[%s]jumpcount[%i]mapid[%i]",
					client, theClass, steamid_id, jumpCounter[client], g_currentMapID);
				}
			}
		}
		CloseHandle(hInsertQuery);
	}
}

public CountUpStart(client)
{
	if (GetConVarBool(g_njKanshaEnable) && db != INVALID_HANDLE)
	{
		if (IsClientInGame(client)) {
			jumpCounter[client] = 0;
			UpdateSteamid(client);
			SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public CountUpAllStart()
{
	new i = 1;
	for (i = 1; i < maxclients + 1; i++) {
		CountUpStart(i);
	}
}

public CountUpEnd(client)
{
	if (GetConVarBool(g_njKanshaEnable) && db != INVALID_HANDLE)
	{
		if (IsClientInGame(client)) {
			UpdateStats(client);
			SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public CountUpAllEnd()
{
	new i = 1;
	for (i = 1; i < maxclients + 1; i++) {
		CountUpEnd(i);
	}
}

/*
damagetype
32      = hit ground
2359360 = rocket launcher(normal, direct hit, liberty, rocket jumper)
2097216 = equalizer(taunt suicide)

262208  = grenade
2490432 = sticky bomb(normal, scottish)
393280  = sticky jumper


*/
public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		new iButtons = GetClientButtons(client);
		new TFClassType:theClass = TF2_GetPlayerClass(client);
		//PrintToServer("debug message [%i/%i/%i/%i/%i]", client, theClass , attacker, iButtons, damagetype);
		if (theClass == TFClass_Soldier)
		{
			if (iButtons & IN_DUCK && damagetype == 2359360 && attacker == client)
			{
				jumpCounter[client]++;
				decl String:tmpString[STRING_MAX];
				Format(tmpString, sizeof(tmpString), "soldier jump[%i]", jumpCounter[client]);
				PrintHintText(client, tmpString);
			}
		}
		if (theClass == TFClass_DemoMan)
		{
			if ((damagetype == 2490432 || damagetype == 393280) && attacker == client)
			{
				jumpCounter[client]++;
				decl String:tmpString[STRING_MAX];
				Format(tmpString, sizeof(tmpString), "demoman jump[%i]", jumpCounter[client]);
				PrintHintText(client, tmpString);
			}
		}
	}
	return Plugin_Continue;
}

/*
debug function.
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
//PrintToServer("%i, %i", TFClass_DemoMan, TFClass_Soldier);
if(buttons & IN_ATTACK)
{
PrintToChatAll("client[%i] is attacking status[%i]", client, buttons);
}
if(buttons & IN_DUCK)
{
PrintToChatAll("client[%i] is ducking status[%i]", client, buttons);
}
return Plugin_Continue;
}
*/