#define CHUNK_SIZE 16 // Only chunk sizes that are to the power of 2. E.g: 2, 4, 8, 16, etc..
#define UPDATE_BUFFER_TIME (1 SECONDS)

// CAMERA CHUNK
//
// A 16x16 grid of the map with a list of turfs that can be seen, are visible and are dimmed.
// Allows the AI Eye to stream these chunks and know what it can and cannot see.

/datum/markerchunk
	///turfs our cameras cant see but are inside our grid. associative list of the form: list(obscured turf = static image on that turf)
	var/list/obscuredTurfs
	///turfs our cameras can see inside our grid
	var/list/visibleTurfs
	///cameras that can see into our grid
	var/list/visionSources
	///list of all turfs
	var/list/turfs
	///camera mobs that can see turfs in our grid
	var/list/seenby
	///images created to represent obscured turfs
	var/list/inactive_static_images
	///images currently in use on obscured turfs.
	var/list/active_static_images

	var/update_queued = FALSE
	var/x = 0
	var/y = 0
	var/z = 0

/// Create a new camera chunk, since the chunks are made as they are needed.
/datum/markerchunk/New(x, y, z, list/netVisionSources)
	obscuredTurfs = list()
	visibleTurfs = list()
	visionSources = list()
	turfs = list()
	seenby = list()
	inactive_static_images = list()
	active_static_images = list()

	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)

	src.x = x
	src.y = y
	src.z = z

	var/turf/centre_turf = locate(x + (CHUNK_SIZE / 2), y + (CHUNK_SIZE / 2))
	for(var/atom/A as anything in netVisionSources)
		if(get_dist(A, centre_turf) <= CHUNK_SIZE)
			visionSources += A

	for(var/turf/t as anything in block(locate(max(x, 1), max(y, 1), z), locate(min(x + CHUNK_SIZE - 1, world.maxx), min(y + CHUNK_SIZE - 1, world.maxy), z)))
		turfs[t] = t

	for(var/turf in turfs)//one for each 16x16 = 256 turfs this camera chunk encompasses
		inactive_static_images += new/image(GLOB.cameranet.obscured)

	for(var/atom/source as anything in visionSources)
		for(var/turf/vis_turf in source.can_see_marker())
			if(turfs[vis_turf])
				visibleTurfs[vis_turf] = vis_turf

	for(var/turf/obscured_turf as anything in turfs - visibleTurfs)
		var/image/new_static = inactive_static_images[length(inactive_static_images)]
		new_static.loc = obscured_turf
		active_static_images += new_static
		inactive_static_images -= new_static
		obscuredTurfs[obscured_turf] = new_static

/// Add an AI eye to the chunk
/datum/markerchunk/proc/add(mob/camera/marker_signal/eye)
	eye.visibleChunks += src
	seenby += eye
	if(update_queued)
		update()

	if(eye.client)
		eye.client.images += active_static_images

/// Remove an AI eye from the chunk
/datum/markerchunk/proc/remove(mob/camera/marker_signal/eye)
	eye.visibleChunks -= src
	seenby -= eye

	if(eye.client)
		eye.client.images -= active_static_images

/// Called when a chunk has changed. I.E: A wall was deleted.
/datum/markerchunk/proc/visibilityChanged(turf/loc)
	if(!visibleTurfs[loc])
		return
	hasChanged()

/**
 * Updates the chunk, makes sure that it doesn't update too much. If the chunk isn't being watched it will
 * instead be flagged to update the next time an AI Eye moves near it.
 */
/datum/markerchunk/proc/hasChanged()
	if(length(seenby))
		//addtimer(CALLBACK(src, .proc/update), UPDATE_BUFFER_TIME, TIMER_UNIQUE)
		//Let's see how this will work out first. If it causes too much lag - use timer (or ideally a subsystem to track perfomance)
		update()
	else
		update_queued = TRUE

/// The actual updating. It gathers the visible turfs from cameras and puts them into the appropiate lists.
/datum/markerchunk/proc/update()
	var/list/updated_visible_turfs = list()

	for(var/atom/source as anything in visionSources)
		var/turf/point = locate(src.x + (CHUNK_SIZE / 2), src.y + (CHUNK_SIZE / 2), src.z)
		if(get_dist(point, source) > CHUNK_SIZE + (CHUNK_SIZE / 2))
			continue

		for(var/turf/vis_turf in source.can_see_marker())
			if(turfs[vis_turf])
				updated_visible_turfs[vis_turf] = vis_turf

	///new turfs that we couldnt see last update but can now
	var/list/newly_visible_turfs = updated_visible_turfs - visibleTurfs
	///turfs that we could see last update but cant see now
	var/list/newly_obscured_turfs = visibleTurfs - updated_visible_turfs

	for(var/mob/camera/marker_signal/client_eye as anything in seenby)
		if(!client_eye.client)
			continue

		client_eye.client.images -= active_static_images

	for(var/turf/visible_turf as anything in newly_visible_turfs)
		var/image/static_image_to_deallocate = obscuredTurfs[visible_turf]
		if(!static_image_to_deallocate)
			continue

		static_image_to_deallocate.loc = null
		active_static_images -= static_image_to_deallocate
		inactive_static_images += static_image_to_deallocate

		obscuredTurfs -= visible_turf

	for(var/turf/obscured_turf as anything in newly_obscured_turfs)
		if(obscuredTurfs[obscured_turf] || istype(obscured_turf, /turf/open/ai_visible))
			continue

		var/image/static_image_to_allocate = inactive_static_images[length(inactive_static_images)]
		if(!static_image_to_allocate)
			stack_trace("somehow a camera chunk ran out of static images!")
			break

		obscuredTurfs[obscured_turf] = static_image_to_allocate
		static_image_to_allocate.loc = obscured_turf

		inactive_static_images -= static_image_to_allocate
		active_static_images += static_image_to_allocate

	visibleTurfs = updated_visible_turfs

	update_queued = FALSE

	for(var/mob/camera/marker_signal/client_eye as anything in seenby)
		if(!client_eye.client)
			continue
		client_eye.client.images += active_static_images

#undef UPDATE_BUFFER_TIME
