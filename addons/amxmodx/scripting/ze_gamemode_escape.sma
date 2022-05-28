#include <zombie_escape>

native ze_gamemode_register(const szName[]);
native ze_gamemode_set_default(game_id);

// Constants.
const MAX_SOUND_LENGTH = 64
const TASK_COUNTDOWN = 3000

// Notice HUD position
const Float:HUD_X = -1.00
const Float:HUD_Y = 0.25

// Settings file.
new const ZE_SETTING_RESOURCES[] = "zombie_escape.ini"

// Enums (Custom Forwards).
enum _:FORWARDS
{
	FORWARD_ZOMBIE_APPEAR = 0,
	FORWARD_ZOMBIE_APPEAR_EX,
	FORWARD_ZOMBIE_RELEASE
}

// Enums (Colors Array).
enum
{
	Red = 0,
	Green,
	Blue
}

// Default gamemode sound.
new const g_szStartSound[][] = { "ambience/the_horror2.wav", "ambience/the_horror3.wav" }

// Cvars Variables.
new g_pCvar_iMode
new g_pCvar_iChance
new g_pCvar_iNoticeMsg
new g_pCvar_iNoticeColors[3]
new g_pCvar_iNoticeSound
new g_pCvar_iSmartRandom
new g_pCvar_iReleasTime
new g_pCvar_iFirstZombieHealth

// Global Variables.
new g_iGame
new g_iRoundMode
new g_iSyncMsgHud
new g_iCountdown
new g_iForwards[FORWARDS]
new bool:g_bBlockInfection
new bool:g_bRespawnAsZombie
new bool:g_bIsZombieFrozen[MAX_PLAYERS+1]

// Dynamic Arrays
new Array:g_aStartSound

// Trie (Hash Map).
new Trie:g_tChosenPlayers

// Hook Chain Variable.
new HookChain:g_pHookTraceAttack

// Forward allows registering natives (called before init).
public plugin_natives()
{
	register_native("ze_is_zombie_frozen", "native_is_zombie_frozen", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Gamemode: Escape", ZE_VERSION, AUTHORS)

	// Hook Chains.
	g_pHookTraceAttack = RegisterHookChain(RG_CBasePlayer_TraceAttack, "fw_TraceAttack_Pre", 0)
	DisableHookChain(g_pHookTraceAttack) // Disable hook "TraceAttack" to allow bullet damage.

	// Cvars.
	g_pCvar_iMode 					= register_cvar("ze_escape_mode", "0")
	g_pCvar_iChance 				= register_cvar("ze_escape_chance", "20")
	g_pCvar_iNoticeMsg 				= register_cvar("ze_escape_notice", "2")
	g_pCvar_iNoticeColors[Red] 		= register_cvar("ze_escape_notice_red", "50")
	g_pCvar_iNoticeColors[Green] 	= register_cvar("ze_escape_notice_green", "100")
	g_pCvar_iNoticeColors[Blue] 	= register_cvar("ze_escape_notice_blue", "255")
	g_pCvar_iNoticeSound 			= register_cvar("ze_escape_sounds", "1")
	g_pCvar_iSmartRandom 			= register_cvar("ze_smart_random", "1")
	g_pCvar_iReleasTime 			= register_cvar("ze_release_time", "15")
	g_pCvar_iFirstZombieHealth 		= register_cvar("ze_first_zombies_health", "20000")

	// New gamemode.
	g_iGame = ze_gamemode_register("Escape")

	// Set "Escape Mode" default gamemode.
	ze_gamemode_set_default(g_iGame)

	// Initialize Trie.
	g_tChosenPlayers = TrieCreate()

	// Initialize custom forwards.
	g_iForwards[FORWARD_ZOMBIE_APPEAR] 		= CreateMultiForward("ze_zombie_appear", ET_IGNORE)
	g_iForwards[FORWARD_ZOMBIE_APPEAR_EX] 	= CreateMultiForward("ze_zombie_appear_ex", ET_IGNORE, FP_STRING, FP_CELL)
	g_iForwards[FORWARD_ZOMBIE_RELEASE] 	= CreateMultiForward("ze_zombie_release", ET_IGNORE)

	// Default Values.
	g_iSyncMsgHud = CreateHudSyncObj()
}

// Forward called when server desactivation or plugin fail.
public plugin_end()
{
	// Destroy dyn array.
	ArrayDestroy(g_aStartSound)

	// Destroy Trie.
	TrieDestroy(g_tChosenPlayers)
}

// Forward allows precaching game files (called before init).
public plugin_precache()
{
	// Initialize dynamic array.
	g_aStartSound = ArrayCreate(MAX_SOUND_LENGTH)

	// Load start sound from ini file.
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "Escape Mode", g_aStartSound)

	new iArrSize, iNum

	// Get number of sounds in dyn array.
	iArrSize = ArraySize(g_aStartSound)

	// Dyn array is empty?
	if (!iArrSize)
	{
		// Store default sounds in dyn array.
		for (iNum = 0; iNum < sizeof(g_szStartSound); iNum++)
			ArrayPushString(g_aStartSound, g_szStartSound[iNum])
		
		// Save default sounds in ini file.
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "Escape Mode", g_aStartSound)
	}

	new szSound[MAX_SOUND_LENGTH]

	// Precache Sounds.
	for (iNum = 0; iNum < iArrSize; iNum++)
	{
		// Get start sound from dyn array.
		ArrayGetString(g_aStartSound, iNum, szSound, charsmax(szSound))

		// Precache Generic File (.mp3).
		if (equali(szSound[strlen(szSound) - 4], ".mp3"))
		{
			// Add path (sound/..)
			format(szSound, charsmax(szSound), "sound/%s", szSound)
			precache_sound(szSound)
		}
		else // Precache Sound (.wav)
		{
			precache_sound(szSound)
		}
	}
}

// Forward called every New Round (Is important to declare it in pre-forward).
public ze_game_started_pre()
{
	// Stop all sounds.
	StopSound()

	// Remove task.
	remove_task(TASK_COUNTDOWN)

	// Disable hook "TraceAttack" to allow bullet damage.
	DisableHookChain(g_pHookTraceAttack)

	// Reset array.
	arrayset(g_bIsZombieFrozen, false, sizeof(g_bIsZombieFrozen))
}

// Forward called every New Round (after gamestarted).
public ze_game_started()
{
	// Get mode.
	g_iRoundMode = get_pcvar_num(g_pCvar_iMode)
}

// Forward called when player spawn.
public ze_player_spawn_post(id)
{
	if (g_bRespawnAsZombie)
	{
		// Allow spawning player Zombie.
		ze_allow_respawn_as_zombie(id)
	}
}

// Hook called when player Trace attack.
public fw_TraceAttack_Pre(iVictim, iAttacker, Float:flDamage, Float:vDirection[3], pTraceHandle, iDamageType)
{
	// Invalid player?
	if (!is_user_connected(iVictim) || !is_user_connected(iAttacker))
		return HC_CONTINUE
	
	// Block Damage.
	return HC_SUPERCEDE
}

// Forward called before infection player.
public ze_user_infected_pre(iVictim, iInfector, iDamage)
{
	// Infector is a Server?
	if (!iInfector)
		return ZE_CONTINUE // Continue infection event.

	// Block infection. 
	if (g_bBlockInfection)
		return ZE_STOP // Block infection event.

	return ZE_CONTINUE // Continue infection event.
}

// Forward called before gamemode chosen.
public ze_gamemode_chosen_pre(game_id, bSkipCheck)
{	
	// This not round of this gamemode?
	if (!bSkipCheck) if (random_num(1, get_pcvar_num(g_pCvar_iChance)) != 1) return ZE_STOP

	// Continue starting gamemode.
	return ZE_CONTINUE
}

// Forward called when gamemode chosen.
public ze_gamemode_chosen(game_id)
{
	// Notice mode.
	switch (get_pcvar_num(g_pCvar_iNoticeMsg))
	{
		case 1: // Normal Text (center).
			client_print(0, print_center, "%L", LANG_PLAYER, "NOTICE_ESCAPE")
		case 2: // HUD.
		{
			// Show HUD for all clients.
			set_hudmessage(get_pcvar_num(g_pCvar_iNoticeColors[Red]), get_pcvar_num(g_pCvar_iNoticeColors[Green]), get_pcvar_num(g_pCvar_iNoticeColors[Blue]), HUD_X, HUD_Y, 1, 5.0, 5.0, 0.1, 0.1)
			ShowSyncHudMsg(0, g_iSyncMsgHud, "%L", LANG_PLAYER, "NOTICE_ESCAPE")
		}
		case 3: // Director HUD
		{
			set_dhudmessage(get_pcvar_num(g_pCvar_iNoticeColors[Red]), get_pcvar_num(g_pCvar_iNoticeColors[Green]), get_pcvar_num(g_pCvar_iNoticeColors[Blue]), HUD_X, HUD_Y, 1, 5.0, 5.0, 0.1, 0.1)
			show_dhudmessage(0, "%L", LANG_PLAYER, "NOTICE_ESCAPE")
		}
	}

	// Get mode type.
	g_iRoundMode = get_pcvar_num(g_pCvar_iMode)

	// Check notice sound is enabled or not?
	if (get_pcvar_num(g_pCvar_iNoticeSound))
	{
		new szSound[MAX_SOUND_LENGTH]

		// Get random sound from dyn array.
		ArrayGetString(g_aStartSound, random_num(0, ArraySize(g_aStartSound) - 1), szSound, charsmax(szSound))

		// Play random sound for all clients.
		PlaySound(0, szSound)
	}

	// Check smart random choose is enabled or not.
	new bool:bSmartRandom = get_pcvar_num(g_pCvar_iSmartRandom) ? true : false

	new iFirstZombies[MAX_PLAYERS], iPlayers[MAX_PLAYERS], szAuthId[34], iAliveCount, iReqZombies, iZombieNum, id

	// Get all alive players and save players index in array.
	get_players(iPlayers, iAliveCount, "ah")

	// Get infection ratio.
	iReqZombies = RequiredZombies()

	// Get health of first Zombies.
	new Float:flFirstHealth = get_pcvar_float(g_pCvar_iFirstZombieHealth)

	// Repeat finding on required Zombies.
	while (iZombieNum < iReqZombies)
	{
		// Get random player.
		id = iPlayers[random_num(0, iAliveCount)]

		// Player is already Zombie?
		if (ze_is_user_zombie(id))
			continue

		// Get authid of player.
		get_user_authid(id, szAuthId, charsmax(szAuthId))
		
		// Player is already infected previous round.
		if (bSmartRandom) if (TrieKeyExists(g_tChosenPlayers, szAuthId)) continue

		if (!g_iRoundMode)
		{
			// Freeze Zombie.
			g_bIsZombieFrozen[id] = true
			set_entvar(id, var_flags, (get_entvar(id, var_flags) | FL_FROZEN))
		}

		// Respawn player Zombie.
		ze_allow_respawn_as_zombie(id)

		// Switch player to Zombies team (Infect him).
		ze_set_user_zombie(id)

		// Set first Zombies specific health.
		if (flFirstHealth > 0)
		{
			set_entvar(id, var_health, flFirstHealth)
		}

		// New Zombie.
		iFirstZombies[iZombieNum++] = id
	}

	// Check smart random choose is enabled or not?
	if (bSmartRandom)
	{
		// Clear Trie first.
		TrieClear(g_tChosenPlayers)

		// Add authid of all Zombies in Trie.
		for (id = 1; id <= MaxClients; id++)
		{
			// Players not a alive?
			if (!is_user_alive(id))
				continue
			
			// Player is not Zombie?
			if (!ze_is_user_zombie(id))
				continue
			
			// Get authid of player.
			get_user_authid(id, szAuthId, charsmax(szAuthId))
		
			// Store a authid of player in Trie.
			TrieSetCell(g_tChosenPlayers, szAuthId, 0)
		}
	}

	if (iZombieNum > 0)
	{
		// Execute forward ze_zombie_appear().
		ExecuteForward(g_iForwards[FORWARD_ZOMBIE_APPEAR])
	}

	// Execute forward ze_zombie_appear_ex(const iZombies[], iZombieNum)
	ExecuteForward(g_iForwards[FORWARD_ZOMBIE_APPEAR_EX], _/* No return value */, iFirstZombies, iZombieNum)

	// This is working only in old gamemode!
	if (!g_iRoundMode)
	{
		// Enable hook "TraceAttack" to block bullet damage.
		EnableHookChain(g_pHookTraceAttack)
	}

	g_bRespawnAsZombie = true // Respawn any player Zombie.
	g_bBlockInfection = true // Block Infection event.

	// Get release time first.
	g_iCountdown = get_pcvar_num(g_pCvar_iReleasTime)

	// Release time task.
	set_task(1.0, "delayReleaseZombie", TASK_COUNTDOWN, "", 0, "b")
}

public delayReleaseZombie(iTask)
{
	// Countdown is over?
	if (g_iCountdown <= 0)
	{
		// Release Zombies.
		releaseZombies()

		// Stop countdown (Remove Task).
		remove_task(iTask)
		return
	}

	// Show release time HUD.
	client_print(0, print_center, "%L", LANG_PLAYER, "ZOMBIE_RELEASE", g_iCountdown--)
}

public releaseZombies()
{
	/*
	 * Old Mod, Freeze zombies and release them after seconds !
	 */
	if (!g_iRoundMode)
	{
		// Enable infection.
		g_bBlockInfection = false

		for (new id = 1; id <= MaxClients; id++)
		{
			// Player is not a Alive?
			if (!is_user_alive(id))
				continue
			
			// Player is a Zombie?
			if (ze_is_user_zombie(id))
			{
				// Unfreeze all Zombies.
				g_bIsZombieFrozen[id] = false
				set_entvar(id, var_flags, (get_entvar(id, var_flags) & ~FL_FROZEN))
			}
		}

		// Disable hook "TraceAttack" to allow bullet damage.
		DisableHookChain(g_pHookTraceAttack)
	}
	else /* New Mod, Zombies are will appear in way between Humans */
	{
		// Enable infection.
		g_bBlockInfection = false
	}

	// Execute forward ze_zombie_release().
	ExecuteForward(g_iForwards[FORWARD_ZOMBIE_RELEASE])
}

// Forward called when round ended.
public ze_roundend(iWinTeam)
{
	g_bRespawnAsZombie = false

	// All clients.
	for (new id = 1; id <= MaxClients; id++)
	{
		// Player is a alive?
		if (is_user_alive(id))
		{
			// Disallow spawning player Zombie.
			ze_disallow_respawn_as_zombie(id)
		}
	}
}

/**
 * Function of native:
 */
public native_is_zombie_frozen(id)
{
	// Player not found or not Zombie?
	if (!is_user_connected(id) || !ze_is_user_zombie(id))
	{
		return NULLENT // Return -1
	}

	return g_bIsZombieFrozen[id] // Return 1 or 0.
}