
// Speed & Capacity Estimation
Macro "controls" (linearr)
//Input: Vector array of Dir, AB_Lanes, BA_Lanes, and 12-category HPMS functional class
//Impute control type [ImpControl] if {n_signal} missing
//Determine signal/stop priority [Aprio/Bprio] based on lanes and a FC ranking

	shared mvw
	{Dir, AB_Lanes, BA_Lanes, FC, Ramp} = linearr
	{n_signal} = {"SIGNAL"}

	 RunMacro("addfields", mvw.line, {"A_Control", "B_Control", "A_Priority", "B_Priority", "A_Synch", "B_Synch", "PCLASS"}, {"i","i","i","i","i","i","i"})
     RunMacro("addfields", mvw.node, {"Links", "Access", "Control_Imp", "Max_Pclass", "Min_Pclass"}, {"i","i","i","i","i"})

	 // Calculate PCLASS based on number of lanes and functional class
     FCscore = if Ramp = 1 then 2
	    else if (FC=1 | FC=11 | FC=12) then 9
		else if (FC=2 | FC=6 | FC=14) then 8
		else if (FC=7 | FC=16) then 6
		else if (FC=8 | FC=17) then 5
		else if (FC=9 | FC=19) then 3
		else if (FC > 90) then 1
		else 2

	 AvgLanes = if Dir = 1 then AB_Lanes
		 else if Dir = -1 then BA_Lanes
		 else if Dir = 0 then (AB_Lanes + BA_Lanes)/2

     PCLASS = 10 * (AvgLanes + FCscore)
     SetDataVector(mvw.line + "|", "PCLASS", Nz(PCLASS), {{"Sort Order",{{"ID","Ascending"}}}})

     // Create From_Node and To_Node fields & join network+nodes, aggregating to give max(PCLASS) min(PCLASS) max(Access)
     FID = CreateNodeField(mvw.line, "A_Node", mvw.node + ".ID", "From", )
     TID = CreateNodeField(mvw.line, "B_Node", mvw.node + ".ID", "To", )

	 fjoin = JoinViews("fjoin", mvw.node+".ID", mvw.line+"."+FID, {{"A", }, {"Fields", {{"Access", {{"Max"}}}, {"PCLASS", {{"Avg"}, {"Max"}, {"Min"}}}}}})
     {Legs, Access, MaxPC, MinPC} = GetDataVectors(fjoin + "|", {"N "+mvw.line, "High Access","High PCLASS", "Low PCLASS"}, {{"Sort Order",{{mvw.node+".ID","Ascending"}}},{"Missing as Zero", "True"}})
     MinPC = if (MinPC = 0) then 11 else MinPC
     SetDataVectors(mvw.node + "|", {{"Links",Legs},{"Access",Access},{"Max_Pclass",MaxPC},{"Min_Pclass",MinPC}},{{"Sort Order",{{mvw.node+".ID","Ascending"}}}})
     CloseView(fjoin)

	 tjoin = JoinViews("tjoin", mvw.node + ".ID", mvw.line + "." + TID, {{"A", }, {"Fields", {{"Access", {{"Max"}}}, {"PCLASS", {{"Avg"}, {"Max"}, {"Min"}}}}}})
     {TLegs, TAccess, TMaxPC, TMinPC} = GetDataVectors(tjoin + "|", {"N "+mvw.line,"High Access","High PCLASS","Low PCLASS"}, {{"Sort Order",{{mvw.node+".ID","Ascending"}}},{"Missing as Zero", "True"}})
     TMinPC = if (TMinPC = 0) then 11 else TMinPC
     SetDataVectors(mvw.node + "|", {{"Links",TLegs+Legs},{"Access",Max(TAccess,Access)},{"Max_Pclass",Max(TMaxPC,MaxPC)},{"Min_Pclass",Min(TMinPC,MinPC)}},{{"Sort Order",{{mvw.node+".ID","Ascending"}}}})
     CloseView(tjoin)

     // Impute Control Type for Unspecified
	 //Control[0,1,2,3,4,5] = [No Control, Signalized, 2-way-stop (often imputed), null, 4/all-way-stop, roundabout]
     {Control, Access, MaxPC, MinPC, Legs} = GetDataVectors(mvw.node + "|", {n_signal,"Access","Max_Pclass","Min_Pclass","Links"}, {{"Sort Order",{{mvw.node+".ID","Ascending"}}}})
     ImpControl = if (Control <> null) then Control
			else if (Access = 3 or Legs < 3) then 0
			else if (MaxPC = MinPC) then 4
			else 2
     SetDataVector(mvw.node + "|", "Control_Imp", ImpControl, {{"Sort Order",{{"ID","Ascending"}}}})

     // Use node fields to populate A_Control, B_Control, A_Priority, B_Priority, A_Synch, B_Synch
     AC = CreateNodeField(mvw.line, "A_Ctrl", mvw.node + ".Control_Imp", "From", )
     BC = CreateNodeField(mvw.line, "B_Ctrl", mvw.node + ".Control_Imp", "To", )
     AMaxPC = CreateNodeField(mvw.line, "A_MaxPC", mvw.node + ".Max_Pclass", "From", )
     BMaxPC = CreateNodeField(mvw.line, "B_MaxPC", mvw.node + ".Max_Pclass", "To", )
     AMinPC = CreateNodeField(mvw.line, "A_MinPC", mvw.node + ".Min_Pclass", "From", )
     BMinPC = CreateNodeField(mvw.line, "B_MinPC", mvw.node + ".Min_Pclass", "To", )
     {ACtrl, BCtrl, AMaxPC, BMaxPC, AMinPC, BMinPC, SigCoord} = GetDataVectors(mvw.line + "|", {AC,BC,AMaxPC,BMaxPC,AMinPC,BMinPC,"SIGNAL_COO"}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}} )


	 //Link priority at signals/stops - lower APrio/BPrio will have higher priority
     APrio = if (ACtrl = 0) then 0 					//ACtrl = Control_Imp From
		 else if (AMaxPC = AMinPC) then 2 		 		//AMinPC: Lowest Link PCLASS
		 else if (AMaxPC = PCLASS) then 1 			 	//AMaxPC: Highest Link PCLASS
		 else 3
     BPrio = if (BCtrl = 0) then 0
		 else if (BMaxPC = BMinPC) then 2
		 else if (BMaxPC = PCLASS) then 1
		 else 3

	 Sync = if (ACtrl = 1 and BCtrl = 1 and APrio = 1 and BPrio = 1) or (SigCoord = 1) then 1 else 0  //signals on both ends
	 ASync = if (ACtrl = 1 and BCtrl = 2 and APrio = 1 and BPrio = 1) or (Sync = 1) then 1 else 0 //two way stop on B end, but priority
	 BSync = if (ACtrl = 2 and BCtrl = 1 and APrio = 1 and BPrio = 1) or (Sync = 1) then 1 else 0 //two way stop on A end, but priority

    SetDataVectors(mvw.line + "|", {{"A_Control",ACtrl},{"B_Control",BCtrl},{"A_Priority",APrio},{"B_Priority",BPrio},{"A_Synch",ASync},{"B_Synch",BSync}},{{"Sort Order",{{mvw.line+".ID","Ascending"}}}})

	arr = GetExpressions(mvw.line)
	for i = 1 to arr.length do DestroyExpression(mvw.line+"."+arr[i]) end

	RunMacro("dropfields", mvw.node, {"Max_Pclass", "Min_Pclass"})
	RunMacro("dropfields", mvw.line, {"PCLASS"})
Quit:
endMacro

Macro "spdcap" (linearr)
	shared mvw, netparam, tazvec
	rurtwtwladj = 1
	urbtwtwladj = 0
	looprampadj = 10
	sliprampadj = 20

	RunMacro("addfields", mvw.line, {"DIVIDED", "FFSPEED", "FFTIME", "AB_AFFTIME", "BA_AFFTIME", "AB_AFFSPD", "BA_AFFSPD","FACTYPE", "AB_UCDELAY", "BA_UCDELAY", "PKHRLNCAP"}, {"i","r","r","r","r","r","r","c","r","r","i"})
	RunMacro("addfields", mvw.line, {"AB_AMCAP", "BA_AMCAP", "AB_PMCAP", "BA_PMCAP", "AB_OPCAP", "BA_OPCAP", "AB_DLYCAP","BA_DLYCAP"}, {"r","r","r","r","r","r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_BPRA", "BA_BPRA", "AB_BPRB", "BA_BPRB"}, {"r","r","r","r"})

     // ------------ PREPROCESS ------------
     // Read in input data field vectors

	{Leng, Dir, I24_Cal, FC, Access, AB_Lanes, BA_Lanes, Ramp, Median, TAZID, TurnLane, LnWidth, RsWidth, PSpeed, PSpeedAdj, ACtrl, BCtrl, APrio, BPrio, ASync, BSync, auxlane, weavelane, truckclimb, ab_basevol, ba_basevol} = linearr

	PSpeed = if PSpeedAdj <> null then PSpeedAdj else PSpeed

	DirLanes = if Dir = 1 then AB_Lanes
		 else if Dir = -1 then BA_Lanes
		 else if Dir = 0 then (AB_Lanes + BA_Lanes)/2

    //Process input fields
	AreaType2 = if (FC < 10) then -1 else if (FC > 10 and FC < 30) then 1 else 0
	FacType = if (FC = null) then "gis" else													// GIS only non-model links
               if (FC > 97) then "cc" else                            						// Centroid Connectors
               if (FC = 92) then "rndabt2" else                            					// Roundabout (2 lane)
               if (FC = 91) then "rndabt1" else                            					// Roundabout (1 lane)
               if (Ramp = 1) then "ramp" else              										// Ramps
			   if (FC = 1 or FC = 11 or (FC = 12 and Median = 1)) then "fwy" else			// Freeways
			   if (Access = 3 and DirLanes > 1 and Median = 1) then "fwy" else
               if (Dir = 0 and DirLanes = 1 and TurnLane = 1 and Median <> 1) then "tw3l" else     // Two-Way Three-Lane (center left turn lane)
               if (Dir = 0 and DirLanes = 1) then "twtl" else                   					// Two-Way Two-Lane
               if (DirLanes > 1 and Median <> 1) then "twmlu" else  					// Two-Way Multi-Lane Undivided
               if (DirLanes > 1 and Median = 1) then "twmld" else  					// Two-Way Multi-Lane Divided
               if (Dir <> 0 and DirLanes = 1) then "owol" else         							// One-Way One-Lane
               if (Dir <> 0 and DirLanes > 1) then "owml" else         							// One-Way Multi-Lane
               "bad"      																		//Errors

	 Divided = if (FacType = "fwy") or (FacType = "twmld") then 1 else 0
	 SetDataVector(mvw.line + "|", "DIVIDED", Divided, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})

     // ------------ WALK TIME ------------
     WalkTime = if (FacType = "cc") then 60 * Log(Leng + 1) / 3 else if (FacType <> "fwy") then 60 * Leng / 3
     //SetDataVector(mvw.line + "|", "WalkTime", WalkTime, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})

     // ------------ FREE-FLOW SPEED ESTIMATION (neglecting control delay) ------------

	 // SB: Probably from NCHRP 387 and that report is out of print.
     ffspeed = if PSpeed = null then 20 else
			   if (FacType = "owol") then 1/(0.119687-0.023365*Log(PSpeed))+0.373821*PSpeed + netparam.owol.value else
               if (FacType = "owml") then 1/(0.081714-0.016217*Log(PSpeed)) + netparam.owml.value else
               if (FacType = "twtl" and AreaType2 = -1) then 0.009751*Pow(PSpeed,2) + 29.4 - rurtwtwladj + netparam.rtwtl.value else
               if (FacType = "twtl" and AreaType2 = 1) then 6.6 + 0.9437*PSpeed - urbtwtwladj + netparam.utwtl.value else
               if (FacType = "tw3l") then 1/(0.119687-0.023365*Log(PSpeed)) + 0.373821*PSpeed + netparam.tw3l.value else
               if (FacType = "twmlu" and AreaType2 = -1) then 3.6*Pow(PSpeed,0.857638) -113*Exp(-41.803252/PSpeed) + netparam.rtwmlu.value else
               if (FacType = "twmlu" and AreaType2 = 1) then 3.0*Pow(PSpeed,0.857638) -75*Exp(-41.803252/PSpeed) + netparam.utwmlu.value else
               if (FacType = "twmld" and AreaType2 = -1 and Access = 3) then 9 + 0.95*PSpeed + netparam.rtwmld.value else
               if (FacType = "twmld" and AreaType2 = 1 and Access = 3) then 1/(0.081714-0.016217*Log(PSpeed)) + netparam.utwmld.value else
               if (FacType = "twmld" and Access = 2) then 0.009*Pow(PSpeed,2) + 35 + netparam.patwmld.value else
               if (FacType = "fwy") then -0.0175*Pow(PSpeed,2) + 2.75*PSpeed - 33.5 + netparam.fwy.value else
			   if (FacType = "ramp") then 12.4892 + 1.3776*PSpeed -0.0061*Pow(PSpeed,2) + netparam.ramp.value else
			   if (FacType = "local") then 1.1 * PSpeed else 1.1 * PSpeed

     // For Centroid Connectors base free-flow time (and speed) on zone size
     jnvw = JoinViews(mvw.line + " + " + mvw.taz, mvw.line + ".TAZID", mvw.taz + ".TAZID", )
     {TAZarea} = GetDataVectors(jnvw + "|", {"Area"}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}} )
     TAZrad = nz(Sqrt(TAZarea/3.14159))
     ffspeed = if (FacType = "cc") then max(45, 20 + 20*log(TAZrad+1)) else ffspeed
     fftime =  if (FacType = "cc") then 60*max(TAZrad,Leng)/ffspeed else 60*Leng/ffspeed

     SetDataVectors(mvw.line + "|", {{"FFSPEED",ffspeed},{"FFTIME",fftime}}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})
     CloseView(jnvw)

     // ------------ INITIAL CAPACITY ESTIMATION (based on HCM 2000, neglecting control delay) ------------
	 // ------------ See SB notes for comparison to HCM 2010 ------------

     CapType = if (FacType = "cc") then "cc" else
               if (FacType = "fwy" | FacType = "ramp") then "fwy" else
			   if (FacType = "rndabt2" | FacType = "rndabt1") then "rndabt" else
			   if (FacType = "gis") then "gis" else
               if (FacType = "owol" or FacType = "twtl" or FacType = "tw3l") then "twy" else "multi"

     IdealCap = if (CapType = "cc") then 20000 else                           // ideal LOS E capacity in pc/hr/ln
                if (CapType = "twy") then 1700 else
				if (CapType = "rndabt" and FacType = "rndabt2") then 1000 else
				if (CapType = "rndabt" and FacType = "rndabt1") then 1300 else
                if (CapType = "multi" and ffspeed < 50) then 1900 else     // HCM 2000 Exhibit 21-2
                if (CapType = "multi" and ffspeed < 55) then 2000 else		// SB: This is the same in HCM 2010 in Exhibit 14-4. Capacity is not given but it is speed*max density for LOS E
                if (CapType = "multi" and ffspeed < 60) then 2100 else
                if (CapType = "multi") then 2200 else
				if (Ramp = 1 and PSpeed < 40) then 1700 else
                if (CapType = "fwy" and ffspeed < 60) then 2250 else       // HCM 2000 Exhibit 23-2
                if (CapType = "fwy" and ffspeed < 65) then 2300 else		// SB: This is the same in HCM 2010. Not a table any more but written in first para under "Capacity under base condition".
                if (CapType = "fwy" and ffspeed < 70) then 2350 else
                if (CapType = "fwy") then 2400 else 1

     SWidth = if (RsWidth < 2 or RsWidth = null) then 2 else if (RsWidth > 6) then 6 else RsWidth    // Shoulder Width
     LWidth = if (LnWidth < 9) then 9 else if (LnWidth > 12) then 12 else if (LnWidth = null) then 11 else LnWidth      // Lane Width

     // Source: NCHRP Report 599, Table 15, HVFrac for Indiana
	 // SB: Get values for Tennessee from Table 15 in NCHRP 599. Areatype = -1 is rural and 1 is urban.
	 // http://onlinepubs.trb.org/onlinepubs/nchrp/nchrp_rpt_599.pdf
     HVFrac =  if ((FacType = "twtl" or FacType = "tw3l" or FacType = "owol") and AreaType2 = -1) then 0.05 else
               if ((FacType = "twtl" or FacType = "tw3l" or FacType = "owol") and AreaType2 = 1) then 0.04 else
               if (AreaType2 = -1) then 0.06 else
               if (AreaType2 = 1) then 0.04 else 0.04

	 AccPts =  if (FacType = "fwy" | FacType = "ramp") then 0 else
               if (Access = 2) then 2.5 else
               if (AreaType2 = -1) then 10 else
               if (AreaType2 = 1) then 25 else 16

     DFactor = if (AreaType2 = -1) then 0.55 else 0.5		//SB: See use of f_d below.

     // adjustment for right-shoulder lateral clearance (f_w), HCM 2000 Exhibit 23-5, Exhibit 21-5
	 // SB: Comparing to HCM 2010, these tables are the same for f_w -- Exhibit 11-9 and 14-9
     f_w = if (CapType = "fwy" and DirLanes < 3) then min(1,max(0.9345,((-6.00001+SWidth)/(0.00010+1.66667*ffspeed)+1))) else
           if (CapType = "fwy" and DirLanes = 3) then min(1,max(0.9564,((-5.99999+SWidth)/(-0.00084+2.50001*ffspeed)+1))) else
           if (CapType = "fwy" and DirLanes = 4) then min(1,max(0.9782,((-6.00001+SWidth)/(-0.00002+5*ffspeed)+1))) else
           if (CapType = "fwy" and DirLanes >= 5) then min(1,max(0.9891,((-6.00002+SWidth)/(0.00371+9.99994*ffspeed)+1))) else
           if (CapType = "multi" and DirLanes < 6) then min(1,max(0.8800,((1095.74797+ffspeed)/(1280.33942+6.53454*Pow(SWidth, 2))+0.03975*SWidth))) else
           if (CapType = "multi") then min(1,max(0.9133,(((1485.43810+ffspeed)/(1660.34815+3.09810*Pow(SWidth, 2))+0.02166*SWidth))))

     // adjustment for heavy vehicles (f_hv)
	 // SB: Equation for f_HV remains the same in HCM 2010 assuming TN also has ROLLING terrain
     f_hv = 1 / (1 + 0.5 * HVFrac)

     // adjustment for driver factor (f_p)
	 // SB: Sill = 1.0 for familiar users in HCM 2010
     f_p = if (FacType <> "gis") then 1.00      // default from NCHRP Reports 387 & 599

     // adjustment for lane width (f_lw), HCM 2000 Exhibits 21-4 and 23-4
	 // SB: Comparing to HCM 2010, these tables are the same for f_lw -- Exhibit 14-8 and 11-8
     f_lw =    if (LWidth = 12) then 1.0000 else
               if (LWidth = 11) then 0.9708 else
               if (LWidth < 11) then 0.8985

     // adjustment for lane and shoulder widths (f_ls), HCM 2000 Exhibit 20-5
	 // SB: Comparing to HCM 2010, this table is the same for f_ls -- Exhibit 15-7
     f_ls =    if (SWidth < 4) then min(1, max(0.8800,1.43621*Pow(ffspeed, (0.26354-0.09366*log(LWidth)))-8.06484/LWidth)) else
               if (SWidth < 6) then min(1, max(0.9125,1.58362*Pow(ffspeed, (0.24881-0.09472*log(LWidth)))-8.34158/LWidth)) else
               if (LWidth = 9) then 0.9537 else
               if (LWidth = 10) then 0.9768 else
               if (LWidth = 11) then 0.9916 else
               if (LWidth = 12) then 1.0000

     // adjustment for number of lanes (f_n), HCM 2000 Exhibit 23-6
	 // SB: This factor is NOT used in HCM 2010
     f_n =     if (CapType = "fwy") then 1.0000 else
               if (DirLanes < 3) then 0.9308 else
               if (DirLanes = 3) then 0.9538 else
               if (DirLanes = 4) then 0.9769 else 1.0000

     // adjustment for interchange density (f_id)
	 // SB: in HCM 2010, this factor is replaced by Total Ramp Density (TRD). In 2000, this was # of interchanges with at least one on-ramp in 3 miles up and 3 miles down from the midpoint
	 // Now this number of ramps (on and off, one direction) within the same 3 miles up and 3 miles down from the mid-point.
	 // ALSO the use of the factor has changed. It was simply (-fID) before. Now it is (-3.22(TRD)^0.84)
     f_id = if (FacType <> "gis") then 1.00

     // adjustment for median type (f_m), HCM 2000 Exhibit 21-6
	 // SB: Comparing to HCM 2010, this table is the same for f_m -- Exhibit 14-10
     f_m = if (Divided = 1 or FacType = "owol" or FacType = "owml") then 1.0000 else 0.9695

     // adjustment for access points (f_a), HCM 2000 Exhibits 21-7, 20-6
	 // SB: Comparing to HCM 2010, these tables are the same for f_lw -- Exhibit 14-11 and 15-8
     f_a = if (AreaType2 = -1) then 1.0000 else
		   if (CapType = "multi") then min(1, max(0.8333, 1.07209-0.00481*AccPts-3.75/ffspeed)) else
		   if (CapType = "twy" and FacType = "tw3l") then min(1, max(0.8125, 1.07984-0.00266*AccPts-3.75/ffspeed)) else
		   if (CapType = "twy") then min(1, max(0.8125, 1.07984-0.00532*AccPts-3.75/ffspeed))
		   else 1.0000

     // adjustment for directional distribution (f_d), NCHRP Report 387
	 // SB: Comparing to HCM 2010, factor has changed significantly. See equation 15-9 when compared to equation 20-6 in HCM 2000
	 // SB: The actual equation came from NCHRP 387 (http://www.fhwa.dot.gov/environment/air_quality/conformity/research/sample_methodologies/emismeth07.cfm)
     f_d = min(1, max(0.826,0.71+0.58*(1-DFactor)))

	//adjustment for weave lanes
	f_weave = if weavelane = 0 or weavelane = null then 1.00 else
			  if DirLanes >= 5 then 0.66 else
			  if DirLanes >= 4 then 0.73 else
			  if DirLanes >= 3 then 0.80 else
			  if DirLanes >= 2 then 0.88

	//adjustment for auxiliary lanes (set as a half-lane capacity)
	f_aux = if auxlane = 0 or auxlane = null then 1.00 else (DirLanes-0.5)/DirLanes

	//adjustment for truck-climbing lanes (default grade of 4.4)
	Grade = 0.044 //average grade of truck-climbing lanes
	HV = 0.10 //heavy vehicle share
	DFR = 0.10*(nz(ab_basevol) + nz(ba_basevol)) //directional flow rate, 10% assumption

	f_tcl = if (truckclimb = 0 or truckclimb = null) then 1.00 else
			if (CapType = "fwy") then Min(1, 1.140849 - 2.33864 * Pow(Grade,1.095345) - 0.68344 * Pow(HV, 0.53738)) else	//.866153
			if (FC = 2 or FC = 6 or FC = 14 or FC = 16) then Min(Min(0.979500 - 7.822222*Grade + 0.0003343*DFR, 0.9586720 + 0.783068*Grade -0.0000256*DFR),1) else
			if (FC = 7 or FC = 8 or FC = 9 or FC = 17 or FC = 19) then Min(1 , 0.9586720 + 0.783068*Grade - 0.0000256*DFR)
			else 1.00

     // Peak Hour Capacity per Lane (neglecting intersections)
	 // SB: Will need to edit based on missing factors
     pkhrlncap =    if (FacType = "ramp" and DirLanes < 2) then 1000 else
                    if (CapType = "fwy") then IdealCap * f_w * f_hv * f_p * f_lw * f_n * f_id * f_weave * f_aux * f_tcl else
                    if (CapType = "multi") then IdealCap * f_w * f_hv * f_p * f_lw * f_m * f_a * f_weave * f_aux * f_tcl else
                    if (CapType = "twy") then IdealCap * f_ls * f_hv * f_p * f_d * f_a * f_weave * f_aux * f_tcl else
                    if (CapType = "cc" | CapType = "rndabt") then IdealCap

     SetDataVectors(mvw.line + "|", {{"PKHRLNCAP",pkhrlncap}}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})

     // ------------ UNIFORM CONTROL DELAY (based on HCM 2000) ------------

     clength = if (ACtrl = 1 or BCtrl = 1) then netparam.CLEN.value     // assume cycle length 90 sec. for all signals

     // assume green time ratio based on relative priority of approach (high, medium, low)
	 // SB: Used in calculating PF which has changed slightly in HCM 2010. See below for more.
     ab_pgreen = if (BCtrl=1 & BPrio=1) then netparam.HIGC.value else if (BCtrl=1 & BPrio=2) then 0.50 else if (BCtrl=1 & BPrio=3) then 1 - netparam.HIGC.value
     ba_pgreen = if (ACtrl=1 & APrio=1) then netparam.HIGC.value else if (ACtrl=1 & APrio=2) then 0.50 else if (ACtrl=1 & APrio=3) then 1 - netparam.HIGC.value

     // progression factors for signal synchronization from Exhibit 16-12
	 // SB: PF is probably not being used in HCM 2010. the new equation now is d = d1 + d2 + d3 .. Eq 18-19
	 // SB: Exhibit 16-12 from HCM 2000 is not present in HCM 2010, so I think we should make default value of PF = 1
	 // sites.kittelson.com/hcqs-urbanst/Uploads/Download/5861 ... this talks a little about just a few changes in PF but I cant find the same in HCM 2010
     ab_pfactor =  if (BCtrl=1 & BPrio=1 & BSync = 1) then netparam.HIPF.value * netparam.MDPF.value * netparam.LOPF.value else      // could go to zero, 0.333, 0.256
                    if (BCtrl=1 & BPrio=2 & BSync = 1) then netparam.MDPF.value * netparam.LOPF.value else
                    if (BCtrl=1 & BPrio=3 & BSync = 1) then netparam.LOPF.value else
                    if (BCtrl = 1) then 1.000
     ba_pfactor =  if (ACtrl=1 & APrio=1 & ASync = 1) then netparam.HIPF.value * netparam.MDPF.value * netparam.LOPF.value else
                    if (ACtrl=1 & APrio=2 & ASync = 1) then netparam.MDPF.value * netparam.LOPF.value else
                    if (ACtrl=1 & APrio=3 & ASync = 1) then netparam.LOPF.value else
                    if (ACtrl = 1) then 1.000

     // calculate delay for each approach, based on Eqs. 16-9, 16-11, 17-38, 17-55
	// SB: The corresponding equations are Eqs. 18-19, 18-20, 19-64 and 20-30
	// SB: Methodology for two-way and all-way stop controlled intersections is the same
	//SB: So here I think we only need to adjust the value of PF
    ab_cdelay =    if (Access = 3 and FacType <> "ramp") then 0 else
                    if (BCtrl = 1) then ((0.5 * clength * Pow(1 - ab_pgreen, 2) + netparam.SGAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5)) * ab_pfactor)/60 else
                    if (BCtrl = 2 & BPrio > 2) then (netparam.STPD.value + netparam.STAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5))/60 else
                    if (BCtrl = 4) then (netparam.STPD.value + netparam.STAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5))/60 else
					if (BCtrl = 5 or CapType = "rndabt") then (netparam.STAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5))/60 else 0

	ba_cdelay =    if (Access = 3 and FacType <> "ramp") then 0 else
                    if (ACtrl = 1) then ((0.5 * clength * Pow(1 - ba_pgreen, 2) + netparam.SGAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5)) * ba_pfactor)/60 else
                    if (ACtrl = 2 & APrio > 2) then (netparam.STPD.value + netparam.STAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5))/60 else
                    if (ACtrl = 4) then (netparam.STPD.value + netparam.STAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5))/60 else
					if (ACtrl = 5 or CapType = "rndabt") then (netparam.STAD.value*((ffspeed*5280/3600)/10 + (ffspeed*5280/3600)/5))/60 else 0

     // adjusted travel time and speed
     ab_afftt =     if (FacType = "cc") then fftime else fftime + ab_cdelay
	 ba_afftt =     if (FacType = "cc") then fftime else fftime + ba_cdelay
	 ab_affspd =    if (FacType = "cc") then ffspeed else 60 * Leng / ab_afftt
	 ba_affspd =    if (FacType = "cc") then ffspeed else 60 * Leng / ba_afftt


     // calculate capacity adjustment
     ab_spdratio = max(0.25, ab_affspd / ffspeed)
     ba_spdratio = max(0.25, ba_affspd / ffspeed)
     ab_f_delay = min(1,(-460 + 745*log(ab_spdratio*ffspeed))/(-460 + 745*log(ffspeed)))
     ba_f_delay = min(1,(-460 + 745*log(ba_spdratio*ffspeed))/(-460 + 745*log(ffspeed)))

     // adjusted peak hour lane capacities
     // ab_pkhrlncap = nz(pkhrlncap) * ab_f_delay
     // ba_pkhrlncap = nz(pkhrlncap) * ba_f_delay

     // peak hour capacities  Ajust capacity on I24 --YS
     ab_pkhrlncap = if (I24_Cal = 1) then 1.3*nz(pkhrlncap)*ab_f_delay else
                    if (I24_Cal = 2) then 1.6*nz(pkhrlncap)*ab_f_delay else nz(pkhrlncap)*ab_f_delay
     ba_pkhrlncap = if (I24_Cal = 1) then 1.3*nz(pkhrlncap)*ba_f_delay else
                    if (I24_Cal = 2) then 1.6*nz(pkhrlncap)*ba_f_delay else nz(pkhrlncap)*ba_f_delay

     // peak hour capacities
     ab_pkcap = AB_Lanes * ab_pkhrlncap
     ba_pkcap = BA_Lanes * ba_pkhrlncap


     // ------------ OFF PEAK CAPACITY ------------
	 // SB: This comes from work done in Indiana in 2004
	 // www.in.gov/indot/files/memorandum(1).pdf

     // inverse k factors for capacity inflation

	 invkfact =     if (CapType = "fwy") then 11.36
                    else if (AreaType2 = 1) then 10.86
                    else if (AreaType2 < 1 or FacType = "cc") then 10

     // Period capacities
	 AB_AMCap = max(1, AB_Lanes * ab_pkhrlncap * 2.8)
     BA_AMCap = max(1, BA_Lanes * ba_pkhrlncap * 2.8)
	 AB_PMCap = max(1, AB_Lanes * ab_pkhrlncap * 2.9)
     BA_PMCap = max(1, BA_Lanes * ba_pkhrlncap * 2.9)
	 AB_DlyCap = max(1, AB_Lanes * ab_pkhrlncap * invkfact)
     BA_DlyCap = max(1, BA_Lanes * ba_pkhrlncap * invkfact)
	 AB_OPCap = max(1,AB_DlyCap - (AB_AMCap + AB_PMCap))
	 BA_OPCap = max(1,BA_DlyCap - (BA_AMCap + BA_PMCap))

     //RunMacro("addfields", mvw.line, {"AB_PkHrLnCap", "BA_PkHrLnCap"}, {r, r})
     //RunMacro("addfields", mvw.line, {"AB_PkPrCap", "BA_PkPrCap"}, {r, r})
	 //SetDataVectors(mvw.line + "|", {{"AB_PkHrLnCap",ab_pkhrlncap}, {"BA_PkHrLnCap",ba_pkhrlncap},{"AB_PkPrCap",ab_pkprcap}, {"BA_PkPrCap",ba_pkprcap}}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})

	SetDataVectors(mvw.line + "|", {{"AB_AFFTIME",ab_afftt}      , {"BA_AFFTIME",ba_afftt},
									{"AB_AFFSPD" ,ab_affspd}     , {"BA_AFFSPD" ,ba_affspd}    ,
									{"AB_UCDELAY",ab_cdelay}     , {"BA_UCDELAY",ba_cdelay}    ,
									{"AB_AMCAP"  ,AB_AMCap}      , {"BA_AMCAP"  ,BA_AMCap}     ,
									{"AB_PMCAP"  ,AB_PMCap}      , {"BA_PMCAP"  ,BA_PMCap}     ,
									{"AB_OPCAP"  ,AB_OPCap}      , {"BA_OPCAP"  ,BA_OPCap}     ,
									{"AB_DLYCAP" ,AB_DlyCap}     , {"BA_DLYCAP" ,BA_DlyCap}}   ,
								     {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})


     // ------------ VOLUME DELAY FUNCTION PARAMETERS ------------
	 // ------------ SB: Stuff below here is not related to HCM thus remains the same ------------

     // Bureau of Public Roads VDF
	 ab_bprA =      if (FacType = "cc") then 0.15 else                     // centroid connectors
                    if (FacType = "fwy") then netparam.FWYA.value else                    // freeway segments
                    if (FacType = "ramp") then netparam.PACA.value else                    // ramps
                    if (Access = 2) then netparam.PACA.value else                         // partial access control
                    if (BCtrl = 1) then netparam.SIGA.value else                           // signal controlled
                    if (BCtrl > 1 and ab_cdelay > 0) then netparam.STPA.value else         // stop controlled
                    if (ab_cdelay = 0) then netparam.OTHA.value                           // other uninterrupted
     ab_bprB =      if (FacType = "cc") then 4.0 else                      // centroid connectors
                    if (FacType = "fwy") then netparam.FWYB.value else                     // freeway segments
                    if (FacType = "ramp") then netparam.PACB.value else                    // ramps
                    if (Access = 2) then netparam.PACB.value else                         // partial access control
                    if (BCtrl = 1) then netparam.SIGB.value else                           // signal controlled
                    if (BCtrl > 1 and ab_cdelay > 0) then netparam.STPB.value else         // stop controlled
                    if (ab_cdelay = 0) then netparam.OTHB.value                            // other uninterrupted
     ba_bprA =      if (FacType = "cc") then 0.15 else                     // centroid connectors
                    if (FacType = "fwy") then netparam.FWYA.value else                    // freeway segments
                    if (FacType = "ramp") then netparam.PACA.value else                    // ramps
                    if (Access = 2) then netparam.PACA.value else                         // partial access control
                    if (ACtrl = 1) then netparam.SIGA.value else                           // signal controlled
                    if (ACtrl > 1 and ba_cdelay > 0) then netparam.STPA.value else         // stop controlled
                    if (ba_cdelay = 0) then netparam.OTHA.value                           // other uninterrupted
     ba_bprB =      if (FacType = "cc") then 4.0 else                      // centroid connectors
                    if (FacType = "fwy") then netparam.FWYB.value else                     // freeway segments
                    if (FacType = "ramp") then netparam.PACB.value else                    // ramps
                    if (Access = 2) then netparam.PACB.value else                         // partial access control
                    if (ACtrl = 1) then netparam.SIGB.value else                           // signal controlled
                    if (ACtrl > 1 and ba_cdelay > 0) then netparam.STPB.value else         // stop controlled
                    if (ba_cdelay = 0) then netparam.OTHB.value                            // other uninterrupted

     SetDataVectors(mvw.line + "|", {{"FACTYPE",FacType}, {"AB_BPRA",ab_bprA}, {"BA_BPRA",ba_bprA}, {"AB_BPRB",ab_bprB}, {"BA_BPRB",ba_bprB}}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}})

	 //RunMacro("dropfields", mvw.line, {"A_Control", "B_Control", "A_Priority", "B_Priority", "A_Synch", "B_Synch"})
Quit:
endMacro



//Skim & TAZ Calculations
Macro "nmskim_setup"
shared mvw
shared skim

// Create .net file & skim length
	tempnet = GetTempFileName(".net")
	SetView(mvw.line)
	walknetwork = CreateNetwork("Walk", tempnet,, {{"length", {mvw.line+".Length",mvw.line+".Length",,,"False"}}} ,, )
	ChangeNetworkSettings(walknetwork, {{"Use Centroids", "True"}, {"Centroids Set", mvw.node + "|" + "Centroids"}})

skimx = null
skimx.net = tempnet
skimx.origin = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
skimx.destination = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
skimx.set = {mvw.linefile+"|"+mvw.node, mvw.node}
skimx.minlst = {"length"}
skimx.nodes = mvw.node+".ID"
skimx.flds = {null}
skimx.out = skim.nm
skimx.Centroid_ID_is_TAZID = 0	//[1(centroid ID matches TAZID); 0(TAZID as node field)]
skimx.Centroid_TAZID_fld = "TAZID"


intra.skim 		= skimx.out
intra.flds      = {"length"}	//must match [skim.minlst] or as "[skim.flds] (skim)"
intra.factor    = 1 //factor applied to average of neighbors
intra.neighbors = 3
intra.operation = 1 //[1(replace values); 2(add values)]
intra.missing   = 2 //[1(missing=0); 2(missing=null)]

RunMacro("skim", skimx)
RunMacro("intrazonal", intra)

 // calculate walk times from lengths
	nmskimmat = OpenMatrix(skimx.out, "Auto")
	 mcwt = RunMacro("CheckMatrixCore", nmskimmat, "WalkTime", null, null)
     mclen = CreateMatrixCurrency(nmskimmat, "length", "Origin", "Destination",)
     mcwt := 60 * mclen / 2.5

//Add PctSidewalk to TAZ
     RunMacro("addfields", mvw.taz, {"StreetMi", "SidewalkMi"}, {"r","r"})

	 // Compute Overlay to get miles of roadway & sidewalk within each TAZ
	 SetView(mvw.taz)
     ColumnAggregate(mvw.taz+"|", 0.1, mvw.line+"|AllStreet", {{"StreetMi", "Sum", "Length", }}, null)
     SetView(mvw.line)
     ColumnAggregate(mvw.taz+"|", 0.1, mvw.line+"|Walk", {{"SidewalkMi", "Sum", "Length", }}, null)

     datavs = GetDataVectors(mvw.taz + "|", {"SidewalkMi", "StreetMi"}, {{"Sort Order",{{"ID","Ascending"}}}} )
     PctSdwlk = nz(datavs[1])/nz(datavs[2])
     SetDataVector(mvw.taz + "|", "PctSdwlk", PctSdwlk, {{"Sort Order",{{"ID","Ascending"}}}})
	 RunMacro("dropfields", mvw.node, {"StreetMi", "SidewalkMi"})

endMacro

Macro "skim_setup" (netfile, outskim, tod)
shared mvw, info

//Skims
	skimx = null
	skimx.net = netfile
	skimx.origin = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
	skimx.destination = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
	skimx.set = {mvw.linefile+"|"+mvw.node, mvw.node}
	skimx.min = "gctta"
	skimx.nodes = mvw.node+".ID"
	skimx.flds = {{"Length","All"}, {"AFFTime","All"}, {"riverx", "All"}}
	if info.iter > 0 then skimx.flds = {{"Length","All"}, {"AFFTime","All"}, {"riverx", "All"}, {"CTime","All"}}
	if tod = "AM" then skimx.flds = {{"Length","All"}, {"AMTime","All"}, {"riverx", "All"}, {"CTime","All"}}
	if tod = "PM" then skimx.flds = {{"Length","All"}, {"PMTime","All"}, {"riverx", "All"}, {"CTime","All"}}
	if tod = "OP" then skimx.flds = {{"Length","All"}, {"OPTime","All"}, {"riverx", "All"}, {"CTime","All"}}

	skimx.out = outskim
	skimx.Centroid_ID_is_TAZID = 0	//[1(centroid ID matches TAZID); 0(TAZID as node field)]
	skimx.Centroid_TAZID_fld = "TAZID"

	RunMacro("skim", skimx)
	skimmtx = OpenMatrix(skimx.out, "True")

//Add other minimized fields to skim
	skimx.minlst = {"gctts", "gcttm"}
	for i = 1 to skimx.minlst.length do
		tempmtx = GetTempFileName(".mtx")
		skimx.min = skimx.minlst[i]
		skimx.flds = {null}
		skimx.out = tempmtx
		RunMacro("skim", skimx)

		tempmat = OpenMatrix(tempmtx, "Auto")
		tempout = RunMacro("CheckMatrixCore", tempmat, skimx.min, "Origin", "Destination")
		mcout = RunMacro("CheckMatrixCore", skimmtx, skimx.min, "Origin", "Destination")
		mcout := tempout
	end

//Intrazonals
	intra.skim 		= outskim
	intra.flds      = {"gctta", "gctts", "gcttm", "Length (Skim)", "AFFTime (Skim)", "riverx (Skim)"}	//if minimized then "skim.field" or as "[skim.fld] (skim)"
	if info.iter > 0 then intra.flds      = {"gctta", "gctts", "gcttm", "Length (Skim)", "AFFTime (Skim)", "riverx (Skim)", "CTime (Skim)"}	//if minimized then "skim.field" or as "[skim.fld] (skim)"
	if tod = "AM" then intra.flds      = {"gctta", "gctts", "gcttm", "Length (Skim)", "riverx (Skim)", "AMTime (Skim)", "CTime (Skim)"}
	if tod = "PM" then intra.flds      = {"gctta", "gctts", "gcttm", "Length (Skim)", "riverx (Skim)", "PMTime (Skim)", "CTime (Skim)"}
	if tod = "OP" then intra.flds      = {"gctta", "gctts", "gcttm", "Length (Skim)", "riverx (Skim)", "OPTime (Skim)", "CTime (Skim)"}
	intra.factor    = .25 //factor applied to average of neighbors
	intra.neighbors = 1
	intra.operation = 1 //[1(replace values); 2(add values)]
	intra.missing   = 2 //[1(missing=0); 2(missing=null)]

	RunMacro("WriteLog", "Calculating Intrazonals")
	RunMacro("intrazonal", intra)


//Matrix index change
	if tod = null then do
		RunMacro("WriteLog", "Index Change")
		SetView(mvw.node)
		tazset = SelectByQuery("tazset", "Several", "Select * where TAZID > 0",)
		TAZID = CreateMatrixIndex("TAZID", skimmtx, "Both", mvw.node+"|tazset", "ID", "TAZID")

	end
endMacro

//TAZ Variables
Macro "DScalc" (vecarray)
     shared mvw, skim
	 shared dsparam

	 //{HH, EMP, UNIV, SCHL, RET, SRVC} = vecarray

	if dsparam.length <> vecarray.length then throw("DSCalc: Array Length Mismatch")

	{AllActs, sqprob, rcprob} = {0, 0, 0}
	dim acts[vecarray.length]
	dim prob[vecarray.length]
	dim probT[vecarray.length]

	for i=1 to vecarray.length do
		acts[i] = dsparam[i][2].value*vecarray[i]
		AllActs = AllActs + acts[i]
	end

	for i=1 to vecarray.length do
		prob[i] = acts[i]/AllActs
		probT[i] = CopyVector(prob[i])

		sqprob = sqprob + Pow(prob[i],2)
		rcprob = rcprob + prob[i]*probT[i]
	end

	ActDiv = 1 - sqprob
    SetDataVectors(mvw.taz+"|", {{"TotActs", AllActs}, {"ACTDIV", nz(ActDiv)}}, {{"Sort Order",{{"ID","Ascending"}}}})

	if GetFileInfo(skim.default) <> null then do
		impmat = OpenMatrix(skim.default, "Auto")
		mcd = RunMacro("CheckMatrixCore", impmat, "D", "Origin", "Destination")
		mcs = RunMacro("CheckMatrixCore", impmat, "S", "Origin", "Destination")

		FixEmpty = if (AllActs = 0) then 0.5 else 0
		FixEmpty.rowbased = false
		mcd := 1 - FixEmpty - nz(rcprob)
		mcs := 1 - mcd
	end

endMacro

Macro "PctNearBus"
     shared thepath, mvw, busfile

	 tmpbandfile = GetTempFileName(".dbd")
	 buslayer = RunMacro("AddLayer", busfile, "Line")
     SetLayer(buslayer)

	 // Create a half-mile band around the bus lines
     CreateBuffers(tmpbandfile, "Busline Bands", { }, "Value", {.5}, {{"Exterior", "Merged"}, {"Interior", "Merged"}, {"Preprocess", "True"}})
     bandlayer = AddLayer(null, "busbands", tmpbandfile, "Busline Bands")

	 // Compute Overlay to get Area within half-mile of bus
     SetLayer(mvw.taz)
     ColumnAggregate(mvw.taz+"|", 0, bandlayer+"|", {{"PctNearBus", "Sum", "Area", }}, null)

     // Compute Percent of TAZ Area within half-mile of bus
     rec = GetFirstRecord(mvw.taz + "|", null)
     while rec <> null do
          mvw.taz.PctNearBus = mvw.taz.PctNearBus / mvw.taz.Area
          rec = GetNextRecord(mvw.taz + "|", null, null)
     end

     // Drop Bus Layers, Delete Bands
     DropLayer( , buslayer)
     DropLayer( , bandlayer)
endMacro

Macro "IntrsctnDens"
	shared mvw
	//mvw.taz =
	//mvw.line =
	//mvw.node =

     from_fld = CreateNodeField(mvw.line, "FROM_ID", mvw.node+".ID", "From", )
     to_fld = CreateNodeField(mvw.line, "TO_ID", mvw.node+".ID", "To", )

	 // Create fields on intersection layer
     RunMacro("addfields", mvw.node, {"FROMJOIN","TOJOIN","LEGS"}, {"r","r","r"})

	 // FROMJOIN: Number of AB links at node
     jnvw = JoinViews(mvw.node + mvw.line, mvw.node+".ID", mvw.line+"."+from_fld, {{"A", }})
     rec = GetFirstRecord(jnvw + "|", null)
     while rec <> null do
          jnvw.FROMJOIN = jnvw.("[N "+mvw.line+"]")
          rec = GetNextRecord(jnvw + "|", null, null)
     end
     CloseView(jnvw)

     // TOJOIN: Number of BA links at node
	// LEGS = (FROMJOIN + TOJOIN) if > 3 else 0
     jnvw = JoinViews(mvw.node + mvw.line, mvw.node+".ID", mvw.line+"."+to_fld, {{"A", }})
     rec = GetFirstRecord(jnvw + "|", null)
     while rec <> null do
          jnvw.TOJOIN = jnvw.("[N "+mvw.line+"]")
          if jnvw.FROMJOIN + jnvw.TOJOIN > 2 then jnvw.LEGS = jnvw.FROMJOIN + jnvw.TOJOIN else jnvw.LEGS = 0
          rec = GetNextRecord(jnvw + "|", null, null)
     end
     CloseView(jnvw)

	 // Aggregates nodes to TAZ using a .25 buffer; TAZ "IntrsctnDens" = Sum all LEGS
     ColumnAggregate(mvw.taz+"|", .25, mvw.node+"|", {{"IntrsctnDens", "Sum", "LEGS", }}, null)

	// Computes Intersection Density = Legs/Area (Square Mile)
     rec = GetFirstRecord(mvw.taz + "|", null)
     while rec <> null do
          mvw.taz.IntrsctnDens = mvw.taz.IntrsctnDens / mvw.taz.Area
          rec = GetNextRecord(mvw.taz + "|", null, null)
     end

endMacro


//Accessibilities
Macro "accessibility" (accvec)
// A macro to calculate logsum of exponential gravity accessibilities - V.Bernardin, Jr.
// If you want to exclude zones from accessibility calculation (perhaps for different modes), the size vector & impedence matrix index need to match
// Currently - only auto (mode = 1) is used across all zones. Transit & NonM are dummy selections.

// accvec = {tazvec.HH, tazvec.TOTPOP, tazvec.TOTACT, tazvec.TOTEMP, tazvec.BAS, tazvec.IND, tazvec.RET, tazvec.FDL, tazvec.PRO, tazvec.OSV}
shared mvw, skim

	{HH, POP, TAS, EMP, BAS, IND, RET, FDL, PRO, OSV} = accvec
	SRV = FDL + PRO + OSV
     impmat = OpenMatrix(skim.default, "Auto")
	 SetMatrixIndex(impmat, "TAZID", "TAZID")
     mcic = CreateMatrixCurrency(impmat, "gctta", "TAZID", "TAZID", null)

     GENATT = POP + 0.6151*BAS + 0.8984*IND + 3.0097*RET + 1.8052*SRV
     NEARATT = 3.4111*RET + 2.7404*SRV
     OTHRATT = 0.2605*HH + 1.000*RET + 1.0452*FDL + 0.2720*OSV + 0.1710*PRO + 0.0804*BAS + 0.0061*IND

     RunMacro("addfields", mvw.taz, {"GENATT","NEARATT","OTHRATT"}, {"r","r","r"})
     SetDataVectors(mvw.taz + "|", {{"GENATT",GENATT}, {"NEARATT",NEARATT}, {"OTHRATT",OTHRATT}}, {{"Sort Order",{{"ID","Ascending"}}}})

	// Transit indicies
	SetView(mvw.node)
	numsel = SelectByQuery("Transit", "Several", "Select * where Centroid = 1", )
	indices = GetMatrixIndexNames(impmat)
	for i = 1 to indices[1].length do if indices[1][i] = "Transit" then DeleteMatrixIndex(impmat, "Transit") end
	nmi = CreateMatrixIndex("Transit", impmat, "Both", mvw.node+"|Transit", "ID", "TAZID")

	// NonMotorized indicies
	numsel = SelectByQuery("NonMotorized", "Several", "Select * where Centroid = 1", )
	indices = GetMatrixIndexNames(impmat)
	for i = 1 to indices[1].length do if indices[1][i] = "NonMotorized" then DeleteMatrixIndex(impmat, "NonMotorized") end
	nmi = CreateMatrixIndex("NonMotorized", impmat, "Both", mvw.node+"|NonMotorized", "ID", "TAZID")

				//sizes  , betas  ,  diff, imp  ,  outnames   ,   modes
	accessarr = {{ GENATT, -0.1911, 0    , mcic , "GenAccess" , 1},
				{ NEARATT, -0.50  , 0    , mcic , "NearAccess", 1},
				{ EMP    , -0.13  , 0    , mcic , "AccessEMP" , 1},
				{ RET    , -0.18  , 0    , mcic , "AccessRET" , 1},
				{ TAS    , -0.60  , 1    , mcic , "AccessD"   , 1},
				{ TAS    , -0.10  , 2    , mcic , "AccessS"   , 1}
				}

      // Add a matrix core to the impedance matrix for accessibility calculations
	 mca1 = RunMacro("CheckMatrixCore", impmat, "AccessCalc", "TAZID", "TAZID")
	 mca2 = CreateMatrixCurrency(impmat, "AccessCalc", "Transit", "Transit",)
     mca3 = CreateMatrixCurrency(impmat, "AccessCalc", "NonMotorized", "NonMotorized",)
     mcd = CreateMatrixCurrency(impmat, "D", "TAZID", "TAZID",)
     mcs = CreateMatrixCurrency(impmat, "S", "TAZID", "TAZID",)

     // Loop over each accessibility measure
     mca = {mca1, mca2, mca3}
     set = {null, "Transit", "NonMotorized"}

     for i = 1 to accessarr.length do
		{size, beta, diff, impx, outname, mode} = accessarr[i]
		  RunMacro("addfields", mvw.taz, {outname}, {"r"})
          thismca = mca[mode]
          thisset = set[mode]
							//thismca := Sizes[i] * exp(betas[i] * imp[i])
          if diff = 0 then do thismca := size * exp(beta * impx) end
          else if diff = 1 then do thismca := size * mcd * exp(beta * impx) end
          else if diff = 2 then do thismca := size * mcs * exp(beta * impx) end
          rsv = GetMatrixVector(thismca, {{"Marginal", "Row Sum"}})
          logsum = Max(0, Log(rsv))
          SetDataVector(mvw.taz+"|"+thisset, outname, logsum, {{"Sort Order",{{"ID","Ascending"}}}})

		  //Calculate GenAcc^2
		  if outname = "GenAccess" then do
			RunMacro("addfields", mvw.taz, {"GenAcc2"}, {"r"})
			GenAcc2 = -1*pow(logsum - 8.5,2)
			SetDataVector(mvw.taz+"|"+thisset, "GenAcc2", GenAcc2, {{"Sort Order",{{"ID","Ascending"}}}})
		  end
     end

	 RunMacro("dropfields", mvw.taz,{"NearAccess","AccessEMP","AccessRET","AccessD","AccessS"})
     SetView(mvw.node)
	 DeleteSet("Transit")
     DeleteSet("NonMotorized")

endMacro


//Highway Network Processing
Macro "gencost_setup"
shared root, mvw, info
shared netparam, net
shared car, sut, mut, ext, link

{car, sut, mut, ext, link} = {null, null, null, null, null}

// Set fc penalty, note that [car < sut < mut] & [ext < mut] for the highest FC term
car.fc  = {netparam.CFCP1.value, netparam.CFCP2.value, netparam.CFCP3.value, netparam.CFCP4.value, netparam.CFCP5.value, netparam.CFCP6.value*netparam.SFCP6.value*netparam.MFCP6.value}
sut.fc  = {netparam.SFCP1.value, netparam.SFCP2.value, netparam.SFCP3.value, netparam.SFCP4.value, netparam.SFCP5.value, netparam.SFCP6.value*netparam.MFCP6.value}
mut.fc  = {netparam.MFCP1.value, netparam.MFCP2.value, netparam.MFCP3.value, netparam.MFCP4.value, netparam.MFCP5.value, netparam.MFCP6.value}
ext.fc  = {netparam.XFCP1.value, netparam.XFCP2.value, netparam.XFCP3.value, netparam.XFCP4.value, netparam.XFCP5.value, netparam.XFCP6.value*netparam.MFCP6.value}

//Auto
car.abbr = "A"
car.type = "FC"
car.rrxdelay = netparam.rrxdelay.value
car.vot = netparam.carvot.value	//VOT in $/hr, converted in calculation to $/min
car.delayfac = netparam.carpdelay.value

//SUT
sut.abbr = "S"
sut.type = "FC"
sut.rrxdelay = netparam.rrxdt.value
sut.vot = netparam.sutvot.value
sut.delayfac = netparam.sutpdelay.value

//MUT
mut.abbr = "M"
mut.type = "FC"
mut.rrxdelay = netparam.rrxdt.value
mut.vot = netparam.mutvot.value
mut.delayfac = netparam.mutpdelay.value

//EXT
/*
ext.abbr = "X"
ext.type = "FC"
ext.rrxdelay = netparam.rrxdelay.value
ext.vot = netparam.extvot.value
ext.delayfac = netparam.extpdelay.value
*/

//Processing
// Calculate NEW funcclass(FUNCNEW) based on FHWA rewised functional class code and TPO designated urbanized areas--YS 2/17/2021
{id  , link.leng, link.fc    , link.ab_fft , link.ba_fft , link.waterx, link.rrx, ab_brpa  , ba_bpra  , ab_bprb  , ba_bprb  , ab_amcap  , ba_amcap  , ab_pmcap  , ba_pmcap  , ab_opcap  , ba_opcap  ,AB_DlyCap  , BA_DlyCap} = GetDataVectors(mvw.line + "|",
{"ID", "Length" , "FUNCNEW", "AB_AFFTIME", "BA_AFFTIME", "WATER_X"  , "RAIL_X", "AB_BPRA", "BA_BPRA", "AB_BPRB", "BA_BPRB", "AB_AMCAP", "BA_AMCAP", "AB_PMCAP", "BA_PMCAP", "AB_OPCAP", "BA_OPCAP","AB_DlyCap", "BA_DlyCap"}                              , {{"Sort Order",{{"ID","Ascending"}}}})
if info.iter = 0 then {link.ab_tt, link.ba_tt} = {link.ab_fft, link.ba_fft}
if info.iter > 0 then {link.ab_tt, link.ba_tt} = GetDataVectors(mvw.line + "|", {"AB_CTime", "BA_CTime"}, {{"Sort Order",{{"ID","Ascending"}}}})

if info.iter = 0 then do
	// Prepopulate Table
     link.vw = CreateTable("GenCost", net.gencost,"FFB",
			{
			{"ID"         , "Integer", 16, null, "No"},
			{"Length"     , "Real"   , 12, 2   , "No"},
			{"FUNCNEW"  , "Integer", 16, null, "No"},
			{"AB_AFFTIME" , "Real"   , 12, 2   , "No"},
			{"BA_AFFTIME" , "Real"   , 12, 2   , "No"},
			{"AB_CTime" , "Real"   , 12, 2   , "No"},
			{"BA_CTime" , "Real"   , 12, 2   , "No"},
			{"WATER_X"    , "Real"   , 12, 2   , "No"},
			{"RAIL_X"     , "Real"   , 12, 2   , "No"},
			{"AB_BPRA"    , "Real"   , 12, 2   , "No"},
			{"BA_BPRA"    , "Real"   , 12, 2   , "No"},
			{"AB_BPRB"    , "Real"   , 12, 2   , "No"},
			{"BA_BPRB"    , "Real"   , 12, 2   , "No"},
			{"AB_AMCAP"   , "Real"   , 12, 2   , "No"},
			{"BA_AMCAP"   , "Real"   , 12, 2   , "No"},
			{"AB_PMCAP"   , "Real"   , 12, 2   , "No"},
			{"BA_PMCAP"   , "Real"   , 12, 2   , "No"},
			{"AB_OPCAP"   , "Real"   , 12, 2   , "No"},
			{"BA_OPCAP"   , "Real"   , 12, 2   , "No"},
			{"AB_DlyCap"   , "Real"   , 12, 2   , "No"},
			{"BA_DlyCap"   , "Real"   , 12, 2   , "No"}
			})
	linecount = VectorStatistic(id, "Count", )
	r = AddRecords(link.vw, null, null, {{"Empty Records", linecount}})

	SetDataVectors(link.vw+"|",{
				{"ID"        ,id}         ,
				{"Length"    ,link.leng}  ,
				{"FUNCNEW" ,link.fc}    ,
				{"AB_AFFTIME",link.ab_fft} ,{"BA_AFFTIME",link.ba_fft},
				{"WATER_X"   ,link.waterx},{"RAIL_X"    ,link.rrx}  ,
				{"AB_BPRA"   ,ab_brpa}    ,{"BA_BPRA"   ,ba_bpra}   ,
				{"AB_BPRB"   ,ab_bprb}    ,{"BA_BPRB"   ,ba_bprb}   ,
				{"AB_AMCAP"  ,ab_amcap}   ,{"AB_PMCAP"  ,ab_pmcap}  , {"AB_OPCAP"  ,ab_opcap}, {"AB_DlyCap",AB_DlyCap},
				{"BA_AMCAP"  ,ba_amcap}   ,{"BA_PMCAP"  ,ba_pmcap}  , {"BA_OPCAP"  ,ba_opcap}, {"BA_DlyCap",BA_DlyCap}
			}  ,{{"Sort Order",{{"ID","Ascending"}}}})
end
if info.iter > 0 then do
	link.vw = OpenTable("GenCost", "FFB", {net.gencost, })
	SetDataVectors(link.vw+"|",{{"AB_CTime",link.ab_tt},{"BA_CTime",link.ba_tt}}  ,{{"Sort Order",{{"ID","Ascending"}}}})
end

	RunMacro("gencost", car, link)
	RunMacro("gencost", sut, link)
	RunMacro("gencost", mut, link)

//if info.iter = 0 then ExportView(mvw.line+"|", "CSV", root.mod+"\\TN_Links.csv", null, {{"CSV Drop Quotes", "True"},{"CSV Header", "True"}})

CloseView(link.vw)
endMacro

Macro "gencost" (gc, link)
	//Calculates generalized costs; writes to network & gencost file
	//Note that VoT provided is in $/sec

	/*
	(Helpfile: Volume Delay Functions for MMA)
	MMA_GCTT = VOT * Time_Cong + Toll
	RSG_GCTT = VOT * [T_FF + k*Delay] + [Toll_$ + Toll_FC]
				= VOT * [k*TravelTime - T_FF*(k-1)] + [Toll_$ + Toll_FC]
				= [VOT*k] * TravelTime + [Toll_$ + Toll_FC - VOT*T_FF*(k-1)]

	RSG_GC   = [Toll_$ + Toll_FC - VOT*T_FF*(k-1)]

	Time_Cong = [T_ff + k*Delay]
				= k*Delay + k*T_ff + T_FF - k*T_ff
				= k*(Delay+T_ff) + T_FF(1-k)
				= k*(TravelTime) - T_FF(k-1)
	*/

	shared mvw

	abftbfld = JoinStrings({"AB_FTB_",gc.abbr},"")
	baftbfld = JoinStrings({"BA_FTB_",gc.abbr},"")
	abtcfld = JoinStrings({"AB_TC",gc.abbr},"")
	batcfld = JoinStrings({"BA_TC",gc.abbr},"")
	abtimefld = JoinStrings({"AB_GCTT",gc.abbr},"")
	batimefld = JoinStrings({"BA_GCTT",gc.abbr},"")

	RunMacro("addfields", mvw.line, {abftbfld, baftbfld, abtcfld, batcfld, abtimefld, batimefld},{"r","r","r","r","r","r"})
	RunMacro("addfields", link.vw, {abftbfld, baftbfld, abtcfld, batcfld, abtimefld, batimefld},{"r","r","r","r","r","r"})

	if gc.type = "FC" then do
		 fc6 = if (link.fc=1 | link.fc=11 | link.fc>70) then 1
			 else if (link.fc=2 | link.fc=12 | link.fc=10 | link.fc=20) then 2
			 else if (link.fc=6 | link.fc=14) then 3
			 else if (link.fc=7 | link.fc=16) then 4
			 else if (link.fc=8 | link.fc=17) then 5
			 else 6

		//FTb (minutes)
		abftb =  if fc6 = 6 then max(0, (link.leng * gc.fc[6])) 														+ nz(link.rrx)*gc.rrxdelay
			else if fc6 = 5 then max(0, (link.leng * gc.fc[6] * gc.fc[5])) 												+ nz(link.rrx)*gc.rrxdelay
			else if fc6 = 4 then max(0, (link.leng * gc.fc[6] * gc.fc[5] * gc.fc[4])) 									+ nz(link.rrx)*gc.rrxdelay
			else if fc6 = 3 then max(0, (link.leng * gc.fc[6] * gc.fc[5] * gc.fc[4] * gc.fc[3])) 						+ nz(link.rrx)*gc.rrxdelay
			else if fc6 = 2 then max(0, (link.leng * gc.fc[6] * gc.fc[5] * gc.fc[4] * gc.fc[3] * gc.fc[2])) 			+ nz(link.rrx)*gc.rrxdelay
			else if fc6 = 1 then max(0, (link.leng * gc.fc[6] * gc.fc[5] * gc.fc[4] * gc.fc[3] * gc.fc[2] * gc.fc[1])) 	+ nz(link.rrx)*gc.rrxdelay
		baftb = abftb

		//TransCAD Fixed Toll (in $) to be used in Assignment
		// Real Tolls + FTb [in $] - VOT(k-1)*AFFTime
		abTC = max(abftb*(gc.vot/60) - ((gc.vot/60)*(gc.delayfac-1) * link.ab_fft), 0)
		baTC = max(baftb*(gc.vot/60) - ((gc.vot/60)*(gc.delayfac-1) * link.ba_fft), 0)

		//Fixed Toll Travel Time with delay (for skimming)
		abGCTT = (gc.delayfac * link.ab_tt) + (link.ab_fft*(1-gc.delayfac)) + abftb
		baGCTT = (gc.delayfac * link.ba_tt) + (link.ba_fft*(1-gc.delayfac)) + baftb
	end

//Write to Network
SetDataVectors(mvw.line + "|", {{abftbfld,abftb},{baftbfld,baftb},{abtcfld,abTC},{batcfld,baTC},{abtimefld,abGCTT},{batimefld,baGCTT}}, {{"Sort Order",{{"ID","Ascending"}}}})

//Write to GCfile
SetDataVectors(link.vw+"|",{{abftbfld,abftb},{baftbfld,baftb},{abtcfld,abTC},{batcfld,baTC},{abtimefld,abGCTT},{batimefld,baGCTT}},{{"Sort Order",{{"ID","Ascending"}}}})

endMacro

Macro "create_hnet"
shared mvw, net, netparam

//Set global turn penalties
 left_tp =  netparam.CLTP.value
 right_tp = netparam.CRTP.value * netparam.CLTP.value

    RunMacro("TCB Init")
    Opts = null
	Opts.Input.[Link Set] = {mvw.linefile+"|"+mvw.line, mvw.line}
    Opts.Global.[Network Options].[Turn Penalties] = "Yes"
    Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
    Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
    Opts.Global.[Network Options].[Time Units] = "Minutes"
	Opts.Global.[Length Units] = "Miles"
	Opts.Global.[Link Options].Length = {mvw.line+".Length"    , mvw.line+".Length"    ,,, "False"}
	Opts.Global.[Link Options].AFFTime= {mvw.line+".AB_AFFTime", mvw.line+".BA_AFFTime",,, "True"}
	Opts.Global.[Link Options].AMCap  = {mvw.line+".AB_AMCap"  , mvw.line+".BA_AMCap"  ,,, "False"}
	Opts.Global.[Link Options].PMCap  = {mvw.line+".AB_PMCap"  , mvw.line+".BA_PMCap"  ,,, "False"}
	Opts.Global.[Link Options].OPCap  = {mvw.line+".AB_OPCap"  , mvw.line+".BA_OPCap"  ,,, "False"}
	Opts.Global.[Link Options].DLYCAP = {mvw.line+".AB_DLYCAP" , mvw.line+".BA_DLYCAP" ,,, "False"}
	Opts.Global.[Link Options].bprA   = {mvw.line+".AB_bprA"   , mvw.line+".BA_bprA"   ,,, "False"}
	Opts.Global.[Link Options].bprB   = {mvw.line+".AB_bprB"   , mvw.line+".BA_bprB"   ,,, "False"}
	Opts.Global.[Link Options].riverx = {mvw.line+".WATER_X"   , mvw.line+".WATER_X"   ,,, "False"}
	Opts.Global.[Link Options].TCa    = {mvw.line+".AB_TCA"    , mvw.line+".BA_TCA"    ,,, "False"}
	Opts.Global.[Link Options].TCs    = {mvw.line+".AB_TCS"    , mvw.line+".BA_TCS"    ,,, "False"}
	Opts.Global.[Link Options].TCm    = {mvw.line+".AB_TCM"    , mvw.line+".BA_TCM"    ,,, "False"}
	Opts.Global.[Link Options].FTBa   = {mvw.line+".AB_FTB_A"  , mvw.line+".BA_FTB_A"  ,,, "False"}
	Opts.Global.[Link Options].FTBs   = {mvw.line+".AB_FTB_S"  , mvw.line+".BA_FTB_S"  ,,, "False"}
	Opts.Global.[Link Options].FTBm   = {mvw.line+".AB_FTB_M"  , mvw.line+".BA_FTB_M"  ,,, "False"}
	Opts.Global.[Link Options].gctta  = {mvw.line+".AB_GCTTA"  , mvw.line+".BA_GCTTA"  ,,, "True"}
	Opts.Global.[Link Options].gctts  = {mvw.line+".AB_GCTTS"  , mvw.line+".BA_GCTTS"  ,,, "True"}
	Opts.Global.[Link Options].gcttm  = {mvw.line+".AB_GCTTM"  , mvw.line+".BA_GCTTM"  ,,, "True"}
	Opts.Output.[Network File] = net.assign

	//Build Highway Network with above parameters
    ok = RunMacro("TCB Run Operation", "Build Highway Network", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )

	// Update Highway Network with Turn Penalties
    RunMacro("TCB Init")
     Opts = null
     Opts.Input.Database = mvw.linefile
     Opts.Input.Network = net.assign
	 Opts.Input.[Toll Set] = {mvw.linefile+"|"+mvw.line, mvw.line}
	 Opts.Input.[Centroids Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Centroids", "Select * where Centroid = 1"}
	 Opts.Global.[Link to Link Penalty Method] = "Table"
     Opts.Global.[Global Turn Penalties] = {left_tp, right_tp, 0, -1}
	 //Opts.Global.[Global Turn Penalties] = {0.999, 0.265734, 0, -1}
	ok = RunMacro("TCB Run Operation", "Network Settings", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )

endMacro

Macro "update_hnet" (assign)
shared mvw, net

    RunMacro("TCB Init")
// STEP 1: Network Settings
    Opts = null
    Opts.Input.Network = net.assign
    Opts.Input.Database = mvw.linefile
    Opts.Input.[Update Link Source Sets] = {{mvw.linefile+"|"+mvw.line, mvw.line}}

	if assign = 1 then do
		Opts.Global.[Update Network Fields].Links.TCa    = {mvw.line+".AB_TCA"    , mvw.line+".BA_TCA"    ,,, "False"}
		Opts.Global.[Update Network Fields].Links.TCs    = {mvw.line+".AB_TCS"    , mvw.line+".BA_TCS"    ,,, "False"}
		Opts.Global.[Update Network Fields].Links.TCm    = {mvw.line+".AB_TCM"    , mvw.line+".BA_TCM"    ,,, "False"}
		Opts.Global.[Update Network Fields].Links.FTBa   = {mvw.line+".AB_FTB_A"  , mvw.line+".BA_FTB_A"  ,,, "False"}
		Opts.Global.[Update Network Fields].Links.FTBs   = {mvw.line+".AB_FTB_S"  , mvw.line+".BA_FTB_S"  ,,, "False"}
		Opts.Global.[Update Network Fields].Links.FTBm   = {mvw.line+".AB_FTB_M"  , mvw.line+".BA_FTB_M"  ,,, "False"}
		Opts.Global.[Update Network Fields].Links.gctta  = {mvw.line+".AB_GCTTA"  , mvw.line+".BA_GCTTA"  ,,, "True"}
		Opts.Global.[Update Network Fields].Links.gctts  = {mvw.line+".AB_GCTTS"  , mvw.line+".BA_GCTTS"  ,,, "True"}
		Opts.Global.[Update Network Fields].Links.gcttm  = {mvw.line+".AB_GCTTM"  , mvw.line+".BA_GCTTM"  ,,, "True"}
		Opts.Global.[Update Network Fields].Links.AMPrePCE = {mvw.line+".AB_AMPrePCE" , mvw.line+".BA_AMPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.PMPrePCE = {mvw.line+".AB_PMPrePCE" , mvw.line+".BA_PMPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.OPPrePCE = {mvw.line+".AB_OPPrePCE" , mvw.line+".BA_OPPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.DLYPrePCE = {mvw.line+".AB_DLYPrePCE" , mvw.line+".BA_DLYPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.AMTime = {mvw.line+".AB_AM_Time", mvw.line+".BA_AM_Time",,, "True"}
		Opts.Global.[Update Network Fields].Links.PMTime = {mvw.line+".AB_PM_Time", mvw.line+".BA_PM_Time",,, "True"}
		Opts.Global.[Update Network Fields].Links.OPTime = {mvw.line+".AB_OP_Time", mvw.line+".BA_OP_Time",,, "True"}
		Opts.Global.[Update Network Fields].Links.CTime  = {mvw.line+".AB_CTime"  , mvw.line+".BA_CTime"  ,,, "True"}
		Opts.Global.[Update Network Fields].Formulas = {}
	end

	if assign = 2 then do
		Opts.Global.[Update Network Fields].Links.AMPrePCE = {mvw.line+".AB_AMPrePCE" , mvw.line+".BA_AMPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.PMPrePCE = {mvw.line+".AB_PMPrePCE" , mvw.line+".BA_PMPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.OPPrePCE = {mvw.line+".AB_OPPrePCE" , mvw.line+".BA_OPPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.DLYPrePCE = {mvw.line+".AB_DLYPrePCE" , mvw.line+".BA_DLYPrePCE" ,,0, "False"}
		Opts.Global.[Update Network Fields].Links.AMTime = {mvw.line+".AB_AM_Time", mvw.line+".BA_AM_Time",,, "True"}
		Opts.Global.[Update Network Fields].Links.PMTime = {mvw.line+".AB_PM_Time", mvw.line+".BA_PM_Time",,, "True"}
		Opts.Global.[Update Network Fields].Links.OPTime = {mvw.line+".AB_OP_Time", mvw.line+".BA_OP_Time",,, "True"}
		Opts.Global.[Update Network Fields].Links.CTime  = {mvw.line+".AB_CTime"  , mvw.line+".BA_CTime"  ,,, "True"}
		Opts.Global.[Update Network Fields].Formulas = {}
	end

	//ODME
	if assign = 3 then do
		Opts.Global.[Update Network Fields].Links.gctta      = {mvw.line+".AB_GCTTA"     , mvw.line+".BA_GCTTA"     ,,,"False"}
		Opts.Global.[Update Network Fields].Links.gctts      = {mvw.line+".AB_GCTTS"     , mvw.line+".BA_GCTTS"     ,,,"False"}
		Opts.Global.[Update Network Fields].Links.gcttm      = {mvw.line+".AB_GCTTM"     , mvw.line+".BA_GCTTM"     ,,,"False"}
		Opts.Global.[Update Network Fields].Links.TCa        = {mvw.line+".AB_TCA"       , mvw.line+".BA_TCA"       ,,,"False"}
		Opts.Global.[Update Network Fields].Links.TCs        = {mvw.line+".AB_TCS"       , mvw.line+".BA_TCS"       ,,,"False"}
		Opts.Global.[Update Network Fields].Links.TCm        = {mvw.line+".AB_TCM"       , mvw.line+".BA_TCM"       ,,,"False"}
		Opts.Global.[Update Network Fields].Links.carcntfact = {mvw.line+".AB_carcntfact", mvw.line+".BA_carcntfact",, , "False"}
		Opts.Global.[Update Network Fields].Links.carnumcnt  = {mvw.line+".AB_carnumcnt" , mvw.line+".BA_carnumcnt" ,, , "False"}
		Opts.Global.[Update Network Fields].Links.sutcntfact = {mvw.line+".AB_sutcntfact", mvw.line+".BA_sutcntfact",, , "False"}
		Opts.Global.[Update Network Fields].Links.sutnumcnt  = {mvw.line+".AB_sutnumcnt" , mvw.line+".BA_sutnumcnt" ,, , "False"}
		Opts.Global.[Update Network Fields].Links.mutcntfact = {mvw.line+".AB_mutcntfact", mvw.line+".BA_mutcntfact",, , "False"}
		Opts.Global.[Update Network Fields].Links.mutnumcnt  = {mvw.line+".AB_mutnumcnt" , mvw.line+".BA_mutnumcnt" ,, , "False"}

		Opts.Global.[Update Network Fields].Formulas = {}
	end

    Opts.Global.[Link to Link Penalty Method] = "Table"
    ok = RunMacro("TCB Run Operation", "Network Settings", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )

endMacro

//DaySim
Macro "daysim_setup"
shared root, mvw, info, indir, outdir, daysim
shared skim

//Robocopy doc: http://ss64.com/nt/robocopy.html
logfile = outdir.daysim + "rcopy.txt"

//Copy runfiles to Input dir
status = RunProgram("cmd /c robocopy "+root.daysim+"Inputs\\ "+indir.daysim+" /S /E /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG:"+logfile,)

//status = RunProgram("cmd /c robocopy "+root.paramds+" "+outdir.daysim+" config.properties /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG:"+logfile,)

//DAYSIM STANDARD CONFIG
	ptr = OpenFile(daysim.cfgtemplate, "r+")
	dscfg = ReadArray(ptr)
	CloseFile(ptr)
	dscfg[7]  = "BasePath = " + outdir.daysim
	dscfg[8]  = "OutputSubpath = .\\"
	dscfg[14] = "NProcessors=" + if info.cores < 4 then 1 else i2s(info.cores/4)
	dscfg[15] = "NBatches=" + i2s(info.cores*1)
	dscfg[33] = "HouseholdSamplingRateOneInX=1"
	dscfg[73] = "RosterPath=roster.csv"
	if info.iter > 0 then dscfg[73] = "RosterPath=roster_tod.csv"
	dscfg[85] = "IxxiPath="+indir.daysim+"\5_ParknRide\\IXXI.dat"
	dscfg[90] = "RawParkAndRideNodePath="+indir.daysim+"\5_ParknRide\\pnr_nodes.dat"
	dscfg[92] = "RawParcelPath="+mvw.mzbuff
	dscfg[94] = "RawZonePath="+indir.daysim+"\1_TAZ_Index\\TAZ_Index.dat"
	dscfg[96] = "RawHouseholdPath="+mvw.popsynhh
	dscfg[98] = "RawPersonPath="+mvw.popsynperson
	dscfg[179] = "WorkLocationModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkLocationCoefficients_Chattanooga.F12"
	dscfg[182] = "SchoolLocationModelCoefficients="+indir.daysim+"\9_Coefficients\\SchoolLocationCoefficients_Chattanooga.F12"
	dscfg[185] = "PayToParkAtWorkplaceModelCoefficients="+indir.daysim+"\9_Coefficients\\PayToParkAtWorkplaceCoefficients_Chattanooga.F12"
	dscfg[188] = "TransitPassOwnershipModelCoefficients="+indir.daysim+"\9_Coefficients\\TransitPassOwnershipCoefficients_Chattanooga.F12"
	dscfg[191] = "AutoOwnershipModelCoefficients="+indir.daysim+"\9_Coefficients\\AutoOwnershipCoefficients_Chattanooga.F12"
	dscfg[195] = "IndividualPersonDayPatternModelCoefficients="+indir.daysim+"\9_Coefficients\\IndividualPersonDayPatternCoefficients_Chattanooga.F12"
	dscfg[197] = "PersonExactNumberOfToursModelCoefficients="+indir.daysim+"\9_Coefficients\\PersonExactNumberOfToursCoefficients_Chattanooga.F12"
	dscfg[201] = "WorkTourDestinationModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkTourDestinationCoefficients_Chattanooga.F12"
	dscfg[203] = "OtherTourDestinationModelCoefficients="+indir.daysim+"\9_Coefficients\\OtherTourDestinationCoefficients_Chattanooga.F12"
	dscfg[206] = "WorkBasedSubtourGenerationModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkBasedSubtourGenerationCoefficients_Chattanooga.F12"
	dscfg[209] = "WorkTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkTourModeCoefficients_Chattanooga.F12"
	dscfg[211] = "SchoolTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\SchoolTourModeCoefficients_Chattanooga.F12"
	dscfg[213] = "WorkBasedSubtourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkBasedSubtourModeCoefficients_Chattanooga.F12"
	dscfg[215] = "EscortTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\EscortTourModeCoefficients_Chattanooga.F12"
	dscfg[217] = "OtherHomeBasedTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\OtherHomeBasedTourModeCoefficients_Chattanooga.F12"
	dscfg[220] = "WorkTourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkTourTimeCoefficients_Chattanooga.F12"
	dscfg[222] = "SchoolTourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\SchoolTourTimeCoefficients_Chattanooga.F12"
	dscfg[224] = "OtherHomeBasedTourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\OtherHomeBasedTourTimeCoefficients_Chattanooga.F12"
	dscfg[226] = "WorkBasedSubtourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkbasedSubtourTimeCoefficients_Chattanooga.F12"
	dscfg[229] = "IntermediateStopGenerationModelCoefficients="+indir.daysim+"\9_Coefficients\\IntermediateStopGenerationCoefficients_Chattanooga.F12"
	dscfg[232] = "IntermediateStopLocationModelCoefficients="+indir.daysim+"\9_Coefficients\\IntermediateStopLocationCoefficients_Chattanooga.F12"
	dscfg[235] = "TripModeModelCoefficients="+indir.daysim+"\9_Coefficients\\TripModeCoefficients_Chattanooga.F12"
	dscfg[238] = "TripTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\TripTimeCoefficients_Chattanooga.F12"
	ptr = OpenFile(daysim.cfg_out, "w")
	WriteArray(ptr, dscfg)
	CloseFile(ptr)


//DAYSIM SHADOWPRICE CONFIG
	ptr = OpenFile(daysim.sp_in, "r+")
	dscfg = ReadArray(ptr)
	CloseFile(ptr)
	dscfg[7]  = "BasePath = " + outdir.daysim
	dscfg[8]  = "OutputSubpath = .\\"
	dscfg[14] = "NProcessors=" + if info.cores < 4 then 1 else i2s(info.cores/4)
	dscfg[15] = "NBatches=" + i2s(info.cores*1)
	dscfg[33] = "HouseholdSamplingRateOneInX=1"
	dscfg[73] = "RosterPath=roster.csv"
	if info.iter > 0 then dscfg[73] = "RosterPath=roster_tod.csv"
	dscfg[85] = "IxxiPath="+indir.daysim+"\5_ParknRide\\IXXI.dat"
	dscfg[90] = "RawParkAndRideNodePath="+indir.daysim+"\5_ParknRide\\pnr_nodes.dat"
	dscfg[92] = "RawParcelPath="+mvw.mzbuff
	dscfg[94] = "RawZonePath="+indir.daysim+"\1_TAZ_Index\\TAZ_Index.dat"
	dscfg[96] = "RawHouseholdPath="+mvw.popsynhh
	dscfg[98] = "RawPersonPath="+mvw.popsynperson
	dscfg[179] = "WorkLocationModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkLocationCoefficients_Chattanooga.F12"
	dscfg[182] = "SchoolLocationModelCoefficients="+indir.daysim+"\9_Coefficients\\SchoolLocationCoefficients_Chattanooga.F12"
	dscfg[185] = "PayToParkAtWorkplaceModelCoefficients="+indir.daysim+"\9_Coefficients\\PayToParkAtWorkplaceCoefficients_Chattanooga.F12"
	dscfg[188] = "TransitPassOwnershipModelCoefficients="+indir.daysim+"\9_Coefficients\\TransitPassOwnershipCoefficients_Chattanooga.F12"
	dscfg[191] = "AutoOwnershipModelCoefficients="+indir.daysim+"\9_Coefficients\\AutoOwnershipCoefficients_Chattanooga.F12"
	dscfg[195] = "IndividualPersonDayPatternModelCoefficients="+indir.daysim+"\9_Coefficients\\IndividualPersonDayPatternCoefficients_Chattanooga.F12"
	dscfg[197] = "PersonExactNumberOfToursModelCoefficients="+indir.daysim+"\9_Coefficients\\PersonExactNumberOfToursCoefficients_Chattanooga.F12"
	dscfg[201] = "WorkTourDestinationModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkTourDestinationCoefficients_Chattanooga.F12"
	dscfg[203] = "OtherTourDestinationModelCoefficients="+indir.daysim+"\9_Coefficients\\OtherTourDestinationCoefficients_Chattanooga.F12"
	dscfg[206] = "WorkBasedSubtourGenerationModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkBasedSubtourGenerationCoefficients_Chattanooga.F12"
	dscfg[209] = "WorkTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkTourModeCoefficients_Chattanooga.F12"
	dscfg[211] = "SchoolTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\SchoolTourModeCoefficients_Chattanooga.F12"
	dscfg[213] = "WorkBasedSubtourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkBasedSubtourModeCoefficients_Chattanooga.F12"
	dscfg[215] = "EscortTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\EscortTourModeCoefficients_Chattanooga.F12"
	dscfg[217] = "OtherHomeBasedTourModeModelCoefficients="+indir.daysim+"\9_Coefficients\\OtherHomeBasedTourModeCoefficients_Chattanooga.F12"
	dscfg[220] = "WorkTourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkTourTimeCoefficients_Chattanooga.F12"
	dscfg[222] = "SchoolTourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\SchoolTourTimeCoefficients_Chattanooga.F12"
	dscfg[224] = "OtherHomeBasedTourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\OtherHomeBasedTourTimeCoefficients_Chattanooga.F12"
	dscfg[226] = "WorkBasedSubtourTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\WorkbasedSubtourTimeCoefficients_Chattanooga.F12"
	dscfg[229] = "IntermediateStopGenerationModelCoefficients="+indir.daysim+"\9_Coefficients\\IntermediateStopGenerationCoefficients_Chattanooga.F12"
	dscfg[232] = "IntermediateStopLocationModelCoefficients="+indir.daysim+"\9_Coefficients\\IntermediateStopLocationCoefficients_Chattanooga.F12"
	dscfg[235] = "TripModeModelCoefficients="+indir.daysim+"\9_Coefficients\\TripModeCoefficients_Chattanooga.F12"
	dscfg[238] = "TripTimeModelCoefficients="+indir.daysim+"\9_Coefficients\\TripTimeCoefficients_Chattanooga.F12"
	ptr = OpenFile(daysim.sp_out, "w")
	WriteArray(ptr, dscfg)
	CloseFile(ptr)

//Copy Roster Files
	rosterdir = indir.daysim+"7_Roster\\"
	status = RunProgram("cmd /c robocopy "+rosterdir+" "+outdir.daysim+" roster*.csv /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG+:"+logfile,)

//Copy Highway & ToD Skims
	status = RunProgram("cmd /c robocopy "+outdir.hwy+" "+outdir.daysim+" Highway_Skim*.mtx /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG+:"+logfile,)

//Copy Transit Skims
	status = RunProgram("cmd /c robocopy "+outdir.transit+" "+outdir.daysim+" *_WalkLocalSkim.mtx /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG+:"+logfile,)
	status = RunProgram("cmd /c robocopy "+outdir.transit+" "+outdir.daysim+" *_WalkShuttleSkim.mtx /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG+:"+logfile,)

//Shadow Prices - Copy user selected shadow_price.txt or converge baseyear_SP 10x
	status = RunProgram("cmd /c robocopy "+info.spdir+" "+outdir.dswrk+" *shadow*.txt /is /R:0 /W:0 /NP /NS /NC /NDL /NJH /TEE /LOG+:"+logfile,)
	if info.spbutton = 1 and info.modyear <> 2019 then do  // update 2014 to 2019 --YS
		for SPiter = 1 to 5 do
			command_line = "cmd /c " + root.daysim + "Daysim.exe -c " + daysim.sp_out
			//>Daysim.exe -c C:\Model\2_Scenarios\Base\Outputs\3_DaySim\Config_SP.properties
			status = RunProgram(command_line,{{"Maximize", "True"}})
		end
		info.spbutton = 0
	end

//Execute DaySim
	command_line = "cmd /c " + root.daysim + "Daysim.exe -c " + daysim.cfg_out
	//>Daysim.exe -c C:\Model\2_Scenarios\Base\Outputs\3_DaySim\Config.properties
	status = RunProgram(command_line,{{"Maximize", "True"}})

endMacro

Macro "daysim_output" (type)
//Process DaySim outputs for TC Assignment
//Assumes Trip O/Ds are actual O-to-Ds

/*
DaySim MODE
{"1"   , "2"   , "3"  , "4"   , "5"    , "6"      , "8"  , "9"}
{"Walk", "Bike", "SOV", "HOV2", "HOV3P", "Transit", "Bus", "Other"}

DaySim Time of Day ; DEPTM is minutes after midnight
{0   , 360} = 12a-6a
{360 , 540} = 6a-9a
{540 , 900} = 9a-3p
{900 , 1080} = 3p-6p
{1080, 1440} = 6p-12a
*/

shared mvw, outdir, od, daysim

//Copy & Open Trip Table as CSV
status = RunProgram("cmd /c ECHO F|xcopy "+daysim.out_trips+" "+daysim.tripscsv+" /R /Y",)
//ShowMessage(i2s(status)) = 0

// DAYSIM AUTO TABLE
if type = "Auto" then do
	tripvw = OpenTable("tripvw", "CSV", {daysim.tripscsv})

	//PCE trips
	tripPCE = CreateExpression(tripvw, "tripPCE", "if MODE = 3 then TREXPFAC*1 else if MODE = 4 then TREXPFAC*1/2  else if MODE = 5 then TREXPFAC*1/3.5  else if MODE = 6 then TREXPFAC*1 else 1*TREXPFAC", {"Integer", 1, 0})

	//Time of day
	trtime = CreateExpression(tripvw, "trtime", "if (HALF = 1) then ARRTM else DEPTM", {"Integer", 4, 0})
	rsgtod = CreateExpression(tripvw, "rsgtod", "if trtime >= 0 and trtime < 360 then 3 else if trtime >= 360 and trtime < 540 then 1 else if trtime >= 540 and trtime < 900 then 3 else if trtime >= 900 and trtime < 1080 then 2 else if trtime >= 1080 and trtime <= 1440 then 3" , {"Integer", 1, 0})

	//Define matrix core names
	dim tripnames[12]
	tripnames = {"AM_Pass", "AM_SUT", "AM_MUT", "PM_Pass", "PM_SUT", "PM_MUT", "OP_Pass", "OP_SUT", "OP_MUT", "PASS", "SUT", "MUT"}

	core01 = "if rsgtod = 1 and (MODE = 3 or MODE = 4 or MODE = 5) then 'AM_Pass'"
	core02 = " else if rsgtod = 2 and (MODE = 3 or MODE = 4 or MODE = 5) then 'PM_Pass'"
	core03 = " else if rsgtod = 3 and (MODE = 3 or MODE = 4 or MODE = 5) then 'OP_Pass'"
	corestr = core01 + core02 + core03
	core_fld = CreateExpression(tripvw, "core_fld", corestr, {"String", 10, 0})


	//DaySim O/D TAZ fields
	{oTAZ, dTAZ} = {"otaz", "dtaz"}
	tazvw = OpenTable("tazvw", "FFB", {mvw.tazbin, })
	tazinfo = GetTableStructure(tazvw)
	tazIDfield = tazinfo[1][1]

		//Create OD matrix & fill 0s
		triptable = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.daysim}, {"Label", "DaySim_Trips"},{"Tables", tripnames} })
		tripmc = CreateMatrixCurrencies(triptable, null, null, null)
		for ft = 1 to tripmc.length do FillMatrix(tripmc[ft][2], null, null, {"Copy", 0}, ) end

		//Match field to matrix core (core_fld) & fill values (tripPCE) ; Matrix Made Easy!
		for todloop = 1 to 3 do
			//SOV
			SetView(tripvw)
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 3) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})

			//HOV2
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 4) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})

			//HOV3+
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 5) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})
		end
			DeleteSet("sel")

	tripmc.PASS := tripmc.AM_Pass + tripmc.PM_Pass + tripmc.OP_Pass

	CloseView(tazvw)
	arr = GetExpressions(tripvw)
	for i = 1 to arr.length do DestroyExpression(tripvw+"."+arr[i]) end
	CloseView(tripvw)
end

//DAYSIM TRANSIT TABLE
if type = "Transit" then do
	//Expand Trips
	tripvw = OpenTable("tripvw", "CSV", {daysim.tripscsv})
	factrips = CreateExpression(tripvw, "factrips", "if MODE = 6 then TREXPFAC*1 else 0", {"Integer", 1, 0})

	//Time of Day
	trtime = CreateExpression(tripvw, "trtime", "if (HALF = 1) then ARRTM else DEPTM", {"Integer", 4, 0})
	rsgtod = CreateExpression(tripvw, "rsgtod", "if trtime >= 0 and trtime < 360 then 3 else if trtime >= 360 and trtime < 540 then 1 else if trtime >= 540 and trtime < 900 then 3 else if trtime >= 900 and trtime < 1080 then 2 else if trtime >= 1080 and trtime <= 1440 then 3" , {"Integer", 1, 0})

	core01= " if rsgtod = 1 and (PATHTYPE = 3) then 'Local'"
	core02= " else if rsgtod = 2 and (PATHTYPE = 3) then 'Local'"
	core03= " else if rsgtod = 3 and (PATHTYPE = 3) then 'Local'"
	core04= " else if rsgtod = 1 and (PATHTYPE = 7) then 'Shuttle'"
	core05= " else if rsgtod = 2 and (PATHTYPE = 7) then 'Shuttle'"
	core06= " else if rsgtod = 3 and (PATHTYPE = 7) then 'Shuttle'"
	corestr = core01 + core02 + core03 + core04 + core05 + core06
	core_fld = CreateExpression(tripvw, "core_fld", corestr, {"String", 10, 0})

	//DaySim O/D TAZ fields
	{oTAZ, dTAZ} = {"otaz", "dtaz"}
	tazvw = OpenTable("tazvw", "FFB", {mvw.tazbin, })
	tazinfo = GetTableStructure(tazvw)
	tazIDfield = tazinfo[1][1]

	//Create OD matrix & fill 0s
	tranam = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.transitam}, {"Label", "TripTable"},{"Tables", {"Local", "Shuttle"}} })
	tranpm = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.transitpm}, {"Label", "TripTable"},{"Tables", {"Local", "Shuttle"}} })
	tranop = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.transitop}, {"Label", "TripTable"},{"Tables", {"Local", "Shuttle"}} })

	//Transit
	SetView(tripvw)
	numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 6) and rsgtod = 1", )
	UpdateMatrixFromView(tranam, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

	numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 6) and rsgtod = 2", )
	UpdateMatrixFromView(tranpm, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

	numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 6) and rsgtod = 3", )
	UpdateMatrixFromView(tranop, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

	DeleteSet("sel")

	CloseView(tazvw)
	arr = GetExpressions(tripvw)
	for i = 1 to arr.length do DestroyExpression(tripvw+"."+arr[i]) end
	CloseView(tripvw)
end

endMacro

Macro "daysim_postprocess"
shared root, mvw, info, indir, outdir, daysim
shared skim

	comp.popsynmz      = Substitute(mvw.mzbuff      ,"\\", "/", null)
	comp.out_hh        = Substitute(daysim.out_hh     ,"\\", "/", null)
	comp.out_pers      = Substitute(daysim.out_pers   ,"\\", "/", null)
	comp.out_persday   = Substitute(daysim.out_persday,"\\", "/", null)
	comp.out_tours     = Substitute(daysim.out_tours  ,"\\", "/", null)
	comp.out_trips     = Substitute(daysim.out_trips  ,"\\", "/", null)
	comp.daysimrep     = Substitute(outdir.daysimrep  ,"\\", "/", null)

	ptr = OpenFile(daysim.postcfg, "r+")
	dscfg = ReadArray(ptr)
	CloseFile(ptr)
	dscfg[4]  = "parcelfile                                = '"+ comp.popsynmz    +"'"
	dscfg[5]  = "dshhfile                                  = '"+ comp.out_hh      +"'"
	dscfg[6]  = "dsperfile                                 = '"+ comp.out_pers    +"'"
	dscfg[7]  = "dspdayfile                                = '"+ comp.out_persday +"'"
	dscfg[8]  = "dstourfile                                = '"+ comp.out_tours   +"'"
	dscfg[9]  = "dstripfile                                = '"+ comp.out_trips   +"'"
	dscfg[46] = "outputsDir                                = '"+ comp.daysimrep   +"'"
	ptr = OpenFile(daysim.postcfg, "w")
	WriteArray(ptr, dscfg)
	CloseFile(ptr)

	//Execute DS Post Processor
	command_line = "cmd /c " + daysim.summary + "daysim_summaries.cmd"
	status = RunProgram(command_line,{{"Maximize", "True"}})

endMacro

//EI_Passenger, Truck, 4TCV Models
Macro "EI_Passenger_Model"
shared mvw, outdir, skim, tazvec, od, info

eivw = OpenTable("ExtInt", "DBASE", {od.countfile, })
jnvw = JoinViews(mvw.taz + eivw, mvw.taz+".ID", eivw+".ID1", null)
{EI_CNT, BASE_A, SEED_A} = GetDataVectors(jnvw+"|",{"EI_PASS", "BASE_ATR", "SEED_ATR"},{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})

//EI_Gen = 22.8865*Pow(tazvec.TotEmp,0.5) + 0.2752*tazvec.HH + 0.34456*tazvec.FDL
EI_Gen = if tazvec.ID < 1000 then max(337.826 - 28.8085*tazvec.GenAccess + 3.3727*Pow(tazvec.TOTEMP,0.5) + 0.6764*tazvec.FDL, 0) else 0
SCEN_A = EI_Gen

if info.scenname = "Base" and info.modyear = 2019 then do // update 2014 to 2019 --YS
	SetDataVectors(jnvw + "|", {{"BASE_ATR",SCEN_A} }, {{"Sort Order",{{"ID","Ascending"}}}})
end

	//Pivot Attraction Vector
	Multi_A  = nz(SEED_A*(SCEN_A/BASE_A))
	Add_A    = nz(SEED_A+(SCEN_A-BASE_A))
	Factor_A = nz(SCEN_A/BASE_A)
	Split_A  = (Factor_A - 0.5)*Add_A + (1.5 - Factor_A)*Multi_A

	Pivot_A = if SEED_A = null then 0
		else if Factor_A < 0.5 then max(Multi_A,0)
		else if Factor_A > 1.5 then max(Add_A,0)
		else max(Split_A,0)

	Growth_A = max(nz(Pivot_A) - nz(SEED_A),0)

	//EI_Counts (add pivot growth if not base year)
	EIPass_P = nz(EI_CNT)/2 + Growth_A

//Distribution
	eipassfile = outdir.ext+"EI_Passenger.bin"

	eipassvw = CreateTable("eipass", eipassfile, "FFB", {
						{"ID", "Integer", 10, null, "No"},
						{"EI_Gen", "Real", 10, 2, "No"},
						{"EI_Pivot", "Real", 10, 2, "No"},
						{"EI_O", "Real", 10, 2, "No"},
						{"EI_D", "Real", 10, 2, "No"},
						{"EI_OD", "Real", 10, 2, "No"}
						})

linecount = VectorStatistic(tazvec.ID, "Count", )
r = AddRecords(eipassvw, null, null, {{"Empty Records", linecount}})

SetDataVectors(eipassvw + "|", {{"ID",tazvec.ID}, {"EI_Gen",EI_Gen}, {"EI_Pivot",SEED_A}, {"EI_O",EIPass_P}, {"EI_D",Pivot_A} }, {{"Sort Order",{{"ID","Ascending"}}}})


// Balance A to Ps
     RunMacro("TCB Init")
     Opts = null
     Opts.Input.[Data View Set] = {eipassfile, eipassvw}
	 Opts.Input.[V2 Holding Sets] = {{eipassfile, "eipass", "Externals", "Select * where ID > 1000"}}
     Opts.Field.[Vector 1] = {eipassvw+".EI_O"}
     Opts.Field.[Vector 2] = {eipassvw+".EI_D"}
	 ok = RunMacro("TCB Run Procedure", "Balance", Opts, null)
	 if !ok then Return( RunMacro("TCB Closing", ok, True ) )


{BalO, BalD} = GetDataVectors(eipassvw+"|",{"EI_O", "EI_D"},{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})
BalOD = BalO + BalD
SetDataVectors(eipassvw + "|", {{"EI_OD",BalOD} }, {{"Sort Order",{{"ID","Ascending"}}}})


//Fratar
//In Base Year: EI_Fratar = Seed
//In Scen Year: EI_Fratar = Seed + Pivot_Vector

	//tempmtx = GetTempFileName(".mtx")
	tempmtx = outdir.ext + "temp.mtx"

	RunMacro("TCB Init")
    Opts = null
    Opts.Input.[Base Matrix Currency] = {od.eiseed, "EI_Pass", "Row ID's", "Col ID's"}
    Opts.Input.[PA View Set] = {eipassfile, "eipass"}
    Opts.Global.[Constraint Type] = "Doubly"
    Opts.Global.Iterations = 100
    Opts.Global.Convergence = 0.001
    Opts.Field.[Core Names Used] = {"EI_Pass"}
    Opts.Field.[P Core Fields] = {"eipass.EI_OD"}
    Opts.Field.[A Core Fields] = {"eipass.EI_OD"}
    Opts.Output.[Output Matrix].Label = "Scaled EI_Pass"
    Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = od.eiauto
    ok = RunMacro("TCB Run Procedure", "Growth Factor", Opts, null)
	if !ok then Return( RunMacro("TCB Closing", ok, True ) )


// Add EI trips to OD matrix
	eiauto = OpenMatrix(od.eiauto,)
	eipass = RunMacro("CheckMatrixCore", eiauto, "EI_Pass", null, null)
	cnames = {"AM_EIPASS", "PM_EIPASS", "OP_EIPASS"}
	for i = 1 to cnames.length do mc = RunMacro("CheckMatrixCore", eiauto, cnames[i], null, null) end

	ei = CreateMatrixCurrencies(eiauto,null,null,null)
	ei.AM_EIPASS := nz(eipass)*0.1980
	ei.PM_EIPASS := nz(eipass)*0.2744
	ei.OP_EIPASS := nz(eipass)*0.5276
endMacro

Macro "Truck_Model"
shared outdir, mvw, skim, od, info
shared tazvec

//{tazvec.ID, tazvec.TAZArea, tazvec.HH, tazvec.TOTPOP, tazvec.UNIV , tazvec.SCHL, tazvec.BAS, tazvec.IND , tazvec.RET , tazvec.FDL , tazvec.PRO , tazvec.OSV}

//Read in Externals Table
	eivw = OpenTable("ExtInt", "DBASE", {od.countfile, })
	jnvw = JoinViews(mvw.taz + eivw, mvw.taz+".ID", eivw+".ID1", null)
	{extvec.EI_SUT_P, extvec.EI_MUT_P} = GetDataVectors(jnvw+"|",{"EI_SUT", "EI_MUT"},{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})

//Generation
SUT_Gen = 0.9830*tazvec.BAS + 2.4290*tazvec.IND + 1.6000*tazvec.RET + 0.3000*tazvec.SRVC + 0.0080*tazvec.HH
MUT_Gen = tazvec.TOTEMP * 0.1276 - tazvec.PRO * 0.1177 + tazvec.IND * 0.0823

//Pseudo EI Split
	II_SUT_Gen = 0.1601 * SUT_Gen
	EI_SUT_Gen = 0.8399 * SUT_Gen
	EI_SUT_Sum = VectorStatistic(EI_SUT_Gen, "Sum", )

	II_MUT_Gen = 0.0782 * MUT_Gen
	EI_MUT_Gen = 0.9218 * MUT_Gen
	EI_MUT_Sum = VectorStatistic(EI_MUT_Gen, "Sum", )

//Pre-balance EI for Attractions
	SUT_Count = VectorStatistic(extvec.EI_SUT_P/2, "Sum", )
	MUT_Count = VectorStatistic(extvec.EI_MUT_P/2, "Sum", )
	EI_SUT_A = EI_SUT_Gen * (SUT_Count/EI_SUT_Sum)
	EI_MUT_A = EI_MUT_Gen * (MUT_Count/EI_MUT_Sum)

//Distribution
	//Create PA table
trkpafile = outdir.truck+"Truck_PA.bin"
trkpavw = CreateTable("trkpa"  , trkpafile,"FFB",
				{   {"ID"     , "Integer", 10  , null, "No"},
					{"SU_Trks" , "Integer", 10  , 3   , "No"},
					{"MU_Trks" , "Integer", 10  , 3   , "No"},
					{"II_SUT_O", "Real"   , 8   , 3   , "No"},
					{"II_SUT_D", "Real"   , 8   , 3   , "No"},
					{"II_MUT_O", "Real"   , 8   , 3   , "No"},
					{"II_MUT_D", "Real"   , 8   , 3   , "No"},
					{"EI_SUT_P", "Real"   , 8   , 3   , "No"},
					{"EI_SUT_A", "Real"   , 8   , 3   , "No"},
					{"EI_MUT_P", "Real"   , 8   , 3   , "No"},
					{"EI_MUT_A", "Real"   , 8   , 3   , "No"}

				})

linecount = VectorStatistic(tazvec.ID, "Count", )
r = AddRecords(trkpavw, null, null, {{"Empty Records", linecount}})

SetDataVectors(trkpavw + "|", {{"ID",tazvec.ID}, {"SU_Trks",SUT_Gen}, {"MU_Trks",MUT_Gen},
								{"II_SUT_O",II_SUT_Gen}, {"II_SUT_D",II_SUT_Gen},
								{"II_MUT_O",II_MUT_Gen}, {"II_MUT_D",II_MUT_Gen},
								{"EI_SUT_P",extvec.EI_SUT_P/2}, {"EI_SUT_A",EI_SUT_A},
								{"EI_MUT_P",extvec.EI_MUT_P/2}, {"EI_MUT_A",EI_MUT_A}
							}, {{"Sort Order",{{"ID","Ascending"}}}})

// ----- BALANCING ------
     RunMacro("TCB Init")
     Opts = null
     Opts.Input.[Data View Set] = {trkpafile, trkpavw}
	 Opts.Input.[V2 Holding Sets] = {{trkpafile, "trkpa", "Externals", "Select * where ID > 1000"}, {trkpafile, "trkpa", "Externals"}, {trkpafile, "trkpa", "Externals"}, {trkpafile, "trkpa", "Externals"}}
     Opts.Field.[Vector 1] = {trkpavw+".II_SUT_O", trkpavw+".II_MUT_O", trkpavw+".EI_SUT_P", trkpavw+".EI_MUT_P"}
     Opts.Field.[Vector 2] = {trkpavw+".II_SUT_D", trkpavw+".II_MUT_D", trkpavw+".EI_SUT_A", trkpavw+".EI_MUT_A"}
     if !RunMacro("TCB Run Procedure", 1, "Balance", Opts) then Return(RunMacro("TCB Closing", 0))


// ----- TRUCK TRIP DISTRIBUTION ------
     // Create K factor matrices for OD portion of utilities (except straight impedance)
	 CopyFile(skim.default, skim.truck)
	kmat = OpenMatrix(skim.truck, "Auto")

	//River Crossing
	mcriv = RunMacro("CheckMatrixCore", kmat, "riverx (Skim)", "Origin", "Destination",)

	//Intrazonal 1s
	mciz  = RunMacro("CheckMatrixCore", kmat, "IZ"           , "Origin", "Destination",)
	mciz := 0
	v1 = Vector(mciz.cols, "float", {{"Constant", 1}})
	SetMatrixVector(mciz, v1, {{"Diagonal"}})

	//k Factors for ISUT, IMUT, ESUT, EMUT
	mckIS = RunMacro("CheckMatrixCore", kmat, "kIS", "Origin", "Destination",)
	mckIM = RunMacro("CheckMatrixCore", kmat, "kIM", "Origin", "Destination",)
	mckES = RunMacro("CheckMatrixCore", kmat, "kES", "Origin", "Destination",)
	mckEM = RunMacro("CheckMatrixCore", kmat, "kEM", "Origin", "Destination",)

     // TAZ portion of utilities
     k_IS = exp(-0.4923*tazvec.GenAccess)    //exp(trkparam.ISGA.value*GenAccess)
     k_IM = exp(-1.5682*tazvec.GenAccess)    //exp(trkparam.ESGA.value*GenAccess)
     k_ES = exp(2.7671*tazvec.GenAccess)     //exp(trkparam.IMGA.value*GenAccess)
     k_EM = exp(-1.5518*tazvec.GenAccess)    //exp(trkparam.EMGA.value*GenAccess)

     // Exponentiated utilities (less any straight impedance component) by adding OD elements to TAZ component
     mckIS := k_IS * exp(-0.8625*mcriv + -1.4781*mciz)	//k_IS * exp(trkparam.ISOR.value*mcriv + trkparam.ISIZ.value*mciz)
     mckIM := k_IM * exp(3.1263*mcriv  + -5.3620*mciz)	//k_IM * exp(trkparam.IMOR.value*mcriv + trkparam.IMIZ.value*mciz)
     mckES := k_ES * exp(-0.8282*mcriv + -1.0657*mciz)	//k_ES * exp(trkparam.ESOR.value*mcriv + trkparam.ESIZ.value*mciz)
     mckEM := k_EM * exp(2.2265*mcriv  + 4.7372*mciz)	//k_EM * exp(trkparam.EMOR.value*mcriv + trkparam.EMIZ.value*mciz)

	//Run Gravity Model to get PAs
	RunMacro("TCB Init")
	Opts = null
	Opts.Input.[PA View Set] = {trkpafile, trkpavw}
	Opts.Input.[FF Matrix Currencies] = {null, null, null, null}
	Opts.Input.[Imp Matrix Currencies] = { {skim.truck, "gctts", "Origin", "Destination"}, {skim.truck, "gcttm", "Origin", "Destination"}, {skim.truck, "gctts", "Origin", "Destination"}, {skim.truck, "gcttm", "Origin", "Destination"} }
    Opts.Input.[KF Matrix Currencies] = {{skim.truck, "kIS", "Origin", "Destination"}, {skim.truck, "kIM", "Origin", "Destination"}, {skim.truck, "kES", "Origin", "Destination"}, {skim.truck, "kEM", "Origin", "Destination"}}
	Opts.Field.[Prod Fields]      = {trkpavw+".II_SUT_O", trkpavw+".II_MUT_O", trkpavw+".EI_SUT_P", trkpavw+".EI_MUT_P"}
	Opts.Field.[Attr Fields]      = {trkpavw+".II_SUT_D", trkpavw+".II_MUT_D", trkpavw+".EI_SUT_A", trkpavw+".EI_MUT_A"}
	Opts.Global.[Purpose Names]   = {"II_SUT"           , "II_MUT"           , "EI_SUT"           , "EI_MUT"}
	Opts.Global.Iterations        = {500                , 500                , 500                , 500}
	Opts.Global.Convergence       = {0.001              , 0.001              , 0.001              , 0.001}
	Opts.Global.[Constraint Type] = {"Double"           , "Double"           , "Double"           , "Double"}
	Opts.Global.[Fric Factor Type]= {"Exponential"      , "Exponential"      , "Exponential"      , "Exponential"}
	Opts.Global.[A List]          = {1                  , 1                  , 1                  , 1}
	Opts.Global.[B List]          = {0.3                , 0.3                , 0.3                , 0.3}
	Opts.Global.[C List]          = {0.9713             , 0.3126             , 0.7141             , 0.0297} //{trkparam.ISTT.value, trkparam.IMTT.value, trkparam.ESTT.value, trkparam.EMTT.value}  // Remember these are -1*
	Opts.Flag.[Use K Factors]     = {1                  , 1                  , 1                  , 1}
	Opts.Flag.[Post Process] = "False"
	Opts.Output.[Output Matrix].Label = "Truck Trip Matrix"
	Opts.Output.[Output Matrix].Type = "Float"
	Opts.Output.[Output Matrix].[File based] = "FALSE"
	Opts.Output.[Output Matrix].Sparse = "False"
	Opts.Output.[Output Matrix].[Column Major] = "False"
	Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = outdir.truck + "Truck_Gravity.mtx"

    ok = RunMacro("TCB Run Procedure", "Gravity", Opts, &Ret)
    if !ok then Return(RunMacro("TCB Closing", ok, True))
	CloseView(trkpavw)

//PA to OD by Averaging with Transpose
	CopyFile(outdir.truck+"Truck_Gravity.mtx", od.trk)
	trkPA = OpenMatrix(outdir.truck+"Truck_Gravity.mtx",)
	trkOD = OpenMatrix(od.trk,)
	tempmtx = GetTempFileName(".mtx")
	trktrans = TransposeMatrix(trkPA, {{"File Name", tempmtx}, {"Label", "Transpose"}, {"Type", "Double"}, {"Sparse", "No"}, {"Column Major", "No"}, {"File Based", "Yes"}, {"Compression", 1}})

	mcEISUT  = CreateMatrixCurrency(trkOD   , "EI_SUT", null, null, null)
	mcEISUTt = CreateMatrixCurrency(trktrans, "EI_SUT", null, null, null)
	mcEISUT := (mcEISUT + mcEISUTt)/2

	mcEIMUT  = CreateMatrixCurrency(trkOD   , "EI_MUT", null, null, null)
	mcEIMUTt = CreateMatrixCurrency(trktrans, "EI_MUT", null, null, null)
	mcEIMUT := (mcEIMUT + mcEIMUTt)/2

	//Sum II & EI Trips
	mcIISUT = CreateMatrixCurrency(trkOD, "II_SUT", null, null, )
	mcTotSUT = RunMacro("CheckMatrixCore", trkOD, "Total_SUT", null, null)
	mcTotSUT := mcIISUT + mcEISUT

	mcIIMUT = CreateMatrixCurrency(trkOD, "II_MUT", null, null, )
	mcTotMUT = RunMacro("CheckMatrixCore", trkOD, "Total_MUT", null, null)
	mcTotMUT := mcIIMUT + mcEIMUT

	//Pivot SUT/MUT using AirSage data
	SeedMtx = OpenMatrix(od.trkseed, "Auto")
		mcSeedSUT = RunMacro("CheckMatrixCore", SeedMtx, "SUTrk", null, null)
		mcSeedMUT = RunMacro("CheckMatrixCore", SeedMtx, "MUTrk", null, null)
		mcBaseSUT = RunMacro("CheckMatrixCore", SeedMtx, "SUT_Base", null, null)
		mcBaseMUT = RunMacro("CheckMatrixCore", SeedMtx, "MUT_Base", null, null)

	if info.scenname = "Base" and info.modyear = 2019 then do // update 2014 to 2019 --YS
		mcBaseSUT := mcTotSUT
		mcBaseMUT := mcTotMUT
	end

	mcPivotSUT = RunMacro("CheckMatrixCore", trkOD, "SUT_Pivot", null, null)
	mcPivotMUT = RunMacro("CheckMatrixCore", trkOD, "MUT_Pivot", null, null)
	mcPivotSUT = RunMacro("PivotMtx", od.trk, mcBaseSUT, mcSeedSUT, mcTotSUT, mcPivotSUT, null, 5.0)
	mcPivotMUT = RunMacro("PivotMtx", od.trk, mcBaseMUT, mcSeedMUT, mcTotMUT, mcPivotMUT, null, 5.0)

 // Apply time-of-day factors
	 cnames = {"AM_SUT", "PM_SUT", "OP_SUT", "AM_MUT", "PM_MUT", "OP_MUT"}
     for i = 1 to cnames.length do mc = RunMacro("CheckMatrixCore", trkOD, cnames[i], null, null) end

	 trks = CreateMatrixCurrencies(trkOD,null,null,null)
	 trks.AM_SUT :=	mcPivotSUT*0.1980
	 trks.PM_SUT :=	mcPivotSUT*0.2744
	 trks.OP_SUT :=	mcPivotSUT*0.5276

	 trks.AM_MUT :=	mcPivotMUT*0.1980
	 trks.PM_MUT :=	mcPivotMUT*0.2744
	 trks.OP_MUT := mcPivotMUT*0.5276

endMacro

Macro "4TCV_Model"
shared mvw, outdir, skim, tazvec, od

//{tazvec.ID, tazvec.TAZArea, tazvec.HH, tazvec.TOTPOP, tazvec.UNIV , tazvec.SCHL, tazvec.BAS, tazvec.IND , tazvec.RET , tazvec.FDL , tazvec.PRO , tazvec.OSV}

//Generation
CV_ADJFACTOR = 0.10
CV_Gen = 1.110*tazvec.BAS + 0.938*tazvec.IND + 0.888*tazvec.RET + 0.437*tazvec.SRVC + 0.251*tazvec.HH

CV_O = nz(CV_Gen) * CV_ADJFACTOR
CV_D = nz(CV_Gen) * CV_ADJFACTOR

/*
//Pseudo EI Split
	II_SUT_Gen = 0.1601 * SUT_Gen
	EI_SUT_Gen = 0.8399 * SUT_Gen
	EI_SUT_Sum = VectorStatistic(EI_SUT_Gen, "Sum", )

	II_MUT_Gen = 0.0782 * MUT_Gen
	EI_MUT_Gen = 0.9218 * MUT_Gen
	EI_MUT_Sum = VectorStatistic(EI_MUT_Gen, "Sum", )

//Pre-balance EI for Attractions
	SUT_Count = VectorStatistic(extvec.EI_SUT_P, "Sum", )
	MUT_Count = VectorStatistic(extvec.EI_MUT_P, "Sum", )
	EI_SUT_A = EI_SUT_Gen * (SUT_Count/EI_SUT_Sum)
	EI_MUT_A = EI_MUT_Gen * (MUT_Count/EI_MUT_Sum)
*/

//Distribution
	cvgenfile = outdir.truck+"CVTripGen.bin"

	cvpavw = CreateTable("cvpa", cvgenfile, "FFB", {
						{"ID", "Integer", 10, null, "No"},
						{"CV_Gen", "Integer", 10, null, "No"},
						{"CV_II_O", "Real", 10, 2, "No"},
						{"CV_II_D", "Real", 10, 2, "No"},
						{"CV_YY_O", "Real", 10, 2, "No"},
						{"CV_YY_D", "Real", 10, 2, "No"}
						})

linecount = VectorStatistic(tazvec.ID, "Count", )
r = AddRecords(cvpavw, null, null, {{"Empty Records", linecount}})

SetDataVectors(cvpavw + "|", {{"ID",tazvec.ID},
								{"CV_Gen",CV_Gen},
								{"CV_II_O",CV_O},
								{"CV_II_D",CV_D},
								{"CV_YY_O",CV_O},
								{"CV_YY_D",CV_D}
							}, {{"Sort Order",{{"ID","Ascending"}}}})

// ----- BALANCING ------
     RunMacro("TCB Init")
     Opts = null
     Opts.Input.[Data View Set] = {cvgenfile, cvpavw}
	 Opts.Input.[V1 Holding Sets] = {{cvgenfile, "cvpa", "Externals", "Select * where ID > 1000"}}
	 Opts.Input.[V2 Holding Sets] = {{cvgenfile, "cvpa", "Externals", "Select * where ID > 1000"}}
     Opts.Field.[Vector 1] = {cvpavw+".CV_II_O"}
     Opts.Field.[Vector 2] = {cvpavw+".CV_II_D"}
	 Opts.Global.[Holding Method] = {"Weighted Sum"}
	 Opts.Global.[Percent Weight] = {50}
	 Opts.Global.[Store Type] = "Real"
     if !RunMacro("TCB Run Procedure", 1, "Balance", Opts) then Return(RunMacro("TCB Closing", 0))

// ----- CV TRIP DISTRIBUTION ------
     // Create K factor matrices for OD portion of utilities (except straight impedance)
	 CopyFile(skim.default, skim.cv)
	 kmat = OpenMatrix(skim.cv, "Auto")

	//River Crossing
	mcriv = RunMacro("CheckMatrixCore", kmat, "riverx (Skim)", "Origin", "Destination",)

	//Intrazonal 1s
	mciz  = RunMacro("CheckMatrixCore", kmat, "IZ"           , "Origin", "Destination",)
	mciz := 0
	v1 = Vector(mciz.cols, "float", {{"Constant", 1}})
	SetMatrixVector(mciz, v1, {{"Diagonal"}})

     // TAZ portion of utilities
	 mckCV = RunMacro("CheckMatrixCore", kmat, "kCV"          , "Origin", "Destination",)
     k_CV = exp(-0.4923*tazvec.GenAccess)

     // Exponentiated utilities (less any straight impedance component) by adding OD elements to TAZ component
     mckCV := k_CV * exp(-0.8625*mcriv + -1.4781*mciz)

	//Run Gravity Model to get PAs
	RunMacro("TCB Init")
	Opts = null
	Opts.Input.[PA View Set] = {cvgenfile, cvpavw}
	Opts.Input.[FF Matrix Currencies] = {null}
	Opts.Input.[Imp Matrix Currencies] = {{skim.cv, "gctta", "Origin", "Destination"}}
    Opts.Input.[KF Matrix Currencies] = {{skim.cv, "kCV", "Origin", "Destination"}}
	Opts.Field.[Prod Fields]      = {cvpavw+".CV_II_O"}
	Opts.Field.[Attr Fields]      = {cvpavw+".CV_II_D"}
	Opts.Global.[Purpose Names]   = {"CV_II"     }
	Opts.Global.Iterations        = {500          }
	Opts.Global.Convergence       = {0.001        }
	Opts.Global.[Constraint Type] = {"Double"     }
	Opts.Global.[Fric Factor Type]= {"Exponential"}
	Opts.Global.[A List]          = {1            }
	Opts.Global.[B List]          = {0.3          }
	Opts.Global.[C List]          = {0.9713       }
	Opts.Flag.[Use K Factors]     = {1            }
	Opts.Flag.[Post Process] = "False"
	Opts.Output.[Output Matrix].Label = "CV Trip Matrix"
	Opts.Output.[Output Matrix].Type = "Float"
	Opts.Output.[Output Matrix].[File based] = "FALSE"
	Opts.Output.[Output Matrix].Sparse = "False"
	Opts.Output.[Output Matrix].[Column Major] = "False"
	Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = outdir.truck + "CV_Gravity.mtx"

    ok = RunMacro("TCB Run Procedure", "Gravity", Opts, &Ret)
    if !ok then Return(RunMacro("TCB Closing", ok, True))
	CloseView(cvpavw)

//PA to OD by Averaging with Transpose
	CopyFile(outdir.truck+"CV_Gravity.mtx", od.cv)
	cvPA = OpenMatrix(outdir.truck+"CV_Gravity.mtx",)
	cvOD = OpenMatrix(od.cv,)
	tempmtx = GetTempFileName(".mtx")
	cvtrans = TransposeMatrix(cvPA, {{"File Name", tempmtx}, {"Label", "Transpose"}, {"Type", "Double"}, {"Sparse", "No"}, {"Column Major", "No"}, {"File Based", "Yes"}, {"Compression", 1}})

	mcCV  = CreateMatrixCurrency(cvOD   , "CV_II", null, null, null)
	mcCVt = CreateMatrixCurrency(cvtrans, "CV_II", null, null, null)
	mcCV := (mcCV + mcCVt)/2

  //Combine EE trips here if not preloading

	//Pivot 4TCV
	cvseedmat = OpenMatrix(od.cvseed, "Auto")
	mccvseed = RunMacro("CheckMatrixCore", cvseedmat, "CV_Seed", null, null)
	mccvbase = RunMacro("CheckMatrixCore", cvseedmat, "CV_Base", null, null)
	mcPivotCV = RunMacro("CheckMatrixCore", cvOD, "CV_Pivot", null, null)

	if info.scenname = "Base" and info.modyear = 2019 then do // update 2014 to 2019 --YS
		mccvbase := mcCV
	end

	RunMacro("PivotMtx", skim.cv, mccvbase, mccvseed, mcCV, mcPivotCV, null, 1.5)

 // Apply time-of-day factors
	 cnames = {"AM_CV", "PM_CV", "OP_CV"}
     for i = 1 to cnames.length do mc = RunMacro("CheckMatrixCore", cvOD, cnames[i], null, null) end

	 cv = CreateMatrixCurrencies(cvOD,null,null,null)
	 cv.AM_CV :=	mcPivotCV*0.1980
	 cv.PM_CV :=	mcPivotCV*0.2744
	 cv.OP_CV :=	mcPivotCV*0.5276

endMacro


//Pivoting
Macro "PivotMtx" (mtxfile, mcBASE, mcSEED, mcINPUT, mcOUTPUT, index, k2)
  mtxvw = OpenMatrix(mtxfile,)

  k1 = 0.5
  //k2 = 5.0	//auto = 1.5 ; trucks = 5.0
  ZEROmc = RunMacro("CheckMatrixCore", mtxvw, "Zeros", index, index)
  X1 = RunMacro("CheckMatrixCore", mtxvw, "X1", index, index)
  X2 = RunMacro("CheckMatrixCore", mtxvw, "X2", index, index)
  ZEROmc := 0.01
  X1 := if mcBASE > 0.001 then k2*mcBASE else 0
  //X2 := if mcSEED > 0.001 and mcBASE > 0.001 then k1*mcBASE + k2*mcBASE * max(mcBASE/mcSEED,k1/k2) else 0
  X2 := if mcBASE > 0.001 then k2*mcBASE else 0

   // Implementation of simplified 8-case pivoting a la RAND (Enhancement of the pivot point process used in the Sydney Strategic Model, James Fox, Andrew Daly, Bhanu Patruni, 2012)
   mcOUTPUT := 0																													// Cases 1, 3, 7
   mcOUTPUT := if mcINPUT <= ZEROmc and mcBASE <= ZEROmc then mcSEED else mcOUTPUT													// Case 5
   mcOUTPUT := if mcINPUT > ZEROmc and mcBASE <= ZEROmc then nz(mcSEED) + nz(mcINPUT) else mcOUTPUT								// Cases 2 & 6
   mcOUTPUT := if mcINPUT > ZEROmc and mcBASE > ZEROmc and mcSEED <= ZEROmc then max(0,(mcINPUT - mcBASE)) else mcOUTPUT				// Case 4 (as modified by RSG)
   mcOUTPUT := if mcINPUT > ZEROmc and mcBASE > ZEROmc and mcSEED > ZEROmc and mcINPUT <= X1 then mcSEED*(mcINPUT / mcBASE) else mcOUTPUT	// Case 8a
   mcOUTPUT := if mcINPUT > ZEROmc and mcBASE > ZEROmc and mcSEED > ZEROmc and mcINPUT >= X1 then mcSEED*X2/mcBASE + (mcINPUT - X2) else mcOUTPUT //Case 8e

Return(mcOUTPUT)
endMacro
