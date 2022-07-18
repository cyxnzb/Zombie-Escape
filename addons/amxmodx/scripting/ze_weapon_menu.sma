#include <zombie_escape>
#include <ze_levels>

// Keys Menu.
const KEYS_MENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

// Old Menu keys.
const OLDMENU_AUTOSELECT = 7
const OLDMENU_BACKNEXT = 8
const OLDMENU_EXIT = 9

// Enums (Weapon Attributes).
enum _:WPN_ATTRIBUTES
{
	WPN_SECTION = 0,
	WPN_NAME[MAX_NAME_LENGTH],
	WPN_CLASS[MAX_NAME_LENGTH],
	WPN_AMMO,
	WPN_LEVEL,
	WPN_VIEWMODEL[MAX_MODEL_LENGTH],
	WPN_WEAPMODEL[MAX_MODEL_LENGTH]
}

// Enums (Section).
enum
{
	WPN_PRIMARY = 1,
	WPN_SECONDARY
}

// Enums (Menu Data).
enum _:MENU_DATA
{
	MENU_AUTOSELECT = 0,
	MENU_PAGE_PRI,
	MENU_PAGE_SEC,
	MENU_PRE_PRI,
	MENU_PRE_SEC
}

// Enums (Grenades).
enum _:Grenades
{
	FlashBang,
	HeGrenade,
	SmGrenade
}

// Default Weapons.
new const g_szDefWeapons[][WPN_ATTRIBUTES] = 
{
	{ 1, "Galil", "weapon_galil", 90, 0 },
	{ 1, "Famas", "weapon_famas", 90, 0 },
	{ 1, "AK47", "weapon_ak47", 90, 0 },
	{ 1, "M4A1", "weapon_m4a1", 90, 0 },
	{ 1, "SG552", "weapon_sg552", 90, 0 },
	{ 1, "Aug", "weapon_aug", 90, 0 },
	{ 1, "M3", "weapon_m3", 35, 0 },
	{ 1, "XM1014", "weapon_xm1014", 35, 0 },
	{ 1, "TMP", "weapon_tmp", 90, 0 },
	{ 1, "Mac10", "weapon_mac10", 100, 0 },
	{ 1, "MP5 Navy", "weapon_mp5navy", 100, 0 },
	{ 1, "UMP45", "weapon_ump45", 100, 0 },
	{ 1, "P90", "weapon_p90", 100, 0 },
	{ 1, "SG550", "weapon_sg550", 90, 0 },
	{ 1, "G1SG3", "weapon_g1sg3", 90, 0 },
	{ 1, "M249", "weapon_m249", 200, 0 },

	{ 2, "Glock18", "weapon_glock18", 200, 0 },
	{ 2, "USP", "weapon_usp", 200, 0 },
	{ 2, "P228", "weapon_p228", 200, 0 },
	{ 2, "Deagle", "weapon_deagle", 200, 0 },
	{ 2, "Five-Seven", "weapon_fiveseven", 200, 0 },
	{ 2, "Dual Elite", "weapon_elite", 200, 0 }
}

// Global Variables.
new g_iBuyTime
new g_iPrimaryCount
new g_iSecondaryCount
new g_iGrenadeNum[Grenades]
new g_iBoughtWeapons[MAX_PLAYERS+1]
new g_iMenuData[MAX_PLAYERS+1][MENU_DATA]
new bool:g_bWeaponMenu
new bool:g_bWeaponLevel
new Float:g_flPlrBuyTime[MAX_PLAYERS+1]

// Dynamic Array's.
new Array:g_aPrimaryWeapons
new Array:g_aSecondaryWeapons

// Forward allows register new natives.
public plugin_natives()
{
	// Set natives filter.
	set_native_filter("fw_NativeFilter_Pre")

	// Create new natives.
	register_native("ze_show_weapon_menu", "native_show_weapon_menu", 1)
	register_native("ze_is_auto_buy_enabled", "native_is_auto_buy_enabled", 1)
	register_native("ze_disable_auto_buy", "native_disable_auto_buy", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Weapons Menu", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Weapons Menu + Features")

	// Create new CVars and bind CVars (Store the new value automatically in Global Variables).
	bind_pcvar_num(create_cvar("ze_weapons_menu", "1"), g_bWeaponMenu)
	bind_pcvar_num(create_cvar("ze_weapons_level", "0"), g_bWeaponLevel)
	bind_pcvar_num(create_cvar("ze_buy_time", "60"), g_iBuyTime)
	bind_pcvar_num(create_cvar("ze_give_FB_nade", "1"), g_iGrenadeNum[FlashBang])
	bind_pcvar_num(create_cvar("ze_give_HE_nade", "1"), g_iGrenadeNum[HeGrenade])
	bind_pcvar_num(create_cvar("ze_give_SM_nade", "1"), g_iGrenadeNum[SmGrenade])

	// Clcmds.
	register_clcmd("say /guns", "clcmd_WeaponsMenu")
	register_clcmd("say_team /guns", "clcmd_WeaponsMenu")
	register_clcmd("say /enable", "clcmd_EnableMenu")
	register_clcmd("say_team /enable", "clcmd_EnableMenu")

	// Create new HUDs Menu in game.
	register_menu("Primary_Weapons", KEYS_MENU, "handler_PrimaryWeapons_Menu")
	register_menu("Secondary_Weapons", KEYS_MENU, "handler_SecondaryWeapons_Menu")
}

// Forward called after init.
public plugin_precache()
{
	// Create new dynamic array's in Memory.
	g_aPrimaryWeapons = ArrayCreate(WPN_ATTRIBUTES)
	g_aSecondaryWeapons = ArrayCreate(WPN_ATTRIBUTES)

	new szCfgDir[32], szFilePath[64]

	// Get configs directory.
	get_configsdir(szCfgDir, charsmax(szCfgDir))

	// Get file path.
	formatex(szFilePath, charsmax(szFilePath), "%s/%s", szCfgDir, ZE_SETTING_RESOURCES)

	// Read all weapons from file.
	read_Weapons(szFilePath)
}

public fw_NativeFilter_Pre(const szName[], id, bTrap)
{
	// Native not found?
	if (!bTrap)
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

// Hook called when player sent command "/guns" in chat.
public clcmd_WeaponsMenu(id)
{
	// Weapons Menu disabled?
	if (!g_bWeaponMenu)
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "BUY_MENU_DISABLED")
		return PLUGIN_HANDLED // Prevent execute a command.
	}

	// Player not alive?
	if (!is_user_alive(id))
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "DEAD_CANT_BUY_WEAPON")
		return PLUGIN_HANDLED // Prevent execute a command.		
	}

	// Player is Zombie?
	if (ze_is_user_zombie_ex(id))
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "NO_BUY_ZOMBIE")
		return PLUGIN_HANDLED // Prevent execute a command.			
	}

	// Buy time has expired?
	if ((g_flPlrBuyTime[id] - get_gametime()) <= 0.0)
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "BUY_MENU_TIME_EXPIRED")
		return PLUGIN_HANDLED // Prevent execute a command.	
	}

	// Show available weapons menu.
	show_Available_Menu(id)
	return PLUGIN_CONTINUE
}

// Hook called when player sent command "/enable" in chat.
public clcmd_EnableMenu(id)
{
	// Weapons Menu disabled?
	if (!g_bWeaponMenu)
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "BUY_MENU_DISABLED")
		return PLUGIN_HANDLED // Prevent execute a command.
	}

	if (!g_iMenuData[id][MENU_AUTOSELECT])
		return PLUGIN_HANDLED

	// Disable auto select.
	g_iMenuData[id][MENU_AUTOSELECT] = false

	// Print colores message on chat for player.
	ze_colored_print(id, "%L", LANG_PLAYER, "BUY_ENABLED")
	return PLUGIN_CONTINUE	
}

// Forward called after player humanized.
public ze_user_humanized(id)
{
	// Get reference time.
	g_flPlrBuyTime[id] = get_gametime() + g_iBuyTime

	// Reset Var.
	g_iBoughtWeapons[id] = 0

	// Auto select enabled?
	if (g_iMenuData[id][MENU_AUTOSELECT])
	{
		buy_Primary_Weapon(id, g_iMenuData[id][MENU_PRE_PRI]) // Give player primary weapon.
		buy_Secondary_Weapon(id, g_iMenuData[id][MENU_PRE_SEC]) // Give player secondary weapon.
	}
	else // Auto Select disabled.
	{
		// Show available weapons menu for player.
		show_Available_Menu(id)		
	}

	// Give player grenades.
	giveGrenades(id)
}

public show_Available_Menu(id)
{
	// Player has choose primary weapon?
	if (!(g_iBoughtWeapons[id] & BIT(WPN_PRIMARY)))
		show_PrimaryWeapons_Menu(id)
	else if (!(g_iBoughtWeapons[id] & BIT(WPN_SECONDARY)))
		show_SecondaryWeapons_Menu(id)
	else // Print colored message in chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "ALREADY_BOUGHT")
}

public show_PrimaryWeapons_Menu(id)
{
	// Local Variables.
	new pWpnAttrib[WPN_ATTRIBUTES], szMenu[250], iItemNum, iWpnNum, iLevel, iLen = 0

	// Get number of items on page.
	new iPageItem = g_iMenuData[id][MENU_PAGE_PRI]
	new iMaxItems = min(iPageItem + 7, g_iPrimaryCount)

	// Weapons with Levels?
	if (g_bWeaponLevel)
	{
		// Get current level of player.
		iLevel = ze_get_user_level(id)
	}

	// Menu title.
	iLen = formatex(szMenu, charsmax(szMenu), "\r%L \y[%d/%d]^n^n", LANG_PLAYER, "MENU_PRIMARY_TITLE", iPageItem, g_iPrimaryCount)

	// Weapon List (1-7)
	for (iWpnNum = iPageItem; iWpnNum < iMaxItems; iWpnNum++)
	{
		// Get weapon attributes from dynamic array.
		ArrayGetArray(g_aPrimaryWeapons, iWpnNum, pWpnAttrib)
	
		// Weapon with Levels enabled?
		if (g_bWeaponLevel)
		{
			// Add weapon name to Menu with Level.
			if (pWpnAttrib[WPN_LEVEL] > iLevel)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\d%s \y%d^n", ++iItemNum, pWpnAttrib[WPN_NAME], pWpnAttrib[WPN_LEVEL])
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w%s^n", ++iItemNum, pWpnAttrib[WPN_NAME]) 
		}
		else
		{
			// Add weapon name to Menu.
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w%s^n", ++iItemNum, pWpnAttrib[WPN_NAME])			
		}
	}

	// Add property Auto Select.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8.\w%L \y[%L]^n", LANG_PLAYER, "MENU_AUTOSELECT", LANG_PLAYER, g_iMenuData[id][MENU_AUTOSELECT] ? "SAVE_YES" : "SAVE_NO")

	// Add property Next and Back.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9.\w%L/%L^n", LANG_PLAYER, "NEXT", LANG_PLAYER, "BACK")

	// Add propert Exit.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0.\w%L^n", LANG_PLAYER, "EXIT")

	// Show the Menu for player.
	show_menu(id, KEYS_MENU, szMenu, -1, "Primary_Weapons")
}

// Hook called when choose any items from Primary Weapons Menu.
public handler_PrimaryWeapons_Menu(id, iKey)
{
	// Player not found or not alive or is Zombie?
	if (!is_user_alive(id) || ze_is_user_zombie_ex(id))
		return PLUGIN_HANDLED // destroy menu.
	
	// Buy time has expired?
	if ((g_flPlrBuyTime[id] - get_gametime()) <= 0.0)
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "BUY_MENU_TIME_EXPIRED")
		return PLUGIN_HANDLED
	}

	// Choose item:
	switch (iKey)
	{
		case OLDMENU_AUTOSELECT: // Remember.
		{
			// (0 = 1 - 1) || (1 = 1 - 0) (1 = true | 0 = false)
			g_iMenuData[id][MENU_AUTOSELECT] = 1 - g_iMenuData[id][MENU_AUTOSELECT]
		}
		case OLDMENU_BACKNEXT: // Next/Back.
		{
			// Next page?
			if ((g_iMenuData[id][MENU_PAGE_PRI] + 7) < g_iPrimaryCount)
				g_iMenuData[id][MENU_PAGE_PRI] += 7
			else
				g_iMenuData[id][MENU_PAGE_PRI] = 0
		}
		case OLDMENU_EXIT: // Exit.
		{
			return PLUGIN_HANDLED
		}
		default:
		{
			// Get item index.
			new iSelection = g_iMenuData[id][MENU_PAGE_PRI] + iKey

			if (iSelection < g_iPrimaryCount)
			{
				// Buy item!
				if (buy_Primary_Weapon(id, iSelection))
				{
					// Show next menu secondary weapons.
					show_SecondaryWeapons_Menu(id)
					return PLUGIN_HANDLED
				}				
			}			
		}
	}

	show_PrimaryWeapons_Menu(id)
	return PLUGIN_HANDLED
}

public show_SecondaryWeapons_Menu(id)
{
	// Local Variables.
	new pWpnAttrib[WPN_ATTRIBUTES], szMenu[250], iItemNum, iWpnNum, iLevel, iLen = 0

	// Get number of items on page.
	new iPageItem = g_iMenuData[id][MENU_PAGE_SEC]
	new iMaxItems = min(iPageItem + 7, g_iSecondaryCount)

	// Weapons with Levels?
	if (g_bWeaponLevel)
	{
		// Get current level of player.
		iLevel = ze_get_user_level(id)
	}

	// Menu title.
	iLen = formatex(szMenu, charsmax(szMenu), "\r%L \y[%d/%d]^n^n", LANG_PLAYER, "MENU_SECONDARY_TITLE", iPageItem, g_iPrimaryCount)

	// Weapon List (1-7)
	for (iWpnNum = iPageItem; iWpnNum < iMaxItems; iWpnNum++)
	{
		// Get weapon attributes from dynamic array.
		ArrayGetArray(g_aSecondaryWeapons, iWpnNum, pWpnAttrib)
	
		// Weapon with Levels enabled?
		if (g_bWeaponLevel)
		{
			// Add weapon name to Menu with Level.
			if (pWpnAttrib[WPN_LEVEL] > iLevel)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\d%s \y%d^n", ++iItemNum, pWpnAttrib[WPN_NAME], pWpnAttrib[WPN_LEVEL])
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w%s^n", ++iItemNum, pWpnAttrib[WPN_NAME]) 
		}
		else
		{
			// Add weapon name to Menu.
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w%s^n", ++iItemNum, pWpnAttrib[WPN_NAME])			
		}
	}

	// Add property Auto Select.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8.\w%L \y[%L]^n", LANG_PLAYER, "MENU_AUTOSELECT", LANG_PLAYER, g_iMenuData[id][MENU_AUTOSELECT] ? "SAVE_YES" : "SAVE_NO")

	// Add property Next and Back.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9.\w%L/%L^n", LANG_PLAYER, "NEXT", LANG_PLAYER, "BACK")

	// Add propert Exit.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0.\w%L^n", LANG_PLAYER, "EXIT")

	// Show the Menu for player.
	show_menu(id, KEYS_MENU, szMenu, -1, "Secondary_Weapons")
}

// Hook called when choose any items from Primary Weapons Menu.
public handler_SecondaryWeapons_Menu(id, iKey)
{
	// Player not found or not alive or is Zombie?
	if (!is_user_alive(id) || ze_is_user_zombie_ex(id))
		return PLUGIN_HANDLED // destroy menu.
	
	// Buy time has expired?
	if ((g_flPlrBuyTime[id] - get_gametime()) <= 0.0)
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "BUY_MENU_TIME_EXPIRED")
		return PLUGIN_HANDLED
	}

	// Choose item:
	switch (iKey)
	{
		case OLDMENU_AUTOSELECT: // Remember.
		{
			// (0 = 1 - 1) || (1 = 1 - 0) (1 = true | 0 = false)
			g_iMenuData[id][MENU_AUTOSELECT] = 1 - g_iMenuData[id][MENU_AUTOSELECT]
		}
		case OLDMENU_BACKNEXT: // Next/Back.
		{
			// Next page?
			if ((g_iMenuData[id][MENU_PAGE_SEC] + 7) > g_iSecondaryCount)
				g_iMenuData[id][MENU_PAGE_SEC] = 0
			else
				g_iMenuData[id][MENU_PAGE_SEC] += 7
		}
		case OLDMENU_EXIT: // Exit.
		{
			return PLUGIN_HANDLED
		}
		default:
		{
			// Get item index.
			new iSelection = g_iMenuData[id][MENU_PAGE_SEC] + iKey

			if (iSelection < g_iSecondaryCount)
			{
				// Buy item!
				if (!(iSelection >= g_iSecondaryCount))
				{
					if (buy_Secondary_Weapon(id, iSelection))
						return PLUGIN_HANDLED
				}			
			}
		}
	}

	show_SecondaryWeapons_Menu(id)
	return PLUGIN_HANDLED
}

public buy_Primary_Weapon(id, iItemNum)
{	
	// Local Variable.
	new pWpnAttrib[WPN_ATTRIBUTES]

	// Get weapon attributes from dynamic array.
	ArrayGetArray(g_aPrimaryWeapons, iItemNum, pWpnAttrib)

	// Weapon with Levels is enabled?
	if (g_bWeaponLevel)
	{
		// Player doesn't have level enough?
		if (pWpnAttrib[WPN_LEVEL] > ze_get_user_level(id))
		{
			// Print message on server console.
			ze_colored_print(id, "%L", LANG_PLAYER, "LEVEL_NOT_ENOUGH")		
			return 0 // Return false.
		}
	}

	// Give player item.
	if (rg_give_item(id, pWpnAttrib[WPN_CLASS], GT_REPLACE) == NULLENT)
	{
		// Print message on server console.
		log_message("[ZE] Invalid Weapon Classname (%s)", pWpnAttrib[WPN_CLASS])
		return 0 // Return false.
	}

	// Get weapon's id.
	new iWeapon = get_weaponid(pWpnAttrib[WPN_CLASS])

	// Set player view Model.
	if (pWpnAttrib[WPN_VIEWMODEL])
		ze_set_user_view_model(id, iWeapon, pWpnAttrib[WPN_VIEWMODEL])

	// Set player weapon Model.
	if (pWpnAttrib[WPN_WEAPMODEL])
		ze_set_user_weap_model(id, iWeapon, pWpnAttrib[WPN_WEAPMODEL])

	// Primary weapon has chosen.
	g_iBoughtWeapons[id] |= BIT(WPN_PRIMARY)

	// Remember weapon index in dynamic array.
	g_iMenuData[id][MENU_PRE_PRI] = iItemNum

	// Set player weapon BpAmmo.
	rg_set_user_bpammo(id, WeaponIdType:iWeapon, pWpnAttrib[WPN_AMMO])
	return 1 // Return true
}

public buy_Secondary_Weapon(id, iItemNum)
{
	// Local Variable.
	new pWpnAttrib[WPN_ATTRIBUTES]

	// Get weapon attributes from dynamic array.
	ArrayGetArray(g_aSecondaryWeapons, iItemNum, pWpnAttrib)

	// Weapon with Levels is enabled?
	if (g_bWeaponLevel)
	{
		// Player doesn't have level enough?
		if (pWpnAttrib[WPN_LEVEL] > ze_get_user_level(id))
		{
			// Print message on server console.
			ze_colored_print(id, "%L", LANG_PLAYER, "LEVEL_NOT_ENOUGH")		
			return 0 // Return false.
		}
	}

	// Give player item.
	if (rg_give_item(id, pWpnAttrib[WPN_CLASS], GT_REPLACE) == NULLENT)
	{
		// Print message on server console.
		log_message("[ZE] Invalid Weapon Classname (%s)", pWpnAttrib[WPN_CLASS])
		return 0 // Return false.
	}

	// Get weapon's id.
	new iWeapon = get_weaponid(pWpnAttrib[WPN_CLASS])

	// Set player view Model.
	if (pWpnAttrib[WPN_VIEWMODEL] != EOS)
		ze_set_user_view_model(id, iWeapon, pWpnAttrib[WPN_VIEWMODEL])

	// Set player weapon Model.
	if (pWpnAttrib[WPN_WEAPMODEL] != EOS)
		ze_set_user_weap_model(id, iWeapon, pWpnAttrib[WPN_WEAPMODEL])

	// Secondary weapon has chosen.
	g_iBoughtWeapons[id] |= BIT(WPN_SECONDARY)

	// Remember weapon index in dynamic array.
	g_iMenuData[id][MENU_PRE_SEC] = iItemNum

	// Auto select enabled?
	if (g_iMenuData[id][MENU_AUTOSELECT])
	{
		// Print colored message on chat for player.
		ze_colored_print(id, "%L", LANG_PLAYER, "RE_ENABLE_MENU")
	}

	// Set player weapon BpAmmo.
	rg_set_user_bpammo(id, WeaponIdType:iWeapon, pWpnAttrib[WPN_AMMO])
	return 1 // Return true
}

/**
 * Functions of natives:
 */
read_Weapons(const szFilePath[])
{
	// Local Variables.
	new szRead[1024], szSection[64], iFound

	// Open the file.
	new iFileHandle = fopen(szFilePath, "r+")

	// Error in opening file.
	if (!iFileHandle)
		return 0 // Return false.

	// Read every Line in the file.
	while (!feof(iFileHandle))
	{
		// Read text from the Line.
		if (fgets(iFileHandle, szRead, charsmax(szRead)) == 0)
			continue
		
		// Remove blanks from text.
		trim(szRead)

		// Comment line or empty line?
		if (szRead[0] == ';' || szRead[0] == '#' || !strlen(szRead))
			continue
		
		// Line is section?
		if (szRead[0] == '[')
		{
			// Parse text.
			parse(szRead, szSection, charsmax(szSection))		

			// Copy section in new buffer.
			copyc(szSection, charsmax(szSection), szRead[1], ']')			

			// Check Section?
			if (equali(szSection, "Weapons Menu"))
			{
				// Section is exist!
				iFound = 1
				break // Stop finding on Section.
			}
		}
	}

	// Section not found?
	if (!iFound)
	{
		// Create section in file.
		fputs(iFileHandle, "[Weapons Menu]^n")
		
		// Save all default weapons in file in Section.
		for (new iWpn = 0; iWpn < sizeof g_szDefWeapons; iWpn++)
		{
			// Save default weapon in File.
			fprintf(iFileHandle, "^"%c^" ^"%s^" ^"%s^" ^"%d^"^n", (g_szDefWeapons[iWpn][WPN_SECTION] == WPN_PRIMARY) ? 'p' : 's', g_szDefWeapons[iWpn][WPN_NAME], g_szDefWeapons[iWpn][WPN_CLASS], g_szDefWeapons[iWpn][WPN_AMMO])
		}

		// ...
		g_iPrimaryCount = 16
		g_iSecondaryCount = 6

		// Close file.
		fclose(iFileHandle)
		return 0 // Return false.
	}

	// Local Variables.
	new pWpnAttrib[WPN_ATTRIBUTES], szName[64], szClass[64], szAmmo[32], szLevel[32], szViewModel[64], szWeapModel[64]

	// Read all data exist in section.
	while (!feof(iFileHandle))
	{
		// Read text from the Line.
		if (fgets(iFileHandle, szRead, charsmax(szRead)) == 0)
			continue
		
		// Remove blanks from text.
		trim(szRead)

		// It's new section?
		if (szRead[0] == '[')
			break

		// Comment line or empty line?
		if (szRead[0] == ';' || szRead[0] == '#' || !strlen(szRead))
			continue

		// Parse text.
		parse(szRead, szSection, charsmax(szSection), szName, charsmax(szName), szClass, charsmax(szClass), szAmmo, charsmax(szAmmo), szLevel, charsmax(szLevel), szViewModel, charsmax(szViewModel), szWeapModel, charsmax(szWeapModel))

		// Remove double quotes.
		remove_quotes(szSection)
		remove_quotes(szName)
		remove_quotes(szClass)
		remove_quotes(szAmmo)
		remove_quotes(szLevel)
		remove_quotes(szViewModel)
		remove_quotes(szWeapModel)

		// Choose section:
		switch (szSection[0])
		{
			case 'P', 'p', '1', 1: // Primary
			{
				// New primary weapon.
				g_iPrimaryCount++

				// Store the weapon attributes in Array.
				pWpnAttrib[WPN_SECTION] = WPN_PRIMARY
				copy(pWpnAttrib[WPN_NAME], charsmax(pWpnAttrib[WPN_NAME]), szName)
				copy(pWpnAttrib[WPN_CLASS], charsmax(pWpnAttrib[WPN_CLASS]), szClass)
				pWpnAttrib[WPN_AMMO] = str_to_num(szAmmo)
				pWpnAttrib[WPN_LEVEL] = str_to_num(szLevel)
				copy(pWpnAttrib[WPN_VIEWMODEL], charsmax(pWpnAttrib[WPN_VIEWMODEL]), szViewModel)
				copy(pWpnAttrib[WPN_WEAPMODEL], charsmax(pWpnAttrib[WPN_WEAPMODEL]), szWeapModel)		

				// Precache Models.
				if (pWpnAttrib[WPN_VIEWMODEL] != EOS)
					precache_model(pWpnAttrib[WPN_VIEWMODEL])
				if (pWpnAttrib[WPN_WEAPMODEL] != EOS)
					precache_model(pWpnAttrib[WPN_WEAPMODEL])

				// Store weapon attributes in dynamic array.
				ArrayPushArray(g_aPrimaryWeapons, pWpnAttrib)
			}
			case 'S', 's', '2', 2:
			{
				// New secondary weapon.
				g_iSecondaryCount++

				// Store the weapon attributes in Array.
				pWpnAttrib[WPN_SECTION] = WPN_SECONDARY
				copy(pWpnAttrib[WPN_NAME], charsmax(pWpnAttrib[WPN_NAME]), szName)
				copy(pWpnAttrib[WPN_CLASS], charsmax(pWpnAttrib[WPN_CLASS]), szClass)
				pWpnAttrib[WPN_AMMO] = str_to_num(szAmmo)
				pWpnAttrib[WPN_LEVEL] = str_to_num(szLevel)
				copy(pWpnAttrib[WPN_VIEWMODEL], charsmax(pWpnAttrib[WPN_VIEWMODEL]), szViewModel)
				copy(pWpnAttrib[WPN_WEAPMODEL], charsmax(pWpnAttrib[WPN_WEAPMODEL]), szWeapModel)						
			
				// Precache Models.
				if (pWpnAttrib[WPN_VIEWMODEL] != EOS)
					precache_model(pWpnAttrib[WPN_VIEWMODEL])
				if (pWpnAttrib[WPN_WEAPMODEL] != EOS)
					precache_model(pWpnAttrib[WPN_WEAPMODEL])

				// Store weapon attributes in dynamic array.
				ArrayPushArray(g_aSecondaryWeapons, pWpnAttrib)
			}
		}

		// Reset string for avoid store a model path of another weapon in Dynamic Array.
		szViewModel = "^0"
		szWeapModel = "^0"
	}

	// Close the file.
	fclose(iFileHandle)
	return 1
}

giveGrenades(id)
{
	// Give player flashbang.
	if (g_iGrenadeNum[FlashBang] > 0)
	{	
		// Player doesn't have flashbang grenade?
		if (!rg_get_user_bpammo(id, WEAPON_FLASHBANG))
		{
			// Give player flashbang grenade.
			rg_give_item(id, "weapon_flashbang", GT_APPEND)

			// Give player more flashbang.
			rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_iGrenadeNum[FlashBang])
		}
		else
		{
			// Give player more flashbang.
			rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_iGrenadeNum[FlashBang])
		}
	}

	// Give player hegrenade.
	if (g_iGrenadeNum[HeGrenade] > 0)
	{	
		// Player doesn't have hegrenade grenade?
		if (!rg_get_user_bpammo(id, WEAPON_HEGRENADE))
		{
			// Give player hegrenade grenade.
			rg_give_item(id, "weapon_hegrenade", GT_APPEND)

			// Give player more hegrenade.
			rg_set_user_bpammo(id, WEAPON_HEGRENADE, g_iGrenadeNum[HeGrenade])
		}
		else
		{
			// Give player more hegrenade.
			rg_set_user_bpammo(id, WEAPON_HEGRENADE, g_iGrenadeNum[HeGrenade])
		}
	}

	// Give player smokegrenade.
	if (g_iGrenadeNum[SmGrenade] > 0)
	{
		// Player doesn't have smokegrenade grenade?
		if (!rg_get_user_bpammo(id, WEAPON_SMOKEGRENADE))
		{
			// Give player smokegrenade grenade.
			rg_give_item(id, "weapon_smokegrenade", GT_APPEND)

			// Give player more smokegrenade.
			rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_iGrenadeNum[SmGrenade])
		}
		else
		{
			// Give player more smokegrenade.
			rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_iGrenadeNum[SmGrenade])
		}
	}
}

/**
 * Function of natives:
 */
public native_show_weapon_menu(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Show menu for player.
	clcmd_WeaponsMenu(id)
	return true
}

public native_is_auto_buy_enabled(id)
{
	// Player not found?
	if (!is_user_connected(id))
		return NULLENT
	
	// Return 1 or 0.
	return g_iMenuData[id][MENU_AUTOSELECT]
}

public native_disable_auto_buy(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Enable weapons menu.
	clcmd_EnableMenu(id)
	return true
}