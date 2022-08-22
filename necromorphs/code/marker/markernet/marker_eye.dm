/mob/camera/marker_signal
	name = "Signal"
	icon_state = "markersignal-"
	icon = 'necromorphs/icons/signals/eye.dmi'
	invisibility = INVISIBILITY_OBSERVER
	see_invisible = SEE_INVISIBLE_OBSERVER
	sight = SEE_MOBS|SEE_OBJS|SEE_TURFS
	movement_type = GROUND|FLYING
	hud_type = /datum/hud/marker
	interaction_range = null
	var/updatedir
	var/list/visibleChunks = list()
	var/obj/structure/marker/marker
	var/static_visibility_range = 16

/mob/camera/marker_signal/Initialize(mapload, obj/structure/marker/master)
	. = ..()
	if(master)
		marker = master
	else
		return INITIALIZE_HINT_QDEL
	AddElement(/datum/element/movetype_handler)
	icon_state += "[rand(1, 25)]"
	master.marker_signals += src
	forceMove(get_turf(marker))

/mob/camera/marker_signal/Destroy()
	if(marker)
		marker.marker_signals -= src
		marker = null
	for(var/V in visibleChunks)
		var/datum/markerchunk/c = V
		c.remove(src)
	return ..()

/mob/camera/marker_signal/proc/get_visible_turfs()
	if(!isturf(loc))
		return list()
	var/list/view = client ? getviewsize(client.view) : getviewsize(world.view)
	var/turf/lowerleft = locate(max(1, x - (view[1] - 1)/2), max(1, y - (view[2] - 1)/2), z)
	var/turf/upperright = locate(min(world.maxx, lowerleft.x + (view[1] - 1)), min(world.maxy, lowerleft.y + (view[2] - 1)), lowerleft.z)
	return block(lowerleft, upperright)

/mob/camera/marker_signal/Move(NewLoc, direct, glide_size_override = 32)
	if(updatedir)
		setDir(direct)//only update dir if we actually need it, so overlays won't spin on base sprites that don't have directions of their own

	if(glide_size_override)
		set_glide_size(glide_size_override)
	if(NewLoc)
		abstract_move(NewLoc)
		marker.markernet.visibility(src, client)
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
		marker.markernet.visibility(src, client)

/mob/camera/marker_signal/forceMove(atom/destination)
	abstract_move(destination) // move like the wind
	marker.markernet.visibility(src, client)
	return TRUE

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
