//Enable Microsoft Message Queue Server Core via cmd "optionalfeatures"

Macro "CHCRPA"
    AddMenuItem("CHCRPA", "After", "Tools")
	manager = CreateObject("CHCRPA.GUIController", null)
	output_data = RunDbox("CHCRPA", manager)
endMacro

//-------------------------------------------------------------------------------------------//
Menu "CHCRPA"
   MenuItem "CHCRPA" text: "CHCRPA" menu "CHCRPA Menu"
endMenu

Menu "CHCRPA Menu"
	MenuItem "Travel Demand Model" do
	manager = CreateObject("CHCRPA.GUIController", null)
	output_data = RunDbox("CHCRPA", manager)
	endItem
	MenuItem "Open Model Folder" do shared root status = RunProgram("explorer " + root.mod, {}) EndItem
	MenuItem "TDM Technical Documentation" do shared root TechDoc = root.mod + "\\0_Model-Documentation\\Chattanooga_TDM_Documentation_Draft04192016.pdf" LaunchDocument(TechDoc, ) EndItem
	//MenuItem "TDM Presentation" do shared root TDMPresentation = root.mod + "\\0_Model-Documentation\\TNstatewideModel_141208.pdf" LaunchDocument(TDMPresentation, ) EndItem
	MenuItem "Remove Menu" do RemoveMenuItem("CHCRPA") EndItem
endMenu



//=========================================================================================================
// ----- INITIALIZE USER INTERFACE CLASS -----

Class "CHCRPA.GUIController"
     Init do
		shared root, info, indir, outdir, mvw
		shared net, skim, od, flow, post
		shared controlvw, netparam, dsparam, accparam

		on escape, notfound do
			on escape default
			on NotFound default
			Return()
		end
	   //ResetLogFile()
	   //ResetReportFile()
	   mapname = GetMap()
	   if mapname <> null then SetMapRedraw(null, "False")
	   SetSelectDisplay("False")

		root   = {} //Root Directories: model, documents, reference, scenario
		indir  = {} //Scenario Input Directories
		outdir = {} //Scenario Output Directories
		net    = {} //assignnet, odmenet
		mvw    = {} //taz, line, node, control
		info   = {}

		info.scenname = "Base"
		info.iter = 0
		info.prmsd = 1
		info.prmseam = 100
		info.prmsepm = 100
		info.prmseop = 100
		info.baseyear = 2019
		info.modyear = 2019
		info.cores = 16
		info.pyear = 2045
		info.domoves = 1
		mvw.scnfile = null
		dt = CreateDateTime()
		MDY = FormatDateTime(dt, "MMMddyyyy")
		info.runname  = "Run_"+MDY
		info.timestamp = FormatDateTime(dt,"MMMddyyyy_HHmm")

	//Static Files
		root.mod   = "C:\\Model"

     Enditem


Macro "loadpaths" (temp) do
	shared root, info, indir, outdir, mvw
	shared net, skim, flow, od, post, daysim
	shared controlvw, netparam, dsparam, accparam

		dirinfo = GetDirectoryInfo(root.mod, "Directory")
		if dirinfo = null then root.mod = ChooseDirectory("Choose the Model Directory", )

		root.doc      = root.mod + "\\0_Model-Documentation\\"
		root.ref      = root.mod + "\\1_Model-Files\\"

	   //info.controlfile = root.ref +"control.dbf"
	   //mvw.control = OpenTable("controlvw", "DBASE", {info.controlfile, })

		root.net      = root.ref + "1_MasterNet\\"
		root.taz      = root.ref + "2_TAZ\\"
		root.popsyn    = root.ref + "3_PopSyn3\\"
		root.pivot     = root.ref + "4_Pivot\\"
		root.daysim    = root.ref + "5_DaySim\\"
		root.paramds   = root.ref + "6_Parameters\\1_DaySim\\"  //"DaysimParameters" fix?
		root.paramoth  = root.ref + "6_Parameters\\2_Other\\"
		root.images    = root.ref + "7_Images\\"
		root.other     = root.ref + "8_Other\\"

		info.calrep = root.paramoth + "CHCRPA_calrepinfo.bin"
		dsparamfile   = root.paramoth + "DScalc.dbf"
		netparamfile  = root.paramoth + "netparams.dbf"

		root.scen       = root.mod + "\\2_Scenarios\\"+info.scenname
		dirinfo = GetDirectoryInfo(root.scen, "Directory")

		info.log        = root.mod + "\\2_Scenarios\\"+info.scenname+"\\Log_"+info.timestamp+".txt"
		if mvw.rtsfile <> null then do
			//rtspath = SplitPath(mvw.rtsfile)
			//info.movetabbin = rtspath[1] + rtspath[2] + "MovementTable.bin"
			//info.movetabdcb = rtspath[1] + rtspath[2] + "MovementTable.dcb"
		end
		indir.zone      = root.scen + "\\Inputs\\1_TAZ\\"
		indir.hwy       = root.scen + "\\Inputs\\2_Networks\\"
		indir.ext       = root.scen + "\\Inputs\\3_ExternalTravel\\"
		indir.daysim    = root.scen + "\\Inputs\\4_DaySim\\"

		outdir.zone         = root.scen + "\\Outputs\\1_TAZ\\"
		outdir.hwy          = root.scen + "\\Outputs\\2_Networks\\"
			outdir.transit      = outdir.hwy + "Transit\\"
		outdir.daysim       = root.scen + "\\Outputs\\3_DaySim\\"
			outdir.dswrk       = outdir.daysim + "working\\"
			outdir.dsest       = outdir.daysim + "estimation\\"
		outdir.truck        = root.scen + "\\Outputs\\4_TruckDemand\\"
		outdir.ext          = root.scen + "\\Outputs\\5_ExternalTravel\\"
		outdir.tables       = root.scen + "\\Outputs\\6_TripTables\\"
		outdir.rep          = root.scen + "\\Outputs\\7_Reports\\"
		outdir.daysimrep    = root.scen + "\\Outputs\\7_Reports\\"
		//outdir.daysimrep    = outdir.rep + "DaySimReporting\\"

		//mvw.mzbuff       = root.daysim + "Inputs\\2_MicroZones\\Chatt_MZ"+i2s(info.modyear)+"_buffed.dat"
		//mvw.popsynhh     = root.daysim + "Inputs\\3_Households\\chattanooga_hh_"+i2s(info.modyear)+".dat"
		//mvw.popsynperson = root.daysim + "Inputs\\4_Persons\\chattanooga_person_"+i2s(info.modyear)+".dat"

		skim.default = outdir.hwy + "Highway_Skim.mtx"
		skim.am      = outdir.hwy + "Highway_Skim_AM.mtx"
		skim.pm      = outdir.hwy + "Highway_Skim_PM.mtx"
		skim.op      = outdir.hwy + "Highway_Skim_OP.mtx"
		skim.nm      = outdir.hwy + "NM_Skim.mtx"
		skim.truck   = outdir.truck + "Truck_KF.mtx"
		skim.cv      = outdir.truck + "CV_KF.mtx"
		skim.eipass  = outdir.ext + "EI_KF.mtx"
		net.gencost  = outdir.hwy + "GenCost.bin"
		net.time     = outdir.hwy + "CongTime_I0.bin"
		net.assign   = outdir.hwy + "Assignment.net"
		net.odme     = outdir.hwy + "ODME.net"

		flow.predly = outdir.tables + "AsnVol_preDly.bin"
		flow.pream  = outdir.tables + "AsnVol_preAM_I0.bin"
		flow.prepm  = outdir.tables + "AsnVol_prePM_I0.bin"
		flow.preop  = outdir.tables + "AsnVol_preOP_I0.bin"
		flow.dly    = outdir.tables + "AsnVol_Dly.bin"
		flow.am     = outdir.tables + "AsnVol_AM_I0.bin"
		flow.pm     = outdir.tables + "AsnVol_PM_I0.bin"
		flow.op     = outdir.tables + "AsnVol_OP_I0.bin"
		flow.asn    = outdir.tables + "BCFW_LinkFlow.bin"
		flow.trk    = outdir.tables + "TRK_LinkFlow.bin"

		//od.seed      = outdir.tables + "Seed_AirSage_Mar01.mtx"
		od.trkseed   = outdir.ext + "Trk_Seed.mtx"
		od.cvseed    = outdir.ext + "4TCV_Seed.mtx"
		od.countfile = outdir.ext + "External_Counts_"+i2s(info.modyear)+".dbf"
		od.eiseed    = outdir.ext + "EI_Passenger.mtx"
		//od.seed      = outdir.tables + "Seed_R5.mtx"
		od.daysim    = outdir.daysim + "DS_Trips_I0.mtx"
		od.triptable = outdir.tables + "TripTable_I0.mtx"

		od.ee        = outdir.ext + "EE_"+i2s(info.modyear)+".mtx"
		od.trk       = outdir.truck + "Truck_OD.mtx"
		od.cv        = outdir.truck + "CV_OD.mtx"
		od.eiauto    = outdir.tables + "EI_Auto.mtx"
		od.transitam = outdir.tables + "TransitTrip_AM.mtx"
		od.transitpm = outdir.tables + "TransitTrip_PM.mtx"
		od.transitop = outdir.tables + "TransitTrip_OP.mtx"

		daysim.cfgtemplate = root.paramds + "Config.properties"
		daysim.cfg_out     = outdir.daysim + "Config.properties"
		daysim.sp_in       = root.paramds + "Config_SP.properties"
		daysim.sp_out      = outdir.daysim + "Config_SP.properties"
		daysim.out_hh      = outdir.daysim + "_household_2.dat"
		daysim.out_pers    = outdir.daysim + "_person_2.dat"
		daysim.out_hhday   = outdir.daysim + "_household_day_2.dat"
		daysim.out_persday = outdir.daysim + "_person_day_2.dat"
		daysim.out_tours   = outdir.daysim + "_tour_2.dat"
		daysim.out_trips   = outdir.daysim + "_trip_2.dat"
		daysim.tripscsv    = outdir.daysim + "_trip_2.csv"
		daysim.summary     = indir.daysim + "8_Summaries\\"
		daysim.postcfg     = daysim.summary + "daysim_output_config.R"

		//Read param files
		netparam  = RunMacro("LoadParams", netparamfile, null)
		dsparam   = RunMacro("LoadParams", dsparamfile , null)
		//accparam  = RunMacro("LoadParams", accparamfile, null)
	endItem
	//endfold

Macro "CheckScenario" do
	shared root
	dirinfo = GetDirectoryInfo(root.scen, "Directory")
	if dirinfo <> null then ShowMessage("Note: Scenario Name already exists. It is recommended to select a unique scenario name.")
endItem
//endfold
endClass


//=========================================================================================================
// ----- MODEL USER INTERFACE -----

Dbox "CHCRPA" (controller) title: "CHCRPA Travel Demand Model V2.0"
	init do
		shared root, info, indir, outdir, mvw
		shared net, skim, od, flow, post
		shared netparam, dsparam, accparam
		shared walkfile
		shared tazvec, linevec
		controller.loadpaths(null)
	endItem

   button "Close" 22.5, 42, 10, 2 Cancel do
	mapname = GetMap()
	SetStatus(1, "@System0", )
	SetStatus(2, "@System1", )
	SetSelectDisplay("True")
	if mapname <> null then SetMapRedraw(null, "True")
	Return()
   endItem

  Tab list 1, 0.5, 55, 45 variable: tab_idx

//-------------------------------------------------------------------------------------------//
  Tab prompt: "About"
//fold
    init do
		msg = {}
		msg.a = ""
		msg.b = ""
		msg.c = "Developed for:"
		msg.d = "CHCRPA"
		msg.e = "1250 Market Street"
		msg.ea= "Suite 2000"
		msg.eb= "Chattanooga, TN 37402"
		msg.ec= "423.643.5946"
		msg.ed= "http://www.chcrpa.org/"
		msg.f = "Developed by:"
		msg.ga= "RSG Inc"
		msg.gb= "Resource Systems Group"
		msg.gc= "55 Railroad Row"
		msg.gd= "White River Junction"
		msg.ge= "VT 05001"
		msg.gf= "802.299.4999"
		msg.gg= "www.rsginc.com"
		msg.h = "April 2022"
		msg.i = "Updated by:"
		msg.ja= "WSP USA"
		msg.jb= "Systems Analysis Group"
		msg.jc= "1100 Market Street"
		msg.jd= "Suite 700"
		msg.je= "Chattanooga, TN 37402"
		msg.jf= "804.397.9279"
		msg.jg= "https://www.wsp.com/en-US"
    enditem

		Sample "clientbutton" .5, .5, 50, 8 Transparent contents: SamplePoint("Color Bitmap", root.images+"CHCRPA.bmp", -1, , )
	text 13, 4.5 variable: msg.a
	text 10, 4.5 variable: msg.b

    text 1, 10.5 variable: msg.c
    text same, 12 variable: msg.d
    text same, 13 variable: msg.e
    text same, 14.5 variable: msg.ea
    text same, 15.5 variable: msg.eb
    text same, 16.5 variable: msg.ec
    text same, 17.5 variable: msg.ed

    text 28, 10.5 variable: msg.f
    text same, 12 variable: msg.ga
    text same, 13 variable: msg.gb
    text same, 14.5 variable: msg.gc
    text same, 15.5 variable: msg.gd
    text same, 16.5 variable: msg.ge
    text same, 17.5 variable: msg.gf
	text same, 18.5 variable: msg.gg

    text 28, 25 variable: msg.i
    text same, 26.5 variable: msg.ja
    text same, 27.5 variable: msg.jb
    text same, 29 variable: msg.jc
    text same, 30 variable: msg.jd
    text same, 31 variable: msg.je
    text same, 32 variable: msg.jf
		text same, 33 variable: msg.jg

	Sample "clientlogo" 1, 20, 18, 5 Transparent contents: SamplePoint("Color Bitmap", root.images+"CHCRPAlogo.bmp", -1, null, null)
    Sample "rsglogo" 28, 20, 8, 4 Transparent contents: SamplePoint("Color Bitmap", root.images+"RSGlogo.bmp", -1, null, null)
  Sample "wsplogo" 28, 34.5, 18, 4 Transparent contents: SamplePoint("Color Bitmap", root.images+"WSPlogo.bmp", -1, null, null)

    text 21, 9 variable: msg.h
//-------------------------------------------------------------------------------------------//
//endfold

  Tab prompt: "Scenario"
//fold

	init do
	endItem

	text "Scenario Name" 5, 1
	edit text "scenname" 20, same, 25 variable: info.scenname do
		controller.loadpaths(null)
		controller.CheckScenario()
		endItem

	text "Model Year" 5, 2.5
	edit Int "modyear" 20, same, 6 variable: info.modyear format:"0000" do
		controller.loadpaths(null)
		endItem

	text "CPU Cores" 30, 2.5
	edit Int "Cores" 40, same, 4 variable: info.cores do
		info.cores = r2i(min(info.cores, 64))
	endItem


   text "Model Path:" 2, 5
   button "PathBrowse" 40.5, same, 10 Prompt:"Browse" do on escape goto endhere
		root.mod = ChooseDirectory("Choose the Model Directory", {{"Initial Directory", root.mod}})
		controller.loadpaths(null)
   endhere:
   endItem
	text "pathDirectory" 2.5, 6.5, 48 framed variable: root.mod


	frame "masterinput"  1, 9, 51.5, 30 prompt: "Scenario Inputs"

	text "TAZ Layer"             3, 11
	text "Master Network Layer"  3, 15
	text "RTS File"              3, 19
	text "Network Scenario"      3, 23
	text "Buffer Microzone"      3, 27
	text "PopSyn Household"      3, 31
	text "PopSyn Persons"        3, 35

	button "TAZBrowse"  44, 11, 6.5 Prompt:"Browse" do on escape goto endhere mvw.tazfile = ChooseFile({{"TAZ Layer (*.dbd)", "*.dbd"},{"Standard (*.dbd)","*.dbd"}}, "Choose a TAZ Layer", {,{"Initial Directory", root.taz},}) endhere: endItem
	button "MNetBrowse" 44, 15, 6.5 Prompt:"Browse" do on escape goto endhere mvw.masternet = ChooseFile({{"Master Network", "*.dbd"}}, "Choose the masternet layer", {,{"Initial Directory", root.net},}) endhere: endItem
	button "RTS File"   44, 19, 6.5 Prompt:"Browse" do on escape goto endhere mvw.rtsfile = ChooseFile({{"RTS File", "*.rts"}}, "Choose the RTS layer", {,{"Initial Directory", root.net},}) endhere: endItem

    button "ScenBrowse" 44, 23, 6.5 Prompt:"Browse" do
		on escape goto endhere
		/*
		projfile = root.net+"Projects\\Project_List.bin"
		projvw = OpenTable("projvw", "FFB", {projfile, })
		{projv} = GetDataVectors(projvw + "|", {"Project_ID"}, {{"Sort Order",{{"ID","Ascending"}}}})
		sortprojv = SortVector(projv, {{"Unique","True"}})
		arr = V2A(sortprojv)
		ptr = OpenFile(root.net+"Projects\\Project_List.txt", "w")
		WriteArray(ptr, arr)
		CloseFile(ptr)
		CloseView(projvw)
		*/
		mvw.scnfile = ChooseFile({{"Scenario File", "*.txt"}}, "Choose the Scenario definition file", {,{"Initial Directory", root.net+"Scenarios\\"},})
	endhere:
	endItem

	button "PSMZ"   44, 27, 6.5 Prompt:"Browse" do on escape goto endhere mvw.mzbuff = ChooseFile({{"dat File", "*.dat"}}, "Choose the Buffered Microzone File", {,{"Initial Directory", root.daysim+"Inputs\\2_MicroZones\\"},}) endhere: endItem
	button "PSHH"   44, 31, 6.5 Prompt:"Browse" do on escape goto endhere mvw.popsynhh = ChooseFile({{"dat File", "*.dat"}}, "Choose the Households File", {,{"Initial Directory", root.daysim+"Inputs\\3_Households\\"},}) endhere: endItem
	button "PSPER"   44, 35, 6.5 Prompt:"Browse" do on escape goto endhere mvw.popsynperson = ChooseFile({{"dat File", "*.dat"}}, "Choose the Persons File", {,{"Initial Directory", root.daysim+"Inputs\\4_Persons\\"},}) endhere: endItem

	//button "ScenView" 40, 19, 6.5 Prompt:"View" do status = RunProgram("notepad " + scnfile, ) endItem

	text "tazfile"      2.5, 12.5, 48 framed variable: Substitute(mvw.tazfile, root.ref, "..", null)
	text "masterfile"   2.5, 16.5, 48 framed variable: Substitute(mvw.masternet, root.ref, "..", null)
	text "masterfile"   2.5, 20.5, 48 framed variable: Substitute(mvw.rtsfile, root.ref, "..", null)
	text "scenariofile" 2.5, 24.5, 48 framed variable: if mvw.scnfile = null then "No Scenario Selected" else "Scenario Selected"
	text "psmzfile" 2.5, 28.5, 48 framed variable: Substitute(mvw.mzbuff, root.daysim, "..", null)
	text "pshhfile" 2.5, 32.5, 48 framed variable: Substitute(mvw.popsynhh, root.daysim, "..", null)
	text "pspersonfile" 2.5, 36.5, 48 framed variable: Substitute(mvw.popsynperson, root.daysim, "..", null)


//-------------------------------------------------------------------------------------------//
//endfold

  Tab prompt: "Run"
//fold
	init do
		info.spbutton = 1
		info.spdir = indir.daysim+"6_ShadowPrices\\"
	endItem

	Radio List 1, 2, 50, 4  Prompt: "Shadow Price" Variable: info.spbutton
	Radio Button 2, 3  Prompt: "Run Default" do endItem
	Radio Button 30, same  Prompt: "Select SP Scenario" do on escape goto endhere
		info.spscen = ChooseDirectory("Choose a Scenario", {,{"Initial Directory", root.mod+"\\2_Scenarios\\"},})
		info.spdir = info.spscen + "\\Outputs\\3_DaySim\\working\\"
		ShowMessage(info.spdir)
		endhere:
			if info.spscen = null then do
				info.spbutton = 1
				info.spdir = indir.daysim+"6_ShadowPrices\\"
			end
		endItem
	text "spfile" 3, 4.5, 47  framed variable: if info.spbutton = 1 then "Default SP Calculation" else info.spscen

	Button "Run All Steps" 5, 8, 45, 3 do
	controller.loadpaths(null)
	HideDbox()
	RunMacro("Initialize")
	RunMacro("RunModel")
	RunMacro("CloseAll")

	//Redraw Map
	SetSelectDisplay("True")
	mapname = GetMap()
	if mapname <> null then do SetMapRedraw(null, "True") RedrawMap() end

	ShowMessage("Model & Post Processor Complete!")
	ShowDbox()
	enditem

frame "IndSteps"  1, 12.5, 51.5, 17 prompt: "Single Modules"

   Button "step1" 5,  14, 45, 2  Prompt: "01 Initialize"        do on escape goto endhere
		controller.loadpaths(null)
		RunMacro("Initialize")
		RunMacro("TAZ_Process")
		RunMacro("Network_Process")

		RunMacro("WriteLog", "Network Skims & Accessibility")
		RunMacro("skim_setup", net.assign, skim.default, null)

		//DS_Calc
		tazvec.SRVC = tazvec.PRO + tazvec.OSV
		DSvec = {tazvec.HH, tazvec.TOTEMP, tazvec.RET, tazvec.SRVC}
		RunMacro("DScalc", DSvec)
		{tazvec.TOTACT} = GetDataVectors(mvw.taz + "|", {"TotActs"} , {{"Sort Order",{{mvw.taz+".ID","Ascending"}}}} )

		//Accessibility Calculator
		accvec = {tazvec.HH, tazvec.TOTPOP, tazvec.TOTACT, tazvec.TOTEMP, tazvec.BAS, tazvec.IND, tazvec.RET, tazvec.FDL, tazvec.PRO, tazvec.OSV}
		RunMacro("accessibility", accvec)
		{tazvec.GenAccess} = GetDataVectors(mvw.taz + "|", {"GenAccess"} , {{"Sort Order",{{mvw.taz+".ID","Ascending"}}}} )

		//Factor Rural Intrazonals
		RunMacro("IZ_Factor", skim, tazvec)
	endhere: endItem

   Button "step2" 5,  18, 45, 2  Prompt: "02 Run DaySim"   do on escape goto endhere
	controller.loadpaths(null)
	RunMacro("daysim_setup")
	RunMacro("daysim_output", "Auto")
	RunMacro("daysim_output", "Transit")
   endhere: endItem

   Button "step3" 5, 22, 45, 2  Prompt: "03 Run Transit" do on escape goto endhere
	controller.loadpaths(null)
  RunMacro("Initialize")
  RunMacro("Network_Process")
	RunMacro("CloseAll")
	CopyFile(root.net + "MODES.dbf"        , indir.hwy + "MODES.dbf")
	CopyFile(root.net + "MODEXFER.dbf"     , indir.hwy + "MODEXFER.dbf")
	//CopyFile(info.movetabbin, indir.hwy + "MovementTable.bin")
	//CopyFile(info.movetabdcb, indir.hwy + "MovementTable.dcb")
	RunMacro("TransitSkimming")
	RunMacro("CloseAll")
	RunMacro("TransitAssignment")
	RunMacro("TransitReport")
   endhere: endItem

   Button "step4" 5, 26, 45, 2  Prompt: "04 Run Assignment"        do on escape goto endhere
	controller.loadpaths(null)
	RunMacro("EI_Passenger_Model")
	RunMacro("Truck_Model")
	RunMacro("4TCV_Model")
	RunMacro("UpdateTripTable", od)
	RunMacro("Assign_Process", 0, 1)
   endhere: endItem

/*
   Button "step5" 5, 30, 15, 2  Prompt: "Test" do on escape goto endhere
	RunMacro("Initialize")
   endhere: endItem
*/

/*
   Button "in2" 25,  6.25, 10, 1.5  Prompt: "Inputs" do on escape goto endhere RunDBox("input2") endhere: endItem
   Button "in3" 25, 10.25, 10, 1.5  Prompt: "Inputs" do on escape goto endhere RunDBox("input3") endhere: endItem
   Button "in4" 25, 14.25, 10, 1.5  Prompt: "Inputs" do on escape goto endhere RunDBox("input4") endhere: endItem

   //Button "out1"  40,  2.25, 10, 1.5  Prompt: "Outputs" do on escape goto endhere RunDBox("output1") endhere: endItem
   Button "out2"  40,  6.25, 10, 1.5  Prompt: "Outputs" do on escape goto endhere RunDBox("output2") endhere: endItem
   Button "out3"  40, 10.25, 10, 1.5  Prompt: "Outputs" do on escape goto endhere RunDBox("output3") endhere: endItem
   Button "out4"  40, 14.25, 10, 1.5  Prompt: "Outputs" do on escape goto endhere RunDBox("output4") endhere: endItem
*/


//-------------------------------------------------------------------------------------------//
//endfold

  Tab prompt: "Post"
text "Scenario Year" 3, 2.5
//fold
	edit Int "postyear" 20, same, 6 variable: info.pyear format:"0000" do
	pyear = info.pyear
	endItem

   text "Scenario Path:" 2, 5
   button "PathBrowse" 40.5, same, 10 Prompt:"Browse" do on escape goto endhere
		pscendir = ChooseDirectory("Choose the Scenario Folder", {{"Initial Directory", root.mod + "\\2_Scenarios"}})
   endhere:
   endItem
	text "PathDir" 2.5, 6.5, 48 framed variable: pscendir

	text "Scenario TAZ" 3, 11
	button "ScenTAZ"  44, 11, 6.5 Prompt:"Browse" do on escape goto endhere ptazfile = ChooseFile({{"Scenario TAZ (*.dbd)", "*.dbd"},{"Standard (*.dbd)","*.dbd"}}, "Choose a Scenario TAZ", {,{"Initial Directory", pscendir+"\\Outputs\\1_TAZ"},}) endhere: endItem
	text "tazfile"      2.5, 12.5, 48 framed variable: Substitute(ptazfile, pscendir, "..", null)

	text "Scenario Network"  3, 15
	button "ScenNet" 44, 15, 6.5 Prompt:"Browse" do on escape goto endhere plinefile = ChooseFile({{"Scenario Network", "Net*.dbd"}}, "Choose the Scenario Network", {,{"Initial Directory", pscendir+"\\Outputs\\2_Networks"},}) endhere: endItem
	text "masterfile"   2.5, 16.5, 48 framed variable: Substitute(plinefile, pscendir, "..", null)

	text "Trip Matrix"  3, 19
	button "ScenMtx" 44, 19, 6.5 Prompt:"Browse" do on escape goto endhere ptripmtx = ChooseFile({{"Trip Matrix", "Trip*.mtx"}}, "Choose the TripTable", {,{"Initial Directory", pscendir+"\\Outputs\\6_TripTables"},}) endhere: endItem
	text "tripfile"   2.5, 20.5, 48 framed variable: Substitute(ptripmtx, pscendir, "..", null)

   Button "post" 5, 30, 45, 3  Prompt: "Run Post Processor" do on escape goto endhere
   		if pyear < 2014 then pyear = 2014
		if pyear > 2045 then pyear = 2045
		if pyear < 2020 then info.domoves = 0
		if plinefile = null then throw("No Network Selected!")
		if ptazfile = null then throw("No TAZ Selected!")
		ptazvw    = RunMacro("AddLayer", ptazfile, "Area")
		plinevw   = RunMacro("AddLayer", plinefile, "Line")

		modeldir = root.ref
		parampath = root.paramoth
		reppath = pscendir+"\\Outputs\\7_Reports\\"
		if info.domoves = 1 then status = RunProgram("cmd /c mkdir " + pscendir + "\\Outputs\\7_Reports\\MOVES",)
		RunMacro("Post_Process", ptazvw, plinevw, netparam, parampath, reppath, pyear, info.domoves)
		if info.domoves = 1 then RunMacro("Post_MOVES", modeldir, pscendir, ptazvw, plinevw, pyear, ptripmtx)
		ShowMessage("Post Processor Complete!")
	endhere: endItem

//-------------------------------------------------------------------------------------------//
//endfold
EndDbox

//=========================================================================================================

Macro "Initialize"
shared root, info, indir, outdir, mvw
shared net, skim, flow, od, post, daysim
shared netparam, dsparam, accparam

	//Create Scenario/Input/Output folders
	dirinfo = GetDirectoryInfo(root.scen, "Directory")
	if dirinfo = null then status = RunProgram("cmd /c mkdir " + root.scen,)

	for i = 1 to indir.length do
		dirinfo = GetDirectoryInfo(indir[i][2], "Directory")
		if dirinfo = null then status = RunProgram("cmd /c mkdir " + indir[i][2],)
	end

	for i = 1 to outdir.length do
		dirinfo = GetDirectoryInfo(outdir[i][2], "Directory")
		if dirinfo = null then status = RunProgram("cmd /c mkdir " + outdir[i][2],)
	end

	if mvw.scnfile <> null then do
		mvw.linefile = ChooseFileName({{"Standard", "*.dbd"}}, "Choose name for new network file", {,{"Initial Directory", indir.hwy},{"Suggested Name","Network_"+info.scenname}, })
		RunMacro("m2a", mvw.masternet, mvw.scnfile, mvw.linefile, mvw.rtsfile)
		mvw.line = "Network_"+info.scnname
		//After m2a: inlf + inrts should match up ;
	end
	else if mvw.scnfile = null then do
		mvw.linefile = mvw.masternet
	end

	//Sort out the input & output files
		tazpath = SplitPath(mvw.tazfile)
		intf = indir.zone+tazpath[3]+tazpath[4]
		outtf = outdir.zone+tazpath[3]+tazpath[4]

		linepath = SplitPath(mvw.linefile)
		inlf = indir.hwy+linepath[3]+linepath[4]
		outlf = outdir.hwy+linepath[3]+linepath[4]
		outupx = outdir.hwy+linepath[3]+".upx"

	//Write Inputs & Outputs
		if intf <> mvw.tazfile then CopyDatabase(mvw.tazfile, intf)
		if outtf <> mvw.tazfile then CopyDatabase(mvw.tazfile, outtf)

		if inlf <> mvw.linefile then CopyDatabase(mvw.linefile, inlf)
		if outlf <> mvw.linefile then CopyDatabase(mvw.linefile, outlf)

	//Route System
		if mvw.rtsfile <> null then do
			rtspath = SplitPath(mvw.rtsfile)
			inrts = indir.hwy + rtspath[3]+rtspath[4]	//created in m2a

			mvw.rtsfile = RunMacro("UpdateRTS", inrts, outlf)
			rsinfo = GetRouteSystemInfo(mvw.rtsfile)
			mvw.rts = rsinfo[3].Name

			if GetFileInfo(outupx) <> null then DeleteFile(outupx)	//Prevents Transit update dialog
		end

	mvw.tazfile  = outtf
	mvw.linefile = outlf
	tazpath    = SplitPath(mvw.tazfile)
	mvw.tazbin = tazpath[1] + tazpath[2] + tazpath[3] + ".bin"

	//walkfile = "C:\\TSTM_V3\\Data\\AllStreets\\TN_StreetCenterline.dbd"
	//Model Officially Starts Here!
	RunMacro("WriteLog", "RSG Chattanooga Model : "+(info.timestamp))

	//Open layers
		mvw.taz    = RunMacro("AddLayer", mvw.tazfile, "Area")
		mvw.line   = RunMacro("AddLayer", mvw.linefile, "Line")
		mvw.node   = GetNodeLayer(mvw.line)
		SetLayerVisibility(mvw.node, "False")

	//Selection Sets
		SetView(mvw.line)
		ModelSet   = "IN_HIGHWAY > 0"
		//TransitSet = "IN_TRANSIT > 0"
		//WalkSet    = "IN_WALK > 0"

		n = SelectByQuery("Street", "Several", "Select * where "+ModelSet,)
		//n = SelectByQuery("Transit", "Several", "Select * where "+TransitSet,)
		//n = SelectByQuery("Walk", "Several", "Select * where "+WalkSet,)

		SetView(mvw.node)
		CentroidSet = "Centroid = 1"
		n = SelectByQuery("Centroids", "Several", "Select * where "+CentroidSet,)

	//Copy Files to Model Input/Output
		//CopyFile(root.pivot + "Seed_AirSage_Mar01.mtx", od.seed)
		CopyFile(root.pivot + "4TCV_Seed.mtx", od.cvseed)
		CopyFile(root.pivot + "Trk_Seed.mtx", od.trkseed)
		//CopyFile(root.pivot + "Seed_R5.mtx", od.seed)
		CopyFile(root.pivot + "External_Counts_"+i2s(info.modyear)+".dbf", od.countfile)

		CopyFile(root.pivot + "EI_Passenger.mtx", od.eiseed)
		CopyFile(root.pivot + "EE_"+i2s(info.modyear)+".mtx", od.ee)
endMacro


Macro "RunModel"
shared mvw, root, info, indir, outdir //paths
shared net, skim, od, flow, post
shared netparam, dsparam, accparam

shared tazvec, linevec
{r, i, c} = {"r","i","c"}

	RunMacro("WriteLog", "Model Initialize")
	//Intro TAZ & Network Processes
	RunMacro("TAZ_Process")
	RunMacro("Network_Process")

	RunMacro("WriteLog", "Network Skims & Accessibility")
	RunMacro("skim_setup", net.assign, skim.default, null)

//DS_Calc
	tazvec.SRVC = tazvec.PRO + tazvec.OSV
	DSvec = {tazvec.HH, tazvec.TOTEMP, tazvec.RET, tazvec.SRVC}
	RunMacro("DScalc", DSvec)
	{tazvec.TOTACT} = GetDataVectors(mvw.taz + "|", {"TotActs"} , {{"Sort Order",{{mvw.taz+".ID","Ascending"}}}} )

//Accessibility Calculator
	accvec = {tazvec.HH, tazvec.TOTPOP, tazvec.TOTACT, tazvec.TOTEMP, tazvec.BAS, tazvec.IND, tazvec.RET, tazvec.FDL, tazvec.PRO, tazvec.OSV}
	RunMacro("accessibility", accvec)
	{tazvec.GenAccess} = GetDataVectors(mvw.taz + "|", {"GenAccess"} , {{"Sort Order",{{mvw.taz+".ID","Ascending"}}}} )

//Factor Rural Intrazonals
	RunMacro("IZ_Factor", skim, tazvec)


//Process Sub-Models (EI_Pass, Truck, 4TCV)
	RunMacro("WriteLog", "Executing SubModels")
	RunMacro("EI_Passenger_Model")
	RunMacro("Truck_Model")
	RunMacro("4TCV_Model")


	//Transit Skimming
	RunMacro("WriteLog", "Running Transit Skims")
	RunMacro("CloseAll")
	CopyFile(root.net + "MODES.dbf"        , indir.hwy + "MODES.dbf")
	CopyFile(root.net + "MODEXFER.dbf"     , indir.hwy + "MODEXFER.dbf")
	//CopyFile(info.movetabbin, indir.hwy + "MovementTable.bin")
	//CopyFile(info.movetabdcb, indir.hwy + "MovementTable.dcb")
	RunMacro("TransitSkimming")
	RunMacro("CloseAll")

	mvw.taz    = RunMacro("AddLayer", mvw.tazfile, "Area")
	mvw.line   = RunMacro("AddLayer", mvw.linefile, "Line")
	mvw.node   = GetNodeLayer(mvw.line)

while info.prmseam > 1 and info.prmsepm > 1 and info.prmseop > 1 and info.iter < 4 do
	RunMacro("WriteLog", "Start Feedback Iteration "+i2s(info.iter))
	od.triptable = outdir.tables + "TripTable_I"+i2s(info.iter)+".mtx"
	od.daysim = outdir.daysim + "DS_Trips_I"+i2s(info.iter)+".mtx"
	net.time = outdir.hwy + "CongTime_I"+i2s(info.iter)+".bin"

//Run DaySim
	RunMacro("WriteLog", "Starting DaySim")
	RunMacro("daysim_setup")

//Daysim Outputs to TC7 .mtx
	RunMacro("WriteLog", "DaySim Complete")
	RunMacro("daysim_output", "Auto")
	RunMacro("daysim_output", "Transit")

//Process Assignment
	RunMacro("UpdateTripTable", od)

	RunMacro("WriteLog", "Starting Assignment")
	RunMacro("Assign_Process", 0, 1) //[Time of Day & Preload]
	RunMacro("WriteLog", "Assignment Complete")

//Update Congested times to .net
	RunMacro("UpdateTime", mvw.line, {flow.am, flow.pm, flow.op}, net.time)

	RunMacro("update_hnet", 2)
	RunMacro("WriteLog", "Update AM Skim")
	RunMacro("skim_setup", net.assign, skim.am, "AM")
	CopyFile(skim.am, outdir.hwy + "Highway_Skim_AM_I"+i2s(info.iter)+".mtx")

	RunMacro("WriteLog", "Update PM Skim")
	RunMacro("skim_setup", net.assign, skim.pm, "PM")
	CopyFile(skim.pm, outdir.hwy + "Highway_Skim_PM_I"+i2s(info.iter)+".mtx")

	RunMacro("WriteLog", "Update OP Skim")
	RunMacro("skim_setup", net.assign, skim.op, "OP")
	CopyFile(skim.op, outdir.hwy + "Highway_Skim_OP_I"+i2s(info.iter)+".mtx")


	if info.iter > 0 then do
		RunMacro("WriteLog", "Feedback Statistics")
		//od.lasttrip = outdir.tables + "TripTable_I"+i2s(info.iter-1)+".mtx"
		skim.thisam = outdir.hwy + "Highway_Skim_AM_I"+i2s(info.iter)+".mtx"
		skim.thispm = outdir.hwy + "Highway_Skim_PM_I"+i2s(info.iter)+".mtx"
		skim.thisop = outdir.hwy + "Highway_Skim_OP_I"+i2s(info.iter)+".mtx"
		skim.lastam = outdir.hwy + "Highway_Skim_AM_I"+i2s(info.iter-1)+".mtx"
		skim.lastpm = outdir.hwy + "Highway_Skim_PM_I"+i2s(info.iter-1)+".mtx"
		skim.lastop = outdir.hwy + "Highway_Skim_OP_I"+i2s(info.iter-1)+".mtx"

		{info.prmsdam, info.prmseam} = RunMacro("Feedback", skim.thisam, skim.lastam, "AM")
		{info.prmsdpm, info.prmsepm} = RunMacro("Feedback", skim.thispm, skim.lastpm, "PM")
		{info.prmsdop, info.prmseop} = RunMacro("Feedback", skim.thisop, skim.lastop, "OP")

		ptr = OpenFile(info.log, "a")
		ar_log = { "Iteration "+i2s(info.iter)    ,
					"AM_PRMSD: "+r2s(info.prmsdam),
					"PM_PRMSD: "+r2s(info.prmsdpm),
					"OP_PRMSD: "+r2s(info.prmsdop),
					"AM_PRMSE: "+r2s(info.prmseam) ,
					"PM_PRMSE: "+r2s(info.prmsepm) ,
					"OP_PRMSE: "+r2s(info.prmseop)
				}
		WriteArray(ptr, ar_log)
		CloseFile(ptr)
	end


//Update iter on variables
	info.iter = info.iter + 1
	dt = CreateDateTime()
	info.timestamp = FormatDateTime(dt,"MMMddyyyy_HHmm")
	net.time = outdir.hwy + "CongTime_I"+i2s(info.iter)+".bin"
	skim.default = outdir.hwy + "Highway_Skim_I"+i2s(info.iter)+".mtx"
	flow.pream  = outdir.tables + "AsnVol_preAM_I"+i2s(info.iter)+".bin"
	flow.prepm  = outdir.tables + "AsnVol_prePM_I"+i2s(info.iter)+".bin"
	flow.preop  = outdir.tables + "AsnVol_preOP_I"+i2s(info.iter)+".bin"
	flow.am     = outdir.tables + "AsnVol_AM_I"+i2s(info.iter)+".bin"
	flow.pm     = outdir.tables + "AsnVol_PM_I"+i2s(info.iter)+".bin"
	flow.op     = outdir.tables + "AsnVol_OP_I"+i2s(info.iter)+".bin"
end
//RunMacro("dropfields", mvw.line,{"AB_AM_Time","BA_AM_Time","AB_PM_Time","BA_PM_Time","AB_OP_Time","BA_OP_Time"})

//Process Transit
RunMacro("CloseAll")
RunMacro("WriteLog", "Transit Assignment")
RunMacro("TransitAssignment")
RunMacro("TransitReport")
RunMacro("WriteLog", "Transit Complete")

RunMacro("CloseAll")
RunMacro("daysim_postprocess")
RunMacro("WriteLog", "Model Complete")
endMacro

Macro "TAZ_Process"
shared mvw, info, root, indir, outdir
shared net, skim, od, flow, post
shared netparam, dsparam, accparam
shared tazvec, linevec
{r, i, c} = {"r","i","c"}

	//Create employment groups from NAICS
	SetView(mvw.taz)
	RunMacro("addfields", mvw.taz, {"Basic_Emp", "Indust_Emp","Retail_Emp","FoodLd_Emp","ProSrv_Emp","OthSrv_Emp"}, {"r","r","r","r","r","r"})
	exp.BAS = CreateExpression(mvw.taz, "BAS", "empoth_p"                      , null)
	exp.IND = CreateExpression(mvw.taz, "IND", "empind_p"                      , null)
	exp.RET = CreateExpression(mvw.taz, "RET", "empret_p"                      , null)
	exp.FDL = CreateExpression(mvw.taz, "FDL", "empfoo_p"                      , null)
	exp.PRO = CreateExpression(mvw.taz, "PRO", "empofc_p + empmed_p + empgov_p", null)
	exp.OSV = CreateExpression(mvw.taz, "OSV", "empedu_p + empsvc_p"           , null)
	SetRecordsValues(null, {{"Basic_Emp","Indust_Emp","Retail_Emp","FoodLd_Emp","ProSrv_Emp","OthSrv_Emp"}, null}, "Formula", {"BAS","IND","RET","FDL","PRO","OSV"}, null)

	//RunMacro("addfields", mvw.taz, {"INCHH_QRMTG"}, {"r"})
	//exp.QRINC  = CreateExpression(mvw.taz, "QRINC" , "HHINC/1000", null)
	//SetRecordsValues(null, {{"INCHH_QRMTG"}, null}, "Formula", {"QRINC"},null)

	arr = GetExpressions(mvw.taz)
	for fld = 1 to arr.length do DestroyExpression(mvw.taz+"."+arr[fld]) end

	{tazvec.ID, tazvec.TAZArea, tazvec.HH, tazvec.TOTPOP,  tazvec.BAS, tazvec.IND , tazvec.RET , tazvec.FDL , tazvec.PRO , tazvec.OSV} = GetDataVectors(mvw.taz+"|",
	{"ID"     , "Area"        , "HH"     ,"TOTPOP"      , "Basic_Emp","Indust_Emp","Retail_Emp","FoodLd_Emp","ProSrv_Emp","OthSrv_Emp"}, {{"Sort Order",{{"ID","Ascending"}}}, {"Missing as Zero", "True"}})

	//Calculate TOTEMP, PopDens, EmpDens
	RunMacro("addfields", mvw.taz, {"Total_Emp", "TotActs","ACTDIV","EmpDens","PopDens"}, {r,r,r,r,r})
	 tazvec.TOTEMP = tazvec.BAS + tazvec.IND + tazvec.RET + tazvec.FDL + tazvec.PRO + tazvec.OSV
	 tazvec.EmpDens = tazvec.TOTEMP / tazvec.TAZArea
	 tazvec.PopDens = tazvec.TOTPOP / tazvec.TAZArea
	SetDataVectors(mvw.taz+"|", {{"Total_Emp", tazvec.TOTEMP}, {"EmpDens", tazvec.EmpDens}, {"PopDens",tazvec.PopDens}}, {{"Sort Order",{{"ID","Ascending"}}}})

endMacro

Macro "Network_Process"
shared mvw, info, root, net, skim
shared netparam, dsparam, accparam
shared tazvec, linevec
{r, i, c} = {"r","i","c"}

	SetView(mvw.line)

	//Line Layer Vectors
	{linevec.ID, linevec.Leng, linevec.Dir, linevec.FCCLASS , linevec.FCAREA, linevec.Access, linevec.AB_Lanes, linevec.BA_Lanes, linevec.Ramp, linevec.Median, linevec.Divided, linevec.TAZID, linevec.TurnLane, linevec.LnWidth, linevec.RsWidth, linevec.PSpeed, linevec.PSpeed_Adj, linevec.auxlane, linevec.weavelane, linevec.truckclimb, linevec.ab_basevol, linevec.ba_basevol} = GetDataVectors(mvw.line + "|",
	{"ID"      , "Length"    ,"Dir"       , "FUNCCLASS",      "DOT_FCAREA",   "Access"       , "AB_LANES"      , "BA_LANES"      , "RAMP"      , "MEDIAN"      , "DIVIDED"      , "TAZID"      ,"TWOTURNLN"      ,"LN_Width"      ,"RS_Width"      ,"SPD_LMT"      , "PSpeed_Adj"      , "AUXLANE"      , "WEAVELANE"      , "MTN_TERRA"       , "AB_BaseVol"      , "BA_BaseVol"}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}} )

  // Calculate NEW funcclass(FUNCNEW) based on FHWA rewised functional class code and TPO designated urbanized areas--YS 2/17/2021
	RunMacro("addfields", mvw.line, {"FUNCNEW"}, {"i"})

   FCCLASS = linevec.FCCLASS
   FCAREA = linevec.FCAREA

	 FUNCNEW = if FCCLASS = 1 and FCAREA = 1 then 1
	 else if FCCLASS = 1 and FCAREA = 2 then 11

	 else if (FCCLASS = 2 or FCCLASS = 3) and FCAREA = 1 then 2
	 else if FCCLASS = 2 and FCAREA = 2 then 12
	 else if FCCLASS = 3 and FCAREA = 2 then 14

	 else if FCCLASS = 4 and FCAREA = 1 then 6
	 else if FCCLASS = 4 and FCAREA = 2 then 16

	 else if FCCLASS = 5 and FCAREA = 1 then 7
	 else if (FCCLASS = 5 or FCCLASS = 6) and FCAREA = 2 then 17
	 else if FCCLASS = 6 and FCAREA = 1 then 8

	 else if FCCLASS = 7 and FCAREA = 1 then 9
	 else if FCCLASS = 7 and FCAREA = 2 then 19

	 else if FCCLASS = 20 then 20

	 else FCCLASS

   SetDataVector(mvw.line + "|", "FUNCNEW", Nz(FUNCNEW), {{"Sort Order",{{"ID","Ascending"}}}})
  // Add I24_Cal to ajust capacity on I24--YS 10/29/2021
	{linevec.ID, linevec.Leng, linevec.Dir, linevec.I24_Cal, linevec.FC ,linevec.Access, linevec.AB_Lanes, linevec.BA_Lanes, linevec.Ramp, linevec.Median, linevec.Divided, linevec.TAZID, linevec.TurnLane, linevec.LnWidth, linevec.RsWidth, linevec.PSpeed, linevec.PSpeed_Adj, linevec.auxlane, linevec.weavelane, linevec.truckclimb, linevec.ab_basevol, linevec.ba_basevol} = GetDataVectors(mvw.line + "|",
	{"ID"      , "Length"    ,"Dir"       , "I24_Cal", "FUNCNEW",  "Access"       , "AB_LANES"      , "BA_LANES"      , "RAMP"      , "MEDIAN"      , "DIVIDED"      , "TAZID"      ,"TWOTURNLN"      ,"LN_Width"      ,"RS_Width"      ,"SPD_LMT"      , "PSpeed_Adj"      , "AUXLANE"      , "WEAVELANE"      , "MTN_TERRA"       , "AB_BaseVol"      , "BA_BaseVol"}, {{"Sort Order",{{mvw.line+".ID","Ascending"}}}} )

	//RunMacro("IntrsctnDens")

	controlvec = {linevec.Dir, linevec.AB_Lanes, linevec.BA_Lanes, linevec.FC, linevec.Ramp}
		RunMacro("controls", controlvec)
	{linevec.ACtrl, linevec.BCtrl, linevec.APrio, linevec.BPrio, linevec.ASync, linevec.BSync} = GetDataVectors(mvw.line + "|", {"A_Control","B_Control","A_Priority","B_Priority","A_Synch","B_Synch"} , {{"Sort Order",{{mvw.line+".ID","Ascending"}}}} )

	// Add I24_Cal to ajust capacity on I24--YS 10/29/2021
	spdfld = {linevec.Leng, linevec.Dir, linevec.I24_Cal, linevec.FC, linevec.Access, linevec.AB_Lanes, linevec.BA_Lanes, linevec.Ramp, linevec.Median, linevec.TAZID, linevec.TurnLane, linevec.LnWidth, linevec.RsWidth, linevec.PSpeed, linevec.PSpeed_Adj, linevec.ACtrl, linevec.BCtrl, linevec.APrio, linevec.BPrio, linevec.ASync, linevec.BSync, linevec.auxlane, linevec.weavelane, linevec.truckclimb, linevec.ab_basevol, linevec.ba_basevol}
		RunMacro("spdcap", spdfld)
		RunMacro("gencost_setup")

	if info.iter = 0 then do
		RunMacro("addfields", mvw.line, {"AB_AM_Time","BA_AM_Time","AB_PM_Time","BA_PM_Time","AB_OP_Time","BA_OP_Time","AB_CTime","BA_CTime"}, {"r","r","r","r","r","r","r","r"})
		SetRecordsValues(null, {{"AB_AM_Time","BA_AM_Time","AB_PM_Time","BA_PM_Time","AB_OP_Time","BA_OP_Time","AB_CTime","BA_CTime"}, null}, "Formula", {"FFTime","FFTime","FFTime","FFTime","FFTime","FFTime","FFTime","FFTime"},null)
		RunMacro("create_hnet")
	end

		if info.iter > 0 then RunMacro("update_hnet", 1)

	// RunMacro("dropfields", mvw.line, {"FUNCNEW"})

endMacro

Macro "IZ_Factor" (skim, tazvec)
		skimmtx = OpenMatrix(skim.default, )
		mctime = RunMacro("CheckMatrixCore", skimmtx, "AFFTime (Skim)", "Origin", "Destination")
		iztime = GetMatrixVector(mctime, {{"Diagonal", "Row"}})
		izruralf = 1 - 0.9*exp(-exp((tazvec.GenAccess - 9.0)))
		iztimef = iztime * izruralf
		SetMatrixVector(mctime, iztimef, {{"Diagonal"}})
endMacro

Macro "UpdateTripTable" (od)
	shared root
		//Join OD matrices into TripTable.mtx for assignment

		CopyFile(od.daysim, od.triptable)

		odmtx = OpenMatrix(od.triptable, "Auto")
		odname = RenameMatrix(odmtx, "TripTable")
		odfinal = CreateMatrixCurrencies(odmtx,null,null,null)

		//od.eiseed    = root.pivot + "EI_Pass_Seed.mtx"
		eiOD = OpenMatrix(od.eiauto, "Auto")
		ei = CreateMatrixCurrencies(eiOD,null,null,null)
			odfinal.AM_Pass := odfinal.AM_Pass + nz(ei.AM_EIPass)
			odfinal.PM_Pass := odfinal.PM_Pass + nz(ei.PM_EIPass)
			odfinal.OP_Pass := odfinal.OP_Pass + nz(ei.OP_EIPass)

		//od.cv = root.pivot + "4TCV_Seed.mtx"
		cvOD = OpenMatrix(od.cv,)
		cv = CreateMatrixCurrencies(cvOD,null,null,null)
			odfinal.AM_Pass := odfinal.AM_Pass + nz(cv.AM_CV)
			odfinal.PM_Pass := odfinal.PM_Pass + nz(cv.PM_CV)
			odfinal.OP_Pass := odfinal.OP_Pass + nz(cv.OP_CV)

		//od.trk = root.pivot + "Trk_Seed.mtx"
		trkOD = OpenMatrix(od.trk, "Auto")
		trks = CreateMatrixCurrencies(trkOD,null,null,null)
			 odfinal.AM_SUT := trks.AM_SUT
			 odfinal.PM_SUT := trks.PM_SUT
			 odfinal.OP_SUT := trks.OP_SUT
			 odfinal.AM_MUT := trks.AM_MUT
			 odfinal.PM_MUT := trks.PM_MUT
			 odfinal.OP_MUT := trks.OP_MUT

		odfinal.PASS := odfinal.AM_Pass + odfinal.PM_Pass + odfinal.OP_Pass
		odfinal.SUT := odfinal.AM_SUT + odfinal.PM_SUT + odfinal.OP_SUT
		odfinal.MUT := odfinal.AM_MUT + odfinal.PM_MUT + odfinal.OP_MUT

endMacro

Macro "Assign_Process" (tod, preload)
shared mvw, info, root, indir, outdir
shared net, skim, od, flow, post
shared netparam, dsparam, accparam

//Processing
	RunMacro("addfields", mvw.line, {"AB_AM_Auto"   , "BA_AM_Auto"   , "Tot_AM_Auto"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_AM_SUT"    , "BA_AM_SUT"    , "Tot_AM_SUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_AM_MUT"    , "BA_AM_MUT"    , "Tot_AM_MUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_AM_TotFlow", "BA_AM_TotFlow", "AM_TotFlow"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_PM_Auto"   , "BA_PM_Auto"   , "Tot_PM_Auto"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_PM_SUT"    , "BA_PM_SUT"    , "Tot_PM_SUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_PM_MUT"    , "BA_PM_MUT"    , "Tot_PM_MUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_PM_TotFlow", "BA_PM_TotFlow", "PM_TotFlow"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_OP_Auto"   , "BA_OP_Auto"   , "Tot_OP_Auto"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_OP_SUT"    , "BA_OP_SUT"    , "Tot_OP_SUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_OP_MUT"    , "BA_OP_MUT"    , "Tot_OP_MUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_OP_TotFlow", "BA_OP_TotFlow", "OP_TotFlow"} , {"r","r","r"})

	SetRecordsValues(mvw.line+"|", {{"AB_AM_Auto"   , "BA_AM_Auto"   , "Tot_AM_Auto"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_AM_SUT"    , "BA_AM_SUT"    , "Tot_AM_SUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_AM_MUT"    , "BA_AM_MUT"    , "Tot_AM_MUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_AM_TotFlow", "BA_AM_TotFlow", "AM_TotFlow"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_PM_Auto"   , "BA_PM_Auto"   , "Tot_PM_Auto"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_PM_SUT"    , "BA_PM_SUT"    , "Tot_PM_SUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_PM_MUT"    , "BA_PM_MUT"    , "Tot_PM_MUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_PM_TotFlow", "BA_PM_TotFlow", "PM_TotFlow"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_OP_Auto"   , "BA_OP_Auto"   , "Tot_OP_Auto"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_OP_SUT"    , "BA_OP_SUT"    , "Tot_OP_SUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_OP_MUT"    , "BA_OP_MUT"    , "Tot_OP_MUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_OP_TotFlow", "BA_OP_TotFlow", "OP_TotFlow"} , null}, "Value", {0,0,0}, null)

	RunMacro("addfields", mvw.line, {"AB_Auto"   , "BA_Auto"  , "Tot_Auto"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_SUT"    , "BA_SUT"   , "Tot_SUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_MUT"    , "BA_MUT"   , "Tot_MUT"} , {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_TotFlow", "BA_TotFlow", "TotFlow"}  , {"r","r","r"})
	SetRecordsValues(mvw.line+"|", {{"AB_Auto"   , "BA_Auto"   , "Tot_Auto"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_SUT"    , "BA_SUT"    , "Tot_SUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_MUT"    , "BA_MUT"    , "Tot_MUT"} , null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_TotFlow", "BA_TotFlow", "TotFlow"} , null}, "Value", {0,0,0}, null)


//Preload EEs
	RunMacro("addfields", mvw.line, {"AB_PreFlow","BA_PreFlow","PreFlow"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_AMPrePCE","BA_AMPrePCE","AMPrePCE"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_PMPrePCE","BA_PMPrePCE","PMPrePCE"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_OPPrePCE","BA_OPPrePCE","OPPrePCE"}, {"r","r","r"})
	SetRecordsValues(mvw.line+"|", {{"AB_PreFlow","BA_PreFlow","PreFlow"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_AMPrePCE","BA_AMPrePCE","AMPrePCE"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_PMPrePCE","BA_PMPrePCE","PMPrePCE"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_OPPrePCE","BA_OPPrePCE","OPPrePCE"}, null}, "Value", {0,0,0}, null)

 //if tod = 1 then RunMacro("MultiClassPreloadSetup")
 RunMacro("MultiClassTODPreloadSetup")
 RunMacro("PCEFlowCalc")
 RunMacro("update_hnet", 2) //Update Preload volumes to Assignment.net


//Assignment
RunMacro("MultiClassTODAssignSetup")
//if tod = 1 then RunMacro("MultiClassAssignSetup")
RunMacro("TotFlowCalc")

RunMacro("addfields", mvw.line, {"AB_TRKFlow", "BA_TRKFlow", "Tot_TRKFlow"}, {"r","r","r"})
ABTrk = CreateExpression(mvw.line, "ABTrk" , "AB_SUT + AB_MUT", null)
BATrk = CreateExpression(mvw.line, "BATrk" , "BA_SUT + BA_MUT", null)
TotTrk = CreateExpression(mvw.line, "TotTrk" , "Tot_SUT + Tot_MUT", null)
SetRecordsValues(null, {{"AB_TRKFlow","BA_TRKFlow","Tot_TRKFlow"}, null}, "Formula", {"ABTrk","BATrk","TotTrk"},null)

//Reporting
if info.modyear = 2019 then do // update 2014 to 2019 --YS
	{calSUT.type , calSUT.vol , calSUT.cnt} = {"SUT", "Tot_SUT", "AADT_SUT"}
	RunMacro("CalRep", 0, calSUT)

	{calMUT.type , calMUT.vol , calMUT.cnt} = {"MUT", "Tot_MUT", "AADT_MUT"}
	RunMacro("CalRep", 0, calMUT)

	{calALL.type, calALL.vol, calALL.cnt} = {"All", "TotFlow", "AADT"}
	RunMacro("CalRep", 1, calALL)

	{calTRK.type, calTRK.vol, calTRK.cnt} = {"Trk", "Tot_TRKFlow", "AADT_TRK"}
	RunMacro("CalRep", 0, calTRK)
end
endMacro

Macro "Feedback" (newod, lastod, tod)
	newmat = OpenMatrix(newod, "Auto")
	oldmat = OpenMatrix(lastod, "Auto")
	//newmc = CreateMatrixCurrencies(newmat, , ,)
	//oldmc = CreateMatrixCurrencies(oldmat, , ,)

	if tod = "AM" then do
		newtimemc = RunMacro("CheckMatrixCore", newmat, "AMTime (Skim)", ,)
		oldtimemc = RunMacro("CheckMatrixCore", oldmat, "AMTime (Skim)", ,)
	end
	if tod = "PM" then do
		newtimemc = RunMacro("CheckMatrixCore", newmat, "PMTime (Skim)", ,)
		oldtimemc = RunMacro("CheckMatrixCore", oldmat, "PMTime (Skim)", ,)
	end
	if tod = "OP" then do
		newtimemc = RunMacro("CheckMatrixCore", newmat, "OPTime (Skim)", ,)
		oldtimemc = RunMacro("CheckMatrixCore", oldmat, "OPTime (Skim)", ,)
	end

	oldstats = MatrixStatistics(oldmat, )

	diffmc = RunMacro("CheckMatrixCore", newmat, "SquaredDiff", ,)
	diffmc := Pow(newtimemc - oldtimemc,2)

	matstats = MatrixStatistics(newmat, )
	sse  = matstats.SquaredDiff.Sum
	tcnt = matstats.SquaredDiff.Count

	if tod = "AM" then sv = matstats.[AMTime (Skim)].Sum
	if tod = "PM" then sv = matstats.[PMTime (Skim)].Sum
	if tod = "OP" then sv = matstats.[OPTime (Skim)].Sum

	prmsd = Pow(sse/tcnt,0.5) / (sv/tcnt)

	rmsestats = MatrixRMSE(newtimemc, oldtimemc)
	//rmsestats.Observations
	//rmsestats.RMSE
	//rmsestats.RelRMSE
	//rmsestats.PercentDiff

Return({prmsd, rmsestats.RelRMSE})
endMacro

Macro "WriteLog" (msg)
shared info
logtime = CreateDateTime()
timestamp = FormatDateTime(logtime, "MMMdd_HHmm")

ptr = OpenFile(info.log, "a")
ar_log = { timestamp+": "+msg }
WriteArray(ptr, ar_log)
CloseFile(ptr)

endMacro

Macro "RunCalRep"
shared mvw
mvw.line = GetView()

/*
{calSUT.type , calSUT.vol , calSUT.cnt} = {"SUT", "Tot_SUT", "AADT_SUT"}
RunMacro("CalRep", 0, calSUT)

{calMUT.type , calMUT.vol , calMUT.cnt} = {"MUT", "Tot_MUT", "AADT_MUT"}
RunMacro("CalRep", 0, calMUT)

RunMacro("addfields", mvw.line, {"Tot_TRK"}, {"r"})
TotTrk = CreateExpression(mvw.line, "TotTrk" , "Tot_SUT + Tot_MUT", null)
SetRecordsValues(null, {{"Tot_TRK"}, null}, "Formula", {"TotTrk"},null)

{calTRK.type, calTRK.vol, calTRK.cnt} = {"Trk", "Tot_TRK", "AADT_TRK"}
RunMacro("CalRep", 0, calTRK)
*/

{calALL.type, calALL.vol, calALL.cnt} = {"All", "TotFlow", "AADT"}
RunMacro("CalRep", 1, calALL)

endMacro
