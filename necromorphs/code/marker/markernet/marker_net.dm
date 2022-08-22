// MARKER NET
//
// The datum containing all the chunks.
/datum/markernet
	/// Name to show for VV and stat()
	var/name = "Camera Net"
	/// The chunks of the map, mapping the areas that the cameras can see.
	var/list/chunks
	///The image cloned by all chunk static images put onto turfs cameras cant see
	var/image/obscured

	var/list/visionSources

/datum/markernet/New()
	chunks = list()
	visionSources = list()
	obscured = new('icons/effects/cameravis.dmi')
	obscured.plane = CAMERA_STATIC_PLANE
	obscured.appearance_flags = RESET_TRANSFORM | RESET_ALPHA | RESET_COLOR | KEEP_APART
	obscured.override = TRUE

/// Checks if a chunk has been Generated in x, y, z.
/datum/markernet/proc/chunkGenerated(x, y, z)
	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)
	return chunks["[x],[y],[z]"]

// Returns the chunk in the x, y, z.
// If there is no chunk, it creates a new chunk and returns that.
/datum/markernet/proc/getCameraChunk(x, y, z)
	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)
	var/key = "[x],[y],[z]"
	. = chunks[key]
	if(!.)
		chunks[key] = . = new /datum/markerchunk(x, y, z, visionSources)

/// Updates what the aiEye can see. It is recommended you use this when the aiEye moves or it's location is set.
/datum/markernet/proc/visibility(list/moved_eyes)
	if(!islist(moved_eyes))
		moved_eyes = moved_eyes ? list(moved_eyes) : list()

	for(var/mob/camera/marker_signal/eye as anything in moved_eyes)
		var/list/visibleChunks = list()
		if(eye.loc)
			var/static_range = eye.static_visibility_range
			var/x1 = max(0, eye.x - static_range) & ~(CHUNK_SIZE - 1)
			var/y1 = max(0, eye.y - static_range) & ~(CHUNK_SIZE - 1)
			var/x2 = min(world.maxx, eye.x + static_range) & ~(CHUNK_SIZE - 1)
			var/y2 = min(world.maxy, eye.y + static_range) & ~(CHUNK_SIZE - 1)

			for(var/x = x1; x <= x2; x += CHUNK_SIZE)
				for(var/y = y1; y <= y2; y += CHUNK_SIZE)
					visibleChunks |= getCameraChunk(x, y, eye.z)

		var/list/remove = eye.visibleChunks - visibleChunks
		var/list/add = visibleChunks - eye.visibleChunks

		for(var/datum/markerchunk/chunk as anything in remove)
			chunk.remove(eye, FALSE)

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
		for(var/x = x1; x <= x2; x += CHUNK_SIZE)
			for(var/y = y1; y <= y2; y += CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, T.z)
				if(chunk)
					chunk.hasChanged()

/datum/markernet/proc/updateChunk(x, y, z)
	var/datum/markerchunk/chunk = chunkGenerated(x, y, z)
	if(chunk)
		chunk.hasChanged()

/// Add a camera to a chunk.
/datum/markernet/proc/addVisionSource(atom/A)
	var/turf/T = get_turf(A)
	if(T)
		visionSources += A
		RegisterSignal(A, COMSIG_PARENT_QDELETING, .proc/onSourceDestroy)
		if(ismovable(A))
			RegisterSignal(A, COMSIG_MOVABLE_MOVED, .proc/onSourceMove)
		var/x1 = max(0, T.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, T.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, T.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, T.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1; x <= x2; x += CHUNK_SIZE)
			for(var/y = y1; y <= y2; y += CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, T.z)
				if(chunk)
					chunk.visionSources += A
					chunk.hasChanged()

/// Removes a camera from a chunk.
/datum/markernet/proc/removeVisionSource(atom/A)
	var/turf/T = get_turf(A)
	if(T)
		visionSources -= A
		UnregisterSignal(A, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
		var/x1 = max(0, T.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, T.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, T.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, T.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1; x <= x2; x += CHUNK_SIZE)
			for(var/y = y1; y <= y2; y += CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, T.z)
				if(chunk)
					chunk.visionSources -= A
					chunk.hasChanged()

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
		for(var/x = x1; x <= x2; x += CHUNK_SIZE)
			for(var/y = y1; y <= y2; y += CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, old_loc.z)
				if(chunk)
					old_chunks |= chunk

	var/list/new_chunks = list()
	if(new_loc)
		var/x1 = max(0, new_loc.x - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y1 = max(0, new_loc.y - (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/x2 = min(world.maxx, new_loc.x + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		var/y2 = min(world.maxy, new_loc.y + (CHUNK_SIZE / 2)) & ~(CHUNK_SIZE - 1)
		for(var/x = x1; x <= x2; x += CHUNK_SIZE)
			for(var/y = y1; y <= y2; y += CHUNK_SIZE)
				var/datum/markerchunk/chunk = chunkGenerated(x, y, new_loc.z)
				if(chunk)
					new_chunks |= chunk

	for(var/datum/markerchunk/chunk as anything in old_chunks-new_chunks)
		chunk.visionSources -= source

	for(var/datum/markerchunk/chunk as anything in new_chunks-old_chunks)
		chunk.visionSources += source

	for(var/datum/markerchunk/chunk as anything in old_chunks|new_chunks)
		chunk.hasChanged()

/datum/markernet/proc/checkTurfVis(turf/position)
	var/datum/markerchunk/chunk = getCameraChunk(position.x, position.y, position.z)
	if(chunk)
		if(chunk.update_queued)
			chunk.update()
		if(chunk.visibleTurfs[position])
			return TRUE
	return FALSE

#undef CHUNK_SIZE
