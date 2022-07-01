#include <zombie_escape>

// Global Variables.
new g_iCustomViewModelsCount
new g_iCustomWeaponModelsCount
new g_iCustomViewModelsPosition[MAX_PLAYERS+1][MAX_WEAPONS]
new g_iCustomWeaponModelsPosition[MAX_PLAYERS+1][MAX_WEAPONS]

// Dynamic Array's.
new Array:g_aCustomViewModelsPath
new Array:g_aCustomWeaponModelsPath

// Forward allows register new natives.
public plugin_natives() {
	register_library("cs_weap_models_api")

	register_native("cs_set_player_view_model", "native_set_user_view_model")
	register_native("cs_reset_player_view_model", "native_reset_user_view_model")

	register_native("cs_set_player_weap_model", "native_set_user_weap_model")
	register_native("cs_reset_player_weap_model", "native_reset_user_weap_model")

	register_native("ze_set_user_view_model", "native_set_user_view_model")
	register_native("ze_reset_user_view_model", "native_reset_user_view_model")

	register_native("ze_set_user_weapn_model", "native_set_user_weap_model")
	register_native("ze_reset_user_weapn_model", "native_reset_user_weap_model")
}

// Forward called after server activation.
public plugin_init() {
	// Load plugin.
	register_plugin("[ZE] Weapon Models APIs", ZE_VERSION, AUTHORS, ZE_HOMEURL)
	
	// Hook Chain.
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_DefaultDeploy_Post", 1)

	// Create new dynamic array's.
	g_aCustomViewModelsPath = ArrayCreate(MAX_MODEL_LENGTH, 1)
	g_aCustomWeaponModelsPath = ArrayCreate(MAX_MODEL_LENGTH, 1)
	
	// Initialize array positions
	new id, iWpnID
	for (id = 1; id <= MaxClients; id++) {
		for (iWpnID = CSW_P228; iWpnID <= CSW_LAST_WEAPON; iWpnID++) {
			g_iCustomViewModelsPosition[id][iWpnID] = NULLENT
			g_iCustomWeaponModelsPosition[id][iWpnID] = NULLENT
		}
	}
}

// Forward called after player disconnected from server.
public client_disconnected(id) {
	// Remove custom models for player after disconnecting
	new iWpnID
	for (iWpnID = CSW_P228; iWpnID <= CSW_LAST_WEAPON; iWpnID++) {
		if (g_iCustomViewModelsPosition[id][iWpnID] != NULLENT)
			RemoveCustomViewModel(id, iWpnID)
		if (g_iCustomWeaponModelsPosition[id][iWpnID] != NULLENT)
			RemoveCustomWeaponModel(id, iWpnID)
	}
}

// Hook called when deploy any 
public fw_DefaultDeploy_Post(ent)
{
	// Invalid entity?
	if (is_nullent(ent))
		return

	// Get weapon's owner
	new id = get_member(ent, m_pPlayer)
	
	// Owner not valid
	if (!is_user_alive(id))
		return;
	
	// Get weapon's id
	new iWpn = get_member(ent, m_iId)
	
	new szModel[MAX_MODEL_LENGTH]

	// Custom view model?
	if (g_iCustomViewModelsPosition[id][iWpn] != NULLENT) {
		ArrayGetString(g_aCustomViewModelsPath, g_iCustomViewModelsPosition[id][iWpn], szModel, charsmax(szModel))
		set_entvar(id, var_viewmodel, szModel)
	}
	
	// Custom weapon model?
	if (g_iCustomWeaponModelsPosition[id][iWpn] != NULLENT) {
		ArrayGetString(g_aCustomWeaponModelsPath, g_iCustomWeaponModelsPosition[id][iWpn], szModel, charsmax(szModel))
		set_entvar(id, var_weaponmodel, szModel)
	}
}

/**
 * Private functions:
 */
AddCustomViewModel(id, iWpn, const szModel[]) {
	g_iCustomViewModelsPosition[id][iWpn] = g_iCustomViewModelsCount
	ArrayPushString(g_aCustomViewModelsPath, szModel)
	g_iCustomViewModelsCount++
}

ReplaceCustomViewModel(id, iWpn, const szModel[]) {
	ArraySetString(g_aCustomViewModelsPath, g_iCustomViewModelsPosition[id][iWpn], szModel)
}

RemoveCustomViewModel(id, iWpnID) {
	// Get current item position in dynamic array 
	new iPos = g_iCustomViewModelsPosition[id][iWpnID]
	
	// Delete model from dynamic array
	ArrayDeleteItem(g_aCustomViewModelsPath, iPos)
	g_iCustomViewModelsPosition[id][iWpnID] = NULLENT
	g_iCustomViewModelsCount--
	
	// Fix view models array positions
	for (id = 1; id <= MaxClients; id++) {
		for (iWpnID = CSW_P228; iWpnID <= CSW_LAST_WEAPON; iWpnID++) {
			if (g_iCustomViewModelsPosition[id][iWpnID] > iPos)
				g_iCustomViewModelsPosition[id][iWpnID]--
		}
	}
}

AddCustomWeaponModel(id, iWpnID, const szModel[]) {
	ArrayPushString(g_aCustomWeaponModelsPath, szModel)
	g_iCustomWeaponModelsPosition[id][iWpnID] = g_iCustomWeaponModelsCount
	g_iCustomWeaponModelsCount++
}

ReplaceCustomWeaponModel(id, iWpnID, const szModel[]) {
	ArraySetString(g_aCustomWeaponModelsPath, g_iCustomWeaponModelsPosition[id][iWpnID], szModel)
}

RemoveCustomWeaponModel(id, iWpnID) {
	// Get current item position in dynamic array 
	new iPos = g_iCustomWeaponModelsPosition[id][iWpnID]

	// Delete model from dynamic array	
	ArrayDeleteItem(g_aCustomWeaponModelsPath, iPos)
	g_iCustomWeaponModelsPosition[id][iWpnID] = NULLENT
	g_iCustomWeaponModelsCount--
	
	// Fix weapon models array positions
	for (id = 1; id <= MaxClients; id++) {
		for (iWpnID = CSW_P228; iWpnID <= CSW_LAST_WEAPON; iWpnID++) {
			if (g_iCustomWeaponModelsPosition[id][iWpnID] > iPos)
				g_iCustomWeaponModelsPosition[id][iWpnID]--
		}
	}
}

/**
 * Function of natives:
 */
public native_set_user_view_model(plugin_id, num_params) {
	// Get player index
	new id = get_param(1)
	
	// Player not found?
	if (!is_user_connected(id)) {
		// Print error on server console with date and time.
		log_error(AMX_ERR_NATIVE, "[ZE] Player is not in game (%d)", id)
		return false;
	}
	
	// Get weapon's id
	new iWpnID = get_param(2)
	
	// Invalid weapon id?
	if ((iWpnID <= CSW_NONE) || (iWpnID > CSW_LAST_WEAPON)) {
		// Print error on server console with date and time.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid weapon id (%d)", iWpnID)
		return false;
	}
	
	// Get weapon's model.
	new szModel[MAX_MODEL_LENGTH]
	get_string(3, szModel, charsmax(szModel))
	
	// Check whether player already has a custom view model set
	if (g_iCustomViewModelsPosition[id][iWpnID] == NULLENT)
		AddCustomViewModel(id, iWpnID, szModel)
	else
		ReplaceCustomViewModel(id, iWpnID, szModel)
	
	// Get current weapon's id
	new iWpnEnt = get_member(id, m_pActiveItem)
	new iWeapon = is_entity(iWpnEnt) ? get_member(iWpnEnt, m_iId) : NULLENT
	
	// Model was set for the current weapon?
	if (is_user_alive(id) && (iWeapon == iWpnID))
		set_entvar(id, var_viewmodel, szModel) // Update weapon models manually
	return true;
}

public native_reset_user_view_model(plugin_id, num_params) {
	// Get player index.
	new id = get_param(1)
	
	// Player not found?
	if (!is_user_connected(id)) {
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false;
	}
	
	// Get weapon's id
	new iWpnID = get_param(2)
	
	// Invalid weapon id?
	if ((iWpnID <= CSW_NONE) || (iWpnID > CSW_LAST_WEAPON)) {
		// Print error on server console with date and time.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid weapon id (%d)", iWpnID)
		return false;
	}
	
	// Player doesn't have a custom view model, no need to reset
	if (g_iCustomViewModelsPosition[id][iWpnID] == NULLENT)
		return true;
	
	// Remove view weapon model from dynamic array.
	RemoveCustomViewModel(id, iWpnID)
	return true;
}

public native_set_user_weap_model(plugin_id, num_params) {
	// Get player index.
	new id = get_param(1)
	
	// Player not found?
	if (!is_user_connected(id)) {
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false;
	}
	
	// Get weapon's id
	new iWpnID = get_param(2)
	
	// Invalid weapon id?
	if ((iWpnID <= CSW_NONE) || (iWpnID > CSW_LAST_WEAPON)) {
		// Print error on server console with date and time.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid weapon id (%d)", iWpnID)
		return false;
	}
	
	new szModel[MAX_MODEL_LENGTH]
	get_string(3, szModel, charsmax(szModel))
	
	// Check whether player already has a custom view model set
	if (g_iCustomWeaponModelsPosition[id][iWpnID] == NULLENT)
		AddCustomWeaponModel(id, iWpnID, szModel)
	else
		ReplaceCustomWeaponModel(id, iWpnID, szModel)
	
	// Get current weapon's id
	new iWpnEnt = get_member(id, m_pActiveItem)
	new iWeapon = is_entity(iWpnEnt) ? get_member(iWpnEnt, m_iId) : NULLENT
	
	// Model was reset for the current weapon?
	if (is_user_alive(id) && (iWpnID == iWeapon))
		set_entvar(id, var_weaponmodel, szModel) // Update weapon models manually
	return true;
}

public native_reset_user_weap_model(plugin_id, num_params) {
	// Get player index.
	new id = get_param(1)
	
	// Player not found?
	if (!is_user_connected(id)) {
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false;
	}
	
	// Get weapon's id
	new iWpnID = get_param(2)
	
	// Invalid weapon id?
	if ((iWpnID <= CSW_NONE) || (iWpnID > CSW_LAST_WEAPON)) {
		// Print error on server console with date and time.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid weapon id (%d)", iWpnID)
		return false;
	}
	
	// Player doesn't have a custom weapon model, no need to reset
	if (g_iCustomWeaponModelsPosition[id][iWpnID] == NULLENT)
		return true;
	
	// Remove weapon's model from dynamic array.
	RemoveCustomWeaponModel(id, iWpnID)
	return true;
}