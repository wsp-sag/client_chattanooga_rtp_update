//Batch record templates for TransCAD 7.0

Macro "skim" (skim)
    RunMacro("TCB Init")
    Opts = null
    Opts.Input.Network = skim.net
    Opts.Input.[Origin Set] = skim.origin
    Opts.Input.[Destination Set] = skim.destination
    Opts.Input.[Via Set] = skim.set
    Opts.Field.Minimize = skim.min
    Opts.Field.Nodes = skim.nodes
    Opts.Field.[Skim Fields] = skim.flds
	Opts.Field.[Skim by Set] = skim.skimset
    Opts.Flag = {}
    Opts.Output.[Output Matrix].Label = "Shortest Path"
    Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = skim.out
    ok = RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret)
    if !ok then Return(RunMacro("TCB Closing", ok, True))
endMacro

Macro "intrazonal" (intra)
	//intramtx = OpenMatrix(intra.skim, "True")
	
	for i = 1 to intra.flds.length do
		//mcintra = RunMacro("CheckMatrixCore", intramtx, intra.flds[i], "Origin", "Destination")
		intra.fld = intra.flds[i]
		
		RunMacro("TCB Init")
		Opts = null
		Opts.Input.[Matrix Currency] = {intra.skim, intra.fld, "Origin", "Destination"}
		Opts.Global.Factor          = intra.factor
		Opts.Global.Neighbors       = intra.neighbors
		Opts.Global.Operation       = intra.operation
		Opts.Global.[Treat Missing] = intra.missing

	   ok = RunMacro("TCB Run Procedure", "Intrazonal", Opts, &Ret)
	   if !ok then Return(RunMacro("TCB Closing", ok, True))
	end
	
endMacro

Macro "NestedLogitApp" (nla)
	{invw, inputfile, inid, modfilename, outfilename, tazvw} = nla
	 
     dataset = {inputfile, invw} 
     if invw = mvw.taz then dataset = {inputfile+ "|"+ invw, invw}

    RunMacro("TCB Init")

// STEP 1: NestedLogitEngine
     Opts = null
     Opts.Global.[Missing Method] = "Drop Mode"
     Opts.Global.[Base Method] = "On View"
     Opts.Global.[Small Volume To Skip] = 0.001
     Opts.Global.[Utility Scaling] = "By Parent Theta"
     Opts.Global.Model = modfilename
     Opts.Flag.[Post Process] = "True"
     Opts.Scaling = 2
     Opts.DropRecord = 0
     Opts.Input.[Data1 Set] = dataset
     Opts.Output.[Probability Table] = outfilename
     Opts.Field.[Primary ID] = invw+"."+inid

     if !RunMacro("TCB Run Procedure", "NestedLogitEngine", Opts, &Ret) then Return(RunMacro("TCB Closing", null, "TRUE"))

endMacro

Macro "Subarea_Assignment" //incomplete
    RunMacro("TCB Init")
// STEP 1: Subarea Assignment
    Opts = null
    Opts.Input.Database = "C:\\TSTM_V2\\2_Scenarios\\2010_Subarea\\Outputs\\2_Highway-Network\\Network_Base.DBD"
    Opts.Input.Network = "C:\\TSTM_V2\\2_Scenarios\\2010_Subarea\\Outputs\\2_Highway-Network\\Preload.net"
    Opts.Input.[OD Matrix Currency] = {"C:\\TSTM_V2\\1_Model-Files\\3_pivoting\\Vehicle_ODME_TTB_v28_5.mtx", "ATRI_TRUCK (0-24)", "Assign_IDs", "Assign_IDs"}
	Opts.Input.[Sub Centroid Set] = {"C:\\TSTM_V2\\2_Scenarios\\2010_Subarea\\Outputs\\2_Highway-Network\\Network_Base.DBD|Node", "Node", "Sub_Centroids", "Select * where BristolCC = 1"}
    Opts.Input.[Ext Station Set] = {"C:\\TSTM_V2\\2_Scenarios\\2010_Subarea\\Outputs\\2_Highway-Network\\Network_Base.DBD|Node", "Node", "Sub_External", "Select * Where BristolEXT = 1"}
    Opts.Input.[Boundary Link Set] = {"C:\\TSTM_V2\\2_Scenarios\\2010_Subarea\\Outputs\\2_Highway-Network\\Network_Base.DBD|Network_Base", "Network_Base", "Sub_Links", "Select * Where Bristol = 1"}
    Opts.Field.[VDF Fld Names] = {"[AB_AFFTime / BA_AFFTime]", "[AB_DlyCap / BA_DlyCap]", "[AB_bprA / BA_bprA]", "[AB_bprB / BA_bprB]", "None"}
	Opts.Global.[Subarea Method] = 3
    Opts.Global.[Load Method] = "AON"
    Opts.Global.[Loading Multiplier] = 1
    Opts.Global.[VDF DLL] = "C:\\Program Files\\TransCAD 6.0\\bpr.vdf"
    Opts.Global.[VDF Defaults] = {, , 0.15, 4, 0}
    Opts.Flag.[Do Theme] = 0
    Opts.Output.[Flow Table] = "C:\\TSTM_V2\\Subarea\\Bristol_LinkFlow.bin"
    Opts.Output.[Subarea OD Matrix].Label = "Subarea OD Matrix"
    Opts.Output.[Subarea OD Matrix].Compression = 1
    Opts.Output.[Subarea OD Matrix].[File Name] = "C:\\TSTM_V2\\Subarea\\Bristol_OD.mtx"

    ok = RunMacro("TCB Run Procedure", "Subarea Assignment", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )
endMacro
