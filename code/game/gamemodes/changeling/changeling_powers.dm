var/global/list/possible_changeling_IDs = list("Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta","Iota","Kappa","Lambda","Mu","Nu","Xi","Omicron","Pi","Rho","Sigma","Tau","Upsilon","Phi","Chi","Psi","Omega")

/datum/changeling //stores changeling powers, changeling recharge thingie, changeling absorbed DNA and changeling ID (for changeling hivemind)
	var/list/absorbed_dna = list()
	var/list/absorbed_species = list()
	var/list/absorbed_languages = list()
	var/absorbedcount = 0
	var/chem_charges = 20
	var/chem_recharge_rate = 0.5
	var/chem_storage = 50
	var/sting_range = 1
	var/changelingID = "Changeling"
	var/geneticdamage = 0
	var/isabsorbing = 0
	var/geneticpoints = 25
	var/purchasedpowers = list()
	var/mimicing = ""

/datum/changeling/New(var/gender=FEMALE)
	..()
	var/honorific = (gender == FEMALE) ? "Ms." : "Mr."
	if(possible_changeling_IDs.len)
		changelingID = pick(possible_changeling_IDs)
		possible_changeling_IDs -= changelingID
		changelingID = "[honorific] [changelingID]"
	else
		changelingID = "[honorific] [rand(1,999)]"

/datum/changeling/proc/regenerate()
	chem_charges = min(max(0, chem_charges+chem_recharge_rate), chem_storage)
	geneticdamage = max(0, geneticdamage-1)

/datum/changeling/proc/GetDNA(var/dna_owner)
	var/datum/dna/chosen_dna
	for(var/datum/dna/DNA in absorbed_dna)
		if(dna_owner == DNA.real_name)
			chosen_dna = DNA
			break
	return chosen_dna

//Restores our verbs. It will only restore verbs allowed during lesser (monkey) form if we are not human
/mob/proc/make_changeling()

	if(!mind)				return
	if(!mind.changeling)	mind.changeling = new /datum/changeling(gender)

	verbs += /datum/changeling/proc/EvolutionMenu
	add_language(LANGUAGE_CHANGELING)


	var/lesser_form = isMonkey()

	if(!powerinstances.len)
		for(var/P in powers)
			powerinstances += new P()

	// Code to auto-purchase free powers.
	for(var/datum/power/changeling/P in powerinstances)
		if(!P.genomecost) // Is it free?
			if(!(P in mind.changeling.purchasedpowers)) // Do we not have it already?
				mind.changeling.purchasePower(mind, P.name, 0)// Purchase it. Don't remake our verbs, we're doing it after this.

	for(var/datum/power/changeling/P in mind.changeling.purchasedpowers)
		if(P.isVerb)
			if(lesser_form && !P.allowduringlesserform)	continue
			if(!(P in src.verbs))
				src.verbs += P.verbpath

	mind.changeling.absorbed_dna |= dna

	var/mob/living/carbon/human/H = src
	if(istype(H))
		mind.changeling.absorbed_species += H.species.name

	for(var/language in languages)
		mind.changeling.absorbed_languages |= language

	return 1

//removes our changeling verbs
/mob/proc/remove_changeling_powers()
	if(!mind || !mind.changeling)	return
	for(var/datum/power/changeling/P in mind.changeling.purchasedpowers)
		if(P.isVerb)
			verbs -= P.verbpath


//Helper proc. Does all the checks and stuff for us to avoid copypasta
/mob/proc/changeling_power(var/required_chems=0, var/required_dna=0, var/max_genetic_damage=100, var/max_stat=0)

	if(!src.mind)		return
	if(!iscarbon(src))	return

	var/datum/changeling/changeling = src.mind.changeling
	if(!changeling)
		log_world("[src] has the changeling_transform() verb but is not a changeling.")
		return

	if(src.stat > max_stat)
		to_chat(src, SPAN_WARNING("We are incapacitated."))
		return

	if(changeling.absorbed_dna.len < required_dna)
		to_chat(src, SPAN_WARNING("We require at least [required_dna] samples of compatible DNA."))
		return

	if(changeling.chem_charges < required_chems)
		to_chat(src, SPAN_WARNING("We require at least [required_chems] units of chemicals to do that!"))
		return

	if(changeling.geneticdamage > max_genetic_damage)
		to_chat(src, SPAN_WARNING("Our genomes are still reassembling. We need time to recover first."))
		return

	return changeling


//Used to dump the languages from the changeling datum into the actual mob.
/mob/proc/changeling_update_languages(var/updated_languages)

	languages = list()
	for(var/language in updated_languages)
		languages += language

	//This isn't strictly necessary but just to be safe...
	add_language(LANGUAGE_CHANGELING)

	return

//Absorbs the victim's DNA making them uncloneable. Requires a strong grip on the victim.
//Doesn't cost anything as it's the most basic ability.
/mob/proc/changeling_absorb_dna()
	set category = "Changeling"
	set name = "Absorb DNA"

	var/datum/changeling/changeling = changeling_power(0,0,100)
	if(!changeling)	return

	var/obj/item/weapon/grab/G = src.get_active_hand()
	if(!istype(G))
		to_chat(src, SPAN_WARNING("We must be grabbing a creature in our active hand to absorb them."))
		return

	var/mob/living/carbon/human/T = G.affecting
	if(!istype(T))
		to_chat(src, SPAN_WARNING("[T] is not compatible with our biology."))
		return

	if(T.species.flags & NO_SCAN)
		to_chat(src, SPAN_WARNING("We do not know how to parse this creature's DNA!"))
		return

	if(HUSK in T.mutations)
		to_chat(src, SPAN_WARNING("This creature's DNA is ruined beyond useability!"))
		return

	if(G.state != GRAB_KILL)
		to_chat(src, SPAN_WARNING("We must have a tighter grip to absorb this creature."))
		return

	if(changeling.isabsorbing)
		to_chat(src, SPAN_WARNING("We are already absorbing!"))
		return

	changeling.isabsorbing = 1
	for(var/stage in 1 to 3)
		switch(stage)
			if(1)
				to_chat(src, SPAN_NOTICE("This creature is compatible. We must hold still..."))
			if(2)
				to_chat(src, SPAN_NOTICE("We extend a proboscis."))
				src.visible_message(SPAN_WARNING("[src] extends a proboscis!"))
			if(3)
				var/obj/item/organ/external/affecting = T.get_organ(src.targeted_organ)
				if(!affecting)
					to_chat(src, SPAN_WARNING("It seems [targeted_organ] is not a place to stab our probscis with. We need to find another"))
					return
				to_chat(src, SPAN_NOTICE("We stab [T] with the proboscis."))
				src.visible_message(SPAN_DANGER("[src] stabs [T] with the proboscis!"))
				to_chat(T, SPAN_DANGER("You feel a sharp stabbing pain!"))
				if(affecting.take_damage(39,0,1,0,"large organic needle"))
					T:UpdateDamageIcon()


		if(!do_mob(src, T, 150))
			to_chat(src, SPAN_WARNING("Our absorption of [T] has been interrupted!"))
			changeling.isabsorbing = 0
			return

	to_chat(src, SPAN_NOTICE("We have absorbed [T]!"))
	src.visible_message(SPAN_DANGER("[src] sucks the fluids from [T]!"))
	to_chat(T, SPAN_DANGER("You have been absorbed by the changeling!"))

	T.dna.real_name = T.real_name //Set this again, just to be sure that it's properly set.
	changeling.absorbed_dna |= T.dna
	changeling.chem_charges += 10
	changeling.geneticpoints += 2

	//Steal all of their languages!
	for(var/language in T.languages)
		if(!(language in changeling.absorbed_languages))
			changeling.absorbed_languages += language

	changeling_update_languages(changeling.absorbed_languages)

	//Steal their species!
	if(T.species && !(T.species.name in changeling.absorbed_species))
		changeling.absorbed_species += T.species.name

	if(T.mind && T.mind.changeling)
		if(T.mind.changeling.absorbed_dna)
			for(var/dna_data in T.mind.changeling.absorbed_dna)	//steal all their loot
				if(dna_data in changeling.absorbed_dna)
					continue
				changeling.absorbed_dna += dna_data
				changeling.absorbedcount++
			T.mind.changeling.absorbed_dna.len = 1

		if(T.mind.changeling.purchasedpowers)
			for(var/datum/power/changeling/Tp in T.mind.changeling.purchasedpowers)
				if(Tp in changeling.purchasedpowers)
					continue
				else
					changeling.purchasedpowers += Tp

					if(!Tp.isVerb)
						call(Tp.verbpath)()
					else
						src.make_changeling()

		changeling.chem_charges += T.mind.changeling.chem_charges
		changeling.geneticpoints += T.mind.changeling.geneticpoints
		T.mind.changeling.chem_charges = 0
		T.mind.changeling.geneticpoints = 0
		T.mind.changeling.absorbedcount = 0

	changeling.absorbedcount++
	changeling.isabsorbing = 0

	T.death(0)
	T.Drain()
	return 1


//Change our DNA to that of somebody we've absorbed.
/mob/proc/changeling_transform()
	set category = "Changeling"
	set name = "Transform (5)"

	if (transforming)
		return

	var/datum/changeling/changeling = changeling_power(5,1,0)
	if(!changeling)	return

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)	return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	changeling.chem_charges -= 5
	src.visible_message(SPAN_WARNING("[src] transforms!"))
	changeling.geneticdamage = 30
	src.dna = chosen_dna.Clone()
	src.real_name = chosen_dna.real_name
	src.flavor_text = ""
	src.UpdateAppearance()
	domutcheck(src, null)

	if(isMonkey())
		var/mob/living/carbon/human/H = src // isMonkey TRUE only for human type mobs.
		H.remove_changeling_powers()
		H.transforming = 1
		H.canmove = 0
		H.icon = null
		H.overlays.Cut()
		H.invisibility = 101
		var/atom/movable/overlay/animation = new /atom/movable/overlay( H.loc )
		animation.icon_state = "blank"
		animation.icon = 'icons/mob/mob.dmi'
		animation.master = src
		animation.layer = ABOVE_MOB_LAYER
		flick("monkey2h", animation)
		sleep(48)

		H.transforming = 0
		H.stunned = 0
		H.update_lying_buckled_and_verb_status()
		H.invisibility = initial(invisibility)

		for(var/obj/item/W in src)
			H.drop_from_inventory(W)

		H.set_species(H.species.greater_form)
		to_chat(src, "<B>You are now [H.species.name]. </B>")
		qdel(animation)

		make_changeling()
	else
		src.verbs -= /mob/proc/changeling_transform
		spawn(10)
			src.verbs += /mob/proc/changeling_transform

	return 1


//Transform into a monkey.
/mob/proc/changeling_lesser_form()
	set category = "Changeling"
	set name = "Lesser Form (1)"

	if(HAS_TRANSFORMATION_MOVEMENT_HANDLER(src))
		return

	var/datum/changeling/changeling = changeling_power(1,0,0)
	if(!changeling)	return

	if(src.has_brain_worms())
		to_chat(src, SPAN_WARNING("We cannot perform this ability at the present time!"))
		return

	var/mob/living/carbon/human/H = src

	if(!istype(H) || !H.species.primitive_form)
		to_chat(src, SPAN_WARNING("We cannot perform this ability in this form!"))
		return


	changeling.chem_charges--
	H.remove_changeling_powers()
	H.visible_message(SPAN_WARNING("[H] transforms!"))
	changeling.geneticdamage = 30
	to_chat(H, SPAN_WARNING("Our genes cry out!"))
	var/list/implants = list() //Try to preserve implants.
	for(var/obj/item/weapon/implant/W in H)
		implants += W
	H.monkeyize()
	H.make_changeling()

	return 1

//Transform into a human
/mob/proc/changeling_lesser_transform()
	set category = "Changeling"
	set name = "Transform (1)"

	var/datum/changeling/changeling = changeling_power(1,1,0)
	if(!changeling)	return

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)	return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	var/mob/living/carbon/C = src

	changeling.chem_charges--
	C.remove_changeling_powers()
	C.visible_message(SPAN_WARNING("[C] transforms!"))
	C.dna = chosen_dna.Clone()

	var/list/implants = list()
	for (var/obj/item/weapon/implant/I in C) //Still preserving implants
		implants += I

	C.transforming = 1
	C.canmove = 0
	C.icon = null
	C.overlays.Cut()
	C.invisibility = 101
	var/atom/movable/overlay/animation = new /atom/movable/overlay( C.loc )
	animation.icon_state = "blank"
	animation.icon = 'icons/mob/mob.dmi'
	animation.master = src
	animation.layer = ABOVE_MOB_LAYER
	flick("monkey2h", animation)
	sleep(48)
	qdel(animation)

	for(var/obj/item/W in src)
		C.drop_from_inventory(W)

	var/mob/living/carbon/human/O = new /mob/living/carbon/human( src )
	if (C.dna.GetUIState(DNA_UI_GENDER))
		O.gender = FEMALE
	else
		O.gender = MALE
	O.dna = C.dna.Clone()
	C.dna = null
	O.real_name = chosen_dna.real_name

	for(var/obj/T in C)
		qdel(T)

	O.loc = C.loc

	O.UpdateAppearance()
	domutcheck(O, null)
	O.setToxLoss(C.getToxLoss())
	O.adjustBruteLoss(C.getBruteLoss())
	O.setOxyLoss(C.getOxyLoss())
	O.adjustFireLoss(C.getFireLoss())
	O.stat = C.stat
	for (var/obj/item/weapon/implant/I in implants)
		I.loc = O
		I.implanted = O

	C.mind.transfer_to(O)
	O.make_changeling()
	O.changeling_update_languages(changeling.absorbed_languages)

	qdel(C)
	return 1


//Fake our own death and fully heal. You will appear to be dead but regenerate fully after a short delay.
/mob/proc/changeling_fakedeath()
	set category = "Changeling"
	set name = "Regenerative Stasis (20)"

	var/datum/changeling/changeling = changeling_power(20,1,100,DEAD)
	if(!changeling)	return

	var/mob/living/carbon/C = src
	if(!C.stat && alert("Are we sure we wish to fake our death?",,"Yes","No") == "No")//Confirmation for living changelings if they want to fake their death
		return
	to_chat(C, SPAN_NOTICE("We will attempt to regenerate our form."))

	C.status_flags |= FAKEDEATH		//play dead
	C.update_lying_buckled_and_verb_status()
	C.remove_changeling_powers()

	C.emote("gasp")
	C.tod = stationtime2text()

	spawn(rand(800,2000))
		if(changeling_power(20,1,100,DEAD))
			// charge the changeling chemical cost for stasis
			changeling.chem_charges -= 20

			// restore us to health
			C.revive()

			// remove our fake death flag
			C.status_flags &= ~(FAKEDEATH)

			// let us move again
			C.update_lying_buckled_and_verb_status()

			// re-add out changeling powers
			C.make_changeling()

			// sending display messages
			to_chat(C, SPAN_NOTICE("We have regenerated."))



	return 1


//Boosts the range of your next sting attack by 1
/mob/proc/changeling_boost_range()
	set category = "Changeling"
	set name = "Ranged Sting (10)"
	set desc="Your next sting ability can be used against targets 2 squares away."

	var/datum/changeling/changeling = changeling_power(10,0,100)
	if(!changeling)	return 0
	changeling.chem_charges -= 10
	to_chat(src, SPAN_NOTICE("Your throat adjusts to launch the sting."))
	changeling.sting_range = 2
	src.verbs -= /mob/proc/changeling_boost_range
	spawn(5)	src.verbs += /mob/proc/changeling_boost_range
	return 1


//Recover from stuns.
/mob/proc/changeling_unstun()
	set category = "Changeling"
	set name = "Epinephrine Sacs (45)"
	set desc = "Removes all stuns"

	var/datum/changeling/changeling = changeling_power(45,0,100,UNCONSCIOUS)
	if(!changeling)	return 0
	changeling.chem_charges -= 45

	var/mob/living/carbon/human/C = src
	C.stat = 0
	C.SetParalysis(0)
	C.SetStunned(0)
	C.SetWeakened(0)
	C.lying = 0
	C.update_lying_buckled_and_verb_status()

	src.verbs -= /mob/proc/changeling_unstun
	spawn(5)	src.verbs += /mob/proc/changeling_unstun
	return 1


//Speeds up chemical regeneration
/mob/proc/changeling_fastchemical()
	src.mind.changeling.chem_recharge_rate *= 2
	return 1

//Increases macimum chemical storage
/mob/proc/changeling_engorgedglands()
	src.mind.changeling.chem_storage += 25
	return 1


//Prevents AIs tracking you but makes you easily detectable to the human-eye.
/mob/proc/changeling_digitalcamo()
	set category = "Changeling"
	set name = "Toggle Digital Camoflague"
	set desc = "The AI can no longer track us, but we will look different if examined.  Has a constant cost while active."

	var/datum/changeling/changeling = changeling_power()
	if(!changeling)	return 0

	var/mob/living/carbon/human/C = src
	if(C.digitalcamo)	to_chat(C, SPAN_NOTICE("We return to normal."))
	else				to_chat(C, SPAN_NOTICE("We distort our form to prevent AI-tracking."))
	C.digitalcamo = !C.digitalcamo

	spawn(0)
		while(C && C.digitalcamo && C.mind && C.mind.changeling)
			C.mind.changeling.chem_charges = max(C.mind.changeling.chem_charges - 1, 0)
			sleep(40)

	src.verbs -= /mob/proc/changeling_digitalcamo
	spawn(5)	src.verbs += /mob/proc/changeling_digitalcamo
	return 1


//Starts healing you every second for 10 seconds. Can be used whilst unconscious.
/mob/proc/changeling_rapidregen()
	set category = "Changeling"
	set name = "Rapid Regeneration (30)"
	set desc = "Begins rapidly regenerating.  Does not effect stuns or chemicals."

	var/datum/changeling/changeling = changeling_power(30,0,100,UNCONSCIOUS)
	if(!changeling)	return 0
	src.mind.changeling.chem_charges -= 30

	var/mob/living/carbon/human/C = src
	spawn(0)
		for(var/i = 0, i<10,i++)
			if(C)
				C.adjustBruteLoss(-10)
				C.adjustToxLoss(-10)
				C.adjustOxyLoss(-10)
				C.adjustFireLoss(-10)
				sleep(10)

	src.verbs -= /mob/proc/changeling_rapidregen
	spawn(5)	src.verbs += /mob/proc/changeling_rapidregen
	return 1

// HIVE MIND UPLOAD/DOWNLOAD DNA

var/list/datum/dna/hivemind_bank = list()

/mob/proc/changeling_hiveupload()
	set category = "Changeling"
	set name = "Hive Channel (10)"
	set desc = "Allows you to channel DNA in the airwaves to allow other changelings to absorb it."

	var/datum/changeling/changeling = changeling_power(10,1)
	if(!changeling)	return

	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		if(!(DNA in hivemind_bank))
			names += DNA.real_name

	if(names.len <= 0)
		to_chat(src, SPAN_NOTICE("The airwaves already have all of our DNA."))
		return

	var/S = input("Select a DNA to channel: ", "Channel DNA", null) as null|anything in names
	if(!S)	return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	changeling.chem_charges -= 10
	hivemind_bank += chosen_dna
	to_chat(src, SPAN_NOTICE("We channel the DNA of [S] to the air."))
	return 1

/mob/proc/changeling_hivedownload()
	set category = "Changeling"
	set name = "Hive Absorb (20)"
	set desc = "Allows you to absorb DNA that is being channeled in the airwaves."

	var/datum/changeling/changeling = changeling_power(20,1)
	if(!changeling)	return

	var/list/names = list()
	for(var/datum/dna/DNA in hivemind_bank)
		if(!(DNA in changeling.absorbed_dna))
			names[DNA.real_name] = DNA

	if(names.len <= 0)
		to_chat(src, SPAN_NOTICE("There's no new DNA to absorb from the air."))
		return

	var/S = input("Select a DNA absorb from the air: ", "Absorb DNA", null) as null|anything in names
	if(!S)	return
	var/datum/dna/chosen_dna = names[S]
	if(!chosen_dna)
		return

	changeling.chem_charges -= 20
	changeling.absorbed_dna += chosen_dna
	to_chat(src, SPAN_NOTICE("We absorb the DNA of [S] from the air."))
	return 1

// Fake Voice

/mob/proc/changeling_mimicvoice()
	set category = "Changeling"
	set name = "Mimic Voice"
	set desc = "Shape our vocal glands to form a voice of someone we choose. We cannot regenerate chemicals when mimicing."


	var/datum/changeling/changeling = changeling_power()
	if(!changeling)	return

	if(changeling.mimicing)
		changeling.mimicing = ""
		to_chat(src, SPAN_NOTICE("We return our vocal glands to their original location."))
		return

	var/mimic_voice = sanitize(input(usr, "Enter a name to mimic.", "Mimic Voice", null), MAX_NAME_LEN)
	if(!mimic_voice)
		return

	changeling.mimicing = mimic_voice

	to_chat(src, SPAN_NOTICE("We shape our glands to take the voice of <b>[mimic_voice]</b>, this will stop us from regenerating chemicals while active."))
	to_chat(src, SPAN_NOTICE("Use this power again to return to our original voice and reproduce chemicals again."))


	spawn(0)
		while(src && src.mind && src.mind.changeling && src.mind.changeling.mimicing)
			src.mind.changeling.chem_charges = max(src.mind.changeling.chem_charges - 1, 0)
			sleep(40)
		if(src && src.mind && src.mind.changeling)
			src.mind.changeling.mimicing = ""
	//////////
	//STINGS//	//They get a pretty header because there's just so fucking many of them ;_;
	//////////

/mob/proc/sting_can_reach(mob/M as mob, sting_range = 1)
	if(M.loc == src.loc)
		return 1 //target and source are in the same thing
	if(!isturf(src.loc) || !isturf(M.loc))
		to_chat(src, SPAN_WARNING("We cannot reach \the [M] with a sting!"))
		return 0 //One is inside, the other is outside something.
	// Maximum queued turfs set to 25; I don't *think* anything raises sting_range above 2, but if it does the 25 may need raising
	if(!AStar(src.loc, M.loc, /turf/proc/AdjacentTurfs, /turf/proc/Distance, max_nodes=25, max_node_depth=sting_range)) //If we can't find a path, fail
		to_chat(src, SPAN_WARNING("We cannot find a path to sting \the [M] by!"))
		return 0
	return 1

//Handles the general sting code to reduce on copypasta (seeming as somebody decided to make SO MANY dumb abilities)
/mob/proc/changeling_sting(var/required_chems=0,var/mob/living/carbon/T)//(var/required_chems=0, var/verb_path,var/mob/living/carbon/T)
	if (!ishuman(T) || (T==src))
		T.Click()
		return

	var/datum/changeling/changeling = changeling_power(required_chems)
	if(!changeling)
		return



	if(!T) return
	if(!(T in view(changeling.sting_range)))
		to_chat(src, "<span class='warning'>Too Far</span>")
		return
	if(!sting_can_reach(T, changeling.sting_range)) return
	if(!changeling_power(required_chems)) return

	changeling.chem_charges -= required_chems
	changeling.sting_range = 1
//	src.verbs -= verb_path
//	spawn(10)	src.verbs += verb_path

	to_chat(src, SPAN_NOTICE("We stealthily sting [T]."))
	to_chat(T, SPAN_WARNING("You feel a tiny prick."))
	log_attack("[src] use [src.client.CH.handler_name] on [T]")
	if(!T.mind || !T.mind.changeling)
		return T //T will be affected by the sting
	return

/mob/proc/changeling_prepare_lsdsting()
	set category = "Changeling"
	set name = "Hallucination Sting (15)"
	set desc = "Causes terror in the target."

	check_CH("Hallucination Sting",/datum/click_handler/changeling/changeling_lsdsting)

	return

/mob/proc/changeling_lsdsting(atom/A)
	var/mob/living/carbon/T = changeling_sting(15, A)
	if(!T)	return 0
	spawn(rand(300,600))
		if(T)	T.hallucination(400, 80)
	return 1



/mob/proc/changeling_prepare_silence_sting()
	set category = "Changeling"
	set name = "Silence sting (10)"
	set desc = "Sting target"

	check_CH("Silence Sting",/datum/click_handler/changeling/changeling_silence_sting)

	return

/mob/proc/changeling_silence_sting(atom/A)
	var/mob/living/carbon/T = changeling_sting(10,A)
	if(!T)	return 0
	T.silent += 30
	return 1



/mob/proc/changeling_prepare_blind_sting()
	set category = "Changeling"
	set name = "Blind sting (20)"
	set desc="Sting target"

	check_CH("Blind Sting",/datum/click_handler/changeling/changeling_blind_sting)

	return

/mob/proc/changeling_blind_sting(atom/A)
	var/mob/living/carbon/T = changeling_sting(20,A)
	if(!T)	return 0
	to_chat(T, "<span class='danger'>Your eyes burn horrificly!</span>")
	T.disabilities |= NEARSIGHTED
	spawn(600)	T.disabilities &= ~NEARSIGHTED
	T.eye_blind = 20
	T.eye_blurry = 40
	return 1



/mob/proc/changeling_prepare_deaf_sting()
	set category = "Changeling"
	set name = "Deaf Sting (5)"
	set desc="Sting target"

	check_CH("Deaf Sting",/datum/click_handler/changeling/changeling_deaf_sting)
	return

/mob/proc/changeling_deaf_sting(atom/A)
	var/mob/living/carbon/T = changeling_sting(5,A)
	if(!T)	return 0
	to_chat(T, SPAN_DANGER("Your ears pop and begin ringing loudly!"))
	T.sdisabilities |= DEAF
	spawn(300)	T.sdisabilities &= ~DEAF
	return 1



/mob/proc/changeling_prepare_paralysis_sting()
	set category = "Changeling"
	set name = "Paralysis Sting (30)"
	set desc="Sting target"

	check_CH("Paralysis Sting",/datum/click_handler/changeling/changeling_paralysis_sting)
	return


/mob/proc/changeling_paralysis_sting(atom/A)
	var/mob/living/carbon/T = changeling_sting(30,A)
	if(!T)	return 0
	to_chat(T, SPAN_DANGER("Your muscles begin to painfully tighten."))
	T.Weaken(20)
	return 1





/*/mob/proc/changeling_transformation_sting()
	var/datum/changeling/changeling = changeling_power(40)
	if(!changeling)	return 0

	var/obj/item/weapon/grab/G = src.get_active_hand()
	if(!istype(G))
		to_chat(src, "<span class='warning'>We must be grabbing a creature in our active hand to transform them.</span>")
		return 0
	if(G.state < GRAB_NECK)
		to_chat(src, "<span class='warning'>We must have a tighter grip to transform this creature.</span>")
		return 0



	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)	return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return

	changeling.chem_charges -= 40
	src.verbs -= /mob/proc/changeling_transformation_sting
	spawn(10)	src.verbs += /mob/proc/changeling_transformation_sting

	var/mob/living/carbon/T = G.affecting
	if((HUSK in T.mutations) || (!ishuman(T) && !issmall(T)))
		to_chat(src, SPAN_WARNING("Our sting appears ineffective against its DNA."))
		return 0
	to_chat(src, "<span class='notice'>We stealthily sting [T] in the neck.</span>")
	to_chat(T, "<span class='warning'>You feel a tiny prick.</span>")
	if(!T.mind || !T.mind.changeling)
		T.visible_message("<span class='warning'>[T] transforms!</span>")
		T.dna = chosen_dna.Clone()
		T.real_name = chosen_dna.real_name
		T.UpdateAppearance()
		domutcheck(T, null)
		return 1
	return*/


/mob/proc/changeling_prepare_transformation_sting()
	set category = "Changeling"
	set name = "Transformation Sting (40)"
	set desc="Sting target"

	var/list/names = list()

	if(istype(src.client.CH, /datum/click_handler/changeling/changeling_transformation_sting))
		kill_CH()
		return

	for(var/datum/dna/DNA in mind.changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)
		return

	var/datum/dna/chosen_dna = mind.changeling.GetDNA(S)
	if(!chosen_dna)
		return
	check_CH("Transformation Sting",/datum/click_handler/changeling/changeling_transformation_sting, chosen_dna)

	return

/mob/proc/changeling_transformation_sting(atom/A, datum/dna/chosen_dna)
	var/mob/living/carbon/T = changeling_sting(40,A)
	if(!T)	return 0
/*
	var/list/names = list()
	for(var/datum/dna/DNA in changeling.absorbed_dna)
		names += "[DNA.real_name]"

	var/S = input("Select the target DNA: ", "Target DNA", null) as null|anything in names
	if(!S)	return

	var/datum/dna/chosen_dna = changeling.GetDNA(S)
	if(!chosen_dna)
		return
*/
	if((HUSK in T.mutations) || (!ishuman(T) && !issmall(T)))
		to_chat(src, SPAN_WARNING("Our sting appears ineffective against its DNA."))
		return 0
	T.visible_message(SPAN_WARNING("[T] transforms!"))
	T.dna = chosen_dna.Clone()
	T.real_name = chosen_dna.real_name
	T.UpdateAppearance()
	domutcheck(T, null)

	return 1


/mob/proc/changeling_prepare_DEATHsting()
	set category = "Changeling"
	set name = "Death Sting (40)"
	set desc = "Causes spasms onto death."

	check_CH("Death Sting",/datum/click_handler/changeling/changeling_DEATHsting)
	return

/mob/proc/changeling_DEATHsting(atom/A)
	var/mob/living/carbon/T = changeling_sting(40,A)
	if(!T)	return 0
	to_chat(T, SPAN_DANGER("You feel a small prick and your chest becomes tight."))
	T.silent = 10
	T.Paralyse(10)
	T.make_jittery(1000)
	if(T.reagents)	T.reagents.add_reagent("lexorin", 40)
	return 1


/mob/proc/changeling_prepare_extract_dna_sting()
	set category = "Changeling"
	set name = "Extract DNA Sting (40)"
	set desc="Stealthily sting a target to extract their DNA."

	check_CH("Extract DNA Sting",/datum/click_handler/changeling/changeling_extract_dna_sting)
	return

/mob/proc/changeling_extract_dna_sting(atom/A)
	var/datum/changeling/changeling = null
	if(src.mind && src.mind.changeling)
		changeling = src.mind.changeling
	else
		return 0
//	if(!changeling)
//		return 0

	var/mob/living/carbon/human/T = changeling_sting(40, A)
	if(!T)	return 0

	T.dna.real_name = T.real_name
	changeling.absorbed_dna |= T.dna
	if(T.species && !(T.species.name in changeling.absorbed_species))
		changeling.absorbed_species += T.species.name
	return 1
