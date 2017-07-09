var/list/loadout_categories = list()
var/list/gear_datums = list()

/datum/loadout_category
	var/category = ""
	var/list/gear = list()

/datum/loadout_category/New(var/cat)
	category = cat
	..()

/hook/startup/proc/populate_gear_list()

	//create a list of gear datums to sort
	for(var/geartype in typesof(/datum/gear)-/datum/gear)
		var/datum/gear/G = geartype

		var/use_name = initial(G.display_name)
		var/use_category = initial(G.sort_category)

		if(!loadout_categories[use_category])
			loadout_categories[use_category] = new /datum/loadout_category(use_category)
		var/datum/loadout_category/LC = loadout_categories[use_category]
		gear_datums[use_name] = new geartype
		LC.gear[use_name] = gear_datums[use_name]

	loadout_categories = sortAssoc(loadout_categories)
	for(var/loadout_category in loadout_categories)
		var/datum/loadout_category/LC = loadout_categories[loadout_category]
		LC.gear = sortAssoc(LC.gear)
	return 1

/datum/category_item/player_setup_item/loadout
	name = "Loadout"
	sort_order = 1
	var/current_tab = "General"

/datum/category_item/player_setup_item/loadout/load_character(var/savefile/S)
	S["gear"] >> pref.gear

/datum/category_item/player_setup_item/loadout/save_character(var/savefile/S)
	S["gear"] << pref.gear

/datum/category_item/player_setup_item/loadout/proc/valid_gear_choices(var/max_cost)
	var/list/valid_gear_choices = list()
	for(var/gear_name in gear_datums)
		var/datum/gear/G = gear_datums[gear_name]
		if(G.whitelisted && !is_alien_whitelisted(preference_mob(), G.whitelisted))
			continue
		if(max_cost && G.cost > max_cost)
			continue
		valid_gear_choices += gear_name
	return valid_gear_choices

/datum/category_item/player_setup_item/loadout/sanitize_character()
	if(!islist(pref.gear))
		pref.gear = list()

	for(var/gear_name in pref.gear)
		if(!(gear_name in gear_datums))
			pref.gear -= gear_name

	var/total_cost = 0
	for(var/gear_name in pref.gear)
		if(!gear_datums[gear_name])
			pref.gear -= gear_name
		else if(!(gear_name in valid_gear_choices()))
			pref.gear -= gear_name
		else
			var/datum/gear/G = gear_datums[gear_name]
			if(total_cost + G.cost > MAX_GEAR_COST)
				pref.gear -= gear_name
			else
				total_cost += G.cost

/datum/category_item/player_setup_item/loadout/content()
	var/total_cost = 0
	if(pref.gear && pref.gear.len)
		for(var/i = 1; i <= pref.gear.len; i++)
			var/datum/gear/G = gear_datums[pref.gear[i]]
			if(G)
				total_cost += G.cost

	var/fcolor =  "#3366CC"
	if(total_cost < MAX_GEAR_COST)
		fcolor = "#E67300"
	. = list()
	. += "<table align = 'center' width = 100%>"
	. += "<tr><td colspan=3><center><b><font color = '[fcolor]'>[total_cost]/[MAX_GEAR_COST]</font> loadout points spent.</b> \[<a href='?src=\ref[src];clear_loadout=1'>Clear Loadout</a>\]</center></td></tr>"

	. += "<tr><td colspan=3><center><b>"

	var/categories = 0
	var/firstcat = 1
	for(var/category in loadout_categories)
		++categories
		if(firstcat)
			firstcat = 0
		else
			. += " |"
		if(category == current_tab)
			. += " [category] "
		else
			var/datum/loadout_category/LC = loadout_categories[category]
			var/tcolor =  "#3366CC"
			for(var/thing in LC.gear)
				if(thing in pref.gear)
					tcolor = "#E67300"
					break
			. += " <a href='?src=\ref[src];select_category=[category]'><font color = '[tcolor]'>[category]</font></a> "
	. += "</b></center></td></tr>"

	if (categories == 0)
		return ""

	var/datum/loadout_category/LC = loadout_categories[current_tab]
	. += "<tr><td colspan=3><hr></td></tr>"
	. += "<tr><td colspan=3><b><center>[LC.category]</center></b></td></tr>"
	. += "<tr><td colspan=3><hr></td></tr>"
	for(var/gear_name in LC.gear)
		if(!(gear_name in valid_gear_choices()))
			continue
		var/datum/gear/G = LC.gear[gear_name]
		var/ticked = (G.display_name in pref.gear)
		var/obj/item/temp = G.path
		. += "<tr style='vertical-align:top'><td width=25%><a href='?src=\ref[src];toggle_gear=[G.display_name]'><font color='[ticked ? "#E67300" : "#3366CC"]'>[G.display_name]</font></a>"
		if(ticked)
			var/metadata = pref.gear[G.display_name]
			if(!metadata)
				metadata = list()
				pref.gear[G.display_name] = metadata
			for(var/datum/gear_tweak/tweak in G.gear_tweaks)
				var/tweak_input = metadata["[tweak]"]
				if(!tweak_input)
					tweak_input = tweak.get_default()
					metadata["[tweak]"] = tweak_input
				. += " <a href='?src=\ref[src];gear=[G.display_name];tweak=\ref[tweak]'>[tweak.get_contents(tweak_input)]</a>"
		. += "</td>"
		. += "<td width = 10% style='vertical-align:top'>[G.cost]</td>"
		. += "<td><font size=2><i>[initial(temp.desc)]</i></font></td></tr>"
	. += "</table>"
	return jointext(., "")

/datum/category_item/player_setup_item/loadout/OnTopic(href, href_list, user)
	if(href_list["toggle_gear"])
		var/datum/gear/TG = gear_datums[href_list["toggle_gear"]]
		if(TG.display_name in pref.gear)
			pref.gear -= TG.display_name
		else
			var/total_cost = 0
			for(var/gear_name in pref.gear)
				var/datum/gear/G = gear_datums[gear_name]
				if(istype(G)) total_cost += G.cost
			if((total_cost+TG.cost) <= MAX_GEAR_COST)
				pref.gear += TG.display_name
		return TOPIC_REFRESH
	if(href_list["gear"] && href_list["tweak"])
		var/datum/gear/gear = gear_datums[href_list["gear"]]
		var/datum/gear_tweak/tweak = locate(href_list["tweak"])
		if(!tweak || !istype(gear) || !(tweak in gear.gear_tweaks))
			return TOPIC_NOACTION
		var/metadata = tweak.get_metadata(user)
		if(!metadata && !CanUseTopic(user))
			return TOPIC_NOACTION
		var/gear_metadata = pref.gear[gear.display_name]
		gear_metadata["[tweak]"] = metadata
		return TOPIC_REFRESH
	else if(href_list["select_category"])
		current_tab = href_list["select_category"]
		return TOPIC_REFRESH
	else if(href_list["clear_loadout"])
		pref.gear.Cut()
		return TOPIC_REFRESH
	return ..()

/datum/gear
	var/display_name       //Name/index. Must be unique.
	var/path               //Path to item.
	var/cost = 1           //Number of points used. Items in general cost 1 point, storage/armor/gloves/special use costs 2 points.
	var/slot               //Slot to equip to.
	var/list/allowed_roles //Roles that can spawn with this item.
	var/whitelisted        //Term to check the whitelist for..
	var/sort_category = "General"
	var/list/gear_tweaks = list() //List of datums which will alter the item after it has been spawned.

/datum/gear/proc/spawn_item(var/location, var/metadata)
	var/item = new path(location)
	for(var/datum/gear_tweak/gt in gear_tweaks)
		gt.apply_tweak(item, metadata["[gt]"])
	return item