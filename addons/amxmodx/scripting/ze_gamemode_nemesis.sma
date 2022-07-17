#include <zombie_escape>

// Notice HUD position
const Float:HUD_X = -1.00
const Float:HUD_Y = 0.25

// Enums (Colors).
enum _:Colors
{
	Red,
	Green,
	Blue
}

// Default nemesis start sound.
new const g_szStartSound[][] = { "x/x_pain1.wav", "x/x_pain3.wav" }

// Global Variables.
new g_iChance
new g_iReqAlivePlayers
new g_iNoticeMsg
new g_iNoticeColors[Colors]
new bool:g_bNoticeSound

// Dynamic Array.
new Array:g_aStartSound

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Gamemode: Nemesis", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Nemesis Mode")

	// CVars.
	bind_pcvar_num(create_cvar("ze_nemesis_chance", "5"), g_iChance)
	bind_pcvar_num(create_cvar("ze_nemesis_reqplayers", "2"), g_iReqAlivePlayers)
	bind_pcvar_num(create_cvar("ze_nemesis_notice", "1"), g_iNoticeMsg)
	bind_pcvar_num(create_cvar("ze_nemesis_notice_red", "255"), g_iNoticeColors[Red])
	bind_pcvar_num(create_cvar("ze_nemesis_notice_green", "0"), g_iNoticeColors[Green])
	bind_pcvar_num(create_cvar("ze_nemesis_notice_blue", "0"), g_iNoticeColors[Blue])
	bind_pcvar_num(create_cvar("ze_nemesis_sounds", "1"), g_bNoticeSound)

	// Register new game mode.
	ze_gamemode_register("Nemesis Mode")
}

// Forward called when server desactivation plugin unloaded.
public plugin_end()
{
	// Remove dynamic array from Memory.
	ArrayDestroy(g_aStartSound)
}

// Forward allows precaching game files (called before init).
public plugin_precache()
{
	// Create new dynamic array in Memory.
	g_aStartSound = ArrayCreate(MAX_SOUND_LENGTH)

	// Load start sound from dynamic array.
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "Nemesis Mode", g_aStartSound)

	new iNum

	// No sound in dynamic array?
	if (!ArraySize(g_aStartSound))
	{
		// Store default start sound in dynamic array.
		for (iNum = 0;iNum < sizeof g_szStartSound; iNum++)
			ArrayPushString(g_aStartSound, g_szStartSound[iNum])

		// Store default start sound in externel file.
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "Nemesis Mode", g_aStartSound)
	}
}

// Forward called before game mode start.
public ze_gamemode_chosen_pre(game_id, bSkipCheck)
{
	// Skip check when game mode started from native?
	if (!bSkipCheck)
	{
		// This is not round of Nemesis Mode?
		if (random_num(1, g_iChance) != 1)
			return ZE_STOP // Skip game mode.
		
		// Required players?
		if (ze_get_humans_number() < g_iReqAlivePlayers)
			return ZE_STOP // Skip game mode.
	}

	// Start game mode.
	return ZE_CONTINUE
}

// Forward called when game mode started.
public ze_gamemode_chosen(game_id)
{
	// The game hasn't started yet?
	if (!ze_is_game_started())
		return

	// Notice mode.
	switch (g_iNoticeMsg)
	{
		case 1: // Normal Text (center).
			client_print(0, print_center, "%L", LANG_PLAYER, "NOTICE_NEMESIS")
		case 2: // HUD.
		{
			// Show HUD for all clients.
			set_hudmessage(g_iNoticeColors[Red], g_iNoticeColors[Green], g_iNoticeColors[Blue], HUD_X, HUD_Y, 1, 5.0, 5.0, 0.1, 0.1)
			show_hudmessage(0, "%L", LANG_PLAYER, "NOTICE_NEMESIS")
		}
		case 3: // Director HUD
		{
			set_dhudmessage(g_iNoticeColors[Red], g_iNoticeColors[Green], g_iNoticeColors[Blue], HUD_X, HUD_Y, 1, 5.0, 5.0, 0.1, 0.1)
			show_dhudmessage(0, "%L", LANG_PLAYER, "NOTICE_NEMESIS")
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
	new iPlayers[MAX_PLAYERS], iAliveCount, iReqNemesis, iNemesisNum, id

	// Get all alive players and save players index in array.
	get_players(iPlayers, iAliveCount, "ah")

	// Get number of required Zombies.
	iReqNemesis = RequiredZombies()

	// Repeat finding on required Nemesis.
	while (iNemesisNum < iReqNemesis)
	{
		// Get random player index.
		id = iPlayers[random_num(0, iAliveCount - 1)]

		// Player is already Nemesis?
		if (ze_is_user_nemesis(id))
			continue

		// Switch player to Zombies team (Infect him).
		ze_set_user_nemesis(id)

		// New Nemesis
		iNemesisNum++
	}
}