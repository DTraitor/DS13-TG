// MARKER NET
//
// The datum containing all the chunks.
/datum/markernet
	/// Name to show for VV and stat()
	var/name = "Camera Net"
	/// The chunks of the map, mapping the areas that the cameras can see.
	var/list/chunks
	///The image cloned by all chunk static images put onto turfs cameras cant see
	var/image/alpha_mask

	var/list/visionSources

	var/list/eyes

/datum/markernet/New()
	chunks = list()
	visionSources = list()
	eyes = list()
	alpha_mask = image('necromorphs/icons/hud/alpha_mask.dmi', null, "alpha_mask")
	alpha_mask.plane = OBSCURITY_MASKING_PLANE
	alpha_mask.appearance_flags = RESET_TRANSFORM | RESET_ALPHA | RESET_COLOR | KEEP_APART

// Used only in one place, if you want it to use somewhere else - do safety checks first. e.g. chunkGenerated()
/datum/markernet/proc/generateChunk(x, y, z)
	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)
	return chunks["[x],[y],[z]"] = new /datum/markerchunk(x, y, z, visionSources, alpha_mask)

/// Checks if a chunk has been Generated in x, y, z.
/datum/markernet/proc/chunkGenerated(x, y, z)
	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)
	return chunks["[x],[y],[z]"]

/// Updates what the aiEye can see. It is recommended you use this when the aiEye moves or it's location is set.
/datum/markernet/proc/visibility(mob/camera/marker_signal/eye)
	var/list/visibleChunks = list()
	if(eye.loc)
		var/static_range = eye.static_visibility_range
		var/x1 = max(0, eye.x - static_range) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, eye.y - static_range) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, eye.x + static_range) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, eye.y + static_range) & ~(CHUNK_SIZE - 1)

		for(var/x = x1 to x2 step CHUNK_SIZE)
			for(var/y = y1 to y2 step CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, eye.z)
				if(chunk)
					visibleChunks |= chunk

	var/list/remove = eye.visibleChunks - visibleChunks
	var/list/add = visibleChunks - eye.visibleChunks

	for(var/datum/markerchunk/chunk as anything in remove)
		chunk.remove(eye)

	for(var/datum/markerchunk/chunk as anything in add)
		chunk.add(eye)

/// Updates the chunks that the turf is located in. Use this when obstacles are destroyed or when doors open.
/datum/markernet/proc/updateVisibility(atom/A, opacity_check = 1)
	if(!SSticker || (opacity_check && !A.opacity))
		return
	var/turf/T = get_turf(A)
	if(T)
		var/x1 = max(0, T.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, T.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, T.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, T.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1 to x2 step CHUNK_SIZE)
			for(var/y = y1 to y2 step CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, T.z)
				if(length(chunk?.viewVisionSources))
					chunk.hasChanged(chunk.viewVisionSources)

/// Add a camera to a chunk.
/datum/markernet/proc/addVisionSource(atom/A, movable, vision_type = VISION_SOURCE_RANGE)
	var/turf/T = get_turf(A)
	if(T)
		visionSources[A] = vision_type
		RegisterSignal(A, COMSIG_PARENT_QDELETING, .proc/onSourceDestroy)
		var/x1 = max(0, T.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, T.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, T.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, T.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1 to x2 step CHUNK_SIZE)
			for(var/y = y1 to y2 step CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, T.z)
				if(chunk)
					var/list/visible = list()
					chunk.visionSources[A] = visible
					for(var/turf/vis_turf as anything in (A.can_see_marker() & chunk.turfs))
						visible += vis_turf
						chunk.visibleTurfs |= vis_turf
						chunk.active_masks |= chunk.turfs[vis_turf]
					for(var/mob/camera/marker_signal/eye as anything in chunk.seenby)
						eye.client?.images |= chunk.active_masks
					if(vision_type == VISION_SOURCE_RANGE)
						chunk.rangeVisionSources += A
					else if(vision_type == VISION_SOURCE_VIEW)
						chunk.viewVisionSources += A
				else
					chunk = generateChunk(x, y, T.z)
					for(var/mob/camera/marker_signal/eye as anything in eyes)
						if(abs(eye.x - x) <= eye.static_visibility_range && abs(eye.y - y) <= eye.static_visibility_range)
							chunk.add(eye)
	if(movable)
		RegisterSignal(A, COMSIG_MOVABLE_MOVED, .proc/onSourceMove)

/// Removes a camera from a chunk.
/datum/markernet/proc/removeVisionSource(atom/A)
	UnregisterSignal(A, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
	var/turf/T = get_turf(A)
	if(T)
		visionSources -= A
		var/x1 = max(0, T.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, T.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, T.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, T.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1 to x2 step CHUNK_SIZE)
			for(var/y = y1 to y2 step CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, T.z)
				if(chunk)
					chunk.visionSources -= A
					chunk.rangeVisionSources -= A
					chunk.viewVisionSources -= A
					LAZYINITLIST(chunk.queued_for_update)
					if(length(chunk.seenby))
						chunk.update()

/datum/markernet/proc/onSourceDestroy(atom/source)
	removeVisionSource(source)

/datum/markernet/proc/onSourceMove(atom/movable/source, turf/old_loc)
	SIGNAL_HANDLER
	var/turf/new_loc = get_turf(source)
	if(new_loc == old_loc)
		return

	var/list/old_chunks = list()
	if(old_loc)
		var/x1 = max(0, old_loc.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, old_loc.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, old_loc.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, old_loc.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1 to x2 step CHUNK_SIZE)
			for(var/y = y1 to y2 step CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, old_loc.z)
				if(chunk)
					old_chunks |= chunk

	var/list/new_chunks = list()
	if(new_loc)
		var/x1 = max(0, new_loc.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, new_loc.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, new_loc.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, new_loc.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1 to x2 step CHUNK_SIZE)
			for(var/y = y1 to y2 step CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, new_loc.z)
				if(chunk)
					new_chunks |= chunk
				else
					// New chunks will handle our movement
					chunk = generateChunk(x, y, new_loc.z)
					for(var/mob/camera/marker_signal/eye as anything in eyes)
						if(abs(eye.x - x) <= eye.static_visibility_range && abs(eye.y - y) <= eye.static_visibility_range)
							chunk.add(eye)

	for(var/datum/markerchunk/chunk as anything in old_chunks-new_chunks)
		chunk.visionSources -= source
		chunk.rangeVisionSources -= source
		chunk.viewVisionSources -= source
		LAZYINITLIST(chunk.queued_for_update)
		if(length(chunk.seenby))
			chunk.update()

	for(var/datum/markerchunk/chunk as anything in new_chunks-old_chunks)
		chunk.visionSources[source] = list()
		if(visionSources[source] == VISION_SOURCE_RANGE)
			chunk.rangeVisionSources += source
		else if(visionSources[source] == VISION_SOURCE_VIEW)
			chunk.viewVisionSources += source
		chunk.hasChanged(source)

	for(var/datum/markerchunk/chunk as anything in old_chunks|new_chunks)
		chunk.hasChanged(source)

/datum/markernet/proc/checkTurfVis(turf/position)
	var/datum/markerchunk/chunk = chunkGenerated(position.x, position.y, position.z)
	if(chunk)
		if(chunk.queued_for_update)
			chunk.update()
		if(position in chunk.visibleTurfs)
			return TRUE
	return FALSE

#undef CHUNK_SIZE
