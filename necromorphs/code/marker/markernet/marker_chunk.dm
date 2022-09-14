#define CHUNK_SIZE 16 // Only chunk sizes that are to the power of 2. E.g: 2, 4, 8, 16, etc..

// CAMERA CHUNK
//
// A 16x16 grid of the map with a list of turfs that can be seen, are visible and are dimmed.
// Allows the AI Eye to stream these chunks and know what it can and cannot see.

/datum/markerchunk

	var/list/visibleTurfs
	/// Assoc list of the form: list(source = list(turfs source can see in this chunk))
	/// Contains all vision sources
	var/list/visionSources
	/// Vision sources that don't update in hasChanged
	var/list/rangeVisionSources
	/// Vision sources that update in hasChanged
	var/list/viewVisionSources
	///list of all turfs = image that masks static
	var/list/turfs

	var/list/active_masks
	///camera mobs that can see turfs in our chunk
	var/list/seenby

	var/list/queued_for_update

	var/x = 0
	var/y = 0
	var/z = 0

/// Create a new camera chunk, since the chunks are made as they are needed.
/datum/markerchunk/New(x, y, z, list/netVisionSources, image/example)
	visibleTurfs = list()
	visionSources = list()
	rangeVisionSources = list()
	viewVisionSources = list()
	turfs = list()
	active_masks = list()
	seenby = list()

	x &= ~(CHUNK_SIZE - 1)
	y &= ~(CHUNK_SIZE - 1)

	src.x = x
	src.y = y
	src.z = z

	for(var/turf/t as anything in block(locate(max(x, 1), max(y, 1), z), locate(min(x + CHUNK_SIZE - 1, world.maxx), min(y + CHUNK_SIZE - 1, world.maxy), z)))
		turfs[t] = image(example, t)

	var/turf/centre_turf = locate(x + (CHUNK_SIZE / 2), y + (CHUNK_SIZE / 2), z)
	for(var/atom/source as anything in netVisionSources)
		if(source.z != z || get_dist(source, centre_turf) > CHUNK_SIZE + (CHUNK_SIZE / 2))
			continue

		var/list/visible = list()
		visionSources[source] = visible
		for(var/turf/vis_turf as anything in (source.can_see_marker() & turfs))
			visible += vis_turf
			visibleTurfs |= vis_turf
			active_masks |= turfs[vis_turf]

		var/vision_type = netVisionSources[source]
		if(vision_type == VISION_SOURCE_RANGE)
			rangeVisionSources += source
		else if(vision_type == VISION_SOURCE_VIEW)
			viewVisionSources += source

/datum/markerchunk/Destroy(force, ...)
	for(var/mob/camera/marker_signal/eye as anything in seenby)
		remove(eye)
	return ..()

/// Add an AI eye to the chunk
/datum/markerchunk/proc/add(mob/camera/marker_signal/eye)
	eye.visibleChunks += src
	seenby += eye
	if(queued_for_update)
		update()

	eye.client?.images += active_masks

/// Remove an AI eye from the chunk
/datum/markerchunk/proc/remove(mob/camera/marker_signal/eye)
	eye.visibleChunks -= src
	seenby -= eye

	eye.client?.images -= active_masks

/*
 * Updates the chunk, makes sure that it doesn't update too much. If the chunk isn't being watched it will
 * instead be flagged to update the next time an AI Eye moves near it.
 */
/datum/markerchunk/proc/hasChanged(list/to_update)
	LAZYADD(queued_for_update, to_update)
	if(length(seenby))
		update()

/// The actual updating. It gathers the visible turfs from cameras and puts them into the appropiate lists.
/datum/markerchunk/proc/update()
	if(!queued_for_update)
		return

	for(var/mob/camera/marker_signal/client_eye as anything in seenby)
		client_eye.client?.images -= active_masks

	var/turf/point = locate(src.x + (CHUNK_SIZE / 2), src.y + (CHUNK_SIZE / 2), src.z)
	for(var/atom/source as anything in queued_for_update)
		if(get_dist(point, source) > CHUNK_SIZE + (CHUNK_SIZE / 2))
			visionSources -= source
			rangeVisionSources -= source
			viewVisionSources -= source
			continue

		var/list/visible = list()
		visionSources[source] = visible
		for(var/turf/vis_turf as anything in (source.can_see_marker() & turfs))
			visible += vis_turf

	visibleTurfs.Cut()
	active_masks.Cut()

	for(var/atom/source as anything in visionSources)
		visibleTurfs |= visionSources[source]

	for(var/turf/vis_turf as anything in visibleTurfs)
		active_masks += turfs[vis_turf]

	for(var/mob/camera/marker_signal/client_eye as anything in seenby)
		client_eye.client?.images += active_masks

	queued_for_update = null
