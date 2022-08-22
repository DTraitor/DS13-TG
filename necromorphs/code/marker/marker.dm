/obj/structure/marker/Initialize(mapload)
	.=..()
	GLOB.necromorph_markers += src
	markernet = new
	markernet.addVisionSource(src)

	camera_mob = new /mob/camera/marker_signal/marker(null, src)
	camera_mob.real_name = camera_mob.name
	camera_mob.mouse_opacity = MOUSE_OPACITY_ICON
	camera_mob.invisibility = INVISIBILITY_OBSERVER

	for(var/datum/necro_class/class as anything in subtypesof(/datum/necro_class))
		necro_classes[class] = new class()

/obj/structure/marker/Destroy()
	GLOB.necromorph_markers -= src
	QDEL_NULL(markernet)
	.=..()

/obj/structure/marker/proc/hive_mind_message(mob/sender, message)
	for(var/mob/dead/observer/observer as anything in GLOB.current_observers_list)
		if(!observer?.client?.prefs || !(observer.client.prefs.chat_toggles & CHAT_NECROMORPH))
			continue
		observer.show_message("[FOLLOW_LINK(observer, sender)] [message]")

	camera_mob?.show_message(message)

	for(var/mob/camera/marker_signal/signal as anything in marker_signals)
		signal.show_message(message)

	for(var/mob/living/carbon/necromorph/necro as anything in necromorphs)
		necro.show_message(message)

/obj/structure/marker/proc/add_necro(mob/living/carbon/necromorph/necro)
	// If the necro is part of another hivemind, they should be removed from that one first
	if(necro.marker != src)
		necro.marker.remove_necro(necro, TRUE)
	necro.marker = src
	necromorphs |= necro
	markernet.addVisionSource(src)

/obj/structure/marker/proc/remove_necro(mob/living/carbon/necromorph/necro, hard=FALSE, light_mode = FALSE)
	if(necro.marker != src)
		return
	markernet.removeVisionSource(src)
	necromorphs -= necro
	necro.marker = null

