#define CHUNK_SIZE 16

/datum/job/marker
	title = ROLE_MARKER_SIGNAL
/datum/job/marker/master
	title = ROLE_MARKER

/datum/antagonist/marker
	name = "\improper Marker Signal"
	show_name_in_check_antagonists = TRUE
	ui_name = "AntagInfoMarker"
	job_rank = ROLE_MARKER
	show_in_antagpanel = FALSE
	show_to_ghosts = TRUE

/mob/camera/marker
	name = "Signal"
	invisibility = INVISIBILITY_MARKER_SIGNAL
	see_invisible = SEE_INVISIBLE_MARKER_SIGNAL
	interaction_range = null
	var/list/visibleCameraChunks = list()
	var/obj/machinery/marker/master
	var/use_static = TRUE
	var/static_visibility_range = 16
	var/sprint = 10
	var/cooldown = 0
	var/acceleration = 1

/mob/camera/marker/Initialize(mapload, obj/machinery/marker/marker)
	.=..()
	master = marker
	master.signals += src
	setLoc(loc, TRUE)

/mob/camera/marker/Destroy()
	for(var/V in visibleCameraChunks)
		var/datum/camerachunk/c = V
		c.remove(src)
	master.signals -= src
	master = null
	.=..()

/mob/camera/marker/Login()
	.=..()
	if(.)
		name = "[initial(name)] ([key])"

/mob/camera/marker/proc/setLoc(destination, force_update = FALSE)
	if(master)
		destination = get_turf(destination)
		if(!force_update && (destination == get_turf(src)) )
			return //we are already here!
		if (destination)
			abstract_move(destination)
		else
			moveToNullspace()
		if(use_static)
			master.visualnet.visibility(src, client, master.signals, TRUE)
		update_parallax_contents()

/mob/camera/marker/zMove(dir, turf/target, z_move_flags = NONE, recursions_left = 1, list/falling_movs)
	. = ..()
	if(.)
		setLoc(loc, force_update = TRUE)

/mob/camera/marker/Move(new_loc, direct)
	var/initial = initial(sprint)
	var/max_sprint = 50

	if(cooldown && cooldown < world.timeofday) // 3 seconds
		sprint = initial

	for(var/i = 0; i < max(sprint, initial); i += 20)
		var/turf/step = get_turf(get_step(src, direct))
		if(step)
			setLoc(step)

	cooldown = world.timeofday + 5
	if(acceleration)
		sprint = min(sprint + 0.5, max_sprint)
	else
		sprint = initial

/atom/move_camera_by_click()
	.=..()
	if(istype(usr, /mob/camera/marker))
		var/mob/camera/marker/signal = usr
		if(signal.z == z && (isturf(loc) || isturf(src)))
			signal.setLoc(src)

/mob/camera/marker/proc/GetViewerClient()
	return client

/mob/camera/marker/master
	name = "Marker"

/mob/camera/marker/master/Initialize(mapload, obj/machinery/marker/marker)
	.=..()
	master.marker_mob = src

/mob/camera/marker/master/Destroy()
	master.marker_mob = null
	.=..()

/datum/cameranet/marker
	name = "Marker Visualnet"

/datum/cameranet/marker/getCameraChunk(x, y, z)
	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)
	var/key = "[x],[y],[z]"
	. = chunks[key]
	if(!.)
		chunks[key] = . = new /datum/camerachunk/marker(x, y, z)

/// Add a camera to a chunk.
/datum/cameranet/marker/addCamera(atom/movable/object)
	majorChunkChange(object, 1)
	//TODO: Update cameranet when object moves
	RegisterSignal(object, COMSIG_MOVABLE_MOVED, .proc/updatePortableCamera)
	RegisterSignal(object, COMSIG_PARENT_QDELETING, .proc/removeCamera)

/// Removes a camera from a chunk.
/datum/cameranet/marker/removeCamera(atom/movable/object)
	majorChunkChange(object, 0)
	UnregisterSignal(object, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))

/datum/camerachunk/marker
/// Create a new camera chunk, since the chunks are made as they are needed.
/datum/camerachunk/marker/New(x, y, z, marker_id)
	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)

	src.x = x
	src.y = y
	src.z = z

	var/list/in_range = urange(CHUNK_SIZE, locate(x + (CHUNK_SIZE / 2), y + (CHUNK_SIZE / 2), z))

	for(var/obj/machinery/marker/marker in in_range)
		if(marker.id == marker_id)
			cameras += marker
		in_range -= marker

	//Add more marker vision objects here

	for(var/turf/t as anything in block(locate(max(x, 1), max(y, 1), z), locate(min(x + CHUNK_SIZE - 1, world.maxx), min(y + CHUNK_SIZE - 1, world.maxy), z)))
		turfs[t] = t

	for(var/turf in turfs)//one for each 16x16 = 256 turfs this camera chunk encompasses
		inactive_static_images += new/image(GLOB.cameranet.obscured)

	for(var/obj/machinery/marker/camera as anything in cameras)
		if(!camera)
			continue

		for(var/turf/vis_turf in get_hear(camera.visualnet_vision_range, get_turf(camera)))
			if(turfs[vis_turf])
				visibleTurfs[vis_turf] = vis_turf

	for(var/turf/obscured_turf as anything in turfs - visibleTurfs)
		var/image/new_static = inactive_static_images[inactive_static_images.len]
		new_static.loc = obscured_turf
		active_static_images += new_static
		inactive_static_images -= new_static
		obscuredTurfs[obscured_turf] = new_static

/obj/machinery/marker
	name = "Marker"
	icon = 'necromorphs/icons/obj/marker_giant.dmi'
	icon_state = "marker_giant_dormant"
	pixel_x = -32
	var/id
	var/visualnet_vision_range = 7
	var/mob/camera/marker/marker_mob
	var/list/mob/camera/marker/signals = list()
	var/datum/cameranet/marker/visualnet = new
	var/list/locked_upgrades = list()
	var/list/unlocked_upgrades = list()

/obj/machinery/marker/Initialize(mapload)
	.=..()
	id = REF(src)
	SSnecromorph.markers[id] = src
	locked_upgrades = SSnecromorph.get_random_upgrades()
	var/list/upgrades = locked_upgrades.Copy()
	if(upgrades.len)
		for(var/i = 1 to 3)
			unlocked_upgrades |= pick(locked_upgrades)
			upgrades -= unlocked_upgrades[i]

	visualnet.addCamera(src)

/mob/dead/observer/verb/join_necromorphs()
	set name = "Join Horde"
	set category = "Necromorphs"

	if(!isobserver(usr) || !client)
		return

	var/obj/machinery/marker/marker = tgui_input_list(usr, "What marker you want to join?", "Join Horde", SSnecromorph.markers)
	if(!marker)
		return

	var/datum/mind/player_mind = new /datum/mind(key)
	player_mind.active = TRUE

	var/mob/camera/marker/holder = new(get_turf(marker), marker)

	player_mind.transfer_to(holder)
	player_mind.set_assigned_role(SSjob.GetJobType(/datum/job/marker))
	player_mind.special_role = ROLE_MARKER_SIGNAL
	player_mind.add_antag_datum(/datum/antagonist/marker)

#undef CHUNK_SIZE
