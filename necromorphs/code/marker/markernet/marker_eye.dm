/mob/camera/marker_signal
	name = "Signal"
	icon_state = "markersignal-"
	icon = 'necromorphs/icons/signals/eye.dmi'
	plane = MARKER_SIGNAL_PLANE
	invisibility = INVISIBILITY_OBSERVER
	see_invisible = SEE_INVISIBLE_OBSERVER
	sight = SEE_MOBS|SEE_OBJS|SEE_TURFS
	mouse_opacity = MOUSE_OPACITY_ICON
	movement_type = GROUND|FLYING
	hud_type = /datum/hud/marker
	interaction_range = null
	var/updatedir
	var/list/visibleChunks
	var/obj/structure/marker/marker
	var/static_visibility_range = 16
	var/atom/movable/screen/cameranet_static/cameranet_static

/mob/camera/marker_signal/Initialize(mapload, obj/structure/marker/master)
	visibleChunks = list()
	cameranet_static = new(null, src)
	. = ..()
	if(master)
		marker = master
	else
		return INITIALIZE_HINT_QDEL
	AddElement(/datum/element/movetype_handler)
	icon_state += "[rand(1, 25)]"
	master.marker_signals += src
	forceMove(get_turf(marker))
	master.markernet.eyes += src

/mob/camera/marker_signal/Destroy()
	marker.markernet.eyes -= src
	marker.marker_signals -= src
	marker = null
	for(var/V in visibleChunks)
		var/datum/markerchunk/c = V
		c.remove(src)
	QDEL_NULL(cameranet_static)
	return ..()

/mob/camera/marker_signal/Login()
	. = ..()
	if(!. || !client)
		return FALSE
	for(var/datum/markerchunk/chunk as anything in visibleChunks)
		client.images += chunk.active_masks
	marker.markernet.visibility(src)
	var/view = client.view || world.view
	cameranet_static.update_o(view)
	cameranet_static.RegisterSignal(client, COMSIG_VIEW_SET, /atom/movable/screen/cameranet_static/proc/on_view_change)
	client.screen += cameranet_static

/mob/camera/marker_signal/Logout()
	cameranet_static.UnregisterSignal(canon_client, COMSIG_VIEW_SET)
	return ..()

/mob/camera/marker_signal/Move(NewLoc, direct, glide_size_override = 32)
	if(updatedir)
		setDir(direct)//only update dir if we actually need it, so overlays won't spin on base sprites that don't have directions of their own

	if(glide_size_override)
		set_glide_size(glide_size_override)
	if(NewLoc)
		abstract_move(NewLoc)
		update_parallax_contents()
	else
		var/turf/destination = get_turf(src)

		if((direct & NORTH) && y < world.maxy)
			destination = get_step(destination, NORTH)

		else if((direct & SOUTH) && y > 1)
			destination = get_step(destination, SOUTH)

		if((direct & EAST) && x < world.maxx)
			destination = get_step(destination, EAST)

		else if((direct & WEST) && x > 1)
			destination = get_step(destination, WEST)

		abstract_move(destination)

/mob/camera/marker_signal/forceMove(atom/destination)
	abstract_move(destination) // move like the wind
	return TRUE

/mob/camera/marker_signal/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	..()
	if(client)
		marker.markernet.visibility(src)
		update_static(old_loc)
	return TRUE

/mob/camera/marker_signal/verb/possess_necromorph(mob/living/carbon/necromorph/necro in world)
	set name = "Possess Necromorph"
	set category = "Object"

	necro.controlling = src
	mind.transfer_to(necro, TRUE)
	//moveToNullspace()
	//We don't want to use doMove() here
	abstract_move(null)

/mob/camera/marker_signal/marker
	name = "Marker"
	icon_state = "mastersignal"
	icon = 'necromorphs/icons/signals/mastersignal.dmi'
	invisibility = INVISIBILITY_OBSERVER
	see_invisible = SEE_INVISIBLE_OBSERVER
	hud_type = /datum/hud/marker
	interaction_range = null
	pixel_x = -7
	pixel_y = -7

/mob/camera/marker_signal/marker/Initialize(mapload, obj/structure/marker/master)
	. = ..()
	icon_state = "mastersignal"

/mob/camera/marker_signal/marker/Destroy()
	marker?.camera_mob = null
	return ..()
