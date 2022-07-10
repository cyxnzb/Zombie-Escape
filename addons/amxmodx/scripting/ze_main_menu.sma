#include <zombie_escape>

// Keys
const KEYSMENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

public plugin_init()
{
	register_plugin("[ZE] Main Menu", ZE_VERSION, AUTHORS)
	
	// Commands
	register_clcmd("chooseteam", "clcmd_MenuMain")
	register_clcmd("jointeam", "clcmd_MenuMain")
	register_clcmd("say /ze", "clcmd_MenuMain")
	register_clcmd("say_team /ze", "clcmd_MenuMain")
	register_clcmd("say /zemenu", "clcmd_MenuMain")
	register_clcmd("say_team /zemenu", "clcmd_MenuMain")	

	// Register Menus
	register_menu("Main Menu", KEYSMENU, "Main_Menu")
}

public clcmd_MenuMain(id)
{
	// Player disconnected?
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE;
	
	// Get team of player.
	new TeamName:iTeam = get_member(id, m_iTeam)

	// Player is Specs or unassigned?
	if ((iTeam == TEAM_TERRORIST) || (iTeam == TEAM_CT))
	{
		Show_Menu_Main(id)
		return PLUGIN_HANDLED // Kill the Choose Team Command
	}
	
	// Player in Spec? Allow him to open choose team menu so he can join
	return PLUGIN_CONTINUE
}

// Main Menu
public Show_Menu_Main(id)
{
	static szMenu[300], iLen
    
	// Title
	iLen = formatex(szMenu, charsmax(szMenu), "\w%L^n^n", id, "MAIN_MENU_TITLE")
	
	// 1. Buy Weapons
	if (!ze_is_auto_buy_enabled(id)) // AutoBuy not enabled - normal case
	{
		if (is_user_alive(id))
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w1.\r %L^n", id, "MENU_WEAPONBUY")
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d1. %L^n", id, "MENU_WEAPONBUY")
		}
	}
	else
	{
		// Auto-Buy enabled - Re-enable case
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w1.\r %L^n", id, "MENU_WEAPONBUY_RE_ENABLE")
	}
	
	// 2. Extra Items
	if (is_user_alive(id))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w2.\r %L^n", id, "MENU_EXTRABUY")
	}
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d2. %L^n", id, "MENU_EXTRABUY")
	}
    
	// 0. Exit
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\w0.\r %L", id, "EXIT")

	// Show the Menu for player.
	show_menu(id, KEYSMENU, szMenu, -1, "Main Menu")
}

// Main Menu
public Main_Menu(id, key)
{
	// Player disconnected?
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
    
	switch (key)
	{
		case 0: // Buy Weapons
		{
			if (!ze_is_auto_buy_enabled(id))
			{
				ze_show_weapon_menu(id)
			}
			else
			{
				ze_disable_auto_buy(id)
				Show_Menu_Main(id)
			}
		}
		case 1: // Extra Items
		{
			if (is_user_alive(id))
			{
				ze_show_items_menu(id)
			}
			else
			{
				ze_colored_print(id, "%L", id, "DEAD_CANT_BUY_WEAPON")
			}
		}
	}
	return PLUGIN_HANDLED
}