/*
Transit Skimming
nagendra.dhakar@rsginc.com
Orig Date: 10/05/2015

@ST - Updated for Chattanooga 01/29/2016
@ND - Updated for OP time period 02/02/2016
*/

Macro "TransitSkimming" (Args)
	shared mvw, skim, indir, outdir //variables passed from GUI.rsc

    RunMacro("SetTransitParameters",Args)
    RunMacro("PrepareInputs")
    RunMacro("BuildDriveConnectors")
    RunMacro("BuildTransitPaths")
    RunMacro("ProcessTransitSkims", Args)
    RunMacro("CopyTransitSkims", Args)

    Return(1)
EndMacro


// 04/24/2013 - Incorporated the Transit Model code from the MTA Model
Macro "SetTransitParameters" (Args)
	//variables passed from GUI.rsc
	shared mvw, skim, indir, outdir

	//UpdateProgressBar("SetTransitParameters",)

	// settings
    shared Periods, Modes, AccessModes, AccessAssgnModes
	// parameters
    shared TransitTimeFactor, TransitOnlyLinkDefaultSpeed, WalkSpeed, WalkBufferDistance
	shared ValueofTime, AutoOperatingCost, AOCC_PNR, PNR_TerminalTime, MaxPNR_DriveTime
    // input files
	shared highway_dbd, highway_link_bin, highway_node_bin, zone_dbd, zone_bin, route_system
    shared route_stop, route_stop_bin, route_bin
	shared modetable, modexfertable, MovementTable
    // output files
	shared mc_network_file, net_file, opskim_file, pkskim_file, OutZData, pnr_time_mat
    shared OutMarketSegment, stat_file, runtime

	/* Transit Time Periods
	AM: 6am - 9am
	OP: 9am - 3pm
	PM: 3pm - 6pm
	OP: 6pm - 6am
	*/

	//  Set paths
    RunMacro("TCB Init")

// ***************************** TEST ********************************************
	zone_dbd      = mvw.tazfile
	route_system  = mvw.rtsfile
	highway_dbd   = mvw.linefile
	modetable     = indir.hwy + "MODES.dbf"
	modexfertable = indir.hwy + "MODEXFER.dbf"
	MovementTable = indir.hwy + "MovementTable.bin"
	stat_file     = outdir.rep + "TrnStat.asc"

	WalkSpeed                   = 3                                  								// Walking Speed in miles per hour
    WalkBufferDistance          = 1                       													// in miles for creating percent walk
    ValueofTime                 = 0.15                                							// in $/min
    AutoOperatingCost           = 10                          											// in cents/mile
    AOCC_PNR                    = 1.2                                   						// average occupancy of vehicle using PNRs
    PNR_TerminalTime            = 1                           											// in minutes
    MaxPNR_DriveTime            = 20                           											// in minutes
// *********************************************************************************

    parts = SplitPath(zone_dbd)
    zone_bin            = parts[1] + parts[2] + parts[3] + ".bin"                  // TAZ layer bin file

    parts = SplitPath(route_system)
    route_stop          = parts[1] + parts[2] + parts[3] + "S.dbd"                  // associated stop layer
    route_stop_bin      = parts[1] + parts[2] + parts[3] + "S.bin"                  // stop layer bin file
    route_bin           = parts[1] + parts[2] + parts[3] + "R.bin"                  // route layer bin file

    parts = SplitPath(highway_dbd)
    highway_link_bin    = parts[1] + parts[2] + parts[3] + ".bin"                   // highway link layer bin file
    highway_node_bin    = parts[1] + parts[2] + parts[3] + "_.bin"                  // highway node layer bin file

    //  Output Files
    mc_network_file     = outdir.transit + "Network_MC.net"
	net_file 					= 	{outdir.transit + "NetworkC_AM.net",
									 outdir.transit + "NetworkC_PM.net",
									 outdir.transit + "NetworkC_OP.net"}
	pnr_time_mat 				= 	{outdir.transit + "PNR_Time_AM.mtx",
									 outdir.transit + "PNR_Time_PM.mtx",
									 outdir.transit + "PNR_Time_OP.mtx"}
	skim.transit = pnr_time_mat
    OutZData            = outdir.transit + "ZoneDataMC.asc"
    OutMarketSegment    = outdir.transit + "hhauto.dat"

//  ************************************************************************************************************************************

	//  Define Parameters
    Periods                     = {"AM","PM","OP"}                             // Transit time periods
    Modes                       = {"Local", "Shuttle"}   																			// List of transit modes
    AccessModes                 = {"Walk"}                                  // List of access modes for building paths
    AccessAssgnModes            = {"Walk"}                              // List of access modes for mode choice model

    TransitTimeFactor           = {1.00,1.00,0.00}                             // corresponds to Link TTF No. (arterials, expressways, transit only links, railroads)
    TransitOnlyLinkDefaultSpeed = {0.00, 0.00, 13.00}                        // corresponds to Link TTF No.

	// Open the log file
    runtime = OpenFile(outdir.transit + "runtime.prn", "w")
    Return(1)
EndMacro

// STEP 1: Prepare inputs required by the transit model in the subsequent steps
Macro "PrepareInputs"
//UpdateProgressBar("SetTransitParameters",)
    shared outdir
    shared Periods, Modes, TransitTimeFactor, WalkSpeed, TransitOnlyLinkDefaultSpeed, DwellTimebyMode
    shared highway_dbd, highway_link_bin, highway_node_bin, zone_dbd, zone_bin, route_stop, route_bin, SpeedFactorTable, IDTable, modetable // input files
    shared OutMarketSegment, nodeidfield, runtime // output files

    stime=GetDateAndTime()
    WriteLine(runtime,"\n Begin Model Run                      - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")

// STEP 1.1: Add required fields in the highway layer (if not already existing)
	RunMacro("AddFields")

	//find node id field
	hnodeview = OpenTable("hnodes","FFB",{highway_node_bin,})
	fields = GetFields(hnodeview, "All")
	nodeidfield = fields[1][1] // sometime id field in .bin and .dcb are different. so always get the first field as id field

// STEP 1.2: Fill the highway fields with default values

    layers = GetDBlayers(highway_dbd)
    nlayer = layers[1]
    llayer = layers[2]
    db_nodelyr = highway_dbd + "|" + nlayer
    db_linklyr = highway_dbd + "|" + llayer

	view_names = GetViewNames()

	for i=1 to view_names.length do
		CloseView(view_names[i])
	end

	RunMacro("TCB Init")

	// populate default auto travel time values
	for iper=1 to Periods.length do
		Opts = null
		Opts.Input.[Dataview Set] = {db_linklyr, llayer}
		Opts.Global.Fields = {"AB_"+Periods[iper]+"Time",
							  "BA_"+Periods[iper]+"Time"}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {"if (AB_AFFTime=null | AB_AFFTime<0.001) then Length*60/25 else AB_AFFTime",
								 "if (BA_AFFTime=null | BA_AFFTime<0.001) then Length*60/25 else BA_AFFTime"}

		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end

	// Fill WalkLink, WalkTime and LinkTTF
    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where ID>=1"}         // Fill All links with LinkTTF=1
    Opts.Global.Fields = {"[LinkTTF]","[WalkLink]","[WalkTime]"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = {"1","250","99999"}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts, &Ret)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where IN_WALK=1 | DOT_FC=98" }    // Walk links and also centroids
    Opts.Global.Fields = {"[WalkLink]","[WalkTime]"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = {"98","[" + llayer + "].Length*60/"+string(WalkSpeed)}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    // Cap walktime on long centroid connectors to take care of huge zones in the suburbs
    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where DOT_FC=98 & Length>0.5"}    // centroid connectors longer than 0.5 miles
    Opts.Global.Fields = {"[WalkTime]"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = {"0.5*60/"+string(WalkSpeed)}     // walk time no longer than 0.5 mile walk
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where DOT_FC<=2 | Ramp=1"}    // freeways, ramps
    Opts.Global.Fields = {"[LinkTTF]"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {2}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where IN_TRANSIT=1"}    // transit only links
    Opts.Global.Fields = {"[LinkTTF]"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {3}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

// STEP 1.4.3: Calculate default transit times based on the auto speeds
    for i=1 to TransitTimeFactor.length do
        Opts = null
        Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where [LinkTTF]="+string(i)}
        Opts.Global.Fields = {"[TransitTimeAM_AB]","[TransitTimeAM_BA]","[TransitTimePM_AB]","[TransitTimePM_BA]","[TransitTimeOP_AB]","[TransitTimeOP_BA]"}
        Opts.Global.Method = "Formula"
        if (i=1) then  Opts.Global.Parameter = {"if (AB_AMTime=null | AB_AMTime<0.001) then [" + llayer + "].Length*60/15 else AB_AMTime*"+string(TransitTimeFactor[i]),
                                                "if (BA_AMTime=null | BA_AMTime<0.001) then [" + llayer + "].Length*60/15 else BA_AMTime*"+string(TransitTimeFactor[i]),
												"if (AB_PMTime=null | AB_PMTime<0.001) then [" + llayer + "].Length*60/15 else AB_PMTime*"+string(TransitTimeFactor[i]),
                                                "if (BA_PMTime=null | BA_PMTime<0.001) then [" + llayer + "].Length*60/15 else BA_PMTime*"+string(TransitTimeFactor[i]),
                                                "if (AB_OPTime=null | AB_OPTime<0.001) then [" + llayer + "].Length*60/15 else AB_OPTime*"+string(TransitTimeFactor[i]),
                                                "if (BA_OPTime=null | BA_OPTime<0.001) then [" + llayer + "].Length*60/15 else BA_OPTime*"+string(TransitTimeFactor[i])}
        if (i=2) then  Opts.Global.Parameter = {"if (AB_AMTime=null | AB_AMTime<0.001) then [" + llayer + "].Length*60/15 else AB_AMTime*"+string(TransitTimeFactor[i]),
                                                "if (BA_AMTime=null | BA_AMTime<0.001) then [" + llayer + "].Length*60/15 else BA_AMTime*"+string(TransitTimeFactor[i]),
												"if (AB_PMTime=null | AB_PMTime<0.001) then [" + llayer + "].Length*60/15 else AB_PMTime*"+string(TransitTimeFactor[i]),
                                                "if (BA_PMTime=null | BA_PMTime<0.001) then [" + llayer + "].Length*60/15 else BA_PMTime*"+string(TransitTimeFactor[i]),
                                                "if (AB_OPTime=null | AB_OPTime<0.001) then [" + llayer + "].Length*60/15 else AB_OPTime*"+string(TransitTimeFactor[i]),
                                                "if (BA_OPTime=null | BA_OPTime<0.001) then [" + llayer + "].Length*60/15 else BA_OPTime*"+string(TransitTimeFactor[i])}
        if (i=3) then  Opts.Global.Parameter = {"[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),  // LinkTTF=3 for transit only links
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
												"[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i])}  // LinkTTF=3 for transit only links
        ret_value = RunMacro("TCB Run Operation", 4, "Fill Dataview", Opts)
        if !ret_value then goto quit
    end

// STEP 1.5: Fill Stop Layer with StopFlags (check whether there is a stop or not)
// add 0's to missing layover values in the stop file
    Opts = null
    Opts.Input.[Dataview Set] = {route_stop + "|Transit Stops", "Transit Stops", "Selection", "Select * where Layover=null"}
    Opts.Global.Fields = {"Layover"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {0}
    ret_value = RunMacro("TCB Run Operation", 6, "Fill Dataview", Opts)
    // if !ret_value then goto quit

    for iper=1 to Periods.length do
        // first set all flag to null and then add 1's to the selected stops
        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Transit Stops", route_bin, "Route_ID", "Route_ID"},}
        Opts.Global.Fields = {"TransitFlag_"+Periods[iper]}
        Opts.Global.Method = "Value"
        Opts.Global.Parameter = {}
        ret_value = RunMacro("TCB Run Operation", 6, "Fill Dataview", Opts)
        if !ret_value then goto quit

        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Transit Stops", route_bin, "Route_ID", "Route_ID"}, "StopsRouteSystemR", "Selection", "Select * where HW_"+Periods[iper]+">0& HW_"+Periods[iper]+"<999"}
        Opts.Global.Fields = {"TransitFlag_"+Periods[iper]}
        Opts.Global.Method = "Value"
        Opts.Global.Parameter = {1}
        ret_value = RunMacro("TCB Run Operation", 6, "Fill Dataview", Opts)
        if !ret_value then goto quit
    end


// STEP 1.6: Open & read the modes table to add Dwell Times
    dim DwellTimeFactor[100]
    ModeTable=OpenTable("modetable","dBASE",{modetable,})
    fields=GetTableStructure(ModeTable)

    view_set=ModeTable+"|"
    rec=GetFirstRecord(view_set,null)
    i=1
    while rec!=null do
        values=GetRecordValues(ModeTable,,)
				Factor = ModeTable.DWELL_FACT   // mins per mile
				imde = ModeTable.MODE_ID
				DwellTimeFactor[i] = {imde, Factor}

        i=i+1
        rec=GetNextRecord(view_set, null, null)
    end

    NumModes=i-1-3    // last 3 are not really modes: walk, transitonly, and nowalk.

		// Fill Dwell time values by period
		for iper=1 to Periods.Length do
			for imode=1 to NumModes do
        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Transit Stops", route_bin, "Route_ID", "Route_ID"}, "Route StopsRouteSystemR", "Selection", "Select * where Mode="+string(DwellTimeFactor[imode][1]) + " and TransitFlag_" + Periods[iper] + "=1"}
        Opts.Global.Fields = {"DwellTime_"+Periods[iper]}
        Opts.Global.Method = "Formula"
        Opts.Global.Parameter = {"Distance_LastStop*" + String(DwellTimeFactor[imode][2])}
        ret_value = RunMacro("TCB Run Operation", 5, "Fill Dataview", Opts, &Ret)
				//if !ret_value then goto quit		// comment this out as not all modes in the routes file
			end
		end

// STEP 1.7: Make a zone-zone matrix of 1's to conduct Preassignment
    zonefile=OpenTable("zonedata","FFB",{zone_bin,})

		SetView("zonedata")
		qry = "Select * where External<>1"

		SelectByQuery("zones", "Several", qry)

    CreateMatrix({"zones","ID","Rows"}, {"zones","ID","Columns"},
                 {{"File Name",outdir.transit + "zone.mtx"}, {"Type" ,"Short"}, {"Tables" ,{"Matrix 1"}}})

    Opts = null
    Opts.Input.[Matrix Currency] = {outdir.transit + "zone.mtx", "Matrix 1", "Rows", "Columns"}
    Opts.Global.Method = 1
    Opts.Global.Value = 1
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix Range] = 1
    Opts.Global.[Matrix List] = {"Matrix 1"}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Matrices", Opts)

    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Prepare Inputs to Transit Model  - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(1)
quit:
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Prepare Inputs to Transit Model  - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

// STEP 3: Create weighted drive connectors
Macro "BuildDriveConnectors"
//UpdateProgressBar("BuildDriveConnectors",)
    shared Periods, Modes
    shared ValueofTime, AutoOperatingCost, AOCC_PNR, PNR_TerminalTime, MaxPNR_DriveTime
    shared highway_dbd, highway_node_bin, zone_bin, nodeidfield
    shared mc_network_file, pnr_time_mat, runtime // output files

    RunMacro("TCB Init")

    layers = GetDBlayers(highway_dbd)
    nlayer = layers[1]
    llayer = layers[2]

    db_nodelyr = highway_dbd + "|" + nlayer
    db_linklyr = highway_dbd + "|" + llayer

	/* Added Build Highway Network Step - to update the time fields */

    // STEP 3.1: Build Highway Network

    Opts = null
    Opts.Input.[Link Set] = {db_linklyr , llayer, "Selection", "Select * where IN_HIGHWAY = 1 or IN_TRANSIT = 1"} //select only highway network links
    Opts.Global.[Network Label] = "Based on "+db_linklyr
    //Opts.Global.[Network Options].[Node Id] = nlayer+".ID"
    Opts.Global.[Network Options].[Turn Penalties] = "Yes"
    Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
    Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
    Opts.Global.[Network Options].[Time Units] = "Minutes"
    Opts.Global.[Link Options] = {{"Length", {llayer+".Length", llayer+".Length", , , "False"}},
    	{"TimeCAM_*", {llayer+".AB_AMTime", llayer+".BA_AMTime", , , "False"}},
    	{"TimeCPM_*", {llayer+".AB_PMTime", llayer+".BA_PMTime", , , "False"}},
    	{"TimeCOP_*", {llayer+".AB_OPTime", llayer+".BA_OPTime", , , "False"}}}
    Opts.Global.[Length Units] = "Miles"
    Opts.Global.[Time Units] = "Minutes"
    Opts.Output.[Network File] = mc_network_file
    ret_value = RunMacro("TCB Run Operation", "Build Highway Network", Opts, &Ret)
    if !ret_value then goto quit

   for iper=1 to Periods.length do
				innet=mc_network_file
				outmat=pnr_time_mat[iper]

    // STEP 3.2: TCSPMAT - Centroids to Parking Nodes Skim
        Opts = null
        Opts.Input.Network = innet
        Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "Selection", "Select * where Centroid=1 & ID<1000"} // exclude external TAZ centroids
        Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "PNR_NODE", "Select * where [PNR_NODE]=1"}
        Opts.Input.[Via Set] = {db_nodelyr, nlayer}
        Opts.Field.Minimize = "TimeC" + Periods[iper] + "_*"
        Opts.Field.Nodes = nlayer + ".ID"
        Opts.Field.[Skim Fields]= {{"TimeC" + Periods[iper] + "_*", "All"}, {"Length", "All"}}
        Opts.Flag = {}
		Opts.Output.[Output Matrix].Label = "Shortest Path"
		Opts.Output.[Output Matrix].Compression = 1
		Opts.Output.[Output Matrix].[File Name] =  outmat
        ret_value = RunMacro("TCB Run Procedure", 3, "TCSPMAT", Opts, &Ret)
        if !ret_value then goto quit

    // STEP 3.2: Revise the times to a weighted time
        tazview = OpenTable("zones","FFB",{zone_bin,})
        hnodeview = OpenTable("hnodes","FFB",{highway_node_bin,})
        dacc = OpenMatrix(outmat,)
        midx = GetMatrixIndex(dacc)
        dacc_time_cur   = CreateMatrixCurrency(dacc, "TimeC" + Periods[iper] +"_* (Skim)", midx[1], midx[2], )
        dacc_dist_cur   = CreateMatrixCurrency(dacc, "Length (Skim)", midx[1], midx[2], )
        dacc_time_cur   := NullToZero(dacc_time_cur)
        rowID           = GetMatrixRowLabels(dacc_time_cur)
        pnrID           = GetMatrixColumnLabels(dacc_time_cur)

        for i=1 to rowID.length do
            drive_time   = GetMatrixVector(dacc_time_cur,  {{"Row", StringToInt(rowID[i])}})
            drive_distance   = GetMatrixVector(dacc_dist_cur,  {{"Row", StringToInt(rowID[i])}})
            DriveTime    = Vector(drive_time.length, "Float",)
            // identify production area type
            rh1 = LocateRecord(tazview+"|", "ID", {StringToInt(rowID[i])}, {{"Exact", "True"}})
            if rh1 <> null then ProdAType=tazview.AREA_TYPE
            if ProdAType = 1 then DrWt = 99       // no connector from CBD
            if (ProdAType = 2 | ProdAType = 3 | ProdAType = 4) then DrWt = 1.5

            for j=1 to drive_time.length do
                pnrshed = 0
                pnrcost = 0
                DriveTime[j] = null
                rh2 = LocateRecord(hnodeview+"|", nodeidfield, {StringToInt(pnrID[j])}, {{"Exact", "True"}})
                if rh2 <> null then pnrshed = hnodeview.PNR_SHED
                if rh2 <> null then pnrcost = hnodeview.PNR_COST
                if (pnrshed > 0) then do
                    if (drive_time[j] <= pnrshed) then DriveTime[j] = DrWt*drive_time[j] +
                                                                         (((AutoOperatingCost/100)/AOCC_PNR)*drive_distance[j]/ValueofTime) +
                                                                         (pnrcost/ValueofTime) +
                                                                         PNR_TerminalTime
                    if (drive_time[j] > pnrshed)  then DriveTime[j] = DrWt*pnrshed +
                                                                         DrWt*((pnrshed - drive_time[j]) + (pnrshed - drive_time[j])*(pnrshed - drive_time[j])) +
                                                                         (((AutoOperatingCost/100)/AOCC_PNR)*drive_distance[j]/ValueofTime) +
                                                                         (pnrcost/ValueofTime) +
                                                                         PNR_TerminalTime
                    if (drive_time[j] > MaxPNR_DriveTime) then DriveTime[j] = null
                    if (DriveTime[j] > 45) then DriveTime[j] = null
                end
            end
            SetMatrixVector(dacc_time_cur, DriveTime, {{"Row", StringToInt(rowID[i])}} )
        end
   end
   stime=GetDateAndTime()
   WriteLine(runtime,"\n End Build Drive Connectors           - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
   Return(1)
quit:
   stime=GetDateAndTime()
   WriteLine(runtime,"\n End Build Drive Connectors           - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
   Return(ret_value)
EndMacro

// STEP 4: Build transit paths
Macro "BuildTransitPaths"
//UpdateProgressBar("BuildTransitPaths",)
    shared outdir, Periods, Modes, AccessModes, ValueofTime, highway_dbd, route_system, nodeidfield
    shared route_stop, route_stop_bin, TerminalTimeMtx, modetable, modexfertable     // input files
    shared pnr_time_mat, runtime // output files
	  shared iper_count, iacc_count, imode_count // for quick transit skim

    RunMacro("TCB Init")

    layers = GetDBlayers(highway_dbd)
    nlayer = layers[1]
    llayer = layers[2]
    db_nodelyr = highway_dbd + "|" + nlayer
    db_linklyr = highway_dbd + "|" + llayer
	counter=Periods.length*Modes.length*AccessModes.length
	count=1


// Main loop
    for iper=1 to Periods.Length do
        for iacc=1 to AccessModes.Length do
            for imode=1 to Modes.Length do

				//UpdateProgressBar("Build transit paths Loop - "+ Periods[iper] +" - " + AccessModes[iacc] + " - "+  Modes[imode] + " -" +i2s(count)+" of " +i2s(counter),)
                outtnw = outdir.transit + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".tnw"
                outskim = outdir.transit + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".mtx"
                outtps  = outdir.transit + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".tps"

				pnr_file = pnr_time_mat[iper]

				//if imode=1 then selmode=" (Mode<>null & Mode=3)"  // local bus
				selmode=" (Mode<>null & (Mode=3 | Mode=4))"  // shuttle

				// STEP 4.1: Build Transit Network
                Opts = null
                Opts.Input.[Transit RS] = route_system
                Opts.Input.[RS Set] = {route_system + "|Transit Routes", "Transit Routes", "Routes", "Select * where HW_" + Periods[iper] + ">0 & " + selmode}
								Opts.Input.[Walk Set] = {db_linklyr, llayer}
                //Opts.Input.[Walk Set] = {db_linklyr, llayer, "Walking Links", "Select * where IN_WALK=1 | DOT_FC=98"}
                Opts.Input.[Stop Set] = {route_stop + "|Transit Stops", "Transit Stops"}
								Opts.Input.[Drive Set] = {db_linklyr, llayer}
				//Opts.Input.[Drive Set] = {db_linklyr, llayer, "Driving Links", "Select * where IN_HIGHWAY=1 | DOT_FC=98"}
                Opts.Global.[Network Label] = "Based on 'Route System'"
                Opts.Global.[Network Options].[Link Attributes] = {{"Length", {llayer + ".Length", llayer + ".Length"}, "SUMFRAC"},
                                                                   {"ID", {llayer + ".ID", llayer + ".ID"}, "SUMFRAC"},
                                                                   {"TimeCAM_*", {llayer + ".AB_AMTime", llayer + ".BA_AMTime"}, "SUMFRAC"},
                                                                   {"TimeCPM_*", {llayer + ".AB_PMTime", llayer + ".BA_PMTime"}, "SUMFRAC"},
                                                                   {"TimeCOP_*", {llayer + ".AB_OPTime", llayer + ".BA_OPTime"}, "SUMFRAC"},
                                                                   {"WalkTime", {llayer + ".WalkTime", llayer + ".WalkTime"}, "SUMFRAC"},
                                                                   {"TransitTimeAM_*", {llayer + ".TransitTimeAM_AB", llayer + ".TransitTimeAM_BA"}, "SUMFRAC"},
																   {"TransitTimePM_*", {llayer + ".TransitTimePM_AB", llayer + ".TransitTimePM_BA"}, "SUMFRAC"},
                                                                   {"TransitTimeOP_*", {llayer + ".TransitTimeOP_AB", llayer + ".TransitTimeOP_BA"}, "SUMFRAC"}}
                Opts.Global.[Network Options].[Street Attributes].Length = {llayer + ".Length", llayer + ".Length"}
                Opts.Global.[Network Options].[Street Attributes].ID = {llayer + ".ID", llayer + ".ID"}
                Opts.Global.[Network Options].[Street Attributes].[TimeCAM_*] = {llayer + ".AB_AMTime", llayer + ".BA_AMTime"}
                Opts.Global.[Network Options].[Street Attributes].[TimeCPM_*] = {llayer + ".AB_PMTime", llayer + ".BA_PMTime"}
                Opts.Global.[Network Options].[Street Attributes].[TimeCOP_*] = {llayer + ".AB_OPTime", llayer + ".BA_OPTime"}
                Opts.Global.[Network Options].[Street Attributes].WalkTime = {llayer + ".WalkTime", llayer + ".WalkTime"}
                Opts.Global.[Network Options].[Street Attributes].[TransitTimeAM_*] = {llayer + ".TransitTimeAM_AB", llayer + ".TransitTimeAM_BA"}
                Opts.Global.[Network Options].[Street Attributes].[TransitTimePM_*] = {llayer + ".TransitTimePM_AB", llayer + ".TransitTimePM_BA"}
                Opts.Global.[Network Options].[Street Attributes].[TransitTimeOP_*] = {llayer + ".TransitTimeOP_AB", llayer + ".TransitTimeOP_BA"}
                Opts.Global.[Network Options].[Route Attributes].Route_ID = {"[Transit Routes].Route_ID"}
                Opts.Global.[Network Options].[Route Attributes].Direction = {"[Transit Routes].Direction"}
                Opts.Global.[Network Options].[Route Attributes].Track = {"[Transit Routes].Route"}
                Opts.Global.[Network Options].[Route Attributes].Distance = {"[Transit Routes].Length"}
                Opts.Global.[Network Options].[Route Attributes].AM_HDWY = {"[Transit Routes].HW_AM"}
                Opts.Global.[Network Options].[Route Attributes].PM_HDWY = {"[Transit Routes].HW_PM"}
                Opts.Global.[Network Options].[Route Attributes].OP_HDWY = {"[Transit Routes].HW_OP"}
                Opts.Global.[Network Options].[Route Attributes].Mode = {"[Transit Routes].Mode"}
				Opts.Global.[Network Options].[Route Attributes].Fare = {"[Transit Routes].Fare"}
                Opts.Global.[Network Options].[Route Attributes].FareType = {"[Transit Routes].FareType"}
                Opts.Global.[Network Options].[Stop Attributes] = {{"ID", {"[Transit Stops].ID"}},
                                                                   {"Longitude", {"[Transit Stops].Longitude"}},
                                                                   {"Latitude", {"[Transit Stops].Latitude"}},
                                                                   {"Route_ID", {"[Transit Stops].Route_ID"}},
                                                                   {"Pass_Count", {"[Transit Stops].Pass_Count"}},
                                                                   {"Milepost", {"[Transit Stops].Milepost"}},
                                                                   {"STOP_ID", {"[Transit Stops].STOP_ID"}},
                                                                   {"NearNode", {"[Transit Stops].NearNode"}}}
                Opts.Global.[Network Options].[Street Node Attributes].ID = {nlayer + ".ID"}
				//Opts.Global.[Network Options].[Street Node Attributes].ID = {nlayer + "."+nodeidfield}       //test
                //Opts.Global.[Network Options].[Street Node Attributes].CCSTYLE = {nlayer + ".Centroid"}             // todo - functional class for node to identify centroids?
                Opts.Global.[Network Options].Walk = "Yes"
                Opts.Global.[Network Options].[Mode Field] = "[Transit Routes].Mode"
                Opts.Global.[Network Options].[Walk Mode] = llayer + ".WalkLink"
                Opts.Global.[Network Options].TagField = "NearNode"
                Opts.Global.[Network Options].Overide = {"[Transit Stops].ID", "Transit Stops.NearNode"}
                Opts.Output.[Network File] = outtnw

                ret_value = RunMacro("TCB Run Operation", "Build Transit Network", Opts, &Ret)
                if !ret_value then goto quit

            // STEP 3.2: Transit Network Setting PF
                Opts = null
								Opts.Global.[Class Names] = {"Class 1"}
								Opts.Global.[Class Description] = {"Class 1"}
								Opts.Global.[current class] = "Class 1"

                Opts.Input.[Transit RS] = route_system
                Opts.Input.[Transit Network] = outtnw
                Opts.Input.[Mode Table] = {modetable}
                Opts.Input.[Mode Cost Table] = {modexfertable}

                if AccessModes[iacc]="Drive" then do
                  Opts.Input.[OP Time Currency] = {pnr_file, "TimeC" + Periods[iper] + "_* (Skim)", , } 		// origin to parking node time matrix info
                  Opts.Input.[OP Dist Currency] = {pnr_file, "Length (Skim)", , }  													// origin to parking node distance matrix info
                  Opts.Input.[Driving Link Set] = {db_linklyr, llayer, "Selection", "Select * where (AB_" + Periods[iper] + "Time+BA_" + Periods[iper] +"Time)<>null"}
                end

                Opts.Input.[Centroid Set] = {db_nodelyr, nlayer, "AllZones", "Select * where Centroid=1"}
                Opts.Field.[Link Impedance] = "TransitTime"+Periods[iper]+"_*"

                if AccessModes[iacc]="Drive" then do
                  Opts.Field.[Link Drive Time] = "TimeC"+Periods[iper]+"_*"
                end

                Opts.Field.[Route Headway] 		  = Periods[iper] + "_HDWY"
				Opts.Field.[Route Fare] 		  = "Fare"
                //Opts.Field.[Mode Fare]            = "FARE"
                Opts.Field.[Mode Imp Weight]      = Periods[iper]+"_LNKIMP"
                Opts.Field.[Mode IWait Weight]    = "WAIT_IW"
                Opts.Field.[Mode XWait Weight]    = "WAIT_XW"
                Opts.Field.[Mode Dwell Weight]    = "DWELL_W"
                Opts.Field.[Mode Max IWait]       = "MAX_WAIT"
                Opts.Field.[Mode Min IWait]       = "MIN_WAIT"
                Opts.Field.[Mode Max XWait]       = "MAX_WAIT"
                Opts.Field.[Mode Min XWait]       = "MIN_WAIT"
                Opts.Field.[Mode Max Access]      = "MAX_ACCESS"
                Opts.Field.[Mode Max Egress]      = "MAX_EGRESS"
                Opts.Field.[Mode Max Transfer]    = "MAX_XFER"
                Opts.Field.[Mode Max Imp]         = "MAX_TIME"
                Opts.Field.[Mode Impedance]       = Periods[iper]+"_IMP"
                Opts.Field.[Mode Used]            = "MODE_USED"
                Opts.Field.[Mode Access]          = "MODE_ACC"
                Opts.Field.[Mode Egress]          = "MODE_EGR"
                Opts.Field.[Inter-Mode Xfer From] = "FROM"
                Opts.Field.[Inter-Mode Xfer To]   = "TO"
                Opts.Field.[Inter-Mode Xfer Time] = "XFER_PEN"
                Opts.Field.[Inter-Mode Xfer Fare] = "XFER_FARE"
                Opts.Global.[Global Fare Type] = 1
                Opts.Global.[Global Fare Value] = 1.50
                Opts.Global.[Global Xfer Fare] = 1.50
                Opts.Global.[Global Max WACC Path] = 50
                Opts.Global.[Global Max PACC Path] = 5
                Opts.Global.[Path Method] = 3
                Opts.Global.[Path Threshold] = 0.7	// original 0.7
                Opts.Global.[Value of Time] = ValueofTime
                Opts.Global.[Max Xfer Number] = 4
                Opts.Global.[Max Trip Time] = 240
                Opts.Global.[Max Drive Time] = 45                     // this is weighted drive time
                Opts.Global.[Walk Weight] = 2.5
                Opts.Global.[Drive Time Weight] = 1.0                 // already weighted
				Opts.Global.[Global Dwell On Time] = 0
				Opts.Global.[Global Dwell Off Time] = 0
                Opts.Flag.[Use All Walk Path] = "Yes"
                if AccessModes[iacc]="Drive" then do
					Opts.Flag.[Use All Walk Path] = "No"
					Opts.Flag.[Use Park and Ride] = "Yes"
					Opts.Flag.[Use P&R Walk Access] = "No"
				end
				else do
					Opts.Flag.[Use Park and Ride] = "No"
                end

                Opts.Global.[Global Layover Time] = 0
                Opts.Flag.[Use Mode] = "Yes"
                Opts.Flag.[Use Mode Cost] = "Yes"
                Opts.Flag.[Combine By Mode] = "Yes"
                Opts.Flag.[Fare System] = 1

                ret_value = RunMacro("TCB Run Operation", "Transit Network Setting PF", Opts, &Ret)
                if !ret_value then goto quit

            // STEP 4.3: Update the transit network with layover times / dwell times
                Opts = null
                Opts.Input.[Transit RS] = route_system
                Opts.Input.Network = outtnw
                Opts.Input.[OD Matrix Currency] = {outdir.transit + "zone.mtx", "Matrix 1", , }
                Opts.Output.[Flow Table] = outdir.transit + Periods[iper] + AccessModes[iacc] + Modes[imode] + "PreloadFlow.bin"
                Opts.Output.[Walk Flow Table] = outdir.transit + Periods[iper] + AccessModes[iacc] + Modes[imode] + "PreloadWalkFlow.bin"
                ret_value = RunMacro("TCB Run Procedure", 2, "Transit Assignment PF", Opts, &Ret)
                if !ret_value then goto quit

            // STEP 4.3.1 Fill Stop layer BaseIVTT variable with results of preload ivtt (add the layover time coded in the stop layer)
                Opts = null
                Opts.Input.[Dataview Set] = {{route_stop + "|Transit Stops", outdir.transit + Periods[iper]+AccessModes[iacc]+Modes[imode]+"PreloadFlow.bin", "ID", "FROM_STOP"}, "Route Stops"+"RouteSystem"+Periods[iper]+"Prel"}
                Opts.Global.Fields = {Periods[iper] + AccessModes[iacc] + Modes[imode] + "IVTT"}
                Opts.Global.Method = "Formula"
                Opts.Global.Parameter = "BaseIVTT + Layover + [DwellTime_" + Periods[iper] +"]"  // Added dwell time to make sure IVTT in skims include dwell time
                ret_value = RunMacro("TCB Run Operation", 7, "Fill Dataview", Opts, &Ret)
                if !ret_value then goto quit

			thisIVTT = Periods[iper]+AccessModes[iacc]+Modes[imode]+"IVTT"

			RunMacro("TCB Init")
			Opts = null
			Opts.Input.[Transit RS] = route_system
			Opts.Input.[Stop View] = {route_stop+"|Transit Stops", "Transit Stops"}
			Opts.Input.Network = outtnw
			Opts.Global.[Update Attributes].[Stop Attributes].(thisIVTT) = {"[Transit Stops]."+thisIVTT}
			ret_value = RunMacro("TCB Run Operation", "Update Transit Network Attributes", Opts, &Ret)
			if !ret_value then goto quit

            // NOTE: In-vehicle time in the transit networks includes IVTT and layover (no dwelling time) -> this is done for skimming purposes in order to count
            //     : dwelling time just once in the generalized cost

            // STEP 4.4: Transit Skim PF
                timevar = "TransitTime"+Periods[iper]+"_*"

                Opts = null
                Opts.Input.Database = highway_dbd
				Opts.Input.[Transit RS] = route_system
                Opts.Input.Network = outtnw

                Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "AllZones", "Select * where Centroid=1"}
                Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "AllZones"}
                Opts.Global.[Skim Var] = {"Generalized Cost", "Fare", "In-Vehicle Time", "Initial Wait Time", "Transfer Wait Time", "Transfer Penalty Time",
                                          "Transfer Walk Time", "Access Walk Time", "Egress Walk Time", "Access Drive Time", "Dwelling Time",
                                          "Number of Transfers", "In-Vehicle Distance", "Drive Distance", timevar}   // Number of Transfers are converted to Number of Boardings later

                Opts.Global.[OD Layer Type] = "Node"
                Opts.Global.[Skim Modes] = {3, 4}
                Opts.Output.[Skim Matrix].Label = Periods[iper] + AccessModes[iacc] + Modes[imode] + " (Skim)"
                Opts.Output.[Skim Matrix].Compression = 0
                Opts.Output.[Skim Matrix].[File Name] = outskim

                if AccessModes[iacc]="Drive" then do
					Opts.Output.[OP Matrix].Label = "Origin to Parking Matrix"
					Opts.Output.[OP Matrix].[File Name]= outdir.transit + Periods[iper] + AccessModes[iacc] + Modes[imode] + "_pnr_time.mtx"
					Opts.Output.[Parking Matrix].Label = "Parking Matrix"
					Opts.Output.[Parking Matrix].[File Name] = outdir.transit + Periods[iper] + AccessModes[iacc] + Modes[imode] + "_pnr_node.mtx"
                end

				Opts.Output.[TPS Table] = outtps

                ret_value = RunMacro("TCB Run Procedure", "Transit Skim PF", Opts, &Ret)
                if !ret_value then goto quit

            // STEP 5: Calculate boardings as xfers+1
                Opts = null
                Opts.Input.[Matrix Currency] = { outskim, "Number of Transfers",,}
                Opts.Global.Method = 11
                Opts.Global.[Cell Range] = 2
                Opts.Global.[Expression Text] = "[Number of Transfers]+ 1"
                Opts.Global.[Force Missing] = "No"
                ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)
                if !ret_value then goto quit

								count=count+1

             end  // end mode loop
         end  // end access mode loop
     end  // end period loop

    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Build Transit Paths Loop       - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    ret_value=1

quit:
		//Return( RunMacro("TCB Closing", ret_value, True ) )
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Build Transit Paths QuitMsg       - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

Macro "AddFields"
	shared highway_dbd, highway_link_bin, highway_node_bin, zone_dbd, zone_bin, route_system
    shared route_stop, route_stop_bin, route_bin
	shared modetable, modexfertable, MovementTable

/* on notfound goto quit  */
    view_name = OpenTable ("hwy_bin","FFB",{highway_link_bin,})

WalkLink:
    on notfound goto WalkLinkIn

		// check if walk fields are present in the highway link layer
    GetField(view_name+".WalkLink")

    goto TransitTime

WalkLinkIn:
		// add walk fields to the highway link table
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end

    new_struct = strct + {{"WalkLink", "Integer", 10, 0, "False",,,, null},
                          {"LinkTTF", "Integer", 10, 0, "False",,,, null},
                          {"WalkTime", "Real", 10, 4, "False",,,, null}}
    ModifyTable(view_name, new_struct)

TransitTime:
    on notfound goto TransitTimeIn

		// check if transit time fields are present in the highway link layer
    GetField(view_name+".TransitTimeAM_AB")
    goto AutoTime

TransitTimeIn:
		// add transit time fields to the highway link table
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end

    new_struct = strct + {{"TransitTimeAM_AB", "Real", 10, 4, "False",,,, null},
                          {"TransitTimeAM_BA", "Real", 10, 4, "False",,,, null},
							{"TransitTimePM_AB", "Real", 10, 4, "False",,,, null},
                          {"TransitTimePM_BA", "Real", 10, 4, "False",,,, null},
                          {"TransitTimeOP_AB", "Real", 10, 4, "False",,,, null},
                          {"TransitTimeOP_BA", "Real", 10, 4, "False",,,, null}}

		ModifyTable(view_name, new_struct)

AutoTime:
		on notfound goto AutoTimeIn

		// check if transit time fields are present in the highway link layer
    GetField(view_name+".AB_AMTime")
    goto MilepostLastStop

AutoTimeIn:
		// add transit time fields to the highway link table
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end

    new_struct = strct + {{"AB_AMTime", "Real", 10, 4, "False",,,, null},
                          {"BA_AMTime", "Real", 10, 4, "False",,,, null},
						  {"AB_PMTime", "Real", 10, 4, "False",,,, null},
                          {"BA_PMTime", "Real", 10, 4, "False",,,, null},
                          {"AB_OPTime", "Real", 10, 4, "False",,,, null},
                          {"BA_OPTime", "Real", 10, 4, "False",,,, null}}

		ModifyTable(view_name, new_struct)

MilepostLastStop:
	CloseView(view_name)
	// open route stops
	view_name = OpenTable ("stop_bin","FFB",{route_stop_bin,})

	on notfound goto MilepostLastStopIn
	GetField(view_name+".MP_LastStop")
	goto DistanceLastStop

MilepostLastStopIn:
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end
		new_struct = strct
		newfield = "MP_LastStop"
		new_struct = new_struct + {{newfield, "Real", 10, 4, "False",,,, null}}

    ModifyTable(view_name, new_struct)

DistanceLastStop:
	on notfound goto DistanceLastStopIn
	GetField(view_name+".Distance_LastStop")
	goto CalculateDistanceLastStop

DistanceLastStopIn:
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end
		new_struct = strct
		newfield = "Distance_LastStop"
		new_struct = new_struct + {{newfield, "Real", 10, 4, "False",,,, null}}

    ModifyTable(view_name, new_struct)

CalculateDistanceLastStop:
	CloseView(view_name)
	// Calculate distance from last stop
	Stopdb_layers = GetDBLayers(route_stop)
	Stopview=AddLayertoWorkspace("Stopview", route_stop, Stopdb_layers[1])
	SetLayer(Stopview)

	// selection set
	nrecs=SelectByQuery("sorted_set", "Several", "Select * where Route_ID>0")

	// sort by route_id and milepost
	SortSet("sorted_set","Route_ID, Milepost")

	// get route_id and milepost
	MPStop=GetDataVectors("sorted_set",{"Route_ID","Milepost"},)

	// initialize variables
	dim MPLastStop[MPStop[1].Length]
	RouteID_prev=0

	// populate an array with MP of previous stop
	for i=1 to MPStop[1].Length do
		RouteID=MPStop[1][i]
		if (i=1 | RouteID!=RouteID_prev) then MPLastStop[i]=MPStop[2][i]
		else MPLastStop[i]=MPStop[2][i-1]
		RouteID_prev=RouteID
	end

	// convert to array
	MPLastStopVec=ArrayToVector(MPLastStop)

	//calculate distance from previous stop
	DistanceLastStop=MPStop[2]-MPLastStopVec

	// Fill fields
	SetDataVectors("sorted_set", {{"MP_LastStop", MPLastStopVec},{"Distance_LastStop", DistanceLastStop}}, )

	// remove layer from workspace
	DropLayerFromWorkSpace(Stopview)

Skip:
	// finished adding fields
	ret_value=1

EndMacro


 // Post Process Transit Skim Matrices for Mode Choice Model & Compress Skims
 Macro "ProcessTransitSkims"(Args)
    shared outdir, Periods, Modes, AccessModes

    //  Define Parameters
    DeleteTempOutputFiles = 0

    RunMacro("TCB Init")

    // STEP 3: Copy Transit Skims
    for iper=1 to Periods.length do
	    for iacc=1 to AccessModes.Length do
        for imode=1 to Modes.Length do
           inmat  = outdir.transit + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".mtx"
           outmat = outdir.transit + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"
           new_mat = CopyFile(inmat,outmat)
         end   // transit mode
      end    // access mode
    end    // period


  // STEP 4: Set Null values to Zero, Also Zero-Out skim tables based on path hierarchy
  for iper=1 to Periods.length do
	  for iacc=1 to AccessModes.Length do
      for imode=1 to Modes.Length do

		        timevar = "TransitTime"+Periods[iper]+"_*"
                m = OpenMatrix(outdir.transit + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx", )

                mc1 = CreateMatrixCurrency(m, "Generalized Cost", , , )
                mc2 = CreateMatrixCurrency(m, "Fare", , , )
                mc3 = CreateMatrixCurrency(m, "In-Vehicle Time", , , )
                mc4 = CreateMatrixCurrency(m, "Initial Wait Time", , , )
                mc5 = CreateMatrixCurrency(m, "Transfer Wait Time", , , )
                mc6 = CreateMatrixCurrency(m, "Transfer Penalty Time", , , )
                mc7 = CreateMatrixCurrency(m, "Transfer Walk Time", , , )
                mc8 = CreateMatrixCurrency(m, "Access Walk Time", , , )
                mc9 = CreateMatrixCurrency(m, "Egress Walk Time", , , )
                mc10 = CreateMatrixCurrency(m, "Access Drive Time", , , )
                mc11 = CreateMatrixCurrency(m, "Dwelling Time", , , )
                mc12 = CreateMatrixCurrency(m, "Number of Transfers", , , )
                mc13 = CreateMatrixCurrency(m, "In-Vehicle Distance", , , )
                mc14 = CreateMatrixCurrency(m, "Access Drive Distance", , , )
                mc15 = CreateMatrixCurrency(m, timevar + " (Local Bus)", , , )
				mc16 = CreateMatrixCurrency(m, timevar + " (Shuttle)", , , )

                mc1 := Nz(mc1)
                mc2 := Nz(mc2)
                mc3 := Nz(mc3)
                mc4 := Nz(mc4)
                mc5 := Nz(mc5)
                mc6 := Nz(mc6)
                mc7 := Nz(mc7)
                mc8 := Nz(mc8)
                mc9 := Nz(mc9)
                mc10 := Nz(mc10)
                mc11 := Nz(mc11)
                mc12 := Nz(mc12)
                mc13 := Nz(mc13)
                mc14 := Nz(mc14)
                mc15 := Nz(mc15)
				mc16 := Nz(mc16)

                if (Modes[imode]="Local") then do
					mc1 := if ((mc15) <= 0) then 0 else mc1
					mc2 := if ((mc15) <= 0) then 0 else mc2
					mc3 := if ((mc15) <= 0) then 0 else mc3
					mc4 := if ((mc15) <= 0) then 0 else mc4
					mc5 := if ((mc15) <= 0) then 0 else mc5
					mc6 := if ((mc15) <= 0) then 0 else mc6
					mc7 := if ((mc15) <= 0) then 0 else mc7
					mc8 := if ((mc15) <= 0) then 0 else mc8
					mc9 := if ((mc15) <= 0) then 0 else mc9
					mc10 := if ((mc15) <= 0) then 0 else mc10
					mc11 := if ((mc15) <= 0) then 0 else mc11
					mc12 := if ((mc15) <= 0) then 0 else mc12
					mc13 := if ((mc15) <= 0) then 0 else mc13
					mc14 := if ((mc15) <= 0) then 0 else mc14
					mc15 := if ((mc15) <= 0) then 0 else mc15
					mc16 := if ((mc15) <= 0) then 0 else mc16

                   FillMatrix(mc2, null, null, {"Multiply", 100}, )
                end

				if (Modes[imode]="Shuttle") then do
					mc1 := if ((mc16) <= 0) then 0 else mc1
					mc2 := if ((mc16) <= 0) then 0 else mc2
					mc3 := if ((mc16) <= 0) then 0 else mc3
					mc4 := if ((mc16) <= 0) then 0 else mc4
					mc5 := if ((mc16) <= 0) then 0 else mc5
					mc6 := if ((mc16) <= 0) then 0 else mc6
					mc7 := if ((mc16) <= 0) then 0 else mc7
					mc8 := if ((mc16) <= 0) then 0 else mc8
					mc9 := if ((mc16) <= 0) then 0 else mc9
					mc10 := if ((mc16) <= 0) then 0 else mc10
					mc11 := if ((mc16) <= 0) then 0 else mc11
					mc12 := if ((mc16) <= 0) then 0 else mc12
					mc13 := if ((mc16) <= 0) then 0 else mc13
					mc14 := if ((mc16) <= 0) then 0 else mc14
					mc15 := if ((mc16) <= 0) then 0 else mc15
					mc16 := if ((mc16) <= 0) then 0 else mc16

					FillMatrix(mc2, null, null, {"Multiply", 100}, )

				end
	      end
	   end
  end

	if (DeleteTempOutputFiles = 1) then do
		batch_ptr = OpenFile(outdir.transit + "deletefiles.bat", "w")
		WriteLine(batch_ptr, "REM temp transit skim files")
		WriteLine(batch_ptr, "del " + outdir.transit + "??_WalkLocal.mtx")
		//WriteLine(batch_ptr, "del " + outdir.transit + "??_DriveLocal.mtx")
		WriteLine(batch_ptr, "del " + outdir.transit + "??_WalkShuttle.mtx")
		//WriteLine(batch_ptr, "del " + outdir.transit + "??_DriveShuttle.mtx")
		WriteLine(batch_ptr, "REM temp files from path building")
		WriteLine(batch_ptr, "del " + outdir.transit + "*.tps")
		WriteLine(batch_ptr, "del " + outdir.transit + "*_pnr_time.mtx")
		WriteLine(batch_ptr, "del " + outdir.transit + "*_pnr_node.mtx")
		WriteLine(batch_ptr, "REM temp files from the preliminary transit assignment for calculating the travel times")
		WriteLine(batch_ptr, "del " + outdir.transit + "*PreloadFlow.bin")
		WriteLine(batch_ptr, "del " + outdir.transit + "*PreloadFlow.dcb")
		WriteLine(batch_ptr, "del " + outdir.transit + "*PreloadWalkFlow.bin")
		WriteLine(batch_ptr, "del " + outdir.transit + "*PreloadWalkFlow.dcb")
		CloseFile(batch_ptr)
		RunProgram(outdir.transit + "deletefiles.bat", )
    end
  Return(1)
quit:
  Return(ret_value)
EndMacro

Macro "CopyTransitSkims"
    shared Scen_Dir, outdir, Periods, Modes, AccessModes, loop
    shared runtime // output files

    // Export only Walk Transit Skims
    counter=Periods.length*Modes.length
    count=1

		//for debug
	loop=info.iter

    for iper=1 to Periods.Length do
        for imode=1 to Modes.Length do
            //UpdateProgressBar("saving skims - "+ Periods[iper] +" - " + "Walk" + " - "+  Modes[imode] + " -" +i2s(count)+" of " +i2s(counter),)

            inMat = outdir.transit + Periods[iper] + "_" + "Walk" + Modes[imode] + "Skim.mtx"

            //copy loop specific skims
            outMat = outdir.transit + Periods[iper] + "_" + "Walk" + Modes[imode] + "Skim_" + String(loop) + ".mtx"
            CopyFile(inMat, outMat)

            count=count+1
        end
    end

EndMacro
