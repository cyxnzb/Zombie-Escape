#include <zombie_escape>

// Constants.
const TASK_COUNTDOWN = 2022
const GAME_CHANCE = 2

// Countdown HUD Position.
const Float:HUD_X = -1.00
const Float:HUD_Y = 0.30

// Enums (Custom Forwards).
enum _:FORWARDS
{
	FORWARD_GAMEMODE_CHOSEN_PRE = 0,
	FORWARD_GAMEMODE_CHOSEN
}

// Enums (Colors Array).
enum 
{
	Red = 0,
	Green,
	Blue
}

// Cvars Variables.
new g_pCvar_iGamemodeDelay
new g_pCvar_iFirstDefaultGame
new g_pCvar_iCountdownMode
new g_pCvar_iCountRandomColor
new g_pCvar_iCountdownColors[3]

// Global Variables.
new g_iGameCount
new g_iCountdown
new g_iSyncMsgHud
new g_iDefaultGame
new g_iFwResult
new g_iGameCurrent
new g_iForwards[FORWARDS]
new bool:g_bIsGameStarted

// Dynamic Arrays.
new Array:g_aGameName
new Array:g_aGameFile

// Forward allows registering natives (called before init).
public plugin_natives()
{
	register_native("ze_gamemode_register", "native_gamemode_register", 0)
	register_native("ze_gamemode_set_default", "native_gamemode_set_default", 0)
	register_native("ze_gamemode_get_current", "native_gamemode_get_current", 0)
	register_native("ze_gamemode_get_name", "native_gamemode_get_name", 0)
	register_native("ze_gamemode_get_id", "native_gamemode_get_id", 0)
	register_native("ze_gamemode_get_count", "native_gamemode_get_count", 0)
	register_native("ze_gamemode_start", "native_gamemode_start", 0)
	register_native("ze_is_gamemode_started", "native_is_gamemode_started", 0)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Gamemodes Manager", ZE_VERSION, AUTHORS)

	// Events.
	register_event("TextMsg", "fw_MapRestart_Event", "a", "2=#Game_Commencing", "2=#Game_will_restart_in", "2=#Round_Draw")

	// Cvars.
	g_pCvar_iGamemodeDelay 			= register_cvar("ze_gamemodes_delay", "10")
	g_pCvar_iFirstDefaultGame 		= register_cvar("ze_gamemodes_firstround", "1")
	g_pCvar_iCountdownMode 			= register_cvar("ze_countdown_mode", "1")
	g_pCvar_iCountRandomColor 		= register_cvar("ze_countdown_random_color", "1")
	g_pCvar_iCountdownColors[Red] 	= register_cvar("ze_countdown_red", "0")
	g_pCvar_iCountdownColors[Green] = register_cvar("ze_countdown_green", "0")
	g_pCvar_iCountdownColors[Blue] 	= register_cvar("ze_countdown_blue", "200")

	// Initialize custom forwards.
	g_iForwards[FORWARD_GAMEMODE_CHOSEN_PRE] 	= CreateMultiForward("ze_gamemode_chosen_pre", ET_CONTINUE, FP_CELL, FP_CELL)
	g_iForwards[FORWARD_GAMEMODE_CHOSEN] 		= CreateMultiForward("ze_gamemode_chosen", ET_IGNORE, FP_CELL)

	// Initialize dynamic array's.
	g_aGameName = ArrayCreate(MAX_NAME_LENGTH)
	g_aGameFile = ArrayCreate(64)

	// Static Values.
	g_iDefaultGame = ZE_WRONG_GAME
	g_iGameCurrent = ZE_WRONG_GAME
	g_iSyncMsgHud = CreateHudSyncObj()
}

// Forward called before game started.
public ze_game_started_pre()
{
	// Remove task.
	remove_task(TASK_COUNTDOWN)	

	// Reset Var.
	g_iGameCurrent = ZE_WRONG_GAME
}

// Forward called after game started.
public ze_game_started()
{
	// Pause all gamemodes plugins.
	pausePlugins()

	// Get countdown period.
	g_iCountdown = get_pcvar_num(g_pCvar_iGamemodeDelay)

	// New Task, for gamemode countdown.
	set_task(1.0, "show_CountDown", TASK_COUNTDOWN, "", 0, "b")
}

// Hook called when round restart.
public fw_MapRestart_Event()
{
	// Remove task (stop countdown).
	remove_task(TASK_COUNTDOWN)
}

public show_CountDown(iTask)
{
	// Countdown is over?
	if (g_iCountdown <= 0)
	{
		// Choose gamemode.
		chooseGame()

		// Stop countdown.
		remove_task(iTask)
		return
	}

	// Get countdown mode (HUD type).
	switch (get_pcvar_num(g_pCvar_iCountdownMode)) 
	{
		case 0: // Normal Text (center)
			client_print(0, print_center, "%L", LANG_PLAYER, "RUN_NOTICE", g_iCountdown--)
		case 1: // HUD.
		{
			// Show countdown HUD for all clients.
			if (get_pcvar_num(g_pCvar_iCountRandomColor))
				set_hudmessage(random(256), random(256), random(256), HUD_X, HUD_Y, 0, 1.0, 1.0, 0.0, 0.0)
			else 
				set_hudmessage(get_pcvar_num(g_pCvar_iCountdownColors[Red]), get_pcvar_num(g_pCvar_iCountdownColors[Green]), get_pcvar_num(g_pCvar_iCountdownColors[Blue]), HUD_X, HUD_Y, 0, 1.0, 1.0, 0.0, 0.0)
			ShowSyncHudMsg(0, g_iSyncMsgHud, "%L", LANG_PLAYER, "RUN_NOTICE", g_iCountdown--)
		}
		case 2: // Director HUD.
		{
			// Show countdown DHUD for all clients.
			if (get_pcvar_num(g_pCvar_iCountRandomColor))
				set_dhudmessage(random(256), random(256), random(256), HUD_X, HUD_Y, 0, 1.0, 1.0, 0.0, 0.0)
			else 
				set_dhudmessage(get_pcvar_num(g_pCvar_iCountdownColors[Red]), get_pcvar_num(g_pCvar_iCountdownColors[Green]), get_pcvar_num(g_pCvar_iCountdownColors[Blue]), HUD_X, HUD_Y, 0, 1.0, 1.0, 0.0, 0.0)
			show_dhudmessage(0, "%L", LANG_PLAYER, "RUN_NOTICE", g_iCountdown--)
		}
	}
}

public chooseGame()
{
	// It's a first round?
	if ((ze_get_round_number() > 1) && !get_pcvar_num(g_pCvar_iFirstDefaultGame))
	{
		// Local Variables.
		new szFileName[64], iTime, iGame

		// Repeat some times!
		while (iTime < GAME_CHANCE)
		{
			// Try start gamemode.
			for (iGame = 0; iGame < g_iGameCount; iGame++)
			{
				// Get filename of gamemode from dynamic array.
				ArrayGetString(g_aGameFile, iGame, szFileName, charsmax(szFileName))

				// Unpause plugin first
				unpause("c", szFileName)

				// Execute forward ze_gamemode_chosen_pre(game_id) and get return value.
				ExecuteForward(g_iForwards[FORWARD_GAMEMODE_CHOSEN_PRE], g_iFwResult, iGame, false)

				// Check return value is 1 or above?
				if (g_iFwResult >= ZE_STOP)
				{
					// Re-pause plugin.
					pause("ac", szFileName)
					continue // Skip this gamemode.
				}
				
				// Execute forward ze_gamemode_chosen(game_id).
				g_iGameCurrent = iGame
				g_bIsGameStarted = true // Has game started.
				ExecuteForward(g_iForwards[FORWARD_GAMEMODE_CHOSEN], _/* No return value */, iGame)
				return // Gamemode has started.
			}

			// Next time.
			iTime++
		}
	}

	// Start default gamemode.
	chooseDefault()
}

public chooseDefault()
{
	// Check default game is exists or not?
	if (g_iDefaultGame == ZE_WRONG_GAME)
	{
		// Print message on server console.
		server_print("[ZE] Default gamemode not found !")
	}
	else // Start default gamemode.
	{
		new szFileName[64]

		// Get filename of gamemode from dyn array.
		ArrayGetString(g_aGameFile, g_iDefaultGame, szFileName, charsmax(szFileName))

		// Unpause plugin first
		unpause("c", szFileName)

		// Execute forward ze_gamemode_chosen_pre(game_id, bSkipCheck) and get return value.
		ExecuteForward(g_iForwards[FORWARD_GAMEMODE_CHOSEN_PRE], g_iFwResult, g_iDefaultGame, true)

		// Check return value is 1 or above?
		if (g_iFwResult >= ZE_STOP)
		{
			// Re-pause plugin.
			pause("ac", szFileName)
			server_print("[ZE] Error in starting default gamemode!")
			return // Skip this gamemode.
		}
		
		// Execute forward ze_gamemode_chosen(game_id).
		ExecuteForward(g_iForwards[FORWARD_GAMEMODE_CHOSEN], _/* Ignore return value */, g_iDefaultGame)
	
		// Gamemode has started.
		g_bIsGameStarted = true
		g_iGameCurrent = g_iDefaultGame
	}
}

public pausePlugins()
{
	// Pause!
	new szFileName[64], iNum
	for (iNum = 0; iNum < g_iGameCount; iNum++)
	{	
		// Get files name from dyn array.
		ArrayGetString(g_aGameFile, iNum, szFileName, charsmax(szFileName))
	
		// Pause plugin.
		pause("ac", szFileName)
	}
}

// Forward called when round over.
public ze_roundend(iWinTeam)
{
	// Round over.
	g_bIsGameStarted = false
	g_iGameCurrent = ZE_WRONG_GAME

	// Remove task.
	remove_task(TASK_COUNTDOWN)
}

/**
 * Functions of Natives:
 */
public native_gamemode_register(plugin_id, params_num) 
{
	// Get name of gamemode.
	new szName[MAX_NAME_LENGTH]
	get_string(1, szName, charsmax(szName))

	// Gamemode is without Name?
	if (strlen(szName) < 1)
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Gamemode without name !")
		return ZE_WRONG_GAME
	}

	// Gamemode name is already exists?
	new szTemp[MAX_NAME_LENGTH], iNum
	for (iNum = 0; iNum < g_iGameCount; iNum++)
	{
		// Get name of gamemode from dynamic array.
		ArrayGetString(g_aGameName, iNum, szTemp, charsmax(szTemp))

		// Name is exists?
		if (equali(szTemp, szName))
		{
			// Print error on server console.
			log_error(AMX_ERR_NATIVE, "[ZE] Gamemode name is already exists !")
			return ZE_WRONG_GAME
		}
	}

	new szFileName[64]

	// Get file name of gamemode.
	get_plugin(plugin_id, szFileName, charsmax(szFileName))

	// Store a gamemode name and filename in dynamic array.
	ArrayPushString(g_aGameName, szName)
	ArrayPushString(g_aGameFile, szFileName)

	// Return index of gamemode.
	return ++g_iGameCount - 1
}

public native_gamemode_set_default(plugin_id, params_num)
{
	// Get index of gamemode.
	new iGame = get_param(1)

	// Gamemode is invalid?
	if ((iGame >= g_iGameCount) || (iGame < 0))
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid game mode (%d)", iGame)
		return false
	}

	// Set default gamemode.
	g_iDefaultGame = iGame	
	return true
}

public native_gamemode_get_current()
{
	// Return gamemode id.
	return g_iGameCurrent
}

public native_gamemode_get_name(plugin_id, params_num)
{
	// Get a game mode ID.
	new iGame = get_param(1)

	// Gamemode is invalid?
	if ((iGame >= g_iGameCount) || (iGame < 0))
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid game mode (%d)", iGame)
		return false
	}

	new szName[MAX_NAME_LENGTH]

	// Get a game mode name from dynamic array.
	ArrayGetString(g_aGameName, iGame, szName, charsmax(szName))

	// Store game mode in new buffer.
	set_string(2, szName, get_param(3))
	return true
}

public native_gamemode_get_id(plugin_id, params_num)
{
	// Get a game mode name.
	new szName[MAX_NAME_LENGTH]
	get_string(1, szName, charsmax(szName))

	// No name entered?
	if (strlen(szName) < 1)
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] You can't get game mode id without name !")
		return ZE_WRONG_GAME
	}

	// Find for name.
	new szTemp[MAX_NAME_LENGTH]
	for (new iNum = 0; iNum < g_iGameCount; iNum++)
	{
		// Get game mode name from dynamic array.
		ArrayGetString(g_aGameName, iNum, szTemp, charsmax(szTemp))

		// Game mode is exists?
		if (equali(szTemp, szName))
			return iNum // Return game mode id.
	}

	// Game mode name not found.
	return ZE_WRONG_GAME
}

public native_gamemode_get_count()
{
	// Return number of game modes.
	return g_iGameCount
}

public native_gamemode_start(plugin_id, paras_num)
{
	// Get a game mode id.
	new iGame = get_param(1)

	// Gamemode is invalid?
	if ((iGame >= g_iGameCount) || (iGame < 0))
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid game mode (%d)", iGame)
		return false
	}

	// Remove countdown task.
	remove_task(TASK_COUNTDOWN)

	new szFileName[64]

	// Get filename of gamemode from dyn array.
	ArrayGetString(g_aGameFile, iGame, szFileName, charsmax(szFileName))

	// Unpause plugin first
	unpause("c", szFileName)

	// Execute forward ze_gamemode_chosen_pre(game_id, bSkipCheck) and get return value.
	ExecuteForward(g_iForwards[FORWARD_GAMEMODE_CHOSEN_PRE], g_iFwResult, iGame, true)

	// Check return value is 1 or above?
	if (g_iFwResult >= ZE_STOP)
	{
		// Re-pause plugin.
		pause("ac", szFileName)
		return false // fail start game mode.
	}
	
	// Execute forward ze_gamemode_chosen(game_id).
	ExecuteForward(g_iForwards[FORWARD_GAMEMODE_CHOSEN], _/* Ignore return value */, iGame)

	// Gamemode has started.
	g_bIsGameStarted = true
	g_iGameCurrent = iGame
	return true
}

public native_is_gamemode_started()
{
	// Return 1 or 0
	return g_bIsGameStarted
}