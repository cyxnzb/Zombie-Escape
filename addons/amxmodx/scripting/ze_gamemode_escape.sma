#include <zombie_escape>

// Constants.
const TASK_COUNTDOWN = 3000

// Notice HUD position
const Float:HUD_X = -1.00
const Float:HUD_Y = 0.25

// Enums (Custom Forwards).
enum _:FORWARDS
{
	FORWARD_ZOMBIE_APPEAR = 0,
	FORWARD_ZOMBIE_APPEAR_EX,
	FORWARD_ZOMBIE_RELEASE
}

// Enums (Colors Array).
enum _:Colors
{
	Red = 0,
	Green,
	Blue
}

// Default gamemode sound.
new const g_szStartSound[][] = { "ambience/the_horror2.wav", "ambience/the_horror3.wav" }

// Global Variables.
new g_iGame
new g_iMode
new g_iChance
new g_iNoticeMsg
new g_iReleaseHud
new g_iReleasTime
new g_iSyncMsgHud
new g_iCountdown
new g_iFirstZombieHealth
new g_iForwards[FORWARDS]
new g_iNoticeColors[Colors]
new g_iReleasColors[Colors]
new bool:g_bNoticeSound
new bool:g_bSmartRandom
new bool:g_bReleaseTime
new bool:g_bIsRoundEscape
new bool:g_bBlockInfection
new bool:g_bRespawnAsZombie
new bool:g_bIsFirstZombie[MAX_PLAYERS+1]
new bool:g_bIsZombieFrozen[MAX_PLAYERS+1]
new Float:g_flRoundEndDelay

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
	register_native("ze_remove_zombie_freeze_msg", "native_remove_zombie_freeze_msg", 1)
	register_native("ze_is_user_first_zombie", "native_is_user_first_zombie", 1)
	register_native("ze_is_round_escape", "native_is_round_escape", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Gamemode: Escape", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Game mode: Escape Mode.")

	// Hook Chains.
	g_pHookTraceAttack = RegisterHookChain(RG_CBasePlayer_TraceAttack, "fw_TraceAttack_Pre", 0)
	DisableHookChain(g_pHookTraceAttack) // Disable hook "TraceAttack" to allow bullet damage.

	// Cvars.
	bind_pcvar_num(create_cvar("ze_escape_type", "0"), g_iMode)
	bind_pcvar_num(create_cvar("ze_escape_chance", "20"), g_iChance)
	bind_pcvar_num(create_cvar("ze_escape_notice", "2"), g_iNoticeMsg)
	bind_pcvar_num(create_cvar("ze_escape_notice_red", "255"), g_iNoticeColors[Red])
	bind_pcvar_num(create_cvar("ze_escape_notice_green", "100"), g_iNoticeColors[Green])
	bind_pcvar_num(create_cvar("ze_escape_notice_blue", "50"), g_iNoticeColors[Blue])
	bind_pcvar_num(create_cvar("ze_releasetime_mode", "1"), g_iReleaseHud)
	bind_pcvar_num(create_cvar("ze_releasetime_red", "255"), g_iReleasColors[Red])
	bind_pcvar_num(create_cvar("ze_releasetime_green", "255"), g_iReleasColors[Green])
	bind_pcvar_num(create_cvar("ze_releasetime_blue", "0"), g_iReleasColors[Blue])
	bind_pcvar_num(create_cvar("ze_escape_sounds", "1"), g_bNoticeSound)
	bind_pcvar_num(create_cvar("ze_smart_random", "1"), g_bSmartRandom)
	bind_pcvar_num(create_cvar("ze_release_time", "15"), g_iReleasTime)
	bind_pcvar_num(create_cvar("ze_first_zombies_health", "20000"), g_iFirstZombieHealth)
	bind_pcvar_num(create_cvar("ze_respawn_as_zombie", "1"), g_bRespawnAsZombie)
	bind_pcvar_float(get_cvar_pointer("ze_round_end_delay"), g_flRoundEndDelay)

	// New gamemode.
	g_iGame = ze_gamemode_register("Escape Mode")

	// Set "Escape Mode" default gamemode.
	ze_gamemode_set_default(g_iGame)

	// Initialize Trie.
	g_tChosenPlayers = TrieCreate()

	// Initialize custom forwards.
	g_iForwards[FORWARD_ZOMBIE_APPEAR] 		= CreateMultiForward("ze_zombie_appear", ET_IGNORE)
	g_iForwards[FORWARD_ZOMBIE_APPEAR_EX] 	= CreateMultiForward("ze_zombie_appear_ex", ET_IGNORE, FP_ARRAY, FP_CELL)
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

	new iNum

	// Dyn array is empty?
	if (!ArraySize(g_aStartSound))
	{
		// Store default sounds in dyn array.
		for (iNum = 0; iNum < sizeof(g_szStartSound); iNum++)
			ArrayPushString(g_aStartSound, g_szStartSound[iNum])
		
		// Save default sounds in ini file.
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "Escape Mode", g_aStartSound)
	}
}

// Forward called when player join the server.
public client_putinserver(id)
{
	// Don't respawn player Zombie?
	if (!g_bRespawnAsZombie && !get_member_game(m_iNumTerrorist))
	{
		// Restart round (Don't reset score or round number).
		rg_round_end(g_flRoundEndDelay, WINSTATUS_NONE, ROUND_END_DRAW, "", "")

		// Print text in center.
		client_print(0, print_center, "%L", LANG_PLAYER, "ESCAPE_DRAW")
	}
}

// Forward called before freeze player using FrostNade.
public ze_frost_pre(id)
{
	// Zombie in frozen time?
	if (g_bReleaseTime)
		return ZE_STOP // Prevent freeze Zombie.
	return ZE_CONTINUE // Continue freeze Zombie.
}

// Forward called before burn player using FireNade.
public ze_fire_pre(id)
{
	// Zombie in frozen time?
	if (g_bReleaseTime)
		return ZE_STOP // Prevent burn Zombie.
	return ZE_CONTINUE // Continue burn Zombie.
}

// Forward called every New Round (Is important to declare it in pre-forward).
public ze_game_started_pre()
{
	// Reset boolean.
	g_bIsRoundEscape = false

	// Stop all sounds.
	StopSound()

	// Remove task.
	remove_task(TASK_COUNTDOWN)

	// Disable hook "TraceAttack" to allow bullet damage.
	DisableHookChain(g_pHookTraceAttack)

	// Reset array.
	arrayset(g_bIsZombieFrozen, false, sizeof(g_bIsZombieFrozen))
}

// Forward called after player humanized.
public ze_user_humanized(id)
{
	// Reset boolean
	g_bIsFirstZombie[id] = false
}

// Forward called when player spawn.
public ze_player_spawn_post(id)
{
	// There are no humans?
	if (get_member_game(m_iNumCT) <= 1)
		return

	// Respawn player Zombie?
	if (g_bRespawnAsZombie)
	{
		// Allow spawning player Zombie.
		ze_allow_respawn_as_zombie(id)
	}
}

// Forward called when player disconnected from server.
public client_disconnected(id)
{
	new szAuthId[34]

	// Get AuthId of player.
	get_user_authid(id, szAuthId, charsmax(szAuthId))

	// Remove AuthId of player from Trie.
	TrieDeleteKey(g_tChosenPlayers, szAuthId)

	// Reset boolean.
	g_bIsZombieFrozen[id] = false
}

// Hook called when player Trace attack.
public fw_TraceAttack_Pre(iVictim, iAttacker, Float:flDamage, Float:vDirection[3], pTraceHandle, iDamageType)
{	
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
	if (!bSkipCheck) if (random_num(1, g_iChance) != 1) return ZE_STOP

	// Continue starting gamemode.
	return ZE_CONTINUE
}

// Forward called when gamemode chosen.
public ze_gamemode_chosen(game_id)
{
	// The game hasn't started yet?
	if (!ze_is_game_started())
		return

	// Escape mode has started.
	g_bIsRoundEscape = true

	// Notice mode.
	switch (g_iNoticeMsg)
	{
		case 1: // Normal Text (center).
			client_print(0, print_center, "%L", LANG_PLAYER, "NOTICE_ESCAPE")
		case 2: // HUD.
		{
			// Show HUD for all clients.
			set_hudmessage(g_iNoticeColors[Red], g_iNoticeColors[Green], g_iNoticeColors[Blue], HUD_X, HUD_Y, 1, 5.0, 5.0, 0.1, 0.1)
			show_hudmessage(0, "%L", LANG_PLAYER, "NOTICE_ESCAPE")
		}
		case 3: // Director HUD
		{
			set_dhudmessage(g_iNoticeColors[Red], g_iNoticeColors[Green], g_iNoticeColors[Blue], HUD_X, HUD_Y, 1, 5.0, 5.0, 0.1, 0.1)
			show_dhudmessage(0, "%L", LANG_PLAYER, "NOTICE_ESCAPE")
		}
	}

	// Check notice sound is enabled or not?
	if (g_bNoticeSound)
	{
		new szSound[MAX_SOUND_LENGTH]

		// Get random sound from dyn array.
		ArrayGetString(g_aStartSound, random_num(0, ArraySize(g_aStartSound) - 1), szSound, charsmax(szSound))

		// Play random sound for all clients.
		PlaySound(0, szSound)
	}

	// Local Variables.
	new iFirstZombies[MAX_PLAYERS], iPlayers[MAX_PLAYERS], szAuthId[34], iAliveCount, iReqZombies, iZombieNum, id

	// Get all alive players and save players index in array.
	get_players(iPlayers, iAliveCount, "ah")

	// Get number of required Zombies.
	iReqZombies = RequiredZombies()

	// Repeat finding on required Zombies.
	while (iZombieNum < iReqZombies)
	{
		// Get random player index.
		id = iPlayers[random_num(0, iAliveCount - 1)]

		// Player is already Zombie?
		if (ze_is_user_zombie_ex(id))
			continue

		// Get authid of player.
		get_user_authid(id, szAuthId, charsmax(szAuthId))
		
		// Player is already infected previous round.
		if (g_bSmartRandom) if (TrieKeyExists(g_tChosenPlayers, szAuthId)) continue

		// Old game mode?
		if (!g_iMode)
		{
			// Freeze Zombie.
			g_bIsZombieFrozen[id] = true

			// Freeze player (No moving)
			set_entvar(id, var_flags, (get_entvar(id, var_flags) | FL_FROZEN))
		}

		// Respawn player Zombie?
		if (g_bRespawnAsZombie)
		{
			// Respawn player Zombie.
			ze_allow_respawn_as_zombie(id)
		}

		// Switch player to Zombies team (Infect him).
		ze_set_user_zombie(id)

		// Set first Zombies specific health.
		if (g_iFirstZombieHealth > 0)
		{
			// Set first Zombie custom health.
			set_entvar(id, var_health, float(g_iFirstZombieHealth))
		}

		// First Zombie
		g_bIsFirstZombie[id] = true

		// New Zombie.
		iFirstZombies[iZombieNum++] = id
	}

	// Check smart random choose is enabled or not?
	if (g_bSmartRandom)
	{
		// Clear Trie first.
		TrieClear(g_tChosenPlayers)

		// Add authid of all Zombies in Trie.
		for (new iNum = 0; iNum < iZombieNum; iNum++)
		{
			// Get player index.
			id = iFirstZombies[iNum]
			
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
	ExecuteForward(g_iForwards[FORWARD_ZOMBIE_APPEAR_EX], _/* No return value */, PrepareArray(iFirstZombies, iZombieNum), iZombieNum)

	// This is working only in old gamemode!
	if (!g_iMode)
	{
		// Zombie has chosen?
		g_bReleaseTime = true

		// Enable hook "TraceAttack" to block bullet damage.
		EnableHookChain(g_pHookTraceAttack)
	}

	g_bBlockInfection = true // Block Infection event.

	// Get release time first.
	g_iCountdown = g_iReleasTime

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
	switch (g_iReleaseHud)
	{
		case 0: // Text.
			client_print(0, print_center, "%L", LANG_PLAYER, "ZOMBIE_RELEASE", g_iCountdown--)
		case 1: // HUD
		{
			set_hudmessage(g_iReleasColors[Red], g_iReleasColors[Green], g_iReleasColors[Blue], -1.0, 0.35, 0, 1.0, 1.0, 0.0, 0.0)
			ShowSyncHudMsg(0, g_iSyncMsgHud, "%L", LANG_PLAYER, "ZOMBIE_RELEASE", g_iCountdown--)
		}
		case 2: // DHUD
		{
			set_dhudmessage(g_iReleasColors[Red], g_iReleasColors[Green], g_iReleasColors[Blue], -1.0, 0.35, 0, 1.0, 1.0, 0.0, 0.0)
			show_dhudmessage(0, "%L", LANG_PLAYER, "ZOMBIE_RELEASE", g_iCountdown--)			
		}
	}
}

public releaseZombies()
{
	/*
	 * Old Mod, Freeze zombies and release them after seconds !
	 */
	if (!g_iMode)
	{
		// Enable infection.
		g_bBlockInfection = false

		// Local Variables.
		new iPlayers[MAX_PLAYERS], iAliveCount, iNum, id

		// Get index of all alive players.
		get_players(iPlayers, iAliveCount, "ah")

		// Release all Zombies.
		for (iNum = 0; iNum <= iAliveCount; iNum++)
		{			
			// Get player index.
			id = iPlayers[iNum]

			// Player is a Zombie?
			if (ze_is_user_zombie_ex(id))
			{
				// Unfreeze all Zombies.
				g_bIsZombieFrozen[id] = false
				set_entvar(id, var_flags, (get_entvar(id, var_flags) & ~FL_FROZEN))
			}
		}

		// Show release time HUD.
		switch (g_iReleaseHud)
		{
			case 0: // Text.
				client_print(0, print_center, "%L", LANG_PLAYER, "ZOMBIE_RELEASED")
			case 1: // HUD
			{
				set_hudmessage(g_iReleasColors[Red], g_iReleasColors[Green], g_iReleasColors[Blue], -1.0, 0.35, 1, 3.0, 3.0, 0.0, 0.0)
				ShowSyncHudMsg(0, g_iSyncMsgHud, "%L", LANG_PLAYER, "ZOMBIE_RELEASED")
			}
			case 2: // DHUD
			{
				set_dhudmessage(g_iReleasColors[Red], g_iReleasColors[Green], g_iReleasColors[Blue], -1.0, 0.35, 1, 3.0, 3.0, 0.0, 0.0)
				show_dhudmessage(0, "%L", LANG_PLAYER, "ZOMBIE_RELEASED")			
			}
		}

		// Release Zombie.
		g_bReleaseTime = false

		// Disable hook "TraceAttack" to allow bullet damage.
		DisableHookChain(g_pHookTraceAttack)
	}
	else /* New Mod, Zombies are will appear in way between Humans without freeze time */
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
	// All clients.
	for (new id = 1; id <= MaxClients; id++)
	{
		// Player is a alive?
		if (is_user_connected(id))
		{
			// Disallow spawning player Zombie.
			ze_disallow_respawn_as_zombie(id)
		}
	}

	// Reset boolean.
	g_bIsRoundEscape = false
}

/**
 * Function of native:
 */
public native_is_user_first_zombie(id)
{
	// Player not found or not Zombie?
	if (!is_user_connected(id) || !ze_is_user_zombie_ex(id))
		return false

	return g_bIsFirstZombie[id] // Return true or false.
}

public native_is_zombie_frozen(id)
{
	// Player not found or not Zombie?
	if (!is_user_connected(id) || !ze_is_user_zombie_ex(id))
	{
		return NULLENT // Return -1
	}

	return g_bIsZombieFrozen[id] // Return 1 or 0.
}

public native_remove_zombie_freeze_msg()
{
	// Check task is exists or not?
	if (task_exists(TASK_COUNTDOWN))
	{
		remove_task(TASK_COUNTDOWN)
		return true
	}
	
	return false	
}

public bool:native_is_round_escape()
{
	return g_bIsRoundEscape
}