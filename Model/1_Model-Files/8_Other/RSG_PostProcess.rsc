//Model Post Processor
Macro "Post_Process" (tazvw, linevw, netparam, parampath, reppath, yearid, domoves)
shared post
	if domoves = 1 then do
		post.movesauto      = reppath + "MOVES\\MOVES_Auto.dbf"
		post.movessut       = reppath + "MOVES\\MOVES_SUT.dbf"
		post.movesmut       = reppath + "MOVES\\MOVES_MUT.dbf"
		post.movesspd       = reppath + "MOVES\\MOVES_HAVGSPD.dbf"
		post.movesbin       = reppath + "MOVES\\MOVES_SPDBIN.dbf"
	end
	
	post.outlink        = reppath + "post_links.dbf"
	post.outnode        = reppath + "post_node.dbf"
	post.outrep         = reppath + "post_report.dbf"
	nodevw   = GetNodeLayer(linevw)
	
/*
	// Convert _trip_2.dat
	tripdat = outdir.daysim + "_trip_2.dat"
	tripbin = outdir.daysim + "_trip_2.bin"
	tripvw = RunMacro("dat2bin", tripdat, tripbin)

	// Convert _person_2.dat
	perdat = outdir.daysim + "_person_2.dat"
	perbin = outdir.daysim + "_person_2.bin"
	personvw = RunMacro("dat2bin", perdat, perbin)
	
	RunMacro("exportsummary", tripbin, perbin, reppath)
*/	

	RunMacro("PostCalc", linevw, nodevw)	
	{outlinkvw, outnodevw} = RunMacro("postalt", linevw, nodevw, netparam, parampath, yearid, domoves)
	RunMacro("PostRep", tazvw, linevw, nodevw, parampath, outlinkvw, outnodevw, reppath)
	
	
	//Clean up network
	SetView(linevw)
	RunMacro("dropfields", linevw, {"FACTYPE"})
	RunMacro("dropfields", linevw, {"WalkLink","LinkTTF ","WalkTime","TransitTimeAM_AB","TransitTimeAM_BA","TransitTimePM_AB","TransitTimePM_BA","TransitTimeOP_AB","TransitTimeOP_BA","AB_AMTime","BA_AMTime","AB_PMTime","BA_PMTime","AB_OPTime","BA_OPTime","DLYPrePCE","AMPrePCE","PMPrePCE","OPPrePCE","AbsErr","Error"})
	RunMacro("dropfields", linevw, {"AB_dlycgtime","BA_dlycgtime","AB_dlycgspd","BA_dlycgspd","AB_pktime","BA_pktime","AB_pkspeed","BA_pkspeed","TOTSUTFlow","TOTMUTFlow"})
    RunMacro("dropfields", linevw, {"AB_ADJ_AUTO","BA_ADJ_AUTO","TOT_ADJ_AUTO","AB_ADJ_TRK","BA_ADJ_TRK","TOT_ADJ_TRK","AB_ADJ_SUT","BA_ADJ_SUT","TOT_ADJ_SUT","AB_ADJ_MUT","BA_ADJ_MUT","TOT_ADJ_MUT","AB_ADJ_TOT","BA_ADJ_TOT","TOT_ADJ_TOT"})

	RunMacro("dropfields", linevw, {"AB_PRE", "BA_PRE"})
	RunMacro("dropfields", linevw, {"HSMclass", "xVMT", "Crashes_I_Tot", "Crashes_I_F", "Crashes_I_I", "Crashes_I_P"})
	RunMacro("dropfields", linevw, {"Crashes_RM_Tot", "Crashes_RM_F", "Crashes_RM_I", "Crashes_RM_P"})
	RunMacro("dropfields", linevw, {"Crashes_R2_Tot", "Crashes_R2_F", "Crashes_R2_I", "Crashes_R2_P"})
	RunMacro("dropfields", linevw, {"Crashes_U_Tot", "Crashes_U_F", "Crashes_U_I", "Crashes_U_P"})
	RunMacro("dropfields", linevw, {"Crashes_Tot", "Crashes_F", "Crashes_I", "Crashes_P"})
	
	SetView(nodevw)
	RunMacro("dropfields", nodevw, {"HSMclass", "Crashes_2L_Tot", "Crashes_2L_F", "Crashes_2L_I", "Crashes_2L_P"})
	RunMacro("dropfields", nodevw, {"Crashes_ML_Tot", "Crashes_ML_F", "Crashes_ML_I", "Crashes_ML_P"})
	RunMacro("dropfields", nodevw, {"Crashes_U_Tot", "Crashes_U_F", "Crashes_U_I", "Crashes_U_P"})
	RunMacro("dropfields", nodevw, {"Crashes_Tot", "Crashes_F", "Crashes_I", "Crashes_P"})
endmacro


Macro "exportsummary" (tripbin, perbin, reppath)
tripvw = OpenTable("Trip", "FFB", {tripbin, null})
pervw = OpenTable("Per", "FFB", {perbin, null})

// Prepare summaries for post processor from these files'
ppl_walk_bike = AggregateTable("Ppl_Walk_bike", tripvw + "|" , "CSV",  reppath+"Agg_Trips.csv", "mode", { {"id","count"} }, null)
CloseView(ppl_walk_bike)
ShowMessage("Close ppl_walk_bike")

pertripvw = JoinViewsMulti("Person Trips", {tripvw + ".hhno", tripvw + ".pno"}, {pervw + ".hhno", pervw + ".pno"},)
SetView(pertripvw)
//info_array = GetViewJoinInfo(pertripvw)
//Pagey is age field in person table
set = SelectByQuery("set", "Several", "Select * where pagey >= 20 and pagey <= 74", )
avg_walk = AggregateTable("Avg_Walk", pertripvw + "|set", "CSV",  reppath+"Avg_TripLen.csv", "mode", { {"travtime","average"} }, null)
endMacro

Macro "PostCalc" (linevw, nodevw)
SetView(nodevw)
RunMacro("addfields", nodevw, {"IntADT", "MaxADT", "MinADT"}, {r,r,r})

	//IntADT = Sum of BaseVol/2
	//MaxADT = Max(BaseVol)
	//MinADT = Min(BaseVol)
	
	FID = CreateNodeField(linevw, "A_Node", nodevw + ".ID", "From", )
	TID = CreateNodeField(linevw, "B_Node", nodevw + ".ID", "To", )

	fjoin = JoinViews("fjoin", nodevw+".ID", linevw+"."+FID, {{"A", }, {"Fields", { {"BaseVol", {{"Sum"},{"Max"},{"Min"}}} }} })
	{BVol, MaxVol, MinVol} = GetDataVectors(fjoin + "|", {"BaseVol", "High BaseVol", "Low BaseVol"}, {{"Sort Order",{{nodevw+".ID","Ascending"}}},{"Missing as Zero", "True"}})
	SetDataVectors(nodevw + "|", {{"IntADT",BVol},{"MinADT",MinVol},{"MaxADT",MaxVol}},{{"Sort Order",{{nodevw+".ID","Ascending"}}}})
	CloseView(fjoin)

	tjoin = JoinViews("tjoin", nodevw + ".ID", linevw + "." + TID, {{"A", }, {"Fields", { {"BaseVol", {{"Sum"},{"Max"},{"Min"}}} }} })
	{TBVol, TMaxVol, TMinVol} = GetDataVectors(tjoin + "|", {"BaseVol", "High BaseVol", "Low BaseVol"}, {{"Sort Order",{{nodevw+".ID","Ascending"}}},{"Missing as Zero", "True"}})
	SetDataVectors(nodevw + "|", {{"IntADT",(BVol+TBVol/2)},{"MinADT",Min(TMinVol,MinVol)},{"MaxADT",Max(TMaxVol,MaxVol)}},{{"Sort Order",{{nodevw+".ID","Ascending"}}}})
	CloseView(tjoin)

	arr = GetExpressions(linevw)
	for i = 1 to arr.length do DestroyExpression(linevw+"."+arr[i]) end
endMacro

Macro "postalt" (linevw, nodevw, netparam, parampath, yearid, domoves)
shared post
	// Calibration factors for crash statistics
	
	//--- Calibration factors -------------------
	
	calflag = 0
	
	// Calibration factors for Hamilton County links only .. rest are adjusted using the same factor - SB
	// https://www.tn.gov/assets/entities/safety/attachments/CrashType.pdf
	// 2010 data 40 fatal crashes, 2725 Injury, 7511 PDO - Hamilton county		// 09/27
	 CfFatal 	= 1.20		// 09/27
	 CfInjury 	= 1.79		// 09/27
	 CfPDO 		= 2.59		// 09/27

     Cfwy = 1       // Calibration factor for freeways
     CrxlF =  1		
     CrxlI =  1		
     CrxlP =  1		
     Cr2lF =  1         
     Cr2lI =  1
     Cr2lP =  1         
     CurbF =  1
     CurbI =  1
     CurbP =  1		 
     CrxliF = 1		
     CrxliI = 1		
     CrxliP = 1		
     Cr2liF = 1		
     Cr2liI = 1
     Cr2liP = 1		
     CurbiF = 1		
     CurbiI = 1
     CurbiP = 1		
     
	//--- Options -------------------
	
    OptRHATfwy = 0     // Option for using Road HAT base model for freeways 
    OptRHATR2L = 0     // Option for using Road HAT base model for rural two lane highways
    OptRHATRXL = 0     // Option for using Road HAT base model for rural multilane highways
    OptRHATUrb = 0     // Option for using Road HAT base model for urban streets
    OptRHATrurint = 0  // Option for using Road HAT base model for rural intersections
    OptRHATurbint = 0  // Option for using Road HAT base model for urban intersections
    OptRHATCMFonly = 0 // Option for using only Road HAT CMFs
	OptTTIR2L = 0	    // Option for using TTI baseline moded for rural two lane highways
	
	OptCMFtrk = 0 	    // Option for using Truck Percentage CMF on freeways
	OptCMFacc = 0	    // Option for using Access Control CMF on rural multilane highways
	OptCMFlwUA = 0     // Option for using TTI CMF for lane width for urban/suburban arterials
	OptCMFrswUA = 0    // Option for using TTI CMF for shoulder width for urban/suburban arterials
	OptCMFtrkUA = 0    // Option for using TTI CMF for truck percentage for urban/suburban arterials
	OptCMFlt = 1       // Option for using HSM CMF for lighting for urban/suburban arterials
	OptCMFtwltlIN = 0  // Option for using IN CMF for TWLTL
	OptCMFddIN = 0     // Option for using IN CMF for driveway density for urban/suburban arterials (only with OptRHATUrb)
	OptCMFlnwR2LIN = 0 // Option for using IN CMF for lane width rural two lane highways
	
	autofuelfile   = parampath + "FUELCOSTLOOKUP.DBF"
	autoemisfile   = parampath + "AUTOEMISRATE.DBF"
	truckemisfile  = parampath + "TRUCKEMISRATE.DBF"
	autofuelcostvw = OpenTable("autofuelcostvw","DBASE",{autofuelfile,})
	autoemisvw     = OpenTable("autoemisvw","DBASE",{autoemisfile,})
	truckemisvw    = OpenTable("truckemisvw","DBASE",{truckemisfile,})        
	//get daily distribution from auxiliary file
	todfile = parampath + "TNDOT24TOD.dbf"
	todvw = OpenTable("todvw", "DBASE", {todfile, })
	// Kept the Truck column in the DBF just in case we need it - SB
	{SPDCLASS,AUTOFUEL,TRUCKFUEL,SUTRUCKFUEL,MUTRUCKFUEL} = GetDataVectors(autofuelcostvw+"|",{"SPEED","AUTO","TRUCK","SUTRUCK","MUTRUCK"},null)
	{VEHCO,VEHCO2,VEHNOX,VEHPM10,VEHSOX,VEHVOC,VEHPM25} = GetDataVectors(autoemisvw+"|",{"CO","CO2","NOX","PM10","SOX","VOC","PM25"},null)
	{TRKCO,TRKCO2,TRKNOX,TRKPM10,TRKSOX,TRKVOC,TRKPM25} = GetDataVectors(truckemisvw+"|",{"CO","CO2","NOX","PM10","SOX","VOC","PM25"},null)
	
	{SUTRKCO,SUTRKCO2,SUTRKNOX,SUTRKPM10,SUTRKSOX,SUTRKVOC,SUTRKPM25} = GetDataVectors(truckemisvw+"|",{"CO_SU","CO2_SU","NOX_SU","PM10_SU","SOX_SU","VOC_SU","PM25_SU"},null)	//SB
	{MUTRKCO,MUTRKCO2,MUTRKNOX,MUTRKPM10,MUTRKSOX,MUTRKVOC,MUTRKPM25} = GetDataVectors(truckemisvw+"|",{"CO_MU","CO2_MU","NOX_MU","PM10_MU","SOX_MU","VOC_MU","PM25_MU"},null)	//SB
	
	{PER,CAR_RF,CAR_RO,CAR_UF,CAR_UO,SU_RF,SU_RO,SU_UF,SU_UO,MU_RF,MU_RO,MU_UF,MU_UO}=GetDataVectors(todvw+"|",{"PERIOD","CAR_RF","CAR_RO","CAR_UF","CAR_UO","SU_RF","SU_RO","SU_UF","SU_UO","MU_RF","MU_RO","MU_UF","MU_UO"},null)
	CloseView(todvw)
	CloseView(autofuelcostvw)
	CloseView(autoemisvw)
	CloseView(truckemisvw)
	// Work with node layer for now - SB
	SetView(nodevw)
	
	// Selection for intersections that are not centroids, have more than 2 links and have some sort of control (stop, signal, etc) in place - SB 
	n = SelectByQuery("Modn", "Several", "Select * where TAZID = null and Links > 2 and Control_IMP > 0 ",)

	// Intersection crashes output - SB
	outnodevw = CreateTable("Intersection Crash Report"  , post.outnode  , "dBase", 						// DBF MAX field name length = 10
							{{"ID1"        , "Integer", 10, null, "No"},      
							{"CrashesTot"  , "Real"   , 12, 2   , "No"},
							{"Crashes_F"   , "Real"   , 12, 2   , "No"},
							{"Crashes_I"   , "Real"   , 12, 2   , "No"},
							{"Crashes_P"   , "Real"   , 12, 2   , "No"}
							})
	
	//  Create empty table for nodes - SB
	{ID} 	= GetDataVectors(nodevw+"|Modn", {"ID"},{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})
	numnodes = VectorStatistic(ID, "Count", )
	r = AddRecords(outnodevw, null, null, {{"Empty Records", numnodes}})
	
	// Work with line view for here on - SB
	SetView(linevw)
	// Selection to exclude non-TN/CCs/unmodeled
	n = SelectByQuery("Mod", "Several", "Select * where FUNCCLASS > 0 and FUNCCLASS < 95 and STATE = 'TN'",)
	//n = SelectByQuery("Mod", "Several", "Select * where FUNCCLASS <> null and FUNCCLASS <> 99",)
	
	// Set all volumes less than 0 to 1 and adjust the totals
	{ID, BASEVOL_AB, BASEVOL_BA, SUTRK_AB, SUTRK_BA, MUTRK_AB, MUTRK_BA, CAR_AB, CAR_BA, VEH_AB, VEH_BA} = GetDataVectors(linevw+"|",
	{"ID","AB_BaseVol","BA_BaseVol","AB_SUT","BA_SUT","AB_MUT","BA_MUT","AB_AUTO","BA_AUTO","AB_TotFlow","BA_TotFlow"},{{"Sort Order",{{"ID","Ascending"}}}, {"Missing as Zero","False"}})

	{AB_AM_AUTO, BA_AM_AUTO, AB_AM_SUT,	BA_AM_SUT,	AB_AM_MUT,	BA_AM_MUT,	AB_AM_TotFlow,	BA_AM_TotFlow} = GetDataVectors(linevw+"|",
	{"AB_AM_Auto","BA_AM_Auto","AB_AM_SUT","BA_AM_SUT","AB_AM_MUT","BA_AM_MUT","AB_AM_TotFlow","BA_AM_TotFlow"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","False"}})

	{AB_PM_AUTO, BA_PM_AUTO, AB_PM_SUT,	BA_PM_SUT,	AB_PM_MUT,	BA_PM_MUT,	AB_PM_TotFlow,	BA_PM_TotFlow} = GetDataVectors(linevw+"|",
	{"AB_PM_Auto","BA_PM_Auto","AB_PM_SUT","BA_PM_SUT","AB_PM_MUT","BA_PM_MUT","AB_PM_TotFlow","BA_PM_TotFlow"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","False"}})
	
	{AB_OP_AUTO, BA_OP_AUTO, AB_OP_SUT,	BA_OP_SUT,	AB_OP_MUT,	BA_OP_MUT,	AB_OP_TotFlow,	BA_OP_TotFlow} = GetDataVectors(linevw+"|",
	{"AB_OP_Auto","BA_OP_Auto","AB_OP_SUT","BA_OP_SUT","AB_OP_MUT","BA_OP_MUT","AB_OP_TotFlow","BA_OP_TotFlow"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","False"}})
	
	BASEVOL_AB		= if (BASEVOL_AB < 1) then 0 else BASEVOL_AB
	BASEVOL_BA		= if (BASEVOL_BA < 1) then 0 else BASEVOL_BA
	SUTRK_AB		= if (SUTRK_AB < 1) then 0 else SUTRK_AB
	SUTRK_BA		= if (SUTRK_BA < 1) then 0 else SUTRK_BA
	MUTRK_AB		= if (MUTRK_AB < 1) then 0 else MUTRK_AB
	MUTRK_BA		= if (MUTRK_BA < 1) then 0 else MUTRK_BA
	CAR_AB			= if (CAR_AB < 1) then 0 else CAR_AB
	CAR_BA			= if (CAR_BA < 1) then 0 else CAR_BA
	VEH_AB			= if (VEH_AB < 1) then 0 else VEH_AB
	VEH_BA			= if (VEH_BA < 1) then 0 else VEH_BA
	AB_AM_AUTO		= if (AB_AM_AUTO < 1) then 0 else AB_AM_AUTO
	BA_AM_AUTO		= if (BA_AM_AUTO < 1) then 0 else BA_AM_AUTO
	AB_AM_SUT		= if (AB_AM_SUT < 1) then 0 else AB_AM_SUT
	BA_AM_SUT		= if (BA_AM_SUT < 1) then 0 else BA_AM_SUT
	AB_AM_MUT		= if (AB_AM_MUT < 1) then 0 else AB_AM_MUT
	BA_AM_MUT		= if (BA_AM_MUT < 1) then 0 else BA_AM_MUT
	AB_AM_TotFlow	= if (AB_AM_TotFlow < 1) then 0 else AB_AM_TotFlow
	BA_AM_TotFlow	= if (BA_AM_TotFlow < 1) then 0 else BA_AM_TotFlow
	AB_PM_AUTO		= if (AB_PM_AUTO < 1) then 0 else AB_PM_AUTO
	BA_PM_AUTO		= if (BA_PM_AUTO < 1) then 0 else BA_PM_AUTO
	AB_PM_SUT		= if (AB_PM_SUT < 1) then 0 else AB_PM_SUT
	BA_PM_SUT		= if (BA_PM_SUT < 1) then 0 else BA_PM_SUT
	AB_PM_MUT		= if (AB_PM_MUT < 1) then 0 else AB_PM_MUT
	BA_PM_MUT		= if (BA_PM_MUT < 1) then 0 else BA_PM_MUT
	AB_PM_TotFlow	= if (AB_PM_TotFlow < 1) then 0 else AB_PM_TotFlow
	BA_PM_TotFlow	= if (BA_PM_TotFlow < 1) then 0 else BA_PM_TotFlow
	AB_OP_AUTO		= if (AB_OP_AUTO < 1) then 0 else AB_OP_AUTO
	BA_OP_AUTO		= if (BA_OP_AUTO < 1) then 0 else BA_OP_AUTO
	AB_OP_SUT		= if (AB_OP_SUT < 1) then 0 else AB_OP_SUT
	BA_OP_SUT		= if (BA_OP_SUT < 1) then 0 else BA_OP_SUT
	AB_OP_MUT		= if (AB_OP_MUT < 1) then 0 else AB_OP_MUT
	BA_OP_MUT		= if (BA_OP_MUT < 1) then 0 else BA_OP_MUT
	AB_OP_TotFlow	= if (AB_OP_TotFlow < 1) then 0 else AB_OP_TotFlow
	BA_OP_TotFlow	= if (BA_OP_TotFlow < 1) then 0 else BA_OP_TotFlow
	//Recaltulate totals
	SUTRK 			= nz(SUTRK_AB) + nz(SUTRK_BA)
	MUTRK 			= nz(MUTRK_AB) + nz(MUTRK_BA)
	CAR 			= nz(CAR_AB) + nz(CAR_BA)
	VEH 			= nz(VEH_AB) + nz(VEH_BA)
	// AM and PM totals are calulated after period adjustments are made in the following code
	
	
	SetDataVectors(linevw+"|", {{"AB_SUT",SUTRK_AB},{"BA_SUT",SUTRK_BA},{"AB_MUT",MUTRK_AB},{"BA_MUT",MUTRK_BA},{"AB_AUTO",CAR_AB},{"BA_AUTO",CAR_BA},{"AB_TotFlow",VEH_AB},{"BA_TotFlow",VEH_BA},
	{"AB_AM_Auto",AB_AM_AUTO},{"BA_AM_Auto",BA_AM_AUTO},{"AB_AM_SUT",AB_AM_SUT},{"BA_AM_SUT",BA_AM_SUT},{"AB_AM_MUT",AB_AM_MUT},{"BA_AM_MUT",BA_AM_MUT},{"AB_AM_TotFlow",AB_AM_TotFlow},{"BA_AM_TotFlow",BA_AM_TotFlow},
	{"AB_PM_Auto",AB_PM_AUTO},{"BA_PM_Auto",BA_PM_AUTO},{"AB_PM_SUT",AB_PM_SUT},{"BA_PM_SUT",BA_PM_SUT},{"AB_PM_MUT",AB_PM_MUT},{"BA_PM_MUT",BA_PM_MUT},{"AB_PM_TotFlow",AB_PM_TotFlow},{"BA_PM_TotFlow",BA_PM_TotFlow},
	{"AB_OP_Auto",AB_OP_AUTO},{"BA_OP_Auto",BA_OP_AUTO},{"AB_OP_SUT",AB_OP_SUT},{"BA_OP_SUT",BA_OP_SUT},{"AB_OP_MUT",AB_OP_MUT},{"BA_OP_MUT",BA_OP_MUT},{"AB_OP_TotFlow",AB_OP_TotFlow},{"BA_OP_TotFlow",BA_OP_TotFlow},
	{"Tot_SUT",SUTRK},{"Tot_MUT",MUTRK},{"Tot_Auto",CAR},{"TotFlow",VEH}},
	{{"Sort Order",{{"ID","Ascending"}}}})
	
	// if AM + PM is greater than total (by vehicle class and direction) then adjust .. this is due to different congestion in periods
	n = SelectByQuery("Selection", "Several", "Select * where (AB_AM_Auto + AB_PM_Auto + AB_OP_Auto) > AB_Auto",)
	if n > 0 then do
		amx = CreateExpression(linevw, "amx", "AB_AM_Auto * (AB_Auto/(AB_AM_Auto + AB_PM_Auto + AB_OP_Auto))", )
		pmx = CreateExpression(linevw, "pmx", "AB_PM_Auto * (AB_Auto/(AB_AM_Auto + AB_PM_Auto + AB_OP_Auto))", )
		opx = CreateExpression(linevw, "opx", "AB_OP_Auto * (AB_Auto/(AB_AM_Auto + AB_PM_Auto + AB_OP_Auto))", )
		SetRecordsValues(linevw+"|Selection", {{"AB_AM_Auto","AB_PM_Auto","AB_OP_Auto"}, null}, "Formula", {amx,pmx,opx},)
	end
	
	n = SelectByQuery("Selection", "Several", "Select * where (BA_AM_Auto + BA_PM_Auto + BA_OP_Auto) > BA_Auto",)
	if n > 0 then do
		amx = CreateExpression(linevw, "amx", "BA_AM_Auto * (BA_Auto/(BA_AM_Auto + BA_PM_Auto + BA_OP_Auto))", )
		pmx = CreateExpression(linevw, "pmx", "BA_PM_Auto * (BA_Auto/(BA_AM_Auto + BA_PM_Auto + BA_OP_Auto))", )
		opx = CreateExpression(linevw, "opx", "BA_OP_Auto * (BA_Auto/(BA_AM_Auto + BA_PM_Auto + BA_OP_Auto))", )
		SetRecordsValues(linevw+"|Selection", {{"BA_AM_Auto","BA_PM_Auto","BA_OP_Auto"}, null}, "Formula", {amx,pmx,opx},)
	end
	
	n = SelectByQuery("Selection", "Several", "Select * where (AB_AM_SUT + AB_PM_SUT + AB_OP_SUT) > AB_SUT",)
    if n > 0 then do
		amx = CreateExpression(linevw, "amx", "AB_AM_SUT * (AB_SUT/(AB_AM_SUT + AB_PM_SUT + AB_OP_SUT))", )
		pmx = CreateExpression(linevw, "pmx", "AB_PM_SUT * (AB_SUT/(AB_AM_SUT + AB_PM_SUT + AB_OP_SUT))", )
		opx = CreateExpression(linevw, "opx", "AB_OP_SUT * (AB_SUT/(AB_AM_SUT + AB_PM_SUT + AB_OP_SUT))", )
		SetRecordsValues(linevw+"|Selection", {{"AB_AM_SUT","AB_PM_SUT","AB_OP_SUT"}, null}, "Formula", {amx,pmx,opx},)
	end
	
	n = SelectByQuery("Selection", "Several", "Select * where (BA_AM_SUT + BA_PM_SUT + BA_OP_SUT) > BA_SUT",)
	if n > 0 then do
		amx = CreateExpression(linevw, "amx", "BA_AM_SUT * (BA_SUT/(BA_AM_SUT + BA_PM_SUT + BA_OP_SUT))", )
		pmx = CreateExpression(linevw, "pmx", "BA_PM_SUT * (BA_SUT/(BA_AM_SUT + BA_PM_SUT + BA_OP_SUT))", )
		opx = CreateExpression(linevw, "pmx", "BA_OP_SUT * (BA_SUT/(BA_AM_SUT + BA_PM_SUT + BA_OP_SUT))", )
		SetRecordsValues(linevw+"|Selection", {{"BA_AM_SUT","BA_PM_SUT","BA_OP_SUT"}, null}, "Formula", {amx,pmx,opx},)
	end
	
	n = SelectByQuery("Selection", "Several", "Select * where (AB_AM_MUT + AB_PM_MUT + AB_OP_MUT) > AB_MUT",)
	if n > 0 then do
		amx = CreateExpression(linevw, "amx", "AB_AM_MUT * (AB_MUT/(AB_AM_MUT + AB_PM_MUT + AB_OP_MUT))", )
		pmx = CreateExpression(linevw, "pmx", "AB_PM_MUT * (AB_MUT/(AB_AM_MUT + AB_PM_MUT + AB_OP_MUT))", )
		opx = CreateExpression(linevw, "opx", "AB_OP_MUT * (AB_MUT/(AB_AM_MUT + AB_PM_MUT + AB_OP_MUT))", )
		SetRecordsValues(linevw+"|Selection", {{"AB_AM_MUT","AB_PM_MUT","AB_OP_MUT"}, null}, "Formula", {amx,pmx,opx},)
	end
	
	n = SelectByQuery("Selection", "Several", "Select * where (BA_AM_MUT + BA_PM_MUT + BA_OP_MUT) > BA_MUT",)
	if n > 0 then do
		amx = CreateExpression(linevw, "amx", "BA_AM_MUT * (BA_MUT/(BA_AM_MUT + BA_PM_MUT + BA_OP_MUT))", )
		pmx = CreateExpression(linevw, "pmx", "BA_PM_MUT * (BA_MUT/(BA_AM_MUT + BA_PM_MUT + BA_OP_MUT))", )
		opx = CreateExpression(linevw, "opx", "BA_OP_MUT * (BA_MUT/(BA_AM_MUT + BA_PM_MUT + BA_OP_MUT))", )
		SetRecordsValues(linevw+"|Selection", {{"BA_AM_MUT","BA_PM_MUT","BA_OP_MUT"}, null}, "Formula", {amx,pmx,opx},)
	end
	
	totamautox = CreateExpression(linevw, "totamautox", "(nz(AB_AM_Auto) + nz(BA_AM_Auto))", )
	totpmautox = CreateExpression(linevw, "totpmautox", "(nz(AB_PM_Auto) + nz(BA_PM_Auto))", )
	totopautox = CreateExpression(linevw, "totopautox", "(nz(AB_OP_Auto) + nz(BA_OP_Auto))", )
	SetRecordsValues(linevw+"|", {{"Tot_AM_Auto","Tot_PM_Auto","Tot_OP_Auto"}, null}, "Formula", {totamautox,totpmautox,totopautox},)	
	totamsutx = CreateExpression(linevw, "totamsutx", "(nz(AB_AM_SUT) + nz(BA_AM_SUT))", )
	totpmsutx = CreateExpression(linevw, "totpmsutx", "(nz(AB_PM_SUT) + nz(BA_PM_SUT))", )
	totopsutx = CreateExpression(linevw, "totopsutx", "(nz(AB_OP_SUT) + nz(BA_OP_SUT))", )
	SetRecordsValues(linevw+"|", {{"Tot_AM_SUT","Tot_PM_SUT","Tot_OP_SUT"}, null}, "Formula", {totamsutx,totpmsutx,totopsutx},)	
	totammutx = CreateExpression(linevw, "totammutx", "(nz(AB_AM_MUT) + nz(BA_AM_MUT))", )
	totpmmutx = CreateExpression(linevw, "totpmmutx", "(nz(AB_PM_MUT) + nz(BA_PM_MUT))", )
	totopmutx = CreateExpression(linevw, "totopmutx", "(nz(AB_OP_MUT) + nz(BA_OP_MUT))", )
	SetRecordsValues(linevw+"|", {{"Tot_AM_MUT","Tot_PM_MUT","Tot_OP_MUT"}, null}, "Formula", {totammutx,totpmmutx,totopmutx},)	
	totabamx = CreateExpression(linevw, "totabamx", "(nz(AB_AM_Auto) + nz(AB_AM_SUT) + nz(AB_AM_MUT))", )
	totbaamx = CreateExpression(linevw, "totbaamx", "(nz(BA_AM_Auto) + nz(BA_AM_SUT) + nz(BA_AM_MUT))", )
	SetRecordsValues(linevw+"|", {{"AB_AM_TotFlow","BA_AM_TotFlow"}, null}, "Formula", {totabamx,totbaamx},)	
	totamx = CreateExpression(linevw, "totamx", "(nz(AB_AM_TotFlow) + nz(BA_AM_TotFlow))", )
	SetRecordsValues(linevw+"|", {{"AM_TotFlow"}, null}, "Formula", {totamx},)	
	totabpmx = CreateExpression(linevw, "totabpmx", "(nz(AB_PM_Auto) + nz(AB_PM_SUT) + nz(AB_PM_MUT))", )
	totbapmx = CreateExpression(linevw, "totbapmx", "(nz(BA_PM_Auto) + nz(BA_PM_SUT) + nz(BA_PM_MUT))", )
	SetRecordsValues(linevw+"|", {{"AB_PM_TotFlow","BA_PM_TotFlow"}, null}, "Formula", {totabpmx,totbapmx},)	
	totpmx = CreateExpression(linevw, "totpmx", "(nz(AB_PM_TotFlow) + nz(BA_PM_TotFlow))", )
	SetRecordsValues(linevw+"|", {{"PM_TotFlow"}, null}, "Formula", {totpmx},)	
	totabopx = CreateExpression(linevw, "totabopx", "(nz(AB_OP_Auto) + nz(AB_OP_SUT) + nz(AB_OP_MUT))", )
	totbaopx = CreateExpression(linevw, "totbaopx", "(nz(BA_OP_Auto) + nz(BA_OP_SUT) + nz(BA_OP_MUT))", )
	SetRecordsValues(linevw+"|", {{"AB_OP_TotFlow","BA_OP_TotFlow"}, null}, "Formula", {totabopx,totbaopx},)	
	totopx = CreateExpression(linevw, "totopx", "(nz(AB_OP_TotFlow) + nz(BA_OP_TotFlow))", )
	SetRecordsValues(linevw+"|", {{"OP_TotFlow"}, null}, "Formula", {totopx},)	
	
	arr = GetExpressions(linevw)
    for i = 1 to arr.length do DestroyExpression(linevw+"."+arr[i]) end
	
	// Selection to exclude non-TN/CCs/unmodeled
	//n = SelectByQuery("Mod", "Several", "Select * where FUNCCLASS <> null and FUNCCLASS <> 99 and STATE = 'TN'",)
	n = SelectByQuery("Mod", "Several", "Select * where FUNCCLASS > 0 and FUNCCLASS < 95",)
	
	outlinkvw = CreateTable("Link Report"  , post.outlink  , "dBase", 						// DBF MAX field name length = 10
							{{"ID1"       , "Integer", 10, null, "No"}, 
							{"Leng"       , "Real"   , 20, 2   , "No"},  
							{"FUNCLASS"   , "Integer", 10, null, "No"}, 
							{"SPD_LMT"    , "Integer", 10, null, "No"}, 
							{"VOL_AB"  , "Real"   , 20, 2   , "No"},   
							{"VOL_BA"  , "Real"   , 20, 2   , "No"}, 
							{"CAR_AB"  , "Real"   , 20, 2   , "No"},   
							{"CAR_BA"  , "Real"   , 20, 2   , "No"}, 
							{"TRK_AB"  , "Real"   , 20, 2   , "No"},
							{"TRK_BA"  , "Real"   , 20, 2   , "No"},       
							{"SUT_AB"  , "Real"   , 20, 2   , "No"},  
							{"SUT_BA"  , "Real"   , 20, 2   , "No"},  
							{"MUT_AB"  , "Real"   , 20, 2   , "No"},  
							{"MUT_BA"  , "Real"   , 20, 2   , "No"},  
							//{"MaxVol_AB"  , "Real"   , 20, 2   , "No"},  
							//{"MaxVol_BA"  , "Real"   , 20, 2   , "No"},
							//{"VolTrk_AB"  , "Real"   , 20, 2   , "No"},
							//{"VolTrk_BA"  , "Real"   , 20, 2   , "No"},       
							//{"VolSUT_AB"  , "Real"   , 20, 2   , "No"},   
							//{"VolSUT_BA"  , "Real"   , 20, 2   , "No"},  
							//{"VolMUT_AB"  , "Real"   , 20, 2   , "No"},   
							//{"VolMUT_BA"  , "Real"   , 20, 2   , "No"}, 
							{"AMPKVol_AB" , "Real"   , 20, 2   , "No"},   
							{"AMPKVol_BA" , "Real"   , 20, 2   , "No"}, 
							{"AMPKPCE_AB" , "Real"   , 20, 2   , "No"},   
							{"AMPKPCE_BA" , "Real"   , 20, 2   , "No"}, 
							{"AMPKVC_AB"  , "Real"   , 20, 4   , "No"}, 
							{"AMPKVC_BA"  , "Real"   , 20, 4   , "No"}, 
							{"AMPKSPD_AB" , "Real"   , 20, 4   , "No"}, 
							{"AMPKSPD_BA" , "Real"   , 20, 4   , "No"}, 
							{"AMPKTME_AB", "Real"   , 20, 4   , "No"}, 
							{"AMPKTME_BA", "Real"   , 20, 4   , "No"},
							{"PMPKVol_AB" , "Real"   , 20, 2   , "No"},   
							{"PMPKVol_BA" , "Real"   , 20, 2   , "No"}, 
							{"PMPKPCE_AB" , "Real"   , 20, 2   , "No"},   
							{"PMPKPCE_BA" , "Real"   , 20, 2   , "No"}, 
							{"PMPKVC_AB"  , "Real"   , 20, 4   , "No"}, 
							{"PMPKVC_BA"  , "Real"   , 20, 4   , "No"}, 
							{"PMPKSPD_AB" , "Real"   , 20, 4   , "No"}, 
							{"PMPKSPD_BA" , "Real"   , 20, 4   , "No"}, 
							{"PMPKTME_AB", "Real"   , 20, 4   , "No"}, 
							{"PMPKTME_BA", "Real"   , 20, 4   , "No"},      
							{"AMPDVol_AB" , "Real"   , 20, 2   , "No"},   
							{"AMPDVol_BA" , "Real"   , 20, 2   , "No"}, 
							{"AMPDPCE_AB" , "Real"   , 20, 2   , "No"},   
							{"AMPDPCE_BA" , "Real"   , 20, 2   , "No"}, 
							{"AMPDVC_AB"  , "Real"   , 20, 4   , "No"}, 
							{"AMPDVC_BA"  , "Real"   , 20, 4   , "No"}, 
							{"AMPDSPD_AB" , "Real"   , 20, 4   , "No"}, 
							{"AMPDSPD_BA" , "Real"   , 20, 4   , "No"}, 
							{"AMPDTME_AB", "Real"   , 20, 4   , "No"}, 
							{"AMPDTME_BA", "Real"   , 20, 4   , "No"},
							{"PMPDVol_AB" , "Real"   , 20, 2   , "No"},   
							{"PMPDVol_BA" , "Real"   , 20, 2   , "No"}, 
							{"PMPDPCE_AB" , "Real"   , 20, 2   , "No"},   
							{"PMPDPCE_BA" , "Real"   , 20, 2   , "No"}, 
							{"PMPDVC_AB"  , "Real"   , 20, 4   , "No"}, 
							{"PMPDVC_BA"  , "Real"   , 20, 4   , "No"}, 
							{"PMPDSPD_AB" , "Real"   , 20, 4   , "No"}, 
							{"PMPDSPD_BA" , "Real"   , 20, 4   , "No"}, 
							{"PMPDTME_AB", "Real"   , 20, 4   , "No"}, 
							{"PMPDTME_BA", "Real"   , 20, 4   , "No"},   							
							{"MAXVC_AB"   , "Real"   , 20, 4   , "No"}, 
							{"MAXVC_BA"   , "Real"   , 20, 4   , "No"}, 
							{"PKSPD_AB"   , "Real"   , 20, 4   , "No"}, 
							{"PKSPD_BA"    , "Real"   , 20, 4   , "No"}, 
							{"PKTIME_AB"   , "Real"   , 20, 4   , "No"}, 
							{"PKTIME_BA"   , "Real"   , 20, 4   , "No"}, 
							{"CDELAY_AB"   , "Real"   , 20, 4   , "No"}, 
							{"CDELAY_BA"   , "Real"   , 20, 4   , "No"}, 
							{"TDELAY_AB"   , "Real"   , 20, 4   , "No"}, 
							{"TDELAY_BA"   , "Real"   , 20, 4   , "No"}, 
							{"SUDELAY_AB" , "Real"   , 20, 4   , "No"}, 
							{"SUDELAY_BA" , "Real"   , 20, 4   , "No"}, 
							{"MUDELAY_AB" , "Real"   , 20, 4   , "No"}, 
							{"MUDELAY_BA" , "Real"   , 20, 4   , "No"}, 							
							{"VHT"         , "Real"   , 20, 2   , "No"}, 
							{"VHT_Car"     , "Real"   , 20, 2   , "No"}, 
							{"VHT_Trk"     , "Real"   , 20, 2   , "No"}, 							
							{"VHT_SUTrk"   , "Real"   , 20, 2   , "No"}, 	
							{"VHT_MUTrk"   , "Real"   , 20, 2   , "No"}, 
							{"VMT"         , "Real"   , 20, 2   , "No"}, 
							{"VMT_Car"     , "Real"   , 20, 2   , "No"}, 
							{"VMT_Trk"     , "Real"   , 20, 2   , "No"},							
							{"VMT_SUTrk"   , "Real"   , 20, 2   , "No"}, 
							{"VMT_MUTrk"   , "Real"   , 20, 2   , "No"},
							{"LOS_AB"      , "String" , 5 , null, "No"},
							{"LOS_BA"      , "String" , 5 , null, "No"},
							{"TOTVEHFUEL"  , "Real"   , 20, 2   , "No"}, 
							{"TOTTRKFUEL"  , "Real"   , 20, 2   , "No"},							
							{"TOTSUTFUEL", "Real"   , 20, 2   , "No"},
							{"TOTMUTFUEL", "Real"   , 20, 2   , "No"},
							{"TOTVEHNFUE"  , "Real"   , 20, 2   , "No"}, 
							{"TOTTRKNFUE"  , "Real"   , 20, 2   , "No"},							
							{"TOTSUTNFUE", "Real"   , 20, 2   , "No"},
							{"TOTMUTNFUE", "Real"   , 20, 2   , "No"},
							{"dlycgtt_AB"  , "Real"   , 20, 2   , "No"},
							{"dlycgtt_BA"  , "Real"   , 20, 2   , "No"},
							{"dlyspd_AB"   , "Real"   , 20, 2   , "No"},
							{"dlyspd_BA"   , "Real"   , 20, 2   , "No"},
							{"CrashesTot"  , "Real"   , 20, 2   , "No"},
							{"Crashes_F"   , "Real"   , 20, 2   , "No"},
							{"Crashes_I"   , "Real"   , 20, 2   , "No"},
							{"Crashes_P"   , "Real"   , 20, 2   , "No"},
							{"xVMT"        , "Real"   , 20, 2   , "No"},
							{"HSMclass"    , "Real"   , 20, 2   , "No"},
							{"VEHCOR"      , "Real"   , 20, 2   , "No"},
							{"VEHCOS"      , "Real"   , 20, 2   , "No"},
							{"VEHCO2R"     , "Real"   , 20, 2   , "No"},
							{"VEHCO2S"     , "Real"   , 20, 2   , "No"},
							{"VEHNOXR"     , "Real"   , 20, 2   , "No"},
							{"VEHNOXS"     , "Real"   , 20, 2   , "No"},
							{"VEHPM10R"    , "Real"   , 20, 2   , "No"},
							{"VEHPM10S"    , "Real"   , 20, 2   , "No"},
							{"VEHPM25R"    , "Real"   , 20, 2   , "No"},
							{"VEHPM25S"    , "Real"   , 20, 2   , "No"},
							{"VEHSOXR"     , "Real"   , 20, 2   , "No"},
							{"VEHSOXS"     , "Real"   , 20, 2   , "No"},
							{"VEHVOCR"     , "Real"   , 20, 2   , "No"},
							{"VEHVOCS"     , "Real"   , 20, 2   , "No"},
							{"TRKCOR"      , "Real"   , 20, 2   , "No"},
							{"TRKCOS"      , "Real"   , 20, 2   , "No"},
							{"TRKCO2R"     , "Real"   , 20, 2   , "No"},
							{"TRKCO2S"     , "Real"   , 20, 2   , "No"},
							{"TRKNOXR"     , "Real"   , 20, 2   , "No"},
							{"TRKNOXS"     , "Real"   , 20, 2   , "No"},
							{"TRKPM10R"    , "Real"   , 20, 2   , "No"},
							{"TRKPM10S"    , "Real"   , 20, 2   , "No"},
							{"TRKPM25R"    , "Real"   , 20, 2   , "No"},
							{"TRKPM25S"    , "Real"   , 20, 2   , "No"},
							{"TRKSOXR"     , "Real"   , 20, 2   , "No"},
							{"TRKSOXS"     , "Real"   , 20, 2   , "No"},
							{"TRKVOCR"     , "Real"   , 20, 2   , "No"},
							{"TRKVOCS"     , "Real"   , 20, 2   , "No"},							
							{"SUTRKCOR"    , "Real"   , 20, 2   , "No"},
							{"SUTRKCOS"    , "Real"   , 20, 2   , "No"},
							{"SUTRKCO2R"   , "Real"   , 20, 2   , "No"},
							{"SUTRKCO2S"   , "Real"   , 20, 2   , "No"},
							{"SUTRKNOXR"   , "Real"   , 20, 2   , "No"},
							{"SUTRKNOXS"   , "Real"   , 20, 2   , "No"},
							{"SUTRKPM10R"  , "Real"   , 20, 2   , "No"},
							{"SUTRKPM10S"  , "Real"   , 20, 2   , "No"},
							{"SUTRKPM25R"  , "Real"   , 20, 2   , "No"},
							{"SUTRKPM25S"  , "Real"   , 20, 2   , "No"},
							{"SUTRKSOXR"   , "Real"   , 20, 2   , "No"},
							{"SUTRKSOXS"   , "Real"   , 20, 2   , "No"},
							{"SUTRKVOCR"   , "Real"   , 20, 2   , "No"},
							{"SUTRKVOCS"   , "Real"   , 20, 2   , "No"},
							{"MUTRKCOR"    , "Real"   , 20, 2   , "No"},
							{"MUTRKCOS"    , "Real"   , 20, 2   , "No"},
							{"MUTRKCO2R"   , "Real"   , 20, 2   , "No"},
							{"MUTRKCO2S"   , "Real"   , 20, 2   , "No"},
							{"MUTRKNOXR"   , "Real"   , 20, 2   , "No"},
							{"MUTRKNOXS"   , "Real"   , 20, 2   , "No"},
							{"MUTRKPM10R"  , "Real"   , 20, 2   , "No"},
							{"MUTRKPM10S"  , "Real"   , 20, 2   , "No"},
							{"MUTRKPM25R"  , "Real"   , 20, 2   , "No"},
							{"MUTRKPM25S"  , "Real"   , 20, 2   , "No"},
							{"MUTRKSOXR"   , "Real"   , 20, 2   , "No"},
							{"MUTRKSOXS"   , "Real"   , 20, 2   , "No"},
							{"MUTRKVOCR"   , "Real"   , 20, 2   , "No"},
							{"MUTRKVOCS"   , "Real"   , 20, 2   , "No"},
							{"VHT_0_1"         , "Real"   , 20, 2   , "No"},
							{"VHT_1_2"         , "Real"   , 20, 2   , "No"},
							{"VHT_2_3"         , "Real"   , 20, 2   , "No"},
							{"VHT_3_4"         , "Real"   , 20, 2   , "No"},
							{"VHT_4_5"         , "Real"   , 20, 2   , "No"},
							{"VHT_5_6"         , "Real"   , 20, 2   , "No"},
							{"VHT_6_7"         , "Real"   , 20, 2   , "No"},
							{"VHT_7_8"         , "Real"   , 20, 2   , "No"},
							{"VHT_8_9"         , "Real"   , 20, 2   , "No"},
							{"VHT_9_10"         , "Real"   , 20, 2   , "No"},
							{"VHT_10_11"         , "Real"   , 20, 2   , "No"},
							{"VHT_11_12"         , "Real"   , 20, 2   , "No"},
							{"VHT_12_13"         , "Real"   , 20, 2   , "No"},
							{"VHT_13_14"         , "Real"   , 20, 2   , "No"},
							{"VHT_14_15"         , "Real"   , 20, 2   , "No"},
							{"VHT_15_16"         , "Real"   , 20, 2   , "No"},
							{"VHT_16_17"         , "Real"   , 20, 2   , "No"},
							{"VHT_17_18"         , "Real"   , 20, 2   , "No"},
							{"VHT_18_19"         , "Real"   , 20, 2   , "No"},
							{"VHT_19_20"         , "Real"   , 20, 2   , "No"},
							{"VHT_20_21"         , "Real"   , 20, 2   , "No"},
							{"VHT_21_22"         , "Real"   , 20, 2   , "No"},
							{"VHT_22_23"         , "Real"   , 20, 2   , "No"},
							{"VHT_23_24"         , "Real"   , 20, 2   , "No"},
							{"VMT_0_1"         , "Real"   , 20, 2   , "No"},
							{"VMT_1_2"         , "Real"   , 20, 2   , "No"},
							{"VMT_2_3"         , "Real"   , 20, 2   , "No"},
							{"VMT_3_4"         , "Real"   , 20, 2   , "No"},
							{"VMT_4_5"         , "Real"   , 20, 2   , "No"},
							{"VMT_5_6"         , "Real"   , 20, 2   , "No"},
							{"VMT_6_7"         , "Real"   , 20, 2   , "No"},
							{"VMT_7_8"         , "Real"   , 20, 2   , "No"},
							{"VMT_8_9"         , "Real"   , 20, 2   , "No"},
							{"VMT_9_10"         , "Real"   , 20, 2   , "No"},
							{"VMT_10_11"         , "Real"   , 20, 2   , "No"},
							{"VMT_11_12"         , "Real"   , 20, 2   , "No"},
							{"VMT_12_13"         , "Real"   , 20, 2   , "No"},
							{"VMT_13_14"         , "Real"   , 20, 2   , "No"},
							{"VMT_14_15"         , "Real"   , 20, 2   , "No"},
							{"VMT_15_16"         , "Real"   , 20, 2   , "No"},
							{"VMT_16_17"         , "Real"   , 20, 2   , "No"},
							{"VMT_17_18"         , "Real"   , 20, 2   , "No"},
							{"VMT_18_19"         , "Real"   , 20, 2   , "No"},
							{"VMT_19_20"         , "Real"   , 20, 2   , "No"},
							{"VMT_20_21"         , "Real"   , 20, 2   , "No"},
							{"VMT_21_22"         , "Real"   , 20, 2   , "No"},
							{"VMT_22_23"         , "Real"   , 20, 2   , "No"},
							{"VMT_23_24"         , "Real"   , 20, 2   , "No"}
							})

	// Take average of AB and BA lanes to get 'Lanes' - SB
	{AB_Lanes1  ,BA_Lanes1} 	= GetDataVectors(linevw+"|Mod", {"AB_LANES","BA_LANES"},{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})
	Lanes 						= (AB_Lanes1 + BA_Lanes1)/2

	{ID  ,Leng    , LinkDir , TAZ   , COUNTYID, Median , FC        ,Ramp  , TurnLane  , Access  , AT         , ACtrl      , BCtrl      , ab_cdelay   , ba_cdelay   , AADT_AB  ,AADT_BA  ,BASEVOL_AB  ,BASEVOL_BA  ,FFTIME_AB   ,FFTIME_BA   ,FFSpeed_AB ,FFSpeed_BA ,DLYCAP_AB  ,DLYCAP_BA  ,AMCAP_AB  , AMCAP_BA  , PMCAP_AB  ,PMCAP_BA  ,SUTRK_AB,SUTRK_BA,MUTRK_AB,MUTRK_BA,CAR_AB   ,CAR_BA   ,VEH_AB      ,VEH_BA      ,PctSU       ,PctMU       ,abBPRA   ,abBPRB   ,baBPRA   ,baBPRB   , SPD_LMT} = GetDataVectors(linevw+"|Mod",
	{"ID","Length","Dir","TAZID","COUNTYID", "MEDIAN","FUNCCLASS","Ramp","TWOTURNLN", "Access", "AREA_TYPE", "A_Control", "B_Control", "AB_UCDelay", "BA_UCDelay", "AB_AADT","BA_AADT","AB_BaseVol","BA_BaseVol","AB_AFFTime","BA_AFFTime","AB_AFFSpd","BA_AFFSpd","AB_DlyCap","BA_DlyCap","AB_AMCap", "BA_AMCap", "AB_PMCap","BA_PMCap","AB_SUT","BA_SUT","AB_MUT","BA_MUT","AB_AUTO","BA_AUTO","AB_TotFlow","BA_TotFlow","VHCL_SU_TR","VHCL_MU_TR","AB_bprA","AB_bprB","BA_bprA","BA_bprB", "SPD_LMT"}
	,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})
	
	//BASEVOL_AB	= if (BASEVOL_AB < 1) then 0 else BASEVOL_AB
	//BASEVOL_BA	= if (BASEVOL_BA < 1) then 0 else BASEVOL_BA
	SUTRK_AB	= if (SUTRK_AB < 1) then 0 else SUTRK_AB
	SUTRK_BA	= if (SUTRK_BA < 1) then 0 else SUTRK_BA
	MUTRK_AB	= if (MUTRK_AB < 1) then 0 else MUTRK_AB
	MUTRK_BA	= if (MUTRK_BA < 1) then 0 else MUTRK_BA
	CAR_AB		= if (CAR_AB < 1) then 0 else CAR_AB
	CAR_BA		= if (CAR_BA < 1) then 0 else CAR_BA
	VEH_AB		= if (VEH_AB < 1) then 0 else VEH_AB
	VEH_BA		= if (VEH_BA < 1) then 0 else VEH_BA
	//{BASEVOL_AM  ,BASEVOL_PM, BASEVOL_ROD} = GetDataVectors(linevw+"|Mod",	{"AM_BaseVol","PM_BaseVol","OP_BaseVol"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})
	
	// Add peak hour volume info from the dataview
	{AB_AM_AUTO, BA_AM_AUTO, AB_AM_SUT,	BA_AM_SUT,	AB_AM_MUT,	BA_AM_MUT,	AB_AM_TotFlow,	BA_AM_TotFlow} = GetDataVectors(linevw+"|Mod",
	{"AB_AM_Auto","BA_AM_Auto","AB_AM_SUT","BA_AM_SUT","AB_AM_MUT","BA_AM_MUT","AB_AM_TotFlow","BA_AM_TotFlow"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})

	{AB_PM_AUTO, BA_PM_AUTO, AB_PM_SUT,	BA_PM_SUT,	AB_PM_MUT,	BA_PM_MUT,	AB_PM_TotFlow,	BA_PM_TotFlow} = GetDataVectors(linevw+"|Mod",
	{"AB_PM_Auto","BA_PM_Auto","AB_PM_SUT","BA_PM_SUT","AB_PM_MUT","BA_PM_MUT","AB_PM_TotFlow","BA_PM_TotFlow"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})
	
	// Rest of day volume for Chattanooga from the model 
	{AB_ROD_AUTO, BA_ROD_AUTO, AB_ROD_SUT,	BA_ROD_SUT,	AB_ROD_MUT,	BA_ROD_MUT,	AB_ROD_TotFlow,	BA_ROD_TotFlow} = GetDataVectors(linevw+"|Mod",
	{"AB_OP_Auto","BA_OP_Auto","AB_OP_SUT","BA_OP_SUT","AB_OP_MUT","BA_OP_MUT","AB_OP_TotFlow","BA_OP_TotFlow"} ,{{"Sort Order",{{"ID","Ascending"}}},{"Missing as Zero","True"}})

	//Make sure rest of day volumes are resonable
	AB_ROD_AUTO		= if (AB_ROD_AUTO < 1) then 0 else AB_ROD_AUTO
	BA_ROD_AUTO		= if (BA_ROD_AUTO < 1) then 0 else BA_ROD_AUTO
	AB_ROD_SUT		= if (AB_ROD_SUT < 1) then 0 else AB_ROD_SUT
	BA_ROD_SUT		= if (BA_ROD_SUT < 1) then 0 else BA_ROD_SUT
	AB_ROD_MUT		= if (AB_ROD_MUT < 1) then 0 else AB_ROD_MUT
	BA_ROD_MUT		= if (BA_ROD_MUT < 1) then 0 else BA_ROD_MUT
	AB_ROD_TotFlow 	= AB_ROD_AUTO + AB_ROD_SUT + AB_ROD_MUT
	BA_ROD_TotFlow 	= BA_ROD_AUTO + BA_ROD_SUT + BA_ROD_MUT
	
	// Add this since truck flow is now broken into two - SB
	TRK_AB	= NZ(SUTRK_AB) + NZ(MUTRK_AB)
	TRK_BA 	= NZ(SUTRK_BA) + NZ(MUTRK_BA)

	TRK_AM_AB	= NZ(AB_AM_SUT) + NZ(AB_AM_MUT)
	TRK_AM_BA	= NZ(BA_AM_SUT) + NZ(BA_AM_MUT)
	TRK_PM_AB	= NZ(AB_PM_SUT) + NZ(AB_PM_MUT)
	TRK_PM_BA	= NZ(BA_PM_SUT) + NZ(BA_PM_MUT)
	TRK_ROD_AB	= NZ(AB_ROD_SUT) + NZ(AB_ROD_MUT)
	TRK_ROD_BA	= NZ(BA_ROD_SUT) + NZ(BA_ROD_MUT)
	
	//Recaltulate totals
	SUTRK 			= nz(SUTRK_AB) + nz(SUTRK_BA)
	MUTRK 			= nz(MUTRK_AB) + nz(MUTRK_BA)
	CAR 			= nz(CAR_AB) + nz(CAR_BA)
	VEH 			= nz(VEH_AB) + nz(VEH_BA)
	
	//SetDataVectors(linevw+"|Mod", {{"AB_BaseVol",BASEVOL_AB},{"BA_BaseVol",BASEVOL_BA},{"AB_SUT",SUTRK_AB},{"BA_SUT",SUTRK_BA},{"AB_MUT",MUTRK_AB},{"BA_MUT",MUTRK_BA},{"AB_AUTO",CAR_AB},{"BA_AUTO",CAR_BA},{"AB_TotFlow",VEH_AB},{"BA_TotFlow",VEH_BA},{"Tot_SUT",SUTRK},{"Tot_MUT",MUTRK},{"Tot_Auto",CAR},{"TotFlow",VEH}},{{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(linevw+"|Mod", {{"AB_SUT",SUTRK_AB},{"BA_SUT",SUTRK_BA},{"AB_MUT",MUTRK_AB},{"BA_MUT",MUTRK_BA},{"AB_AUTO",CAR_AB},{"BA_AUTO",CAR_BA},{"AB_TotFlow",VEH_AB},{"BA_TotFlow",VEH_BA},{"Tot_SUT",SUTRK},{"Tot_MUT",MUTRK},{"Tot_Auto",CAR},{"TotFlow",VEH}},{{"Sort Order",{{"ID","Ascending"}}}})
	
	FacType = if (FC = null) then "gis" else													// GIS only non-model links
               if (FC > 95) then "cc" else                            						// Centroid Connectors
               if (FC = 92) then "rndabt2" else                            					// Roundabout (2 lane)
               if (FC = 91) then "rndabt1" else                            					// Roundabout (1 lane)
               if (Ramp = 1) then "ramp" else              										// Ramps
               if (LinkDir <> 0 and Lanes = 1) then "owol" else         							// One-Way One-Lane
               if (LinkDir <> 0 and Lanes > 1) then "owml" else         							// One-Way Multi-Lane
               if (LinkDir = 0 and Lanes = 1) then "twtl" else                   					// Two-Way Two-Lane
               if (LinkDir = 0 and Lanes = 1 and TurnLane = 1 and Median <> 1) then "tw3l" else     // Two-Way Three-Lane (center left turn lane)
               if (LinkDir = 0 and Lanes > 1 and Median <> 1) then "twmlu" else  					// Two-Way Multi-Lane Undivided
               if (LinkDir <> 0 and Lanes > 1 and Median = 1) then "twmld" else  					// Two-Way Multi-Lane Divided
               if (Access = 2 or FC = 1 or FC = 11 or FC = 12) then "fwy" else "bad"      // Freeways and Errors
			   

	numlinks = VectorStatistic(ID, "Count", )
	r = AddRecords(outlinkvw, null, null, {{"Empty Records", numlinks}})

	MDVOL_AB = CAR_AB + SUTRK_AB + MUTRK_AB
	MDVOL_BA = CAR_BA + SUTRK_BA + MUTRK_BA
	
	MDVOL_AM_AB = AB_AM_TotFlow
	MDVOL_AM_BA = BA_AM_TotFlow
	MDVOL_PM_AB = AB_PM_TotFlow
	MDVOL_PM_BA = BA_PM_TotFlow
	MDVOL_ROD_AB = AB_ROD_TotFlow
	MDVOL_ROD_BA = BA_ROD_TotFlow

	// Do this since not adjust volume based on counts
	NVOL_AB = MDVOL_AB
	NVOL_BA = MDVOL_BA
	// Since we dont have counts by period - SB
	NVOL_AM_AB = MDVOL_AM_AB
	NVOL_AM_BA = MDVOL_AM_BA
	NVOL_PM_AB = MDVOL_PM_AB
	NVOL_PM_BA = MDVOL_PM_BA
	NVOL_ROD_AB = MDVOL_ROD_AB
	NVOL_ROD_BA = MDVOL_ROD_BA

	// We can now calculate the values to SU/MUPCT_AB/BA directly  based on the volume - SB
	TRKPCT_AB = if TRK_AB < 1 then 0 else if MDVOL_AB < 1 then 0 else TRK_AB / MDVOL_AB
	TRKPCT_BA = if TRK_BA < 1 then 0 else if MDVOL_BA < 1 then 0 else TRK_BA / MDVOL_BA
	
	// Replace code above by calculations using the SU and MU volume - SB
	SUPCT_AB  = if TRK_AB < 1 then 0 else if MDVOL_AB < 1 then 0 else SUTRK_AB / MDVOL_AB
	SUPCT_BA  = if TRK_BA < 1 then 0 else if MDVOL_BA < 1 then 0 else SUTRK_BA / MDVOL_BA
	MUPCT_AB  = if TRK_AB < 1 then 0 else if MDVOL_AB < 1 then 0 else MUTRK_AB / MDVOL_AB
	MUPCT_BA  = if TRK_BA < 1 then 0 else if MDVOL_BA < 1 then 0 else MUTRK_BA / MDVOL_BA
	
	SUPCT_AM_AB  = if TRK_AM_AB < 1 then 0 else if MDVOL_AM_AB < 1 then 0 else AB_AM_SUT / MDVOL_AM_AB
	SUPCT_AM_BA  = if TRK_AM_BA < 1 then 0 else if MDVOL_AM_BA < 1 then 0 else BA_AM_SUT / MDVOL_AM_BA
	MUPCT_AM_AB  = if TRK_AM_AB < 1 then 0 else if MDVOL_AM_AB < 1 then 0 else AB_AM_MUT / MDVOL_AM_AB
	MUPCT_AM_BA  = if TRK_AM_BA < 1 then 0 else if MDVOL_AM_BA < 1 then 0 else BA_AM_MUT / MDVOL_AM_BA
	SUPCT_PM_AB  = if TRK_PM_AB < 1 then 0 else if MDVOL_PM_AB < 1 then 0 else AB_PM_SUT / MDVOL_PM_AB
	SUPCT_PM_BA  = if TRK_PM_BA < 1 then 0 else if MDVOL_PM_BA < 1 then 0 else BA_PM_SUT / MDVOL_PM_BA
	MUPCT_PM_AB  = if TRK_PM_AB < 1 then 0 else if MDVOL_PM_AB < 1 then 0 else AB_PM_MUT / MDVOL_PM_AB
	MUPCT_PM_BA  = if TRK_PM_BA < 1 then 0 else if MDVOL_PM_BA < 1 then 0 else BA_PM_MUT / MDVOL_PM_BA
	SUPCT_ROD_AB  = if TRK_ROD_AB < 1 then 0 else if MDVOL_ROD_AB < 1 then 0 else AB_ROD_SUT / MDVOL_ROD_AB
	SUPCT_ROD_BA  = if TRK_ROD_BA < 1 then 0 else if MDVOL_ROD_BA < 1 then 0 else BA_ROD_SUT / MDVOL_ROD_BA
	MUPCT_ROD_AB  = if TRK_ROD_AB < 1 then 0 else if MDVOL_ROD_AB < 1 then 0 else AB_ROD_MUT / MDVOL_ROD_AB
	MUPCT_ROD_BA  = if TRK_ROD_BA < 1 then 0 else if MDVOL_ROD_BA < 1 then 0 else BA_ROD_MUT / MDVOL_ROD_BA	
	
	// Calculate truck volumes using count adjusted Nvol and truck percentages from the model
	// Using PCE values from netparam file instead of fixed 1.88. To be used in v/c calculations
	// Dont use PCE factor here since this gets written to the network and we report total volume only (not PCE adjusted vol)
	// Daily
	ADJTRK_AB = TRKPCT_AB * NVOL_AB
	ADJTRK_BA = TRKPCT_BA * NVOL_BA
	ADJSUTRK_AB = SUPCT_AB * NVOL_AB
	ADJSUTRK_BA = SUPCT_BA * NVOL_BA
	ADJMUTRK_AB = MUPCT_AB * NVOL_AB
	ADJMUTRK_BA = MUPCT_BA * NVOL_BA

	ADJCAR_AB = NVOL_AB - ADJSUTRK_AB - ADJMUTRK_AB
	ADJCAR_BA = NVOL_BA - ADJSUTRK_BA - ADJMUTRK_BA
	ADJVOL_AB = ADJCAR_AB + ADJSUTRK_AB +  ADJMUTRK_AB
	ADJVOL_BA = ADJCAR_BA + ADJSUTRK_BA + ADJMUTRK_BA
	// AM
	ADJSUTRK_AM_AB = SUPCT_AM_AB * NVOL_AM_AB
	ADJSUTRK_AM_BA = SUPCT_AM_BA * NVOL_AM_BA
	ADJMUTRK_AM_AB = MUPCT_AM_AB * NVOL_AM_AB
	ADJMUTRK_AM_BA = MUPCT_AM_BA * NVOL_AM_BA
	ADJCAR_AM_AB = NVOL_AM_AB - ADJSUTRK_AM_AB - ADJMUTRK_AM_AB
	ADJCAR_AM_BA = NVOL_AM_BA - ADJSUTRK_AM_BA - ADJMUTRK_AM_BA
	ADJVOL_AM_AB = ADJCAR_AM_AB + ADJSUTRK_AM_AB +  ADJMUTRK_AM_AB
	ADJVOL_AM_BA = ADJCAR_AM_BA + ADJSUTRK_AM_BA + ADJMUTRK_AM_BA
	// PM
	ADJSUTRK_PM_AB = SUPCT_PM_AB * NVOL_PM_AB
	ADJSUTRK_PM_BA = SUPCT_PM_BA * NVOL_PM_BA
	ADJMUTRK_PM_AB = MUPCT_PM_AB * NVOL_PM_AB
	ADJMUTRK_PM_BA = MUPCT_PM_BA * NVOL_PM_BA
	ADJCAR_PM_AB = NVOL_PM_AB - ADJSUTRK_PM_AB - ADJMUTRK_PM_AB
	ADJCAR_PM_BA = NVOL_PM_BA - ADJSUTRK_PM_BA - ADJMUTRK_PM_BA
	ADJVOL_PM_AB = ADJCAR_PM_AB + ADJSUTRK_PM_AB +  ADJMUTRK_PM_AB
	ADJVOL_PM_BA = ADJCAR_PM_BA + ADJSUTRK_PM_BA + ADJMUTRK_PM_BA
	// ROD
	ADJSUTRK_ROD_AB = SUPCT_ROD_AB * NVOL_ROD_AB
	ADJSUTRK_ROD_BA = SUPCT_ROD_BA * NVOL_ROD_BA
	ADJMUTRK_ROD_AB = MUPCT_ROD_AB * NVOL_ROD_AB
	ADJMUTRK_ROD_BA = MUPCT_ROD_BA * NVOL_ROD_BA
	ADJCAR_ROD_AB = NVOL_ROD_AB - ADJSUTRK_ROD_AB - ADJMUTRK_ROD_AB
	ADJCAR_ROD_BA = NVOL_ROD_BA - ADJSUTRK_ROD_BA - ADJMUTRK_ROD_BA
	ADJVOL_ROD_AB = ADJCAR_ROD_AB + ADJSUTRK_ROD_AB +  ADJMUTRK_ROD_AB
	ADJVOL_ROD_BA = ADJCAR_ROD_BA + ADJSUTRK_ROD_BA + ADJMUTRK_ROD_BA
	

	alpha1   = if abBPRA <> null then abBPRA else 0.15
	alpha2   = if baBPRA <> null then baBPRA else 0.15
	beta1    = if abBPRB <> null then abBPRB else 4.0
	beta2    = if baBPRB <> null then baBPRB else 4.0 
				
	ab_dlycgtime = if LinkDir = 0 or LinkDir = 1 then FFTIME_AB * (1 + alpha1 * Pow(VEH_AB/DLYCAP_AB,beta1)) else null////average daily congested time
    ba_dlycgtime = if LinkDir = 0 or LinkDir = -1 then FFTIME_BA * (1 + alpha2 * Pow(VEH_BA/DLYCAP_BA,beta2)) else null
	ab_dlyspd = Leng/ab_dlycgtime * 60
	ba_dlyspd = Leng/ba_dlycgtime * 60
	
	cdelay_AB = 0
	cdelay_BA = 0
	
	tdelay_AB = 0
	tdelay_BA = 0

	sutdelay_AB = 0
	sutdelay_BA = 0

	mutdelay_AB = 0
	mutdelay_BA = 0	
	
	dim HVolVeh_AB[24] dim HVolSu_AB[24] dim HVolMu_AB[24] dim HVol_AB[24] dim HVolTrk_AB[24]
	dim HVolVeh_BA[24] dim HVolSu_BA[24] dim HVolMu_BA[24] dim HVol_BA[24] dim HVolTrk_BA[24]
	dim HPCEVol_AB[24] dim HPCEVol_BA[24]
	
	dim VC_AB[24] dim TT_AB[24] dim losttime_AB[24] dim CGSpeed_AB[24] dim CGSpeed_ABLookUP[24]
	dim VC_BA[24] dim TT_BA[24] dim losttime_BA[24] dim CGSpeed_BA[24] dim CGSpeed_BALookUP[24]
	
	dim H_VHT_AB[24] dim H_VHT_VEH_AB[24] dim H_VHT_TRK_AB[24] dim H_VHT_SUTRK_AB[24] dim H_VHT_MUTRK_AB[24] 
	dim H_VHT_BA[24] dim H_VHT_VEH_BA[24] dim H_VHT_TRK_BA[24] dim H_VHT_SUTRK_BA[24]   dim H_VHT_MUTRK_BA[24] 
	
	dim H_VMT_AB[24] dim H_VMT_VEH_AB[24] dim H_VMT_TRK_AB[24] dim H_VMT_SUTRK_AB[24] dim H_VMT_MUTRK_AB[24]
	dim H_VMT_BA[24] dim H_VMT_VEH_BA[24] dim H_VMT_TRK_BA[24] dim H_VMT_SUTRK_BA[24] dim H_VMT_MUTRK_BA[24]
	
	dim AutoFuelRate_AB[24] dim AutoFuelRate_BA[24] 
	dim TruckFuelRate_AB[24] dim TruckFuelRate_BA[24]
	dim SUTruckFuelRate_AB[24] dim SUTruckFuelRate_BA[24]
	dim MUTruckFuelRate_AB[24] dim MUTruckFuelRate_BA[24]
	
	dim VEHCORATE_AB[24] dim VEHCORATE_BA[24]
	dim VEHCO2RATE_AB[24] dim VEHCO2RATE_BA[24] 
	dim VEHNOXRATE_AB[24] dim VEHNOXRATE_BA[24]
	dim VEHPM10RATE_AB[24] dim VEHPM10RATE_BA[24]
	dim VEHPM25RATE_AB[24] dim VEHPM25RATE_BA[24]
	dim VEHSOXRATE_AB[24] dim VEHSOXRATE_BA[24]
	dim VEHVOCRATE_AB[24] dim VEHVOCRATE_BA[24]
	
	dim TRKCORATE_AB[24] dim TRKCORATE_BA[24]
	dim TRKCO2RATE_AB[24] dim TRKCO2RATE_BA[24] 
	dim TRKNOXRATE_AB[24] dim TRKNOXRATE_BA[24]
	dim TRKPM10RATE_AB[24] dim TRKPM10RATE_BA[24]
	dim TRKPM25RATE_AB[24] dim TRKPM25RATE_BA[24]
	dim TRKSOXRATE_AB[24] dim TRKSOXRATE_BA[24]
	dim TRKVOCRATE_AB[24] dim TRKVOCRATE_BA[24]
	
	dim SUTRKCORATE_AB[24] dim SUTRKCORATE_BA[24]
	dim SUTRKCO2RATE_AB[24] dim SUTRKCO2RATE_BA[24] 
	dim SUTRKNOXRATE_AB[24] dim SUTRKNOXRATE_BA[24]
	dim SUTRKPM10RATE_AB[24] dim SUTRKPM10RATE_BA[24]
	dim SUTRKPM25RATE_AB[24] dim SUTRKPM25RATE_BA[24]
	dim SUTRKSOXRATE_AB[24] dim SUTRKSOXRATE_BA[24]
	dim SUTRKVOCRATE_AB[24] dim SUTRKVOCRATE_BA[24]
	
	dim MUTRKCORATE_AB[24] dim MUTRKCORATE_BA[24]
	dim MUTRKCO2RATE_AB[24] dim MUTRKCO2RATE_BA[24] 
	dim MUTRKNOXRATE_AB[24] dim MUTRKNOXRATE_BA[24]
	dim MUTRKPM10RATE_AB[24] dim MUTRKPM10RATE_BA[24]
	dim MUTRKPM25RATE_AB[24] dim MUTRKPM25RATE_BA[24]
	dim MUTRKSOXRATE_AB[24] dim MUTRKSOXRATE_BA[24]
	dim MUTRKVOCRATE_AB[24] dim MUTRKVOCRATE_BA[24]
	
	// Normalize time of day file to use the period volumes (AM and PM and rest of day)

	am_car_rf = 0
	am_car_ro = 0
	am_car_uf = 0
	am_car_uo = 0
	am_su_rf = 0
	am_su_ro = 0
	am_su_uf = 0
	am_su_uo = 0
	am_mu_rf = 0
	am_mu_ro = 0
	am_mu_uf = 0
	am_mu_uo = 0
	pm_car_rf = 0
	pm_car_ro = 0
	pm_car_uf = 0
	pm_car_uo = 0
	pm_su_rf = 0
	pm_su_ro = 0
	pm_su_uf = 0
	pm_su_uo = 0
	pm_mu_rf = 0
	pm_mu_ro = 0
	pm_mu_uf = 0
	pm_mu_uo = 0
	rod_car_rf = 0
	rod_car_ro = 0
	rod_car_uf = 0
	rod_car_uo = 0
	rod_su_rf = 0
	rod_su_ro = 0
	rod_su_uf = 0
	rod_su_uo = 0
	rod_mu_rf = 0
	rod_mu_ro = 0
	rod_mu_uf = 0
	rod_mu_uo = 0
	
	for t = 1 to PER.length do	// Sum up different periods. PER.length = 24
		if (PER[t] = 1) then do
			am_car_rf = am_car_rf + CAR_RF[t]
			am_car_ro = am_car_ro + CAR_RO[t]
			am_car_uf = am_car_uf + CAR_UF[t]
			am_car_uo = am_car_uo + CAR_UO[t]
			am_su_rf = am_su_rf + SU_RF[t]
			am_su_ro = am_su_ro + SU_RO[t]
			am_su_uf = am_su_uf + SU_UF[t]
			am_su_uo = am_su_uo + SU_UO[t]
			am_mu_rf = am_mu_rf + MU_RF[t]
			am_mu_ro = am_mu_ro + MU_RO[t]
			am_mu_uf = am_mu_uf + MU_UF[t]
			am_mu_uo = am_mu_uo + MU_UO[t]
			end 
		else if (PER[t] = 2) then do
			pm_car_rf = pm_car_rf + CAR_RF[t]
			pm_car_ro = pm_car_ro + CAR_RO[t]
			pm_car_uf = pm_car_uf + CAR_UF[t]
			pm_car_uo = pm_car_uo + CAR_UO[t]
			pm_su_rf = pm_su_rf + SU_RF[t]
			pm_su_ro = pm_su_ro + SU_RO[t]
			pm_su_uf = pm_su_uf + SU_UF[t]
			pm_su_uo = pm_su_uo + SU_UO[t]
			pm_mu_rf = pm_mu_rf + MU_RF[t]
			pm_mu_ro = pm_mu_ro + MU_RO[t]
			pm_mu_uf = pm_mu_uf + MU_UF[t]
			pm_mu_uo = pm_mu_uo + MU_UO[t]
			end 
		else  do
			rod_car_rf = rod_car_rf + CAR_RF[t]
			rod_car_ro = rod_car_ro + CAR_RO[t]
			rod_car_uf = rod_car_uf + CAR_UF[t]
			rod_car_uo = rod_car_uo + CAR_UO[t]
			rod_su_rf = rod_su_rf + SU_RF[t]
			rod_su_ro = rod_su_ro + SU_RO[t]
			rod_su_uf = rod_su_uf + SU_UF[t]
			rod_su_uo = rod_su_uo + SU_UO[t]
			rod_mu_rf = rod_mu_rf + MU_RF[t]
			rod_mu_ro = rod_mu_ro + MU_RO[t]
			rod_mu_uf = rod_mu_uf + MU_UF[t]
			rod_mu_uo = rod_mu_uo + MU_UO[t]
			end
	end
	
	for t = 1 to PER.length do		// Normalize each period
		if (PER[t] = 1) then do
			CAR_RF[t] = CAR_RF[t] / am_car_rf
			CAR_RO[t] = CAR_RO[t] / am_car_ro
			CAR_UF[t] = CAR_UF[t] / am_car_uf
			CAR_UO[t] = CAR_UO[t] / am_car_uo
			SU_RF[t] = SU_RF[t] / am_su_rf
			SU_RO[t] = SU_RO[t] / am_su_ro
			SU_UF[t] = SU_UF[t] / am_su_uf
			SU_UO[t] = SU_UO[t] / am_su_uo
			MU_RF[t] = MU_RF[t] / am_mu_rf
			MU_RO[t] = MU_RO[t] / am_mu_ro
			MU_UF[t] = MU_UF[t] / am_mu_uf
			MU_UO[t] = MU_UO[t] / am_mu_uo
			end
		else if (PER[t] = 2) then do
			CAR_RF[t] = CAR_RF[t] / pm_car_rf
			CAR_RO[t] = CAR_RO[t] / pm_car_ro
			CAR_UF[t] = CAR_UF[t] / pm_car_uf
			CAR_UO[t] = CAR_UO[t] / pm_car_uo
			SU_RF[t] = SU_RF[t] / pm_su_rf
			SU_RO[t] = SU_RO[t] / pm_su_ro
			SU_UF[t] = SU_UF[t] / pm_su_uf
			SU_UO[t] = SU_UO[t] / pm_su_uo
			MU_RF[t] = MU_RF[t] / pm_mu_rf
			MU_RO[t] = MU_RO[t] / pm_mu_ro
			MU_UF[t] = MU_UF[t] / pm_mu_uf
			MU_UO[t] = MU_UO[t] / pm_mu_uo
			end
		else  do
			CAR_RF[t] = CAR_RF[t] / rod_car_rf
			CAR_RO[t] = CAR_RO[t] / rod_car_ro
			CAR_UF[t] = CAR_UF[t] / rod_car_uf
			CAR_UO[t] = CAR_UO[t] / rod_car_uo
			SU_RF[t] = SU_RF[t] / rod_su_rf
			SU_RO[t] = SU_RO[t] / rod_su_ro
			SU_UF[t] = SU_UF[t] / rod_su_uf
			SU_UO[t] = SU_UO[t] / rod_su_uo
			MU_RF[t] = MU_RF[t] / rod_mu_rf
			MU_RO[t] = MU_RO[t] / rod_mu_ro
			MU_UF[t] = MU_UF[t] / rod_mu_uf
			MU_UO[t] = MU_UO[t] / rod_mu_uo
			end
	end
	for i = 1 to 24 do
	//Adjust volume by vehicle type by hour 
	// RF is rural freeway, RO is rural other (exept freeway), UF is urban freeway and UO is urban other (except freeway) - SB
	// replace 1.88 if necesary - SB
		if (PER[i] = 1) then do
			HVolVeh_AB[i] = if (FC = 1) then (ADJCAR_AM_AB)*CAR_RF[i] 
					else if (FC < 11) then (ADJCAR_AM_AB)*CAR_RO[i] 
					else if (FC < 14) then (ADJCAR_AM_AB)*CAR_UF[i] 
					else (ADJCAR_AM_AB)*CAR_UO[i]
			
			HVolSu_AB[i] = if (FC = 1) then ADJSUTRK_AM_AB*SU_RF[i] 
					else if (FC < 11) then ADJSUTRK_AM_AB*SU_RO[i] 
					else if (FC < 14) then ADJSUTRK_AM_AB*SU_UF[i] 
					else (ADJSUTRK_AM_AB)*SU_UO[i]
					
			HVolMu_AB[i] = if (FC = 1) then ADJMUTRK_AM_AB*MU_RF[i] 
					else if (FC < 11) then ADJMUTRK_AM_AB*MU_RO[i] 
					else if (FC < 14) then ADJMUTRK_AM_AB*MU_UF[i] 
					else (ADJMUTRK_AM_AB)*MU_UO[i]

					
			HVol_AB[i] = nz(HVolVeh_AB[i]) + nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])
			HPCEVol_AB[i] = nz(HVolVeh_AB[i]) + netparam.SUPCE.value * nz(HVolSu_AB[i]) + netparam.MUPCE.value * nz(HVolMu_AB[i])
			HVolTrk_AB[i] = nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])
			
			HVolVeh_BA[i] = if (FC = 1) then (ADJCAR_AM_BA)*CAR_RF[i] 
					else if (FC < 11) then (ADJCAR_AM_BA)*CAR_RO[i] 
					else if (FC < 14) then (ADJCAR_AM_BA)*CAR_UF[i] 
					else (ADJCAR_AM_BA)*CAR_UO[i]
			
			HVolSu_BA[i] = if (FC = 1) then ADJSUTRK_AM_BA*SU_RF[i] 
					else if (FC < 11) then ADJSUTRK_AM_BA*SU_RO[i] 
					else if (FC < 14) then ADJSUTRK_AM_BA*SU_UF[i] 
					else (ADJSUTRK_AM_BA)*SU_UO[i]
					
			HVolMu_BA[i] = if (FC = 1) then ADJMUTRK_AM_BA*MU_RF[i] 
					else if (FC < 11) then ADJMUTRK_AM_BA*MU_RO[i] 
					else if (FC < 14) then ADJMUTRK_AM_BA*MU_UF[i] 
					else (ADJMUTRK_AM_BA)*MU_UO[i]
					
			HVol_BA[i] = nz(HVolVeh_BA[i]) + nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])
			HPCEVol_BA[i] = nz(HVolVeh_BA[i]) + netparam.SUPCE.value * nz(HVolSu_BA[i]) + netparam.MUPCE.value * nz(HVolMu_BA[i])
			HVolTrk_BA[i] = nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])	
			end
		else if (PER[i] = 2) then do 
			HVolVeh_AB[i] = if (FC = 1) then (ADJCAR_PM_AB)*CAR_RF[i] 
					else if (FC < 11) then (ADJCAR_PM_AB)*CAR_RO[i] 
					else if (FC < 14) then (ADJCAR_PM_AB)*CAR_UF[i] 
					else (ADJCAR_PM_AB)*CAR_UO[i]
			
			HVolSu_AB[i] = if (FC = 1) then ADJSUTRK_PM_AB*SU_RF[i] 
					else if (FC < 11) then ADJSUTRK_PM_AB*SU_RO[i] 
					else if (FC < 14) then ADJSUTRK_PM_AB*SU_UF[i] 
					else (ADJSUTRK_PM_AB)*SU_UO[i]
					
			HVolMu_AB[i] = if (FC = 1) then ADJMUTRK_PM_AB*MU_RF[i] 
					else if (FC < 11) then ADJMUTRK_PM_AB*MU_RO[i] 
					else if (FC < 14) then ADJMUTRK_PM_AB*MU_UF[i] 
					else (ADJMUTRK_PM_AB)*MU_UO[i]
					
			HVol_AB[i] = nz(HVolVeh_AB[i]) + nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])
			HPCEVol_AB[i] = nz(HVolVeh_AB[i]) + netparam.SUPCE.value * nz(HVolSu_AB[i]) + netparam.MUPCE.value * nz(HVolMu_AB[i])
			HVolTrk_AB[i] = nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])
			
			HVolVeh_BA[i] = if (FC = 1) then (ADJCAR_PM_BA)*CAR_RF[i] 
					else if (FC < 11) then (ADJCAR_PM_BA)*CAR_RO[i] 
					else if (FC < 14) then (ADJCAR_PM_BA)*CAR_UF[i] 
					else (ADJCAR_PM_BA)*CAR_UO[i]
			
			HVolSu_BA[i] = if (FC = 1) then ADJSUTRK_PM_BA*SU_RF[i] 
					else if (FC < 11) then ADJSUTRK_PM_BA*SU_RO[i] 
					else if (FC < 14) then ADJSUTRK_PM_BA*SU_UF[i] 
					else (ADJSUTRK_PM_BA)*SU_UO[i]
					
			HVolMu_BA[i] = if (FC = 1) then ADJMUTRK_PM_BA*MU_RF[i] 
					else if (FC < 11) then ADJMUTRK_PM_BA*MU_RO[i] 
					else if (FC < 14) then ADJMUTRK_PM_BA*MU_UF[i] 
					else (ADJMUTRK_PM_BA)*MU_UO[i]
					
			HVol_BA[i] = nz(HVolVeh_BA[i]) + nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])
			HPCEVol_BA[i] = nz(HVolVeh_BA[i]) + netparam.SUPCE.value * nz(HVolSu_BA[i]) + netparam.MUPCE.value * nz(HVolMu_BA[i])
			HVolTrk_BA[i] = nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])		
			end
		else  do
			HVolVeh_AB[i] = if (FC = 1) then (ADJCAR_ROD_AB)*CAR_RF[i] 
					else if (FC < 11) then (ADJCAR_ROD_AB)*CAR_RO[i] 
					else if (FC < 14) then (ADJCAR_ROD_AB)*CAR_UF[i] 
					else (ADJCAR_ROD_AB)*CAR_UO[i]
			
			HVolSu_AB[i] = if (FC = 1) then ADJSUTRK_ROD_AB*SU_RF[i] 
					else if (FC < 11) then ADJSUTRK_ROD_AB*SU_RO[i] 
					else if (FC < 14) then ADJSUTRK_ROD_AB*SU_UF[i] 
					else (ADJSUTRK_ROD_AB)*SU_UO[i]
					
			HVolMu_AB[i] = if (FC = 1) then ADJMUTRK_ROD_AB*MU_RF[i] 
					else if (FC < 11) then ADJMUTRK_ROD_AB*MU_RO[i] 
					else if (FC < 14) then ADJMUTRK_ROD_AB*MU_UF[i] 
					else (ADJMUTRK_ROD_AB)*MU_UO[i]
					
			HVol_AB[i] = nz(HVolVeh_AB[i]) + nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])
			HPCEVol_AB[i] = nz(HVolVeh_AB[i]) + netparam.SUPCE.value * nz(HVolSu_AB[i]) + netparam.MUPCE.value * nz(HVolMu_AB[i])
			HVolTrk_AB[i] = nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])
			
			HVolVeh_BA[i] = if (FC = 1) then (ADJCAR_ROD_BA)*CAR_RF[i] 
					else if (FC < 11) then (ADJCAR_ROD_BA)*CAR_RO[i] 
					else if (FC < 14) then (ADJCAR_ROD_BA)*CAR_UF[i] 
					else (ADJCAR_ROD_BA)*CAR_UO[i]
			
			HVolSu_BA[i] = if (FC = 1) then ADJSUTRK_ROD_BA*SU_RF[i] 
					else if (FC < 11) then ADJSUTRK_ROD_BA*SU_RO[i] 
					else if (FC < 14) then ADJSUTRK_ROD_BA*SU_UF[i] 
					else (ADJSUTRK_ROD_BA)*SU_UO[i]
					
			HVolMu_BA[i] = if (FC = 1) then ADJMUTRK_ROD_BA*MU_RF[i] 
					else if (FC < 11) then ADJMUTRK_ROD_BA*MU_RO[i] 
					else if (FC < 14) then ADJMUTRK_ROD_BA*MU_UF[i] 
					else (ADJMUTRK_ROD_BA)*MU_UO[i]
					
			HVol_BA[i] = nz(HVolVeh_BA[i]) + nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])
			HPCEVol_BA[i] = nz(HVolVeh_BA[i]) + netparam.SUPCE.value * nz(HVolSu_BA[i]) + netparam.MUPCE.value * nz(HVolMu_BA[i])
			HVolTrk_BA[i] = nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])		
			end
	//calculate congested speed and travel time using hourly v/c ratio
		// Use PCE adjusted volume for V/C calculations only
		VC_AB[i]       = if PMCAP_AB = 0 then 0 else HPCEVol_AB[i]/(PMCAP_AB/3)	// PMCAP_AB is 3 hour period capacity so /3 is close estimate for 1 hour capacity
		TT_AB[i]       = FFTIME_AB * (1 + (alpha1 * pow(VC_AB[i], beta1)))
		losttime_AB[i] = TT_AB[i] - FFTIME_AB
		
		// For non-freeway links cap max delay at 5 min and readjust travel time. For freeways cap speed at 6 MPH and recalculate travel time and losttime/delay
		losttime_AB[i] = if (FC = 1 and (Leng*60/TT_AB[i]) < 6) then ((Leng*60/6) - FFTIME_AB) 
					else if ((FC = 11 or FC = 12) and (Leng*60/TT_AB[i]) < 6) then ((Leng*60/6) - FFTIME_AB) 
					else if (losttime_AB[i] > 5 and FC <> 1 and FC <> 11 and FC <> 12) then 5 
					else losttime_AB[i]
		
		// If lost time is less than 0 then make lost time as 00
		losttime_AB[i] = if (losttime_AB[i] < 0) then 0 else losttime_AB[i]
		
		TT_AB[i] = losttime_AB[i] + FFTIME_AB	
		
		delay_AB       = nz(delay_AB) + (losttime_AB[i] *HVol_AB[i])/60
		cdelay_AB      = nz(cdelay_AB) + (losttime_AB[i] * nz(HVolVeh_AB[i]))/60
		tdelay_AB      = nz(tdelay_AB) + (losttime_AB[i] * (nz(HVolSu_AB[i]) + nz(HVolMu_AB[i])))/60
		// Added code for SU and MU trucks - SB
		sutdelay_AB      = nz(sutdelay_AB) + (losttime_AB[i] * (nz(HVolSu_AB[i])))/60
		mutdelay_AB      = nz(mutdelay_AB) + (losttime_AB[i] * (nz(HVolMu_AB[i])))/60
		CGSpeed_AB[i]  = if LinkDir = 0 or LinkDir = 1 then (Leng/TT_AB[i] * 60) else null

		// Use PCE adjusted volume for V/C calculations only
		VC_BA[i]       = if PMCAP_BA = 0 then 0 else HPCEVol_BA[i]/(PMCAP_BA/3)	// PMCAP_BA is 3 hour period capacity so /3 is close estimate for 1 hour capacity
		TT_BA[i]       = FFTIME_BA * (1 + (alpha2 * pow(VC_BA[i], beta2)))
		losttime_BA[i] = TT_BA[i] - FFTIME_BA
		
		// For non-freeway links cap max delay at 5 min and readjust travel time. For freeways cap speed at 6 MPH and recalculate travel time and losttime/delay
		losttime_BA[i] = if (FC = 1 and Leng*60/TT_BA[i] < 6) then ((Leng*60/6) - FFTIME_BA) 
					else if ((FC = 11 or FC = 12) and (Leng*60/TT_BA[i]) < 6) then ((Leng*60/6) - FFTIME_BA) 
					else if (losttime_BA[i] > 5 and FC <> 1 and FC <> 11 and FC <> 12) then 5 
					else losttime_BA[i]
		
		// If lost time is less than 0 then make lost time as 00
		losttime_BA[i] = if (losttime_BA[i] < 0) then 0 else losttime_BA[i]
		
		TT_BA[i] = losttime_BA[i] + FFTIME_BA
		
		delay_BA       = nz(delay_BA) + (losttime_BA[i] *HVol_BA[i])/60
		cdelay_BA      = nz(cdelay_BA) + (losttime_BA[i] * nz(HVolVeh_BA[i]))/60
		tdelay_BA      = nz(tdelay_BA) + (losttime_BA[i] * (nz(HVolSu_BA[i]) + nz(HVolMu_BA[i])))/60
		// Added code for SU and MU trucks - SB
		sutdelay_BA      = nz(sutdelay_BA) + (losttime_BA[i] * (nz(HVolSu_BA[i])))/60
		mutdelay_BA      = nz(mutdelay_BA) + (losttime_BA[i] * (nz(HVolMu_BA[i])))/60
		CGSpeed_BA[i]  = if LinkDir = 0 or LinkDir = -1 then (Leng/TT_BA[i] * 60) else null

	//hourly VMT & VHT
		H_VHT_AB[i]     = HVol_AB[i] * TT_AB[i] / 60
		H_VHT_VEH_AB[i] = HVolVeh_AB[i] * TT_AB[i] / 60
		H_VHT_TRK_AB[i] = HVolTrk_AB[i] * TT_AB[i] / 60
		// Added code for SU and MU trucks - SB
		H_VHT_SUTRK_AB[i] = HVolSu_AB[i] * TT_AB[i] / 60
		H_VHT_MUTRK_AB[i] = HVolMu_AB[i] * TT_AB[i] / 60
		                
		H_VMT_AB[i]     = HVol_AB[i] * Leng
		H_VMT_VEH_AB[i] = HVolVeh_AB[i] * Leng
		H_VMT_TRK_AB[i] = HVolTrk_AB[i]  * Leng
		// Added code for SU and MU trucks - SB
		H_VMT_SUTRK_AB[i] = HVolSu_AB[i]  * Leng
		H_VMT_MUTRK_AB[i] = HVolMu_AB[i]  * Leng
		                
		H_VHT_BA[i]     = HVol_BA[i] * TT_BA[i] / 60
		H_VHT_VEH_BA[i] = HVolVeh_BA[i] * TT_BA[i] / 60
		H_VHT_TRK_BA[i] = HVolTrk_BA[i] * TT_BA[i] / 60
		// Added code for SU and MU trucks - SB
		H_VHT_SUTRK_BA[i] = HVolSu_BA[i] * TT_BA[i] / 60
		H_VHT_MUTRK_BA[i] = HVolMu_BA[i] * TT_BA[i] / 60
		
		H_VMT_BA[i]     = HVol_BA[i] * Leng
		H_VMT_VEH_BA[i] = HVolVeh_BA[i] * Leng
		H_VMT_TRK_BA[i] = HVolTrk_BA[i] * Leng
		// Added code for SU and MU trucks - SB
		H_VMT_SUTRK_BA[i] = HVolSu_BA[i]  * Leng
		H_VMT_MUTRK_BA[i] = HVolMu_BA[i]  * Leng		

		// vehicle operation cost on each link

		CGSpeed_ABLookUP[i] = if (CGSpeed_AB[i]>80) then 80
				      else if (CGSpeed_AB[i]<5) then 5
				      else floor(CGSpeed_AB[i])
		CGSpeed_BALookUP[i] = if (CGSpeed_BA[i]>80) then 80
				      else if (CGSpeed_BA[i]<5) then 5
				      else floor(CGSpeed_BA[i])
		
		AutoFuelRate_AB[i]  	=  AUTOFUEL[CGSpeed_ABLookUP[i]]
		TruckFuelRate_AB[i] 	=  TRUCKFUEL[CGSpeed_ABLookUP[i]]
		SUTruckFuelRate_AB[i] 	=  SUTRUCKFUEL[CGSpeed_ABLookUP[i]]
		MUTruckFuelRate_AB[i] 	=  MUTRUCKFUEL[CGSpeed_ABLookUP[i]]
		AutoFuelRate_BA[i]  	= AUTOFUEL[CGSpeed_BALookUP[i]]
		TruckFuelRate_BA[i] 	= TRUCKFUEL[CGSpeed_BALookUP[i]]     
		SUTruckFuelRate_BA[i] 	= SUTRUCKFUEL[CGSpeed_BALookUP[i]]     		
		MUTruckFuelRate_BA[i] 	= MUTRUCKFUEL[CGSpeed_BALookUP[i]]     
		VEHCORATE_AB[i]    	 	= VEHCO[CGSpeed_ABLookUP[i]]
		VEHCORATE_BA[i]     	= VEHCO[CGSpeed_BALookUP[i]]
		VEHCO2RATE_AB[i]    	= VEHCO2[CGSpeed_ABLookUP[i]]
		VEHCO2RATE_BA[i]    	= VEHCO2[CGSpeed_BALookUP[i]]
		VEHNOXRATE_AB[i]    	= VEHNOX[CGSpeed_ABLookUP[i]]
		VEHNOXRATE_BA[i]    	= VEHNOX[CGSpeed_BALookUP[i]]
		VEHPM10RATE_AB[i]   	= VEHPM10[CGSpeed_ABLookUP[i]]
		VEHPM10RATE_BA[i]   	= VEHPM10[CGSpeed_BALookUP[i]]
		VEHPM25RATE_AB[i]   	= VEHPM25[CGSpeed_ABLookUP[i]]
		VEHPM25RATE_BA[i]   	= VEHPM25[CGSpeed_BALookUP[i]]
		VEHSOXRATE_AB[i]    	= VEHSOX[CGSpeed_ABLookUP[i]]
		VEHSOXRATE_BA[i]    	= VEHSOX[CGSpeed_BALookUP[i]]
		VEHVOCRATE_AB[i]    	= VEHVOC[CGSpeed_ABLookUP[i]]
		VEHVOCRATE_BA[i]    	= VEHVOC[CGSpeed_BALookUP[i]]
		TRKCORATE_AB[i]     	= TRKCO[CGSpeed_ABLookUP[i]]
		TRKCORATE_BA[i]     	= TRKCO[CGSpeed_BALookUP[i]]
		TRKCO2RATE_AB[i]    	= TRKCO2[CGSpeed_ABLookUP[i]]
		TRKCO2RATE_BA[i]    	= TRKCO2[CGSpeed_BALookUP[i]]
		TRKNOXRATE_AB[i]    	= TRKNOX[CGSpeed_ABLookUP[i]]
		TRKNOXRATE_BA[i]    	= TRKNOX[CGSpeed_BALookUP[i]]
		TRKPM10RATE_AB[i]   	= TRKPM10[CGSpeed_ABLookUP[i]]
		TRKPM10RATE_BA[i]   	= TRKPM10[CGSpeed_BALookUP[i]]
		TRKPM25RATE_AB[i]   	= TRKPM25[CGSpeed_ABLookUP[i]]
		TRKPM25RATE_BA[i]   	= TRKPM25[CGSpeed_BALookUP[i]]
		TRKSOXRATE_AB[i]    	= TRKSOX[CGSpeed_ABLookUP[i]]
		TRKSOXRATE_BA[i]    	= TRKSOX[CGSpeed_BALookUP[i]]
		TRKVOCRATE_AB[i]    	= TRKVOC[CGSpeed_ABLookUP[i]]
		TRKVOCRATE_BA[i]    	= TRKVOC[CGSpeed_BALookUP[i]]  
		
		SUTRKCORATE_AB[i]     	= SUTRKCO[CGSpeed_ABLookUP[i]]
		SUTRKCORATE_BA[i]     	= SUTRKCO[CGSpeed_BALookUP[i]]
		SUTRKCO2RATE_AB[i]    	= SUTRKCO2[CGSpeed_ABLookUP[i]]
		SUTRKCO2RATE_BA[i]    	= SUTRKCO2[CGSpeed_BALookUP[i]]
		SUTRKNOXRATE_AB[i]    	= SUTRKNOX[CGSpeed_ABLookUP[i]]
		SUTRKNOXRATE_BA[i]    	= SUTRKNOX[CGSpeed_BALookUP[i]]
		SUTRKPM10RATE_AB[i]   	= SUTRKPM10[CGSpeed_ABLookUP[i]]
		SUTRKPM10RATE_BA[i]   	= SUTRKPM10[CGSpeed_BALookUP[i]]
		SUTRKPM25RATE_AB[i]   	= SUTRKPM25[CGSpeed_ABLookUP[i]]
		SUTRKPM25RATE_BA[i]   	= SUTRKPM25[CGSpeed_BALookUP[i]]
		SUTRKSOXRATE_AB[i]    	= SUTRKSOX[CGSpeed_ABLookUP[i]]
		SUTRKSOXRATE_BA[i]    	= SUTRKSOX[CGSpeed_BALookUP[i]]
		SUTRKVOCRATE_AB[i]    	= SUTRKVOC[CGSpeed_ABLookUP[i]]
		SUTRKVOCRATE_BA[i]    	= SUTRKVOC[CGSpeed_BALookUP[i]] 
		
		MUTRKCORATE_AB[i]     	= MUTRKCO[CGSpeed_ABLookUP[i]]
		MUTRKCORATE_BA[i]     	= MUTRKCO[CGSpeed_BALookUP[i]]
		MUTRKCO2RATE_AB[i]    	= MUTRKCO2[CGSpeed_ABLookUP[i]]
		MUTRKCO2RATE_BA[i]    	= MUTRKCO2[CGSpeed_BALookUP[i]]
		MUTRKNOXRATE_AB[i]    	= MUTRKNOX[CGSpeed_ABLookUP[i]]
		MUTRKNOXRATE_BA[i]    	= MUTRKNOX[CGSpeed_BALookUP[i]]
		MUTRKPM10RATE_AB[i]   	= MUTRKPM10[CGSpeed_ABLookUP[i]]
		MUTRKPM10RATE_BA[i]   	= MUTRKPM10[CGSpeed_BALookUP[i]]
		MUTRKPM25RATE_AB[i]   	= MUTRKPM25[CGSpeed_ABLookUP[i]]
		MUTRKPM25RATE_BA[i]   	= MUTRKPM25[CGSpeed_BALookUP[i]]
		MUTRKSOXRATE_AB[i]    	= MUTRKSOX[CGSpeed_ABLookUP[i]]
		MUTRKSOXRATE_BA[i]    	= MUTRKSOX[CGSpeed_BALookUP[i]]
		MUTRKVOCRATE_AB[i]    	= MUTRKVOC[CGSpeed_ABLookUP[i]]
		MUTRKVOCRATE_BA[i]    	= MUTRKVOC[CGSpeed_BALookUP[i]] 
	end		


	//LOS on each link
	{TOTVHT,TOTVHTCAR,TOTVHTTRK,TOTVMT,TOTVMTCAR,TOTVMTTRK,PKSPD_AB, PKSPD_BA, MAXVC_AB,MaxVol_AB,MaxVolTrk_AB,MAXVC_BA,MaxVol_BA,MaxVolTrk_BA,TOTVEHFUEL,TOTTRKFUEL,TOTVEHNFUEL,TOTTRKNFUEL}={0,0,0,0,0,0,100,100,0,0,0,0,0,0,0,0,0,0}
	{TOTVHTSUTRK,TOTVMTSUTRK,MaxVolSUTRK_AB,MaxVolSUTRK_BA,TOTSUTRKFUEL,TOTSUTRKNFUEL}={0,0,0,0,0,0}
	{TOTVHTMUTRK,TOTVMTMUTRK,MaxVolMUTRK_AB,MaxVolMUTRK_BA,TOTMUTRKFUEL,TOTMUTRKNFUEL}={0,0,0,0,0,0}
	
	//{fatal,Injury,PDO,accident,fatalC,InjuryC,PDOC,accidentC} = {0,0,0,0,0,0,0,0}
	//{CrashesTot,Crashes_F,Crashes_I,Crashes_P,xVMT,HSMclass,Sys} = {0,0,0,0,0,0,0}
	// New crash variables for links and intersections - SB
	{Crashes_Total_Links,Crashes_Fatal_Links,Crashes_Injury_Links,Crashes_PDO_Links,xVMT,HSMclass} = {0,0,0,0,0,0}
	{Crashes_Total_Int,Crashes_Fatal_Int,Crashes_Injury_Int,Crashes_PDO_Int,HSMclass} = {0,0,0,0,0}
	
	{TOTVEHCOR,TOTVEHCOS,TOTVEHCO2R,TOTVEHCO2S,TOTVEHNOXR,TOTVEHNOXS,TOTVEHPM10R,TOTVEHPM10S,TOTVEHPM25R,TOTVEHPM25S,TOTVEHSOXR,TOTVEHSOXS,TOTVEHVOCR,TOTVEHVOCS}={0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	{TOTTRKCOR,TOTTRKCOS,TOTTRKCO2R,TOTTRKCO2S,TOTTRKNOXR,TOTTRKNOXS,TOTTRKPM10R,TOTTRKPM10S,TOTTRKPM25R,TOTTRKPM25S,TOTTRKSOXR,TOTTRKSOXS,TOTTRKVOCR,TOTTRKVOCS}={0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	
	{TOTSUTRKCOR,TOTSUTRKCOS,TOTSUTRKCO2R,TOTSUTRKCO2S,TOTSUTRKNOXR,TOTSUTRKNOXS,TOTSUTRKPM10R,TOTSUTRKPM10S,TOTSUTRKPM25R,TOTSUTRKPM25S,TOTSUTRKSOXR,TOTSUTRKSOXS,TOTSUTRKVOCR,TOTSUTRKVOCS}={0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	{TOTMUTRKCOR,TOTMUTRKCOS,TOTMUTRKCO2R,TOTMUTRKCO2S,TOTMUTRKNOXR,TOTMUTRKNOXS,TOTMUTRKPM10R,TOTMUTRKPM10S,TOTMUTRKPM25R,TOTMUTRKPM25S,TOTMUTRKSOXR,TOTMUTRKSOXS,TOTMUTRKVOCR,TOTMUTRKVOCS}={0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	
	//Calculate AM & PM Peak Statistics
	//FC distribution sometimes offers different PM peaks
	ampk1 = 7  //6-7a ;
	ampk2 = 8  //7-8a ;
	ampk3 = 9  //8-9a ;
	pmpk1 = 16 //3-4p ;
	pmpk2 = 17 //4-5p ; 
	pmpk3 = 18 //5-6p ; 
	
	AMPK.Vol_AB  = if LinkDir = -1 then null else max(HVol_AB[ampk1]         , max(HVol_AB[ampk2]         , HVol_AB[ampk3]         ))
	AMPK.Vol_BA  = if LinkDir = 1  then null else max(HVol_BA[ampk1]         , max(HVol_BA[ampk2]         , HVol_BA[ampk3]         ))
	AMPK.PCE_AB  = if LinkDir = -1 then null else max(HPCEVol_AB[ampk1]      , max(HPCEVol_AB[ampk2]      , HPCEVol_AB[ampk3]      ))
	AMPK.PCE_BA  = if LinkDir = 1  then null else max(HPCEVol_BA[ampk1]      , max(HPCEVol_BA[ampk2]      , HPCEVol_BA[ampk3]      ))
	AMPK.VC_AB   = if LinkDir = -1 then null else max(VC_AB[ampk1]           , max(VC_AB[ampk2]           , VC_AB[ampk3]           ))
	AMPK.VC_BA   = if LinkDir = 1  then null else max(VC_BA[ampk1]           , max(VC_BA[ampk2]           , VC_BA[ampk3]           ))
	AMPK.SPD_AB  = if LinkDir = -1 then null else min(CGSpeed_ABLookUP[ampk1], min(CGSpeed_ABLookUP[ampk2], CGSpeed_ABLookUP[ampk3]))
	AMPK.SPD_BA  = if LinkDir = 1  then null else min(CGSpeed_BALookUP[ampk1], min(CGSpeed_BALookUP[ampk2], CGSpeed_BALookUP[ampk3]))
	AMPK.TIME_AB = if LinkDir = -1 then null else Leng*60/AMPK.SPD_AB
	AMPK.TIME_BA = if LinkDir = 1  then null else Leng*60/AMPK.SPD_BA
	            
	PMPK.Vol_AB  = if LinkDir = -1 then null else max(HVol_AB[pmpk1]         , max(HVol_AB[pmpk2]         , HVol_AB[pmpk3]         ))
	PMPK.Vol_BA  = if LinkDir = 1  then null else max(HVol_BA[pmpk1]         , max(HVol_BA[pmpk2]         , HVol_BA[pmpk3]         ))
	PMPK.PCE_AB  = if LinkDir = -1 then null else max(HPCEVol_AB[pmpk1]      , max(HPCEVol_AB[pmpk2]      , HPCEVol_AB[pmpk3]      ))
	PMPK.PCE_BA  = if LinkDir = 1  then null else max(HPCEVol_BA[pmpk1]      , max(HPCEVol_BA[pmpk2]      , HPCEVol_BA[pmpk3]      ))
	PMPK.VC_AB   = if LinkDir = -1 then null else max(VC_AB[pmpk1]           , max(VC_AB[pmpk2]           , VC_AB[pmpk3]           ))
	PMPK.VC_BA   = if LinkDir = 1  then null else max(VC_BA[pmpk1]           , max(VC_BA[pmpk2]           , VC_BA[pmpk3]           ))
	PMPK.SPD_AB  = if LinkDir = -1 then null else min(CGSpeed_ABLookUP[pmpk1], min(CGSpeed_ABLookUP[pmpk2], CGSpeed_ABLookUP[pmpk3]))
	PMPK.SPD_BA  = if LinkDir = 1  then null else min(CGSpeed_BALookUP[pmpk1], min(CGSpeed_BALookUP[pmpk2], CGSpeed_BALookUP[pmpk3]))
	PMPK.TIME_AB = if LinkDir = -1 then null else Leng*60/PMPK.SPD_AB
	PMPK.TIME_BA = if LinkDir = 1  then null else Leng*60/PMPK.SPD_BA
	
	AMPD.Vol_AB  = if LinkDir = -1 then null else HVol_AB[7]    + HVol_AB[8]    + HVol_AB[9]
	AMPD.Vol_BA  = if LinkDir = 1  then null else HVol_BA[7]    + HVol_BA[8]    + HVol_BA[9]
	AMPD.PCE_AB  = if LinkDir = -1 then null else HPCEVol_AB[7] + HPCEVol_AB[8] + HPCEVol_AB[9]
	AMPD.PCE_BA  = if LinkDir = 1  then null else HPCEVol_BA[7] + HPCEVol_BA[8] + HPCEVol_BA[9]
	AMPD.VC_AB   = if LinkDir = -1 then null else AMPD.PCE_AB / AMCAP_AB
	AMPD.VC_BA   = if LinkDir = 1  then null else AMPD.PCE_BA / AMCAP_BA
	AMPD.SPD_AB  = if LinkDir = -1 then null else (H_VMT_AB[7] + H_VMT_AB[8] + H_VMT_AB[9])/(H_VHT_AB[7] + H_VHT_AB[8] + H_VHT_AB[9])
	AMPD.SPD_BA  = if LinkDir = 1  then null else (H_VMT_BA[7] + H_VMT_BA[8] + H_VMT_BA[9])/(H_VHT_BA[7] + H_VHT_BA[8] + H_VHT_BA[9])
	AMPD.TIME_AB = if LinkDir = -1 then null else Leng*60/AMPD.SPD_AB
	AMPD.TIME_BA = if LinkDir = 1  then null else Leng*60/AMPD.SPD_BA
	
	PMPD.Vol_AB  = if LinkDir = -1 then null else HVol_AB[16]    + HVol_AB[17]    + HVol_AB[19]
	PMPD.Vol_BA  = if LinkDir = 1  then null else HVol_BA[16]    + HVol_BA[17]    + HVol_BA[19]
	PMPD.PCE_AB  = if LinkDir = -1 then null else HPCEVol_AB[16] + HPCEVol_AB[17] + HPCEVol_AB[18]
	PMPD.PCE_BA  = if LinkDir = 1  then null else HPCEVol_BA[16] + HPCEVol_BA[17] + HPCEVol_BA[18]
	PMPD.VC_AB   = if LinkDir = -1 then null else PMPD.PCE_AB / PMCAP_AB
	PMPD.VC_BA   = if LinkDir = 1  then null else PMPD.PCE_BA / PMCAP_BA
	PMPD.SPD_AB  = if LinkDir = -1 then null else (H_VMT_AB[16] + H_VMT_AB[17] + H_VMT_AB[18])/(H_VHT_AB[16] + H_VHT_AB[17] + H_VHT_AB[18])
	PMPD.SPD_BA  = if LinkDir = 1  then null else (H_VMT_BA[16] + H_VMT_BA[17] + H_VMT_BA[18])/(H_VHT_BA[16] + H_VHT_BA[17] + H_VHT_BA[18])
	PMPD.TIME_AB = if LinkDir = -1 then null else Leng*60/PMPD.SPD_AB
	PMPD.TIME_BA = if LinkDir = 1  then null else Leng*60/PMPD.SPD_BA
	
	
	
	for i=1 to 24 do
		TOTVHT       = TOTVHT + nz(H_VHT_AB[i]) + nz(H_VHT_BA[i])
		TOTVHTCAR    = TOTVHTCAR + nz(H_VHT_VEH_AB[i]) + nz(H_VHT_VEH_BA[i])
		TOTVHTTRK    = TOTVHTTRK + nz(H_VHT_TRK_AB[i]) + nz(H_VHT_TRK_BA[i])
		
		TOTVHTSUTRK  = TOTVHTSUTRK + nz(H_VHT_SUTRK_AB[i]) + nz(H_VHT_SUTRK_BA[i])
		TOTVHTMUTRK  = TOTVHTMUTRK + nz(H_VHT_MUTRK_AB[i]) + nz(H_VHT_MUTRK_BA[i])
		
		TOTVMT       = TOTVMT + nz(H_VMT_AB[i]) + nz(H_VMT_BA[i])
		TOTVMTCAR    = TOTVMTCAR + nz(H_VMT_VEH_AB[i]) + nz(H_VMT_VEH_BA[i])
		TOTVMTTRK    = TOTVMTTRK + nz(H_VMT_TRK_AB[i]) + nz(H_VMT_TRK_BA[i])
		
		TOTVMTSUTRK  = TOTVMTSUTRK + nz(H_VMT_SUTRK_AB[i]) + nz(H_VMT_SUTRK_BA[i])
		TOTVMTMUTRK  = TOTVMTMUTRK + nz(H_VMT_MUTRK_AB[i]) + nz(H_VMT_MUTRK_BA[i])
		
		//AVGTT_AB     = (AVGTT_AB + (TT_AB[i])/24)
		//AVGTT_BA     = (AVGTT_BA + (TT_BA[i])/24)
		PKSPD_AB    = min(PKSPD_AB   , CGSpeed_ABLookUP[i]) //peak hour congested speed
		PKSPD_BA    = min(PKSPD_BA   , CGSpeed_BALookUP[i]) //peak hour congested speed
		MAXVC_AB     = max(MAXVC_AB    , VC_AB[i])
		MAXVC_BA     = max(MAXVC_BA    , VC_BA[i])
		MaxVol_AB    = max(MaxVol_AB   , HVol_AB[i])
		MaxVol_BA    = max(MaxVol_BA   , HVol_BA[i])
		MaxVolTrk_AB = max(MaxVolTrk_AB, HVolTrk_AB[i])
		MaxVolTrk_BA = max(MaxVolTrk_BA, HVolTrk_BA[i])
		MaxVolSUTRK_AB = max(MaxVolSUTRK_AB, HVolSu_AB[i])
		MaxVolSUTRK_BA = max(MaxVolSUTRK_BA, HVolSu_BA[i])
		MaxVolMUTRK_AB = max(MaxVolMUTRK_AB, HVolMu_AB[i])
		MaxVolMUTRK_BA = max(MaxVolMUTRK_BA, HVolMu_BA[i])
		
		
		TOTVEHFUEL  = TOTVEHFUEL + (nz(AutoFuelRate_AB[i])* nz(H_VMT_VEH_AB[i]) + nz(AutoFuelRate_BA[i]) * nz(H_VMT_VEH_BA[i])) * netparam.autofuel.value
		TOTTRKFUEL  = TOTTRKFUEL + (nz(TruckFuelRate_AB[i])* nz(H_VMT_TRK_AB[i]) + nz(TruckFuelRate_BA[i]) * nz(H_VMT_TRK_BA[i])) * netparam.trkfuel.value
		
		TOTSUTRKFUEL  = TOTSUTRKFUEL + (nz(SUTruckFuelRate_AB[i])* nz(H_VMT_SUTRK_AB[i]) + nz(SUTruckFuelRate_BA[i]) * nz(H_VMT_SUTRK_BA[i])) * netparam.sutrkfuel.value
		TOTMUTRKFUEL  = TOTMUTRKFUEL + (nz(MUTruckFuelRate_AB[i])* nz(H_VMT_MUTRK_AB[i]) + nz(MUTruckFuelRate_BA[i]) * nz(H_VMT_MUTRK_BA[i])) * netparam.mutrkfuel.value
		
		TOTVEHNFUEL = TOTVEHNFUEL +  (nz(H_VMT_VEH_AB[i]) +  nz(H_VMT_VEH_BA[i])) * netparam.autononf.value
		TOTTRKNFUEL = TOTTRKNFUEL +  (nz(H_VMT_TRK_AB[i]) +  nz(H_VMT_TRK_BA[i])) * netparam.trknonf.value 
		
		TOTSUTRKNFUEL = TOTSUTRKNFUEL +  (nz(H_VMT_SUTRK_AB[i]) +  nz(H_VMT_SUTRK_BA[i])) * netparam.sutrknonf.value 
		TOTMUTRKNFUEL = TOTMUTRKNFUEL +  (nz(H_VMT_MUTRK_AB[i]) +  nz(H_VMT_MUTRK_BA[i])) * netparam.mutrknonf.value 
		
		TOTVEHCOR   = TOTVEHCOR + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHCORATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHCORATE_BA[i])* netparam.COCOST.value
		TOTVEHCOS   = TOTVEHCOS + (nz(HVol_AB[i]) * 0.00000110231131 * VEHCO[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHCO[1])* netparam.COCOST.value
		TOTVEHCO2R  = TOTVEHCO2R + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHCO2RATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHCO2RATE_BA[i])* netparam.CO2COST.value
		TOTVEHCO2S  = TOTVEHCO2S + (nz(HVol_AB[i]) * 0.00000110231131 * VEHCO2[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHCO2[1])* netparam.CO2COST.value
		TOTVEHNOXR  = TOTVEHNOXR + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHNOXRATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHNOXRATE_BA[i])* netparam.NOXCOST.value
		TOTVEHNOXS  = TOTVEHNOXS + (nz(HVol_AB[i]) * 0.00000110231131 * VEHNOX[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHNOX[1])* netparam.NOXCOST.value
		TOTVEHPM10R = TOTVEHPM10R + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHPM10RATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHPM10RATE_BA[i])* netparam.PMCOST.value
		TOTVEHPM10S = TOTVEHPM10S + (nz(HVol_AB[i]) * 0.00000110231131 * VEHPM10[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHPM10[1])* netparam.PMCOST.value  
		TOTVEHPM25R = TOTVEHPM25R + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHPM25RATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHPM25RATE_BA[i])* netparam.PM25COST.value
		TOTVEHPM25S = TOTVEHPM25S + (nz(HVol_AB[i]) * 0.00000110231131 * VEHPM25[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHPM25[1])* netparam.PM25COST.value  
		TOTVEHSOXR  = TOTVEHSOXR + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHSOXRATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHSOXRATE_BA[i])* netparam.SOXCOST.value
		TOTVEHSOXS  = TOTVEHSOXS + (nz(HVol_AB[i]) * 0.00000110231131 * VEHSOX[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHSOX[1])* netparam.SOXCOST.value
		TOTVEHVOCR  = TOTVEHVOCR + (nz(H_VMT_VEH_AB[i]) * 0.00000110231131 * VEHVOCRATE_AB[i] + nz(H_VMT_VEH_BA[i]) * 0.00000110231131 * VEHVOCRATE_BA[i])* netparam.VOCCOST.value
		TOTVEHVOCS  = TOTVEHVOCS + (nz(HVol_AB[i]) * 0.00000110231131 * VEHVOC[1] + nz(HVol_BA[i]) * 0.00000110231131 * VEHVOC[1])* netparam.VOCCOST.value
		
		TOTTRKCOR   = TOTTRKCOR + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKCORATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKCORATE_BA[i])* netparam.COCOST.value
		TOTTRKCOS   = TOTTRKCOS + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKCO[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKCO[1])* netparam.COCOST.value
		TOTTRKCO2R  = TOTTRKCO2R + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKCO2RATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKCO2RATE_BA[i])* netparam.CO2COST.value
		TOTTRKCO2S  = TOTTRKCO2S + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKCO2[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKCO2[1])* netparam.CO2COST.value
		TOTTRKNOXR  = TOTTRKNOXR + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKNOXRATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKNOXRATE_BA[i])* netparam.NOXCOST.value
		TOTTRKNOXS  = TOTTRKNOXS + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKNOX[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKNOX[1])* netparam.NOXCOST.value
		TOTTRKPM10R = TOTTRKPM10R + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKPM10RATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKPM10RATE_BA[i])* netparam.PMCOST.value
		TOTTRKPM10S = TOTTRKPM10S + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKPM10[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKPM10[1])* netparam.PMCOST.value 
		TOTTRKPM25R = TOTTRKPM25R + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKPM25RATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKPM25RATE_BA[i])* netparam.PM25COST.value
		TOTTRKPM25S = TOTTRKPM25S + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKPM25[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKPM25[1])* netparam.PM25COST.value 		
		TOTTRKSOXR  = TOTTRKSOXR + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKSOXRATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKSOXRATE_BA[i])* netparam.SOXCOST.value
		TOTTRKSOXS  = TOTTRKSOXS + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKSOX[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKSOX[1])* netparam.SOXCOST.value
		TOTTRKVOCR  = TOTTRKVOCR + (nz(H_VMT_TRK_AB[i]) * 0.00000110231131 * TRKVOCRATE_AB[i] + nz(H_VMT_TRK_BA[i]) * 0.00000110231131 * TRKVOCRATE_BA[i])* netparam.VOCCOST.value
		TOTTRKVOCS  = TOTTRKVOCS + (nz(HVolTrk_AB[i]) * 0.00000110231131 * TRKVOC[1] + nz(HVolTrk_BA[i]) * 0.00000110231131 * TRKVOC[1])* netparam.VOCCOST.value 
		
		// What are these factors and do they need to be updated for SU - SB
		TOTSUTRKCOR   = TOTSUTRKCOR + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKCORATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKCORATE_BA[i])* netparam.COCOST.value
		TOTSUTRKCOS   = TOTSUTRKCOS + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKCO[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKCO[1])* netparam.COCOST.value
		TOTSUTRKCO2R  = TOTSUTRKCO2R + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKCO2RATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKCO2RATE_BA[i])* netparam.CO2COST.value
		TOTSUTRKCO2S  = TOTSUTRKCO2S + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKCO2[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKCO2[1])* netparam.CO2COST.value
		TOTSUTRKNOXR  = TOTSUTRKNOXR + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKNOXRATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKNOXRATE_BA[i])* netparam.NOXCOST.value
		TOTSUTRKNOXS  = TOTSUTRKNOXS + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKNOX[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKNOX[1])* netparam.NOXCOST.value
		TOTSUTRKPM10R = TOTSUTRKPM10R + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKPM10RATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKPM10RATE_BA[i])* netparam.PMCOST.value
		TOTSUTRKPM10S = TOTSUTRKPM10S + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKPM10[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKPM10[1])* netparam.PMCOST.value  
		TOTSUTRKPM25R = TOTSUTRKPM25R + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKPM25RATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKPM25RATE_BA[i])* netparam.PM25COST.value
		TOTSUTRKPM25S = TOTSUTRKPM25S + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKPM25[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKPM25[1])* netparam.PM25COST.value  
		TOTSUTRKSOXR  = TOTSUTRKSOXR + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKSOXRATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKSOXRATE_BA[i])* netparam.SOXCOST.value
		TOTSUTRKSOXS  = TOTSUTRKSOXS + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKSOX[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKSOX[1])* netparam.SOXCOST.value
		TOTSUTRKVOCR  = TOTSUTRKVOCR + (nz(H_VMT_SUTRK_AB[i]) * 0.00000110231131 * SUTRKVOCRATE_AB[i] + nz(H_VMT_SUTRK_BA[i]) * 0.00000110231131 * SUTRKVOCRATE_BA[i])* netparam.VOCCOST.value
		TOTSUTRKVOCS  = TOTSUTRKVOCS + (nz(HVolSu_AB[i]) * 0.00000110231131 * SUTRKVOC[1] + nz(HVolSu_BA[i]) * 0.00000110231131 * SUTRKVOC[1])* netparam.VOCCOST.value 
		
		// What are these factors and do they need to be updated for MU - SB
		TOTMUTRKCOR   = TOTMUTRKCOR + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKCORATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKCORATE_BA[i])* netparam.COCOST.value
		TOTMUTRKCOS   = TOTMUTRKCOS + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKCO[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKCO[1])* netparam.COCOST.value
		TOTMUTRKCO2R  = TOTMUTRKCO2R + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKCO2RATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKCO2RATE_BA[i])* netparam.CO2COST.value
		TOTMUTRKCO2S  = TOTMUTRKCO2S + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKCO2[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKCO2[1])* netparam.CO2COST.value
		TOTMUTRKNOXR  = TOTMUTRKNOXR + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKNOXRATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKNOXRATE_BA[i])* netparam.NOXCOST.value
		TOTMUTRKNOXS  = TOTMUTRKNOXS + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKNOX[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKNOX[1])* netparam.NOXCOST.value
		TOTMUTRKPM10R = TOTMUTRKPM10R + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKPM10RATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKPM10RATE_BA[i])* netparam.PMCOST.value
		TOTMUTRKPM10S = TOTMUTRKPM10S + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKPM10[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKPM10[1])* netparam.PMCOST.value  
		TOTMUTRKPM25R = TOTMUTRKPM25R + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKPM25RATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKPM25RATE_BA[i])* netparam.PM25COST.value
		TOTMUTRKPM25S = TOTMUTRKPM25S + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKPM25[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKPM25[1])* netparam.PM25COST.value  
		TOTMUTRKSOXR  = TOTMUTRKSOXR + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKSOXRATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKSOXRATE_BA[i])* netparam.SOXCOST.value
		TOTMUTRKSOXS  = TOTMUTRKSOXS + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKSOX[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKSOX[1])* netparam.SOXCOST.value
		TOTMUTRKVOCR  = TOTMUTRKVOCR + (nz(H_VMT_MUTRK_AB[i]) * 0.00000110231131 * MUTRKVOCRATE_AB[i] + nz(H_VMT_MUTRK_BA[i]) * 0.00000110231131 * MUTRKVOCRATE_BA[i])* netparam.VOCCOST.value
		TOTMUTRKVOCS  = TOTMUTRKVOCS + (nz(HVolMu_AB[i]) * 0.00000110231131 * MUTRKVOC[1] + nz(HVolMu_BA[i]) * 0.00000110231131 * MUTRKVOC[1])* netparam.VOCCOST.value 
	end
	
	// Length should be Leng since "Length" is not a data vector and was read into "Leng" - SB
	PKTIME_AB	 = Leng*60/PKSPD_AB //peak hour congested time
	PKTIME_BA	 = Leng*60/PKSPD_BA //peak hour congested time
	
	// ===== MAINLINE CRASHES ON LINE LAYER ===============================

	SetLayer(linevw)
	
	
	// add output fields if necessary
    r = "r"
    RunMacro("addfields", linevw, {"HSMclass", "xVMT", "Crashes_I_Tot", "Crashes_I_F", "Crashes_I_I", "Crashes_I_P"}, {r,r,r,r,r,r})
	RunMacro("addfields", linevw, {"Crashes_RM_Tot", "Crashes_RM_F", "Crashes_RM_I", "Crashes_RM_P"}, {r,r,r,r})
	RunMacro("addfields", linevw, {"Crashes_R2_Tot", "Crashes_R2_F", "Crashes_R2_I", "Crashes_R2_P"}, {r,r,r,r})
	RunMacro("addfields", linevw, {"Crashes_U_Tot", "Crashes_U_F", "Crashes_U_I", "Crashes_U_P"}, {r,r,r,r})
	RunMacro("addfields", linevw, {"Crashes_Tot", "Crashes_F", "Crashes_I", "Crashes_P"}, {r,r,r,r})
	 
	//--- Freeways --------------------
	//	Methods from TTI's Roadway Safety Design Workbook
	//	Assumed each ramp is counted on two mainline freeway links (up & downstream) and each mainline link therefore has 0.5 entrances and 0.5 exits
	
	// Replace variable names - SB
	// FHWA_FC -> FUNCCLASS
	// TOT_Dly -> TotFlow
	// TRK_Dly -> Tot_TRKFlow
	// Lanes -> NBR_LANES
	
	//qry = "Select * where (FUNCCLASS = 1 or FUNCCLASS = 11 or FUNCCLASS = 12 or (Access = 3 and FUNCCLASS < 20)) and STATE = 'TN'"
	qry = "Select * where (FUNCCLASS = 1 or FUNCCLASS = 11 or FUNCCLASS = 12 or (Access = 3 and FUNCCLASS < 20))"
	n = SelectByQuery("working", "Several", qry, )
	v1 = Vector(n, "float", {{"Constant", 1}})
	
	// Freeway Segments Multi-Vehicle and single-vehicle crashes

     // Remember TOT_Dly vs. Dly_Tot_Vol; TRK_Dly
	datavs = GetDataVectors(linevw + "|working", {"Length", "Dir", "TotFlow", "NBR_LANES", "LN_Width", "RS_Width", "FUNCCLASS", "AREA_TYPE", "LenEntRamp", "LenExtRamp", "MEDIAN", "Tot_SUT", "Tot_MUT"}, 
                                                  {{"Sort Order",{{"ID","Ascending"}}}})
	L = datavs[1]
	Dir = datavs[2]
	ADT = if (Dir = 0) then datavs[3] else 2*datavs[3]
    fdir = if (Dir = 0) then 1 else 0.5
	Lanes = datavs[4]
	LN_Width = datavs[5]
	RS_Width = datavs[6]
	//LS_Width
	//M_Width
	//Grade - in percents
	FUNCCLASS = datavs[7]
	Tot_TRKFlow = nz(datavs[12]) + nz(datavs[13])
	Rural = if (FUNCCLASS < 10) then 1 else 0
	TRKpct = 100*Tot_TRKFlow / ADT
	AREATYPE = datavs[8]
	MED = datavs[11]
	
	// Length of entry and exit ramps to calculate effective length - SB
	LenEntRamp = datavs[9]
	LenExtRamp = datavs[10]
	// Effective length Eq 3.13 - SB
	Leff = if((L - 0.5*Nz(LenEntRamp) - 0.5*Nz(LenExtRamp)) > 0) then (L - 0.5*Nz(LenEntRamp) - 0.5*Nz(LenExtRamp))
			else L
	
	//Baseline Number of Crashes
	// Should be using through lanes but info not available for freeways - SB
	// Areatype = 4 is rural; rest all is urban - SB
	
	// Multi-vehicle crashes
	NMVFI = if (Rural = 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-5.975 + 1.492*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-6.092 + 1.492*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-6.140 + 1.492*log(0.001*ADT)))
			else if (Rural <> 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-5.470 + 1.492*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-5.587 + 1.492*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-5.635 + 1.492*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 10) or (Dir <> 0 and Lanes >= 5)) then Leff*exp(-5.842 + 1.492*log(0.001*ADT)))
									
	NMVPDO = if (Rural = 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-6.882 + 1.936*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-7.141 + 1.936*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-7.329 + 1.936*log(0.001*ADT)))
			else if (Rural <> 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-6.548 + 1.936*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-6.809 + 1.936*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-6.997 + 1.936*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 10) or (Dir <> 0 and Lanes >= 5)) then Leff*exp(-7.260 + 1.936*log(0.001*ADT)))		
		
	
	// Single-vehicle crashes
	NSVFI = if (Rural = 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-2.126 + 0.646*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-2.055 + 0.646*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-1.985 + 0.646*log(0.001*ADT)))		// 09/27
			else if (Rural <> 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-2.126 + 0.646*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-2.055 + 0.646*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-1.985 + 0.646*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 10) or (Dir <> 0 and Lanes >= 5)) then Leff*exp(-1.915 + 0.646*log(0.001*ADT)))
									
	NSVPDO = if (Rural = 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-2.235 + 0.876*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-2.274 + 0.876*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-2.312 + 0.876*log(0.001*ADT)))
			else if (Rural <> 1) then (if((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then Leff*exp(-2.235 + 0.876*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then Leff*exp(-2.274 + 0.876*log(0.001*ADT))
									else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes >= 4)) then Leff*exp(-2.312 + 0.876*log(0.001*ADT))
									else if ((Dir = 0 and Lanes >= 10) or (Dir <> 0 and Lanes >= 5)) then Leff*exp(-2.351 + 0.876*log(0.001*ADT)))	
									


    // Road HAT base model
     if OptRHATfwy = 1 then do
          Ntot_fwy = if (Rural = 1) then 0.212*L*Pow(ADT/1000, 0.939) else 0.0056*L*Pow(ADT/1000, 2.016)
          Nfi_fwy = 0.16495*Ntot	// ratio from INDOT Interstates, 2004-2008
     end 

	//Crash Modification Factors (CMFs)
	// CMF for lane width .. same coefficients for SV and MV - SB
	CMFLWFI = if (LN_Width < 13) then (exp(-0.0376*(LN_Width-12)))
				else 0.963
				
	CMFLWPDO = 1.0
	
	// CMF for presence of median barrier .. same coefficients for SV and MV - SB
	CMFMPFI = if (MED = 1) then 0.131 else 1.0
	CMFMPPDO = if (MED = 1) then 0.169 else 1.0
	
	// CMF for outside shoulder width .. only for SV - SB
	// will require horizontal curve information - SB
	
	// Dont have horizontal curve, inside shoulder width, median width, volume concentration, lane change activity, rumble strips, outside clerance and barrier
	// Thus all the factors below are not used
	Pi = if (Rural = 1) then (if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 0.62 else 0.56)
		else if (Rural <> 1) then if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 0.44 
					else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then 0.37
					else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes = 4)) then 0.38
					else if ((Dir = 0 and Lanes > 8) or (Dir <> 0 and Lanes > 4)) then 0.41
	CMFlw = 1 + (Pi/0.62)*(exp(-0.050*(LN_Width - 12)) - 1)

	// CMF for outside/right shoulder width
	Pi = if (Rural = 1) then (if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 0.26 else 0.14)
		else if (Rural <> 1) then if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 0.15 
					else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then 0.089
					else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes = 4)) then 0.066
					else if ((Dir = 0 and Lanes > 8) or (Dir <> 0 and Lanes > 4)) then 0.071
	CMFrsw = 1 + (Pi/0.26)*(exp(-0.026*(RS_Width - 10)) - 1)

	// CMF for inside/left shoulder width - currently not used
     	Pi = if (Rural = 1) then (if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 0.30 else 0.32)
     		else if (Rural <> 1) then if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 0.20 
     					else if ((Dir = 0 and Lanes = 6) or (Dir <> 0 and Lanes = 3)) then 0.16
     					else if ((Dir = 0 and Lanes = 8) or (Dir <> 0 and Lanes = 4)) then 0.14
     					else if ((Dir = 0 and Lanes > 8) or (Dir <> 0 and Lanes > 4)) then 0.15
     	LS_Base = if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then 4 else 10	
     	CMFlsw = 1 + (Pi/0.30)*(exp(-0.028*(LS_Width - LS_Base)) - 1)
     
    // CMF for no barrier median width - currently not used
     	CMFmw = exp(-0.0296*(Pow(M_Width - LS_Width,0.5) - Pow(56 - LS_Base,0.5)))
     
    // CMF for full barrier median width - currently not used
     	Wicb = M_Width - LS_Width // approximation? check
     	CMFmw = if ((Dir = 0 and Lanes = 4) or (Dir <> 0 and Lanes = 2)) then exp(0.890*Wicb - 0.296*(Pow(2*M_Width,0.5) - 5.29))
     		else if ((Dir = 0 and Lanes > 4) or (Dir <> 0 and Lanes > 2)) then exp(0.890*Wicb - 0.296*(Pow(2*M_Width,0.5) - 2.45))
     
    // CMF for grade - currently not used
     	CMFg = exp(0.019*Grade)
	
	// CMF for Truck Percentage - currently not used
	CMFtrk = exp(-0.010*(TRKpct - 20))
	  
	// Final adjusted crashes
	// Using new factors - SB
	// Nfi_Fwy = fdir * Cfwy * Nfi * CMFlw * CMFrsw * Pow(CMFtrk, OptCMFtrk)
	Nfi_Fwy = fdir * (Nz(NSVFI) + Nz(NMVFI)) * CMFLWFI * CMFMPFI		// 09/27
	Npdo_Fwy = fdir * (Nz(NSVPDO) + Nz(NMVPDO)) * CMFLWPDO * CMFMPPDO	// 09/27
	Ntot_Fwy =  Nfi_Fwy + Npdo_Fwy

	Nf_Fwy = Nfi_Fwy * 0.01880	// proportion of fatal F/I crashes from TN. Split by road type not available - SB
	Ni_Fwy = Nfi_Fwy - Nf_Fwy
	xVMT = fdir*ADT*L

	SetDataVectors(linevw + "|working", {{"Crashes_I_Tot",Ntot_Fwy},{"Crashes_I_F",Nf_Fwy},{"Crashes_I_I",Ni_Fwy},{"Crashes_I_P",Npdo_Fwy},
                    {"xVMT",xVMT}, {"HSMclass",v1}}, 
				{{"Sort Order",{{"ID","Ascending"}}}})

	//--- Rural Multilane Highways --------------------
	//	Methods from Interactive Highway Safety Design Model (IHSDM) / Highway Safety Manaual (HSM)
	qry = "Select * where Access <> 3 and (FUNCCLASS < 10 and ((Dir = 0 and NBR_LANES > 3) or (Dir <> 0 and NBR_LANES > 1)))"
	n = SelectByQuery("working", "Several", qry, )
	v2 = Vector(n, "float", {{"Constant", 2}})

	datavs = GetDataVectors(linevw + "|working", {"Length", "Dir", "TotFlow", "Divided", "LN_Width", "RS_Width", "Access"}, 
                                                  {{"Sort Order",{{"ID","Ascending"}}}})
	L = datavs[1]
	Dir = datavs[2]
	ADT = if (Dir = 0) then datavs[3] else 2*datavs[3]
     fdir = if (Dir = 0) then 1 else 0.5
	Divided = datavs[4]
	LN_Width = datavs[5]
	RS_Width = datavs[6]
	Acc = datavs[7]
	
	//Baseline Number of Crashes
	// Factors checked - SB
	Ntot_RXL = if (Divided = 1) then exp(-9.025 + 1.049*log(ADT) + log(L)) else if (Divided <> 1) then exp(-9.653 + 1.176*log(ADT) + log(L))
	Nfi_RXL = if (Divided = 1) then exp(-8.837 + 0.958*log(ADT) + log(L)) else if (Divided <> 1) then exp(-9.410 + 1.094*log(ADT) + log(L))
    // Factors NOT checked - SB 
	if OptRHATRXL = 1 then do
          Ntot_RXL = 0.737*Pow(ADT/1000,0.654)*L
          Nfi_RXL = Ntot_RXL * 0.241709	// F/I proportion of all crashes from Indiana US Highways, 2004-2008  
    end

	//Crash Modification Factors (CMFs)
	// CMF for lane width
	// Factors checked and updated - SB
	CMFRA = if (Divided = 1) then (if (LN_Width >= 12) then 1.00
				else if (LN_Width >= 11) then if (ADT < 400) then 1.01 else if (ADT > 2000) then 1.03 else 1.01 + 0.0000125*(ADT - 400)
				else if (LN_Width >= 10) then if (ADT < 400) then 1.01 else if (ADT > 2000) then 1.15 else 1.01 + 0.0000875*(ADT - 400)
				else if (ADT < 400) then 1.03 else if (ADT > 2000) then 1.25 else 1.03 + 0.0001380*(ADT - 400)) 
		else if (Divided <> 1) then (if (LN_Width >= 12) then 1.00
				else if (LN_Width >= 11) then if (ADT < 400) then 1.01 else if (ADT > 2000) then 1.04 else 1.01 + 0.0000188*(ADT - 400)
				else if (LN_Width >= 10) then if (ADT < 400) then 1.02 else if (ADT > 2000) then 1.23 else 1.02 + 0.0001310*(ADT - 400)
				else if (ADT < 400) then 1.04 else if (ADT > 2000) then 1.38 else 1.04 + 0.0002130*(ADT - 400))
	pRA = if (Divided = 1) then 0.5 else 0.27 					
	CMFlw = (CMFRA - 1)*pRA + 1	

	// CMF for shoulder width	
	// Factors checked and updated - SB
	CMFWRA = if (Divided <> 1 ) then (if (RS_Width >= 8) then if (ADT < 400) then 0.98 else if (ADT > 2000) then 0.87 else 0.98 - 0.00006875*(ADT - 400) 
				else if (RS_Width >= 6) then 1.00
				else if (RS_Width >= 4) then if (ADT < 400) then 1.02 else if (ADT > 2000) then 1.15 else 1.02 + 0.00008125*(ADT - 400)
				else if (RS_Width >= 2) then if (ADT < 400) then 1.07 else if (ADT > 2000) then 1.30 else 1.07 + 0.00014300*(ADT - 400)
				else if (ADT < 400) then 1.10 else if (ADT > 2000) then 1.50 else 1.10 + 0.00025000*(ADT - 400)) 

	CMFrsw = if (Divided = 1) then (if (RS_Width >= 8) then 1.00 
				else if (RS_Width >= 6) then 1.04 
				else if (RS_Width >= 4) then 1.09 
				else if (RS_Width >= 2) then 1.13 
				else 1.18)
		//else if (Divided <> 1) then (CMFWRA - 1.00 - 1)*0.27 + 1 // I think this is incorrect. See Crash prediction for Rural Multi-Lane Hwy - SB
		else if (Divided <> 1) then (CMFWRA * 1.00 - 1)*pRA + 1 // The "*1" is for CMFTRA from IHSDM. Shouldnt be "-1". Also replace hard coded 0.27 with pRA - SB
		
	// CMF for median width
     	// currently not in use
		// Median width still not available thus is not used. - SB
     	CMF3 = if (Divided = 1) then if (M_Width >= 90) then 0.94
     				else if (M_Width >= 80) then 0.95 
     				else if (M_Width >= 60) then 0.96 
     				else if (M_Width >= 50) then 0.97 
     				else if (M_Width >= 40) then 0.99 
     				else if (M_Width >= 30) then 1.00 
     				else if (M_Width >= 20) then 1.02 
     				else 1.04
     		else if (Divided <> 1) then 1.00
	
	// CMF for access control based on NCHRP Report 420, p. 4 info on accidents for rural divided facilities
	// Not part of IHSDM thus disabled - SB
	CMFacc = if (Divided = 1) then (if (Acc = 1) then 1.25 else if (Acc = 2) then 1.00 else if (Acc = 3) then 0.75)
		else if (Divided <> 1) then if (Acc = 1) then 1.25 else if (Acc = 2) then 1.00 else if (Acc = 3) then 0.75 

	// Final adjusted crashes 
	// Not using access control (CMFacc) factors - SB
	/* Ntot_RXL = fdir * Ntot_RXL * CMFlw * CMFrsw * Pow(CMFacc, OptCMFacc)
	Nfi_RXL = fdir * Nfi_RXL * CMFlw * CMFrsw * Pow(CMFacc, OptCMFacc)*/
	if OptRHATCMFonly = 1 then do
	    Ntot_RXL = fdir * Ntot
	    Nfi_RXL = fdir * Nfi
	end
	Ntot_RXL = fdir * Ntot_RXL * CMFlw * CMFrsw 
	Nfi_RXL = fdir * Nfi_RXL * CMFlw * CMFrsw
	Npdo_RXL = Ntot_RXL - Nfi_RXL
	// The 0.02849 below is factor for IN - SB
	// Fatal crashes factor out of F/I crashes for TN is 0.01880 from 2011 to 2015 - SB
	// Nf_RXL = Nfi_RXL * 0.02849	// proportion of fatal F/I crashes from Indiana US Highways, 2004-2008 (65% of RXL in IN are US hwys comprising 39% of IN US hwys)
	Nf_RXL = Nfi_RXL * 0.01880	// proportion of fatal F/I crashes from TN. Split by road type not available - SB
	Ni_RXL = Nfi_RXL - Nf_RXL
	xVMT = fdir*ADT*L
	
	// Calibration Adjustments
	Nf_RXL = Nf_RXL * CrxlF
	Ni_RXL = Ni_RXL * CrxlI
	Npdo_RXL = Npdo_RXL * CrxlP
	Ntot_RXL = Nf_RXL + Ni_RXL + Npdo_RXL

	SetDataVectors(linevw + "|working", {{"Crashes_RM_Tot",Ntot_RXL},{"Crashes_RM_F",Nf_RXL},{"Crashes_RM_I",Ni_RXL},{"Crashes_RM_P",Npdo_RXL},
                    {"xVMT",xVMT},{"HSMclass",v2}}, 
				{{"Sort Order",{{"ID","Ascending"}}}})


	//--- Rural Two-Lane Highways --------------------
	//	Methods from Interactive Highway Safety Design Model (IHSDM) / Highway Safety Manaual (HSM) 
	
	qry = "Select * where Access <> 3 and (FUNCCLASS < 10 and ((Dir = 0 and NBR_LANES < 4) or (Dir <> 0 and NBR_LANES = 1)))"
	n = SelectByQuery("working", "Several", qry, )
	v3 = Vector(n, "float", {{"Constant", 3}})

	datavs = GetDataVectors(linevw + "|working", {"Length", "Dir", "TotFlow", "Divided", "LN_Width", "RS_Width", "NBR_LANES", "TWOTURNLN"}, {{"Sort Order",{{"ID","Ascending"}}}})
	L = datavs[1]
	Dir = datavs[2]
	ADT = if (Dir = 0) then datavs[3] else 2*datavs[3]
     fdir = if (Dir = 0) then 1 else 0.5
	Divided = datavs[4]
	LN_Width = datavs[5]
	RS_Width = datavs[6]
	//Grade - in percents
	
	// Recalculate lanes in 1 direction using NBR_LANES - SB
	NBR_LANES = datavs[7]
	LN1DIR = if (Dir = 0) then (NBR_LANES/2) else NBR_LANES
	
	// Get TWTL data from layer - SB
	//TWLTL = if (Divided = 1 and LN1DIR = 1) then 1 else 0
	TWLTL = NZ(datavs[8])

	//Baseline Number of Crashes
	// Factors checked - SB
	Ntot_R2L = ADT * L * 365 * pow(10,-6) * exp(-0.312)
	if OptTTIR2L = 1 then Ntot_R2L = 0.0537*Pow(0.001*ADT,1.3)*L
     if OptRHATR2L = 1 then Ntot_R2L = 0.922*Pow(ADT/1000,0.598)*L

	//Crash Modification Factors (CMFs)
	// CMF for lane width
	// Factors checked - SB
	CMFRA = if (LN_Width >= 12) then 1.00
		else if (LN_Width >= 11) then if (ADT < 400) then 1.01 else if (ADT > 2000) then 1.05 else 1.01 + 0.000025*(ADT - 400)
		else if (LN_Width >= 10) then if (ADT < 400) then 1.02 else if (ADT > 2000) then 1.30 else 1.02 + 0.000175*(ADT - 400)
		else if (ADT < 400) then 1.05 else if (ADT > 2000) then 1.50 else 1.05 + 0.000281*(ADT - 400) 
	// pra hard coded - SB
	CMFlw = (CMFRA - 1)*0.574 + 1
	if OptCMFlnwR2LIN = 1 then do
	    CMFlw = if (LN_Width >= 12) then 1.00
		else if (LN_Width >= 11) then 1.19
		else 1.41
	end
	
	// CMF for shoulder width
	// Factors checked - SB	
	CMFWRA = if (RS_Width >= 8) then if (ADT < 400) then 0.98 else if (ADT > 2000) then 0.87 else 0.98 - 0.00006875*(ADT - 400) 
		else if (RS_Width >= 6) then 1.00
		else if (RS_Width >= 4) then if (ADT < 400) then 1.02 else if (ADT > 2000) then 1.15 else 1.02 + 0.00008125*(ADT - 400)
		else if (RS_Width >= 2) then if (ADT < 400) then 1.07 else if (ADT > 2000) then 1.30 else 1.07 + 0.00014300*(ADT - 400)
		else if (ADT < 400) then 1.10 else if (ADT > 2000) then 1.50 else 1.10 + 0.00025000*(ADT - 400) 
	
	// Correct code below. There is no "-1.00" in IHSDM - SB 
	//CMFrsw = (CMFWRA - 1.00 - 1)*0.574 + 1 // I think this is incorrect. See Crash prediction for Rural Two-Lane Hwy - SB
	CMFrsw = (CMFWRA * 1.00 - 1)*0.574 + 1 // The "*1" is for CMFTRA (shoulder type) from IHSDM. Shouldnt be "-1" - SB
		
	
	// CMF for grade - currently not used
	//CMFg = if (Grade <= 3) then 1.00 else if (Grade <= 6) then 1.10 else 1.16
	
	// CMF for TWLTL
	CMFtwltl = if (TWLTL = 1) then 0.882 else 1.0	// assumes driveway density of 15/mi; 0.932 @ 10/mi or 0.836 @ 20/mi
	// CMF for TWLTL for IN from Tarko et. al
	if OptCMFtwltlIN = 1 then CMFtwltl = if (TWLTL = 1) then 0.53 else 1.0
	
	// Final adjusted crashes 
	// Factors checked - SB	
	Ntot_R2L = fdir * Ntot_R2L * CMFlw * CMFrsw *CMFtwltl
	if OptRHATCMFonly = 1 then Ntot_R2L = fdir * Ntot_R2L * CMFtwltl
	Npdo_R2L = Ntot_R2L * 0.679
	Nf_R2L = Ntot_R2L * 0.013
	Ni_R2L = Ntot_R2L - Nf_R2L - Npdo_R2L
	xVMT = fdir*ADT*L
	
	// Calibration Adjustments
	Nf_R2L = Nf_R2L * Cr2lF
	Ni_R2L = Ni_R2L * Cr2lI
	Npdo_R2L = Npdo_R2L * Cr2lP
	Ntot_R2L = Nf_R2L + Ni_R2L + Npdo_R2L

	SetDataVectors(linevw + "|working", {{"Crashes_R2_Tot",Ntot_R2L},{"Crashes_R2_F",Nf_R2L},{"Crashes_R2_I",Ni_R2L},{"Crashes_R2_P",Npdo_R2L},
                    {"xVMT",xVMT},{"HSMclass",v3}}, 
				{{"Sort Order",{{"ID","Ascending"}}}})


//--- Urban/Suburban Arterials --------------------
//	Methods from Interactive Highway Safety Design Model (IHSDM) / Highway Safety Manaual (HSM)

	qry = "Select * where Access <> 3 and FUNCCLASS < 20 and FUNCCLASS > 10"
	n = SelectByQuery("working", "Several", qry, )
	v4 = Vector(n, "float", {{"Constant", 4}})
	
	// Remove LN1DIR and calculate it from number of lanes - SB
	// Need to get driveway density ... DM fields - SB
	datavs = GetDataVectors(linevw + "|working", {"Length", "Dir", "TotFlow", "NBR_LANES", "Divided", "LN_Width", "RS_Width", "SPD_LMT", "TWOTURNLN", "Tot_SUT", "Tot_MUT"}, 
				                               {{"Sort Order",{{"ID","Ascending"}}}})
	L = datavs[1]
	Dir = datavs[2]
	ADT = if (Dir = 0) then datavs[3] else 2*datavs[3]
     fdir = if (Dir = 0) then 1 else 0.5	
	Lanes = datavs[4]
	LN1DIR = if (Dir = 0) then (Lanes/2) else Lanes
	Divided = datavs[5]
	LN_Width = datavs[6]
	RS_Width = datavs[7]
	DMjC = if (Dir <> null) then 0.01
	DmnC = if (Dir <> null) then 0.01
	DMjI = if (Dir <> null) then 0.01
	DmnI = if (Dir <> null) then 0.01
	DMjR = if (Dir <> null) then 0.01
	DmnR = if (Dir <> null) then 0.01
	Tot_TRKFlow = nz(datavs[10]) + nz(datavs[11])
	TRKpct = 100*Tot_TRKFlow / ADT
	PSpd = datavs[8]
	// TWLTL data available in DBD - SB
	// TWLTL = if ((Divided = 1 and LN1DIR = 1) or (Lanes = 5 and LN1DIR = 2)) then 1 else 0
	TWLTL = NZ(datavs[9])
	
	// SB - The definition: 
	// 2U = Two-lane undivided arterials; 3T = Three-lane arterials w/ center TWLTL;
	// 4U = Four-lane undivided arterial; 4D = Four-lane divided arterial;
	// 5T = Fine-lane arterials including TWLTL
	U2U = if (Dir = 0 and Lanes = 2 and Divided <> 1) then 1 else 0
	U3T = if ((Dir = 0 and Lanes < 4 and U2U = 0) or (Dir <> 0 and Lanes = 1)) then 1 else 0	// treat 1 lane 1 way as 3Ts
	U4U = if (Dir = 0 and Lanes > 3 and Divided <> 1 and Lanes <> 5 and Lanes <> 7) then 1 else 0
	U4D = if (Dir = 0 and Lanes > 3 and Divided = 1 and Lanes <> 5 and Lanes <> 7) then 1 else 0
	U5T = if ((Dir = 0 and (Lanes = 5 or Lanes = 7)) or (Dir <> 0 and Lanes > 1)) then 1 else 0	// treat multilane 1 ways as 5Ts    	
     	
	if OptRHATUrb <> 1 then do
     	//Baseline Number of Crashes
		// Factors checked and edited - SB
     	Nbrmv2U = if U2U = 1 then exp(-15.22+1.68*Log(ADT)+Log(L))  
     	Nbrmv3T = if U3T = 1 then exp(-12.40+1.41*Log(ADT)+Log(L)) 
     	Nbrmv4U = if U4U = 1 then exp(-11.63+1.33*Log(ADT)+Log(L)) 
     	Nbrmv4D = if U4D = 1 then exp(-12.34+1.36*Log(ADT)+Log(L)) 
     	Nbrmv5T = if U5T = 1 then exp(-9.70+1.17*Log(ADT)+Log(L)) 
     	NbrmvFI2U = if U2U = 1 then exp(-16.22+1.66*Log(ADT)+Log(L))
     	NbrmvFI3T = if U3T = 1 then exp(-16.45+1.69*Log(ADT)+Log(L)) 
     	NbrmvFI4U = if U4U = 1 then exp(-12.08+1.25*Log(ADT)+Log(L)) 
     	NbrmvFI4D = if U4D = 1 then exp(-12.76+1.28*Log(ADT)+Log(L)) 
     	NbrmvFI5T = if U5T = 1 then exp(-10.47+1.12*Log(ADT)+Log(L)) 
     	NbrmvPDO2U = if U2U = 1 then exp(-15.62+1.69*Log(ADT)+Log(L)) 
     	NbrmvPDO3T = if U3T = 1 then exp(-11.95+1.33*Log(ADT)+Log(L))
     	NbrmvPDO4U = if U4U = 1 then exp(-12.53+1.38*Log(ADT)+Log(L)) 
     	NbrmvPDO4D = if U4D = 1 then exp(-12.81+1.38*Log(ADT)+Log(L)) 
     	NbrmvPDO5T = if U5T = 1 then exp(-9.97+1.17*Log(ADT)+Log(L))
     
     	NbrmvFI2U = Nbrmv2U*NbrmvFI2U/(NbrmvFI2U+NbrmvPDO2U)
     	NbrmvFI3T = Nbrmv3T*NbrmvFI3T/(NbrmvFI3T+NbrmvPDO3T)
     	NbrmvFI4U = Nbrmv4U*NbrmvFI4U/(NbrmvFI4U+NbrmvPDO4U)
     	NbrmvFI4D = Nbrmv4D*NbrmvFI4D/(NbrmvFI4D+NbrmvPDO4D)
     	NbrmvFI5T = Nbrmv5T*NbrmvFI5T/(NbrmvFI5T+NbrmvPDO5T)
		
		// The PDO crashes would also need to be adjusted to match the total. See equation 3.23 - SB
		NbrmvPDO2U = Nbrmv2U - NbrmvFI2U
		NbrmvPDO3T = Nbrmv3T - NbrmvFI3T
     	NbrmvPDO4U = Nbrmv4U - NbrmvFI4U
     	NbrmvPDO4D = Nbrmv4D - NbrmvFI4D
     	NbrmvPDO5T = Nbrmv5T - NbrmvFI5T
		
		// Factors checked and edited - SB
     	Nbrsv2U = if U2U = 1 then exp(-5.47+0.56*Log(ADT)+Log(L))  
     	Nbrsv3T = if U3T = 1 then exp(-5.74+0.54*Log(ADT)+Log(L)) 
     	Nbrsv4U = if U4U = 1 then exp(-7.99+0.81*Log(ADT)+Log(L)) 
     	Nbrsv4D = if U4D = 1 then exp(-5.05+0.47*Log(ADT)+Log(L)) 
     	Nbrsv5T = if U5T = 1 then exp(-4.82+0.54*Log(ADT)+Log(L)) 
     	NbrsvFI2U = if U2U = 1 then exp(-3.96+0.23*Log(ADT)+Log(L))
     	NbrsvFI3T = if U3T = 1 then exp(-6.37+0.47*Log(ADT)+Log(L)) 
     	NbrsvFI4U = if U4U = 1 then exp(-7.37+0.61*Log(ADT)+Log(L)) 
     	NbrsvFI4D = if U4D = 1 then exp(-8.71+0.66*Log(ADT)+Log(L)) 
     	NbrsvFI5T = if U5T = 1 then exp(-4.43+0.35*Log(ADT)+Log(L)) 
     	NbrsvPDO2U = if U2U = 1 then exp(-6.51+0.64*Log(ADT)+Log(L)) 
     	NbrsvPDO3T = if U3T = 1 then exp(-6.29+0.56*Log(ADT)+Log(L))
     	NbrsvPDO4U = if U4U = 1 then exp(-8.50+0.84*Log(ADT)+Log(L)) 
     	NbrsvPDO4D = if U4D = 1 then exp(-5.04+0.45*Log(ADT)+Log(L)) 
     	NbrsvPDO5T = if U5T = 1 then exp(-5.83+0.61*Log(ADT)+Log(L))
     
     	NbrsvFI2U = Nbrsv2U*NbrsvFI2U/(NbrsvFI2U+NbrsvPDO2U)
     	NbrsvFI3T = Nbrsv3T*NbrsvFI3T/(NbrsvFI3T+NbrsvPDO3T)
     	NbrsvFI4U = Nbrsv4U*NbrsvFI4U/(NbrsvFI4U+NbrsvPDO4U)
     	NbrsvFI4D = Nbrsv4D*NbrsvFI4D/(NbrsvFI4D+NbrsvPDO4D)
     	NbrsvFI5T = Nbrsv5T*NbrsvFI5T/(NbrsvFI5T+NbrsvPDO5T)
		
		// The PDO crashes would also need to be adjusted to match the total. See equation 3.23 - SB
		NbrsvPDO2U = Nbrsv2U - NbrsvFI2U
     	NbrsvPDO3T = Nbrsv3T - NbrsvFI3T
     	NbrsvPDO4U = Nbrsv4U - NbrsvFI4U
     	NbrsvPDO4D = Nbrsv4D - NbrsvFI4D
     	NbrsvPDO5T = Nbrsv5T - NbrsvFI5T
		
		// Factors checked and edited - SB
          Nbrdwy2U = if U2U = 1 then (0.158*DMjC + 0.050*DmnC + 0.172*DMjI + 0.023*DmnI + 0.083*DMjR + 0.016*DmnR)*Pow(ADT/15000,1.0)
          Nbrdwy3T = if U3T = 1 then (0.102*DMjC + 0.032*DmnC + 0.110*DMjI + 0.015*DmnI + 0.053*DMjR + 0.010*DmnR)*Pow(ADT/15000,1.0)
          Nbrdwy4U = if U4U = 1 then (0.182*DMjC + 0.058*DmnC + 0.198*DMjI + 0.026*DmnI + 0.096*DMjR + 0.018*DmnR)*Pow(ADT/15000,1.172)
          Nbrdwy4D = if U4D = 1 then (0.033*DMjC + 0.011*DmnC + 0.036*DMjI + 0.005*DmnI + 0.018*DMjR + 0.003*DmnR)*Pow(ADT/15000,1.106)
          Nbrdwy5T = if U5T = 1 then (0.165*DMjC + 0.053*DmnC + 0.181*DMjI + 0.024*DmnI + 0.087*DMjR + 0.016*DmnR)*Pow(ADT/15000,1.172)
          
		// Factors checked and edited - SB  
          NbrdwyFI2U = 0.323*Nbrdwy2U
          NbrdwyFI3T = 0.243*Nbrdwy3T
          NbrdwyFI4U = 0.342*Nbrdwy4U
          NbrdwyFI4D = 0.284*Nbrdwy4D
          NbrdwyFI5T = 0.269*Nbrdwy5T
               
          Nbr2U = Nbrmv2U + Nbrsv2U + Nbrdwy2U
          Nbr3T = Nbrmv3T + Nbrsv3T + Nbrdwy3T
          Nbr4U = Nbrmv4U + Nbrsv4U + Nbrdwy4U
          Nbr4D = Nbrmv4D + Nbrsv4D + Nbrdwy4D
          Nbr5T = Nbrmv5T + Nbrsv5T + Nbrdwy5T
          
          NbrFI2U = NbrmvFI2U + NbrsvFI2U + NbrdwyFI2U
          NbrFI3T = NbrmvFI3T + NbrsvFI3T + NbrdwyFI3T
          NbrFI4U = NbrmvFI4U + NbrsvFI4U + NbrdwyFI4U
          NbrFI4D = NbrmvFI4D + NbrsvFI4D + NbrdwyFI4D
          NbrFI5T = NbrmvFI5T + NbrsvFI5T + NbrdwyFI5T
     end
              
	//Crash Modification Factors (CMFs)
	// These CMFs are not in the IHSM. Do we still use any of them? - SB
	// CMF for lane width from TTI
     Pi = if (Divided = 1) then 0.26 else if ((Dir = 0 and Lanes < 4) or (Dir <> 0 and Lanes = 1)) then 0.27 
                                        else if ((Dir = 0 and Lanes < 6) or (Dir <> 0 and Lanes = 2)) then 0.17 else 0.13
     CMFlw = Pow((1 + (Pi/0.26)*(exp(-0.042*(LN_Width - 12)) - 1)),OptCMFlwUA) 
	// CMF for shoulder width from TTI
     Pi = if (Divided = 1) then if (Lanes < 6) then 0.11 else 0.08
           else if (Divided <> 1) then if ((Dir = 0 and Lanes < 4) or (Dir <> 0 and Lanes = 1)) then 0.19 
                                   else if ((Dir = 0 and Lanes < 6) or (Dir <> 0 and Lanes = 2)) then 0.094 else 0.050
     CMFrsw = Pow((1 + (Pi/0.11)*(exp(-0.032*(RS_Width - 1.5)) - 1)),OptCMFrswUA) 
	// CMF for Truck Percentage from TTI
	CMFtrk = pow(exp(-0.068*(TRKpct - 6)),OptCMFtrkUA)
	// CMF for lighting - base is no lighting which is not correct in Indiana urban/suburban areas?
	// This is from IHSM - SB
	Pinr = if (U2U = 1) then 0.424 
          else if (U3T = 1) then 0.429
          else if (U4U = 1) then 0.517
          else if (U4D = 1) then 0.364
          else if (U5T = 1) then 0.432
     Ppnr = if (U2U = 1) then 0.576
          else if (U3T = 1) then 0.571
          else if (U4U = 1) then 0.438
          else if (U4D = 1) then 0.636
          else if (U5T = 1) then 0.568
     Pnr = if (U2U = 1) then 0.316 
          else if (U3T = 1) then 0.304
          else if (U4U = 1) then 0.365
          else if (U4D = 1) then 0.410
          else if (U5T = 1) then 0.274
     CMFlt = pow(1 - (Pnr*(1 - 0.72*Pinr - 0.83*Ppnr)), OptCMFlt)
	// CMF for TWLTL for IN from Tarko et. al
	// This is not from IHSM - SB
	CMFtwltl = if (TWLTL = 1) then 0.53 else 1.0
     

	if OptRHATUrb <> 1 then do
          Nbr2U = Nbr2U*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          Nbr3T = Nbr3T*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          Nbr4U = Nbr4U*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          Nbr4D = Nbr4D*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          Nbr5T = Nbr5T*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          
          NbrFI2U = NbrFI2U*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          NbrFI3T = NbrFI3T*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          NbrFI4U = NbrFI4U*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          NbrFI4D = NbrFI4D*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
          NbrFI5T = NbrFI5T*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)
               
          // Vehicle-Pedestrian Crashes
		  // Factors checked - SB
          fpedr = if (PSpd <= 30) then if U2U = 1 then 0.036 
                                   else if U3T = 1 then 0.041 
                                   else if U4U = 1 then 0.022 
                                   else if U4D = 1 then 0.067 
                                   else if U5T = 1 then 0.030
                    else if (PSpd > 30) then if U2U = 1 then 0.005 
                                        else if U3T = 1 then 0.013 
                                        else if U4U = 1 then 0.009 
                                        else if U4D = 1 then 0.019 
                                        else if U5T = 1 then 0.023
          Npedr2U = Nbr2U*fpedr
          Npedr3T = Nbr3T*fpedr
          Npedr4U = Nbr4U*fpedr
          Npedr4D = Nbr4D*fpedr
          Npedr5T = Nbr5T*fpedr
     
          // Vehicle-Bicycle Crashes
          fbiker = if (PSpd <= 30) then if U2U = 1 then 0.018 
                                   else if U3T = 1 then 0.027 
                                   else if U4U = 1 then 0.011 
                                   else if U4D = 1 then 0.013 
                                   else if U5T = 1 then 0.050
                    else if (PSpd > 30) then if U2U = 1 then 0.004 
                                        else if U3T = 1 then 0.007 
                                        else if U4U = 1 then 0.002 
                                        else if U4D = 1 then 0.005 
                                        else if U5T = 1 then 0.012
          Nbiker2U = Nbr2U*fbiker
          Nbiker3T = Nbr3T*fbiker
          Nbiker4U = Nbr4U*fbiker
          Nbiker4D = Nbr4D*fbiker
          Nbiker5T = Nbr5T*fbiker     
          
          // Final Segment Crashes
          Nrs2U = Nz(Nbr2U) + Nz(Npedr2U) + Nz(Nbiker2U)
          Nrs3T = Nz(Nbr3T) + Nz(Npedr3T) + Nz(Nbiker3T)
          Nrs4U = Nz(Nbr4U) + Nz(Npedr4U) + Nz(Nbiker4U)
          Nrs4D = Nz(Nbr4D) + Nz(Npedr4D) + Nz(Nbiker4D)
          Nrs5T = Nz(Nbr5T) + Nz(Npedr5T) + Nz(Nbiker5T)
          
          NrsFI2U = Nz(NbrFI2U) + Nz(Npedr2U) + Nz(Nbiker2U)
          NrsFI3T = Nz(NbrFI3T) + Nz(Npedr3T) + Nz(Nbiker3T)
          NrsFI4U = Nz(NbrFI4U) + Nz(Npedr4U) + Nz(Nbiker4U)
          NrsFI4D = Nz(NbrFI4D) + Nz(Npedr4D) + Nz(Nbiker4D)
          NrsFI5T = Nz(NbrFI5T) + Nz(Npedr5T) + Nz(Nbiker5T)
          
          Nrs = fdir * (Nz(Nrs2U) + Nz(Nrs3T) + Nz(Nrs4U) + Nz(Nrs4D) + Nz(Nrs5T)) 
          NrsFI = fdir * (Nz(NrsFI2U) + Nz(NrsFI3T) + Nz(NrsFI4U) + Nz(NrsFI4D) + Nz(NrsFI5T)) 
     end
     
	 // Not used for TN - SB
     if OptRHATUrb = 1 then do
          Nrs = if (LN1DIR = 1) then 0.733*Pow(ADT/1000,0.917)*L else 2.641*Pow(ADT/1000,0.458)*L
          CMFddIN = 0.0126*(DMjC + DmnC + DMjI + DmnI + DMjR + DmnR) + 0.4596   // based on Tarko et al.
          Nrs = fdir * Ntot*CMFlw*CMFrsw*CMFtrk*CMFlt*Pow(CMFtwltl,OptCMFtwltlIN)*Pow(CMFddIN,OptCMFddIN)
          if OptRHATCMFonly = 1 then Nrs = fdir * Ntot*Pow(CMFtwltl,OptCMFtwltlIN)*Pow(CMFddIN,OptCMFddIN)
          NrsFI = Nrs * 0.19199	// F/I proportion of all crashes from Indiana local roads and streets, 2003-2008  
     end
     
     NrsPDO = Nrs - NrsFI
     // For TN the split by road type is not available thus use the overall split - SB
	 //NrsF = NrsFI*0.0140      // ratio for Indiana local roads and streets, 2003-2008
	 NrsF = NrsFI*0.01880      // ratio for TN  from 2011 to 2015 - SB
     NrsI = NrsFI - NrsF
	xVMT = fdir*ADT*L
		
	// Calibration Adjustments
	NrsF = NrsF * CurbF
	NrsI = NrsI * CurbI
	NrsPDO = NrsPDO * CurbP
	Nrs = NrsF + NrsI + NrsPDO

	SetDataVectors(linevw + "|working", {{"Crashes_U_Tot",Nrs},{"Crashes_U_F",NrsF},{"Crashes_U_I",NrsI},{"Crashes_U_P",NrsPDO},
                                        {"xVMT",xVMT},{"HSMclass",v4}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})     

     DeleteSet("working")     
	
	datavs = GetDataVectors(linevw + "|Mod", {	"Crashes_I_Tot", "Crashes_I_F", "Crashes_I_I", "Crashes_I_P",
											"Crashes_RM_Tot", "Crashes_RM_F", "Crashes_RM_I", "Crashes_RM_P", 
											"Crashes_R2_Tot", "Crashes_R2_F", "Crashes_R2_I", "Crashes_R2_P",
											"Crashes_U_Tot", "Crashes_U_F", "Crashes_U_I", "Crashes_U_P",
											"xVMT", "HSMclass"},
                                                  {{"Sort Order",{{"ID","Ascending"}}}})
	
	Crashes_Total_Links 	= 	Nz(datavs[1]) + Nz(datavs[5]) + Nz(datavs[9]) + Nz(datavs[13])

	Crashes_Fatal_Links 	= 	Nz(datavs[2]) + Nz(datavs[6]) + Nz(datavs[10]) + Nz(datavs[14])
	
	Crashes_Injury_Links 	= 	Nz(datavs[3]) + Nz(datavs[7]) + Nz(datavs[11]) + Nz(datavs[15])
	
	Crashes_PDO_Links 		= 	Nz(datavs[4]) + Nz(datavs[8]) + Nz(datavs[12]) + Nz(datavs[16])
	
	xVMT 					= 	datavs[17]
	HSMclass				= 	datavs[18]
	
	SetDataVectors(linevw + "|Mod", {{"Crashes_Tot",Crashes_Total_Links},{"Crashes_F",Crashes_Fatal_Links},{"Crashes_I",Crashes_Injury_Links},{"Crashes_P",Crashes_PDO_Links}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})											  
	
//===== INTERSECTION CRASHES ON NODE LAYER ===============================
     SetLayer(nodevw)
     //RunMacro("NodeFields", {linevw})  

     // add output fields if necessary
     r = "r"
	 RunMacro("addfields", nodevw, {"HSMclass", "Crashes_2L_Tot", "Crashes_2L_F", "Crashes_2L_I", "Crashes_2L_P"}, {r,r,r,r,r})
	 RunMacro("addfields", nodevw, {"Crashes_ML_Tot", "Crashes_ML_F", "Crashes_ML_I", "Crashes_ML_P"}, {r,r,r,r})
	 RunMacro("addfields", nodevw, {"Crashes_U_Tot", "Crashes_U_F", "Crashes_U_I", "Crashes_U_P"}, {r,r,r,r})
	 RunMacro("addfields", nodevw, {"Crashes_Tot", "Crashes_F", "Crashes_I", "Crashes_P"}, {r,r,r,r})
     	
//--- Rural Intersections --------------------	
     // - Two-lane - 
	qry = "Select * where TAZID = null and Access <> 0 and Urban <> 1 and Multilane <> 1 and Links > 2 and Access = 1" // Only Access = 1 will be the same but this is more readable - SB
	n = SelectByQuery("working", "Several", qry, )
	vn1 = Vector(n, "float", {{"Constant", 1}})

	datavs = GetDataVectors(nodevw + "|working", {"Links", "IntADT", "Control_Imp", "MinADT", "MaxADT"}, 
                                                  {{"Sort Order",{{"ID","Ascending"}}}})     
	Legs = datavs[1]
	IntADT = datavs[2]
	Ctrl = datavs[3]
	MinADT = datavs[4]
	MaxADT = datavs[5]
	
  	//Baseline Number of Crashes - HSM/IHSDM
	// Adding +1 to both AADTs because there are lots of zeros in min and max ADT - SB
	// We can change this by not having a max/min AADT but then the log will still produce an error - SB
	// Factors checked - SB
     Ntot = if (Legs = 3 and Ctrl <> 1) then exp(-9.86 + 0.79*log(MaxADT + 1) + 0.49*log(MinADT + 1)) else 
               if (Ctrl <> 1) then exp(-8.56 + 0.60*log(MaxADT + 1) + 0.61*log(MinADT + 1)) else
                    exp(-5.13 + 0.60*log(MaxADT + 1) + 0.20*log(MinADT + 1))
     
  	//Baseline Number of Crashes - RoadHAT
     if OptRHATrurint = 1 then Ntot = if (Ctrl = 1) then 0.30*Pow(IntADT/1000, 0.953) else 
                                        if (Ctrl > 2) then 0.274*Pow(IntADT/1000, 1.324) else 0.522*Pow(IntADT/1000, 1.093)

     // Currently no CMFs for rural two lane intersections - skew angle could be added 
     
     
     // Final Intersection Crashes 
	 // Factors checked and set to HSM defaults - SB
     Nf = if (Ctrl = 1) then Ntot * 0.009 else if (Legs = 3) then Ntot * 0.017 else Ntot * 0.018
     Npdo = if (Ctrl = 1) then Ntot * 0.660 else if (Legs = 3) then Ntot * 0.585 else Ntot * 0.569
     Ni = Ntot - Nf - Npdo
          
	// Calibration Adjustments
	Nf = Nf * Cr2liF
	Ni = Ni * Cr2liI
	Npdo = Npdo * Cr2liP
	Ntot = Nf + Ni + Npdo
     
	SetDataVectors(nodevw + "|working", {{"Crashes_2L_Tot",Ntot},{"Crashes_2L_F",Nf},{"Crashes_2L_I",Ni},{"Crashes_2L_P",Npdo},
                                        {"HSMclass",vn1}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})     
     

     // - Multilane - 
	qry = "Select * where TAZID = null and Access <> 0 and Urban <> 1 and Multilane = 1 and Links > 2 and Access = 1"
	n = SelectByQuery("working", "Several", qry, )
	vn2 = Vector(n, "float", {{"Constant", 2}})

	datavs = GetDataVectors(nodevw + "|working", {"Links", "IntADT", "Control_Imp", "MinADT", "MaxADT"}, 
                                                  {{"Sort Order",{{"ID","Ascending"}}}})     // need to create "Signal" on CM nodes
	Legs = datavs[1]
	IntADT = datavs[2]
	Ctrl = datavs[3]
	MinADT = datavs[4]
	MaxADT = datavs[5]
	
  	//Baseline Number of Crashes - HSM/IHSDM
	// +1 aded to all ADT to address the 0 ADT problem. LN(1) = 0 - SB
     Ntot = if (Legs = 3 and Ctrl <> 1) then exp(-12.526 + 1.204*log(MaxADT + 1) + 0.236*log(MinADT + 1)) else 
               if (Ctrl <> 1) then exp(-10.008 + 0.848*log(MaxADT + 1) + 0.448*log(MinADT + 1)) else
                    exp(-7.182 + 0.722*log(MaxADT + 1) + 0.337*log(MinADT + 1))
     Nfi = if (Legs = 3 and Ctrl <> 1) then exp(-12.664 + 1.107*log(MaxADT + 1) + 0.272*log(MinADT + 1)) else 
               if (Ctrl <> 1) then exp(-11.554 + 0.888*log(MaxADT + 1) + 0.525*log(MinADT + 1)) else
                    exp(-6.393 + 0.638*log(MaxADT + 1) + 0.232*log(MinADT + 1))
     
  	//Baseline Number of Crashes - RoadHAT
     if OptRHATrurint = 1 then do
          Ntot = if (Ctrl = 1) then 0.30*Pow(IntADT/1000, 0.953) else 
                                        if (Ctrl > 2) then 0.274*Pow(IntADT/1000, 1.324) else 0.522*Pow(IntADT/1000, 1.093)
          Nfi = if (Ctrl = 1) then Ntot * (1 - 0.660) else if (Legs = 3) then Ntot * (1 - 0.585) else Ntot * (1 - 0.569)
     end
          
     // Currently no CMFs for rural multilane intersections - skew angle could be added or default turning lanes assumed, etc. 
     
     // Final Intersection Crashes
     Nf = if (Ctrl = 1) then Ntot * 0.009 else if (Legs = 3) then Ntot * 0.017 else Ntot * 0.018
     Ni = Nfi - Nf
     Npdo = Ntot - Nfi
               
	// Calibration Adjustments
	Nf = Nf * CrxliF
	Ni = Ni * CrxliI
	Npdo = Npdo * CrxliP
	Ntot = Nf + Ni + Npdo
	
	SetDataVectors(nodevw + "|working", {{"Crashes_ML_Tot",Ntot},{"Crashes_ML_F",Nf},{"Crashes_ML_I",Ni},{"Crashes_ML_P",Npdo},
                                        {"HSMclass",vn2}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})       


//--- Urban Intersections --------------------

	qry = "Select * where TAZID = null and Access <> 0 and Urban = 1 and Links > 2 and Access = 1"
	n = SelectByQuery("working", "Several", qry, )
	vn3 = Vector(n, "float", {{"Constant", 3}})

	datavs = GetDataVectors(nodevw + "|working", {"Links", "IntADT", "Control_Imp", "MinADT", "MaxADT", "Multilane"}, 
                                                  {{"Sort Order",{{"ID","Ascending"}}}})     // need to create "Signal" on CM nodes
	Legs = datavs[1]
	IntADT = datavs[2]
	Ctrl = datavs[3]
	MinADT = datavs[4]
	MaxADT = datavs[5]
	multilane = datavs[6]
	UI3ST = if (Ctrl <> 1 and Legs = 3) then 1 else 0
	UI4ST = if (Ctrl <> 1 and Legs > 3) then 1 else 0
	UI3SG = if (Ctrl = 1 and Legs = 3) then 1 else 0
	UI4SG = if (Ctrl = 1 and Legs > 3) then 1 else 0
     
  	//Baseline Number of Crashes - RoadHAT
     if OptRHATurbint = 1 then do
          Ntot = if (Ctrl = 1) then 0.30*Pow(IntADT/1000, 0.953) else 
                                        if (Ctrl > 2) then 0.274*Pow(IntADT/1000, 1.324) else 0.522*Pow(IntADT/1000, 1.093)
          Nfi = if (Ctrl = 1) then Ntot * (1 - 0.660) else if (Legs = 3) then Ntot * (1 - 0.585) else Ntot * (1 - 0.569)
     end
     else do
       	//Baseline Number of Crashes - HSM/IHSDM
     	Nbimv3ST = if UI3ST = 1 then exp(-13.36+1.11*Log(MaxADT + 1)+0.41*Log(MinADT + 1))  
     	Nbimv3SG = if UI3SG = 1 then exp(-12.13+1.11*Log(MaxADT + 1)+0.26*Log(MinADT + 1)) 
     	Nbimv4ST = if UI4ST = 1 then exp(-8.90+0.82*Log(MaxADT + 1)+0.25*Log(MinADT + 1)) 
     	Nbimv4SG = if UI4SG = 1 then exp(-10.99+1.07*Log(MaxADT + 1)+0.23*Log(MinADT + 1)) 
     	NbimvFI3ST = if UI3ST = 1 then exp(-14.01+1.16*Log(MaxADT + 1)+0.30*Log(MinADT + 1))
     	NbimvFI3SG = if UI3SG = 1 then exp(-11.58+1.02*Log(MaxADT + 1)+0.17*Log(MinADT + 1)) 
     	NbimvFI4ST = if UI4ST = 1 then exp(-11.13+0.93*Log(MaxADT + 1)+0.28*Log(MinADT + 1)) 
     	NbimvFI4SG = if UI4SG = 1 then exp(-13.14+1.18*Log(MaxADT + 1)+0.22*Log(MinADT + 1)) 
     	NbimvPDO3ST = if UI3ST = 1 then exp(-15.38+1.20*Log(MaxADT + 1)+0.51*Log(MinADT + 1)) 
     	NbimvPDO3SG = if UI3SG = 1 then exp(-13.24+1.14*Log(MaxADT + 1)+0.30*Log(MinADT + 1))
     	NbimvPDO4ST = if UI4ST = 1 then exp(-8.74+0.77*Log(MaxADT + 1)+0.23*Log(MinADT + 1)) 
     	NbimvPDO4SG = if UI4SG = 1 then exp(-11.02+1.02*Log(MaxADT + 1)+0.24*Log(MinADT + 1)) 
     
     	NbimvFI3ST = Nbimv3ST*NbimvFI3ST/(NbimvFI3ST+NbimvPDO3ST)
     	NbimvFI3SG = Nbimv3SG*NbimvFI3SG/(NbimvFI3SG+NbimvPDO3SG)
     	NbimvFI4ST = Nbimv4ST*NbimvFI4ST/(NbimvFI4ST+NbimvPDO4ST)
     	NbimvFI4SG = Nbimv4SG*NbimvFI4SG/(NbimvFI4SG+NbimvPDO4SG)
		
		// The PDO crashes would also need to be adjusted to match the total. See equation 3.80 - SB
		NbimvPDO3ST = Nbimv3ST - NbimvFI3ST
     	NbimvPDO3SG = Nbimv3SG - NbimvFI3SG
     	NbimvPDO4ST = Nbimv4ST - NbimvFI4ST
     	NbimvPDO4SG = Nbimv4SG - NbimvFI4SG
		
     	Nbisv3ST = if UI3ST = 1 then exp(-6.81+0.16*Log(MaxADT + 1)+0.51*Log(MinADT + 1))  
     	Nbisv3SG = if UI3SG = 1 then exp(-9.02+0.42*Log(MaxADT + 1)+0.40*Log(MinADT + 1)) 
     	Nbisv4ST = if UI4ST = 1 then exp(-5.33+0.33*Log(MaxADT + 1)+0.12*Log(MinADT + 1)) 
     	Nbisv4SG = if UI4SG = 1 then exp(-10.21+0.68*Log(MaxADT + 1)+0.27*Log(MinADT + 1)) 
     	NbisvFI3ST = if UI3ST = 1 then 0.31*Nbisv3ST
     	NbisvFI3SG = if UI3SG = 1 then exp(-9.75+0.27*Log(MaxADT + 1)+0.51*Log(MinADT + 1)) 
     	NbisvFI4ST = if UI4ST = 1 then 0.28*Nbisv4ST
     	NbisvFI4SG = if UI4SG = 1 then exp(-9.25+0.43*Log(MaxADT + 1)+0.29*Log(MinADT + 1)) 
     	NbisvPDO3ST = if UI3ST = 1 then exp(-8.36+0.25*Log(MaxADT + 1)+0.55*Log(MinADT + 1)) 
     	NbisvPDO3SG = if UI3SG = 1 then exp(-9.08+0.45*Log(MaxADT + 1)+0.33*Log(MinADT + 1))
     	NbisvPDO4ST = if UI4ST = 1 then exp(-7.04+0.36*Log(MaxADT + 1)+0.25*Log(MinADT + 1)) 
     	NbisvPDO4SG = if UI4SG = 1 then exp(-11.34+0.78*Log(MaxADT + 1)+0.25*Log(MinADT + 1)) 
     
     	NbisvFI3ST = Nbisv3ST*NbisvFI3ST/(NbisvFI3ST+NbisvPDO3ST)
     	NbisvFI3SG = Nbisv3SG*NbisvFI3SG/(NbisvFI3SG+NbisvPDO3SG)
     	NbisvFI4ST = Nbisv4ST*NbisvFI4ST/(NbisvFI4ST+NbisvPDO4ST)
     	NbisvFI4SG = Nbisv4SG*NbisvFI4SG/(NbisvFI4SG+NbisvPDO4SG)
		
		// The PDO crashes would also need to be adjusted to match the total. See equation 3.80 - SB
       	NbisvPDO3ST = Nbisv3ST - NbisvFI3ST
     	NbisvPDO3SG = Nbisv3SG - NbisvFI3SG
     	NbisvPDO4ST = Nbisv4ST - NbisvFI4ST
     	NbisvPDO4SG = Nbisv4SG - NbisvFI4SG
		
          Nbi3ST = Nbimv3ST + Nbisv3ST
          Nbi3SG = Nbimv3SG + Nbisv3SG
          Nbi4ST = Nbimv4ST + Nbisv4ST
          Nbi4SG = Nbimv4SG + Nbisv4SG
          
          NbiFI3ST = NbimvFI3ST + NbisvFI3ST
          NbiFI3SG = NbimvFI3SG + NbisvFI3SG
          NbiFI4ST = NbimvFI4ST + NbisvFI4ST
          NbiFI4SG = NbimvFI4SG + NbisvFI4SG
          
          // Currently no CMFs - require operational detail (turning lane/phasing info)
          
          // Ped crashes assumes medium pedestrian activity - 400/day 3leg; 700/day 4leg 
		  // Add +1 to ADT - SB
          nlanesx = if multilane = 1 then 4 else 2
          Npedi3ST = if UI3ST = 1 then 0.021*Nbi3ST
          Npedi3SG = if UI3SG = 1 then exp(-6.60+0.05*Log(IntADT + 1)+0.24*Log((MinADT+ 1)/(MaxADT+ 1))+0.41*log(400)+0.09*nlanesx) 
          Npedi4ST = if UI4ST = 1 then 0.022*Nbi4ST
          Npedi4SG = if UI4SG = 1 then exp(-9.53+0.40*Log(IntADT+ 1)+0.26*Log((MinADT+ 1)/(MaxADT+ 1))+0.45*log(700)+0.04*nlanesx) 
          Npedi = Nz(Npedi3ST) + Nz(Npedi3SG) + Nz(Npedi4ST) + Nz(Npedi4SG)
          Nbikei3ST = if UI3ST = 1 then 0.016*Nbi3ST
          Nbikei3SG = if UI3SG = 1 then 0.011*Nbi3SG
          Nbikei4ST = if UI4ST = 1 then 0.018*Nbi4ST
          Nbikei4SG = if UI4SG = 1 then 0.015*Nbi4SG
          Nbikei = Nz(Nbikei3ST) + Nz(Nbikei3SG) + Nz(Nbikei4ST) + Nz(Nbikei4SG)
          
          Ntot = Nz(Nbi3ST) + Nz(Nbi3SG) + Nz(Nbi4ST) + Nz(Nbi4SG) + Npedi + Nbikei
          Nfi = Nz(NbiFI3ST) + Nz(NbiFI3SG) + Nz(NbiFI4ST) + Nz(NbiFI4SG) + Npedi + Nbikei
     end
     
     // Nf = Nfi*0.0140      // ratio for Indiana local roads and streets, 2003-2008
	 Nf = Nfi*0.01880 		// Overall ratio for TN - SB
     Ni = Nfi - Nf
     Npdo = Ntot - Nfi
          
	// Calibration Adjustments
	Nf = Nf * CurbiF
	Ni = Ni * CurbiI
	Npdo = Npdo * CurbiP
	Ntot = Nf + Ni + Npdo
          
	SetDataVectors(nodevw + "|working", {{"Crashes_U_Tot",Ntot},{"Crashes_U_F",Nf},{"Crashes_U_I",Ni},{"Crashes_U_P",Npdo},
                                        {"HSMclass",vn3}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})       

     DeleteSet("working")     
	

	 
     
	NodeID = GetDataVector(nodevw + "|Modn", "ID", {{"Sort Order",{{"ID","Ascending"}}}})
	
	datavs = GetDataVectors(nodevw + "|Modn", {	"Crashes_2L_Tot", "Crashes_2L_F", "Crashes_2L_I", "Crashes_2L_P",
												"Crashes_ML_Tot", "Crashes_ML_F", "Crashes_ML_I", "Crashes_ML_P", 
												"Crashes_U_Tot", "Crashes_U_F", "Crashes_U_I", "Crashes_U_P"},
                                                  {{"Sort Order",{{"ID","Ascending"}}}})

	Crashes_Total_Int 	= 	Nz(datavs[1]) + Nz(datavs[5]) + Nz(datavs[9])

	Crashes_Fatal_Int 	= 	Nz(datavs[2]) + Nz(datavs[6]) + Nz(datavs[10])
	
	Crashes_Injury_Int 	= 	Nz(datavs[3]) + Nz(datavs[7]) + Nz(datavs[11])
	
	Crashes_PDO_Int 	= 	Nz(datavs[4]) + Nz(datavs[8]) + Nz(datavs[12])

	SetDataVectors(nodevw + "|Modn", {{"Crashes_Tot",Crashes_Total_Int},{"Crashes_F",Crashes_Fatal_Int},{"Crashes_I",Crashes_Injury_Int},{"Crashes_P",Crashes_PDO_Int}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})	
     
	SetDataVectors(outnodevw +"|", {{"ID1",NodeID},{"CrashesTot",Crashes_Total_Int},{"Crashes_F",Crashes_Fatal_Int},{"Crashes_I",Crashes_Injury_Int},{"Crashes_P",Crashes_PDO_Int}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	// Distribute intersection crashes among associated links based on Total Flow at the link level
	// The intersection crashes will be added to the same type of crashes at link level - SB
	
	linkdatavs = GetDataVectors(linevw + "|Mod", {"ID", "TotFlow", "Crashes_Tot", "Crashes_F", "Crashes_I", "Crashes_P"}, 		// 09/27
                                                  {{"Sort Order",{{"ID","Ascending"}}}})
												  
	nodedatavs = GetDataVectors(nodevw + "|Modn", {"ID", "IntADT", "Crashes_Tot", "Crashes_F", "Crashes_I", "Crashes_P"}, 		// 09/27
                                                  {{"Sort Order",{{"ID","Ascending"}}}})
												  

	// Run this for every node ID
	for i = 1 to nodedatavs[1].length do				// nodedatavs[1] is node ID datavector
		SetLayer(nodevw)
		link_ids = GetNodeLinks(nodedatavs[1][i])
		node_flow = 0
		
		SetLayer(linevw)
		// Get total flow at a node
		for j = 1 to link_ids.length do
		   SetRecord(linevw , ID2RH(link_ids[j]))
		   node_flow = node_flow + nz(linevw.TotFlow)		// TotFlow is field in link layer that has total link level volume
		end
		
		// Distribute intersection crashes to links as a weighted average of total flow 
		if node_flow <> 0 then do
			for j = 1 to link_ids.length do
			   SetRecord(linevw , ID2RH(link_ids[j]))
			   linevw.Crashes_F = linevw.Crashes_F + ((linevw.TotFlow) * (nodedatavs[4][i]) / node_flow)		// nodedatavs[4][i] is fatal intersection level crashes
			   linevw.Crashes_I = linevw.Crashes_I + ((linevw.TotFlow) * (nodedatavs[5][i]) / node_flow)		// nodedatavs[5][i] is injury intersection level crashes
			   linevw.Crashes_P = linevw.Crashes_P + ((linevw.TotFlow) * (nodedatavs[6][i]) / node_flow)		// nodedatavs[6][i] is pdo intersection level crashes
			   linevw.Crashes_Tot = nz(linevw.Crashes_F) + nz(linevw.Crashes_I) + nz(linevw.Crashes_P)		// sum up for total crashes
			end
		end
		
	End	
	
	// Apply calibration factors for the study area - SB
	
	datavs = GetDataVectors(linevw + "|Mod", {	"Crashes_F", "Crashes_I", "Crashes_P"},
                                                  {{"Sort Order",{{"ID","Ascending"}}}})
	Crashes_Fatal_Links 	= 	CfFatal * Nz(datavs[1])
	Crashes_Injury_Links 	= 	CfInjury * Nz(datavs[2])
	Crashes_PDO_Links 		= 	CfPDO * Nz(datavs[3])
	Crashes_Total_Links		= 	Crashes_Fatal_Links + Crashes_Injury_Links + Crashes_PDO_Links
	
	SetDataVectors(linevw + "|Mod", {{"Crashes_Tot",Crashes_Total_Links},{"Crashes_F",Crashes_Fatal_Links},{"Crashes_I",Crashes_Injury_Links},{"Crashes_P",Crashes_PDO_Links}}, 
				                     {{"Sort Order",{{"ID","Ascending"}}}})			

									 
	// Code before adding crash module - SB
    /*            fatal = if(FC = 1 | FC = 2 | FC = 6 | FC = 11 | FC = 12 | FC = 14 | FC = 16) then TOTVMT * netparam.FatalR.value else 0
                Injury = if(FC = 1 | FC = 2 | FC = 6 | FC = 11 | FC = 12 | FC = 14 | FC = 16) then TOTVMT * netparam.InjR.value else 0
                PDO = if(FC = 1 | FC = 2 | FC = 6 | FC = 11 | FC = 12 | FC = 14 | FC = 16) then TOTVMT * netparam.PDOR.value else 0  

				accident  = fatal + Injury + PDO
				          
				fatalC    = fatal * netparam.FatalC.value
				InjuryC   = Injury * netparam.InjC.value
				PDOC      = PDO * netparam.PDOC.value
				accidentC = fatalC + InjuryC + PDOC
    */
	
	LOS_AB = if (FC = 1 or FC = 11) and MAXVC_AB > 1.00 THEN "F"
		 else if (FC = 1 or FC = 11) and MAXVC_AB > .88 THEN "E"
		 else if (FC = 1 or FC = 11) and MAXVC_AB > .69 THEN "D"
		 else if (FC = 1 or FC = 11) and MAXVC_AB > .47 THEN "C"
		 else if (FC = 1 or FC = 11) and MAXVC_AB > .29 THEN "B"
		 else if FC = 12 and MAXVC_AB > 1.00 THEN "F"
		 else if FC = 12 and MAXVC_AB > .88 THEN "E"
		 else if FC = 12 and MAXVC_AB > .75 THEN "D"
		 else if FC = 12 and MAXVC_AB > .55 THEN "C"
		 else if FC = 12 and MAXVC_AB > .33 THEN "B"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_AB > 1.00 THEN "F"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_AB > .84 THEN "E"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_AB > .70 THEN "D"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_AB > .50 THEN "C"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_AB > .30 THEN "B"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_AB > 1.00 THEN "F"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_AB > .83 THEN "E"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_AB > .72 THEN "D"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_AB > .52 THEN "C"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_AB > .31 THEN "B"
		 else "A"

	LOS_BA = if (FC = 1 or FC = 11) and MAXVC_BA > 1.00 THEN "F"
		 else if (FC = 1 or FC = 11) and MAXVC_BA > .88 THEN "E"
		 else if (FC = 1 or FC = 11) and MAXVC_BA > .69 THEN "D"
		 else if (FC = 1 or FC = 11) and MAXVC_BA > .47 THEN "C"
		 else if (FC = 1 or FC = 11) and MAXVC_BA > .29 THEN "B"
		 else if FC = 12 and MAXVC_BA > 1.00 THEN "F"
		 else if FC = 12 and MAXVC_BA > .88 THEN "E"
		 else if FC = 12 and MAXVC_BA > .75 THEN "D"
		 else if FC = 12 and MAXVC_BA > .55 THEN "C"
		 else if FC = 12 and MAXVC_BA > .33 THEN "B"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_BA > 1.00 THEN "F"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_BA > .84 THEN "E"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_BA > .70 THEN "D"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_BA > .50 THEN "C"
		 else if (FC=2 or FC=6 or FC=14 or FC=16) and MAXVC_BA > .30 THEN "B"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_BA > 1.00 THEN "F"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_BA > .83 THEN "E"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_BA > .72 THEN "D"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_BA > .52 THEN "C"
		 else if (FC=7 or FC=8 or FC=9 or FC=17 or FC=19) and MAXVC_BA > .31 THEN "B"
		 else "A"
	
	SetDataVectors(outlinkvw +"|", {{"ID1",ID},{"Leng",Leng},{"VOL_AB",NVOL_AB},{"VOL_BA",NVOL_BA},{"CAR_AB",ADJCAR_AB},{"CAR_BA",ADJCAR_BA},{"TRK_AB",ADJTRK_AB},{"TRK_BA",ADJTRK_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUT_AB",ADJSUTRK_AB},{"SUT_BA",ADJSUTRK_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUT_AB",ADJMUTRK_AB},{"MUT_BA",ADJMUTRK_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"FUNCLASS",FC},{"SPD_LMT",SPD_LMT}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	SetDataVectors(outlinkvw +"|", {{"AMPKVol_AB",AMPK.Vol_AB},{"AMPKVol_BA",AMPK.Vol_BA},{"AMPKPCE_AB",AMPK.PCE_AB},{"AMPKPCE_BA",AMPK.PCE_BA},{"AMPKVC_AB",AMPK.VC_AB},{"AMPKVC_BA",AMPK.VC_BA},{"AMPKSPD_AB",AMPK.SPD_AB},{"AMPKSPD_BA",AMPK.SPD_BA},{"AMPKTME_AB",AMPK.TIME_AB},{"AMPKTME_BA",AMPK.TIME_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"PMPKVol_AB",PMPK.Vol_AB},{"PMPKVol_BA",PMPK.Vol_BA},{"PMPKPCE_AB",PMPK.PCE_AB},{"PMPKPCE_BA",PMPK.PCE_BA},{"PMPKVC_AB",PMPK.VC_AB},{"PMPKVC_BA",PMPK.VC_BA},{"PMPKSPD_AB",PMPK.SPD_AB},{"PMPKSPD_BA",PMPK.SPD_BA},{"PMPKTME_AB",PMPK.TIME_AB},{"PMPKTME_BA",PMPK.TIME_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"AMPDVol_AB",AMPD.Vol_AB},{"AMPDVol_BA",AMPD.Vol_BA},{"AMPDPCE_AB",AMPD.PCE_AB},{"AMPDPCE_BA",AMPD.PCE_BA},{"AMPDVC_AB",AMPD.VC_AB},{"AMPDVC_BA",AMPD.VC_BA},{"AMPDSPD_AB",AMPD.SPD_AB},{"AMPDSPD_BA",AMPD.SPD_BA},{"AMPDTME_AB",AMPD.TIME_AB},{"AMPDTME_BA",AMPD.TIME_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"PMPDVol_AB",PMPD.Vol_AB},{"PMPDVol_BA",PMPD.Vol_BA},{"PMPDPCE_AB",PMPD.PCE_AB},{"PMPDPCE_BA",PMPD.PCE_BA},{"PMPDVC_AB",PMPD.VC_AB},{"PMPDVC_BA",PMPD.VC_BA},{"PMPDSPD_AB",PMPD.SPD_AB},{"PMPDSPD_BA",PMPD.SPD_BA},{"PMPDTME_AB",PMPD.TIME_AB},{"PMPDTME_BA",PMPD.TIME_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	//SetDataVectors(outlinkvw +"|", {{"MaxVol_AB",MaxVol_AB},{"MaxVol_BA",MaxVol_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	//SetDataVectors(outlinkvw +"|", {{"VolTrk_AB",MaxVolTrk_AB},{"VolTrk_BA",MaxVolTrk_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MAXVC_AB",MAXVC_AB},{"MAXVC_BA",MAXVC_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"PKSPD_AB",PKSPD_AB},{"PKSPD_BA",PKSPD_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"PKTIME_AB",PKTIME_AB},{"PKTIME_BA",PKTIME_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VHT",TOTVHT},{"VHT_Car",TOTVHTCAR},{"VHT_Trk",TOTVHTTRK},{"VMT",TOTVMT},{"VMT_Car",TOTVMTCAR},{"VMT_Trk",TOTVMTTRK}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	//SetDataVectors(outlinkvw +"|", {{"LOS_AB",LOS_AB},{"LOS_BA",LOS_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"TOTVEHFUEL",TOTVEHFUEL},{"TOTTRKFUEL",TOTTRKFUEL},{"TOTVEHNFUE",TOTVEHNFUEL},{"TOTTRKNFUE",TOTTRKNFUEL}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	SetDataVectors(outlinkvw +"|", {{"VMT_0_1",(nz(H_VMT_AB[1])+nz(H_VMT_BA[1]))},{"VHT_0_1",(nz(H_VHT_AB[1])+nz(H_VHT_BA[1]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_1_2",(nz(H_VMT_AB[2])+nz(H_VMT_BA[2]))},{"VHT_1_2",(nz(H_VHT_AB[2])+nz(H_VHT_BA[2]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_2_3",(nz(H_VMT_AB[3])+nz(H_VMT_BA[3]))},{"VHT_2_3",(nz(H_VHT_AB[3])+nz(H_VHT_BA[3]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_3_4",(nz(H_VMT_AB[4])+nz(H_VMT_BA[4]))},{"VHT_3_4",(nz(H_VHT_AB[4])+nz(H_VHT_BA[4]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_4_5",(nz(H_VMT_AB[5])+nz(H_VMT_BA[5]))},{"VHT_4_5",(nz(H_VHT_AB[5])+nz(H_VHT_BA[5]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_5_6",(nz(H_VMT_AB[6])+nz(H_VMT_BA[6]))},{"VHT_5_6",(nz(H_VHT_AB[6])+nz(H_VHT_BA[6]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_6_7",(nz(H_VMT_AB[7])+nz(H_VMT_BA[7]))},{"VHT_6_7",(nz(H_VHT_AB[7])+nz(H_VHT_BA[7]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_7_8",(nz(H_VMT_AB[8])+nz(H_VMT_BA[8]))},{"VHT_7_8",(nz(H_VHT_AB[8])+nz(H_VHT_BA[8]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_8_9",(nz(H_VMT_AB[9])+nz(H_VMT_BA[9]))},{"VHT_8_9",(nz(H_VHT_AB[9])+nz(H_VHT_BA[9]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_9_10",(nz(H_VMT_AB[10])+nz(H_VMT_BA[10]))},{"VHT_9_10",(nz(H_VHT_AB[10])+nz(H_VHT_BA[10]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_10_11",(nz(H_VMT_AB[11])+nz(H_VMT_BA[11]))},{"VHT_10_11",(nz(H_VHT_AB[11])+nz(H_VHT_BA[11]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_11_12",(nz(H_VMT_AB[12])+nz(H_VMT_BA[12]))},{"VHT_11_12",(nz(H_VHT_AB[12])+nz(H_VHT_BA[12]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_12_13",(nz(H_VMT_AB[13])+nz(H_VMT_BA[13]))},{"VHT_12_13",(nz(H_VHT_AB[13])+nz(H_VHT_BA[13]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_13_14",(nz(H_VMT_AB[14])+nz(H_VMT_BA[14]))},{"VHT_13_14",(nz(H_VHT_AB[14])+nz(H_VHT_BA[14]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_14_15",(nz(H_VMT_AB[15])+nz(H_VMT_BA[15]))},{"VHT_14_15",(nz(H_VHT_AB[15])+nz(H_VHT_BA[15]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_15_16",(nz(H_VMT_AB[16])+nz(H_VMT_BA[16]))},{"VHT_15_16",(nz(H_VHT_AB[16])+nz(H_VHT_BA[16]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_16_17",(nz(H_VMT_AB[17])+nz(H_VMT_BA[17]))},{"VHT_16_17",(nz(H_VHT_AB[17])+nz(H_VHT_BA[17]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_17_18",(nz(H_VMT_AB[18])+nz(H_VMT_BA[18]))},{"VHT_17_18",(nz(H_VHT_AB[18])+nz(H_VHT_BA[18]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_18_19",(nz(H_VMT_AB[19])+nz(H_VMT_BA[19]))},{"VHT_18_19",(nz(H_VHT_AB[19])+nz(H_VHT_BA[19]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_19_20",(nz(H_VMT_AB[20])+nz(H_VMT_BA[20]))},{"VHT_19_20",(nz(H_VHT_AB[20])+nz(H_VHT_BA[20]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_20_21",(nz(H_VMT_AB[21])+nz(H_VMT_BA[21]))},{"VHT_20_21",(nz(H_VHT_AB[21])+nz(H_VHT_BA[21]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_21_22",(nz(H_VMT_AB[22])+nz(H_VMT_BA[22]))},{"VHT_21_22",(nz(H_VHT_AB[22])+nz(H_VHT_BA[22]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_22_23",(nz(H_VMT_AB[23])+nz(H_VMT_BA[23]))},{"VHT_22_23",(nz(H_VHT_AB[23])+nz(H_VHT_BA[23]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VMT_23_24",(nz(H_VMT_AB[24])+nz(H_VMT_BA[24]))},{"VHT_23_24",(nz(H_VHT_AB[24])+nz(H_VHT_BA[24]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	
	//SetDataVectors(outlinkvw +"|", {{"VolSUT_AB",MaxVolSUTRK_AB},{"VolSUT_BA",MaxVolSUTRK_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	//SetDataVectors(outlinkvw +"|", {{"VolMUT_AB",MaxVolMUTRK_AB},{"VolMUT_BA",MaxVolMUTRK_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VHT_SUTRK",TOTVHTSUTRK},{"VMT_SUTRK",TOTVMTSUTRK},{"TOTSUTFUEL",TOTSUTRKFUEL},{"TOTSUTNFUE",TOTSUTRKNFUEL}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VHT_MUTRK",TOTVHTMUTRK},{"VMT_MUTRK",TOTVMTMUTRK},{"TOTMUTFUEL",TOTMUTRKFUEL},{"TOTMUTNFUE",TOTMUTRKNFUEL}}, {{"Sort Order",{{"ID1","Ascending"}}}})

	//	SetDataVectors(outlinkvw +"|", {{"R2_AB",R2_AB},{"Rhalf_AB",Rhalf_AB},{"Rmid_AB",Rmid_AB},{"R2_BA",R2_BA},{"Rhalf_BA",Rhalf_BA},{"Rmid_BA",Rmid_BA},{"Count_AB",COUNT_AB},{"BaseVol_AB",BASEVOL_AB},{"ModVol_AB",MDVOL_AB}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"dlycgtt_AB",ab_dlycgtime},{"dlycgtt_BA",ba_dlycgtime},{"dlyspd_AB",ab_dlyspd},{"dlyspd_BA",ba_dlyspd},	{"CDELAY_AB",cdelay_AB},{"CDELAY_BA",cdelay_BA},{"TDELAY_AB",tdelay_AB},{"TDELAY_BA",tdelay_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	SetDataVectors(outlinkvw +"|", {{"SUDELAY_AB",sutdelay_AB},{"SUDELAY_BA",sutdelay_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUDELAY_AB",mutdelay_AB},{"MUDELAY_BA",mutdelay_BA}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	//SetDataVectors(outlinkvw +"|", {{"fatal",fatal},{"Injury",Injury}, {"PDO",PDO},{"accident",accident}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	//SetDataVectors(outlinkvw +"|", {{"fatalC",fatalC},{"InjuryC",InjuryC}, {"PDOC",PDOC},{"accidentC",accidentC}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"CrashesTot",Crashes_Total_Links},{"Crashes_F",Crashes_Fatal_Links}, {"Crashes_I",Crashes_Injury_Links},{"Crashes_P",Crashes_PDO_Links}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"xVMT",xVMT},{"HSMclass",HSMclass}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	SetDataVectors(outlinkvw +"|", {{"VEHCOR",TOTVEHCOR},{"VEHCOS",TOTVEHCOS},{"TRKCOR",TOTTRKCOR},{"TRKCOS",TOTTRKCOS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VEHCO2R",TOTVEHCO2R},{"VEHCO2S",TOTVEHCO2S},{"TRKCO2R",TOTTRKCO2R},{"TRKCO2S",TOTTRKCO2S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VEHNOXR",TOTVEHNOXR},{"VEHNOXS",TOTVEHNOXS},{"TRKNOXR",TOTTRKNOXR},{"TRKNOXS",TOTTRKNOXS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VEHPM10R",TOTVEHPM10R},{"VEHPM10S",TOTVEHPM10S},{"TRKPM10R",TOTTRKPM10R},{"TRKPM10S",TOTTRKPM10S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VEHPM25R",TOTVEHPM25R},{"VEHPM25S",TOTVEHPM25S},{"TRKPM25R",TOTTRKPM25R},{"TRKPM25S",TOTTRKPM25S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VEHSOXR",TOTVEHSOXR},{"VEHSOXS",TOTVEHSOXS},{"TRKSOXR",TOTTRKSOXR},{"TRKSOXS",TOTTRKSOXS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"VEHVOCR",TOTVEHVOCR},{"VEHVOCS",TOTVEHVOCS},{"TRKVOCR",TOTTRKVOCR},{"TRKVOCS",TOTTRKVOCS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	SetDataVectors(outlinkvw +"|", {{"SUTRKCOR",TOTSUTRKCOR},{"SUTRKCOS",TOTSUTRKCOS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUTRKCO2R",TOTSUTRKCO2R},{"SUTRKCO2S",TOTSUTRKCO2S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUTRKNOXR",TOTSUTRKNOXR},{"SUTRKNOXS",TOTSUTRKNOXS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUTRKPM10R",TOTSUTRKPM10R},{"SUTRKPM10S",TOTSUTRKPM10S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUTRKPM25R",TOTSUTRKPM25R},{"SUTRKPM25S",TOTSUTRKPM25S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUTRKSOXR",TOTSUTRKSOXR},{"SUTRKSOXS",TOTSUTRKSOXS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"SUTRKVOCR",TOTSUTRKVOCR},{"SUTRKVOCS",TOTSUTRKVOCS}}, {{"Sort Order",{{"ID1","Ascending"}}}})

	SetDataVectors(outlinkvw +"|", {{"MUTRKCOR",TOTMUTRKCOR},{"MUTRKCOS",TOTMUTRKCOS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUTRKCO2R",TOTMUTRKCO2R},{"MUTRKCO2S",TOTMUTRKCO2S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUTRKNOXR",TOTMUTRKNOXR},{"MUTRKNOXS",TOTMUTRKNOXS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUTRKPM10R",TOTMUTRKPM10R},{"MUTRKPM10S",TOTMUTRKPM10S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUTRKPM25R",TOTMUTRKPM25R},{"MUTRKPM25S",TOTMUTRKPM25S}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUTRKSOXR",TOTMUTRKSOXR},{"MUTRKSOXS",TOTMUTRKSOXS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(outlinkvw +"|", {{"MUTRKVOCR",TOTMUTRKVOCR},{"MUTRKVOCS",TOTMUTRKVOCS}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
	// Drop crash data fields from the line DBD because they are now properly stored in the post link DBF - SB
	// This is also important so duplicate fields do not appear in the "PostRep" join view
	RunMacro("dropfields", linevw, {"Crashes_Tot", "Crashes_F", "Crashes_I","Crashes_P"}, {"r","r","r","r"})	
		
	//DeleteSet("Mod")
	
	
if domoves = 1 then do	
	//MOVES processing
MV_RoadType = if Ramp > 0 and (AT < 4) then 4 // Urban Restricted (ramps)
		else if Ramp > 0 and (AT = 4 or AT = null) then 2   //Rural Restricted (ramps) 
		else if FC = 1  then 2                            //Rural restricted (interstate)
        else if FC > 1  and FC <= 9 and Access = 3 then 2  //Rural restricted  (non interstate)
		else if FC > 1 and FC <= 9 and Access <> 3 then 3  //Rural Unrestricted (non interstate)
		else if FC = 11  then 4                             //Urban restricted  (interstate)
        else if FC > 11  and FC <=19 and Access = 3 then 4  //Urban restricted  (non interstate) 
        else if FC > 11  and FC <=19 and Access <> 3 then 5 //Uural unrestricted  (non interstate)

//MOVES Auto H_VHT_VEH_AB[i] H_VHT_VEH_BA[i] 
//fold

	movesauto = CreateTable("MOVES_Auto"  , post.movesauto  , "dBase",
							{{"ID1"     , "Integer", 10, null, "No"}, 
							{"Leng"     , "Real"   , 20, 2   , "No"},  
							{"COUNTYID" , "Integer", 10, null, "No"}, 
							{"FUNCCLASS" , "Integer", 10, null, "No"}, 
							{"RoadType" , "Integer", 10, null, "No"}, 
							{"Ramp"     , "Integer", 10, null, "No"}, 
							{"SpdLmt"   , "Integer", 10, null, "No"}, 
							{"VHT_0_1"  , "Real"   , 20, 2   , "No"},
							{"VHT_1_2"  , "Real"   , 20, 2   , "No"},
							{"VHT_2_3"  , "Real"   , 20, 2   , "No"},
							{"VHT_3_4"  , "Real"   , 20, 2   , "No"},
							{"VHT_4_5"  , "Real"   , 20, 2   , "No"},
							{"VHT_5_6"  , "Real"   , 20, 2   , "No"},
							{"VHT_6_7"  , "Real"   , 20, 2   , "No"},
							{"VHT_7_8"  , "Real"   , 20, 2   , "No"},
							{"VHT_8_9"  , "Real"   , 20, 2   , "No"},
							{"VHT_9_10" , "Real"   , 20, 2   , "No"},
							{"VHT_10_11", "Real"   , 20, 2   , "No"},
							{"VHT_11_12", "Real"   , 20, 2   , "No"},
							{"VHT_12_13", "Real"   , 20, 2   , "No"},
							{"VHT_13_14", "Real"   , 20, 2   , "No"},
							{"VHT_14_15", "Real"   , 20, 2   , "No"},
							{"VHT_15_16", "Real"   , 20, 2   , "No"},
							{"VHT_16_17", "Real"   , 20, 2   , "No"},
							{"VHT_17_18", "Real"   , 20, 2   , "No"},
							{"VHT_18_19", "Real"   , 20, 2   , "No"},
							{"VHT_19_20", "Real"   , 20, 2   , "No"},
							{"VHT_20_21", "Real"   , 20, 2   , "No"},
							{"VHT_21_22", "Real"   , 20, 2   , "No"},
							{"VHT_22_23", "Real"   , 20, 2   , "No"},
							{"VHT_23_24", "Real"   , 20, 2   , "No"},
							{"VMT_0_1"  , "Real"   , 20, 2   , "No"},
							{"VMT_1_2"  , "Real"   , 20, 2   , "No"},
							{"VMT_2_3"  , "Real"   , 20, 2   , "No"},
							{"VMT_3_4"  , "Real"   , 20, 2   , "No"},
							{"VMT_4_5"  , "Real"   , 20, 2   , "No"},
							{"VMT_5_6"  , "Real"   , 20, 2   , "No"},
							{"VMT_6_7"  , "Real"   , 20, 2   , "No"},
							{"VMT_7_8"  , "Real"   , 20, 2   , "No"},
							{"VMT_8_9"  , "Real"   , 20, 2   , "No"},
							{"VMT_9_10" , "Real"   , 20, 2   , "No"},
							{"VMT_10_11", "Real"   , 20, 2   , "No"},
							{"VMT_11_12", "Real"   , 20, 2   , "No"},
							{"VMT_12_13", "Real"   , 20, 2   , "No"},
							{"VMT_13_14", "Real"   , 20, 2   , "No"},
							{"VMT_14_15", "Real"   , 20, 2   , "No"},
							{"VMT_15_16", "Real"   , 20, 2   , "No"},
							{"VMT_16_17", "Real"   , 20, 2   , "No"},
							{"VMT_17_18", "Real"   , 20, 2   , "No"},
							{"VMT_18_19", "Real"   , 20, 2   , "No"},
							{"VMT_19_20", "Real"   , 20, 2   , "No"},
							{"VMT_20_21", "Real"   , 20, 2   , "No"},
							{"VMT_21_22", "Real"   , 20, 2   , "No"},
							{"VMT_22_23", "Real"   , 20, 2   , "No"},
							{"VMT_23_24", "Real"   , 20, 2   , "No"},
							{"TOT_VHT"  , "Real"   , 20, 2   , "No"},
							{"TOT_VMT"  , "Real"   , 20, 2   , "No"}
							})
							
	
	
	r = AddRecords(movesauto, null, null, {{"Empty Records", numlinks}})
	SetDataVectors(movesauto+"|", {{"ID1", ID}, {"Leng", Leng}, {"COUNTYID", COUNTYID}, {"FUNCCLASS", FC}, {"RoadType", MV_RoadType}, {"Ramp", Ramp}, {"SpdLmt", SPD_LMT}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_0_1",(nz(H_VMT_VEH_AB[1])+nz(H_VMT_VEH_BA[1]))},{"VHT_0_1",(nz(H_VHT_VEH_AB[1])+nz(H_VHT_VEH_BA[1]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_1_2",(nz(H_VMT_VEH_AB[2])+nz(H_VMT_VEH_BA[2]))},{"VHT_1_2",(nz(H_VHT_VEH_AB[2])+nz(H_VHT_VEH_BA[2]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_2_3",(nz(H_VMT_VEH_AB[3])+nz(H_VMT_VEH_BA[3]))},{"VHT_2_3",(nz(H_VHT_VEH_AB[3])+nz(H_VHT_VEH_BA[3]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_3_4",(nz(H_VMT_VEH_AB[4])+nz(H_VMT_VEH_BA[4]))},{"VHT_3_4",(nz(H_VHT_VEH_AB[4])+nz(H_VHT_VEH_BA[4]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_4_5",(nz(H_VMT_VEH_AB[5])+nz(H_VMT_VEH_BA[5]))},{"VHT_4_5",(nz(H_VHT_VEH_AB[5])+nz(H_VHT_VEH_BA[5]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_5_6",(nz(H_VMT_VEH_AB[6])+nz(H_VMT_VEH_BA[6]))},{"VHT_5_6",(nz(H_VHT_VEH_AB[6])+nz(H_VHT_VEH_BA[6]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_6_7",(nz(H_VMT_VEH_AB[7])+nz(H_VMT_VEH_BA[7]))},{"VHT_6_7",(nz(H_VHT_VEH_AB[7])+nz(H_VHT_VEH_BA[7]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_7_8",(nz(H_VMT_VEH_AB[8])+nz(H_VMT_VEH_BA[8]))},{"VHT_7_8",(nz(H_VHT_VEH_AB[8])+nz(H_VHT_VEH_BA[8]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_8_9",(nz(H_VMT_VEH_AB[9])+nz(H_VMT_VEH_BA[9]))},{"VHT_8_9",(nz(H_VHT_VEH_AB[9])+nz(H_VHT_VEH_BA[9]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_9_10",(nz(H_VMT_VEH_AB[10])+nz(H_VMT_VEH_BA[10]))},{"VHT_9_10",(nz(H_VHT_VEH_AB[10])+nz(H_VHT_VEH_BA[10]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_10_11",(nz(H_VMT_VEH_AB[11])+nz(H_VMT_VEH_BA[11]))},{"VHT_10_11",(nz(H_VHT_VEH_AB[11])+nz(H_VHT_VEH_BA[11]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_11_12",(nz(H_VMT_VEH_AB[12])+nz(H_VMT_VEH_BA[12]))},{"VHT_11_12",(nz(H_VHT_VEH_AB[12])+nz(H_VHT_VEH_BA[12]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_12_13",(nz(H_VMT_VEH_AB[13])+nz(H_VMT_VEH_BA[13]))},{"VHT_12_13",(nz(H_VHT_VEH_AB[13])+nz(H_VHT_VEH_BA[13]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_13_14",(nz(H_VMT_VEH_AB[14])+nz(H_VMT_VEH_BA[14]))},{"VHT_13_14",(nz(H_VHT_VEH_AB[14])+nz(H_VHT_VEH_BA[14]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_14_15",(nz(H_VMT_VEH_AB[15])+nz(H_VMT_VEH_BA[15]))},{"VHT_14_15",(nz(H_VHT_VEH_AB[15])+nz(H_VHT_VEH_BA[15]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_15_16",(nz(H_VMT_VEH_AB[16])+nz(H_VMT_VEH_BA[16]))},{"VHT_15_16",(nz(H_VHT_VEH_AB[16])+nz(H_VHT_VEH_BA[16]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_16_17",(nz(H_VMT_VEH_AB[17])+nz(H_VMT_VEH_BA[17]))},{"VHT_16_17",(nz(H_VHT_VEH_AB[17])+nz(H_VHT_VEH_BA[17]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_17_18",(nz(H_VMT_VEH_AB[18])+nz(H_VMT_VEH_BA[18]))},{"VHT_17_18",(nz(H_VHT_VEH_AB[18])+nz(H_VHT_VEH_BA[18]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_18_19",(nz(H_VMT_VEH_AB[19])+nz(H_VMT_VEH_BA[19]))},{"VHT_18_19",(nz(H_VHT_VEH_AB[19])+nz(H_VHT_VEH_BA[19]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_19_20",(nz(H_VMT_VEH_AB[20])+nz(H_VMT_VEH_BA[20]))},{"VHT_19_20",(nz(H_VHT_VEH_AB[20])+nz(H_VHT_VEH_BA[20]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_20_21",(nz(H_VMT_VEH_AB[21])+nz(H_VMT_VEH_BA[21]))},{"VHT_20_21",(nz(H_VHT_VEH_AB[21])+nz(H_VHT_VEH_BA[21]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_21_22",(nz(H_VMT_VEH_AB[22])+nz(H_VMT_VEH_BA[22]))},{"VHT_21_22",(nz(H_VHT_VEH_AB[22])+nz(H_VHT_VEH_BA[22]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_22_23",(nz(H_VMT_VEH_AB[23])+nz(H_VMT_VEH_BA[23]))},{"VHT_22_23",(nz(H_VHT_VEH_AB[23])+nz(H_VHT_VEH_BA[23]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"VMT_23_24",(nz(H_VMT_VEH_AB[24])+nz(H_VMT_VEH_BA[24]))},{"VHT_23_24",(nz(H_VHT_VEH_AB[24])+nz(H_VHT_VEH_BA[24]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesauto +"|", {{"TOT_VHT",TOTVHTCAR},{"TOT_VMT",TOTVMTCAR}}, {{"Sort Order",{{"ID1","Ascending"}}}})

	
//endfold
//MOVES SUT H_VHT_SUTRK_AB[i] H_VHT_SUTRK_BA[i] 
//fold
	movessut = CreateTable("MOVES_SUT"  , post.movessut  , "dBase",
						{{"ID1"     , "Integer", 10, null, "No"}, 
						{"Leng"     , "Real"   , 20, 2   , "No"},
						{"COUNTYID" , "Integer", 10, null, "No"},
						{"FUNCCLASS" , "Integer", 10, null, "No"}, 
						{"RoadType" , "Integer", 10, null, "No"}, 
						{"Ramp"     , "Integer", 10, null, "No"}, 
						{"SpdLmt"   , "Integer", 10, null, "No"}, 
						{"VHT_0_1"  , "Real"   , 20, 2   , "No"},
						{"VHT_1_2"  , "Real"   , 20, 2   , "No"},
						{"VHT_2_3"  , "Real"   , 20, 2   , "No"},
						{"VHT_3_4"  , "Real"   , 20, 2   , "No"},
						{"VHT_4_5"  , "Real"   , 20, 2   , "No"},
						{"VHT_5_6"  , "Real"   , 20, 2   , "No"},
						{"VHT_6_7"  , "Real"   , 20, 2   , "No"},
						{"VHT_7_8"  , "Real"   , 20, 2   , "No"},
						{"VHT_8_9"  , "Real"   , 20, 2   , "No"},
						{"VHT_9_10" , "Real"   , 20, 2   , "No"},
						{"VHT_10_11", "Real"   , 20, 2   , "No"},
						{"VHT_11_12", "Real"   , 20, 2   , "No"},
						{"VHT_12_13", "Real"   , 20, 2   , "No"},
						{"VHT_13_14", "Real"   , 20, 2   , "No"},
						{"VHT_14_15", "Real"   , 20, 2   , "No"},
						{"VHT_15_16", "Real"   , 20, 2   , "No"},
						{"VHT_16_17", "Real"   , 20, 2   , "No"},
						{"VHT_17_18", "Real"   , 20, 2   , "No"},
						{"VHT_18_19", "Real"   , 20, 2   , "No"},
						{"VHT_19_20", "Real"   , 20, 2   , "No"},
						{"VHT_20_21", "Real"   , 20, 2   , "No"},
						{"VHT_21_22", "Real"   , 20, 2   , "No"},
						{"VHT_22_23", "Real"   , 20, 2   , "No"},
						{"VHT_23_24", "Real"   , 20, 2   , "No"},
						{"VMT_0_1"  , "Real"   , 20, 2   , "No"},
						{"VMT_1_2"  , "Real"   , 20, 2   , "No"},
						{"VMT_2_3"  , "Real"   , 20, 2   , "No"},
						{"VMT_3_4"  , "Real"   , 20, 2   , "No"},
						{"VMT_4_5"  , "Real"   , 20, 2   , "No"},
						{"VMT_5_6"  , "Real"   , 20, 2   , "No"},
						{"VMT_6_7"  , "Real"   , 20, 2   , "No"},
						{"VMT_7_8"  , "Real"   , 20, 2   , "No"},
						{"VMT_8_9"  , "Real"   , 20, 2   , "No"},
						{"VMT_9_10" , "Real"   , 20, 2   , "No"},
						{"VMT_10_11", "Real"   , 20, 2   , "No"},
						{"VMT_11_12", "Real"   , 20, 2   , "No"},
						{"VMT_12_13", "Real"   , 20, 2   , "No"},
						{"VMT_13_14", "Real"   , 20, 2   , "No"},
						{"VMT_14_15", "Real"   , 20, 2   , "No"},
						{"VMT_15_16", "Real"   , 20, 2   , "No"},
						{"VMT_16_17", "Real"   , 20, 2   , "No"},
						{"VMT_17_18", "Real"   , 20, 2   , "No"},
						{"VMT_18_19", "Real"   , 20, 2   , "No"},
						{"VMT_19_20", "Real"   , 20, 2   , "No"},
						{"VMT_20_21", "Real"   , 20, 2   , "No"},
						{"VMT_21_22", "Real"   , 20, 2   , "No"},
						{"VMT_22_23", "Real"   , 20, 2   , "No"},
						{"VMT_23_24", "Real"   , 20, 2   , "No"},
						{"TOT_VHT"  , "Real"   , 20, 2   , "No"},
						{"TOT_VMT"  , "Real"   , 20, 2   , "No"}
						})
							
	r = AddRecords(movessut, null, null, {{"Empty Records", numlinks}})
	SetDataVectors(movessut+"|", {{"ID1", ID}, {"Leng", Leng}, {"COUNTYID", COUNTYID}, {"FUNCCLASS", FC}, {"RoadType", MV_RoadType}, {"Ramp", Ramp}, {"SpdLmt", SPD_LMT}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_0_1",(nz(H_VMT_SUTRK_AB[1])+nz(H_VMT_SUTRK_BA[1]))},{"VHT_0_1",(nz(H_VHT_SUTRK_AB[1])+nz(H_VHT_SUTRK_BA[1]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_1_2",(nz(H_VMT_SUTRK_AB[2])+nz(H_VMT_SUTRK_BA[2]))},{"VHT_1_2",(nz(H_VHT_SUTRK_AB[2])+nz(H_VHT_SUTRK_BA[2]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_2_3",(nz(H_VMT_SUTRK_AB[3])+nz(H_VMT_SUTRK_BA[3]))},{"VHT_2_3",(nz(H_VHT_SUTRK_AB[3])+nz(H_VHT_SUTRK_BA[3]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_3_4",(nz(H_VMT_SUTRK_AB[4])+nz(H_VMT_SUTRK_BA[4]))},{"VHT_3_4",(nz(H_VHT_SUTRK_AB[4])+nz(H_VHT_SUTRK_BA[4]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_4_5",(nz(H_VMT_SUTRK_AB[5])+nz(H_VMT_SUTRK_BA[5]))},{"VHT_4_5",(nz(H_VHT_SUTRK_AB[5])+nz(H_VHT_SUTRK_BA[5]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_5_6",(nz(H_VMT_SUTRK_AB[6])+nz(H_VMT_SUTRK_BA[6]))},{"VHT_5_6",(nz(H_VHT_SUTRK_AB[6])+nz(H_VHT_SUTRK_BA[6]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_6_7",(nz(H_VMT_SUTRK_AB[7])+nz(H_VMT_SUTRK_BA[7]))},{"VHT_6_7",(nz(H_VHT_SUTRK_AB[7])+nz(H_VHT_SUTRK_BA[7]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_7_8",(nz(H_VMT_SUTRK_AB[8])+nz(H_VMT_SUTRK_BA[8]))},{"VHT_7_8",(nz(H_VHT_SUTRK_AB[8])+nz(H_VHT_SUTRK_BA[8]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_8_9",(nz(H_VMT_SUTRK_AB[9])+nz(H_VMT_SUTRK_BA[9]))},{"VHT_8_9",(nz(H_VHT_SUTRK_AB[9])+nz(H_VHT_SUTRK_BA[9]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_9_10",(nz(H_VMT_SUTRK_AB[10])+nz(H_VMT_SUTRK_BA[10]))},{"VHT_9_10",(nz(H_VHT_SUTRK_AB[10])+nz(H_VHT_SUTRK_BA[10]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_10_11",(nz(H_VMT_SUTRK_AB[11])+nz(H_VMT_SUTRK_BA[11]))},{"VHT_10_11",(nz(H_VHT_SUTRK_AB[11])+nz(H_VHT_SUTRK_BA[11]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_11_12",(nz(H_VMT_SUTRK_AB[12])+nz(H_VMT_SUTRK_BA[12]))},{"VHT_11_12",(nz(H_VHT_SUTRK_AB[12])+nz(H_VHT_SUTRK_BA[12]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_12_13",(nz(H_VMT_SUTRK_AB[13])+nz(H_VMT_SUTRK_BA[13]))},{"VHT_12_13",(nz(H_VHT_SUTRK_AB[13])+nz(H_VHT_SUTRK_BA[13]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_13_14",(nz(H_VMT_SUTRK_AB[14])+nz(H_VMT_SUTRK_BA[14]))},{"VHT_13_14",(nz(H_VHT_SUTRK_AB[14])+nz(H_VHT_SUTRK_BA[14]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_14_15",(nz(H_VMT_SUTRK_AB[15])+nz(H_VMT_SUTRK_BA[15]))},{"VHT_14_15",(nz(H_VHT_SUTRK_AB[15])+nz(H_VHT_SUTRK_BA[15]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_15_16",(nz(H_VMT_SUTRK_AB[16])+nz(H_VMT_SUTRK_BA[16]))},{"VHT_15_16",(nz(H_VHT_SUTRK_AB[16])+nz(H_VHT_SUTRK_BA[16]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_16_17",(nz(H_VMT_SUTRK_AB[17])+nz(H_VMT_SUTRK_BA[17]))},{"VHT_16_17",(nz(H_VHT_SUTRK_AB[17])+nz(H_VHT_SUTRK_BA[17]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_17_18",(nz(H_VMT_SUTRK_AB[18])+nz(H_VMT_SUTRK_BA[18]))},{"VHT_17_18",(nz(H_VHT_SUTRK_AB[18])+nz(H_VHT_SUTRK_BA[18]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_18_19",(nz(H_VMT_SUTRK_AB[19])+nz(H_VMT_SUTRK_BA[19]))},{"VHT_18_19",(nz(H_VHT_SUTRK_AB[19])+nz(H_VHT_SUTRK_BA[19]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_19_20",(nz(H_VMT_SUTRK_AB[20])+nz(H_VMT_SUTRK_BA[20]))},{"VHT_19_20",(nz(H_VHT_SUTRK_AB[20])+nz(H_VHT_SUTRK_BA[20]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_20_21",(nz(H_VMT_SUTRK_AB[21])+nz(H_VMT_SUTRK_BA[21]))},{"VHT_20_21",(nz(H_VHT_SUTRK_AB[21])+nz(H_VHT_SUTRK_BA[21]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_21_22",(nz(H_VMT_SUTRK_AB[22])+nz(H_VMT_SUTRK_BA[22]))},{"VHT_21_22",(nz(H_VHT_SUTRK_AB[22])+nz(H_VHT_SUTRK_BA[22]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_22_23",(nz(H_VMT_SUTRK_AB[23])+nz(H_VMT_SUTRK_BA[23]))},{"VHT_22_23",(nz(H_VHT_SUTRK_AB[23])+nz(H_VHT_SUTRK_BA[23]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"VMT_23_24",(nz(H_VMT_SUTRK_AB[24])+nz(H_VMT_SUTRK_BA[24]))},{"VHT_23_24",(nz(H_VHT_SUTRK_AB[24])+nz(H_VHT_SUTRK_BA[24]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movessut +"|", {{"TOT_VHT",TOTVHTSUTRK},{"TOT_VMT",TOTVMTSUTRK}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
//endfold
//MOVES MUT H_VHT_MUTRK_AB[i] H_VHT_MUTRK_BA[i]
//fold
	movesmut = CreateTable("MOVES_MUT"  , post.movesmut  , "dBase",
					{{"ID1"     , "Integer", 10, null, "No"}, 
					{"Leng"     , "Real"   , 20, 2   , "No"},
					{"COUNTYID" , "Integer", 10, null, "No"}, 
					{"FUNCCLASS" , "Integer", 10, null, "No"}, 
					{"RoadType" , "Integer", 10, null, "No"}, 
					{"Ramp"     , "Integer", 10, null, "No"}, 
					{"SpdLmt"   , "Integer", 10, null, "No"}, 
					{"VHT_0_1"  , "Real"   , 20, 2   , "No"},
					{"VHT_1_2"  , "Real"   , 20, 2   , "No"},
					{"VHT_2_3"  , "Real"   , 20, 2   , "No"},
					{"VHT_3_4"  , "Real"   , 20, 2   , "No"},
					{"VHT_4_5"  , "Real"   , 20, 2   , "No"},
					{"VHT_5_6"  , "Real"   , 20, 2   , "No"},
					{"VHT_6_7"  , "Real"   , 20, 2   , "No"},
					{"VHT_7_8"  , "Real"   , 20, 2   , "No"},
					{"VHT_8_9"  , "Real"   , 20, 2   , "No"},
					{"VHT_9_10" , "Real"   , 20, 2   , "No"},
					{"VHT_10_11", "Real"   , 20, 2   , "No"},
					{"VHT_11_12", "Real"   , 20, 2   , "No"},
					{"VHT_12_13", "Real"   , 20, 2   , "No"},
					{"VHT_13_14", "Real"   , 20, 2   , "No"},
					{"VHT_14_15", "Real"   , 20, 2   , "No"},
					{"VHT_15_16", "Real"   , 20, 2   , "No"},
					{"VHT_16_17", "Real"   , 20, 2   , "No"},
					{"VHT_17_18", "Real"   , 20, 2   , "No"},
					{"VHT_18_19", "Real"   , 20, 2   , "No"},
					{"VHT_19_20", "Real"   , 20, 2   , "No"},
					{"VHT_20_21", "Real"   , 20, 2   , "No"},
					{"VHT_21_22", "Real"   , 20, 2   , "No"},
					{"VHT_22_23", "Real"   , 20, 2   , "No"},
					{"VHT_23_24", "Real"   , 20, 2   , "No"},
					{"VMT_0_1"  , "Real"   , 20, 2   , "No"},
					{"VMT_1_2"  , "Real"   , 20, 2   , "No"},
					{"VMT_2_3"  , "Real"   , 20, 2   , "No"},
					{"VMT_3_4"  , "Real"   , 20, 2   , "No"},
					{"VMT_4_5"  , "Real"   , 20, 2   , "No"},
					{"VMT_5_6"  , "Real"   , 20, 2   , "No"},
					{"VMT_6_7"  , "Real"   , 20, 2   , "No"},
					{"VMT_7_8"  , "Real"   , 20, 2   , "No"},
					{"VMT_8_9"  , "Real"   , 20, 2   , "No"},
					{"VMT_9_10" , "Real"   , 20, 2   , "No"},
					{"VMT_10_11", "Real"   , 20, 2   , "No"},
					{"VMT_11_12", "Real"   , 20, 2   , "No"},
					{"VMT_12_13", "Real"   , 20, 2   , "No"},
					{"VMT_13_14", "Real"   , 20, 2   , "No"},
					{"VMT_14_15", "Real"   , 20, 2   , "No"},
					{"VMT_15_16", "Real"   , 20, 2   , "No"},
					{"VMT_16_17", "Real"   , 20, 2   , "No"},
					{"VMT_17_18", "Real"   , 20, 2   , "No"},
					{"VMT_18_19", "Real"   , 20, 2   , "No"},
					{"VMT_19_20", "Real"   , 20, 2   , "No"},
					{"VMT_20_21", "Real"   , 20, 2   , "No"},
					{"VMT_21_22", "Real"   , 20, 2   , "No"},
					{"VMT_22_23", "Real"   , 20, 2   , "No"},
					{"VMT_23_24", "Real"   , 20, 2   , "No"},
					{"TOT_VHT"  , "Real"   , 20, 2   , "No"},
					{"TOT_VMT"  , "Real"   , 20, 2   , "No"}
					})
	r = AddRecords(movesmut, null, null, {{"Empty Records", numlinks}})
	SetDataVectors(movesmut+"|", {{"ID1", ID}, {"Leng", Leng}, {"COUNTYID", COUNTYID}, {"FUNCCLASS", FC}, {"RoadType", MV_RoadType}, {"Ramp", Ramp}, {"SpdLmt", SPD_LMT}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_0_1"  ,(nz(H_VMT_MUTRK_AB[1])+nz(H_VMT_MUTRK_BA[1]))}  ,{"VHT_0_1"  ,(nz(H_VHT_MUTRK_AB[1])+nz(H_VHT_MUTRK_BA[1]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_1_2"  ,(nz(H_VMT_MUTRK_AB[2])+nz(H_VMT_MUTRK_BA[2]))}  ,{"VHT_1_2"  ,(nz(H_VHT_MUTRK_AB[2])+nz(H_VHT_MUTRK_BA[2]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_2_3"  ,(nz(H_VMT_MUTRK_AB[3])+nz(H_VMT_MUTRK_BA[3]))}  ,{"VHT_2_3"  ,(nz(H_VHT_MUTRK_AB[3])+nz(H_VHT_MUTRK_BA[3]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_3_4"  ,(nz(H_VMT_MUTRK_AB[4])+nz(H_VMT_MUTRK_BA[4]))}  ,{"VHT_3_4"  ,(nz(H_VHT_MUTRK_AB[4])+nz(H_VHT_MUTRK_BA[4]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_4_5"  ,(nz(H_VMT_MUTRK_AB[5])+nz(H_VMT_MUTRK_BA[5]))}  ,{"VHT_4_5"  ,(nz(H_VHT_MUTRK_AB[5])+nz(H_VHT_MUTRK_BA[5]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_5_6"  ,(nz(H_VMT_MUTRK_AB[6])+nz(H_VMT_MUTRK_BA[6]))}  ,{"VHT_5_6"  ,(nz(H_VHT_MUTRK_AB[6])+nz(H_VHT_MUTRK_BA[6]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_6_7"  ,(nz(H_VMT_MUTRK_AB[7])+nz(H_VMT_MUTRK_BA[7]))}  ,{"VHT_6_7"  ,(nz(H_VHT_MUTRK_AB[7])+nz(H_VHT_MUTRK_BA[7]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_7_8"  ,(nz(H_VMT_MUTRK_AB[8])+nz(H_VMT_MUTRK_BA[8]))}  ,{"VHT_7_8"  ,(nz(H_VHT_MUTRK_AB[8])+nz(H_VHT_MUTRK_BA[8]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_8_9"  ,(nz(H_VMT_MUTRK_AB[9])+nz(H_VMT_MUTRK_BA[9]))}  ,{"VHT_8_9"  ,(nz(H_VHT_MUTRK_AB[9])+nz(H_VHT_MUTRK_BA[9]))}}  , {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_9_10" ,(nz(H_VMT_MUTRK_AB[10])+nz(H_VMT_MUTRK_BA[10]))},{"VHT_9_10" ,(nz(H_VHT_MUTRK_AB[10])+nz(H_VHT_MUTRK_BA[10]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_10_11",(nz(H_VMT_MUTRK_AB[11])+nz(H_VMT_MUTRK_BA[11]))},{"VHT_10_11",(nz(H_VHT_MUTRK_AB[11])+nz(H_VHT_MUTRK_BA[11]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_11_12",(nz(H_VMT_MUTRK_AB[12])+nz(H_VMT_MUTRK_BA[12]))},{"VHT_11_12",(nz(H_VHT_MUTRK_AB[12])+nz(H_VHT_MUTRK_BA[12]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_12_13",(nz(H_VMT_MUTRK_AB[13])+nz(H_VMT_MUTRK_BA[13]))},{"VHT_12_13",(nz(H_VHT_MUTRK_AB[13])+nz(H_VHT_MUTRK_BA[13]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_13_14",(nz(H_VMT_MUTRK_AB[14])+nz(H_VMT_MUTRK_BA[14]))},{"VHT_13_14",(nz(H_VHT_MUTRK_AB[14])+nz(H_VHT_MUTRK_BA[14]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_14_15",(nz(H_VMT_MUTRK_AB[15])+nz(H_VMT_MUTRK_BA[15]))},{"VHT_14_15",(nz(H_VHT_MUTRK_AB[15])+nz(H_VHT_MUTRK_BA[15]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_15_16",(nz(H_VMT_MUTRK_AB[16])+nz(H_VMT_MUTRK_BA[16]))},{"VHT_15_16",(nz(H_VHT_MUTRK_AB[16])+nz(H_VHT_MUTRK_BA[16]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_16_17",(nz(H_VMT_MUTRK_AB[17])+nz(H_VMT_MUTRK_BA[17]))},{"VHT_16_17",(nz(H_VHT_MUTRK_AB[17])+nz(H_VHT_MUTRK_BA[17]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_17_18",(nz(H_VMT_MUTRK_AB[18])+nz(H_VMT_MUTRK_BA[18]))},{"VHT_17_18",(nz(H_VHT_MUTRK_AB[18])+nz(H_VHT_MUTRK_BA[18]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_18_19",(nz(H_VMT_MUTRK_AB[19])+nz(H_VMT_MUTRK_BA[19]))},{"VHT_18_19",(nz(H_VHT_MUTRK_AB[19])+nz(H_VHT_MUTRK_BA[19]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_19_20",(nz(H_VMT_MUTRK_AB[20])+nz(H_VMT_MUTRK_BA[20]))},{"VHT_19_20",(nz(H_VHT_MUTRK_AB[20])+nz(H_VHT_MUTRK_BA[20]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_20_21",(nz(H_VMT_MUTRK_AB[21])+nz(H_VMT_MUTRK_BA[21]))},{"VHT_20_21",(nz(H_VHT_MUTRK_AB[21])+nz(H_VHT_MUTRK_BA[21]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_21_22",(nz(H_VMT_MUTRK_AB[22])+nz(H_VMT_MUTRK_BA[22]))},{"VHT_21_22",(nz(H_VHT_MUTRK_AB[22])+nz(H_VHT_MUTRK_BA[22]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_22_23",(nz(H_VMT_MUTRK_AB[23])+nz(H_VMT_MUTRK_BA[23]))},{"VHT_22_23",(nz(H_VHT_MUTRK_AB[23])+nz(H_VHT_MUTRK_BA[23]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"VMT_23_24",(nz(H_VMT_MUTRK_AB[24])+nz(H_VMT_MUTRK_BA[24]))},{"VHT_23_24",(nz(H_VHT_MUTRK_AB[24])+nz(H_VHT_MUTRK_BA[24]))}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesmut +"|", {{"TOT_VHT",TOTVHTMUTRK},{"TOT_VMT",TOTVMTMUTRK}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	
//endfold

//MOVES Speed CGSpeed_AB[i] CGSpeed_BA[i]
//fold
	movesspd = CreateTable("MOVES_Spd"  , post.movesspd  , "dBase",
					{{"ID1"     , "Integer", 10, null, "No"}, 
					{"Leng"     , "Real"   , 20, 2   , "No"},
					{"COUNTYID" , "Integer", 10, null, "No"},
					{"FUNCCLASS", "Integer", 10, null, "No"}, 
					{"RoadType" , "Integer", 10, null, "No"}, 
					{"Ramp"     , "Integer", 10, null, "No"}, 
					{"SpdLmt"   , "Integer", 10, null, "No"},
					{"Spd_0_1"  , "Real", 6 , 2, "No"},
					{"Spd_1_2"  , "Real", 6 , 2, "No"},
					{"Spd_2_3"  , "Real", 6 , 2, "No"},
					{"Spd_3_4"  , "Real", 6 , 2, "No"},
					{"Spd_4_5"  , "Real", 6 , 2, "No"},
					{"Spd_5_6"  , "Real", 6 , 2, "No"},
					{"Spd_6_7"  , "Real", 6 , 2, "No"},
					{"Spd_7_8"  , "Real", 6 , 2, "No"},
					{"Spd_8_9"  , "Real", 6 , 2, "No"},
					{"Spd_9_10" , "Real", 6 , 2, "No"},
					{"Spd_10_11", "Real", 6 , 2, "No"},
					{"Spd_11_12", "Real", 6 , 2, "No"},
					{"Spd_12_13", "Real", 6 , 2, "No"},
					{"Spd_13_14", "Real", 6 , 2, "No"},
					{"Spd_14_15", "Real", 6 , 2, "No"},
					{"Spd_15_16", "Real", 6 , 2, "No"},
					{"Spd_16_17", "Real", 6 , 2, "No"},
					{"Spd_17_18", "Real", 6 , 2, "No"},
					{"Spd_18_19", "Real", 6 , 2, "No"},
					{"Spd_19_20", "Real", 6 , 2, "No"},
					{"Spd_20_21", "Real", 6 , 2, "No"},
					{"Spd_21_22", "Real", 6 , 2, "No"},
					{"Spd_22_23", "Real", 6 , 2, "No"},
					{"Spd_23_24", "Real", 6 , 2, "No"}
					})
	movesbin = CreateTable("MOVES_SpdBin"  , post.movesbin  , "dBase",
					{{"ID1"     , "Integer", 10, null, "No"}, 
					{"Leng"     , "Real"   , 20, 2   , "No"},
					{"COUNTYID" , "Integer", 10, null, "No"},
					{"FUNCCLASS", "Integer", 10, null, "No"}, 
					{"RoadType" , "Integer", 10, null, "No"}, 
					{"Ramp"     , "Integer", 10, null, "No"}, 
					{"SpdLmt"   , "Integer", 10, null, "No"},
					{"Bin_0_1"  , "Integer", 4 , null, "No"},
					{"Bin_1_2"  , "Integer", 4 , null, "No"},
					{"Bin_2_3"  , "Integer", 4 , null, "No"},
					{"Bin_3_4"  , "Integer", 4 , null, "No"},
					{"Bin_4_5"  , "Integer", 4 , null, "No"},
					{"Bin_5_6"  , "Integer", 4 , null, "No"},
					{"Bin_6_7"  , "Integer", 4 , null, "No"},
					{"Bin_7_8"  , "Integer", 4 , null, "No"},
					{"Bin_8_9"  , "Integer", 4 , null, "No"},
					{"Bin_9_10" , "Integer", 4 , null, "No"},
					{"Bin_10_11", "Integer", 4 , null, "No"},
					{"Bin_11_12", "Integer", 4 , null, "No"},
					{"Bin_12_13", "Integer", 4 , null, "No"},
					{"Bin_13_14", "Integer", 4 , null, "No"},
					{"Bin_14_15", "Integer", 4 , null, "No"},
					{"Bin_15_16", "Integer", 4 , null, "No"},
					{"Bin_16_17", "Integer", 4 , null, "No"},
					{"Bin_17_18", "Integer", 4 , null, "No"},
					{"Bin_18_19", "Integer", 4 , null, "No"},
					{"Bin_19_20", "Integer", 4 , null, "No"},
					{"Bin_20_21", "Integer", 4 , null, "No"},
					{"Bin_21_22", "Integer", 4 , null, "No"},
					{"Bin_22_23", "Integer", 4 , null, "No"},
					{"Bin_23_24", "Integer", 4 , null, "No"}
					})
	
	dim MV_HAvgSpd[24]
	dim MV_SpeedBin[24]
/*
	temp1 = H_VMT_AB[1][1710] //34.31
	temp2 = H_VMT_BA[1][1710] //33.58
	temptot = TOTVMT[1710] //9466.78
	temp3 = CGSpeed_AB[1][1710] //48.90
	temp4 = CGSpeed_BA[1][1710] //48.90
	tempnum = temp1+temp2
	tempdenom = Pow(temp3*temp1,-1) + Pow(temp4*temp2,-1)
	tempavgspd = tempnum/tempdenom
*/	
	for i=1 to 24 do
		//MV_AAvgSpd[i] = if LinkDir = 1 then CGSpeed_AB[i] else if LinkDir = -1 then CGSpeed_BA[i] else (CGSpeed_AB[i]+CGSpeed_BA[i]/2) //artih mean
		MV_HAvgSpd[i] = if LinkDir = 1 then CGSpeed_AB[i] else if LinkDir = -1 then CGSpeed_BA[i] else 2 / (Pow(CGSpeed_AB[i],-1) + Pow(CGSpeed_BA[i],-1)) //harmonic mean
					
		MV_SpeedBin[i] = if MV_HAvgSpd[i] < 2.5  then 1	                   		//	1 	speed<2.5mph 
				  else if MV_HAvgSpd[i] >= 2.5  and MV_HAvgSpd[i] < 7.5  then 2       //	2 	2.5mph<=speed<7.5mph 
				  else if MV_HAvgSpd[i] >= 7.5  and MV_HAvgSpd[i] < 12.5 then 3       //	3 	7.5mph<=speed<12.5mph 
				  else if MV_HAvgSpd[i] >= 12.5 and MV_HAvgSpd[i] < 17.5 then 4       //	4 	12.5mph<=speed<17.5mph 
				  else if MV_HAvgSpd[i] >= 17.5 and MV_HAvgSpd[i] < 22.5 then 5       //	5 	17.5mph<=speed<22.5mph 
				  else if MV_HAvgSpd[i] >= 22.5 and MV_HAvgSpd[i] < 27.5 then 6       //	6 	22.5mph<=speed<27.5mph 
				  else if MV_HAvgSpd[i] >= 27.5 and MV_HAvgSpd[i] < 32.5 then 7       //	7 	27.5mph<=speed<32.5mph 
				  else if MV_HAvgSpd[i] >= 32.5 and MV_HAvgSpd[i] < 37.5 then 8       //	8 	32.5mph<=speed<37.5mph 
				  else if MV_HAvgSpd[i] >= 37.5 and MV_HAvgSpd[i] < 42.5 then 9       //	9 	37.5mph<=speed<42.5mph 
				  else if MV_HAvgSpd[i] >= 42.5 and MV_HAvgSpd[i] < 47.5 then 10      //	10 	42.5mph<=speed<47.5mph 
				  else if MV_HAvgSpd[i] >= 47.5 and MV_HAvgSpd[i] < 52.5 then 11      //	11 	47.5mph<=speed<52.5mph 
				  else if MV_HAvgSpd[i] >= 52.5 and MV_HAvgSpd[i] < 57.5 then 12      //	12 	52.5mph<=speed<57.5mph 
				  else if MV_HAvgSpd[i] >= 57.5 and MV_HAvgSpd[i] < 62.5 then 13      //	13 	57.5mph<=speed<62.5mph 
				  else if MV_HAvgSpd[i] >= 62.5 and MV_HAvgSpd[i] < 67.5 then 14      //	14 	62.5mph<=speed<67.5mph 
				  else if MV_HAvgSpd[i] >= 67.5 and MV_HAvgSpd[i] < 72.5 then 15      //	15 	67.5mph<=speed<72.5mph 
				  else if MV_HAvgSpd[i] >= 72.5 then 16    		            	//	16 	72.5mph<=speed 
	end

//Speeds
	r = AddRecords(movesspd, null, null, {{"Empty Records", numlinks}})
	SetDataVectors(movesspd+"|", {{"ID1", ID}, {"Leng", Leng}, {"COUNTYID", COUNTYID}, {"FUNCCLASS", FC}, {"RoadType", MV_RoadType}, {"Ramp", Ramp}, {"SpdLmt", SPD_LMT}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesspd +"|", { {"Spd_0_1",MV_HAvgSpd[1]},{"Spd_1_2",MV_HAvgSpd[2]},{"Spd_2_3",MV_HAvgSpd[3]},{"Spd_3_4",MV_HAvgSpd[4]},{"Spd_4_5",MV_HAvgSpd[5]},{"Spd_5_6",MV_HAvgSpd[6]},{"Spd_6_7",MV_HAvgSpd[7]},{"Spd_7_8",MV_HAvgSpd[8]},{"Spd_8_9",MV_HAvgSpd[9]},{"Spd_9_10",MV_HAvgSpd[10]},{"Spd_10_11",MV_HAvgSpd[11]},{"Spd_11_12",MV_HAvgSpd[12]},{"Spd_12_13",MV_HAvgSpd[13]},{"Spd_13_14",MV_HAvgSpd[14]},{"Spd_14_15",MV_HAvgSpd[15]},{"Spd_15_16",MV_HAvgSpd[16]},{"Spd_16_17",MV_HAvgSpd[17]},{"Spd_17_18",MV_HAvgSpd[18]},{"Spd_18_19",MV_HAvgSpd[19]},{"Spd_19_20",MV_HAvgSpd[20]},{"Spd_20_21",MV_HAvgSpd[21]},{"Spd_21_22",MV_HAvgSpd[22]},{"Spd_22_23",MV_HAvgSpd[23]},{"Spd_23_24",MV_HAvgSpd[24]} }, {{"Sort Order",{{"ID1","Ascending"}}}})
		
//Bins
	r = AddRecords(movesbin, null, null, {{"Empty Records", numlinks}})
	SetDataVectors(movesbin+"|", {{"ID1", ID}, {"Leng", Leng}, {"COUNTYID", COUNTYID}, {"FUNCCLASS", FC}, {"RoadType", MV_RoadType}, {"Ramp", Ramp}, {"SpdLmt", SPD_LMT}}, {{"Sort Order",{{"ID1","Ascending"}}}})
	SetDataVectors(movesbin +"|", {{"Bin_0_1",MV_SpeedBin[1]},{"Bin_1_2",MV_SpeedBin[2]},{"Bin_2_3",MV_SpeedBin[3]},{"Bin_3_4",MV_SpeedBin[4]},{"Bin_4_5",MV_SpeedBin[5]},{"Bin_5_6",MV_SpeedBin[6]},{"Bin_6_7",MV_SpeedBin[7]},{"Bin_7_8",MV_SpeedBin[8]},{"Bin_8_9",MV_SpeedBin[9]},{"Bin_9_10",MV_SpeedBin[10]},{"Bin_10_11",MV_SpeedBin[11]},{"Bin_11_12",MV_SpeedBin[12]},{"Bin_12_13",MV_SpeedBin[13]},{"Bin_13_14",MV_SpeedBin[14]},{"Bin_14_15",MV_SpeedBin[15]},{"Bin_15_16",MV_SpeedBin[16]},{"Bin_16_17",MV_SpeedBin[17]},{"Bin_17_18",MV_SpeedBin[18]},{"Bin_18_19",MV_SpeedBin[19]},{"Bin_19_20",MV_SpeedBin[20]},{"Bin_20_21",MV_SpeedBin[21]},{"Bin_21_22",MV_SpeedBin[22]},{"Bin_22_23",MV_SpeedBin[23]},{"Bin_23_24",MV_SpeedBin[24]} }, {{"Sort Order",{{"ID1","Ascending"}}}})
		
//endfold
end

Return({outlinkvw, outnodevw})
endMacro

Macro "PostRep" (tazvw, linevw, nodevw, parampath, outlinkvw, outnodevw, reppath)
	shared post
	repinfo   = parampath + "CHCRPA_postaltinfo.bin"
	
	outview = CreateTable("Model Summary Report", post.outrep, "dBase", {
							{"Item"       , "String", 25, null, "No"},
							{"NumObs"     , "Real"  , 20, 2   , "No"},  
							{"VC"         , "Real"  , 20, 2   , "No"}, 
							{"RDMILES"    , "Real"  , 20, 2   , "No"},   
							{"VMT"        , "Real"  , 20, 2   , "No"}, 
							{"VHT"        , "Real"  , 20, 2   , "No"},  
							{"AUTO_DELAY" , "Real"  , 20, 2   , "No"},
							{"TRK_DELAY"  , "Real"  , 20, 2   , "No"},
							{"SUT_DELAY"  , "Real"  , 20, 2   , "No"},
							{"MUT_DELAY"  , "Real"  , 20, 2   , "No"},       
							{"VMT_AUTO"   , "Real"  , 20, 2   , "No"}, 
							{"VMT_TRK"    , "Real"  , 20, 2   , "No"},
							{"VMT_SUTRK"  , "Real"  , 20, 2   , "No"}, 
							{"VMT_MUTRK"  , "Real"  , 20, 2   , "No"},       
							{"VHT_AUTO"   , "Real"  , 20, 2   , "No"}, 
							{"VHT_TRK"    , "Real"  , 20, 2   , "No"},
							{"VHT_SUTRK"  , "Real"  , 20, 2   , "No"}, 
							{"VHT_MUTRK"  , "Real"  , 20, 2   , "No"},       
							{"TOTVEHFUEL" , "Real"  , 20, 2   , "No"}, 
							{"TOTTRKFUEL" , "Real"  , 20, 2   , "No"},       
							{"TOTSUTFUEL" , "Real"  , 20, 2   , "No"},
							{"TOTMUTFUEL" , "Real"  , 20, 2   , "No"},
							{"TOTVEHNFUE" , "Real"  , 20, 2   , "No"}, 
							{"TOTTRKNFUE" , "Real"  , 20, 2   , "No"},       
							{"TOTSUTNFUE" , "Real"  , 20, 2   , "No"},
							{"TOTMUTNFUE" , "Real"  , 20, 2   , "No"},
							{"fatal"      , "Real"  , 20, 2   , "No"}, 
							{"Injury"     , "Real"  , 20, 2   , "No"}, 
							{"PDO"        , "Real"  , 20, 2   , "No"}, 
							{"accident"   , "Real"  , 20, 2   , "No"},
							//{"fatalC"   , "Real"  , 20, 2   , "No"}, 
							//{"InjuryC"  , "Real"  , 20, 2   , "No"}, 
							//{"PDOC"     , "Real"  , 20, 2   , "No"}, 
							//{"accidentC", "Real"  , 20, 2   , "No"},
							{"VEHCOR"     , "Real"  , 20, 2   , "No"},
							{"VEHCOS"     , "Real"  , 20, 2   , "No"},
							{"VEHCO2R"    , "Real"  , 20, 2   , "No"},
							{"VEHCO2S"    , "Real"  , 20, 2   , "No"},
							{"VEHNOXR"    , "Real"  , 20, 2   , "No"},
							{"VEHNOXS"    , "Real"  , 20, 2   , "No"},
							{"VEHPM10R"   , "Real"  , 20, 2   , "No"},
							{"VEHPM10S"   , "Real"  , 20, 2   , "No"},
							{"VEHPM25R"   , "Real"  , 20, 2   , "No"},
							{"VEHPM25S"   , "Real"  , 20, 2   , "No"},
							{"VEHSOXR"    , "Real"  , 20, 2   , "No"},
							{"VEHSOXS"    , "Real"  , 20, 2   , "No"},
							{"VEHVOCR"    , "Real"  , 20, 2   , "No"},
							{"VEHVOCS"    , "Real"  , 20, 2   , "No"},
							{"TRKCOR"     , "Real"  , 20, 2   , "No"},
							{"TRKCOS"     , "Real"  , 20, 2   , "No"},
							{"TRKCO2R"    , "Real"  , 20, 2   , "No"},
							{"TRKCO2S"    , "Real"  , 20, 2   , "No"},
							{"TRKNOXR"    , "Real"  , 20, 2   , "No"},
							{"TRKNOXS"    , "Real"  , 20, 2   , "No"},
							{"TRKPM10R"   , "Real"  , 20, 2   , "No"},
							{"TRKPM10S"   , "Real"  , 20, 2   , "No"},
							{"TRKPM25R"   , "Real"  , 20, 2   , "No"},
							{"TRKPM25S"   , "Real"  , 20, 2   , "No"},
							{"TRKSOXR"    , "Real"  , 20, 2   , "No"},
							{"TRKSOXS"    , "Real"  , 20, 2   , "No"},
							{"TRKVOCR"    , "Real"  , 20, 2   , "No"},
							{"TRKVOCS"    , "Real"  , 20, 2   , "No"},
							{"SUTRKCOR"   , "Real"  , 20, 2   , "No"},
							{"SUTRKCOS"   , "Real"  , 20, 2   , "No"},
							{"SUTRKCO2R"  , "Real"  , 20, 2   , "No"},
							{"SUTRKCO2S"  , "Real"  , 20, 2   , "No"},
							{"SUTRKNOXR"  , "Real"  , 20, 2   , "No"},
							{"SUTRKNOXS"  , "Real"  , 20, 2   , "No"},
							{"SUTRKPM10R" , "Real"  , 20, 2   , "No"},
							{"SUTRKPM10S" , "Real"  , 20, 2   , "No"},
							{"SUTRKPM25R" , "Real"  , 20, 2   , "No"},
							{"SUTRKPM25S" , "Real"  , 20, 2   , "No"},
							{"SUTRKSOXR"  , "Real"  , 20, 2   , "No"},
							{"SUTRKSOXS"  , "Real"  , 20, 2   , "No"},
							{"SUTRKVOCR"  , "Real"  , 20, 2   , "No"},
							{"SUTRKVOCS"  , "Real"  , 20, 2   , "No"},
							{"MUTRKCOR"   , "Real"  , 20, 2   , "No"},
							{"MUTRKCOS"   , "Real"  , 20, 2   , "No"},
							{"MUTRKCO2R"  , "Real"  , 20, 2   , "No"},
							{"MUTRKCO2S"  , "Real"  , 20, 2   , "No"},
							{"MUTRKNOXR"  , "Real"  , 20, 2   , "No"},
							{"MUTRKNOXS"  , "Real"  , 20, 2   , "No"},
							{"MUTRKPM10R" , "Real"  , 20, 2   , "No"},
							{"MUTRKPM10S" , "Real"  , 20, 2   , "No"},
							{"MUTRKPM25R" , "Real"  , 20, 2   , "No"},
							{"MUTRKPM25S" , "Real"  , 20, 2   , "No"},
							{"MUTRKSOXR"  , "Real"  , 20, 2   , "No"},
							{"MUTRKSOXS"  , "Real"  , 20, 2   , "No"},
							{"MUTRKVOCR"  , "Real"  , 20, 2   , "No"},
							{"MUTRKVOCS"  , "Real"  , 20, 2   , "No"}       
						})
						
	postrepinfo = OpenTable("postrepinfo", "FFB", {repinfo, })
	{Type, Item, Query} = GetDataVectors(postrepinfo + "|", {"Type", "Item", "Query"}, null)
	CloseView(postrepinfo)
		
	RunMacro("dropfields", linevw, {"AB_PRE", "BA_PRE"}, {"r","r"})
	RunMacro("addfields", linevw, {"AB_ADJ_AUTO", "BA_ADJ_AUTO","TOT_ADJ_AUTO"}, {"r","r","r"})
	RunMacro("addfields", linevw, {"AB_ADJ_TRK", "BA_ADJ_TRK","TOT_ADJ_TRK"}, {"r","r","r"})
	RunMacro("addfields", linevw, {"AB_ADJ_SUT", "BA_ADJ_SUT","TOT_ADJ_SUT"}, {"r","r","r"})
	RunMacro("addfields", linevw, {"AB_ADJ_MUT", "BA_ADJ_MUT","TOT_ADJ_MUT"}, {"r","r","r"})
	RunMacro("addfields", linevw, {"AB_ADJ_TOT", "BA_ADJ_TOT","TOT_ADJ_TOT"}, {"r","r","r"})
	RunMacro("addfields", linevw, {"AB_dlycgtime", "BA_dlycgtime","AB_dlycgspd","BA_dlycgspd"}, {"r","r","r","r"})
	RunMacro("addfields", linevw, {"AB_pktime", "BA_pktime","AB_pkspeed","BA_pkspeed"}, {"r","r","r","r"})
	
	// Add SU and MU truck related field - SB
	//RunMacro("addfields", {linevw, {"TOTSUTFlow", "TOTMUTFlow"}, {"r","r"}})
	
	jnvw = JoinViews("jnvw", linevw+".ID", outlinkvw+".ID1", )
	SetView(jnvw)
	
	//Replace TN modeled volumes with ADJVOL
	//n = SelectByQuery("Mod", "Several", "Select * where FUNCCLASS <> null and FUNCCLASS <> 99 and STATE = 'TN'",)
	n = SelectByQuery("Mod", "Several", "Select * where FUNCCLASS > 0 and FUNCCLASS < 95 ",)
	tcf = CreateExpression(jnvw, "TCF", "nz(CAR_AB) + nz(CAR_BA)", )
	ttf = CreateExpression(jnvw, "TTF", "nz(TRK_AB) + nz(TRK_BA)", )
	
	tsutf = CreateExpression(jnvw, "TSUTF", "nz(SUT_AB) + nz(SUT_BA)", )
	tmutf = CreateExpression(jnvw, "TMUTF", "nz(MUT_AB) + nz(MUT_BA)", )
	
	abtvf = CreateExpression(jnvw, "ABTVF", "nz(CAR_AB) + nz(TRK_AB)", )
	batvf = CreateExpression(jnvw, "BATVF", "nz(CAR_BA) + nz(TRK_BA)", )
	tvf = CreateExpression(jnvw, "TVF", "ABTVF + BATVF", )
	SetRecordsValues(jnvw+"|Mod", {{"AB_ADJ_AUTO", "BA_ADJ_AUTO","TOT_ADJ_AUTO","AB_ADJ_TRK", "BA_ADJ_TRK","TOT_ADJ_TRK","AB_ADJ_TOT", "BA_ADJ_TOT","TOT_ADJ_TOT","AB_dlycgtime", "BA_dlycgtime", "AB_dlycgspd", "BA_dlycgspd", "AB_pktime", "BA_pktime", "AB_pkspeed", "BA_pkspeed"}, null}, "Formula", 
								  {"CAR_AB"      ,"CAR_BA"      ,"TCF"         , "TRK_AB"   , "TRK_BA"    ,"TTF"        ,"ABTVF"     , "BATVF"     , "TVF"       , "dlycgtt_AB" , "dlycgtt_BA"  , "dlyspd_AB"  , "dlyspd_BA"  , "PKTIME_AB", "PKTIME_BA", "PKSPD_AB"  , "PKSPD_BA"}  ,)
	
	// SB - For SU and MU trucks
	SetRecordsValues(jnvw+"|Mod", {{"AB_ADJ_SUT", "BA_ADJ_SUT","TOT_ADJ_SUT","AB_ADJ_MUT", "BA_ADJ_MUT","TOT_ADJ_MUT"}, null}, "Formula", 
								  {"SUT_AB"     , "SUT_BA"    ,"TSUTF"      , "MUT_AB"   , "MUT_BA"    ,"TMUTF"}      ,)
	
	arr = GetExpressions(jnvw)
	for i = 1 to arr.length do DestroyExpression(jnvw+"."+arr[i]) end        
	
	for i = 1 to Query.length do
		if Type[i] = "SEP" then do AddRecord(outview,{{"Item",Item[i]}}) goto nextquery end
		//NumObs = SelectByQuery("set", "Several", "Select * where (" + Query[i] +") and FUNCCLASS <> null and FUNCCLASS < 95 and STATE = 'TN'", )
		NumObs = SelectByQuery("set", "Several", "Select * where (" + Query[i] +") and FUNCCLASS > 0 and FUNCCLASS < 95", )
		if NumObs > 0 then do
			{leng, VHT, VHT_CAR, VHT_TRK, VMT, VMT_CAR, VMT_TRK, MAXVC_AB, MAXVC_BA, CDELAY_AB, CDELAY_BA, TDELAY_AB, TDELAY_BA} = GetDataVectors(jnvw + "|set", {"Length", "VHT", "VHT_CAR", "VHT_TRK", "VMT", "VMT_CAR", "VMT_TRK", "MAXVC_AB", "MAXVC_BA","CDELAY_AB","CDELAY_BA","TDELAY_AB","TDELAY_BA"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{TOTVEHFUEL, TOTTRKFUEL, TOTVEHNFUE, TOTTRKNFUE} = GetDataVectors(jnvw + "|set", {"TOTVEHFUEL","TOTTRKFUEL","TOTVEHNFUE","TOTTRKNFUE"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			// New crash data - SB
			//{fatal, Injury, PDO, accident, fatalC, InjuryC, PDOC, accidentC} = GetDataVectors(jnvw + "|set", {"fatal","Injury","PDO","accident","fatalC","InjuryC","PDOC", "accidentC"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{fatal, Injury, PDO, accident} = GetDataVectors(jnvw + "|set", {"Crashes_F","Crashes_I","Crashes_P","CrashesTot"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{VEHCOR, VEHCOS, VEHCO2R, VEHCO2S, VEHNOXR, VEHNOXS, VEHPM10R, VEHPM10S, VEHPM25R, VEHPM25S, VEHSOXR, VEHSOXS, VEHVOCR, VEHVOCS} = GetDataVectors(jnvw + "|set", {"VEHCOR","VEHCOS","VEHCO2R","VEHCO2S","VEHNOXR","VEHNOXS","VEHPM10R","VEHPM10S","VEHPM25R","VEHPM25S","VEHSOXR","VEHSOXS","VEHVOCR","VEHVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{TRKCOR, TRKCOS, TRKCO2R, TRKCO2S, TRKNOXR, TRKNOXS, TRKPM10R, TRKPM10S, TRKPM25R, TRKPM25S, TRKSOXR, TRKSOXS, TRKVOCR, TRKVOCS} = GetDataVectors(jnvw + "|set", {"TRKCOR","TRKCOS","TRKCO2R","TRKCO2S","TRKNOXR","TRKNOXS","TRKPM10R","TRKPM10S","TRKPM25R","TRKPM25S","TRKSOXR","TRKSOXS","TRKVOCR","TRKVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			// SU and MU VHT , VMT and delay - SB
			{VHT_SUTRK, VMT_SUTRK, SUDELAY_AB, SUDELAY_BA} = GetDataVectors(jnvw + "|set", {"VHT_SUTrk", "VMT_SUTrk", "SUDELAY_AB", "SUDELAY_BA"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{VHT_MUTRK, VMT_MUTRK, MUDELAY_AB, MUDELAY_BA} = GetDataVectors(jnvw + "|set", {"VHT_MUTrk", "VMT_MUTrk", "MUDELAY_AB", "MUDELAY_BA"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{TOTSUTFUEL, TOTSUTNFUE} = GetDataVectors(jnvw + "|set", {"TOTSUTFUEL", "TOTSUTNFUE"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{TOTMUTFUEL, TOTMUTNFUE} = GetDataVectors(jnvw + "|set", {"TOTMUTFUEL", "TOTMUTNFUE"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{SUTRKCOR, SUTRKCOS, SUTRKCO2R, SUTRKCO2S, SUTRKNOXR, SUTRKNOXS, SUTRKPM10R, SUTRKPM10S, SUTRKPM25R, SUTRKPM25S, SUTRKSOXR, SUTRKSOXS, SUTRKVOCR, SUTRKVOCS} = GetDataVectors(jnvw + "|set", {"SUTRKCOR","SUTRKCOS","SUTRKCO2R","SUTRKCO2S","SUTRKNOXR","SUTRKNOXS","SUTRKPM10R","SUTRKPM10S","SUTRKPM25R","SUTRKPM25S","SUTRKSOXR","SUTRKSOXS","SUTRKVOCR","SUTRKVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{MUTRKCOR, MUTRKCOS, MUTRKCO2R, MUTRKCO2S, MUTRKNOXR, MUTRKNOXS, MUTRKPM10R, MUTRKPM10S, MUTRKPM25R, MUTRKPM25S, MUTRKSOXR, MUTRKSOXS, MUTRKVOCR, MUTRKVOCS} = GetDataVectors(jnvw + "|set", {"MUTRKCOR","MUTRKCOS","MUTRKCO2R","MUTRKCO2S","MUTRKNOXR","MUTRKNOXS","MUTRKPM10R","MUTRKPM10S","MUTRKPM25R","MUTRKPM25S","MUTRKSOXR","MUTRKSOXS","MUTRKVOCR","MUTRKVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			MAXVC = max(nz(MAXVC_AB), nz(MAXVC_BA))
			WFCVC = MAXVC * VMT
			CDELAY = (nz(CDELAY_AB) + nz(CDELAY_BA))
			TDELAY = (nz(TDELAY_AB) + nz(TDELAY_BA))

			// SU and MU data added where applicable - SB
			SUDELAY = (nz(SUDELAY_AB) + nz(SUDELAY_BA))
			MUDELAY = (nz(MUDELAY_AB) + nz(MUDELAY_BA))
			
			weight  = Vector(NumObs, "Long", {{"Constant", 1}})
			RM      = VectorStatistic(leng, "Sum", {"Weight",weight})
			TOTVMT  = VectorStatistic(VMT, "Sum", {"Weight",weight})
			TOTVHT  = VectorStatistic(VHT, "Sum", {"Weight",weight})
			AUTODELAY = VectorStatistic(CDELAY, "Sum", {"Weight",weight})
			TRKDELAY = VectorStatistic(TDELAY, "Sum", {"Weight",weight})
			
			SUTRKDELAY = VectorStatistic(SUDELAY, "Sum", {"Weight",weight})
			MUTRKDELAY = VectorStatistic(MUDELAY, "Sum", {"Weight",weight})
			
			VMTAUTO = VectorStatistic(VMT_CAR, "Sum", {"Weight",weight})
			VMTTRK  = VectorStatistic(VMT_TRK, "Sum", {"Weight",weight})
			
			VMTSUTRK  = VectorStatistic(VMT_SUTRK, "Sum", {"Weight",weight})
			VMTMUTRK  = VectorStatistic(VMT_MUTRK, "Sum", {"Weight",weight})
			
			VHTAUTO = VectorStatistic(VHT_CAR, "Sum", {"Weight",weight})
			VHTTRK  = VectorStatistic(VHT_TRK, "Sum", {"Weight",weight})
			
			VHTSUTRK  = VectorStatistic(VHT_SUTRK, "Sum", {"Weight",weight})
			VHTMUTRK  = VectorStatistic(VHT_MUTRK, "Sum", {"Weight",weight})
			
			
			VC      = VectorStatistic(WFCVC, "Sum", {"Weight",weight}) / TOTVMT
			VEHFUEL   = VectorStatistic(TOTVEHFUEL, "Sum", {"Weight",weight})
			TRKFUEL  = VectorStatistic(TOTTRKFUEL, "Sum", {"Weight",weight})
			
			SUTRKFUEL  = VectorStatistic(TOTSUTFUEL, "Sum", {"Weight",weight})
			MUTRKFUEL  = VectorStatistic(TOTMUTFUEL, "Sum", {"Weight",weight})
			
			VEHNFUEL   = VectorStatistic(TOTVEHNFUE, "Sum", {"Weight",weight})
			TRKNFUE   = VectorStatistic(TOTTRKNFUE, "Sum", {"Weight",weight})
			
			SUTRKNFUE   = VectorStatistic(TOTSUTNFUE, "Sum", {"Weight",weight})
			MUTRKNFUE   = VectorStatistic(TOTMUTNFUE, "Sum", {"Weight",weight})
			
			TOTFATAL  = VectorStatistic(fatal, "Sum", {"Weight",weight})
			TOTINJURY  = VectorStatistic(Injury, "Sum", {"Weight",weight})
			TOTPDO  = VectorStatistic(PDO, "Sum", {"Weight",weight})
			TOTACCI  = VectorStatistic(accident, "Sum", {"Weight",weight})
			/*TOTFATALC  = VectorStatistic(fatalC, "Sum", {"Weight",weight})
			TOTINJURYC  = VectorStatistic(InjuryC, "Sum", {"Weight",weight})
			TOTPDOC  = VectorStatistic(PDOC, "Sum", {"Weight",weight})
			TOTACCIC  = VectorStatistic(accidentC, "Sum", {"Weight",weight})*/
			TOTVEHCOR = VectorStatistic(VEHCOR, "Sum", {"Weight",weight})
			TOTVEHCOS = VectorStatistic(VEHCOS, "Sum", {"Weight",weight})
			TOTVEHCO2R = VectorStatistic(VEHCO2R, "Sum", {"Weight",weight})
			TOTVEHCO2S = VectorStatistic(VEHCO2S, "Sum", {"Weight",weight})	
			TOTVEHNOXR = VectorStatistic(VEHNOXR, "Sum", {"Weight",weight})
			TOTVEHNOXS = VectorStatistic(VEHNOXS, "Sum", {"Weight",weight})
			TOTVEHPMR = VectorStatistic(VEHPM10R, "Sum", {"Weight",weight})
			TOTVEHPMS = VectorStatistic(VEHPM10S, "Sum", {"Weight",weight})
			TOTVEHPM25R = VectorStatistic(VEHPM25R, "Sum", {"Weight",weight})
			TOTVEHPM25S = VectorStatistic(VEHPM25S, "Sum", {"Weight",weight})
			TOTVEHSOXR = VectorStatistic(VEHSOXR, "Sum", {"Weight",weight})
			TOTVEHSOXS = VectorStatistic(VEHSOXS, "Sum", {"Weight",weight})
			TOTVEHVOCR = VectorStatistic(VEHVOCR, "Sum", {"Weight",weight})
			TOTVEHVOCS = VectorStatistic(VEHVOCS, "Sum", {"Weight",weight})
			TOTTRKCOR = VectorStatistic(TRKCOR, "Sum", {"Weight",weight})
			TOTTRKCOS = VectorStatistic(TRKCOS, "Sum", {"Weight",weight})
			TOTTRKCO2R = VectorStatistic(TRKCO2R, "Sum", {"Weight",weight})
			TOTTRKCO2S = VectorStatistic(TRKCO2S, "Sum", {"Weight",weight})	
			TOTTRKNOXR = VectorStatistic(TRKNOXR, "Sum", {"Weight",weight})
			TOTTRKNOXS = VectorStatistic(TRKNOXS, "Sum", {"Weight",weight})
			TOTTRKPMR = VectorStatistic(TRKPM10R, "Sum", {"Weight",weight})
			TOTTRKPMS = VectorStatistic(TRKPM10S, "Sum", {"Weight",weight})
			TOTTRKPM25R = VectorStatistic(TRKPM25R, "Sum", {"Weight",weight})
			TOTTRKPM25S = VectorStatistic(TRKPM25S, "Sum", {"Weight",weight})
			TOTTRKSOXR = VectorStatistic(TRKSOXR, "Sum", {"Weight",weight})
			TOTTRKSOXS = VectorStatistic(TRKSOXS, "Sum", {"Weight",weight})
			TOTTRKVOCR = VectorStatistic(TRKVOCR, "Sum", {"Weight",weight})
			TOTTRKVOCS = VectorStatistic(TRKVOCS, "Sum", {"Weight",weight})	

			TOTSUTRKCOR = VectorStatistic(SUTRKCOR, "Sum", {"Weight",weight})
			TOTSUTRKCOS = VectorStatistic(SUTRKCOS, "Sum", {"Weight",weight})
			TOTSUTRKCO2R = VectorStatistic(SUTRKCO2R, "Sum", {"Weight",weight})
			TOTSUTRKCO2S = VectorStatistic(SUTRKCO2S, "Sum", {"Weight",weight})	
			TOTSUTRKNOXR = VectorStatistic(SUTRKNOXR, "Sum", {"Weight",weight})
			TOTSUTRKNOXS = VectorStatistic(SUTRKNOXS, "Sum", {"Weight",weight})
			TOTSUTRKPMR = VectorStatistic(SUTRKPM10R, "Sum", {"Weight",weight})
			TOTSUTRKPMS = VectorStatistic(SUTRKPM10S, "Sum", {"Weight",weight})
			TOTSUTRKPM25R = VectorStatistic(SUTRKPM25R, "Sum", {"Weight",weight})
			TOTSUTRKPM25S = VectorStatistic(SUTRKPM25S, "Sum", {"Weight",weight})
			TOTSUTRKSOXR = VectorStatistic(SUTRKSOXR, "Sum", {"Weight",weight})
			TOTSUTRKSOXS = VectorStatistic(SUTRKSOXS, "Sum", {"Weight",weight})
			TOTSUTRKVOCR = VectorStatistic(SUTRKVOCR, "Sum", {"Weight",weight})
			TOTSUTRKVOCS = VectorStatistic(SUTRKVOCS, "Sum", {"Weight",weight})
			TOTMUTRKCOR = VectorStatistic(MUTRKCOR, "Sum", {"Weight",weight})
			TOTMUTRKCOS = VectorStatistic(MUTRKCOS, "Sum", {"Weight",weight})
			TOTMUTRKCO2R = VectorStatistic(MUTRKCO2R, "Sum", {"Weight",weight})
			TOTMUTRKCO2S = VectorStatistic(MUTRKCO2S, "Sum", {"Weight",weight})	
			TOTMUTRKNOXR = VectorStatistic(MUTRKNOXR, "Sum", {"Weight",weight})
			TOTMUTRKNOXS = VectorStatistic(MUTRKNOXS, "Sum", {"Weight",weight})
			TOTMUTRKPMR = VectorStatistic(MUTRKPM10R, "Sum", {"Weight",weight})
			TOTMUTRKPMS = VectorStatistic(MUTRKPM10S, "Sum", {"Weight",weight})
			TOTMUTRKPM25R = VectorStatistic(MUTRKPM25R, "Sum", {"Weight",weight})
			TOTMUTRKPM25S = VectorStatistic(MUTRKPM25S, "Sum", {"Weight",weight})
			TOTMUTRKSOXR = VectorStatistic(MUTRKSOXR, "Sum", {"Weight",weight})
			TOTMUTRKSOXS = VectorStatistic(MUTRKSOXS, "Sum", {"Weight",weight})
			TOTMUTRKVOCR = VectorStatistic(MUTRKVOCR, "Sum", {"Weight",weight})
			TOTMUTRKVOCS = VectorStatistic(MUTRKVOCS, "Sum", {"Weight",weight})			
		end                
		
		//if NumObs = 0 then {VC,RM,TOTVMT,TOTVHT,TOTDELAY,VMTAUTO,VMTTRK,VHTAUTO,VHTTRK,VEHFUEL,TRKFUEL,VEHNFUEL,TRKNFUE,TOTFATAL,TOTINJURY,TOTPDO,TOTACCI,TOTFATALC,TOTINJURYC,TOTPDOC,TOTACCIC,TOTVEHCOR,TOTVEHCOS,TOTVEHCO2R,TOTVEHCO2S,TOTVEHNOXR,TOTVEHNOXS,TOTVEHPMR,TOTVEHPMS,TOTVEHSOXR,TOTVEHSOXS,TOTVEHVOCR,TOTVEHVOCS,TOTTRKCOR,TOTTRKCOS,TOTTRKCO2R,TOTTRKCO2S,TOTTRKNOXR,TOTTRKNOXS,TOTTRKPMR,TOTTRKPMS,TOTTRKSOXR,TOTTRKSOXS,TOTTRKVOCR,TOTTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if NumObs = 0 then {VC,RM,TOTVMT,TOTVHT,TOTDELAY,VMTAUTO,VMTTRK,VHTAUTO,VHTTRK,VEHFUEL,TRKFUEL,VEHNFUEL,TRKNFUE,TOTFATAL,TOTINJURY,TOTPDO,TOTACCI,TOTVEHCOR,TOTVEHCOS,TOTVEHCO2R,TOTVEHCO2S,TOTVEHNOXR,TOTVEHNOXS,TOTVEHPMR,TOTVEHPMS,TOTVEHPM25R,TOTVEHPM25S,TOTVEHSOXR,TOTVEHSOXS,TOTVEHVOCR,TOTVEHVOCS,TOTTRKCOR,TOTTRKCOS,TOTTRKCO2R,TOTTRKCO2S,TOTTRKNOXR,TOTTRKNOXS,TOTTRKPMR,TOTTRKPMS,TOTTRKPM25R,TOTTRKPM25S,TOTTRKSOXR,TOTTRKSOXS,TOTTRKVOCR,TOTTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if NumObs = 0 then {VMTSUTRK,VHTSUTRK,SUTRKFUEL,SUTRKNFUE,TOTSUTRKCOR,TOTSUTRKCOS,TOTSUTRKCO2R,TOTSUTRKCO2S,TOTSUTRKNOXR,TOTSUTRKNOXS,TOTSUTRKPMR,TOTSUTRKPMS,TOTSUTRKPM25R,TOTSUTRKPM25S,TOTSUTRKSOXR,TOTSUTRKSOXS,TOTSUTRKVOCR,TOTSUTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if NumObs = 0 then {VMTMUTRK,VHTMUTRK,MUTRKFUEL,MUTRKNFUE,TOTMUTRKCOR,TOTMUTRKCOS,TOTMUTRKCO2R,TOTMUTRKCO2S,TOTMUTRKNOXR,TOTMUTRKNOXS,TOTMUTRKPMR,TOTMUTRKPMS,TOTMUTRKPM25R,TOTMUTRKPM25S,TOTMUTRKSOXR,TOTMUTRKSOXS,TOTMUTRKVOCR,TOTMUTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		
		// These were not zeroed out - SB
		if NumObs = 0 then {AUTODELAY,TRKDELAY,SUTRKDELAY,MUTRKDELAY} = {0,0,0,0}
		
		AddRecord(outview,{{"Item",Item[i]},{"NumObs",NumObs},{"VC",VC},{"RDMILES",RM},{"VMT",TOTVMT},{"VHT",TOTVHT},{"AUTO_DELAY",AUTODELAY},{"TRK_DELAY",TRKDELAY},
		
		{"SUT_DELAY",SUTRKDELAY},{"MUT_DELAY",MUTRKDELAY},
		
		{"VMT_AUTO",VMTAUTO},{"VMT_TRK",VMTTRK},
		
		{"VMT_SUTRK",VMTSUTRK},{"VMT_MUTRK",VMTMUTRK},
		
		{"VHT_AUTO",VHTAUTO},{"VHT_TRK",VHTTRK},
		
		{"VHT_SUTRK",VHTSUTRK},{"VHT_MUTRK",VHTMUTRK},
		
		{"TOTVEHFUEL",VEHFUEL},{"TOTTRKFUEL",TRKFUEL},
		
		{"TOTSUTFUEL",SUTRKFUEL},{"TOTMUTFUEL",MUTRKFUEL},
		
		{"TOTVEHNFUE",VEHNFUEL},{"TOTTRKNFUE",TRKNFUE},
		
		{"TOTSUTNFUE",SUTRKNFUE},{"TOTMUTNFUE",MUTRKNFUE},
		
		{"fatal",TOTFATAL},{"Injury",TOTINJURY},{"PDO",TOTPDO},{"accident",TOTACCI},
		
		//{"fatalC",TOTFATALC},{"InjuryC",TOTINJURYC},{"PDOC",TOTPDOC},{"accidentC",TOTACCIC},
		{"VEHCOR",TOTVEHCOR},{"VEHCOS",TOTVEHCOS},
		{"VEHCO2R",TOTVEHCO2R},{"VEHCO2S",TOTVEHCO2S},
		{"VEHNOXR",TOTVEHNOXR},{"VEHNOXS",TOTVEHNOXS},
		{"VEHPM10R",TOTVEHPMR},{"VEHPM10S",TOTVEHPMS},
		{"VEHPM25R",TOTVEHPM25R},{"VEHPM25S",TOTVEHPM25S},
		{"VEHSOXR",TOTVEHSOXR},{"VEHSOXS",TOTVEHSOXS}, 
		{"VEHVOCR",TOTVEHVOCR},{"VEHVOCS",TOTVEHVOCS},
		{"TRKCOR",TOTTRKCOR},  {"TRKCOS",TOTTRKCOS},
		{"TRKCO2R",TOTTRKCO2R},{"TRKCO2S",TOTTRKCO2S},
		{"TRKNOXR",TOTTRKNOXR},{"TRKNOXS",TOTTRKNOXS},
		{"TRKPM10R",TOTTRKPMR},{"TRKPM10S",TOTTRKPMS},
		{"TRKPM25R",TOTTRKPM25R},{"TRKPM25S",TOTTRKPM25S},
		{"TRKSOXR",TOTTRKSOXR},{"TRKSOXS",TOTTRKSOXS}, 
		{"TRKVOCR",TOTTRKVOCR},{"TRKVOCS",TOTTRKVOCS},
		
		{"SUTRKCOR",TOTSUTRKCOR},  {"SUTRKCOS",TOTSUTRKCOS},
		{"SUTRKCO2R",TOTSUTRKCO2R},{"SUTRKCO2S",TOTSUTRKCO2S},
		{"SUTRKNOXR",TOTSUTRKNOXR},{"SUTRKNOXS",TOTSUTRKNOXS},
		{"SUTRKPM10R",TOTSUTRKPMR},{"SUTRKPM10S",TOTSUTRKPMS},
		{"SUTRKPM25R",TOTSUTRKPM25R},{"SUTRKPM25S",TOTSUTRKPM25S},
		{"SUTRKSOXR",TOTSUTRKSOXR},{"SUTRKSOXS",TOTSUTRKSOXS}, 
		{"SUTRKVOCR",TOTSUTRKVOCR},{"SUTRKVOCS",TOTSUTRKVOCS},
		
		{"MUTRKCOR",TOTMUTRKCOR},  {"MUTRKCOS",TOTMUTRKCOS},
		{"MUTRKCO2R",TOTMUTRKCO2R},{"MUTRKCO2S",TOTMUTRKCO2S},
		{"MUTRKNOXR",TOTMUTRKNOXR},{"MUTRKNOXS",TOTMUTRKNOXS},
		{"MUTRKPM10R",TOTMUTRKPMR},{"MUTRKPM10S",TOTMUTRKPMS},
		{"MUTRKPM25R",TOTMUTRKPM25R},{"MUTRKPM25S",TOTMUTRKPM25S},
		{"MUTRKSOXR",TOTMUTRKSOXR},{"MUTRKSOXS",TOTMUTRKSOXS}, 
		{"MUTRKVOCR",TOTMUTRKVOCR},{"MUTRKVOCS",TOTMUTRKVOCS}})
		
		nextquery:
	end
	
//Now for unique Label field
	// Create this "lable" field to be used later - SB
	AddRecord(outview, {{"Item","Labels"}})
	LabelObs = SelectByQuery("set", "Several", "Select * where Label <> null", )
	if LabelObs > 0 then do
		{label} = GetDataVectors(jnvw+"|set", {"Label"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
		labarr = V2A(label)
		uniques = SortArray(labarr, {{"Unique","True"}, {"Ascending","True"}})
	
		for i = 1 to uniques.length do
			NumObs = SelectByQuery("set", "Several", "Select * where Label = '" + uniques[i] +"' ", )
			{leng, VHT, VHT_CAR, VHT_TRK, VMT, VMT_CAR, VMT_TRK, MAXVC_AB, MAXVC_BA, CDELAY_AB, CDELAY_BA, TDELAY_AB, TDELAY_BA} = GetDataVectors(jnvw + "|set", {"Length", "VHT", "VHT_CAR", "VHT_TRK", "VMT", "VMT_CAR", "VMT_TRK", "MAXVC_AB", "MAXVC_BA","CDELAY_AB","CDELAY_BA","TDELAY_AB","TDELAY_BA"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			{VHT_SUTRK, VMT_SUTRK} = GetDataVectors(jnvw + "|set", {"VHT_SUTRK", "VMT_SUTRK"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{VHT_MUTRK, VMT_MUTRK} = GetDataVectors(jnvw + "|set", {"VHT_MUTRK", "VMT_MUTRK"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			//{TOTVEHFUEL, TOTTRKFUEL, TOTVEHNFUE, TOTTRKNFUE, fatal, Injury, PDO, accident, fatalC, InjuryC, PDOC, accidentC} = GetDataVectors(jnvw + "|set", {"TOTVEHFUEL","TOTTRKFUEL","TOTVEHNFUE","TOTTRKNFUE","fatal","Injury","PDO","accident","fatalC","InjuryC","PDOC", "accidentC"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{TOTVEHFUEL, TOTTRKFUEL, TOTVEHNFUE, TOTTRKNFUE} = GetDataVectors(jnvw + "|set", {"TOTVEHFUEL","TOTTRKFUEL","TOTVEHNFUE","TOTTRKNFUE"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{fatal, Injury, PDO, accident} = GetDataVectors(jnvw + "|set", {"Crashes_F","Crashes_I","Crashes_P","CrashesTot"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			{SUTRKFUEL, SUTRKNFUE} = GetDataVectors(jnvw + "|set", {"TOTSUTFUEL","TOTSUTNFUE"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{MUTRKFUEL, MUTRKNFUE} = GetDataVectors(jnvw + "|set", {"TOTMUTFUEL","TOTMUTNFUE"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			{VEHCOR, VEHCOS, VEHCO2R, VEHCO2S, VEHNOXR, VEHNOXS, VEHPM10R, VEHPM10S, VEHPM25R, VEHPM25S, VEHSOXR, VEHSOXS, VEHVOCR, VEHVOCS} = GetDataVectors(jnvw + "|set", {"VEHCOR","VEHCOS","VEHCO2R","VEHCO2S","VEHNOXR","VEHNOXS","VEHPM10R","VEHPM10S","VEHPM25R","VEHPM25S","VEHSOXR","VEHSOXS","VEHVOCR","VEHVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{TRKCOR, TRKCOS, TRKCO2R, TRKCO2S, TRKNOXR, TRKNOXS, TRKPM10R, TRKPM10S, TRKPM25R, TRKPM25S, TRKSOXR, TRKSOXS, TRKVOCR, TRKVOCS} = GetDataVectors(jnvw + "|set", {"TRKCOR","TRKCOS","TRKCO2R","TRKCO2S","TRKNOXR","TRKNOXS","TRKPM10R","TRKPM10S","TRKPM25R","TRKPM25S","TRKSOXR","TRKSOXS","TRKVOCR","TRKVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			
			{SUTRKCOR, SUTRKCOS, SUTRKCO2R, SUTRKCO2S, SUTRKNOXR, SUTRKNOXS, SUTRKPM10R, SUTRKPM10S, SUTRKPM25R, SUTRKPM25S, SUTRKSOXR, SUTRKSOXS, SUTRKVOCR, SUTRKVOCS} = GetDataVectors(jnvw + "|set", {"SUTRKCOR","SUTRKCOS","SUTRKCO2R","SUTRKCO2S","SUTRKNOXR","SUTRKNOXS","SUTRKPM10R","SUTRKPM10S","SUTRKPM25R","SUTRKPM25S","SUTRKSOXR","SUTRKSOXS","SUTRKVOCR","SUTRKVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
			{MUTRKCOR, MUTRKCOS, MUTRKCO2R, MUTRKCO2S, MUTRKNOXR, MUTRKNOXS, MUTRKPM10R, MUTRKPM10S, MUTRKPM25R, MUTRKPM25S, MUTRKSOXR, MUTRKSOXS, MUTRKVOCR, MUTRKVOCS} = GetDataVectors(jnvw + "|set", {"MUTRKCOR","MUTRKCOS","MUTRKCO2R","MUTRKCO2S","MUTRKNOXR","MUTRKNOXS","MUTRKPM10R","MUTRKPM10S","MUTRKPM25R","MUTRKPM25S","MUTRKSOXR","MUTRKSOXS","MUTRKVOCR","MUTRKVOCS"},{{"Sort Order",{{linevw+".ID","Ascending"}}}})
				
			MAXVC = max(nz(MAXVC_AB), nz(MAXVC_BA))
			WFCVC = MAXVC * VMT
			CDELAY = (CDELAY_AB + CDELAY_BA)
			TDELAY = (TDELAY_AB + TDELAY_BA)
			SUDELAY = (SUDELAY_AB + SUDELAY_BA)
			MUDELAY = (MUDELAY_AB + MUDELAY_BA)
			
			weight     = Vector(NumObs, "Long", {{"Constant", 1}})
			RM         = VectorStatistic(leng      , "Sum", {"Weight",weight})
			TOTVMT     = VectorStatistic(VMT       , "Sum", {"Weight",weight})
			TOTVHT     = VectorStatistic(VHT       , "Sum", {"Weight",weight})
			AUTODELAY   = VectorStatistic(CDELAY     , "Sum", {"Weight",weight})
			TRKDELAY   = VectorStatistic(TDELAY     , "Sum", {"Weight",weight})
			
			SUTRKDELAY   = VectorStatistic(SUDELAY     , "Sum", {"Weight",weight})
			MUTRKDELAY   = VectorStatistic(MUDELAY     , "Sum", {"Weight",weight})
			
			VMTAUTO    = VectorStatistic(VMT_CAR   , "Sum", {"Weight",weight})
			VMTTRK     = VectorStatistic(VMT_TRK   , "Sum", {"Weight",weight})
			
			VMTSUTRK     = VectorStatistic(VMT_SUTRK   , "Sum", {"Weight",weight})
			VMTMUTRK     = VectorStatistic(VMT_MUTRK   , "Sum", {"Weight",weight})
			
			VHTAUTO    = VectorStatistic(VHT_CAR   , "Sum", {"Weight",weight})
			VHTTRK     = VectorStatistic(VHT_TRK   , "Sum", {"Weight",weight})
			
			VHTSUTRK     = VectorStatistic(VHT_SUTRK   , "Sum", {"Weight",weight})
			VHTMUTRK     = VectorStatistic(VHT_MUTRK   , "Sum", {"Weight",weight})
			
			VC         = VectorStatistic(WFCVC     , "Sum", {"Weight",weight})/TOTVMT
			VEHFUEL    = VectorStatistic(TOTVEHFUEL, "Sum", {"Weight",weight})
			TRKFUEL    = VectorStatistic(TOTTRKFUEL, "Sum", {"Weight",weight})
			
			SUTRKFUEL    = VectorStatistic(SUTRKFUEL, "Sum", {"Weight",weight})
			MUTRKFUEL    = VectorStatistic(MUTRKFUEL, "Sum", {"Weight",weight})
			
			VEHNFUEL   = VectorStatistic(TOTVEHNFUE, "Sum", {"Weight",weight})
			TRKNFUE    = VectorStatistic(TOTTRKNFUE, "Sum", {"Weight",weight})
			
			SUTRKNFUE    = VectorStatistic(SUTRKNFUE, "Sum", {"Weight",weight})
			MUTRKNFUE    = VectorStatistic(MUTRKNFUE, "Sum", {"Weight",weight})
			
			TOTFATAL   = VectorStatistic(fatal     , "Sum", {"Weight",weight})
			TOTINJURY  = VectorStatistic(Injury    , "Sum", {"Weight",weight})
			TOTPDO     = VectorStatistic(PDO       , "Sum", {"Weight",weight})
			TOTACCI    = VectorStatistic(accident  , "Sum", {"Weight",weight})
			/*TOTFATALC  = VectorStatistic(fatalC    , "Sum", {"Weight",weight})
			TOTINJURYC = VectorStatistic(InjuryC   , "Sum", {"Weight",weight})
			TOTPDOC    = VectorStatistic(PDOC      , "Sum", {"Weight",weight})
			TOTACCIC   = VectorStatistic(accidentC , "Sum", {"Weight",weight})*/
			TOTVEHCOR  = VectorStatistic(VEHCOR    , "Sum", {"Weight",weight})
			TOTVEHCOS  = VectorStatistic(VEHCOS    , "Sum", {"Weight",weight})
			TOTVEHCO2R = VectorStatistic(VEHCO2R   , "Sum", {"Weight",weight})
			TOTVEHCO2S = VectorStatistic(VEHCO2S   , "Sum", {"Weight",weight}) 
			TOTVEHNOXR = VectorStatistic(VEHNOXR   , "Sum", {"Weight",weight})
			TOTVEHNOXS = VectorStatistic(VEHNOXS   , "Sum", {"Weight",weight})
			TOTVEHPMR  = VectorStatistic(VEHPM10R  , "Sum", {"Weight",weight})
			TOTVEHPMS = VectorStatistic(VEHPM10S, "Sum", {"Weight",weight})
			TOTVEHPM25R = VectorStatistic(VEHPM25R, "Sum", {"Weight",weight})
			TOTVEHPM25S = VectorStatistic(VEHPM25S, "Sum", {"Weight",weight})
			TOTVEHSOXR = VectorStatistic(VEHSOXR   , "Sum", {"Weight",weight})
			TOTVEHSOXS = VectorStatistic(VEHSOXS   , "Sum", {"Weight",weight})
			TOTVEHVOCR = VectorStatistic(VEHVOCR   , "Sum", {"Weight",weight})
			TOTVEHVOCS = VectorStatistic(VEHVOCS   , "Sum", {"Weight",weight})
			TOTTRKCOR  = VectorStatistic(TRKCOR    , "Sum", {"Weight",weight})
			TOTTRKCOS  = VectorStatistic(TRKCOS    , "Sum", {"Weight",weight})
			TOTTRKCO2R = VectorStatistic(TRKCO2R   , "Sum", {"Weight",weight})
			TOTTRKCO2S = VectorStatistic(TRKCO2S   , "Sum", {"Weight",weight}) 
			TOTTRKNOXR = VectorStatistic(TRKNOXR   , "Sum", {"Weight",weight})
			TOTTRKNOXS = VectorStatistic(TRKNOXS   , "Sum", {"Weight",weight})
			TOTTRKPMR  = VectorStatistic(TRKPM10R  , "Sum", {"Weight",weight})
			TOTTRKPMS = VectorStatistic(TRKPM10S, "Sum", {"Weight",weight})
			TOTTRKPM25R = VectorStatistic(TRKPM25R, "Sum", {"Weight",weight})
			TOTTRKPM25S = VectorStatistic(TRKPM25S, "Sum", {"Weight",weight})
			TOTTRKSOXR = VectorStatistic(TRKSOXR   , "Sum", {"Weight",weight})
			TOTTRKSOXS = VectorStatistic(TRKSOXS   , "Sum", {"Weight",weight})
			TOTTRKVOCR = VectorStatistic(TRKVOCR   , "Sum", {"Weight",weight})
			TOTTRKVOCS = VectorStatistic(TRKVOCS   , "Sum", {"Weight",weight}) 
			TOTSUTRKCOR  = VectorStatistic(SUTRKCOR    , "Sum", {"Weight",weight})
			TOTSUTRKCOS  = VectorStatistic(SUTRKCOS    , "Sum", {"Weight",weight})
			TOTSUTRKCO2R = VectorStatistic(SUTRKCO2R   , "Sum", {"Weight",weight})
			TOTSUTRKCO2S = VectorStatistic(SUTRKCO2S   , "Sum", {"Weight",weight}) 
			TOTSUTRKNOXR = VectorStatistic(SUTRKNOXR   , "Sum", {"Weight",weight})
			TOTSUTRKNOXS = VectorStatistic(SUTRKNOXS   , "Sum", {"Weight",weight})
			TOTSUTRKPMR  = VectorStatistic(SUTRKPM10R  , "Sum", {"Weight",weight})
			TOTSUTRKPMS = VectorStatistic(SUTRKPM10S, "Sum", {"Weight",weight})
			TOTSUTRKPM25R = VectorStatistic(SUTRKPM25R, "Sum", {"Weight",weight})
			TOTSUTRKPM25S = VectorStatistic(SUTRKPM25S, "Sum", {"Weight",weight})
			TOTSUTRKSOXR = VectorStatistic(SUTRKSOXR   , "Sum", {"Weight",weight})
			TOTSUTRKSOXS = VectorStatistic(SUTRKSOXS   , "Sum", {"Weight",weight})
			TOTSUTRKVOCR = VectorStatistic(SUTRKVOCR   , "Sum", {"Weight",weight})
			TOTSUTRKVOCS = VectorStatistic(SUTRKVOCS   , "Sum", {"Weight",weight}) 
			TOTMUTRKCOR = VectorStatistic(MUTRKCOR, "Sum", {"Weight",weight})
			TOTMUTRKCOS = VectorStatistic(MUTRKCOS, "Sum", {"Weight",weight})
			TOTMUTRKCO2R = VectorStatistic(MUTRKCO2R, "Sum", {"Weight",weight})
			TOTMUTRKCO2S = VectorStatistic(MUTRKCO2S, "Sum", {"Weight",weight})	
			TOTMUTRKNOXR = VectorStatistic(MUTRKNOXR, "Sum", {"Weight",weight})
			TOTMUTRKNOXS = VectorStatistic(MUTRKNOXS, "Sum", {"Weight",weight})
			TOTMUTRKPMR = VectorStatistic(MUTRKPM10R, "Sum", {"Weight",weight})
			TOTMUTRKPMS = VectorStatistic(MUTRKPM10S, "Sum", {"Weight",weight})
			TOTMUTRKPM25R = VectorStatistic(MUTRKPM25R, "Sum", {"Weight",weight})
			TOTMUTRKPM25S = VectorStatistic(MUTRKPM25S, "Sum", {"Weight",weight})
			TOTMUTRKSOXR = VectorStatistic(MUTRKSOXR, "Sum", {"Weight",weight})
			TOTMUTRKSOXS = VectorStatistic(MUTRKSOXS, "Sum", {"Weight",weight})
			TOTMUTRKVOCR = VectorStatistic(MUTRKVOCR, "Sum", {"Weight",weight})
			TOTMUTRKVOCS = VectorStatistic(MUTRKVOCS, "Sum", {"Weight",weight})				
		
		//if NumObs = 0 then {VC,RM,TOTVMT,TOTVHT,TOTDELAY,VMTAUTO,VMTTRK,VHTAUTO,VHTTRK,VEHFUEL,TRKFUEL,VEHNFUEL,TRKNFUE,TOTFATAL,TOTINJURY,TOTPDO,TOTACCI,TOTFATALC,TOTINJURYC,TOTPDOC,TOTACCIC,TOTVEHCOR,TOTVEHCOS,TOTVEHCO2R,TOTVEHCO2S,TOTVEHNOXR,TOTVEHNOXS,TOTVEHPMR,TOTVEHPMS,TOTVEHSOXR,TOTVEHSOXS,TOTVEHVOCR,TOTVEHVOCS,TOTTRKCOR,TOTTRKCOS,TOTTRKCO2R,TOTTRKCO2S,TOTTRKNOXR,TOTTRKNOXS,TOTTRKPMR,TOTTRKPMS,TOTTRKSOXR,TOTTRKSOXS,TOTTRKVOCR,TOTTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if NumObs = 0 then {VC,RM,TOTVMT,TOTVHT,TOTDELAY,VMTAUTO,VMTTRK,VHTAUTO,VHTTRK,VEHFUEL,TRKFUEL,VEHNFUEL,TRKNFUE,TOTFATAL,TOTINJURY,TOTPDO,TOTACCI,TOTVEHCOR,TOTVEHCOS,TOTVEHCO2R,TOTVEHCO2S,TOTVEHNOXR,TOTVEHNOXS,TOTVEHPMR,TOTVEHPMS,TOTVEHPM25R,TOTVEHPM25S,TOTVEHSOXR,TOTVEHSOXS,TOTVEHVOCR,TOTVEHVOCS,TOTTRKCOR,TOTTRKCOS,TOTTRKCO2R,TOTTRKCO2S,TOTTRKNOXR,TOTTRKNOXS,TOTTRKPMR,TOTTRKPMS,TOTTRKPM25R,TOTTRKPM25S,TOTTRKSOXR,TOTTRKSOXS,TOTTRKVOCR,TOTTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if NumObs = 0 then {VMTSUTRK,VHTSUTRK,SUTRKFUEL,SUTRKNFUE,TOTSUTRKCOR,TOTSUTRKCOS,TOTSUTRKCO2R,TOTSUTRKCO2S,TOTSUTRKNOXR,TOTSUTRKNOXS,TOTSUTRKPMR,TOTSUTRKPMS,TOTSUTRKPM25R,TOTSUTRKPM25S,TOTSUTRKSOXR,TOTSUTRKSOXS,TOTSUTRKVOCR,TOTSUTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if NumObs = 0 then {VMTMUTRK,VHTMUTRK,MUTRKFUEL,MUTRKNFUE,TOTMUTRKCOR,TOTMUTRKCOS,TOTMUTRKCO2R,TOTMUTRKCO2S,TOTMUTRKNOXR,TOTMUTRKNOXS,TOTMUTRKPMR,TOTMUTRKPMS,TOTMUTRKPM25R,TOTMUTRKPM25S,TOTMUTRKSOXR,TOTMUTRKSOXS,TOTMUTRKVOCR,TOTMUTRKVOCS} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		
		// These were not zeroed out - SB
		if NumObs = 0 then {AUTODELAY,TRKDELAY,SUTRKDELAY,MUTRKDELAY} = {0,0,0,0}
		
		AddRecord(outview,{
		{"Item"      ,uniques[i]},{"NumObs"    ,NumObs}    ,{"VC"        ,VC}      ,{"RDMILES"   ,RM}      ,{"VMT",TOTVMT},{"VHT",TOTVHT},{"AUTO_DELAY",AUTODELAY},{"TRK_DELAY",TRKDELAY},
		
		{"SUT_DELAY",SUTRKDELAY},{"MUT_DELAY",MUTRKDELAY},
		
		{"VMT_AUTO"  ,VMTAUTO},{"VMT_TRK"   ,VMTTRK},
		
		{"VMT_SUTRK",VMTSUTRK},{"VMT_MUTRK",VMTMUTRK},
		
		{"VHT_AUTO"  ,VHTAUTO},{"VHT_TRK"   ,VHTTRK},
		
		{"VHT_SUTRK",VHTSUTRK},{"VHT_MUTRK",VHTMUTRK},
		
		{"TOTVEHFUEL",VEHFUEL},{"TOTTRKFUEL",TRKFUEL},
		
		{"TOTSUTFUEL",SUTRKFUEL},{"TOTMUTFUEL",MUTRKFUEL},
		
		{"TOTVEHNFUE",VEHNFUEL},{"TOTTRKNFUE",TRKNFUE},
		
		{"TOTSUTNFUE",SUTRKNFUE},{"TOTMUTNFUE",MUTRKNFUE},
		
		{"fatal"     ,TOTFATAL}  ,{"Injury"    ,TOTINJURY} ,{"PDO"       ,TOTPDO}  ,{"accident"  ,TOTACCI} ,
		//{"fatalC"    ,TOTFATALC} ,{"InjuryC"   ,TOTINJURYC},{"PDOC"      ,TOTPDOC} ,{"accidentC" ,TOTACCIC},
		{"VEHCOR"    ,TOTVEHCOR} ,{"VEHCOS"    ,TOTVEHCOS} ,
		{"VEHCO2R"   ,TOTVEHCO2R},{"VEHCO2S"   ,TOTVEHCO2S},
		{"VEHNOXR"   ,TOTVEHNOXR},{"VEHNOXS"   ,TOTVEHNOXS},
		{"VEHPM10R"  ,TOTVEHPMR} ,{"VEHPM10S"  ,TOTVEHPMS} ,
		{"VEHPM25R" ,TOTVEHPM25R},{"VEHPM25S"	,TOTVEHPM25S},
		{"VEHSOXR"   ,TOTVEHSOXR},{"VEHSOXS"   ,TOTVEHSOXS}, 
		{"VEHVOCR"   ,TOTVEHVOCR},{"VEHVOCS"   ,TOTVEHVOCS},
		{"TRKCOR"    ,TOTTRKCOR} ,{"TRKCOS"    ,TOTTRKCOS} ,
		{"TRKCO2R"   ,TOTTRKCO2R},{"TRKCO2S"   ,TOTTRKCO2S},
		{"TRKNOXR"   ,TOTTRKNOXR},{"TRKNOXS"   ,TOTTRKNOXS},
		{"TRKPM10R"  ,TOTTRKPMR} ,{"TRKPM10S"  ,TOTTRKPMS} ,
		{"TRKPM25R"	,TOTTRKPM25R},{"TRKPM25S"	,TOTTRKPM25S},
		{"TRKSOXR"   ,TOTTRKSOXR},{"TRKSOXS"   ,TOTTRKSOXS}, 
		{"TRKVOCR"   ,TOTTRKVOCR},{"TRKVOCS"   ,TOTTRKVOCS},
		
		{"SUTRKCOR",TOTSUTRKCOR},  {"SUTRKCOS",TOTSUTRKCOS},
		{"SUTRKCO2R",TOTSUTRKCO2R},{"SUTRKCO2S",TOTSUTRKCO2S},
		{"SUTRKNOXR",TOTSUTRKNOXR},{"SUTRKNOXS",TOTSUTRKNOXS},
		{"SUTRKPM10R",TOTSUTRKPMR},{"SUTRKPM10S",TOTSUTRKPMS},
		{"SUTRKPM25R",TOTSUTRKPM25R},{"SUTRKPM25S",TOTSUTRKPM25S},
		{"SUTRKSOXR",TOTSUTRKSOXR},{"SUTRKSOXS",TOTSUTRKSOXS}, 
		{"SUTRKVOCR",TOTSUTRKVOCR},{"SUTRKVOCS",TOTSUTRKVOCS},
		
		{"MUTRKCOR",TOTMUTRKCOR},  {"MUTRKCOS",TOTMUTRKCOS},
		{"MUTRKCO2R",TOTMUTRKCO2R},{"MUTRKCO2S",TOTMUTRKCO2S},
		{"MUTRKNOXR",TOTMUTRKNOXR},{"MUTRKNOXS",TOTMUTRKNOXS},
		{"MUTRKPM10R",TOTMUTRKPMR},{"MUTRKPM10S",TOTMUTRKPMS},
		{"MUTRKPM25R",TOTMUTRKPM25R},{"MUTRKPM25S",TOTMUTRKPM25S},
		{"MUTRKSOXR",TOTMUTRKSOXR},{"MUTRKSOXS",TOTMUTRKSOXS}, 
		{"MUTRKVOCR",TOTMUTRKVOCR},{"MUTRKVOCS",TOTMUTRKVOCS}})
		
		end   
	end

CloseView(jnvw)
CloseView(outlinkvw)

//Add information from TAZ view
	// Export total population and household information
	SetView(tazvw)
	n = SelectByQuery("all", "Several", "Select * where STATEID <> null",)
	{TAZID, COUNTYID, TOTPOP, HH} = GetDataVectors(tazvw+"|all", {"TAZID", "COUNTYID", "TOTPOP", "HH"},{{"Sort Order",{{tazvw+".ID","Ascending"}}}})
	POP = VectorStatistic(TOTPOP, "Sum", )
	HHs = VectorStatistic(HH, "Sum", )
	
	AddRecord(outview,{{"Item","Total Population"},{"NumObs",POP}})
	AddRecord(outview,{{"Item","Total Households"},{"NumObs",HHs}})
	
ExportView(outview+"|", "CSV", reppath+"post_report.csv", null, {{"CSV Drop Quotes", "True"},{"CSV Header", "True"}})
CloseView(outview)
endMacro


//MOVES Processor
/*
Prepare 7 MOVES inputs for DaySim model
1. Fraction of VMT within County
2. Road Type Distribution (roadTypeDistribution)
3. Growth by SourceType (sourceTypeYear)
4. Hourly Vehicle Type VMT (hourVMTFraction)
5. Avg Speed Distribution (avgSpeedDistribution)
6. Ramp VMT Fractions
7. HPMS Annual VMT (HPMSVTypeYear)

Sample files at http://www.chcrpa.org/TPO_reorganized/Air_Quality_and_Congestion_Mgmt/IAC/MOVES_Input_Files-listed.htm
*/

Macro "Post_MOVES" (modeldir, scendir, tazvw, linevw, yearid, tripmtx)
shared logfile
//VehOcc from Chatt Model is {SOV, HOV2, HOV3Plus} = {1, 2, 3.5}
//User Select
/*
yearid =  2020
modeldir = "E:\\Model\\1_Model-Files\\"
scendir = "E:\\Model\\2_Scenarios\\2020_45ECX\\"

tazfile =  scendir + "Outputs\\1_TAZ\\CHCRPA_TAZ_2020.dbd"
linefile = scendir + "Outputs\\2_Networks\\Network_2020_45EC.dbd"
tazvw   = RunMacro("AddLayer", tazfile, "Area")
linevw   = RunMacro("AddLayer", linefile, "Line")

tripdir = scendir + "Outputs\\6_TripTables\\"
tripmtx = tripdir + "TripTable_I1.mtx"
*/

linefile = GetLayerDB(linevw)
tazcntyfile   = modeldir + "\\8_Other\\TAZ_County_Lookup.dbf"
hvf_base      = modeldir + "\\8_Other\\hourVMTFraction.csv"
asd_base      = modeldir + "\\8_Other\\avgSpeedDistribution.csv"
//truckmtx_base = modeldir + "\\4_Pivot\\Trk_Seed.mtx"

dsdir = scendir + "\\Outputs\\3_DaySim\\"
	dshh = dsdir + "_household_2.dat"
	dstrips = dsdir + "_trip_2.dat"

movesdir = scendir + "\\Outputs\\7_Reports\\MOVES\\"
	csvhh = movesdir + "household.csv"
	csvtrips = movesdir + "trips.csv"
	mv_aut = movesdir + "MOVES_AUTO.DBF"
	mv_sut = movesdir + "MOVES_SUT.DBF"
	mv_mut = movesdir + "MOVES_MUT.DBF"
	mv_spd = movesdir + "MOVES_SPDBIN.DBF"

ftcvmtx = scendir + "\\Outputs\\4_TruckDemand\\CV_OD.mtx"
truckmtx = scendir + "\\Outputs\\4_TruckDemand\\Truck_OD.mtx"

//Outputs
netout      = movesdir + "MOVES.net"
skimmtx     = movesdir + "MOVES_Skim.mtx"
cntytripmtx = movesdir + "County_Trips.mtx"
hrtripmtx   = movesdir + "Hourly_Trips.mtx"
vmttripmtx  = movesdir + "VMT_Trips.mtx"
logfile     = movesdir + "Log.txt"

//Initialize
status = RunProgram("cmd /c ECHO F|xcopy "+dstrips+" "+csvtrips+" /R /Y",) 
status = RunProgram("cmd /c ECHO F|xcopy "+dshh+" "+csvhh+" /R /Y",) 


//Get model population
SetView(tazvw)
qcnty = "Select * where COUNTYID = 65"
cnty = SelectByQuery("cnty", "Several", qcnty, )

{vpop} = GetDataVectors(tazvw+"|cnty", {"TOTPOP"},)
modpop = VectorStatistic(vpop, "Sum",) //modpop[2020] = 359434
basepop = 340960 //Hamilton County [Model Total: 445799]
popgrowth = max(modpop/basepop,1)

//RunMacro("AddIntExt", tazcntyfile, truckmtx_base)
RunMacro("AddIntExt", tazcntyfile, tripmtx) //Add Internal & External index
RunMacro("SimpleNet", linefile, linevw, netout) //Create simple .net file
RunMacro("SkimCounty", linefile, linevw, netout, skimmtx) //Generate Skims by CountyMiles (miles within Hamilton County) & RoadType
RunMacro("AddIntExt", tazcntyfile, skimmtx) //Add Internal & External index
RunMacro("DaySimTripList", csvhh, csvtrips, tazcntyfile, cntytripmtx, hrtripmtx, vmttripmtx) //DaySimTripList - parse down to needed information

cvmt_out = movesdir + "M01_CountyVMT.txt"
rtd_out = movesdir + "M02_RoadTypeDistribution.txt"
sty_out = movesdir + "M03_SourceTypeYear.txt"
hvf_out = movesdir + "M04_hourVMTFraction.csv"
asd_out = movesdir + "M05_avgSpeedDistribution.csv"
ramp_out = movesdir + "M06_rampfraction.txt"
hvty_out = movesdir + "M07_HPMSVTypeYear.txt"


RunMacro("County_VMT", cntytripmtx, tripmtx, skimmtx, cvmt_out)
RunMacro("roadTypeDistribution", mv_aut, mv_sut, mv_mut, rtd_out)
RunMacro("sourceTypeYear", csvhh, tazcntyfile, ftcvmtx, truckmtx, yearid, popgrowth, sty_out)
RunMacro("hourVMTFraction", tazcntyfile, hrtripmtx, vmttripmtx, skimmtx, hvf_base, hvf_out)
RunMacro("avgSpeedDist", mv_aut, mv_sut, mv_mut, mv_spd, asd_base, asd_out)
RunMacro("rampfraction", mv_aut, mv_sut, mv_mut, ramp_out)
RunMacro("HPMSVTypeYear", mv_aut, mv_sut, mv_mut, yearid, popgrowth, hvty_out)
endMacro

//Utilities
Macro "AddIntExt" (tazcntyfile, mtxfile)
tazcntyvw = OpenTable("tazcnty", "DBASE", {tazcntyfile, })
mat = OpenMatrix(mtxfile, "Auto")

RunMacro("CheckMatrixIndex", mat, "Internal", "Internal", tazcntyvw, "Select * where EXTERNAL = null", "TAZID", "TAZID")
RunMacro("CheckMatrixIndex", mat, "External", "External", tazcntyvw, "Select * where EXTERNAL = 1", "TAZID", "TAZID")
CloseView(tazcntyvw)
endMacro

Macro "DaySimTripList" (csvhh, csvtrips, tazcntyfile, cntytripmtx, hrtripmtx, vmttripmtx)
hhvw = OpenTable("hhvw", "CSV", {csvhh})
tazcntyvw = OpenTable("tazcnty", "DBASE", {tazcntyfile, })
tripvw = OpenTable("tripvw", "CSV", {csvtrips})

//Join Trips + HH + tazcnty
triphhvw = JoinViews(tripvw+"+"+hhvw, tripvw+".hhno", hhvw+".hhno", )
thcvw = JoinViews(triphhvw+"+"+tazcntyvw, triphhvw+".hhtaz", tazcntyvw+".TAZID", )

//Create Trip Matrix - modified "daysim_output" macro
	//PCE trips
	tripPCE = CreateExpression(thcvw, "tripPCE", "if MODE = 3 then TREXPFAC*1 else if MODE = 4 then TREXPFAC*1/2  else if MODE = 5 then TREXPFAC*1/3.5  else if MODE = 6 then TREXPFAC*1 else 1*TREXPFAC", {"Integer", 1, 0})

	//Time of day
	trtime = CreateExpression(thcvw, "trtime", "if (HALF = 1) then ARRTM else DEPTM", {"Integer", 4, 0})
	//rsgtod = CreateExpression(thcvw, "rsgtod", "if trtime >= 0 and trtime < 360 then 3 else if trtime >= 360 and trtime < 540 then 1 else if trtime >= 540 and trtime < 900 then 3 else if trtime >= 900 and trtime < 1080 then 2 else if trtime >= 1080 and trtime <= 1440 then 3" , {"Integer", 1, 0}) 

	{oTAZ, dTAZ} = {"otaz", "dtaz"} //DaySim O/D TAZ fields
	
//COUNTY TRIPS
	dim tripnames[4]
	tripnames = {"Pass_65", "Pass_47", "Pass_295", "Pass_83"} 

	core01 = "if COUNTYID = 65 and (MODE = 3 or MODE = 4 or MODE = 5) then 'Pass_65'"
	core02 = " else if COUNTYID = 47 and (MODE = 3 or MODE = 4 or MODE = 5) then 'Pass_47'"
	core03 = " else if COUNTYID = 295 and (MODE = 3 or MODE = 4 or MODE = 5) then 'Pass_295'"
	core04 = " else if COUNTYID = 83 and (MODE = 3 or MODE = 4 or MODE = 5) then 'Pass_83'"
	corestr = core01 + core02 + core03 + core04
	core_fld = CreateExpression(thcvw, "core_fld", corestr, {"String", 10, 0}) 
	
	//Create OD matrix & fill 0s
	triptable = CreateMatrix({tazcntyvw+"|",tazcntyvw+".TAZID", "Origin"},{tazcntyvw+"|",tazcntyvw+".TAZID", "Destination"}, {{"File Name", cntytripmtx}, {"Label", "DaySim_Trips"},{"Tables", tripnames} })
	tripmc = CreateMatrixCurrencies(triptable, null, null, null)
	for ft = 1 to tripmc.length do FillMatrix(tripmc[ft][2], null, null, {"Copy", 0}, ) end
	
	//Match field to matrix core (core_fld) & fill values (tripPCE) ; Matrix Made Easy!
	//SOV
	SetView(thcvw)
	numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 3)", )
	UpdateMatrixFromView(triptable, thcvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})

	//HOV2
	numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 4)", )
	UpdateMatrixFromView(triptable, thcvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})
	
	//HOV3+
	numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 5)", )
	UpdateMatrixFromView(triptable, thcvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})
	DeleteSet("sel")

//HOURLY TRIPS
	dim hrnames[25]
	hrnames = {"hr01","hr02","hr03","hr04","hr05","hr06","hr07","hr08","hr09","hr10","hr11","hr12","hr13","hr14","hr15","hr16","hr17","hr18","hr19","hr20","hr21","hr22","hr23","hr24","total"}
	
	hr01 = 	"if trtime >= 0 and trtime < 60 then 'hr01'"
	hr02 = 	"else if trtime >= 60   and trtime < 120  then 'hr02'"
	hr03 = 	"else if trtime >= 120  and trtime < 180  then 'hr03'"
	hr04 =  "else if trtime >= 180  and trtime < 240  then 'hr04'"
	hr05 =  "else if trtime >= 240  and trtime < 300  then 'hr05'"
	hr06 =  "else if trtime >= 300  and trtime < 360  then 'hr06'"
	hr07 =  "else if trtime >= 360  and trtime < 420  then 'hr07'"
	hr08 =  "else if trtime >= 420  and trtime < 480  then 'hr08'"
	hr09 =  "else if trtime >= 480  and trtime < 540  then 'hr09'"
	hr10 =  "else if trtime >= 540  and trtime < 600  then 'hr10'"
	hr11 =  "else if trtime >= 600  and trtime < 660  then 'hr11'"
	hr12 =  "else if trtime >= 660  and trtime < 720  then 'hr12'"
	hr13 =  "else if trtime >= 720  and trtime < 780  then 'hr13'"
	hr14 =  "else if trtime >= 780  and trtime < 840  then 'hr14'"
	hr15 =  "else if trtime >= 840  and trtime < 900  then 'hr15'"
	hr16 =  "else if trtime >= 900  and trtime < 960  then 'hr16'"
	hr17 =  "else if trtime >= 960  and trtime < 1020 then 'hr17'"
	hr18 =  "else if trtime >= 1020 and trtime < 1080 then 'hr18'"
	hr19 =  "else if trtime >= 1080 and trtime < 1140 then 'hr19'"
	hr20 =  "else if trtime >= 1140 and trtime < 1200 then 'hr20'"
	hr21 =  "else if trtime >= 1200 and trtime < 1260 then 'hr21'"
	hr22 =  "else if trtime >= 1260 and trtime < 1320 then 'hr22'"
	hr23 =  "else if trtime >= 1320 and trtime < 1380 then 'hr23'"
	hr24 =  "else if trtime >= 1380 and trtime < 1440 then 'hr24'"

	hrstr = hr01 + hr02 + hr03 + hr04 + hr05 + hr06 + hr07 + hr08 + hr09 + hr10 + hr11 + hr12 + hr13 + hr14 + hr15 + hr16 + hr17 + hr18 + hr19 + hr20 + hr21 + hr22 + hr23 + hr24
	hr_fld = CreateExpression(thcvw, "hr_fld", hrstr, {"String", 10, 0}) 

		//Create OD matrix & fill 0s
		triptable = CreateMatrix({tazcntyvw+"|",tazcntyvw+".TAZID", "Origin"},{tazcntyvw+"|",tazcntyvw+".TAZID", "Destination"}, {{"File Name", hrtripmtx}, {"Label", "Hourly_Trips"},{"Tables", hrnames} })
		tripmc = CreateMatrixCurrencies(triptable, null, null, null)
		for ft = 1 to tripmc.length do FillMatrix(tripmc[ft][2], null, null, {"Copy", 0}, ) end
		
		//Match field to matrix core (hr_fld) & fill values (tripPCE) ; Matrix Made Easy!
		//SOV
		SetView(thcvw)
		numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 3)", )
		UpdateMatrixFromView(triptable, thcvw+"|sel", oTAZ, dTAZ, "hr_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})

		//HOV2
		numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 4)", )
		UpdateMatrixFromView(triptable, thcvw+"|sel", oTAZ, dTAZ, "hr_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})
		
		//HOV3+
		numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 5)", )
		UpdateMatrixFromView(triptable, thcvw+"|sel", oTAZ, dTAZ, "hr_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})
		DeleteSet("sel")
		
	tripmc.total := tripmc.hr01 + tripmc.hr02 + tripmc.hr03 + tripmc.hr04 + tripmc.hr05 + tripmc.hr06 + tripmc.hr07 + tripmc.hr08 + tripmc.hr09 + tripmc.hr10 + tripmc.hr11 + tripmc.hr12 + tripmc.hr13 + tripmc.hr14 + tripmc.hr15 + tripmc.hr16 + tripmc.hr17 + tripmc.hr18 + tripmc.hr19 + tripmc.hr20 + tripmc.hr21 + tripmc.hr22 + tripmc.hr23 + tripmc.hr24
	arr = GetExpressions(thcvw)
	for i = 1 to arr.length do DestroyExpression(thcvw+"."+arr[i]) end
	
//VMT TABLE (empty)
dim vmtnames[4]
	vmtnames = {"RTVMT02", "RTVMT03", "RTVMT04", "RTVMT05", "total"}
		triptable = CreateMatrix({tazcntyvw+"|",tazcntyvw+".TAZID", "Origin"},{tazcntyvw+"|",tazcntyvw+".TAZID", "Destination"}, {{"File Name", vmttripmtx}, {"Label", "VMT"},{"Tables", vmtnames} })
		tripmc = CreateMatrixCurrencies(triptable, null, null, null)
		for ft = 1 to tripmc.length do FillMatrix(tripmc[ft][2], null, null, {"Copy", 0}, ) end	

CloseView(thcvw)
CloseView(triphhvw)
CloseView(tripvw)
CloseView(tazcntyvw)
CloseView(hhvw)
endMacro

Macro "SkimCounty" (linefile, linevw, netfile, skimmtx)	
//Custom Length within County
SetView(linevw)
nodevw   = GetNodeLayer(linevw)
RunMacro("addfields", linevw, {"RoadType", "CntyLng", "RT2Leng", "RT3Leng", "RT4Leng", "RT5Leng"}, "r")
{FC, Ramp, AT, Access} = GetDataVectors(linevw+"|", {"FUNCCLASS","RAMP","AREA_TYPE","ACCESS"}, {{"Sort Order",{{linevw+".ID","Ascending"}}},{"Missing as Zero", "True"}})

MV_RoadType = if Ramp > 0 and (AT < 4) then 4 // Urban Restricted (ramps)
		else if Ramp > 0 and (AT = 4 or AT = null) then 2   //Rural Restricted (ramps) 
		else if FC = 1  then 2                            //Rural restricted (interstate)
        else if FC > 1  and FC <= 9 and Access= 3 then 2  //Rural restricted  (non interstate)
		else if FC > 1 and FC <= 9 and Access<>3 then 3  //Rural Unrestricted (non interstate)
		else if FC = 11  then 4                             //Urban restricted  (interstate)
        else if FC > 11  and FC <=19 and Access= 3 then 4  //Urban restricted  (non interstate) 
        else if FC > 11  and FC <=19 and Access<>3 then 5 //Uural unrestricted  (non interstate)

SetDataVectors(linevw+"|", {{"RoadType", MV_RoadType}}, {{"Sort Order",{{"ID","Ascending"}}}})

//n = SelectByQuery("Selection", "Several", "Select * where COUNTYID = 65",)
LengEx = CreateExpression(linevw, "LengEx", "if COUNTYID = 65 then Length else 0", )
LengRT2 = CreateExpression(linevw, "RT2", "if (RoadType = 2 and COUNTYID = 65) then Length else 0", )
LengRT3 = CreateExpression(linevw, "RT3", "if (RoadType = 3 and COUNTYID = 65) then Length else 0", )
LengRT4 = CreateExpression(linevw, "RT4", "if (RoadType = 4 and COUNTYID = 65) then Length else 0", )
LengRT5 = CreateExpression(linevw, "RT5", "if (RoadType = 5 and COUNTYID = 65) then Length else 0", )
SetRecordsValues(linevw+"|", {{"CntyLng","RT2Leng","RT3Leng","RT4Leng","RT5Leng"}, null}, "Formula", {LengEx, LengRT2, LengRT3, LengRT4, LengRT5},)
//SetRecordsValues(null, {{"Basic_Emp","Indust_Emp","Retail_Emp","FoodLd_Emp","ProSrv_Emp","OthSrv_Emp"}, null}, "Formula", {"BAS","IND","RET","FDL","PRO","OSV"}, null)

arr = GetExpressions(linevw)
for i = 1 to arr.length do DestroyExpression(linevw+"."+arr[i]) end
	
//Update .net
    RunMacro("TCB Init")
    Opts = null
    Opts.Input.Network = netfile
    Opts.Input.Database = linefile
    Opts.Input.[Update Link Source Sets] = {{linefile+"|"+linevw, linevw}}
	Opts.Global.[Update Network Fields].Links.gctta  = {linevw+".AB_GCTTA"  , linevw+".BA_GCTTA"  ,,, "True"}
	Opts.Global.[Update Network Fields].Links.CntyLng = {linevw+".CntyLng"    , linevw+".CntyLng"    ,,, "False"}
	Opts.Global.[Update Network Fields].Links.RT2Leng = {linevw+".RT2Leng"    , linevw+".RT2Leng"    ,,, "False"}
	Opts.Global.[Update Network Fields].Links.RT3Leng = {linevw+".RT3Leng"    , linevw+".RT3Leng"    ,,, "False"}
	Opts.Global.[Update Network Fields].Links.RT4Leng = {linevw+".RT4Leng"    , linevw+".RT4Leng"    ,,, "False"}
	Opts.Global.[Update Network Fields].Links.RT5Leng = {linevw+".RT5Leng"    , linevw+".RT5Leng"    ,,, "False"}
	//Opts.Global.[Update Network Fields].Links.TCs    = {linevw+".AB_TCS"    , linevw+".BA_TCS"    ,,, "False"}
	//Opts.Global.[Update Network Fields].Links.TCm    = {linevw+".AB_TCM"    , linevw+".BA_TCM"    ,,, "False"}
	//Opts.Global.[Update Network Fields].Links.FTBa   = {linevw+".AB_FTB_A"  , linevw+".BA_FTB_A"  ,,, "False"}
	Opts.Global.[Update Network Fields].Formulas = {}
	
    Opts.Global.[Link to Link Penalty Method] = "Table"
    ok = RunMacro("TCB Run Operation", "Network Settings", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )

//Skim over CntyLng (minimize gctta)
	skimx = null
	skimx.net                  = netfile
	skimx.origin               = {linefile+"|"+nodevw, nodevw, "Selection", "Select * where Centroid = 1"}
	skimx.destination          = {linefile+"|"+nodevw, nodevw, "Selection", "Select * where Centroid = 1"}
	skimx.set                  = {linefile+"|"+nodevw, nodevw}
	skimx.min                  = "gctta"
	skimx.nodes                = nodevw+".ID"
	skimx.flds                 = {{"Length","All"}, {"CntyLng","All"}, {"RT2Leng","All"}, {"RT3Leng","All"}, {"RT4Leng","All"}, {"RT5Leng","All"}}
	skimx.out                  = skimmtx
	skimx.Centroid_ID_is_TAZID = 0 //[1(centroid ID matches TAZID); 0(TAZID as node field)]
	skimx.Centroid_TAZID_fld   = "TAZID"

	RunMacro("skim", skimx)
	
endMacro

Macro "SimpleNet" (linefile, linevw, netfile)
RunMacro("TCB Init")
    Opts = null
	Opts.Input.[Link Set] = {linefile+"|"+linevw, linevw, "Modeled", "Select * where IN_HIGHWAY = 1"}
    Opts.Global.[Network Options].[Turn Penalties] = "Yes"
    Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
    Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
    Opts.Global.[Network Options].[Time Units] = "Minutes"
	Opts.Global.[Length Units] = "Miles"
	Opts.Global.[Link Options].Length = {linevw+".Length"    , linevw+".Length"    ,,, "False"}
	Opts.Output.[Network File] = netfile
	
	//Build Highway Network with above parameters
    ok = RunMacro("TCB Run Operation", "Build Highway Network", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )
endMacro


//01: County VMT with Origins in County
Macro "County_VMT" (cntytripmtx, tripmtx, skimmtx, cvmt_out)
RunMacro("MOVES_Log", "County VMT")
skimmat = OpenMatrix(skimmtx, "Auto")
mccntyleng = RunMacro("CheckMatrixCore", skimmat, "CntyLng (Skim)", , )
mccntyleng_ii = RunMacro("CheckMatrixCore", skimmat, "CntyLng (Skim)", "Internal", "Internal")
mccntyleng_ei = RunMacro("CheckMatrixCore", skimmat, "CntyLng (Skim)", "External", "Internal")
mccntyleng_ie = RunMacro("CheckMatrixCore", skimmat, "CntyLng (Skim)", "Internal", "External")

//OUTPUT_01a: Auto_VMT = Trips*CountyMiles/VehOcc
ctmat = OpenMatrix(cntytripmtx, "Auto")
mcptrp = RunMacro("CheckMatrixCore", ctmat, "Pass_65", null, null)
mcpvmt = RunMacro("CheckMatrixCore", ctmat, "VMT", null, null)
mcpvmt := mccntyleng * mcptrp

psgrstat = MatrixStatistics(ctmat, )
psgrvmt = psgrstat.VMT.Sum

//OUTPUT_01b: Truck_VMT = I-I trips + 0.5 (IE+EI) trips
tripmat = OpenMatrix(tripmtx, "Auto")

mcstrp_ii = RunMacro("CheckMatrixCore", tripmat, "SUT", "Internal", "Internal")
mcstrp_ei = RunMacro("CheckMatrixCore", tripmat, "SUT", "External", "Internal")
mcstrp_ie = RunMacro("CheckMatrixCore", tripmat, "SUT", "Internal", "External")
mcsvmt_ii = RunMacro("CheckMatrixCore", tripmat, "SUTVMT", "Internal", "Internal")
mcsvmt_ei = RunMacro("CheckMatrixCore", tripmat, "SUTVMT", "External", "Internal")
mcsvmt_ie = RunMacro("CheckMatrixCore", tripmat, "SUTVMT", "Internal", "External")
mcsvmt_ii := 1.0 * mccntyleng_ii * mcstrp_ii
mcsvmt_ei := 0.5 * mccntyleng_ei * mcstrp_ei
mcsvmt_ie := 0.5 * mccntyleng_ie * mcstrp_ie

mcmtrp_ii = RunMacro("CheckMatrixCore", tripmat, "MUT", "Internal", "Internal")
mcmtrp_ei = RunMacro("CheckMatrixCore", tripmat, "MUT", "External", "Internal")
mcmtrp_ie = RunMacro("CheckMatrixCore", tripmat, "MUT", "Internal", "External")
mcmvmt_ii = RunMacro("CheckMatrixCore", tripmat, "MUTVMT", "Internal", "Internal")
mcmvmt_ei = RunMacro("CheckMatrixCore", tripmat, "MUTVMT", "External", "Internal")
mcmvmt_ie = RunMacro("CheckMatrixCore", tripmat, "MUTVMT", "Internal", "External")
mcmvmt_ii := 1.0 * mccntyleng_ii * mcmtrp_ii
mcmvmt_ei := 0.5 * mccntyleng_ei * mcmtrp_ei
mcmvmt_ie := 0.5 * mccntyleng_ie * mcmtrp_ie

trkstat = MatrixStatistics(tripmat, )
sutvmt = trkstat.SUTVMT.Sum
mutvmt = trkstat.MUTVMT.Sum

//Write Output
ptr = OpenFile(cvmt_out, "w")
ar_log = { "Daily Auto VMT:\t"+ i2s(r2i(psgrvmt)), "Daily SUT VMT:\t "+ i2s(r2i(sutvmt)), "Daily MUT VMT:\t "+ i2s(r2i(mutvmt))}
WriteArray(ptr, ar_log)
CloseFile(ptr) 
endMacro

/*
Autos [11, 21, 31] 
4TCV [32]
SUT [52, 53]
MUT [61, 62]
*/

//02: roadTypeDistribution
Macro "roadTypeDistribution" (mv_aut, mv_sut, mv_mut, rtd_out)
RunMacro("MOVES_Log", "roadTypeDistribution")
//Defaults
rtd11 = {0.00000,0.00000,0.05557,0.28280,0.66163}
rtd21 = {0.00000,0.00000,0.03681,0.35895,0.60424}
rtd31 = {0.00000,0.00000,0.03681,0.35895,0.60424}
rtd32 = {0.00000,0.00000,0.03681,0.35895,0.60424}
rtd41 = {0.00000,0.00000,0.02689,0.75679,0.21632}
rtd42 = {0.00000,0.00000,0.02689,0.75679,0.21632}
rtd43 = {0.00000,0.00000,0.02689,0.75679,0.21632}
rtd51 = {0.00000,0.00000,0.03951,0.48170,0.47878}
rtd52 = {0.00000,0.00000,0.03951,0.48170,0.47878}
rtd53 = {0.00000,0.00000,0.03951,0.48170,0.47878}
rtd54 = {0.00000,0.00000,0.03951,0.48170,0.47878}
rtd61 = {0.00000,0.00000,0.02272,0.71352,0.26376}
rtd62 = {0.00000,0.00000,0.02272,0.71352,0.26376}


autvmt = OpenTable("AutVMT", "DBASE", {mv_aut, })
sutvmt = OpenTable("SUTVMT", "DBASE", {mv_sut, })
mutvmt = OpenTable("MUTVMT", "DBASE", {mv_mut, })

cls = {autvmt, sutvmt, mutvmt}
dim MOVESvmt2[3]
dim MOVESvmt3[3]
dim MOVESvmt4[3]
dim MOVESvmt5[3]
dim MOVESvmtsum[3]

//Sum VMT by Class by RoadType
for i=1 to cls.length do
	SetView(cls[i])
	qRT2 = "Select * where COUNTYID = 65 and ROADTYPE = 2"
	qRT3 = "Select * where COUNTYID = 65 and ROADTYPE = 3"
	qRT4 = "Select * where COUNTYID = 65 and ROADTYPE = 4"
	qRT5 = "Select * where COUNTYID = 65 and ROADTYPE = 5"
	
	set2 = SelectByQuery("set2", "Several", qRT2, )
	set3 = SelectByQuery("set3", "Several", qRT3, )
	set4 = SelectByQuery("set4", "Several", qRT4, )
	set5 = SelectByQuery("set5", "Several", qRT5, )
	
	if set2 > 0 then do
		{VMT_RT2} = GetDataVectors(cls[i]+"|set2", {"TOT_VMT"},)
		MOVESvmt2[i] = VectorStatistic(VMT_RT2, "Sum",)
	end
	
	if set3 > 0 then do
		{VMT_RT3} = GetDataVectors(cls[i]+"|set3", {"TOT_VMT"},)
		MOVESvmt3[i] = VectorStatistic(VMT_RT3, "Sum",)
	end
	
	if set4 > 0 then do
		{VMT_RT4} = GetDataVectors(cls[i]+"|set4", {"TOT_VMT"},)
		MOVESvmt4[i] = VectorStatistic(VMT_RT4, "Sum",)
	end
	
	if set5 > 0 then do
		{VMT_RT5} = GetDataVectors(cls[i]+"|set5", {"TOT_VMT"},)
		MOVESvmt5[i] = VectorStatistic(VMT_RT5, "Sum",)
	end

	
	MOVESvmtsum[i] = nz(MOVESvmt2[i]) + nz(MOVESvmt3[i]) + nz(MOVESvmt4[i]) + nz(MOVESvmt5[i])
	if MOVESvmtsum[i] = 0 then MOVESvmtsum[i] = 1

CloseView(cls[i])
end

//Write Output 
ptr = OpenFile(rtd_out, "w")
ar_log = {	"sourceTypeID	roadTypeID	roadTypeVMTFraction",
		"11	1	"+r2s(rtd11[1]),
		"11	2	"+r2s(MOVESvmt2[1]/MOVESvmtsum[1]),
		"11	3	"+r2s(MOVESvmt3[1]/MOVESvmtsum[1]),
		"11	4	"+r2s(MOVESvmt4[1]/MOVESvmtsum[1]),
		"11	5	"+r2s(MOVESvmt5[1]/MOVESvmtsum[1]),
		
		"21	1	"+r2s(rtd21[1]),
		"21	2	"+r2s(MOVESvmt2[1]/MOVESvmtsum[1]),
		"21	3	"+r2s(MOVESvmt3[1]/MOVESvmtsum[1]),
		"21	4	"+r2s(MOVESvmt4[1]/MOVESvmtsum[1]),
		"21	5	"+r2s(MOVESvmt5[1]/MOVESvmtsum[1]),
		
		"31	1	"+r2s(rtd31[1]),
		"31	2	"+r2s(MOVESvmt2[1]/MOVESvmtsum[1]),
		"31	3	"+r2s(MOVESvmt3[1]/MOVESvmtsum[1]),
		"31	4	"+r2s(MOVESvmt4[1]/MOVESvmtsum[1]),
		"31	5	"+r2s(MOVESvmt5[1]/MOVESvmtsum[1]),
		
		"32	1	"+r2s(rtd32[1]),                              
		"32	2	"+r2s(rtd32[2]),
		"32	3	"+r2s(rtd32[3]),
		"32	4	"+r2s(rtd32[4]),
		"32	5	"+r2s(rtd32[5]),
		
		"41	1	"+r2s(rtd41[1]),                              
		"41	2	"+r2s(rtd41[2]),
		"41	3	"+r2s(rtd41[3]),
		"41	4	"+r2s(rtd41[4]),
		"41	5	"+r2s(rtd41[5]),
		
		"42	1	"+r2s(rtd42[1]),                              
		"42	2	"+r2s(rtd42[2]),
		"42	3	"+r2s(rtd42[3]),
		"42	4	"+r2s(rtd42[4]),
		"42	5	"+r2s(rtd42[5]),
		
		"43	1	"+r2s(rtd43[1]),                              
		"43	2	"+r2s(rtd43[2]),
		"43	3	"+r2s(rtd43[3]),
		"43	4	"+r2s(rtd43[4]),
		"43	5	"+r2s(rtd43[5]),
		
		"51	1	"+r2s(rtd51[1]),                              
		"51	2	"+r2s(rtd51[2]),
		"51	3	"+r2s(rtd51[3]),
		"51	4	"+r2s(rtd51[4]),
		"51	5	"+r2s(rtd51[5]),
		
		"52	1	"+r2s(rtd52[1]),                              
		"52	2	"+r2s(rtd52[2]),
		"52	3	"+r2s(rtd52[3]),
		"52	4	"+r2s(rtd52[4]),
		"52	5	"+r2s(rtd52[5]),
		
		"53	1	"+r2s(rtd53[1]),
		"53	2	"+r2s(rtd53[2]),
		"53	3	"+r2s(rtd53[3]),
		"53	4	"+r2s(rtd53[4]),
		"53	5	"+r2s(rtd53[5]),
		
		"54	1	"+r2s(rtd54[1]),                                
		"54	2	"+r2s(rtd54[2]),
		"54	3	"+r2s(rtd54[3]),
		"54	4	"+r2s(rtd54[4]),
		"54	5	"+r2s(rtd54[5]),
		
		"61	1	"+r2s(rtd61[1]),                                
		"61	2	"+r2s(MOVESvmt2[3]/MOVESvmtsum[3]),
		"61	3	"+r2s(MOVESvmt3[3]/MOVESvmtsum[3]),
		"61	4	"+r2s(MOVESvmt4[3]/MOVESvmtsum[3]),
		"61	5	"+r2s(MOVESvmt5[3]/MOVESvmtsum[3]),
		
		"62	1	"+r2s(rtd62[1]),                                
		"62	2	"+r2s(MOVESvmt2[3]/MOVESvmtsum[3]),
		"62	3	"+r2s(MOVESvmt3[3]/MOVESvmtsum[3]),
		"62	4	"+r2s(MOVESvmt4[3]/MOVESvmtsum[3]),
		"62	5	"+r2s(MOVESvmt5[3]/MOVESvmtsum[3])
		}
WriteArray(ptr, ar_log)
CloseFile(ptr)  	 
endMacro

//03: sourceTypeYear
Macro "sourceTypeYear" (csvhh, tazcntyfile, ftcvmtx, truckmtx, yearid, popgrowth, sty_out)
RunMacro("MOVES_Log", "sourceTypeYear")
//2014 Defaults
bstp11 = 8795
bstp21 = 119783
bstp31 = 101718
bstp32 = 18104
bstp41 = 4
bstp42 = 89
bstp43 = 306
bstp51 = 121
bstp52 = 5532
bstp53 = 185
bstp54 = 1164
bstp61 = 1867
bstp62 = 2022

basevehsum = 278689 //2014 DaySim HHVEHs in Hamilton
baseFTCV = 17166.42 //II Trips
baseSUT = 32758.49   //II Trips   //mod_SUT = 33791.96
baseMUT = 1741.19  //II Trips     //mod_MUT = 1815.03

hhvw = OpenTable("hhvw", "CSV", {csvhh})
tazcntyvw = OpenTable("tazcnty", "DBASE", {tazcntyfile, })

hcvw = JoinViews(hhvw+"+"+tazcntyvw, hhvw+".hhtaz", tazcntyvw+".TAZID", )
SetView(hcvw)
n = SelectByQuery("Selection", "Several", "Select * where COUNTYID = 65",)

//SourceType 11, 21, 31: Growth in DaySim County HH Vehicles
{vehicles} = GetDataVectors(hcvw+"|Selection", {"hhvehs"},)
vehsum = VectorStatistic(vehicles, "Sum", ) //2020 Hamilton vehicles: 295653
PassGrowth = vehsum/basevehsum  //1.06
pop11 = r2i(bstp11*PassGrowth)
pop21 = r2i(bstp21*PassGrowth)
pop31 = r2i(bstp31*PassGrowth)

//SourceType 32: four-tire commercial vehicle I-I trip growth
ftcvmat = OpenMatrix(ftcvmtx, "Auto")
modftcv = MatrixStatistics(ftcvmat, )
FTCVGrowth = modftcv.CV_II.Sum / baseFTCV //2020: 18132.57 (1.056)
pop32 = r2i(bstp32*FTCVGrowth)

pop41 = r2i(bstp41*popgrowth)
pop42 = r2i(bstp42*popgrowth)
pop43 = r2i(bstp43*popgrowth)

//SourceType 51, 52, 61, 62: SUT & MUT I-I trip growth
/*
basetrkmat = OpenMatrix(truckmtx_base, "Auto")
SetMatrixIndex(basetrkmat, "Internal", "Internal")
basetrk = MatrixStatistics(basetrkmat, )
*/

trkmat = OpenMatrix(truckmtx, "Auto")
modtrk = MatrixStatistics(trkmat, )


SUTGrowth = modtrk.II_SUT.Sum/baseSUT 
MUTGrowth = modtrk.II_MUT.Sum/baseMUT 
RunMacro("MOVES_Log", "SUTGrowth:"+ r2s(SUTGrowth))
RunMacro("MOVES_Log", "MUTGrowth:"+ r2s(MUTGrowth))
pop51 = r2i(bstp51 * SUTGrowth)
pop52 = r2i(bstp52 * SUTGrowth)
pop53 = r2i(bstp53 * SUTGrowth)
pop54 = r2i(bstp54 * SUTGrowth)
pop61 = r2i(bstp61 * MUTGrowth)
pop62 = r2i(bstp62 * MUTGrowth)
CloseView(hcvw)
CloseView(tazcntyvw)
CloseView(hhvw)

//Write Output
//Use default sourceTypePopulation for all other classes
ptr = OpenFile(sty_out, "w")
ar_log = {	"yearID	sourceTypeID	sourceTypePopulation",
			i2s(yearid) + "	11	"+i2s(pop11),
			i2s(yearid) + "	21	"+i2s(pop21),
			i2s(yearid) + "	31	"+i2s(pop31),
			i2s(yearid) + "	32	"+i2s(pop32),                              
			i2s(yearid) + "	41	"+i2s(pop41),                              
			i2s(yearid) + "	42	"+i2s(pop42),                              
			i2s(yearid) + "	43	"+i2s(pop43),                              
			i2s(yearid) + "	51	"+i2s(pop51),                              
			i2s(yearid) + "	52	"+i2s(pop52),
			i2s(yearid) + "	53	"+i2s(pop53),
			i2s(yearid) + "	54	"+i2s(pop54),                                
			i2s(yearid) + "	61	"+i2s(pop61),
			i2s(yearid) + "	62	"+i2s(pop62)
			}
WriteArray(ptr, ar_log)
CloseFile(ptr)  	 

endMacro

//04: hourVMTFraction
Macro "hourVMTFraction"(tazcntyfile, hrtripmtx, vmttripmtx, skimmtx, hvf_base, hvf_out)
RunMacro("MOVES_Log", "Hourly VMT Fraction")
RT2def = {0.01077,0.00764,0.00655,0.00663,0.00954,0.02006,0.04103,0.05797,0.05347,0.05255,0.05506,0.05767,0.05914,0.06080,0.06530,0.07261,0.07738,0.07548,0.05871,0.04399,0.03573,0.03074,0.02385,0.01732}
RT3def = {0.01077,0.00764,0.00655,0.00663,0.00954,0.02006,0.04103,0.05797,0.05347,0.05255,0.05506,0.05767,0.05914,0.06080,0.06530,0.07261,0.07738,0.07548,0.05871,0.04399,0.03573,0.03074,0.02385,0.01732}
RT4def = {0.00986,0.00627,0.00506,0.00467,0.00699,0.01849,0.04596,0.06964,0.06083,0.05029,0.04994,0.05437,0.05765,0.05803,0.06226,0.07100,0.07697,0.07743,0.05978,0.04439,0.03545,0.03182,0.02494,0.01791}
RT5def = {0.00986,0.00627,0.00506,0.00467,0.00699,0.01849,0.04596,0.06964,0.06083,0.05029,0.04994,0.05437,0.05765,0.05803,0.06226,0.07100,0.07697,0.07743,0.05978,0.04439,0.03545,0.03182,0.02494,0.01791}

hrtripmat = OpenMatrix(hrtripmtx, "Auto")
tripmc = CreateMatrixCurrencies(hrtripmat, null, null, null)

hrnames = {"hr01","hr02","hr03","hr04","hr05","hr06","hr07","hr08","hr09","hr10","hr11","hr12","hr13","hr14","hr15","hr16","hr17","hr18","hr19","hr20","hr21","hr22","hr23","hr24","total"}

vmttripmat = OpenMatrix(vmttripmtx, "Auto")
vmtmc = CreateMatrixCurrencies(vmttripmat, null, null, null)

skimmat = OpenMatrix(skimmtx, "Auto")
skimmc = CreateMatrixCurrencies(skimmat, null, null, null)

tazcntyvw = OpenTable("tazcnty", "DBASE", {tazcntyfile, })

//OUTPUT_04a: Normalize over HourofDay
//Create VMT mtx and apply RoadTypeSkim
dim RT2hr[24] dim RT3hr[24] dim RT4hr[24] dim RT5hr[24]
{RT2tot, RT3tot, RT4tot, RT5tot} = {1, 1, 1, 1}

for hr = 1 to 24 do
	vmtmc.RTVMT02 := skimmc.[RT2Leng (Skim)] * tripmc.(hrnames[hr])	//check if [RT2Leng (Skim)] will work
	vmtmc.RTVMT03 := skimmc.[RT3Leng (Skim)] * tripmc.(hrnames[hr])
	vmtmc.RTVMT04 := skimmc.[RT4Leng (Skim)] * tripmc.(hrnames[hr])
	vmtmc.RTVMT05 := skimmc.[RT5Leng (Skim)] * tripmc.(hrnames[hr])
	stat = MatrixStatistics(vmttripmat, )
	RT2hr[hr] = stat.RTVMT02.Sum
	RT3hr[hr] = stat.RTVMT03.Sum
	RT4hr[hr] = stat.RTVMT04.Sum
	RT5hr[hr] = stat.RTVMT05.Sum
	RT2tot = RT2tot + stat.RTVMT02.Sum
	RT3tot = RT3tot + stat.RTVMT03.Sum
	RT4tot = RT4tot + stat.RTVMT04.Sum
	RT5tot = RT5tot + stat.RTVMT05.Sum
end

CloseView(tazcntyvw)

//Write Output
//OUTPUT_04b: Truck hourly distribution by counts (coded in Base template)
//OUTPUT_04c: Defaults for non-private & weekends (coded in Base template)
	ptr = OpenFile(hvf_base, "r+")
	hvfarr = ReadArray(ptr)
	CloseFile(ptr)

	hvfarr[314] =  "21	2	5	1	"+r2s(Mean({RT2def[1] ,RT2hr[1]/RT2tot }))
	hvfarr[315] =  "21	2	5	2	"+r2s(Mean({RT2def[2] ,RT2hr[2]/RT2tot }))
	hvfarr[316] =  "21	2	5	3	"+r2s(Mean({RT2def[3] ,RT2hr[3]/RT2tot }))
	hvfarr[317] =  "21	2	5	4	"+r2s(Mean({RT2def[4] ,RT2hr[4]/RT2tot }))
	hvfarr[318] =  "21	2	5	5	"+r2s(Mean({RT2def[5] ,RT2hr[5]/RT2tot }))
	hvfarr[319] =  "21	2	5	6	"+r2s(Mean({RT2def[6] ,RT2hr[6]/RT2tot }))
	hvfarr[320] =  "21	2	5	7	"+r2s(Mean({RT2def[7] ,RT2hr[7]/RT2tot }))
	hvfarr[321] =  "21	2	5	8	"+r2s(Mean({RT2def[8] ,RT2hr[8]/RT2tot }))
	hvfarr[322] =  "21	2	5	9	"+r2s(Mean({RT2def[9] ,RT2hr[9]/RT2tot }))
	hvfarr[323] = "21	2	5	10	"+r2s(Mean({RT2def[10],RT2hr[10]/RT2tot}))
	hvfarr[324] = "21	2	5	11	"+r2s(Mean({RT2def[11],RT2hr[11]/RT2tot}))
	hvfarr[325] = "21	2	5	12	"+r2s(Mean({RT2def[12],RT2hr[12]/RT2tot}))
	hvfarr[326] = "21	2	5	13	"+r2s(Mean({RT2def[13],RT2hr[13]/RT2tot}))
	hvfarr[327] = "21	2	5	14	"+r2s(Mean({RT2def[14],RT2hr[14]/RT2tot}))
	hvfarr[328] = "21	2	5	15	"+r2s(Mean({RT2def[15],RT2hr[15]/RT2tot}))
	hvfarr[329] = "21	2	5	16	"+r2s(Mean({RT2def[16],RT2hr[16]/RT2tot}))
	hvfarr[330] = "21	2	5	17	"+r2s(Mean({RT2def[17],RT2hr[17]/RT2tot}))
	hvfarr[331] = "21	2	5	18	"+r2s(Mean({RT2def[18],RT2hr[18]/RT2tot}))
	hvfarr[332] = "21	2	5	19	"+r2s(Mean({RT2def[19],RT2hr[19]/RT2tot}))
	hvfarr[333] = "21	2	5	20	"+r2s(Mean({RT2def[20],RT2hr[20]/RT2tot}))
	hvfarr[334] = "21	2	5	21	"+r2s(Mean({RT2def[21],RT2hr[21]/RT2tot}))
	hvfarr[335] = "21	2	5	22	"+r2s(Mean({RT2def[22],RT2hr[22]/RT2tot}))
	hvfarr[336] = "21	2	5	23	"+r2s(Mean({RT2def[23],RT2hr[23]/RT2tot}))
	hvfarr[337] = "21	2	5	24	"+r2s(Mean({RT2def[24],RT2hr[24]/RT2tot}))
	
	hvfarr[362] =  "21	3	5	1	"+r2s(Mean({RT3def[1] ,RT3hr[1]/RT3tot }))
	hvfarr[363] =  "21	3	5	2	"+r2s(Mean({RT3def[2] ,RT3hr[2]/RT3tot }))
	hvfarr[364] =  "21	3	5	3	"+r2s(Mean({RT3def[3] ,RT3hr[3]/RT3tot }))
	hvfarr[365] =  "21	3	5	4	"+r2s(Mean({RT3def[4] ,RT3hr[4]/RT3tot }))
	hvfarr[366] =  "21	3	5	5	"+r2s(Mean({RT3def[5] ,RT3hr[5]/RT3tot }))
	hvfarr[367] =  "21	3	5	6	"+r2s(Mean({RT3def[6] ,RT3hr[6]/RT3tot }))
	hvfarr[368] =  "21	3	5	7	"+r2s(Mean({RT3def[7] ,RT3hr[7]/RT3tot }))
	hvfarr[369] =  "21	3	5	8	"+r2s(Mean({RT3def[8] ,RT3hr[8]/RT3tot }))
	hvfarr[370] =  "21	3	5	9	"+r2s(Mean({RT3def[9] ,RT3hr[9]/RT3tot }))
	hvfarr[371] = "21	3	5	10	"+r2s(Mean({RT3def[10],RT3hr[10]/RT3tot}))
	hvfarr[372] = "21	3	5	11	"+r2s(Mean({RT3def[11],RT3hr[11]/RT3tot}))
	hvfarr[373] = "21	3	5	12	"+r2s(Mean({RT3def[12],RT3hr[12]/RT3tot}))
	hvfarr[374] = "21	3	5	13	"+r2s(Mean({RT3def[13],RT3hr[13]/RT3tot}))
	hvfarr[375] = "21	3	5	14	"+r2s(Mean({RT3def[14],RT3hr[14]/RT3tot}))
	hvfarr[376] = "21	3	5	15	"+r2s(Mean({RT3def[15],RT3hr[15]/RT3tot}))
	hvfarr[377] = "21	3	5	16	"+r2s(Mean({RT3def[16],RT3hr[16]/RT3tot}))
	hvfarr[378] = "21	3	5	17	"+r2s(Mean({RT3def[17],RT3hr[17]/RT3tot}))
	hvfarr[379] = "21	3	5	18	"+r2s(Mean({RT3def[18],RT3hr[18]/RT3tot}))
	hvfarr[380] = "21	3	5	19	"+r2s(Mean({RT3def[19],RT3hr[19]/RT3tot}))
	hvfarr[381] = "21	3	5	20	"+r2s(Mean({RT3def[20],RT3hr[20]/RT3tot}))
	hvfarr[382] = "21	3	5	21	"+r2s(Mean({RT3def[21],RT3hr[21]/RT3tot}))
	hvfarr[383] = "21	3	5	22	"+r2s(Mean({RT3def[22],RT3hr[22]/RT3tot}))
	hvfarr[384] = "21	3	5	23	"+r2s(Mean({RT3def[23],RT3hr[23]/RT3tot}))
	hvfarr[385] = "21	3	5	24	"+r2s(Mean({RT3def[24],RT3hr[24]/RT3tot}))
	
	hvfarr[410] =  "21	4	5	1	"+r2s(Mean({RT4def[1] ,RT4hr[1]/RT4tot }))
	hvfarr[411] =  "21	4	5	2	"+r2s(Mean({RT4def[2] ,RT4hr[2]/RT4tot }))
	hvfarr[412] =  "21	4	5	3	"+r2s(Mean({RT4def[3] ,RT4hr[3]/RT4tot }))
	hvfarr[413] =  "21	4	5	4	"+r2s(Mean({RT4def[4] ,RT4hr[4]/RT4tot }))
	hvfarr[414] =  "21	4	5	5	"+r2s(Mean({RT4def[5] ,RT4hr[5]/RT4tot }))
	hvfarr[415] =  "21	4	5	6	"+r2s(Mean({RT4def[6] ,RT4hr[6]/RT4tot }))
	hvfarr[416] =  "21	4	5	7	"+r2s(Mean({RT4def[7] ,RT4hr[7]/RT4tot }))
	hvfarr[417] =  "21	4	5	8	"+r2s(Mean({RT4def[8] ,RT4hr[8]/RT4tot }))
	hvfarr[418] =  "21	4	5	9	"+r2s(Mean({RT4def[9] ,RT4hr[9]/RT4tot }))
	hvfarr[419] = "21	4	5	10	"+r2s(Mean({RT4def[10],RT4hr[10]/RT4tot}))
	hvfarr[420] = "21	4	5	11	"+r2s(Mean({RT4def[11],RT4hr[11]/RT4tot}))
	hvfarr[421] = "21	4	5	12	"+r2s(Mean({RT4def[12],RT4hr[12]/RT4tot}))
	hvfarr[422] = "21	4	5	13	"+r2s(Mean({RT4def[13],RT4hr[13]/RT4tot}))
	hvfarr[423] = "21	4	5	14	"+r2s(Mean({RT4def[14],RT4hr[14]/RT4tot}))
	hvfarr[424] = "21	4	5	15	"+r2s(Mean({RT4def[15],RT4hr[15]/RT4tot}))
	hvfarr[425] = "21	4	5	16	"+r2s(Mean({RT4def[16],RT4hr[16]/RT4tot}))
	hvfarr[426] = "21	4	5	17	"+r2s(Mean({RT4def[17],RT4hr[17]/RT4tot}))
	hvfarr[427] = "21	4	5	18	"+r2s(Mean({RT4def[18],RT4hr[18]/RT4tot}))
	hvfarr[428] = "21	4	5	19	"+r2s(Mean({RT4def[19],RT4hr[19]/RT4tot}))
	hvfarr[429] = "21	4	5	20	"+r2s(Mean({RT4def[20],RT4hr[20]/RT4tot}))
	hvfarr[430] = "21	4	5	21	"+r2s(Mean({RT4def[21],RT4hr[21]/RT4tot}))
	hvfarr[431] = "21	4	5	22	"+r2s(Mean({RT4def[22],RT4hr[22]/RT4tot}))
	hvfarr[432] = "21	4	5	23	"+r2s(Mean({RT4def[23],RT4hr[23]/RT4tot}))
	hvfarr[433] = "21	4	5	24	"+r2s(Mean({RT4def[24],RT4hr[24]/RT4tot}))
	
	hvfarr[458] =  "21	5	5	1	"+r2s(Mean({RT5def[1] ,RT5hr[1]/RT5tot }))
	hvfarr[459] =  "21	5	5	2	"+r2s(Mean({RT5def[2] ,RT5hr[2]/RT5tot }))
	hvfarr[460] =  "21	5	5	3	"+r2s(Mean({RT5def[3] ,RT5hr[3]/RT5tot }))
	hvfarr[461] =  "21	5	5	4	"+r2s(Mean({RT5def[4] ,RT5hr[4]/RT5tot }))
	hvfarr[462] =  "21	5	5	5	"+r2s(Mean({RT5def[5] ,RT5hr[5]/RT5tot }))
	hvfarr[463] =  "21	5	5	6	"+r2s(Mean({RT5def[6] ,RT5hr[6]/RT5tot }))
	hvfarr[464] =  "21	5	5	7	"+r2s(Mean({RT5def[7] ,RT5hr[7]/RT5tot }))
	hvfarr[465] =  "21	5	5	8	"+r2s(Mean({RT5def[8] ,RT5hr[8]/RT5tot }))
	hvfarr[466] =  "21	5	5	9	"+r2s(Mean({RT5def[9] ,RT5hr[9]/RT5tot }))
	hvfarr[467] = "21	5	5	10	"+r2s(Mean({RT5def[10],RT5hr[10]/RT5tot}))
	hvfarr[468] = "21	5	5	11	"+r2s(Mean({RT5def[11],RT5hr[11]/RT5tot}))
	hvfarr[469] = "21	5	5	12	"+r2s(Mean({RT5def[12],RT5hr[12]/RT5tot}))
	hvfarr[470] = "21	5	5	13	"+r2s(Mean({RT5def[13],RT5hr[13]/RT5tot}))
	hvfarr[471] = "21	5	5	14	"+r2s(Mean({RT5def[14],RT5hr[14]/RT5tot}))
	hvfarr[472] = "21	5	5	15	"+r2s(Mean({RT5def[15],RT5hr[15]/RT5tot}))
	hvfarr[473] = "21	5	5	16	"+r2s(Mean({RT5def[16],RT5hr[16]/RT5tot}))
	hvfarr[474] = "21	5	5	17	"+r2s(Mean({RT5def[17],RT5hr[17]/RT5tot}))
	hvfarr[475] = "21	5	5	18	"+r2s(Mean({RT5def[18],RT5hr[18]/RT5tot}))
	hvfarr[476] = "21	5	5	19	"+r2s(Mean({RT5def[19],RT5hr[19]/RT5tot}))
	hvfarr[477] = "21	5	5	20	"+r2s(Mean({RT5def[20],RT5hr[20]/RT5tot}))
	hvfarr[478] = "21	5	5	21	"+r2s(Mean({RT5def[21],RT5hr[21]/RT5tot}))
	hvfarr[479] = "21	5	5	22	"+r2s(Mean({RT5def[22],RT5hr[22]/RT5tot}))
	hvfarr[480] = "21	5	5	23	"+r2s(Mean({RT5def[23],RT5hr[23]/RT5tot}))
	hvfarr[481] = "21	5	5	24	"+r2s(Mean({RT5def[24],RT5hr[24]/RT5tot}))

	
	ptr = OpenFile(hvf_out, "w")
	WriteArray(ptr, hvfarr)
	CloseFile(ptr)
endMacro

//05: avgSpeedDistribution
Macro "avgSpeedDist" (mv_aut, mv_sut, mv_mut, mv_spd, asd_base, asd_out)
RunMacro("MOVES_Log", "Average Speed Distribution")
//sourcetype= {11   ,21    ,31    ,32    ,41    ,42    ,43    ,51    ,52    ,53     ,54     ,61     ,62}
//stfields  = {"ST1", "ST2", "ST3", "ST4", "ST5", "ST6", "ST7", "ST8", "ST9", "ST10", "ST11", "ST12", "ST13"}
sourcetype= {21   , 52   , 61}
linestart = {21506, 32258, 36866 }//Array start {ST, 2, 15, 1, X}
roadtype = {2,3,4,5}
	
hourday = {15    ,25     ,35     ,45     ,55     ,65     ,75     ,85     ,95     ,105    ,115    ,125    ,135    ,145    ,155    ,165    ,175    ,185    ,195    ,205    ,215    ,225    ,235    ,245}
vmtstr = {"VMT_0_1","VMT_1_2","VMT_2_3","VMT_3_4","VMT_4_5","VMT_5_6","VMT_6_7","VMT_7_8","VMT_8_9","VMT_9_10","VMT_10_11","VMT_11_12","VMT_12_13","VMT_13_14","VMT_14_15","VMT_15_16","VMT_16_17","VMT_17_18","VMT_18_19","VMT_19_20","VMT_20_21","VMT_21_22","VMT_22_23","VMT_23_24"}
vhtstr = {"VHT_0_1","VHT_1_2","VHT_2_3","VHT_3_4","VHT_4_5","VHT_5_6","VHT_6_7","VHT_7_8","VHT_8_9","VHT_9_10","VHT_10_11","VHT_11_12","VHT_12_13","VHT_13_14","VHT_14_15","VHT_15_16","VHT_16_17","VHT_17_18","VHT_18_19","VHT_19_20","VHT_20_21","VHT_21_22","VHT_22_23","VHT_23_24"}
	
speedbin = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
binfld = {"BIN_0_1","BIN_1_2","BIN_2_3","BIN_3_4","BIN_4_5","BIN_5_6","BIN_6_7","BIN_7_8","BIN_8_9","BIN_9_10","BIN_10_11","BIN_11_12","BIN_12_13","BIN_13_14","BIN_14_15","BIN_15_16","BIN_16_17","BIN_17_18","BIN_18_19","BIN_19_20","BIN_20_21","BIN_21_22","BIN_22_23","BIN_23_24"}

//Get SpdBins
LinkSpd = OpenTable("LinkSpd", "DBASE", {mv_spd, })
  
//asd_base
ptr = OpenFile(asd_base, "r+")
asdarr = ReadArray(ptr)
CloseFile(ptr)
	
//OUTPUT_05a: normalize over roadType by hour by speedbin
autvht = OpenTable("AutVHT", "DBASE", {mv_aut, })
sutvht = OpenTable("SUTVHT", "DBASE", {mv_sut, })
mutvht = OpenTable("MUTVHT", "DBASE", {mv_mut, })
	
dim vhttab[3]
dim speedfract[16]
dim vhtspdbin[16]
vhttab = {autvht, sutvht, mutvht}
for a = 1 to sourcetype.length do
	jnVS = JoinViews("jnVS", vhttab[a]+".ID1", LinkSpd+".ID1", )
	SetView(jnVS)
	for b = 1 to roadtype.length do
		for c = 1 to hourday.length do
			vhthrtot = 0
			for d = 1 to speedbin.length do
				queryb = SelectByQuery("queryout", "Several", "Select * where "+vhttab[a]+".ROADTYPE = "+i2s(roadtype[b]) +" and "+vhttab[a]+".RAMP = 0")
				queryd = SelectByQuery("queryout", "subset", "Select * where "+binfld[c]+" = "+i2s(speedbin[d]))
				
				if queryd > 0 then do
					{vht} = GetDataVectors(jnVS+"|queryout", {vhtstr[c]},)
					vhtspdbin[d] = VectorStatistic(vht, "Sum",)
				end
				else if queryd = 0 then do
					vhtspdbin[d] = 0
				end
				vhthrtot = vhthrtot + vhtspdbin[d]
			end
			
			//Write output by sourcetype, roadtype, hourtype, speedbin, vhtfrac
			for d = 1 to speedbin.length do
				speedfract[d] = vhtspdbin[d]/max(vhthrtot,1)
				idx = linestart[a]-1 + ((b-1)*24*16 + (c-1)*16 + d)
				asdarr[idx] = i2s(sourcetype[a])+","+i2s(roadtype[b])+","+i2s(hourday[c])+","+i2s(speedbin[d])+","+r2s(speedfract[d])
				debug = asdarr[idx]
			end
		end
	end
CloseView(jnVS)
CloseView(vhttab[a])
end
CloseView(LinkSpd)

//Write Output
ptr = OpenFile(asd_out, "w")
WriteArray(ptr, asdarr)
CloseFile(ptr)
endMacro

//06: rampfraction
Macro "rampfraction" (mv_aut, mv_sut, mv_mut, ramp_out)
RunMacro("MOVES_Log", "Ramp Fraction")
//Take ramp & freeway VHTs (exclude system-to-system ramps)
autvmt = OpenTable("AutVMT", "DBASE", {mv_aut, })
sutvmt = OpenTable("SUTVMT", "DBASE", {mv_sut, })
mutvmt = OpenTable("MUTVMT", "DBASE", {mv_mut, })

dim vmttab[3]
vmttab = {autvmt, sutvmt, mutvmt}
{tot2f, tot2r, tot4f, tot4r} = {0,0,0,0}

for cls = 1 to vmttab.length do
	{vmt2f, vmt4f, vmt2r, vmt4r} = {0,0,0,0}
	SetView(vmttab[cls])
	RunMacro("addfields", vmttab[cls], {"SysRamp"}, "i")
	sr = CreateExpression(vmttab[cls], "sr", "if RAMP = 1 and SPDLMT > 50 then 1 else 0", {"Integer", 4, 0})
	SetRecordsValues(vmttab[cls]+"|", {{"SysRamp"}, null}, "Formula", {sr},)
	arr = GetExpressions(vmttab[cls])
	for i = 1 to arr.length do DestroyExpression(vmttab[cls]+"."+arr[i]) end
	
	q2fwy = "Select * where COUNTYID = 65 and (ROADTYPE = 2 or ROADTYPE = 2 and SYSRAMP = 1)"
	set2f = SelectByQuery("set2f", "Several", q2fwy, )
	if set2f > 0 then do
		v2f = GetDataVectors(vmttab[cls]+"|set2f", {"TOT_VMT"},)
		vmt2f = VectorStatistic(v2f[1], "Sum",)
	end
	tot2f = tot2f + vmt2f
	
	q4fwy = "Select * where COUNTYID = 65 and (ROADTYPE = 4 or ROADTYPE = 4 and SYSRAMP = 1)"
	set4f = SelectByQuery("set4f", "Several", q4fwy, )
	if set4f > 0 then do
		v4f = GetDataVectors(vmttab[cls]+"|set4f", {"TOT_VMT"},)
		vmt4f = VectorStatistic(v4f[1], "Sum",)
	end
	tot4f = tot4f + vmt4f
	
	q2ramp = "Select * where COUNTYID = 65 and ROADTYPE = 2 and RAMP = 1 and SYSRAMP = 0"
	set2r = SelectByQuery("set2r", "Several", q2ramp, )
	if set2r > 0 then do
		v2r = GetDataVectors(vmttab[cls]+"|set2r", {"TOT_VMT"},)
		vmt2r = VectorStatistic(v2r[1], "Sum",)
	end
	tot2r = tot2r + vmt2r
	
	q4ramp = "Select * where COUNTYID = 65 and ROADTYPE = 4 and RAMP = 1 and SYSRAMP = 0"
	set4r = SelectByQuery("set4r", "Several", q4ramp, )
	if set4r > 0 then do
		v4r = GetDataVectors(vmttab[cls]+"|set4r", {"TOT_VMT"},)
		vmt4r = VectorStatistic(v4r[1], "Sum",)
	end
	tot4r = tot4r + vmt4r
	RunMacro("MOVES_Log", "RT2_Fwy: "+r2s(vmt2f)+"\t RT4_Fwy: "+r2s(vmt4f)+"\t RT2_Ramp: "+r2s(vmt2r)+"\t RT4_Ramp: "+r2s(vmt4r))
	
	CloseView(vmttab[cls])
end

//OUTPUT_06: [ramp/(ramp+freeway)] VMT
rf2 = if tot2f+tot2r=0 then 0 else tot2r/(tot2f+tot2r)
rf4 = if tot4f+tot4r=0 then 0 else tot4r/(tot4f+tot4r)


//Write Output
ptr = OpenFile(ramp_out, "w")
ar_log = {	"roadTypeID	rampFraction",
			"2	"+r2s(rf2),
			"4	"+r2s(rf4)
		}
WriteArray(ptr, ar_log)
CloseFile(ptr)
endMacro

//07: HPMSVTypeYear
Macro "HPMSVTypeYear" (mv_aut, mv_sut, mv_mut, yearid, popgrowth, hvty_out)
RunMacro("MOVES_Log", "HPMS Yearly VMT")

//Reported HPMS VMT
rephvt10 = 20468573
rephvt25 = 3379781269
rephvt40 = 2845725
rephvt50 = 73157979
rephvt60 = 247042469
wgt10 = Round(rephvt10/(rephvt10 + rephvt25),5) //0.00602
wgt25 = Round(rephvt25/(rephvt10 + rephvt25),5) //0.99398

//Base Year Model VMT (daily)
bautoVMT = 7802218
bsutVMT = 340106
bmutVMT = 687994

localscale = 1.50 //represents unmodeled local roads
yearfact = 342 //annualization factor (332-347)

autvmt = OpenTable("AutVMT", "DBASE", {mv_aut, })
sutvmt = OpenTable("SUTVMT", "DBASE", {mv_sut, })
mutvmt = OpenTable("MUTVMT", "DBASE", {mv_mut, })
vmttab = {autvmt, sutvmt, mutvmt}

qfwy = "Select * where COUNTYID = 65 and (FUNCCLASS = 1 or FUNCCLASS = 11 or FUNCCLASS = 2 or FUNCCLASS = 12)"
qoth = "Select * where COUNTYID = 65 and (FUNCCLASS <> 1 and FUNCCLASS <> 11 and FUNCCLASS <> 2 and FUNCCLASS <> 12)"

dim totvmtfwy[3]
dim totvmtoth[3]
for cls=1 to vmttab.length do
	SetView(vmttab[cls])
	fwy = SelectByQuery("fwy", "Several", qfwy)
	oth = SelectByQuery("oth", "Several", qoth)
	{vmtfwy} = GetDataVectors(vmttab[cls]+"|fwy", {"TOT_VMT"},)
	{vmtoth} = GetDataVectors(vmttab[cls]+"|oth", {"TOT_VMT"},)
	totvmtfwy[cls] = Round((VectorStatistic(vmtfwy, "Sum",)),1)
	totvmtoth[cls] = Round((VectorStatistic(vmtoth, "Sum",)),1)
	CloseView(vmttab[cls])
	RunMacro("MOVES_Log", "Fwy_VMT: "+r2s(totvmtfwy[cls])+"\t Oth_VMT: "+r2s(totvmtoth[cls]))
end

//OUTPUT_07a: Use LocalScale & Annualization factor
hvt10 = Round((totvmtfwy[1] + totvmtoth[1] * localscale) * yearfact * wgt10,1)
hvt25 = Round((totvmtfwy[1] + totvmtoth[1] * localscale) * yearfact * wgt25,1)

//OUTPUT_07c: Apply population growth factor to 2014 HPMS
hvt40 = Round(rephvt40 * popgrowth,1)

//OUTPUT_07b: Apply SUT growth & MUT growth to 2014 HPMS
sutgrowth = (totvmtfwy[2] + totvmtoth[2])/bsutVMT
mutgrowth = (totvmtfwy[3] + totvmtoth[3])/bmutVMT
hvt50 = Round(rephvt50*sutgrowth,1)
hvt60 = Round(rephvt60*mutgrowth,1)


//Write Output
ptr = OpenFile(hvty_out, "w")
ar_log = {	"HPMSVTypeID	yearID	HPMSBaseYearVMT",
			"10	" + i2s(yearid) + "	"+Format(hvt10,"*0"),
			"25	" + i2s(yearid) + "	"+Format(hvt25,"*0"),
			"40	" + i2s(yearid) + "	"+Format(hvt40,"*0"),                              
			"50	" + i2s(yearid) + "	"+Format(hvt50,"*0"),                              
			"60	" + i2s(yearid) + "	"+Format(hvt60,"*0")
			}
WriteArray(ptr, ar_log)
CloseFile(ptr)  

endMacro


//Tools
Macro "CheckMatrixIndex" (mtx, rowidx, colidx, view, qry, oldid, newid)
	idxexists = 0
	idxnames = GetMatrixIndexNames(mtx)

	if rowidx <> null then do
		for i=1 to idxnames[1].length do
			if idxnames[1][i] = rowidx then idxexists = 1
		end
	end
	if colidx <> null then do
		for i=1 to idxnames[2].length do
			if idxnames[2][i] = colidx then idxexists = 1
		end
	end

	if idxexists = 1 then do 
		Return()
	end
	else if idxexists = 0 then do
		SetView(view)
		set = SelectByQuery(rowidx, "Several", qry, )
		newidx = CreateMatrixIndex(rowidx, mtx, "Both", view+"|"+rowidx, oldid, newid)
		Return()
	end
endMacro

Macro "AddLayer" (file, type)
//Adds .dbd to map as a layer
//Type: "Point", "Line", or "Area" for geographic layers, "Image" for image layers, or "Image Library" for image libraries

map_name = GetMap()
layer_names = GetLayerNames()
file_layers = GetDBLayers(file)
file_info = GetDBInfo(file)
if map_name = null then map_name = CreateMap("RSG", {{"Scope", file_info[1]}, {"Auto Project", "True"}})
SetMapRedraw(map_name, "False")

//If .rts then add to map
if type = "rts" then do
	newlyr = AddRouteSystemLayer(null, "Transit Routes", file, null)
	RunMacro("Set Default RS Style", newlyr, "True", "True")
	Return(newlyr[1])
	//[1] Route System Layer Name
	//[2] Stops
	//[3] Physical Stops
	//[4] Node Layer Name (if added)
	//[5] Line Layer Name (if added)
end

//Check if db already exists
for i=1 to layer_names.length do
	//Skip if Type mismatch
	layer_type = GetLayerType(layer_names[i])
	if layer_type <> type then goto skip
	
	//Check for dbd match
	layer_info = GetLayerInfo(layer_names[i])
	layerdb = layer_info[10]
	if lower(layerdb) = lower(file) then do
		//ShowMessage("AddLayer: LayerDB already exists in map")
		Return(layer_names[i])
	end
	skip:
end

/*
//Check if layername already exists
for i=1 to file_layers.length do
	idx = ArrayPosition(layer_names, {file_layers[i]}, ) 
	if idx <> 0 and GetLayerType(file_layers[i]) = type then do
		newlyr = layer_names[idx]
		//ShowMessage("AddLayer: LayerName already exists")
		Return(newlyr)
	end
end
*/

//Else, add file to map
newlyr = AddLayer(null, file_layers[1], file, file_layers[1])
if GetLayerType(newlyr) <> type then do
	newlyr = AddLayer( , file_layers[2], file, file_layers[2]) //Add lines if only nodes were loaded
end
RunMacro("G30 new layer default settings", newlyr)
Return(newlyr)

endhere:
throw("AddLayer: Layer already exists in map!")

endMacro

Macro "MOVES_Log" (msg)
shared logfile
logtime = CreateDateTime()
timestamp = FormatDateTime(logtime, "MMMdd_HHmm")

ptr = OpenFile(logfile, "a")
ar_log = { timestamp+": "+msg }
WriteArray(ptr, ar_log)
CloseFile(ptr) 

endMacro


/*
COUNTYID
65 - Hamilton (TN)
83 - Dade (TN)
47 - Catoosa (GA)
295 - Walker (GA)

MOVES RoadTypes
1 Off Network
2 Rural restricted (interstate / ramps)
3 Rural Unrestricted (non interstate)
4 Urban restricted  (interstate / ramps)
5 Urban unrestricted  (non interstate)

MOVES SourceTypes
11 Motorcycle
-21 Passenger Car
31 Passenger Truck
32 Light Commercial Truck
41 Intercity Bus
42 Transit Bus
43 School Bus
51 Refuse Truck
53 Single Unit Long-haul Truck
54 Motor Home
-52 Single Unit Short-haul Truck
62 Combination Long-haul Truck
-61 Combination Short-haul Truck
*/