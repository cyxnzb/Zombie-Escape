#include <zombie_escape>

// Static (Change it if you need)
new const g_szVaultName[] = "Escape_Coins"
new const g_szLogFile[] = "Escape-Coins.log" // MySQL Errors log file

// Database
enum _:DataBase
{
	Host[64] = 0,
	User[32],
	Pass[32],
	DB[128]
}

// MySQL Table
new const g_szTable[] = 
" \
	CREATE TABLE IF NOT EXISTS `zombie_escape` \
	( \
		`SteamID` varchar(34) NOT NULL, \
		`EC` int(16) NOT NULL, \
		PRIMARY KEY (`SteamID`) \
	); \
"

// Global Variables.
new g_iSaveType,
	g_iMaxCoins,
	g_iStartCoins,
	g_iVaultHandle,
	g_iDamageCoins,
	g_iEscapeSuccess, 
	g_iHumanInfected,
	g_iEscapeCoins[MAX_PLAYERS+1],
	bool:g_bEarnChatNotice,
	Float:g_flRequiredDamage,
	Float:g_flCollectDamage[MAX_PLAYERS+1]

// String.
new g_szDataBaseInfo[DataBase]

// MySQL
new Handle:g_hTuple

// Forward allows registering new natives.
public plugin_natives()
{
	// Create new natives.
	register_native("ze_get_escape_coins", "native_ze_get_escape_coins", 1)
	register_native("ze_set_escape_coins", "native_ze_set_escape_coins", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Escape Coins System", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Escape Coins System for Items Manager")
	
	// Hook Chains
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "Fw_TakeDamage_Post", 1)
	
	// Commands
	register_clcmd("say /EC", "Coins_Info")
	register_clcmd("say_team /EC", "Coins_Info")
	register_clcmd("say /ec", "Coins_Info")
	register_clcmd("say_team /ec", "Coins_Info")
	
	// Cvars
	bind_pcvar_num(register_cvar("ze_coins_save_type", "0"), g_iSaveType)
	bind_pcvar_num(register_cvar("ze_escape_success_coins", "15"), g_iEscapeSuccess)
	bind_pcvar_num(register_cvar("ze_human_infected_coins", "5"), g_iHumanInfected)
	bind_pcvar_num(register_cvar("ze_damage_coins", "4"), g_iDamageCoins)
	bind_pcvar_num(register_cvar("ze_start_coins", "50"), g_iStartCoins)
	bind_pcvar_num(register_cvar("ze_max_coins", "200000"), g_iMaxCoins)
	bind_pcvar_num(register_cvar("ze_earn_chat_notice", "1"), g_bEarnChatNotice)
	bind_pcvar_float(register_cvar("ze_damage_required", "300"), g_flRequiredDamage)
	
	bind_pcvar_string(register_cvar("ze_ec_host", "localhost"), g_szDataBaseInfo[Host], charsmax(g_szDataBaseInfo))
	bind_pcvar_string(register_cvar("ze_ec_user", "user"), g_szDataBaseInfo[User], charsmax(g_szDataBaseInfo))
	bind_pcvar_string(register_cvar("ze_ec_pass", "pass"), g_szDataBaseInfo[Pass], charsmax(g_szDataBaseInfo))
	bind_pcvar_string(register_cvar("ze_ec_dbname", "dbname"), g_szDataBaseInfo[DB], charsmax(g_szDataBaseInfo))
	
	// Initialize MySQL - Delay 0.1 second required so we make sure that our zombie_escape.cfg already executed and cvars values loaded from it
	set_task(0.1, "Delay_MySQL_Init")
}

// Forward called when server desactivation or plugin unloaded.
public plugin_end()
{
	if (g_iSaveType == 1) if (g_hTuple != Empty_Handle) SQL_FreeHandle(g_hTuple)
}

public Coins_Info(id)
{
	// Print colored message on chat for player.
	ze_colored_print(id, "%L", LANG_PLAYER, "COINS_INFO", g_iEscapeCoins[id])
}

public Delay_MySQL_Init()
{
	// Initialize database.
	MySQL_Init()
}

public MySQL_Init()
{
	if (g_iSaveType == 0)
		return
		
	g_hTuple = SQL_MakeDbTuple(g_szDataBaseInfo[Host], g_szDataBaseInfo[User], g_szDataBaseInfo[Pass], g_szDataBaseInfo[DB])
	
	// Let's ensure that the g_hTuple will be valid, we will access the database to make sure
	new iErrorCode, szError[512], Handle:hSQLConnection
	
	hSQLConnection = SQL_Connect(g_hTuple, iErrorCode, szError, charsmax(szError))
	
	if(hSQLConnection != Empty_Handle)
	{
		log_amx("[MySQL] Successfully connected to host: %s (ALL IS OK).", g_szDataBaseInfo[Host])
		SQL_FreeHandle(hSQLConnection)
	}
	else
	{
		// Disable plugin, and display the error
		set_fail_state("Failed to connect to MySQL database: %s", szError)
	}
	
	// Create our table
	SQL_ThreadQuery(g_hTuple, "QueryCreateTable", g_szTable)
}

public QueryCreateTable(iFailState, Handle:hQuery, szError[], iError, szData[], iSize, Float:flQueueTime) 
{
	SQL_IsFail(iFailState, iError, szError, g_szLogFile)
}

// Forward called when player join the server.
public client_putinserver(id)
{
	// Player is Bot or HLTV?
	if (is_user_bot(id) || is_user_hltv(id))
		return
	
	// Just 1 second delay
	set_task(1.0, "DelayLoad", id)
}

// Forward called when player disconnected from server.
public client_disconnected(id)
{
	// Save EC of player in vault or MySQL
	SaveCoins(id)
}

public DelayLoad(id)
{
	LoadCoins(id)
}
 
// Forward called when round over.
public ze_roundend(WinTeam)
{
	if (WinTeam == ZE_TEAM_HUMAN)
	{
		new iPlayers[MAX_PLAYERS], iAliveCount, id

		// Get index of all alive players.
		get_players(iPlayers, iAliveCount, "ah")

		for(new iNum = 1; iNum <= MaxClients; iNum++)
		{
			// Get player index from Array.
			id = iPlayers[iNum]

			// Reset Var
			g_flCollectDamage[id] = 0.0
			
			// Player 
			if (!ze_is_user_zombie_ex(id))
				continue
			
			// Give player Escape Coins 
			g_iEscapeCoins[id] += g_iEscapeSuccess
			
			// Print colored message on chat for player.
			if (g_bEarnChatNotice) ze_colored_print(id, "%L", LANG_PLAYER, "ESCAPE_SUCCESS_COINS", g_iEscapeSuccess)
		}
	}
}

// Forward called after player infected.
public ze_user_infected(iVictim, iInfector)
{
	if (iInfector == 0) // Server ID
		return

	// Give player Escapes Coins.
	g_iEscapeCoins[iInfector] += g_iHumanInfected
	
	// Print colored message on chat for player.
	if (g_bEarnChatNotice) ze_colored_print(iInfector, "%L", LANG_PLAYER, "HUMAN_INFECTED_COINS", g_iHumanInfected)
}

// Hook called after player take damage. 
public Fw_TakeDamage_Post(iVictim, iInflictor, iAttacker, Float:flDamage, bitsDamageType)
{
	// Player Damage Himself
	if (iVictim == iAttacker || !is_user_alive(iVictim) || !is_user_alive(iAttacker))
		return HC_CONTINUE
	
	// Two Players From one Team
	if (ze_is_user_zombie_ex(iVictim) == ze_is_user_zombie_ex(iAttacker))
		return HC_CONTINUE
	
	// Store Damage For every Player
	g_flCollectDamage[iAttacker] += flDamage
	
	// Damage Calculator Equal or Higher than needed damage
	while (g_flCollectDamage[iAttacker] >= g_flRequiredDamage)
	{
		g_iEscapeCoins[iAttacker] += g_iDamageCoins
		g_flCollectDamage[iAttacker] -= g_flRequiredDamage
	}
	
	return HC_CONTINUE
}

LoadCoins(id)
{
	// Local Variables.
	new szAuthID[34]

	// Get steam id of player.
	get_user_authid(id, szAuthID, charsmax(szAuthID))
	
	switch (g_iSaveType)
	{
		case 0: // nVault
		{			
			// Open the Vault
			g_iVaultHandle = nvault_open(g_szVaultName)

			// Local Variables.
			new szCoins[16], iTimestamp
						
			// Load EC from nVault.
			if (!nvault_lookup(g_iVaultHandle, szAuthID, szCoins, charsmax(szCoins), iTimestamp))
			{
				// Player exist? Load start value then save
				g_iEscapeCoins[id] = g_iStartCoins
			}
			else
			{
				g_iEscapeCoins[id] = str_to_num(szCoins)
			}

			// Close the vault.
			nvault_close(g_iVaultHandle)
		}
		case 1: // MySQL
		{
			new szQuery[128], szData[5]
			formatex(szQuery, charsmax(szQuery), "SELECT `EC` FROM `zombie_escape` WHERE ( `SteamID` = '%s' );", szAuthID)
		
			num_to_str(id, szData, charsmax(szData))
			SQL_ThreadQuery(g_hTuple, "QuerySelectData", szQuery, szData, charsmax(szData))			
		}
	}
}

public QuerySelectData(iFailState, Handle:hQuery, szError[], iError, szData[]) 
{
	if(SQL_IsFail(iFailState, iError, szError, g_szLogFile))
		return
	
	new id = str_to_num(szData)
	
	// No results for this query means that player not saved before
	if(!SQL_NumResults(hQuery))
	{
		// This is new player
		g_iEscapeCoins[id] = g_iStartCoins
		
		// Get user steamid
		new szAuthID[35]
		get_user_authid(id, szAuthID, charsmax(szAuthID))
		
		// Insert his data to our database
		new szQuery[128]
		formatex(szQuery, charsmax(szQuery), "INSERT INTO `zombie_escape` (`SteamID`, `EC`) VALUES ('%s', '%d');", szAuthID, g_iEscapeCoins[id])
		SQL_ThreadQuery(g_hTuple, "QueryInsertData", szQuery)
		return
	}
	
	// Get the "EC" column number (It's 2, always i don't like to hardcode :p)
	new iEC_Column = SQL_FieldNameToNum(hQuery, "EC")
	
	// Read the coins of this player
	g_iEscapeCoins[id] = SQL_ReadResult(hQuery, iEC_Column)
}

public QueryInsertData(iFailState, Handle:hQuery, szError[], iError, szData[], iSize, Float:flQueueTime)
{
	SQL_IsFail(iFailState, iError, szError, g_szLogFile)
}

SaveCoins(id)
{
	new szAuthID[35]
	get_user_authid(id, szAuthID, charsmax(szAuthID))
	
	// Set Him to max if he Higher than Max Value
	if (g_iEscapeCoins[id] > g_iMaxCoins)
		g_iEscapeCoins[id] = g_iMaxCoins

	new szData[16]
	num_to_str(g_iEscapeCoins[id], szData, charsmax(szData))

	switch (g_iSaveType)
	{
		case 0: // nVault
		{
			// Open the Vault
			g_iVaultHandle = nvault_open(g_szVaultName)

			// Save His SteamID, Escape Coins
			nvault_set(g_iVaultHandle, szAuthID, szData)

			// Close the vault.
			nvault_close(g_iVaultHandle)
		}
		case 1: // MySQL
		{
			new szQuery[128]
			formatex(szQuery, charsmax(szQuery), "UPDATE `zombie_escape` SET `EC` = '%d' WHERE `SteamID` = '%s';", g_iEscapeCoins[id], szAuthID)
			SQL_ThreadQuery(g_hTuple, "QueryUpdateData", szQuery)			
		}
	}
}

public QueryUpdateData(iFailState, Handle:hQuery, szError[], iError, szData[], iSize, Float:flQueueTime) 
{
	SQL_IsFail(iFailState, iError, szError, g_szLogFile)
}

// Natives
public native_ze_get_escape_coins(id)
{
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false;
	}
	
	return g_iEscapeCoins[id]
}

public native_ze_set_escape_coins(id, iAmount)
{
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false;
	}
	
	g_iEscapeCoins[id] = iAmount
	
	SaveCoins(id)
	return true;
}