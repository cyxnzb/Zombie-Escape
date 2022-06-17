#include <amxmodx>
#include <amxmisc>
#include <reapi>

// Constants.
const msg_Damage = 71
const msg_DeathMsg = 83
const msg_ScoreAttrib = 84
const msg_ScoreInfo = 85
const msg_AmmoPickup = 91
const msg_ScreenFade = 98

// Chat Prefix.
#define ZE_PREFIX "[!gZombie Escape!y] "

/**
 * Print colored message on chat for specific player or all players.
 *
 * @param id		Client index, 0 = everyone.
 * @param message 	Formatting rules.
 * @param ...		Variable number of formatting parameters.
 *
 * @noreturn
 *
 */
stock ze_colored_print(const id, const message[], any:...)
{
	static szMsg[512];
	vformat(szMsg, charsmax(szMsg), message, 3)
	format(szMsg, charsmax(szMsg), "%s %s", ZE_PREFIX, szMsg);
	replace_string(szMsg, charsmax(szMsg), "!y", "^1"); // Green color.
	replace_string(szMsg, charsmax(szMsg), "!t", "^3"); // Team color.
	replace_string(szMsg, charsmax(szMsg), "!g", "^4"); // Normal color.

	// Print message for all clients.
	if (id == 0)
	{
		// Print colored message for all clients.
		client_print_color(0, print_team_default, szMsg)
	}
	else
	{
		// Player not found?
		if (!is_user_connected(id))
		{
			// Print error on server console.
			log_error(AMX_ERR_NOTFOUND, "[ZE] Invalid Player id (%d)", id)
			return
		}

		// Print colored message for all clients.
		client_print_color(id, print_team_default, szMsg)		
	}
}

/**
 * Returns the number of alive players in specific team.
 *
 * @param iTeam 	Team CS_TEAM_T or CS_TEAM_CT.
 *
 */
stock GetAlivePlayersNum(CsTeams:iTeam)
{
	static iTAliveNum

	// Get the number of all alive players in specific team.
	switch (iTeam)
	{
		case CS_TEAM_T:
			iTAliveNum = get_playersnum_ex((GetPlayers_ExcludeDead|GetPlayers_MatchTeam), "TERRORIST")
		case CS_TEAM_CT:
			iTAliveNum = get_playersnum_ex((GetPlayers_ExcludeDead|GetPlayers_MatchTeam), "CT")
	}
	return iTAliveNum
}

/**
 * Returns the number of required Zombies.
 */
stock RequiredZombies()
{
	switch(GetAllAlivePlayersNum())
	{
		case 2..5: return 1
		case 6..15: return 2
		case 16..25: return 3
		case 26..32: return 4
	}
	return 0
}

/**
 * Set player map light style.
 *
 * @param id 				Client index.
 * @param szMapLightStyle	Map light style characters (a..z) a = darkest | z = brightest
 *
 * @noreturn
 *
 */
stock Set_MapLightStyle(id, const szMapLightStyle[])
{
	message_begin(MSG_ONE, SVC_LIGHTSTYLE, .player = id)
	write_byte(0)
	write_string(szMapLightStyle)
	message_end()
}

/**
 * Set a player fade screen.
 *
 * @param id 			Client index.
 * @param iDuration		Duration of fade.
 * @param iHoldTime 	Hold time.
 * @param iFlags 		Fade type.
 * @param iRed 			Red color (0..255)
 * @param iGreen		Green color (0..255)
 * @param iBlue 		Blue color (0..255)
 * @param iAlpha 		Fade brightness (0..255)
 *
 * @noreturn
 *
 */
stock Set_NightVision(id, iDuration = 0, iHoldTime = 0, iFlags = 0x0000, iRed = 0, iGreen = 0, iBlue = 0, iAlpha = 0)
{
	message_begin(MSG_ONE, msg_ScreenFade, .player = id)
	write_short(iDuration)
	write_short(iHoldTime)
	write_short(iFlags)
	write_byte(iRed)
	write_byte(iGreen)
	write_byte(iBlue)
	write_byte(iAlpha)
	message_end()
}

/**
 * Set a Zombie knockback.
 *
 * @param ent 			Client index.
 * @param VicOrigin[3] 	Origin of player.
 * @param speed 		Speed.
 * @param type 			Knockback type.
 *
 * @noreturn
 *
 */
stock Set_Knockback(ent, Float:VicOrigin[3], Float:speed, type)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	get_entvar(ent, var_origin, EntOrigin)
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
	
	switch (type)
	{
		case 1:
		{
			fl_Velocity[0] = ((VicOrigin[0] - EntOrigin[0]) / fl_Time) * 1.5
			fl_Velocity[1] = ((VicOrigin[1] - EntOrigin[1]) / fl_Time) * 1.5
			fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time		
		}
		case 2:
		{
			fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time) * 1.5
			fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time) * 1.5
			fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time
		}
	}
	
	set_entvar(ent, var_velocity, fl_Velocity)
}

/**
 * Update Player Frags and Deaths.
 * 
 * @param iAttacker 	Attacker index, 0 = Skip.
 * @param iVictim 		Victim index, 0 = Skip.
 * @param iFrags 		Frags.
 * @param iDeaths 		Deaths.
 * @param iScoreboard 	Update frags and deaths on scoreboard (1 | 0).
 *
 * @noreturn
 *
 */
stock UpdateFrags(iAttacker, iVictim, iFrags, iDeaths, iScoreboard)
{
	if (is_user_connected(iAttacker))
	{
		// Get frags of attacker.
		new iSetFrags = floatround(get_entvar(iAttacker, var_frags))
	
		// Set attacker frags
		set_entvar(iAttacker, var_frags, float(iSetFrags + iFrags))	
	
		// Update frags in Scoreboard.
		if (iScoreboard)
		{
			message_begin(MSG_BROADCAST, msg_ScoreInfo)
			write_byte(iAttacker) // id
			write_short(iSetFrags + iFrags) // frags
			write_short(get_member(iAttacker, m_iDeaths)) // deaths
			write_short(0) // class?
			write_short(get_member(iAttacker, m_iTeam)) // team
			message_end()
		}	
	}
	
	if (is_user_connected(iVictim))
	{
		// Get number of deaths victim
		new iSetDeaths = get_member(iVictim, m_iDeaths)

		// Set victim deaths
		set_member(iVictim, m_iDeaths, (iSetDeaths + iDeaths))

		// Update scoreboard with attacker and victim info
		if (iScoreboard)
		{
			message_begin(MSG_BROADCAST, msg_ScoreInfo)
			write_byte(iVictim) // id
			write_short(floatround(get_entvar(iVictim, var_frags))) // frags
			write_short((iSetDeaths + iDeaths)) // deaths
			write_short(0) // class?
			write_short(get_member(iVictim, m_iTeam)) // team
			message_end()
		}
	}
}

/**
 * Sent green skull in death message.
 *
 * @param iAttacker 	Attacker index.
 * @param iVictim 		Victim index.
 *
 * @noreturn
 *
 */
stock SendDeathMsg(iAttacker, iVictim, bool:bGreen = false)
{
	message_begin(MSG_ALL, msg_DeathMsg)
	write_byte(iAttacker) // killer
	write_byte(iVictim) // victim
	write_byte(0) // headshot flag
	write_string(bGreen ? "teammate" : "infection") // killer's weapon
	message_end()
}

/**
 * Show infection icon for specific player.
 * 
 * @param id 	Client index.
 *
 * @noreturn
 *
 */
stock InfectionIcon(id)
{
	message_begin(MSG_ONE_UNRELIABLE, msg_Damage, .player = id)
	write_byte(0) // damage save
	write_byte(0) // damage take
	write_long(DMG_NERVEGAS) // damage type - DMG_RADIATION
	write_coord(0) // x
	write_coord(0) // y
	write_coord(0) // z
	message_end()
}

/**
 * Remove dead attrib in scoreboard for specific player.
 *
 * @param id 	Client index.
 *
 * @noreturn
 *
 */
stock FixDeadAttrib(id)
{
	message_begin(MSG_ALL, msg_ScoreAttrib)
	write_byte(id) // id
	write_byte(0) // attrib (0 = Nothing || 1 = Dead)
	message_end()
}

/**
 * Set entity new key value's.
 *
 * @param entity 	Entity index.
 * @param key 		Key name.
 * @param value 	Value to set.
 * @param classname Classname of entity
 *
 * @noreturn
 *
 */
stock Set_KeyValue(entity, const key[], const value[], const classname[])
{
	set_kvd(0, KV_ClassName, classname)
	set_kvd(0, KV_KeyName, key)
	set_kvd(0, KV_Value, value)
	set_kvd(0, KV_fHandled, 0)

	dllfunc(DLLFunc_KeyValue, entity, 0)
}

/**
 * Set custom sky for current map.
 *
 * @param szSkyName 	Sky name.
 *
 * @noreturn
 *
 */
stock Precache_Sky(const szSkyName[])
{
	new szTgaFile[35]
	new const szSuffix[6][3] = {"up", "dn", "ft", "bk", "lf", "rt"}

	for(new id = 0; id < 6; id++)
	{
		formatex(szTgaFile, 34, "gfx/env/%s%s.tga", szSkyName, szSuffix[id])
		
		if(file_exists(szTgaFile))
			precache_generic(szTgaFile)
		else
			server_print("[ZE] Cannot locate file '%s', Skipping...", szTgaFile)
	}
	
	set_cvar_string("sv_skyname", szSkyName)
}

/**
 * Add commas in number and convert that to string. 
 *
 * @param iNum 		Number.
 * @param szOutput 	The buffer to store string in.
 * @param iLen 		Character size of the output buffer.
 *
 * @return 			Number of cells written. 
 *
 */
stock AddCommas(iNum, szOutput[], iLen)  
{  
    static szTmp[15], iOutputPos, iNumPos, iNumLen 
    szTmp="", iOutputPos=0, iNumPos=0, iNumLen=0

    if (iNum < 0)  
    {  
        szOutput[iOutputPos++] = '-' 
        iNum = abs(iNum)
    }  
      
    iNumLen = num_to_str(iNum , szTmp , charsmax(szTmp))

    if (iNumLen <= 3)  
    {  
        iOutputPos += copy(szOutput[iOutputPos], iLen, szTmp)
    }  
    else  
    {  
        while ((iNumPos < iNumLen) && (iOutputPos < iLen))   
        {  
            szOutput[iOutputPos++] = szTmp[iNumPos++]
          
            if((iNumLen - iNumPos) && !((iNumLen - iNumPos) % 3))   
                szOutput[iOutputPos++] = ','
        }

        szOutput[iOutputPos] = EOS 
    }

    return iOutputPos
}

/**
 * Play sound for specific player or everyone.
 *
 * @param id 		Client index.
 * @param sound 	Sound to play (.mp3 or .wav).
 *
 * @noreturn
 *
 */
stock PlaySound(id, const sound[])
{
	if (equal(sound[strlen(sound)-4], ".mp3"))
	{
		client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	}
	else
	{
		client_cmd(id, "spk ^"%s^"", sound)
	}
}

/**
 * Stop sound for all players.
 */
stock StopSound()
{
	client_cmd(0, "mp3 stop")
	client_cmd(0, "stopsound")
}

/**
 * Set rendering of entity.
 *
 * @param ent 		Entity index.
 * @param fx 		Render fx, check kRendeFx in amxconst.inc
 * @param r 		Red color (0..255)
 * @param g 		Green color (0..255)
 * @param b 		Blue color (0..255)
 * @param render 	Render mode, check kRender in amxconst.inc
 * @param amout 	Render amout (0..255)
 *
 * @noreturn
 *
 */
stock Set_Rendering(ent, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16)
{
	static Float:color[3]
	color[0] = float(r)
	color[1] = float(g)
	color[2] = float(b)
	
	set_entvar(ent, var_renderfx, fx)
	set_entvar(ent, var_rendercolor, color)
	set_entvar(ent, var_rendermode, render)
	set_entvar(ent, var_renderamt, float(amount))
}

/**
 * Multiply Vector by Scalar
 */
stock VecMulScalar(const Float:vec[], Float:scalar, Float:out[])
{
	out[0] = vec[0] * scalar
	out[1] = vec[1] * scalar
	out[2] = vec[2] * scalar
}

/**
 * Show given BP Ammo HUD for specific player.
 *
 * @param id 			Client inde.
 * @param iAmmoType 	Ammo types
 *
 * @noreturn
 */
stock Show_Given_BPAmmo(id, iAmmoType, iAmount)
{
	if (iAmount <= 0)
		return
	
	message_begin(MSG_ONE, msg_AmmoPickup, .player = id)
	write_byte(iAmmoType)
	write_byte(iAmount)
	message_end()
}

/**
 * Log MySQL Errors.
 */
stock SQL_IsFail(iFailState, iError, szError[], const szLogFile[])
{
	if (iFailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file(szLogFile, "[MySQL] Could not connect to SQL database: %s", szError)
		return true
	}
	else if (iFailState == TQUERY_QUERY_FAILED)
	{
		log_to_file(szLogFile, "[MySQL] Query failed: %s", szError)
		return true
	}
	else if (iError)
	{
		log_to_file(szLogFile, "[MySQL] Error on query: %s", szError)
		return true
	}
	
	return false
}