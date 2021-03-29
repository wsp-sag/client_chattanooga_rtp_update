/*
 Transit Assignment
 Intial scripts are borrowed from the Nashville ABM
 Implemented by nagendra.dhakar@rsginc.com
 Date: 10/20/2015
*/

// STEP 8; Perform transit assignment
Macro "TransitAssignment"(Args)
    shared outdir, Modes, AccessAssgnModes, route_system, MovementTable, Periods // input files
    shared runtime // output files
    
    //Periods={"AM","PM","OP"} - for three time periods
	
    RunMacro("TCB Init")
    RunMacro("SetTransitParameters",Args)
    
// STEP 1: Perform Transit Assignment

	// assignment by time period and mode
    for iper=1 to Periods.length do
		for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
				
				// only for walk			
				AccessNet="Walk"
				
				// set transit network (outtnw), demand matrix (inmat), and core in the matrix (tablename)
				outtnw= outdir.transit + Periods[iper] + "_" + AccessNet + Modes[imode] + ".tnw"
				inmat = outdir.tables + "TransitTrip_" + Periods[iper] + ".mtx"
				tablename = Modes[imode]			
				
				// assignment options
				Opts = null
				Opts.Input.[Transit RS] = route_system
				Opts.Input.Network = outtnw
				Opts.Input.[OD Matrix Currency] = {inmat, tablename, "Origin", "Destination"}
				Opts.Input.[Movement Set] = {MovementTable, "MovementTable"}
				Opts.Flag.[Do OnOff Report]=1
				Opts.Flag.[Do Aggre Report]=1
				Opts.Output.[Flow Table] = outdir.transit + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "Flow.bin"
				Opts.Output.[Walk Flow Table] = outdir.transit + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "WalkFlow.bin"
				Opts.Output.[Aggre Table] = outdir.transit + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "AggreFlow.bin"
				Opts.Output.[OnOff Table] = outdir.transit + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "OnOffFlow.bin"
				Opts.Output.[Movement Table] = outdir.transit + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "MOV.bin"

				ret_value = RunMacro("TCB Run Procedure", 2, "Transit Assignment PF", Opts, &Ret)
				if !ret_value then goto quit
			end
		end
    end

    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Assignment               - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(1)
quit:
	// RunMacro("TCB Closing", ret_value, True )
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Assignment               - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

// STEP 9: Transit reporting
Macro "TransitReport" (Args)
    shared outdir, Modes, AccessAssgnModes, route_system, MovementTable, Periods // input files
	shared runtime
    RunMacro("TCB Init")

	// for assignment use only walk
    //AccessAssgnModes = {"Walk"}	
	//RunMacro("SetTransitParameters",Args)

// STEP 10.1: Macro to fill the Transit Flow files with PH and PM
    ret_value = RunMacro("Fill_TASN_FLW_File",)
    if !ret_value then goto quit

// STEP 10.2: Macro to run transit summary by route - PH, PM and Boarding by purpose and access types
    ret_value = RunMacro("Rte_PH_PM",)
    if !ret_value then goto quit

    ret_value = RunMacro("Rte_boarding",)
    if !ret_value then goto quit

// STEP 10.3: Macro to output Mode Choice Statistics
    ret_value = RunMacro("TRNSTAT",)
    if !ret_value then goto quit

// STEP 10.4: Macro to output boarding summary at route- and stop-levels
    ret_value = RunMacro("Stop_Level_Summary",)
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Reporting                - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    if !ret_value then goto quit

// clean up the output folder - delete temperory files
    if (DeleteTempOutputFiles = 1) then do
        batch_ptr = OpenFile(outdir.transit + "deletefiles.bat", "w")
        WriteLine(batch_ptr, "REM temp files from percent walk procedure")
        WriteLine(batch_ptr, "del " + OutDir + "*buffer*")
				
        if (DeleteSummitFiles = 1) then do
					WriteLine(batch_ptr, "del " + OutDir + "*.fta")
        end
				
        WriteLine(batch_ptr, "REM temp files from the transit assignment")
        WriteLine(batch_ptr, "del " + outdir.transit + "*OnOffFlow.bin")
        WriteLine(batch_ptr, "del " + outdir.transit + "*OnOffFlow.dcb")
        WriteLine(batch_ptr, "del " + outdir.transit + "*MOV.bin")
        WriteLine(batch_ptr, "del " + outdir.transit + "*MOV.dcb")
        WriteLine(batch_ptr, "del " + outdir.transit + "*WalkFlow.bin")
        WriteLine(batch_ptr, "del " + outdir.transit + "*WalkFlow.dcb")
        WriteLine(batch_ptr, "del " + outdir.transit + "*AggreFlow.bin")
        WriteLine(batch_ptr, "del " + outdir.transit + "*AggreFlow.dcb")
        WriteLine(batch_ptr, "del " + outdir.transit + "*LocalFlow.bin")
        WriteLine(batch_ptr, "del " + outdir.transit + "*LocalFlow.dcb")
        CloseFile(batch_ptr)
        RunProgram(outdir.transit + "deletefiles.bat", )
        PutInRecycleBin(outdir.transit + "deletefiles.bat")
    end

quit:
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Reporting                - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

// STEP 10.1: Macro to fill the Transit Flow files with PH and PM
Macro "Fill_TASN_FLW_File"
    shared outdir, Modes, AccessAssgnModes, Periods

	RunMacro("CloseAll")
	
	// for assignment use only walk
    //AccessAssgnModes = {"Walk"}
	
    nfiles=Periods.length*AccessAssgnModes.length*Modes.Length
    dim TransitFlowFile[nfiles]
    k1=1
    for iper=1 to Periods.length do
		for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
				TransitFlowFile[k1]=Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]+"Flow.bin"     //AMWalkLocalFlow.bin
				k1=k1+1
			end
		end
    end

	for k = 1 to TransitFlowFile.length do
		view_name = OpenTable ("TASN_FLW","FFB",{outdir.transit + TransitFlowFile[k],})

		on notfound goto PHCalc
		GetField(view_name+".PH")
		goto skip1

PHCalc:
		strct = GetTableStructure(view_name)
		for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end
		// Add the required fields
		new_struct = strct + {{"PH", "Real", 10, 4, "False",,,,,,, null},
					  {"PM", "Real", 10, 4, "False",,,,,,, null}}

		ModifyTable(view_name, new_struct)
skip1:
	    RunMacro("TCB Init")
	    view_name = OpenTable ("TASN_FLW","FFB",{outdir.transit + TransitFlowFile[k],})

	    Opts = null
	    Opts.Input.[Dataview Set] = {outdir.transit + TransitFlowFile[k], "TASN_FLW"}
	    Opts.Global.Fields = {view_name + ".PH", view_name + ".PM"}
	    Opts.Global.Method = "Formula"
	    Opts.Global.Parameter = {"(BaseIVTT/60)*TransitFlow", "((TO_MP-FROM_MP)*TransitFlow)", "1"}

	    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
	    if !ret_value then goto quit
	end
    Return(1)
quit:
    Return(ret_value)
EndMacro


// STEP 10.2: Macro to run transit summary by route - PH, PM by purpose and access types
Macro "Rte_PH_PM"
    shared outdir, Modes, AccessAssgnModes, route_bin, Periods

    Global phpm_view
    Global num_routes, list_num
    Global sumph, sumpm
	Global rtehram, rtemiam, rtehrmd, rtemimd, rtehrpm, rtemipm, rtehrop, rtemiop

	// for assignment use only walk
    //AccessAssgnModes = {"Walk"}
	
	nfiles=Periods.length*AccessAssgnModes.length*Modes.Length
	nroutes = 500
    dim route_id_list[nroutes], route_name_list[nroutes],route_modeid_list[nroutes],route_amhdwy_list[nroutes],route_mdhdwy_list[nroutes],route_pmhdwy_list[nroutes],route_ophdwy_list[nroutes]
    dim route_fare_list[nroutes],route_dir_list[nroutes],route_track_list[nroutes],sumph[nroutes], sumpm[nroutes]
	dim rtehram[nroutes], rtemiam[nroutes], rtehrmd[nroutes], rtemimd[nroutes], rtehrpm[nroutes], rtemipm[nroutes], rtehrop[nroutes], rtemiop[nroutes]
    dim Transit_flow_file[nfiles]

    RunMacro("TCB Init")

//  These files are the output of Transit Assignment
    k1=1
    for iper=1 to Periods.length do
		for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
				Transit_flow_file[k1]=Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]+"Flow.bin"
				k1=k1+1
			end
		end
    end

//   Initializing matrix to zero
    for mmm=1 to route_id_list.Length do
		rtehram[mmm]=0
		rtemiam[mmm]=0
		rtehrmd[mmm]=0
		rtemimd[mmm]=0
		rtehrpm[mmm]=0
		rtemipm[mmm]=0
		rtehrop[mmm]=0
		rtemiop[mmm]=0
		sumph[mmm]=0
		sumpm[mmm]=0
    end

    route_info_view = OpenTable("route_info_view","FFB",{route_bin,})
    view_set1 = route_info_view + "|"
    nrec1 = GetRecordCount(route_info_view,null)
    rec1=GetFirstRecord(view_set1, null)
    num_routes = 0
    While rec1 <> null do
            num_routes = num_routes + 1
            route_id_list[num_routes] = route_info_view.Route_ID
            route_name_list[num_routes] = route_info_view.Route_Name
            route_amhdwy_list[num_routes] = route_info_view.HW_AM
			route_pmhdwy_list[num_routes] = route_info_view.HW_PM
            route_ophdwy_list[num_routes] = route_info_view.HW_OP
            route_modeid_list[num_routes] = route_info_view.Mode
            route_fare_list[num_routes] = route_info_view.Fare
            route_dir_list[num_routes] = route_info_view.Direction
            route_track_list[num_routes] = route_info_view.Route //todo - modify the variable name

            rec1 = GetNextRecord(view_set1, null, null)
    end

    for trn_asn_file = 1 to Transit_flow_file.length do
        TransitFlowFile = outdir.transit + Transit_flow_file[trn_asn_file]
        trn_flow_view = OpenTable("trn_flow_view","FFB",{TransitFlowFile,})
        view_set = trn_flow_view + "|"
				
		// for each route id add the pax miles and pax hours between stops
        for m = 1 to num_routes do
            rec=GetFirstRecord(view_set, null)
//        route_id_list[m] = S2I(route_id_list[m])
			While rec <> null do
				if (trn_flow_view.ROUTE = route_id_list[m]) then do
				
					if (trn_asn_file = 1) then do                           
					    rtehram[m] = rtehram[m] + trn_flow_view.BaseIVTT
					    rtemiam[m] = trn_flow_view.TO_MP
					end
					if (trn_asn_file = 2) then do                          
					    rtehrpm[m] = rtehrpm[m] + trn_flow_view.BaseIVTT
					    rtemipm[m] = trn_flow_view.TO_MP
					end					
					if (trn_asn_file = 3) then do   							
					    rtehrop[m] = rtehrop[m] + trn_flow_view.BaseIVTT
					    rtemiop[m] = trn_flow_view.TO_MP
					end
					
					sumph[m] = sumph[m] + trn_flow_view.PH
					sumpm[m] = sumpm[m] + trn_flow_view.PM
				end
				rec = GetNextRecord(view_set, null, null)
		    end
	    end
	end
    Return(1)
endMacro



// STEP 10.2: Macro to run transit summary by route - Boarding by purpose and access types
Macro "Rte_boarding"
    shared outdir, Modes, AccessAssgnModes, route_bin, Periods                     

    nfiles=Periods.length*AccessAssgnModes.length*Modes.length
	nroutes=500
    dim title[nfiles],route_id_list[nroutes], route_name_list[nroutes], route_amhdwy_list[nroutes],route_mdhdwy_list[nroutes],route_pmhdwy_list[nroutes],route_ophdwy_list[nroutes]
    dim route_modeid_list[nroutes],route_fare_list[nroutes],route_dir_list[nroutes],route_track_list[nroutes],sumon[nroutes,nfiles], sumoff[nroutes,nfiles], TotOn[nroutes], TotOff[nroutes]
    dim OnOff_file[nfiles]

    Global boards_view
    Global num_routes, list_num
	

//  These files are the output of Transit Assignment
    k1=1
    for iper=1 to Periods.length do
		for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
				OnOff_file[k1] = Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]+"OnOffFlow.bin"
				title[k1]=Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]
				k1=k1+1
			end
		end
    end

//   Initializing matrix to zero
    for mmm=1 to route_id_list.length do
        TotOn[mmm] = 0
        TotOff[mmm] = 0
        for kkk=1 to OnOff_file.length do
           sumon[mmm][kkk]=0
           sumoff[mmm][kkk]=0
        end
    end

    route_info_view = OpenTable("route_info_view","FFB",{route_bin,})
    view_set1 = route_info_view + "|"
    nrec1 = GetRecordCount(route_info_view,null)
    rec1=GetFirstRecord(view_set1, null)
    num_routes = 0
		
    While rec1 <> null do
		num_routes = num_routes + 1
		route_id_list[num_routes] = route_info_view.Route_ID
		route_name_list[num_routes] = route_info_view.Route_Name
		route_amhdwy_list[num_routes] = route_info_view.HW_AM
		route_pmhdwy_list[num_routes] = route_info_view.HW_PM
		route_ophdwy_list[num_routes] = route_info_view.HW_OP						
		route_modeid_list[num_routes] = route_info_view.Mode
		route_fare_list[num_routes] = route_info_view.Fare
		route_dir_list[num_routes] = route_info_view.Direction
		route_track_list[num_routes] = route_info_view.Route  //todo - change variable name

		rec1 = GetNextRecord(view_set1, null, null)
    end

    for trn_asn_file = 1 to OnOff_file.length do
        onoff_file = outdir.transit + OnOff_file[trn_asn_file]
        onoff_view = OpenTable("onoff_view","FFB",{onoff_file,})
        view_set = onoff_view + "|"
		// for each route id add the boardings
        for m = 1 to num_routes do
			rec=GetFirstRecord(view_set, null)
			While rec <> null do
				if (onoff_view.ROUTE = route_id_list[m]) then do
					sumon[m][trn_asn_file] = sumon[m][trn_asn_file] + onoff_view.On
					TotOn[m] = TotOn[m] + onoff_view.On
					sumoff[m][trn_asn_file] = sumoff[m][trn_asn_file] + onoff_view.Off
					TotOff[m] = TotOff[m] + onoff_view.Off
				end
				rec = GetNextRecord(view_set, null, null)
			end
		end
    end

// Create boarding table

    boards_info = {
		{"Route_ID", "Integer", 8, null, "Yes"},
		{"Route_Name", "String", 25, null, "No"},
		{"MODE", "Integer", 5, null, "No"},
		{"AM_HEAD", "Integer", 5, null, "No"},
		{"PM_HEAD", "Integer", 5, null, "No"},
		{"OP_HEAD", "Integer", 5, null, "No"},
		{"ROUTE", "String", 5, null, "No"},
		{"AM_MILES", "Real", 10, 2, "No"},
		{"AM_MINUTES", "Real", 10, 2, "No"},
		{"PM_MILES", "Real", 10, 2, "No"},
		{"PM_MINUTES", "Real", 10, 2, "No"},
		{"OP_MILES", "Real", 10, 2, "No"},
		{"OP_MINUTES", "Real", 10, 2, "No"},				
		{"ON_TOTAL", "Integer", 8, 0, "No"},
		{title[1], "Real", 5, 1, "No"},
		{title[2], "Real", 5, 1, "No"},
		{title[3], "Real", 5, 1, "No"},	
		{title[4], "Real", 5, 1, "No"},
		{title[5], "Real", 5, 1, "No"},
		{title[6], "Real", 5, 1, "No"},			
		{"PAX_HOURS", "Integer", 8, 0, "No"},
		{"PAX_MILES", "Integer", 8, 0, "No"}
		}

    boards_name = "BOARDINGS"
    boards_file = outdir.rep + "TrnSummary.asc"

    on notfound do goto skip end

skip:
    boards_view = CreateTable (boards_name, boards_file, "FFA", boards_info)

// Populate Boardings
    
    SetView(boards_view)
    for k = 1 to num_routes do
        boards_values = {
            {"Route_ID", route_id_list[k]},
						{"Route_Name", route_name_list[k]},
						{"MODE", route_modeid_list[k]},
						{"AM_HEAD", route_amhdwy_list[k]},
						{"PM_HEAD", route_pmhdwy_list[k]},
						{"OP_HEAD", route_ophdwy_list[k]},			
						{"ROUTE", route_track_list[k]},
						{"AM_MILES", rtemiam[k]},
						{"AM_MINUTES", rtehram[k]},
						{"PM_MILES", rtemipm[k]},
						{"PM_MINUTES", rtehrpm[k]},
						{"OP_MILES", rtemiop[k]},
						{"OP_MINUTES", rtehrop[k]},			
						{"ON_TOTAL", TotOn[k]},
						{title[1], sumon[k][1]},
						{title[2], sumon[k][2]},
						{title[3], sumon[k][3]},
						{title[4], sumon[k][4]},
						{title[5], sumon[k][5]},
						{title[6], sumon[k][6]},
						{"PAX_HOURS", sumph[k]},
						{"PAX_MILES", sumpm[k]}
						}
        AddRecord (boards_view,boards_values)
    end
	CloseView(boards_name)

	on notfound do
	   goto quit
	end

    Return(1)
quit:
    PutInRecycleBin(outdir.rep + "TrnSummary.AX")
    Return(0)
EndMacro


// STEP 10.3: Macro to output Mode Choice Statistics
Macro "TRNSTAT"
    shared outdir, DwellTimeFactor, DeleteTempOutputFiles, DeleteSummitFiles, modetable, Periods   // input files
    shared stat_file // output files

    nfiles=Periods.length
    nchoice=3  //2 options for mode choice and 1 for total
    maxmode=4 // maximum mode number in the network
	nroutes=500 // maximum number of routes
    dim TransitTripFiles[nfiles]  // transit trip tables by period
    dim Flows[nfiles+1,nchoice]       //dim1 is purpose and dim2 is mode
    dim modename[maxmode],ambrd[maxmode],mdbrd[maxmode],pmbrd[maxmode],opbrd[maxmode],totbrd[maxmode]
    dim track[nroutes],modenum[nroutes],ambrdrte[nroutes],mdbrdrte[nroutes],pmbrdrte[nroutes],opbrdrte[nroutes],totbrdrte[nroutes]
    dim totrte[nfiles+1],tot[nfiles+1],xfer[nfiles+1],xferr[nfiles+1]
    k1=1
	
	for iper=1 to Periods.length do 
		TransitTripFiles[iper]="TransitTrip_" + Periods[iper]+".mtx"
	end

    for iper=1 to (nfiles+1) do
        tot[iper]=0
        totrte[iper]=0
        xfer[iper]=0
        xferr[iper]=0
        for imde=1 to nchoice do
			Flows[iper][imde]=0
        end
    end

    for i=1 to ambrd.Length do
        ambrd[i]=0
        pmbrd[i]=0
        opbrd[i]=0				
        totbrd[i]=0
    end
    for i=1 to totbrdrte.Length do
        ambrdrte[i]=00
        pmbrdrte[i]=0
        opbrdrte[i]=0				
        totbrdrte[i]=0
    end

    modename[3]="         Local"
	modename[4]="       Shuttle"

    stat_file1 = outdir.rep + "TrnSummary.asc"
    sfile = OpenFile(stat_file,"w+")
    sfile1 = OpenFile(stat_file1,"r")

    stime=GetDateAndTime()
    WriteLine(sfile,"\n Created On: "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+")\n Chattanooga Transit Assignment Summary")
    //WriteLine(sfile,"\n Alternative: "+SubString(InDir,1,100)+" \n\n\n")

	dim DwellTimeFactor[100]
    ModeTable=OpenTable("modetable","dBASE",{modetable,})
    fields=GetTableStructure(ModeTable)

    view_set=ModeTable+"|"
    rec=GetFirstRecord(view_set,null)
    i=1
    while rec!=null do
        values=GetRecordValues(ModeTable,,)
		Factor = ModeTable.DWELL_FACT	// mins/mile
        imde=ModeTable.MODE_ID
		
		DwellTimeFactor[i] = {imde,Factor}

        i=i+1
        rec=GetNextRecord(view_set, null, null)
    end	
	
    for k = 1 to TransitTripFiles.length do
		on notfound goto skip

    skip:

        mat = OpenMatrix(outdir.tables+TransitTripFiles[k],)
        stat_array = MatrixStatistics(mat, )
		
		Flows[k][1] = stat_array.[Local].Sum
		Flows[k][2] = stat_array.[Shuttle].Sum
		Flows[k][3] = Flows[k][1] + Flows[k][2]
		
		// total flow
		Flows[4][1] = Flows[4][1] + Flows[k][1]
		Flows[4][2] = Flows[4][2] + Flows[k][2]
		Flows[4][3] = Flows[4][3] + Flows[k][3]

        if k=1 then do
			WriteLine(sfile,"\n\n\nTRIPS BY TOD AND MODE (MODE CHOICE MODEL RESULTS)")
			WriteLine(sfile,"=================================|============")
			WriteLine(sfile," Per   WalkLocal   WalkShuttle   | Transit Trips")
			WriteLine(sfile,"=================================|============")
        end
		
        WriteLine(sfile,Lpad(Periods[k],5)+"   "+Format(Flows[k][1],",00000")+"           "+Format(Flows[k][2],",00000")+"  | "+Format(Flows[k][3],",00000"))
    end
		
    WriteLine(sfile,"=================================|============")
    WriteLine(sfile,"TOTAL   "+Format(Flows[4][1],",00000")+"           "+Format(Flows[4][2],",00000")+"  | "+Format(Flows[4][3],",00000"))

												
    While !FileAtEOF(sfile1) do
        linei=ReadLine(sfile1)
				
        mode=R2I(value(SubString(linei,34,5)))
        if (mode=0) then mode=14
		
		// route_id
        route=R2I(value(SubString(linei,1,8)))
        if (route=0) then route=499
		
		// service route
		track[route]=SubString(linei,54,5)
		
		//boardings		
		ambrdtotal = value(SubString(linei,127,5)) + value(SubString(linei,132,5))
		pmbrdtotal = value(SubString(linei,137,5)) + value(SubString(linei,142,5))					 
		opbrdtotal = value(SubString(linei,147,5)) + value(SubString(linei,152,5))									 
		brdtotal = value(SubString(linei, 119,8))
				
		// mode level boarding
        ambrd[mode] = ambrd[mode] + ambrdtotal
		pmbrd[mode] = pmbrd[mode] + pmbrdtotal
		opbrd[mode] = opbrd[mode] + opbrdtotal														
        totbrd[mode] = totbrd[mode] + brdtotal
        
		// route level boarding
		modenum[route]=mode
        ambrdrte[route] = ambrdrte[route] + ambrdtotal
		pmbrdrte[route] = pmbrdrte[route] + pmbrdtotal
		opbrdrte[route] = opbrdrte[route] + opbrdtotal      
        totbrdrte[route] = totbrdrte[route] + brdtotal
		
		// total boarding by mode
        tot[1] = tot[1] + ambrdtotal
        tot[2] = tot[2] + pmbrdtotal
        tot[3] = tot[3] + opbrdtotal	
        tot[4] = tot[4] + brdtotal
        
		// total boarding by route
        totrte[1] = totrte[1] + ambrdtotal
        totrte[2] = totrte[2] + pmbrdtotal
        totrte[3] = totrte[3] + opbrdtotal
        totrte[4] = totrte[4] + brdtotal
    end
	
    CloseFile(sfile1)

    WriteLine(sfile,"\n\n\nTRANSIT BOARDINGS BY MODE (TRANSIT ASSIGNMENT RESULTS)")
    WriteLine(sfile,"====================================================================================|=========")
    WriteLine(sfile," Mode         Mode Name      Dwell Factor           AM         PM           OP      |    Total")
    WriteLine(sfile,"====================================================================================|=========")
    
		for k=1 to maxmode do
			if (totbrd[k] > 0) then do
				WriteLine(sfile,"   "+Format(k,"00")+"    "+modename[k]+"            "+Format(DwellTimeFactor[k][2],"0.00")+"          "+Format(ambrd[k],",00000")+"      "+
				Format(pmbrd[k],",00000")+"      "+Format(opbrd[k],",00000")+"     |   "+Format(totbrd[k],",00000"))
			end
    end
    WriteLine(sfile,"====================================================================================|=========")
    WriteLine(sfile,"        TOTAL                                    "+Format(tot[1],",00000")+"      "+Format(tot[2],",00000")+"      "+Format(tot[3],",00000")+"     |   "+Format(tot[4],",00000"))

    WriteLine(sfile,"\n\n\nTRANSFER RATES BY TOD")
    WriteLine(sfile,"=======================================")
    WriteLine(sfile," Period    Transfers   (Rate)")
    WriteLine(sfile,"=======================================")
    
    for k=1 to 3 do
			xfer[k]=(tot[k]-(Flows[k][1]+Flows[k][2]))
			xferr[k]=(tot[k]/(Flows[k][1]+Flows[k][2])-1)*100
			WriteLine(sfile,"  "+LPad(Periods[k],5)+"       "+Format(xfer[k],",00000")+" ("+Format(xferr[k],"00.00")+"%) ")
    end
		
    xfer[4]=(tot[4]-(Flows[4][1]+Flows[4][2]))
    xferr[4]=(tot[4]/(Flows[4][1]+Flows[4][2])-1)*100
	
    WriteLine(sfile,"=======================================")
    WriteLine(sfile," TOTAL        "+Format(xfer[k],",00000")+" ("+Format(xferr[k],"00.00")+"%) ")
	
    WriteLine(sfile,"\n\n\nTRANSIT BOARDINGS BY ROUTE (TRANSIT ASSIGNMENT RESULTS)")
    WriteLine(sfile,"====================================================================|=========")
    WriteLine(sfile," Route_ID     Route     Mode         AM           PM         OP     |    Total")
    WriteLine(sfile,"====================================================================|=========")
    
		for k=1 to 200 do
			if (modenum[k] > 0) then do
				WriteLine(sfile," Rte "+Format(k,"000")+"      "+track[k]+"     "+Format(modenum[k],"00")+"       "+Format(ambrdrte[k],",00000")+"       "+Format(pmbrdrte[k],",00000")+"       "+Format(opbrdrte[k],",00000")+"   |   "+Format(totbrdrte[k],",00000"))
			end
		end
    
	WriteLine(sfile,"====================================================================|=========")
    WriteLine(sfile,"        TOTAL                    "+Format(totrte[1],",00000")+"       "+Format(totrte[2],",00000")+"       "+Format(totrte[3],",00000")+"   |   "+Format(totrte[4],",00000"))

    stime=GetDateAndTime()
    WriteLine(sfile,"\n\n\n END TRANSIT REPORTING - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    CloseFile(sfile)

    Return(1)
quit:
    Return(0)
EndMacro


//STEP 10.4: Stop level boarding summary
Macro "Stop_Level_Summary"
    shared indir, outdir, highway_dbd, route_system // input files
	shared Periods, AccessAssgnModes, Modes 
    shared all_boards_file // output files

   // Inputs
	Dir = indir
	net_file = highway_dbd                   // highway network
	route_file = route_system                // transit network
   // Outputs
	all_boards_file = outdir.transit + "ALL_BOARDINGS.dbf"

	// -- create a table to store the ON/OFF Boards Information for all Buses/Premium Services

	all_boards_info = {
		{"Route_ID", "Integer", 8, null, "Yes"},
		{"Route_Name", "String", 25, null, "Yes"},
		{"MODE", "Integer", 8, null, "No"},
		{"HW_AM", "Real", 8, 2, "No"},
		{"HW_PM", "Real", 8, 2, "No"},
		{"HW_OP", "Real", 8, 2, "No"},		
		{"STOP_ID", "Integer", 8, null, "No"},
		{"NODE_ID", "Integer", 8, null, "No"},
		{"STOP_NAME", "String", 25, null, "No"},
		{"MILEPOST", "Real", 10, 4, "No"},
		{"AM_IVTT", "Real", 10, 4, "No"},
		{"PM_IVTT", "Real", 10, 4, "No"},
		{"OP_IVTT", "Real", 10, 4, "No"},		
		{"AMWLK_ON", "Real", 10, 2, "No"},
		{"AMWLK_OF", "Real", 10, 2, "No"},
		{"PMWLK_ON", "Real", 10, 2, "No"},
		{"PMWLK_OF", "Real", 10, 2, "No"},
		{"OPWLK_ON", "Real", 10, 2, "No"},
		{"OPWLK_OF", "Real", 10, 2, "No"},
		{"AM_ON", "Real", 10, 2, "No"},
		{"AM_OFF", "Real", 10, 2, "No"},
		{"AM_RIDES", "Real", 10, 2, "No"},
		{"PM_ON", "Real", 10, 2, "No"},
		{"PM_OFF", "Real", 10, 2, "No"},
		{"PM_RIDES", "Real", 10, 2, "No"},
		{"OP_ON", "Real", 10, 2, "No"},
		{"OP_OFF", "Real", 10, 2, "No"},
		{"OP_RIDES", "Real", 10, 2, "No"}		
	}

	all_boards_name = "ALL_BOARDINGS"
	all_boards_view = CreateTable (all_boards_name, all_boards_file, "DBASE", all_boards_info)

	// Get the scope of a geographic file
	info = GetDBInfo(net_file)
	scope = info[1]

	// Create a map using this scope
	CreateMap(net, {{"Scope", scope},{"Auto Project", "True"}})
	layers = GetDBLayers(net_file)
	node_lyr = addlayer(net, layers[1], net_file, layers[1])
	link_lyr = addlayer(net, layers[2], net_file, layers[2])
	rtelyr = AddRouteSystemLayer(net, "Vehicle Routes", route_file, )
	RunMacro("Set Default RS Style", rtelyr, "TRUE", "TRUE")
	SetLayerVisibility(node_lyr, "True")
	SetIcon(node_lyr + "|", "Font Character", "Caliper Cartographic|4", 36)
	SetIcon("Transit Stops|", "Font Character", "Caliper Cartographic|4", 36)
	SetLayerVisibility(link_lyr, "True")
	solid = LineStyle({{{1, -1, 0}}})
	SetLineStyle(link_lyr+"|", solid)
	SetLineColor(link_lyr+"|", ColorRGB(0, 0, 32000))
	SetLineWidth(link_lyr+"|", 0)
	SetLayerVisibility("Transit Stops", "False")

on notfound default
	SetView("Vehicle Routes")
	n1 = SelectByQuery("RailRoutes", "Several", "Select * where Mode>0",)   // modify this selection to output for the modes that you want the boarding summary (for now include all transit)
	routes_view = GetView()


// ----- Set the paths for the TASN_FLOW files
	// open flow views to get travel times...only using rail flows as it all routes exist in them
	am_flow_view = OpenTable("am_flow_view", "FFB", {outdir.transit + "AMWalkLocalFlow.bin",})
	pm_flow_view = OpenTable("pm_flow_view", "FFB", {outdir.transit + "PMWalkLocalFlow.bin",})
	op_flow_view = OpenTable("op_flow_view", "FFB", {outdir.transit + "OPWalkLocalFlow.bin",})	

	Dim all_am_ons[4,5,3]
	Dim all_am_offs[4,5,3]
	Dim all_pm_ons[4,5,3]
	Dim all_pm_offs[4,5,3]
	Dim all_op_ons[4,5,3]
	Dim all_op_offs[4,5,3]
	
	for i = 1 to Periods.length do
		for j = 1 to Modes.length do
			for k = 1 to AccessAssgnModes.length do
				all_am_ons[i][j][k] = 0
				all_am_offs[i][j][k] = 0
				all_pm_ons[i][j][k] = 0
				all_pm_offs[i][j][k] = 0
				all_op_ons[i][j][k] = 0
				all_op_offs[i][j][k] = 0				
			end
		end
	end

	//open the on-off tables to get boardings by stop
	Dim path_ONOS[4,5,3]
	Dim tasn_view[4,5,3]

	counter = 0
	for i = 1 to Periods.length do
		for j = 1 to Modes.length do
			for k = 1 to AccessAssgnModes.length do
				counter = counter + 1
				path_ONOS[i][j][k] = outdir.transit + "\\" + Periods[i] + AccessAssgnModes[k] + Modes[j] + "OnOffFlow.bin"
				tasn_view[i][j][k] = OpenTable("tasn_view" + I2S(counter),"FFB",{path_ONOS[i][j][k],})
			end
		end
	end
	counter = 0
	
	SetView(routes_view)

	rec = 0
	nrec = GetRecordCount (routes_view, "RailRoutes")
	CreateProgressBar ("Processing Vehicle Route" + String(nrec) + " Transit Routes", "True")

	routes_rec = GetFirstRecord (routes_view + "|RailRoutes", {{"Route_Name", "Ascending"}})

	while routes_rec <> null do
		rec = rec + 1
		percent = r2i (rec * 100 / nrec)

		cancel = UpdateProgressBar ("Processing Vehicle Route " + String (rec) + " of " + String (nrec) + " Transit Routes", percent)

		if cancel = "True" then do
			DestroyProgressBar ()
			Return (1)
		end

		am_boards_flag = 0
		pm_boards_flag = 0
		op_boards_flag = 0		
		am_boards = 0
		pm_boards = 0
		op_boards = 0		

		SetView(routes_view)
		route_id = routes_view.Route_ID
		route_name = routes_view.Route_Name
		mode = routes_view.Mode
		am_headway = routes_view.HW_AM
		pm_headway = routes_view.HW_PM
		op_headway = routes_view.HW_OP		

		stop_layer = "Transit Stops"
		SetView("Transit Stops")

		select = "Select * where Route_ID = " + String(route_id)
		stop_selection = SelectByQuery ("Stops", "Several", select, )

		num_stops = GetRecordCount ("Transit Stops", "Stops")
		stop_rec = GetFirstRecord ("Transit Stops" + "|Stops", {{"Milepost", "Ascending"}})

		while stop_rec <> null do
			stop_id = stop_layer.ID
			node_id = stop_layer.NearNode
			milepost = stop_layer.Milepost

			// --- get the milepost distances and travel times
			if (am_headway = 0) then do
				for i = 1 to 1 do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							all_am_ons[i][j][k] = 0
							all_am_offs[i][j][k] = 0
						end
					end
				end
				am_on = 0
				am_off = 0
				am_boards = 0
			end else do
				am_on = 0
				am_off = 0
				for i = 1 to 1 do	//Periods.length                                                               // todo - what is this?
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							amboards = RunMacro("Get Boardings", route_id, stop_id, tasn_view[i][j][k])
							all_am_ons[i][j][k] = all_am_ons[i][j][k] + amboards[1]
							all_am_offs[i][j][k] = all_am_offs[i][j][k] + amboards[2]
							am_on = am_on + amboards[1]
							am_off = am_off + amboards[2]
						end
					end
				end

				if am_boards_flag = 0 then do
					am_boards = am_on
					am_boards_flag = 1
				end else do
					am_boards = am_boards + am_on - am_off
				end
				am_ttime = RunMacro("Get Run Time", route_id, stop_id, am_flow_view)
			end    // -- end of process for summarizing am boards

			if (pm_headway = 0) then do
				for i = 2 to 2 do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							all_pm_ons[i][j][k] = 0
							all_pm_offs[i][j][k] = 0
						end
					end
				end
				pm_on = 0
				pm_off = 0
				pm_boards = 0
			end else do
				pm_on = 0
				pm_off = 0
				for i = 2 to 2 do	//PurpPeriods.length                                                               // todo - what is this?
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							pmboards = RunMacro("Get Boardings", route_id, stop_id, tasn_view[i][j][k])
							all_pm_ons[i][j][k] = all_pm_ons[i][j][k] + pmboards[1]
							all_pm_offs[i][j][k] = all_pm_offs[i][j][k] + pmboards[2]
							pm_on = pm_on + pmboards[1]
							pm_off = pm_off + pmboards[2]
						end
					end
				end

				if pm_boards_flag = 0 then do
					pm_boards = pm_on
					pm_boards_flag = 1
				end else do
					pm_boards = pm_boards + pm_on - pm_off
				end
				pm_ttime = RunMacro("Get Run Time", route_id, stop_id, pm_flow_view)
			end  // -- end of processing pm boards			

			if (op_headway = 0) then do
				for i = 3 to 3 do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							all_op_ons[i][j][k] = 0
							all_op_offs[i][j][k] = 0
						end
					end
				end
				op_on = 0
				op_off = 0
				op_boards = 0
			end else do
				op_on = 0
				op_off = 0
				for i = 3 to 3 do	//PurpPeriods.length                                                               // todo - what is this?
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							opboards = RunMacro("Get Boardings", route_id, stop_id, tasn_view[i][j][k])
							all_op_ons[i][j][k] = all_op_ons[i][j][k] + opboards[1]
							all_op_offs[i][j][k] = all_op_offs[i][j][k] + opboards[2]
							op_on = op_on + opboards[1]
							op_off = op_off + opboards[2]
						end
					end
				end

				if op_boards_flag = 0 then do
					op_boards = op_on
					op_boards_flag = 1
				end else do
					op_boards = op_boards + op_on - op_off
				end
				op_ttime = RunMacro("Get Run Time", route_id, stop_id, op_flow_view)
			end  // -- end of processing op boards	
			
			SetView(all_boards_view)

			all_board_values = {
				{"Route_ID", route_id},
				{"Route_Name", route_name},
				{"MODE", mode},
				{"HW_AM", am_headway},
				{"HW_PM", pm_headway},
				{"HW_OP", op_headway},
				{"STOP_ID", stop_id},
				{"NODE_ID", node_id},
				{"MILEPOST", milepost},
				{"AM_IVTT", am_ttime},
				{"PM_IVTT", pm_ttime},
				{"OP_IVTT", op_ttime},
				{"AMWLK_ON", all_am_ons[1][1][1]+all_am_ons[1][2][1]+all_am_ons[1][3][1]},
				{"AMWLK_OF", all_am_offs[1][1][1]+all_am_offs[1][2][1]+all_am_offs[1][3][1]},
				{"PMWLK_ON", all_pm_ons[2][1][1]+all_pm_ons[2][2][1]+all_pm_ons[2][3][1]},
				{"PMWLK_OF", all_pm_offs[2][1][1]+all_pm_offs[2][2][1]+all_pm_offs[2][3][1]},
				{"OPWLK_ON", all_op_ons[3][1][1]+all_op_ons[3][2][1]+all_op_ons[3][3][1]},
				{"OPWLK_OF", all_op_offs[3][1][1]+all_op_offs[3][2][1]+all_op_offs[3][3][1]},
				{"AM_ON", am_on},
				{"AM_OFF", am_off},
				{"AM_RIDES", am_boards},
				{"PM_ON", pm_on},
				{"PM_OFF", pm_off},
				{"PM_RIDES", pm_boards},
				{"OP_ON", op_on},
				{"OP_OFF", op_off},
				{"OP_RIDES", op_boards}
				}

			AddRecord (all_boards_view, all_board_values)

			// reset all the values for the next stop
			for i = 1 to Periods.length do
				for j = 1 to Modes.length do
					for k = 1 to AccessAssgnModes.length do

						all_am_ons[i][j][k] = 0
						all_am_offs[i][j][k] = 0
						all_pm_ons[i][j][k] = 0
						all_pm_offs[i][j][k] = 0
						all_op_ons[i][j][k] = 0
						all_op_offs[i][j][k] = 0							
												
					end
				end
			end

			SetView(stop_layer)
			stop_rec = GetNextRecord ("Transit Stops" + "|Stops", null, {{"Milepost", "Ascending"}})
		end		//end for stops

		SetView(routes_view)
		routes_rec = GetNextRecord (routes_view + "|RailRoutes", null, {{"Route_Name", "Ascending"}})
	end

//--- Invoke the Macro to Generate a Print file for Boardings Summary
	DestroyProgressBar ()
	CloseMap()
  Return(1)

endMacro

// ---------------------------------------
//   Macro to Summarize Boardings
// ---------------------------------------
Macro "Get Boardings" (route_id, stop_id, view_name)
	dim boards[2]
	SetView(view_name)

	selection = "Select * where ROUTE = " + String(route_id) + " and STOP = " + String(stop_id)
	record_selection = SelectByQuery ("Select Record", "Several", selection,)
	num_select = GetRecordCount (view_name, "Select Record")

	if (num_select > 1) then
		ShowMessage("More than one record Selected...PROBLEM HERE")
	else if (num_select = 0) then do		// --- no records are found in the boardings file
			boards[1] = 0.0
			boards[2] = 0.0
	end else do
		selected_record = GetFirstRecord (view_name + "|Select Record", null)
		boards[1] = view_name.On
		boards[2] = view_name.Off
	end
	Return(boards)
endMacro


//--------------------------------------------------------------------------
//  Macro to Get run time to a particular stop on a route from previous stop
//--------------------------------------------------------------------------
Macro "Get Run Time" (route_id, stop_id, view_name)
	SetView(view_name)

	selection = "Select * where ROUTE = " + String(route_id) + " and To_Stop = " + String(stop_id)
	record_selection = SelectByQuery ("Select Record", "Several", selection,)
	num_select = GetRecordCount (view_name, "Select Record")

	if (num_select > 1) then
		ShowMessage("More than one record Selected...PROBLEM HERE")
	else if (num_select = 0) then do		// --- no records are found in the boardings file
			rtime = 0.0000
	end else do
		selected_record = GetFirstRecord (view_name + "|Select Record", null)
		rtime = view_name.BaseIVTT
	end
	Return(rtime)
endMacro
