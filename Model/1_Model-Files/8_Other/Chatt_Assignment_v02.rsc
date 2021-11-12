//Assignment_v01.rsc - MUST BE COMPILED WITH RSG_Tools_v#.rsc
//TransCAD 7.0 Assignment & ODME script
//STrevino 01/11/16

/*
Inputs Needed:
1. *.dbd network/node (TC7)
2. *.net with all necessary .dbd input fields
3. *.mtx to assign - must have INDEX matching node layer IDs
4. netparams.dbf OR value of time parameters (VOT/VOI)

To Run:
1. Modify RunAssignment and AssignSetup macros
2. Compile this + RSG_Tools_v#.rsc
3. Test "RunAssignment" or "RunODME" macro
*/

//Initialize
Macro "CHCRPA_Assignment"
shared root, net, mvw, outdir
shared netparam, calrep
shared od, flow

preload = 1
root.path = "C:\\Projects\\Chattanooga\\Model\\"
root.output = root.path + "\\2_Scenarios\\2010_Base\\Outputs\\"
od.mtx = root.output + "6_TripTables\\SPT_AirSage.mtx"	//Input (3)
outdir.tables = root.output + "6_TripTables\\"
/*
//Inputs
root.paramoth = root.path + "\\1_Model-Files\\6_Parameters\\2_Other\\"
outdir.rep = root.path

mvw.linefile = root.output + "2_Networks\\Network_Base.dbd"	//Input (1)
net.assign = root.output + "2_Networks\\Assignment.net"	//Input (2)

netparamfile  = root.paramoth + "netparams.dbf" //Input (4)
netparam  = RunMacro("LoadParams", netparamfile, 0)


//Outputs
flow.pream = outdir.tables + "AsnVol_preAM.bin"
flow.prepm = outdir.tables + "AsnVol_prePM.bin"
flow.premd = outdir.tables + "AsnVol_preMD.bin"
flow.prent = outdir.tables + "AsnVol_preNT.bin"

flow.am =  outdir.tables + "AsnVol_AM.bin"
flow.pm =  outdir.tables + "AsnVol_PM.bin"
flow.md =  outdir.tables + "AsnVol_MD.bin"
flow.nt =  outdir.tables + "AsnVol_NT.bin"
*/
flow.predly = outdir.tables + "AsnVol_preDly.bin"
flow.dly = outdir.tables + "AsnVol_Dly.bin"

//Processing
mvw.line   = RunMacro("AddLayer", mvw.linefile, "Line")
mvw.node   = GetNodeLayer(mvw.line)

RunMacro("addfields", mvw.line, {"AB_TotFlow","BA_TotFlow","TotFlow"}, {"r","r","r"})
SetRecordsValues(mvw.line+"|", {{"AB_TotFlow","BA_TotFlow","TotFlow"}, null}, "Value", {0,0,0}, null)

//Execute Preload & Assignment
if preload = 1 then do
	RunMacro("addfields", mvw.line, {"AB_PreFlow","BA_PreFlow","PreFlow"}, {"r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, {"r","r","r"})
	SetRecordsValues(mvw.line+"|", {{"AB_PreFlow","BA_PreFlow","PreFlow"}, null}, "Value", {0,0,0}, null)
	SetRecordsValues(mvw.line+"|", {{"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, null}, "Value", {0,0,0}, null)
	RunMacro("MultiClassPreloadSetup")
end

//Update Preload volumes to Assignment.net
 RunMacro("update_hnet", 1)

//RunMacro("SingleClassAssignSetup")
RunMacro("MultiClassAssignSetup")

//Reporting
calrep.info = root.paramoth + "CHCRPA_calrepinfo.bin"

{calSUT.type , calSUT.vol , calSUT.cnt} = {"SUT", "Tot_SUT", "AADT_SUT"}
RunMacro("CalRep", 0, calSUT)

{calMUT.type , calMUT.vol , calMUT.cnt} = {"MUT", "Tot_MUT", "AADT_MUT"}
RunMacro("CalRep", 0, calMUT)

{calALL.type, calALL.vol, calALL.cnt} = {"All", "TotFlow", "AADT"}
RunMacro("CalRep", 1, calALL)

//ShowMessage("Complete!")
endMacro

Macro "RunODME"
shared root, net, mvw, info, skim, seed, outdir
shared netparam, gencostfile, calrep
shared od, odmemtx, flow

	root.path = "C:\\Projects\\Chattanooga\\ODME\\"
	root.path = "E:\\Projects\\Clients\\15029_ChattanoogaTDM\\ODME\\"
	mvw.tazfile = root.path + "TAZ\\CHCRPA_TAZ_Mar01.dbd"
	mvw.linefile = root.path + "Net\\Network_Base_DSF3.dbd"
	net.assign = root.path + "Assignment.net"
	net.odme = net.assign
	info.iter = 0
	info.odmelog = root.path + "ODME_Report.txt"
	ODMEiter = 6   //Number of iterations

	od.ee = root.path + "EE_2010_v1.mtx"
	//seed.mtx = root.path + "Seed_AirSage_Mar01.mtx"
	//seed.mtx = root.path + "Seed_SUTII60.mtx"
	seed.mtx = root.path + "DS4Tv2.mtx"

	seed.min = root.path + "Seed_Min.mtx"
	seed.max = root.path + "Seed_Max.mtx"
	seed.class = {"AutoTrips", "SUTrk", "MUTrk"}
	{seed.ridx, seed.cidx} = {"Row ID's", "Col ID's"}
	//{seed.ridx, seed.cidx} = {"Origins", "Destinations"}

	info.calrep = root.path + "CHCRPA_calrepinfo.bin"
	outdir.rep = root.path
	outdir.tables = root.path

	netparamfile  = root.path + "netparams.dbf"
	netparam  = RunMacro("LoadParams", netparamfile, 0)

	//mvw.taz    = RunMacro("AddLayer", mvw.tazfile, "Area")
	mvw.line   = RunMacro("AddLayer", mvw.linefile, "Line")
	mvw.node   = GetNodeLayer(mvw.line)
	SetLayerVisibility(mvw.node, "False")

	mapname = GetMap()
	if mapname <> null then SetMapRedraw(null, "False")
	SetSelectDisplay("False")

	//Add Fields
	RunMacro("addfields", mvw.line, {"AB_carcntfact","BA_carcntfact","AB_carnumcnt","BA_carnumcnt"}, {"r","r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_sutcntfact","BA_sutcntfact","AB_sutnumcnt","BA_sutnumcnt"}, {"r","r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_mutcntfact","BA_mutcntfact","AB_mutnumcnt","BA_mutnumcnt"}, {"r","r","r","r"})
	RunMacro("addfields", mvw.line, {"AB_DLYPrePCE","BA_DLYPrePCE"}, {"r","r"})
	RunMacro("addfields", mvw.line, {"AB_AMPrePCE","BA_AMPrePCE"}, {"r","r"})
	RunMacro("addfields", mvw.line, {"AB_PMPrePCE","BA_PMPrePCE"}, {"r","r"})
	RunMacro("addfields", mvw.line, {"AB_OPPrePCE","BA_OPPrePCE"}, {"r","r"})
	RunMacro("addfields", mvw.line, {"AB_AM_Time","BA_AM_Time","AB_PM_Time","BA_PM_Time","AB_OP_Time","BA_OP_Time","AB_CTime","BA_CTime"}, {"r","r","r","r","r","r","r","r"})


//Vince ODME
	for iter = 0 to ODMEiter do
		info.iter = iter
		if iter = 0 then od.triptable = seed.mtx else od.triptable = root.path+"ODME_i"+i2s(iter)+".mtx"	//prev OD mtx
		flow.dly = root.path + "ODME_Flow_i"+i2s(iter)+".bin"
		flow.predly = root.path + "ODME_PreFlow_i"+i2s(iter)+".bin"
		od.nextmtx   = root.path+"ODME_i"+i2s(iter+1)+".mtx"
		skim.odme = root.path+"ODMEskim_"+i2s(iter+1)+".mtx"

		RunMacro("addfields", mvw.line, {"AB_Auto", "BA_Auto", "Tot_Auto"}, {"r","r","r"})
		RunMacro("addfields", mvw.line, {"AB_SUT", "BA_SUT", "Tot_SUT"}, {"r","r","r"})
		RunMacro("addfields", mvw.line, {"AB_MUT", "BA_MUT", "Tot_MUT"}, {"r","r","r"})
		RunMacro("addfields", mvw.line, {"AB_TotFlow","BA_TotFlow","TotFlow"}, {"r","r","r"})
		SetRecordsValues(mvw.line+"|", {{"AB_Auto", "BA_Auto", "Tot_Auto"}, null}, "Value", {0,0,0}, null)
		SetRecordsValues(mvw.line+"|", {{"AB_SUT", "BA_SUT", "Tot_SUT"}, null}, "Value", {0,0,0}, null)
		SetRecordsValues(mvw.line+"|", {{"AB_MUT", "BA_MUT", "Tot_MUT"}, null}, "Value", {0,0,0}, null)
		SetRecordsValues(mvw.line+"|", {{"AB_TotFlow","BA_TotFlow","TotFlow"}, null}, "Value", {0,0,0}, null)

		RunMacro("addfields", mvw.line, {"AB_PreFlow","BA_PreFlow","PreFlow"}, {"r","r","r"})
		RunMacro("addfields", mvw.line, {"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, {"r","r","r"})
		SetRecordsValues(mvw.line+"|", {{"AB_PreFlow","BA_PreFlow","PreFlow"}, null}, "Value", {0,0,0}, null)
		SetRecordsValues(mvw.line+"|", {{"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, null}, "Value", {0,0,0}, null)

		//Assign
		RunMacro("MultiClassPreloadSetup")
		RunMacro("update_hnet", 1)
		RunMacro("MultiClassAssignSetup")

		//CalRep
		dt = CreateDateTime()
		MDY = FormatDateTime(dt, "MMMddyyyy")
		info.runname  = "ODME_"+MDY
		info.timestamp = FormatDateTime(dt,"MMMddyyyy_HHmmss")

		{calSUT.type, calSUT.vol, calSUT.cnt} = {"SUT", "Tot_SUT", "AADT_SUT"}
		RunMacro("CalRep", 0, calSUT)
		{calMUT.type, calMUT.vol, calMUT.cnt} = {"MUT", "Tot_MUT", "AADT_MUT"}
		RunMacro("CalRep", 0, calMUT)
		{calALL.type, calALL.vol, calALL.cnt} = {"All", "TotFlow", "AADT"}
		RunMacro("CalRep", 0, calALL)

		//Adjust
		//if iter <> ODMEiter then RunMacro("AdjustODs", null)
		//if iter <> ODMEiter then RunMacro("AdjustODs", "II")
		if iter <> ODMEiter then RunMacro("AdjustAutos", "II")

		RunMacro("ODME_Log", seed.mtx, od.triptable, iter, info.odmelog)
	end

mapname = GetMap()
SetStatus(1, "@System0", )
SetStatus(2, "@System1", )
SetSelectDisplay("True")
if mapname <> null then SetMapRedraw(null, "True")
ShowMessage("Complete!")
endMacro

Macro "ODME_Log" (seedmat, odmemat, iter, logfile)
	datetime = GetDateAndTime()
	dttrim = Substring(datetime, 5, 15)
	dtstr = Substitute(dttrim, ":", "", null)
   dtstr = ""

   seedmtx = OpenMatrix(seedmat, "Auto")
   seeda = CreateMatrixCurrency(seedmtx, "AutoTrips", null, null, null)
   seeds = CreateMatrixCurrency(seedmtx, "SUTrk", null, null, null)
   seedm = CreateMatrixCurrency(seedmtx, "MUTrk", null, null, null)

	odmemtx = OpenMatrix(odmemat, "Auto")
	odmea = CreateMatrixCurrency(odmemtx, "AutoTrips", null, null, null)
	odmes = CreateMatrixCurrency(odmemtx, "SUTrk", null, null, null)
	odmem = CreateMatrixCurrency(odmemtx, "MUTrk", null, null, null)

	odmearra = MatrixRMSE(odmea, seeda)
	odmearrs = MatrixRMSE(odmes, seeds)
	odmearrm = MatrixRMSE(odmem, seedm)

//Write to logfile
	ptr = OpenFile(logfile, "a")
	//"Date : ODMEiter : mRMSE : mRelRMSE : mPctDiff",
	ar_log = { dtstr +"_Auto : "+ string(iter) +" : "+ string(odmearra.RMSE) +" : "+ string(odmearra.RelRMSE) +" : "+ string(odmearra.PercentDiff),
				dtstr +"_SUT : "+ string(iter) +" : "+ string(odmearrs.RMSE) +" : "+ string(odmearrs.RelRMSE) +" : "+ string(odmearrs.PercentDiff),
				dtstr +"_MUT : "+ string(iter) +" : "+ string(odmearrm.RMSE) +" : "+ string(odmearrm.RelRMSE) +" : "+ string(odmearrm.PercentDiff)+"\n"}
	WriteArray(ptr, ar_log)
	CloseFile(ptr)
	Return()
endMacro

//ASSIGNMENT TEMPLATES
Macro "SingleClassPreloadSetup"
shared mvw, outdir, netparam
shared net, od, flow

pre               = null
pre.Database      = mvw.linefile
pre.Network       = net.assign
pre.Preload       = 1

	//VDF
pre.VDF           = "bpr.vdf"
pre.Time          = "RJ_Time"
pre.Alpha         = "bprA"
pre.Beta          = "bprB"

pre.Periods      = 1
pre.NumClass     = 1

	//Method
pre.Method = "AON"
pre.Convergence = .0005	//ignored in AON
pre.Iterations = 100    //ignored in AON

if pre.Method = "AON" then do
	pre.AON.FFTime = "gctta"
end
	//TOD
pre.dly.Name     = {"PRETRK"}
pre.dly.Excl     = {null}
pre.dly.CurrName = {"TruckTrip"}
pre.dly.GenCost  = "gcm"
pre.dly.OD       = {odmtx, "TRUCKS (0-24)", "Assign_IDs", "Assign_IDs"}
pre.dly.Cap      = "RJ_Cap"
pre.dly.FlowTable= flow.predly
pre.dly.PCE      = {1}
pre.dly.VOI      = {netparam.mutvot.value}

pre.AM.Name      = {"PRETRK_AM"}
pre.AM.Excl      = {null}
pre.AM.CurrName  = {"AMTRK"}
pre.AM.GenCost   = "gcm"
pre.AM.OD        = {odmtx, "TRUCKS (0-24)", "Assign_IDs", "Assign_IDs"}
pre.AM.Cap       = "AMCap"
pre.AM.FlowTable = flow.pream
pre.AM.PCE       = {1}
pre.AM.VOI       = {netparam.mutvot.value*netparam.mutpdelay.value}

pre.PM.Name     = {"PRETRK_PM"}
pre.PM.Excl     = {null}
pre.PM.CurrName = {"PMTRK"}
pre.PM.GenCost  = "gcm"
pre.PM.OD       = {odmtx, "TRUCKS (0-24)", "Assign_IDs", "Assign_IDs"}
pre.PM.Cap      = "PMCap"
pre.PM.FlowTable= flow.prepm
pre.PM.PCE      = {1}
pre.PM.VOI      = {netparam.mutvot.value*netparam.mutpdelay.value}

pre.OP.Name     = {"PRETRK_OP"}
pre.OP.Excl     = {null}
pre.OP.CurrName = {"OPTRK"}
pre.OP.GenCost  = "gcm"
pre.OP.OD       = {odmtx, "TRUCKS (0-24)", "Assign_IDs", "Assign_IDs"}
pre.OP.Cap      = "OPCap"
pre.OP.FlowTable= flow.preop
pre.OP.PCE      = {1}
pre.OP.VOI      = {netparam.mutvot.value*netparam.mutpdelay.value}


//Processing
//Define VDF fields
/*
1: Alcelik: { Free Flow Link Time, Link Capacity, Zero-Flow Control Delay, Calibration Parameter, Link Length, Preload }
2: BPR: { Time, Capacity, Alpha, Beta, Preload }
3: Conical Congestion: { Time, Capacity, Alpha, Preload }
4: Generalized Cost: { Time, Capacity, Alpha, Beta, K, Op. Cost, Value of Time, Length, Preload}
5: Logit Delay: { Link Time, Link Capacity, Intersection Time, Intersection Capacity, C1, C2, C3, C4, P1, P2, P3, P4, Preload }
6: Node Delay: { Time, Capacity, Green, Saturation, D0, Cycle, Light, Alpha, Beta, Preload }
*/

if asn.VDF = "bpr.vdf" then do
	pre.dly.VDFflds = {asn.Time, asn.dly.Cap, asn.Alpha, asn.Beta, "None"}
	pre.AM.VDFflds  = {asn.Time, asn.AM.Cap , asn.Alpha, asn.Beta, "None"}
	pre.PM.VDFflds  = {asn.Time, asn.PM.Cap , asn.Alpha, asn.Beta, "None"}
	pre.MD.VDFflds  = {asn.Time, asn.MD.Cap , asn.Alpha, asn.Beta, "None"}
	pre.NT.VDFflds  = {asn.Time, asn.NT.Cap , asn.Alpha, asn.Beta, "None"}
end


{pre.Name    , pre.Excl    , pre.CurrName    , pre.GenCost    , pre.OD    , pre.VDFflds    , pre.FlowTable    , pre.PCE    , pre.VOI} =
{pre.dly.Name, pre.dly.Excl, pre.dly.CurrName, pre.dly.GenCost, pre.dly.OD, pre.dly.VDFflds, pre.dly.FlowTable, pre.dly.PCE, pre.dly.VOI}

RunMacro("MMA", pre)
RunMacro("asn2dbd", mvw, pre, "DLY")


endMacro

Macro "SingleClassAssignSetup"
shared mvw, outdir, netparam
shared net, od, flow

	//Setup Assignment Parameters
asn               = null
asn.Database      = mvw.linefile
asn.Network       = net.assign
asn.Periods       = 1 //USER DEFINED
asn.NumClass      = 1 //USER DEFINED
asn.Preload       = 2

	//VDF
asn.VDF      = "bpr.vdf" //["akcelik.vdf", "bpr.vdf", "emme2.vdf", "gc_vdf.vdf" (not used in MMA), "iitpr.vdf", "Sig_VDF.vdf"]
asn.Time     = "RJ_Time"
asn.Alpha    = "bprA"
asn.Beta     = "bprB"

	//Method
asn.Method = "CUE"	//["AON","UE","CUE","SUE","PUE"]
asn.Convergence = .0005
asn.Iterations = 200

if asn.Method = "CUE" then do
	asn.CUE.Nconjugate = 3
	asn.CUE.iterfile = outdir.tables + "MMA_IterationLog.bin"
end

if asn.Method = "AON" then do
	asn.AON.FFTime = "gctta"
end

if asn.Method = "UE" then do
	asn.UE.field = null
end

if asn.Method = "SUE" then do
	asn.SUE.error = 5
	asn.SUE.function = "Normal" //["Normal", "Gumbel", "Uniform"]
end

if asn.Method = "PUE" then do
	asn.PUE.time = 0
	asn.PUE.path = outdir.tables + "MMA_PUE_Path.obt"
end

	//TOD Inputs
asn.dly.Name     = "DLYCAR"
asn.dly.Excl     = {null}
asn.dly.CurrName = {"PASSENGER_VEHICLES (0-24)"}
asn.dly.GenCost  = {"gca"}
asn.dly.OD       = {odmtx, "PASSENGER_VEHICLES (0-24)", "Assign_IDs", "Assign_IDs"}
asn.dly.Cap      = "RJ_Cap"
asn.dly.Pre      = "DLYPrePCE"
asn.dly.FlowTable= flow.dly
asn.dly.PCE      = {1}
asn.dly.VOI      = {netparam.carpdelay.value}

asn.AM.Name     = "AMCAR"
asn.AM.Excl      = {null}
asn.AM.CurrName  = {"CARAM"}
asn.AM.GenCost   = {"gca"}
asn.AM.OD        = {odmtx, "CARAM", "Assign_IDs", "Assign_IDs"}
asn.AM.Cap       = "AMCap"
asn.AM.Pre       = "AMPrePCE"
asn.AM.FlowTable = flow.am
asn.AM.PCE       = {1}
asn.AM.VOI       = {netparam.carpdelay.value}

asn.PM.Name     = "PMCAR"
asn.PM.Excl      = {null}
asn.PM.CurrName  = {"CARPM"}
asn.PM.GenCost   = {"gca"}
asn.PM.OD        = {odmtx, "CARPM", "Assign_IDs", "Assign_IDs"}
asn.PM.Cap       = "PMCap"
asn.PM.Pre       = "PMPrePCE"
asn.PM.FlowTable = flow.pm
asn.PM.PCE       = {1}
asn.PM.VOI       = {netparam.carpdelay.value}

asn.OP.Name     = "MDCAR"
asn.OP.Excl      = {null}
asn.OP.CurrName  = {"CAROP"}
asn.OP.GenCost   = {"gca"}
asn.OP.OD        = {odmtx, "CAROP", "Assign_IDs", "Assign_IDs"}
asn.OP.Cap       = "OPCap"
asn.OP.Pre       = "OPPrePCE"
asn.OP.FlowTable = flow.op
asn.OP.PCE       = {1}
asn.OP.VOI       = {netparam.carpdelay.value}


//Processing

	//Define VDF fields
/*
1: Alcelik: { Free Flow Link Time, Link Capacity, Zero-Flow Control Delay, Calibration Parameter, Link Length, Preload }
2: BPR: { Time, Capacity, Alpha, Beta, Preload }
3: Conical Congestion: { Time, Capacity, Alpha, Preload }
4: Generalized Cost: { Time, Capacity, Alpha, Beta, K, Op. Cost, Value of Time, Length, Preload}
5: Logit Delay: { Link Time, Link Capacity, Intersection Time, Intersection Capacity, C1, C2, C3, C4, P1, P2, P3, P4, Preload }
6: Node Delay: { Time, Capacity, Green, Saturation, D0, Cycle, Light, Alpha, Beta, Preload }
*/

if asn.VDF = "bpr.vdf" then do
	asn.dly.VDFflds = {asn.Time, asn.dly.Cap, asn.Alpha, asn.Beta, asn.dly.Pre}
	asn.AM.VDFflds  = {asn.Time, asn.AM.Cap , asn.Alpha, asn.Beta, asn.AM.Pre}
	asn.PM.VDFflds  = {asn.Time, asn.PM.Cap , asn.Alpha, asn.Beta, asn.PM.Pre}
	asn.OP.VDFflds  = {asn.Time, asn.OP.Cap , asn.Alpha, asn.Beta, asn.OP.Pre}
end

if asn.VDF = "akcelik.vdf" then x = null
if asn.VDF = "emme2.vdf"   then x = null
if asn.VDF = "gc_vdf.vdf"  then x = null
if asn.VDF = "iitpr.vdf"   then x = null
if asn.VDF = "Sig_VDF.vdf" then x = null

vdfdef = GetVDFParameters(asn.VDF)
asn.VDFdef = vdfdef[4][2]


//Add volume fields
RunMacro("addfields", mvw.line, {"AB_"+asn.dly.Name,"BA_"+asn.dly.Name,"Tot_"+asn.dly.Name}, {"r","r","r"})
SetRecordsValues(mvw.line+"|", {{"AB_"+asn.dly.Name,"BA_"+asn.dly.Name,"Tot_"+asn.dly.Name}, null}, "Value", {0,0,0}, null)

{asn.Name    , asn.Excl    , asn.CurrName    , asn.GenCost    , asn.OD    , asn.VDFflds    , asn.FlowTable    , asn.PCE    , asn.VOI} =
{asn.dly.Name, asn.dly.Excl, asn.dly.CurrName, asn.dly.GenCost, asn.dly.OD, asn.dly.VDFflds, asn.dly.FlowTable, asn.dly.PCE, asn.dly.VOI}

RunMacro("MMA", asn)
RunMacro("asn2dbd", mvw, asn)


endMacro

//Setup for AirSage
Macro "MultiClassPreloadSetup"
shared mvw, outdir, netparam
shared net, od, flow, info

pcecar = 1
pcesut = netparam.SUPCE.value
pcemut = netparam.MUPCE.value
voicar = (netparam.carvot.value/60)*netparam.carpdelay.value
voisut = (netparam.sutvot.value/60)*netparam.sutpdelay.value
voimut = (netparam.mutvot.value/60)*netparam.mutpdelay.value

	//Setup Preload Parameters
pre               = null
pre.Database      = mvw.linefile
pre.Network       = net.assign
pre.NumClass      = 3
pre.Preload       = 1

	//VDF
pre.VDF      = null //["akcelik.vdf", "bpr.vdf", "emme2.vdf", "gc_vdf.vdf" (not used in MMA), "iitpr.vdf", "Sig_VDF.vdf"]
pre.Time     = "AFFTime"
pre.Alpha    = "bprA" // does not apply in AoN preload
pre.Beta     = "bprB"

	//Method
pre.Method = "AON"	//["AON","UE","CUE","SUE","PUE"]
pre.Convergence = 0.001
pre.Iterations = 200

if pre.Method = "AON" then do
	pre.AON.FFTime = "TCa"
end

	//Multiclass Inputs
pre.dly.Name      = {"Auto", "SUT", "MUT"}	//Match preload fields to Assign fields
pre.dly.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
pre.dly.CurrName  = {"AutoTrips", "SUTrk", "MUTrk"}
pre.dly.GenCost   = {"TCa", "TCs", "TCm"}
pre.dly.OD        = {od.ee, "AutoTrips", "Externals", "Externals"}	//must match a core & index names
pre.dly.Cap       = "DLYCAP"
pre.dly.Pre       = "None"
pre.dly.FlowTable = flow.predly
pre.dly.PCE       = {pcecar, pcesut, pcemut}
pre.dly.VOI       = {voicar, voisut, voimut}


if pre.VDF = "bpr.vdf" then do
	pre.dly.VDFflds = {pre.Time, pre.dly.Cap, pre.Alpha, pre.Beta, pre.dly.Pre}
end

else if pre.VDF <> null then do
	vdfdef = GetVDFParameters(pre.VDF)
	pre.VDFdef = vdfdef[4][2]
end


//Run assignment macro
	{pre.Name    , pre.Excl    , pre.CurrName    , pre.GenCost    , pre.OD    , pre.VDFflds    , pre.FlowTable    , pre.PCE    , pre.VOI} =
	{pre.dly.Name, pre.dly.Excl, pre.dly.CurrName, pre.dly.GenCost, pre.dly.OD, pre.dly.VDFflds, pre.dly.FlowTable, pre.dly.PCE, pre.dly.VOI}

	RunMacro("MMA", pre)
	RunMacro("asn2dbd", mvw, pre, "DLY")

endMacro

Macro "MultiClassAssignSetup"
shared mvw, outdir, netparam
shared net, od, flow

pcecar = 1
pcesut = netparam.SUPCE.value
pcemut = netparam.MUPCE.value
voicar = (netparam.carvot.value/60)*netparam.carpdelay.value
voisut = (netparam.sutvot.value/60)*netparam.sutpdelay.value
voimut = (netparam.mutvot.value/60)*netparam.mutpdelay.value

	//Setup Assignment Parameters
asn               = null
asn.Database      = mvw.linefile
asn.Network       = net.assign
asn.Periods       = 1
asn.NumClass      = 3
asn.Preload       = 2

	//VDF
asn.VDF      = "bpr.vdf" //["akcelik.vdf", "bpr.vdf", "emme2.vdf", "gc_vdf.vdf" (not used in MMA), "iitpr.vdf", "Sig_VDF.vdf"]
asn.Time     = "AFFTime"
asn.Alpha    = "bprA"
asn.Beta     = "bprB"

	//Method
asn.Method = "PUE"	//["AON","UE","CUE","SUE","PUE"]
asn.Convergence = 0.0001 //0.0005
asn.Iterations = 200

if asn.Method = "CUE" then do
	asn.CUE.Nconjugate = 3
	asn.CUE.iterfile = outdir.tables + "MMA_IterationLog.bin"
end

if asn.Method = "AON" then do
	asn.AON.FFTime = "gctta"
end

if asn.Method = "UE" then do
	asn.UE.field = null
end

if asn.Method = "SUE" then do
	asn.SUE.error = 5
	asn.SUE.function = "Normal" //["Normal", "Gumbel", "Uniform"]
end

if asn.Method = "PUE" then do
	asn.PUE.time = 0
	asn.PUE.path = outdir.tables + "MMA_PUE.obt"
end

	//Multiclass Inputs
asn.dly.Name      = {"Auto", "SUT", "MUT"}
asn.dly.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
asn.dly.CurrName  = {"AutoTrips", "SUTrk", "MUTrk"}
asn.dly.GenCost   = {"TCa", "TCs", "TCm"}
asn.dly.OD        = {od.triptable, "AutoTrips", "Row ID's", "Col ID's"}
asn.dly.Cap       = "DLYCAP"
asn.dly.Pre       = "DLYPrePCE"
asn.dly.FlowTable = flow.dly
asn.dly.PCE       = {pcecar, pcesut, pcemut}
asn.dly.VOI       = {voicar, voisut, voimut}


if asn.VDF = "bpr.vdf" then do
	asn.dly.VDFflds = {asn.Time, asn.dly.Cap, asn.Alpha, asn.Beta, asn.dly.Pre}
end

vdfdef = GetVDFParameters(asn.VDF)
asn.VDFdef = vdfdef[4][2]

//Run assignment macro
if asn.Periods = 1 then do
	{asn.Name    , asn.Excl    , asn.CurrName    , asn.GenCost    , asn.OD    , asn.VDFflds    , asn.FlowTable    , asn.PCE    , asn.VOI} =
	{asn.dly.Name, asn.dly.Excl, asn.dly.CurrName, asn.dly.GenCost, asn.dly.OD, asn.dly.VDFflds, asn.dly.FlowTable, asn.dly.PCE, asn.dly.VOI}

	RunMacro("MMA", asn)
	RunMacro("asn2dbd", mvw, asn)
end
endMacro


//TransCAD + DAYSIM ASSIGNMENT
Macro "MultiClassTODPreloadSetup"
shared mvw, netparam
shared net, od, flow

pcecar = 1
pcesut = netparam.SUPCE.value
pcemut = netparam.MUPCE.value
voicar = (netparam.carvot.value/60)*netparam.carpdelay.value
voisut = (netparam.sutvot.value/60)*netparam.sutpdelay.value
voimut = (netparam.mutvot.value/60)*netparam.mutpdelay.value

	//Setup Preload Parameters
pre               = null

pre.Database      = mvw.linefile
pre.Network       = net.assign

pre.Periods       = 3
pre.NumClass      = 3
pre.Preload       = 1

	//VDF
pre.VDF      = null //["akcelik.vdf", "bpr.vdf", "emme2.vdf", "gc_vdf.vdf" (not used in MMA), "iitpr.vdf", "Sig_VDF.vdf"]
pre.Time     = "AFFTime"
pre.Alpha    = "bprA"
pre.Beta     = "bprB"

	//Method
pre.Method = "AON"
pre.Convergence = 0.001
pre.Iterations = 200

if pre.Method = "AON" then do
	pre.AON.FFTime = "AFFTime"
end

	//Multiclass Inputs
pre.AM.Name      = {"Auto", "SUT", "MUT"}
pre.AM.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
pre.AM.CurrName  = {"AM_Pass", "AM_SUT", "AM_MUT"}
pre.AM.GenCost   = {"TCa", "TCs", "TCm"}
//pre.AM.OD        = {od.ee, "AM_Pass", "Origin", "Destination"}
pre.AM.OD        = {od.ee, "AM_Pass", null, null}
pre.AM.Cap       = "AMCap"
//pre.AM.VDFflds   = {pre.Time, pre.AM.Cap, pre.Alpha, pre.Beta, null}
pre.AM.FlowTable = flow.pream
pre.AM.PCE       = {pcecar, pcesut, pcemut}
pre.AM.VOI       = {voicar, voisut, voimut}


pre.PM.Name      = {"Auto", "SUT", "MUT"}
pre.PM.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
pre.PM.CurrName  = {"PM_Pass", "PM_SUT", "PM_MUT"}
pre.PM.GenCost   = {"TCa", "TCs", "TCm"}
//pre.PM.OD        = {od.ee, "AM_Pass", "Origin", "Destination"}
pre.PM.OD        = {od.ee, "AM_Pass", null, null}
pre.PM.Cap       = "PMCap"
//pre.PM.VDFflds   = {pre.Time, pre.PM.Cap, pre.Alpha, pre.Beta, null}
pre.PM.FlowTable = flow.prepm
pre.PM.PCE       = {pcecar, pcesut, pcemut}
pre.PM.VOI       = {voicar, voisut, voimut}

pre.OP.Name      = {"Auto", "SUT", "MUT"}
pre.OP.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
pre.OP.CurrName  = {"OP_Pass", "OP_SUT", "OP_MUT"}
pre.OP.GenCost   = {"TCa", "TCs", "TCm"}
//pre.OP.OD        = {od.ee, "AM_Pass", "Origin", "Destination"}
pre.OP.OD        = {od.ee, "AM_Pass", null, null}
pre.OP.Cap       = "OPCap"
//pre.OP.VDFflds   = {pre.Time, pre.OP.Cap, pre.Alpha, pre.Beta, null}
pre.OP.FlowTable = flow.preop
pre.OP.PCE       = {pcecar, pcesut, pcemut}
pre.OP.VOI       = {voicar, voisut, voimut}


//Parallel assignment
//RunMacro("ParallelMMA", pre)

//Write Outputs
mvw.line   = RunMacro("AddLayer", mvw.linefile, "Line")

{pre.Name   ,pre.Excl   , pre.CurrName   , pre.GenCost   , pre.OD   , pre.VDFflds   , pre.FlowTable   , pre.PCE   , pre.VOI} =
{pre.AM.Name,pre.AM.Excl, pre.AM.CurrName, pre.AM.GenCost, pre.AM.OD, pre.AM.VDFflds, pre.AM.FlowTable, pre.AM.PCE, pre.AM.VOI}
RunMacro("MMA", pre)
RunMacro("asn2dbd", mvw, pre, "AM")

{pre.Name   ,pre.Excl   , pre.CurrName   , pre.GenCost   , pre.OD   , pre.VDFflds   , pre.FlowTable   , pre.PCE   , pre.VOI} =
{pre.PM.Name,pre.PM.Excl, pre.PM.CurrName, pre.PM.GenCost, pre.PM.OD, pre.PM.VDFflds, pre.PM.FlowTable, pre.PM.PCE, pre.PM.VOI}
RunMacro("MMA", pre)
RunMacro("asn2dbd", mvw, pre, "PM")

{pre.Name   ,pre.Excl   , pre.CurrName   , pre.GenCost   , pre.OD   , pre.VDFflds   , pre.FlowTable   , pre.PCE   , pre.VOI} =
{pre.OP.Name,pre.OP.Excl, pre.OP.CurrName, pre.OP.GenCost, pre.OP.OD, pre.OP.VDFflds, pre.OP.FlowTable, pre.OP.PCE, pre.OP.VOI}
RunMacro("MMA", pre)
RunMacro("asn2dbd", mvw, pre, "OP")

endMacro

Macro "MultiClassTODAssignSetup"
shared mvw, outdir, netparam
shared net, od, flow

pcecar = 1
pcesut = netparam.SUPCE.value
pcemut = netparam.MUPCE.value
voicar = (netparam.carvot.value/60)*netparam.carpdelay.value
voisut = (netparam.sutvot.value/60)*netparam.sutpdelay.value
voimut = (netparam.mutvot.value/60)*netparam.mutpdelay.value

	//Setup Assignment Parameters
asn               = null
asn.Database      = mvw.linefile
asn.Network       = net.assign
asn.Periods       = 3
asn.NumClass      = 3
asn.Preload       = 2

	//VDF
asn.VDF      = "bpr.vdf" //["akcelik.vdf", "bpr.vdf", "emme2.vdf", "gc_vdf.vdf" (not used in MMA), "iitpr.vdf", "Sig_VDF.vdf"]
asn.Time     = "AFFTime"
asn.Alpha    = "bprA"
asn.Beta     = "bprB"

	//Method
asn.Method = "PUE"	//["AON","UE","CUE","SUE","PUE"]
asn.Convergence = 0.0001
asn.Iterations = 200

if asn.Method = "CUE" then do
	asn.CUE.Nconjugate = 3
	asn.CUE.amiterfile = outdir.tables + "MMA_AM_IterationLog.bin"
	asn.CUE.pmiterfile = outdir.tables + "MMA_PM_IterationLog.bin"
	asn.CUE.opiterfile = outdir.tables + "MMA_OP_IterationLog.bin"
end

if asn.Method = "AON" then do
	asn.AON.FFTime = "gctta"
end

if asn.Method = "UE" then do
	asn.UE.field = null
end

if asn.Method = "SUE" then do
	asn.SUE.error = 5
	asn.SUE.function = "Normal" //["Normal", "Gumbel", "Uniform"]
end

if asn.Method = "PUE" then do
	asn.PUE.time = 0
	asn.PUE.ampath = outdir.tables + "MMA_AM_PUE.obt"
	asn.PUE.pmpath = outdir.tables + "MMA_PM_PUE.obt"
	asn.PUE.oppath = outdir.tables + "MMA_OP_PUE.obt"
end

	//Multiclass Inputs
asn.AM.Name      = {"Auto", "SUT", "MUT"}
asn.AM.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
asn.AM.CurrName  = {"AM_Pass", "AM_SUT", "AM_MUT"}
asn.AM.GenCost   = {"TCa", "TCs", "TCm"}
asn.AM.OD        = {od.triptable, "AM_Pass", null, null}
asn.AM.Cap       = "AMCap"
asn.AM.Pre       = "AMPrePCE"
asn.AM.FlowTable = flow.am
asn.AM.PCE       = {pcecar, pcesut, pcemut}
asn.AM.VOI       = {voicar, voisut, voimut}

asn.PM.Name      = {"Auto", "SUT", "MUT"}
asn.PM.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
asn.PM.CurrName  = {"PM_Pass", "PM_SUT", "PM_MUT"}
asn.PM.GenCost   = {"TCa", "TCs", "TCm"}
asn.PM.OD        = {od.triptable, "AM_Pass", null, null}
asn.PM.Cap       = "PMCap"
asn.PM.Pre       = "PMPrePCE"
asn.PM.FlowTable = flow.pm
asn.PM.PCE       = {pcecar, pcesut, pcemut}
asn.PM.VOI       = {voicar, voisut, voimut}

asn.OP.Name      = {"Auto", "SUT", "MUT"}
asn.OP.Excl      = {{mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway", "Select * where IN_HIGHWAY = 0"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}, {mvw.linefile+"|"+mvw.line, mvw.line, "NonHighway"}}
asn.OP.CurrName  = {"OP_Pass", "OP_SUT", "OP_MUT"}
asn.OP.GenCost   = {"TCa", "TCs", "TCm"}
asn.OP.OD        = {od.triptable, "AM_Pass", null, null}
asn.OP.Cap       = "OPCap"
asn.OP.Pre       = "OPPrePCE"
asn.OP.FlowTable = flow.op
asn.OP.PCE       = {pcecar, pcesut, pcemut}
asn.OP.VOI       = {voicar, voisut, voimut}


if asn.VDF = "bpr.vdf" then do
	asn.AM.VDFflds = {asn.Time, asn.AM.Cap, asn.Alpha, asn.Beta, asn.AM.Pre}
	asn.PM.VDFflds = {asn.Time, asn.PM.Cap, asn.Alpha, asn.Beta, asn.PM.Pre}
	asn.OP.VDFflds = {asn.Time, asn.OP.Cap, asn.Alpha, asn.Beta, asn.OP.Pre}
end

vdfdef = GetVDFParameters(asn.VDF)
asn.VDFdef = vdfdef[4][2]

//Parallel Assignment
//RunMacro("ParallelMMA", asn)

//Write Outputs
mvw.line   = RunMacro("AddLayer", mvw.linefile, "Line")


{asn.Name   ,asn.Excl   , asn.CurrName   , asn.GenCost   , asn.OD   , asn.VDFflds   , asn.FlowTable   , asn.PCE   , asn.VOI, asn.PUE.path} =
{asn.AM.Name,asn.AM.Excl, asn.AM.CurrName, asn.AM.GenCost, asn.AM.OD, asn.AM.VDFflds, asn.AM.FlowTable, asn.AM.PCE, asn.AM.VOI, asn.PUE.ampath}
RunMacro("MMA", asn)
RunMacro("asn2dbd", mvw, asn, "AM")

{asn.Name   ,asn.Excl   , asn.CurrName   , asn.GenCost   , asn.OD   , asn.VDFflds   , asn.FlowTable   , asn.PCE   , asn.VOI, asn.PUE.path} =
{asn.PM.Name,asn.PM.Excl, asn.PM.CurrName, asn.PM.GenCost, asn.PM.OD, asn.PM.VDFflds, asn.PM.FlowTable, asn.PM.PCE, asn.PM.VOI, asn.PUE.pmpath}
RunMacro("MMA", asn)
RunMacro("asn2dbd", mvw, asn, "PM")

{asn.Name   ,asn.Excl   , asn.CurrName   , asn.GenCost   , asn.OD   , asn.VDFflds   , asn.FlowTable   , asn.PCE   , asn.VOI, asn.PUE.path} =
{asn.OP.Name,asn.OP.Excl, asn.OP.CurrName, asn.OP.GenCost, asn.OP.OD, asn.OP.VDFflds, asn.OP.FlowTable, asn.OP.PCE, asn.OP.VOI, asn.PUE.oppath}
RunMacro("MMA", asn)
RunMacro("asn2dbd", mvw, asn, "OP")

endMacro


//Parallel Assignment
Macro "ParallelMMA" (asn)
RunDbox("Parallel.Toolbox")

popts = null
popts.Progress = "Running MMA"

//AM
	assignAM = CreateObject("Parallel.Task", "MMA", GetInterface())
	assignAM.Name = "AM Assignment"
	{asn.Name   ,asn.Excl   , asn.CurrName   , asn.GenCost   , asn.OD   , asn.VDFflds   , asn.FlowTable   , asn.PCE   , asn.VOI, asn.CUE.iterfile} =
	{asn.AM.Name,asn.AM.Excl, asn.AM.CurrName, asn.AM.GenCost, asn.AM.OD, asn.AM.VDFflds, asn.AM.FlowTable, asn.AM.PCE, asn.AM.VOI, asn.CUE.amiterfile}
    assignAM.Run(asn)

//PM
	assignPM = CreateObject("Parallel.Task", "MMA", GetInterface())
	assignPM.Name = "PM Assignment"
	{asn.Name   ,asn.Excl   , asn.CurrName   , asn.GenCost   , asn.OD   , asn.VDFflds   , asn.FlowTable   , asn.PCE   , asn.VOI, asn.CUE.iterfile} =
	{asn.PM.Name,asn.PM.Excl, asn.PM.CurrName, asn.PM.GenCost, asn.PM.OD, asn.PM.VDFflds, asn.PM.FlowTable, asn.PM.PCE, asn.PM.VOI, asn.CUE.pmiterfile}
	assignPM.Run(asn)

//OP
	assignOP = CreateObject("Parallel.Task", "MMA", GetInterface())
	assignOP.Name = "OP Assignment"
	{asn.Name   ,asn.Excl   , asn.CurrName   , asn.GenCost   , asn.OD   , asn.VDFflds   , asn.FlowTable   , asn.PCE   , asn.VOI, asn.CUE.iterfile} =
	{asn.OP.Name,asn.OP.Excl, asn.OP.CurrName, asn.OP.GenCost, asn.OP.OD, asn.OP.VDFflds, asn.OP.FlowTable, asn.OP.PCE, asn.OP.VOI, asn.CUE.opiterfile}
	assignOP.Run(asn)

// wait until all parallel tasks are completed
	tasks = {assignAM, assignPM, assignOP}
    monitor = CreateObject("Parallel.TaskMonitor", tasks)
    monitor.WaitForAll(popts)

ret_value = RunMacro("ParallelTaskResults", tasks, "Parallel MMA", {{"Return Errors", True}})
if !ret_value then goto quit

quit:
CloseDbox("Parallel.Toolbox")
endMacro

//Write Output
Macro "asn2dbd" (mvw, asn, tod)
	//Preload = 0 ; Assignment without Preload
	//Preload = 1 ; Preload Assignment
	//Preload = 2 ; Assignment with Preload

	dim abclassfld[asn.NumClass]
	dim baclassfld[asn.NumClass]
	dim totclassfld[asn.NumClass]
	dim abstrfld[asn.NumClass]
	dim bastrfld[asn.NumClass]
	dim abvolfld[asn.NumClass]
	dim bavolfld[asn.NumClass]
	dim totvolfld[asn.NumClass]

	//Add volume fields for each class
	for nc = 1 to asn.NumClass do
		abclassfld[nc]  = "AB_"+tod+"_"+asn.Name[nc]
		baclassfld[nc]  = "BA_"+tod+"_"+asn.Name[nc]
		totclassfld[nc] = "Tot_"+tod+"_"+asn.Name[nc]
	end

	//Join assignment output & write volumes to links
	asnvw = OpenTable("asn", "FFB", {asn.FlowTable, })
	jnvw = JoinViews("jnvw", mvw.line+".ID", asnvw+".ID1", )
	SetView(jnvw)

	//Note: AB_Flow_[NAME] are vehicle volumes (PCE unapplied)
	for nc = 1 to asn.NumClass do
		abstrfld[nc] = RunMacro("str2fld", JoinStrings({"AB_Flow_",asn.CurrName[nc]},""))
		bastrfld[nc] = RunMacro("str2fld", JoinStrings({"BA_Flow_",asn.CurrName[nc]},""))
		abvolfld[nc] = CreateExpression(jnvw, "abv", "nz("+abstrfld[nc]+") + nz("+abclassfld[nc]+")", )
		bavolfld[nc] = CreateExpression(jnvw, "bav", "nz("+bastrfld[nc]+") + nz("+baclassfld[nc]+")", )
		totvolfld[nc] = CreateExpression(jnvw, "tcf", "abv + bav", )
		SetRecordsValues(jnvw+"|", {{abclassfld[nc],baclassfld[nc],totclassfld[nc]}, null}, "Formula", {abvolfld[nc],bavolfld[nc],"tcf"},)

		arr = GetExpressions(jnvw)
		for i = 1 to arr.length do DestroyExpression(jnvw+"."+arr[i]) end
	end

	//Preload Assignment
	if asn.Preload = 1 then do
		abtf = CreateExpression(jnvw, "abtf", "nz(AB_PreFlow)+nz(AB_Flow)", )
		batf = CreateExpression(jnvw, "batf", "nz(BA_PreFlow)+nz(BA_Flow)", )
		ttf  = CreateExpression(jnvw, "ttf", "nz(PreFlow)+nz(Tot_Flow)", )
		SetRecordsValues(jnvw+"|", {{"AB_PreFlow","BA_PreFlow","PreFlow"}, null}, "Formula", {"abtf","batf","ttf"},)

		//Preload PCE volumes
		abpf = CreateExpression(jnvw, "abpf", "nz(AB_"+tod+"PrePCE)+nz(AB_Flow_PCE)", )
		bapf = CreateExpression(jnvw, "bapf", "nz(BA_"+tod+"PrePCE)+nz(BA_Flow_PCE)", )
		tpf  = CreateExpression(jnvw, "tpf", "nz("+tod+"PrePCE)+nz(Tot_Flow_PCE)", )
		SetRecordsValues(jnvw+"|", {{"AB_"+tod+"PrePCE","BA_"+tod+"PrePCE",tod+"PrePCE"}, null}, "Formula", {"abpf","bapf","tpf"},)
	end

	arr = GetExpressions(jnvw)
	for i = 1 to arr.length do DestroyExpression(jnvw+"."+arr[i]) end
	CloseView(jnvw)
	CloseView(asnvw)

endMacro

Macro "PCEFlowCalc"
shared mvw
	aba = CreateExpression(mvw.line, "aba", "nz(AB_AMPrePCE) +nz(AB_PMPrePCE)+nz(AB_OPPrePCE)"   , )
	baa = CreateExpression(mvw.line, "baa", "nz(BA_AMPrePCE) +nz(BA_PMPrePCE)+nz(BA_OPPrePCE)"   , )
	ta  = CreateExpression(mvw.line, "ta" , "nz(AMPrePCE)+nz(PMPrePCE)+nz(OPPrePCE)", )
	SetRecordsValues(mvw.line+"|", {{"AB_DLYPrePCE","BA_DLYPrePCE","DLYPrePCE"}, null}, "Formula", {"aba","baa","ta"},)

	arr = GetExpressions(mvw.line)
	for i = 1 to arr.length do DestroyExpression(mvw.line+"."+arr[i]) end
endMacro

Macro "TotFlowCalc"
shared mvw
//Auto
	aba = CreateExpression(mvw.line, "aba", "nz(AB_AM_Auto) +nz(AB_PM_Auto)+nz(AB_OP_Auto)"   , )
	baa = CreateExpression(mvw.line, "baa", "nz(BA_AM_Auto) +nz(BA_PM_Auto)+nz(BA_OP_Auto)"   , )
	ta  = CreateExpression(mvw.line, "ta" , "nz(Tot_AM_Auto)+nz(Tot_PM_Auto)+nz(Tot_OP_Auto)", )
	SetRecordsValues(mvw.line+"|", {{"AB_Auto","BA_Auto","Tot_Auto"}, null}, "Formula", {"aba","baa","ta"},)
//SUT
	abs = CreateExpression(mvw.line, "abs", "nz(AB_AM_SUT) +nz(AB_PM_SUT)+nz(AB_OP_SUT)"   , )
	bas = CreateExpression(mvw.line, "bas", "nz(BA_AM_SUT) +nz(BA_PM_SUT)+nz(BA_OP_SUT)"   , )
	ts  = CreateExpression(mvw.line, "ts" , "nz(Tot_AM_SUT)+nz(Tot_PM_SUT)+nz(Tot_OP_SUT)", )
	SetRecordsValues(mvw.line+"|", {{"AB_SUT","BA_SUT","Tot_SUT"}, null}, "Formula", {"abs","bas","ts"},)
//MUT
	abm = CreateExpression(mvw.line, "abm", "nz(AB_AM_MUT) +nz(AB_PM_MUT)+nz(AB_OP_MUT)"   , )
	bam = CreateExpression(mvw.line, "bam", "nz(BA_AM_MUT) +nz(BA_PM_MUT)+nz(BA_OP_MUT)"   , )
	tm  = CreateExpression(mvw.line, "tm" , "nz(Tot_AM_MUT)+nz(Tot_PM_MUT)+nz(Tot_OP_MUT)", )
	SetRecordsValues(mvw.line+"|", {{"AB_MUT","BA_MUT","Tot_MUT"}, null}, "Formula", {"abm","bam","tm"},)
//AM
	abamtf = CreateExpression(mvw.line, "abamtf", "nz(AB_AM_Auto) +nz(AB_AM_SUT)+nz(AB_AM_MUT)"   , )
	baamtf = CreateExpression(mvw.line, "baamtf", "nz(BA_AM_Auto) +nz(BA_AM_SUT)+nz(BA_AM_MUT)"   , )
	tamtf  = CreateExpression(mvw.line, "tamtf" , "nz(Tot_AM_Auto)+nz(Tot_AM_SUT)+nz(Tot_AM_MUT)", )
	SetRecordsValues(mvw.line+"|", {{"AB_AM_TotFlow","BA_AM_TotFlow","AM_TotFlow"}, null}, "Formula", {"abamtf","baamtf","tamtf"},)
//PM
	abpmtf = CreateExpression(mvw.line, "abpmtf", "nz(AB_PM_Auto) +nz(AB_PM_SUT)+nz(AB_PM_MUT)"   , )
	bapmtf = CreateExpression(mvw.line, "bapmtf", "nz(BA_PM_Auto) +nz(BA_PM_SUT)+nz(BA_PM_MUT)"   , )
	tpmtf  = CreateExpression(mvw.line, "tpmtf" , "nz(Tot_PM_Auto)+nz(Tot_PM_SUT)+nz(Tot_PM_MUT)", )
	SetRecordsValues(mvw.line+"|", {{"AB_PM_TotFlow","BA_PM_TotFlow","PM_TotFlow"}, null}, "Formula", {"abpmtf","bapmtf","tpmtf"},)
//OP
	aboptf = CreateExpression(mvw.line, "aboptf", "nz(AB_OP_Auto) +nz(AB_OP_SUT)+nz(AB_OP_MUT)"   , )
	baoptf = CreateExpression(mvw.line, "baoptf", "nz(BA_OP_Auto) +nz(BA_OP_SUT)+nz(BA_OP_MUT)"   , )
	toptf  = CreateExpression(mvw.line, "toptf" , "nz(Tot_OP_Auto)+nz(Tot_OP_SUT)+nz(Tot_OP_MUT)", )
	SetRecordsValues(mvw.line+"|", {{"AB_OP_TotFlow","BA_OP_TotFlow","OP_TotFlow"}, null}, "Formula", {"aboptf","baoptf","toptf"},)
//Total
	abtf = CreateExpression(mvw.line, "abtf", "nz(AB_Auto) +nz(AB_SUT)+nz(AB_MUT)"   , )
	batf = CreateExpression(mvw.line, "batf", "nz(BA_Auto) +nz(BA_SUT)+nz(BA_MUT)"   , )
	ttf  = CreateExpression(mvw.line, "ttf" , "nz(Tot_Auto)+nz(Tot_SUT)+nz(Tot_MUT)", )
	SetRecordsValues(mvw.line+"|", {{"AB_TotFlow","BA_TotFlow","TotFlow"}, null}, "Formula", {"abtf","batf","ttf"},)


	arr = GetExpressions(mvw.line)
	for i = 1 to arr.length do DestroyExpression(mvw.line+"."+arr[i]) end

endMacro

Macro "BaseFlowCalc"
linevw = GetView()

SetRecordsValues(linevw+"|", {{"AB_BaseVol","BA_BaseVol","BaseVol"}, null}, "Formula", {"AB_TotFlow","BA_TotFlow", "TotFlow"},)
SetRecordsValues(linevw+"|", {{"AM_BaseVol","PM_BaseVol","OP_BaseVol"}, null}, "Formula", {"AM_TotFlow","PM_TotFlow", "OP_TotFlow"},)

endMacro

Macro "UpdateTime" (linevw, flowlist, timetable)
//Calculates congested time from assignment flow tables (flowlist)
//Output: timetable.bin by link ID

if flowlist.length = 1 then do
	todlist = {"DLY"}
end

if flowlist.length = 3 then do
	todlist = {"AM", "PM", "OP"}
end

{linevec.ID} = GetDataVectors(linevw + "|", {"ID"}, {{"Sort Order",{{linevw+".ID","Ascending"}}}} )
RunMacro("addfields", linevw, {"AB_AM_Time","BA_AM_Time","AB_PM_Time","BA_PM_Time","AB_OP_Time","BA_OP_Time","AB_CTime","BA_CTime"}, {"r","r","r","r","r","r","r","r"})

//Create Table
if GetFileInfo(timetable) <> null then do
timevw = OpenTable("timetable", "FFB", {timetable, })
end
if GetFileInfo(timetable) = null then do
	// Prepopulate Table
     timevw = CreateTable("timetable", timetable,"FFB",
			{{"ID"    , "Integer", 16, null, "No"},
			{"AB_C_T" , "Real"   , 12, 2   , "No"},
			{"BA_C_T" , "Real"   , 12, 2   , "No"}
			})
	linecount = VectorStatistic(linevec.id, "Count", )
	r = AddRecords(timevw, null, null, {{"Empty Records", linecount}})
	SetDataVectors(timevw+"|",{ {"ID",linevec.id} }  ,{{"Sort Order",{{"ID","Ascending"}}}})
end

//Write ToD Time & Flow to Network
for t = 1 to todlist.length do
	tod = todlist[t]
	flowtbl = flowlist[t]
	abtodfld  = "AB_"+tod+"_T"
	batodfld  = "BA_"+tod+"_T"
	abvolfld  = "AB_"+tod+"_F"
	bavolfld  = "BA_"+tod+"_F"

	RunMacro("addfields", timevw, {abtodfld, batodfld, abvolfld, bavolfld}, {"r","r","r","r"})
	asnvw = OpenTable("asn", "FFB", {flowtbl, })
	jnvw = JoinViews("jnvw", timevw+".ID", asnvw+".ID1", )

	abtime  = CreateExpression(jnvw, "abtime" , "nz(AB_Time)", )
	batime  = CreateExpression(jnvw, "batime" , "nz(BA_Time)", )
	abflow  = CreateExpression(jnvw, "abflow" , "nz(AB_Flow)", )
	baflow  = CreateExpression(jnvw, "baflow" , "nz(BA_Flow)", )
	SetRecordsValues(jnvw+"|", {{abtodfld,batodfld,abvolfld,bavolfld}, null}, "Formula", {"abtime","batime","abflow","baflow"},)

	CloseView(jnvw)
	CloseView(asnvw)
end

//Calculate Cong Time
if flowlist.length = 1 then do
	SetView(timevw)
	abdl = CreateExpression(timevw, "abdl" , "AB_DLY_T/max(AB_DLY_F,1)",)
	badl = CreateExpression(timevw, "badl" , "BA_DLY_T/max(BA_DLY_F,1)",)
	SetRecordsValues(timevw+"|", {{"AB_C_T","BA_C_T"}, null}, "Formula", {"abdl","badl"},)
	arr = GetExpressions(timevw)
	for i = 1 to arr.length do DestroyExpression(timevw+"."+arr[i]) end

	//Write to linevw
	jnvw = JoinViews("jnvw", timevw+".ID", linevw+".ID", )
	SetRecordsValues(jnvw+"|", {{"AB_AM_Time","BA_AM_Time"}, null}, "Formula", {"AB_AM_T","BA_AM_T"},)
	SetRecordsValues(jnvw+"|", {{"AB_PM_Time","BA_PM_Time"}, null}, "Formula", {"AB_PM_T","BA_PM_T"},)
	SetRecordsValues(jnvw+"|", {{"AB_OP_Time","BA_OP_Time"}, null}, "Formula", {"AB_OP_T","BA_OP_T"},)
	SetRecordsValues(jnvw+"|", {{"AB_CTime","BA_CTime"}, null}, "Formula", {"AB_C_T","BA_C_T"},)

	CloseView(jnvw)
	CloseView(timevw)
end

if flowlist.length = 3 then do
	SetView(timevw)
	abwt = CreateExpression(timevw, "abwt" , "AB_AM_T*max(AB_AM_F,1) + AB_PM_T*max(AB_PM_F,1) + AB_OP_T*max(AB_OP_F,1)", )
	bawt = CreateExpression(timevw, "bawt" , "BA_AM_T*max(BA_AM_F,1) + BA_PM_T*max(BA_PM_F,1) + BA_OP_T*max(BA_OP_F,1)", )
	abtv = CreateExpression(timevw, "abtv" , "max(AB_AM_F + AB_PM_F + AB_OP_F,3)", )
	batv = CreateExpression(timevw, "batv" , "max(BA_AM_F + BA_PM_F + BA_OP_F,3)", )
	abdl = CreateExpression(timevw, "abdl" , "abwt/abtv",)
	badl = CreateExpression(timevw, "badl" , "bawt/batv",)
	SetRecordsValues(timevw+"|", {{"AB_C_T","BA_C_T"}, null}, "Formula", {"abdl","badl"},)

	arr = GetExpressions(timevw)
	for i = 1 to arr.length do DestroyExpression(timevw+"."+arr[i]) end

	//Write to linevw
	jnvw = JoinViews("jnvw", timevw+".ID", linevw+".ID", )
	SetRecordsValues(jnvw+"|", {{"AB_AM_Time","BA_AM_Time"}, null}, "Formula", {"AB_AM_T","BA_AM_T"},)
	SetRecordsValues(jnvw+"|", {{"AB_PM_Time","BA_PM_Time"}, null}, "Formula", {"AB_PM_T","BA_PM_T"},)
	SetRecordsValues(jnvw+"|", {{"AB_OP_Time","BA_OP_Time"}, null}, "Formula", {"AB_OP_T","BA_OP_T"},)
	SetRecordsValues(jnvw+"|", {{"AB_CTime","BA_CTime"}, null}, "Formula", {"AB_C_T","BA_C_T"},)

	CloseView(jnvw)
	CloseView(timevw)
end

Return()
endMacro

//MultiClass ODME (Vince)
Macro "AdjustODs" (type)
shared root, mvw, net, skim, seed, flow, od, info, netparam

adjfactor_car = .5
adjfactor_sut = .3
adjfactor_mut = .3

// Copy Prev Trip Table to create next iteration OD
m = OpenMatrix(od.triptable, )
m1 = CreateMatrixCurrency(m, seed.class[1], seed.ridx, seed.cidx, )
m2 = CreateMatrixCurrency(m, seed.class[2], seed.ridx, seed.cidx, )
m3 = CreateMatrixCurrency(m, seed.class[3], seed.ridx, seed.cidx, )
nm = CopyMatrix(m1, {{"File Name", od.nextmtx}})

// Create count/volume on network
	SetView(mvw.line)
	SelectByQuery("Cnts", "Several", "Select * where AADT_SUT > 0 and AADT_MUT > 0",)
	{id, AB_CAR_AADT, BA_CAR_AADT, AB_SUT_AADT, BA_SUT_AADT, AB_MUT_AADT, BA_MUT_AADT, AB_CARFlow, BA_CARFlow, AB_SUTFlow, BA_SUTFlow, AB_MUTFlow, BA_MUTFlow} = GetDataVectors(mvw.line + "|Cnts", {"ID", "AB_CAR_ADT","BA_CAR_ADT","AB_SUT_ADT","BA_SUT_ADT","AB_MUT_ADT","BA_MUT_ADT","AB_Auto","BA_Auto","AB_SUT","BA_SUT","AB_MUT","BA_MUT"}, {{"Sort Order",{{"ID","Ascending"}}}} )

	car_abcntfact = if AB_CARFlow > 1 then min((AB_CAR_AADT/AB_CARFlow),10) else null
	car_bacntfact = if BA_CARFlow > 1 then min((BA_CAR_AADT/BA_CARFlow),10) else null
	car_abnumcnt = if AB_CAR_AADT > 0 then 1 else 0
	car_banumcnt = if BA_CAR_AADT > 0 then 1 else 0

	sut_abcntfact = if AB_SUTFlow > 1 then min((AB_SUT_AADT/AB_SUTFlow),10) else null
	sut_bacntfact = if BA_SUTFlow > 1 then min((BA_SUT_AADT/BA_SUTFlow),10) else null
	sut_abnumcnt = if AB_SUT_AADT > 0 then 1 else 0
	sut_banumcnt = if BA_SUT_AADT > 0 then 1 else 0

	mut_abcntfact = if AB_MUTFlow > 1 then min((AB_MUT_AADT/AB_MUTFlow),10) else null
	mut_bacntfact = if BA_MUTFlow > 1 then min((BA_MUT_AADT/BA_MUTFlow),10) else null
	mut_abnumcnt = if AB_MUT_AADT > 0 then 1 else 0
	mut_banumcnt = if BA_MUT_AADT > 0 then 1 else 0

	SetDataVectors(mvw.line + "|Cnts", {{"AB_carcntfact",car_abcntfact},{"BA_carcntfact",car_bacntfact},{"AB_carnumcnt",car_abnumcnt},{"BA_carnumcnt",car_banumcnt}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	SetDataVectors(mvw.line + "|Cnts", {{"AB_SUTcntfact",sut_abcntfact},{"BA_sutcntfact",sut_bacntfact},{"AB_sutnumcnt",sut_abnumcnt},{"BA_sutnumcnt",sut_banumcnt}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	SetDataVectors(mvw.line + "|Cnts", {{"AB_mutcntfact",mut_abcntfact},{"BA_mutcntfact",mut_bacntfact},{"AB_mutnumcnt",mut_abnumcnt},{"BA_mutnumcnt",mut_banumcnt}}, {{"Sort Order",{{"ID","Ascending"}}}} )

//Write factors for each iteration
carfactor = root.path+"odmefactors.bin"

if GetFileInfo(carfactor) = null then do
factvw = CreateTable("Factors", carfactor,"FFB",
			{
			{"ID"       , "Integer", 16, null, "No"},
			{"AB_carnumcnt", "Real"   , 10, 2   , "No"},
			{"BA_carnumcnt", "Real"   , 10, 2   , "No"},
			{"AB_sutnumcnt", "Real"   , 10, 2   , "No"},
			{"BA_sutnumcnt", "Real"   , 10, 2   , "No"},
			{"AB_mutnumcnt", "Real"   , 10, 2   , "No"},
			{"BA_mutnumcnt", "Real"   , 10, 2   , "No"}
			})
	r = AddRecords(factvw, null, null, {{"Empty Records", id.length}})
	SetDataVectors(factvw+"|", {{"ID",id},
	{"AB_carnumcnt",car_abnumcnt},{"BA_carnumcnt",car_banumcnt},
	{"AB_sutnumcnt",sut_abnumcnt},{"BA_sutnumcnt",sut_banumcnt},
	{"AB_mutnumcnt",mut_abnumcnt},{"BA_mutnumcnt",mut_banumcnt}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	CloseView(factvw)
end

	factvw = OpenTable("Factors", "FFB", {carfactor, })
	RunMacro("addfields", factvw, {"AB_carcntfact_"+i2s(info.iter), "BA_carcntfact_"+i2s(info.iter),"AB_sutcntfact_"+i2s(info.iter), "BA_sutcntfact_"+i2s(info.iter),"AB_mutcntfact_"+i2s(info.iter), "BA_mutcntfact_"+i2s(info.iter)}, {"r","r","r","r","r","r"})
	SetDataVectors(factvw+"|", {{"AB_carcntfact_"+i2s(info.iter),car_abcntfact},{"BA_carcntfact_"+i2s(info.iter),car_bacntfact}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	SetDataVectors(factvw+"|", {{"AB_sutcntfact_"+i2s(info.iter),sut_abcntfact},{"BA_sutcntfact_"+i2s(info.iter),sut_bacntfact}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	SetDataVectors(factvw+"|", {{"AB_mutcntfact_"+i2s(info.iter),mut_abcntfact},{"BA_mutcntfact_"+i2s(info.iter),mut_bacntfact}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	CloseView(factvw)

// Skim count/volume along shortest paths to get adjustment factors

	asnvw = OpenTable("asn", "FFB", {flow.dly, })
	jnvw = JoinViews("jnvw", mvw.line+".ID", asnvw+".ID1", )
	SetView(jnvw)
	{abgca,bagca,abgcs,bagcs,abgcm,bagcm,ab_fft,ba_fft,ab_tt,ba_tt} = GetDataVectors(jnvw + "|", {"AB_FTB_A","BA_FTB_A","AB_FTB_S","BA_FTB_S","AB_FTB_M","BA_FTB_M",asnvw+".AB_Time",asnvw+".BA_Time","AB_AFFTime","BA_AFFTime"}, {{"Sort Order",{{"ID","Ascending"}}}})

	abgctta = (netparam.carpdelay.value * ab_tt) + (ab_fft*(1-netparam.carpdelay.value)) + abgca
	bagctta = (netparam.carpdelay.value * ba_tt) + (ba_fft*(1-netparam.carpdelay.value)) + bagca
	abgctts = (netparam.sutpdelay.value * ab_tt) + (ab_fft*(1-netparam.sutpdelay.value)) + abgcs
	bagctts = (netparam.sutpdelay.value * ba_tt) + (ba_fft*(1-netparam.sutpdelay.value)) + bagcs
	abgcttm = (netparam.mutpdelay.value * ab_tt) + (ab_fft*(1-netparam.mutpdelay.value)) + abgcm
	bagcttm = (netparam.mutpdelay.value * ba_tt) + (ba_fft*(1-netparam.mutpdelay.value)) + bagcm

	abtca = max(abgca*(netparam.carvot.value/60) - ((netparam.carvot.value/60)*(netparam.carpdelay.value-1) * ab_fft), 0)
	batca = max(bagca*(netparam.carvot.value/60) - ((netparam.carvot.value/60)*(netparam.carpdelay.value-1) * ba_fft), 0)
	abtcs = max(abgca*(netparam.sutvot.value/60) - ((netparam.sutvot.value/60)*(netparam.sutpdelay.value-1) * ab_fft), 0)
	batcs = max(bagca*(netparam.sutvot.value/60) - ((netparam.sutvot.value/60)*(netparam.sutpdelay.value-1) * ba_fft), 0)
	abtcm = max(abgca*(netparam.mutvot.value/60) - ((netparam.mutvot.value/60)*(netparam.mutpdelay.value-1) * ab_fft), 0)
	batcm = max(bagca*(netparam.mutvot.value/60) - ((netparam.mutvot.value/60)*(netparam.mutpdelay.value-1) * ba_fft), 0)

	SetDataVectors(jnvw + "|", {{"AB_GCTTA",abgctta},{"BA_GCTTA",bagctta}}, {{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(jnvw + "|", {{"AB_GCTTS",abgctts},{"BA_GCTTS",bagctts}}, {{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(jnvw + "|", {{"AB_GCTTM",abgcttm},{"BA_GCTTM",bagcttm}}, {{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(jnvw + "|", {{"AB_TCA",abtca},{"BA_TCA",batca}}, {{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(jnvw + "|", {{"AB_TCS",abtcs},{"BA_TCS",batcs}}, {{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(jnvw + "|", {{"AB_TCM",abtcm},{"BA_TCM",batcm}}, {{"Sort Order",{{"ID","Ascending"}}}})

	CloseView(jnvw)
	CloseView(asnvw)

	RunMacro("update_hnet", 3)

	// Shortest Path Auto
		RunMacro("TCB Init")
		Opts = null
		Opts.Input.Network = net.odme
		Opts.Input.[Origin Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
		Opts.Input.[Destination Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection"}
		Opts.Input.[Via Set] = {mvw.linefile+"|"+mvw.node, mvw.node}
		Opts.Field.Minimize = "gctta"
		Opts.Field.Nodes = mvw.node+".ID"
		Opts.Field.[Skim Fields] = {{"carcntfact","All"},{"carnumcnt","All"}}
		Opts.Flag = {}
		Opts.Output.[Output Matrix].Label = "Shortest Path"
		Opts.Output.[Output Matrix].[File Name] = skim.odme
		if !RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret) then Return( RunMacro("TCB Closing", ok, True ) )

		sm = OpenMatrix(skim.odme, "True")

	// Shortest Path SUT
		tempmtx = GetTempFileName(".mtx")

		RunMacro("TCB Init")
		Opts = null
		Opts.Input.Network = net.odme
		Opts.Input.[Origin Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
		Opts.Input.[Destination Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection"}
		Opts.Input.[Via Set] = {mvw.linefile+"|"+mvw.node, mvw.node}
		Opts.Field.Minimize = "gctts"
		Opts.Field.Nodes = mvw.node+".ID"
		Opts.Field.[Skim Fields] = {{"sutcntfact","All"},{"sutnumcnt","All"}}
		Opts.Flag = {}
		Opts.Output.[Output Matrix].Label = "Shortest Path"
		Opts.Output.[Output Matrix].[File Name] = tempmtx
		if !RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret) then Return( RunMacro("TCB Closing", ok, True ) )

		//Write SUT skim to Auto skim mtx
		tempmat = OpenMatrix(tempmtx, "Auto")
		skim01 = "sutcntfact (Skim)"
		skim02 = "sutnumcnt (Skim)"
		tempout01 = RunMacro("CheckMatrixCore", tempmat, skim01, "Origin", "Destination")
		tempout02 = RunMacro("CheckMatrixCore", tempmat, skim02, "Origin", "Destination")
		mcout01 = RunMacro("CheckMatrixCore", sm, skim01, "Origin", "Destination")
		mcout02 = RunMacro("CheckMatrixCore", sm, skim02, "Origin", "Destination")
		mcout01 := tempout01
		mcout02 := tempout02

	// Shortest Path MUT
		tempmtx = GetTempFileName(".mtx")
		RunMacro("TCB Init")
		Opts = null
		Opts.Input.Network = net.odme
		Opts.Input.[Origin Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
		Opts.Input.[Destination Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection"}
		Opts.Input.[Via Set] = {mvw.linefile+"|"+mvw.node, mvw.node}
		Opts.Field.Minimize = "gcttm"
		Opts.Field.Nodes = mvw.node+".ID"
		Opts.Field.[Skim Fields] = {{"mutcntfact","All"},{"mutnumcnt","All"}}
		Opts.Flag = {}
		Opts.Output.[Output Matrix].Label = "Shortest Path"
		Opts.Output.[Output Matrix].[File Name] = tempmtx
		if !RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret) then Return( RunMacro("TCB Closing", ok, True ) )

		//Write SUT skim to Auto skim mtx
		sm = OpenMatrix(skim.odme, "True")
		tempmat = OpenMatrix(tempmtx, "Auto")
		skim01 = "mutcntfact (Skim)"
		skim02 = "mutnumcnt (Skim)"
		tempout01 = RunMacro("CheckMatrixCore", tempmat, skim01, "Origin", "Destination")
		tempout02 = RunMacro("CheckMatrixCore", tempmat, skim02, "Origin", "Destination")
		mcout01 = RunMacro("CheckMatrixCore", sm, skim01, "Origin", "Destination")
		mcout02 = RunMacro("CheckMatrixCore", sm, skim02, "Origin", "Destination")
		mcout01 := tempout01
		mcout02 := tempout02



// Apply adjustments to ODs
if type = null then do
	nm1 = CreateMatrixCurrency(nm, seed.class[1], seed.ridx, seed.cidx, )
	nm2 = CreateMatrixCurrency(nm, seed.class[2], seed.ridx, seed.cidx, )
	nm3 = CreateMatrixCurrency(nm, seed.class[3], seed.ridx, seed.cidx, )

	fmc = RunMacro("CheckMatrixCore", sm, "CarFactor", , )
	tfmc = CreateMatrixCurrency(sm, "carcntfact (Skim)", , , )
	cfmc = CreateMatrixCurrency(sm, "carnumcnt (Skim)", , , )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm1 := nm1 * (fmc)

	fmc = RunMacro("CheckMatrixCore", sm, "sutFactor", , )
	tfmc = CreateMatrixCurrency(sm, "sutcntfact (Skim)", , , )
	cfmc = CreateMatrixCurrency(sm, "sutnumcnt (Skim)", , , )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm2 := nm2 * (fmc)

	fmc = RunMacro("CheckMatrixCore", sm, "mutFactor", , )
	tfmc = CreateMatrixCurrency(sm, "mutcntfact (Skim)", , , )
	cfmc = CreateMatrixCurrency(sm, "mutnumcnt (Skim)", , , )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm3 := nm3 * (fmc)

//Enforce min/max
	minmtx = OpenMatrix(seed.min, "Auto")
	min1 = CreateMatrixCurrency(minmtx, seed.class[1], seed.ridx, seed.cidx,)
	min2 = CreateMatrixCurrency(minmtx, seed.class[2], seed.ridx, seed.cidx,)
	min3 = CreateMatrixCurrency(minmtx, seed.class[3], seed.ridx, seed.cidx,)
	maxmtx = OpenMatrix(seed.max, "Auto")
	max1 = CreateMatrixCurrency(maxmtx, seed.class[1], seed.ridx, seed.cidx,)
	max2 = CreateMatrixCurrency(maxmtx, seed.class[2], seed.ridx, seed.cidx,)
	max3 = CreateMatrixCurrency(maxmtx, seed.class[3], seed.ridx, seed.cidx,)

	nm1:= max(nm1, min1)
	nm2:= max(nm2, min2)
	nm3:= max(nm3, min3)
	nm1:= min(nm1, max1)
	nm2:= min(nm2, max2)
	nm3:= min(nm3, max3)

end

if type = "II" then do
//Create Matrix index of Internals-only zones
	SetView(mvw.node)
	numsel = SelectByQuery("Internals", "Several", "Select * where TAZID < 1000", )
	IIset = mvw.node + "|Internals"
	tazindex = CreateMatrixIndex("Internals", sm, "Both", IIset, "TAZID", "TAZID")  // put a new index (TAZ) to skim table

// Apply adjustments to ODs
	nm1 = CreateMatrixCurrency(nm, seed.class[1], "Internals", "Internals", )
	nm2 = CreateMatrixCurrency(nm, seed.class[2], "Internals", "Internals", )
	nm3 = CreateMatrixCurrency(nm, seed.class[3], "Internals", "Internals", )

	fmc = RunMacro("CheckMatrixCore", sm, "CarFactor", "Internals", "Internals" )
	tfmc = CreateMatrixCurrency(sm, "carcntfact (Skim)", "Internals", "Internals", )
	cfmc = CreateMatrixCurrency(sm, "carnumcnt (Skim)", "Internals", "Internals", )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm1 := nm1 * (fmc)

	fmc = RunMacro("CheckMatrixCore", sm, "sutFactor", , )
	tfmc = CreateMatrixCurrency(sm, "sutcntfact (Skim)", "Internals", "Internals", )
	cfmc = CreateMatrixCurrency(sm, "sutnumcnt (Skim)", "Internals", "Internals", )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm2 := nm2 * (fmc)

	fmc = RunMacro("CheckMatrixCore", sm, "mutFactor", "Internals", "Internals")
	tfmc = CreateMatrixCurrency(sm, "mutcntfact (Skim)", "Internals", "Internals", )
	cfmc = CreateMatrixCurrency(sm, "mutnumcnt (Skim)", "Internals", "Internals", )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm3 := nm3 * (fmc)

	//Enforce min/max
	minmtx = OpenMatrix(seed.min, "Auto")
	min1 = CreateMatrixCurrency(minmtx, seed.class[1], "Internals", "Internals",)
	min2 = CreateMatrixCurrency(minmtx, seed.class[2], "Internals", "Internals",)
	min3 = CreateMatrixCurrency(minmtx, seed.class[3], "Internals", "Internals",)
	maxmtx = OpenMatrix(seed.max, "Auto")
	max1 = CreateMatrixCurrency(maxmtx, seed.class[1], "Internals", "Internals",)
	max2 = CreateMatrixCurrency(maxmtx, seed.class[2], "Internals", "Internals",)
	max3 = CreateMatrixCurrency(maxmtx, seed.class[3], "Internals", "Internals",)

	nm1:= max(nm1, min1)
	nm2:= max(nm2, min2)
	nm3:= max(nm3, min3)
	nm1:= min(nm1, max1)
	nm2:= min(nm2, max2)
	nm3:= min(nm3, max3)
end

endMacro

Macro "AdjustAutos" (type)
shared root, mvw, net, skim, seed, flow, od, info, netparam

// Copy Prev Trip Table to create next iteration OD
m = OpenMatrix(od.triptable, )
m1 = CreateMatrixCurrency(m, seed.class[1], seed.ridx, seed.cidx, )
nm = CopyMatrix(m1, {{"File Name", od.nextmtx}})

// Create count/volume on network
	SetView(mvw.line)
	SelectByQuery("Cnts", "Several", "Select * where AADT > 0",)
	{id, AB_CAR_AADT, BA_CAR_AADT, AB_CARFlow, BA_CARFlow} = GetDataVectors(mvw.line + "|Cnts", {"ID", "AB_CAR_ADT","BA_CAR_ADT","AB_Auto","BA_Auto"}, {{"Sort Order",{{"ID","Ascending"}}}} )

	car_abcntfact = if AB_CARFlow > 1 then min((AB_CAR_AADT/AB_CARFlow),10) else null
	car_bacntfact = if BA_CARFlow > 1 then min((BA_CAR_AADT/BA_CARFlow),10) else null
	car_abnumcnt = if AB_CAR_AADT > 0 then 1 else 0
	car_banumcnt = if BA_CAR_AADT > 0 then 1 else 0


	SetDataVectors(mvw.line + "|Cnts", {{"AB_carcntfact",car_abcntfact},{"BA_carcntfact",car_bacntfact},{"AB_carnumcnt",car_abnumcnt},{"BA_carnumcnt",car_banumcnt}}, {{"Sort Order",{{"ID","Ascending"}}}} )

//Write factors for each iteration
carfactor = root.path+"odmecarfactors.bin"

if GetFileInfo(carfactor) = null then do
factvw = CreateTable("Factors", carfactor,"FFB",
			{
			{"ID"       , "Integer", 16, null, "No"},
			{"AB_carnumcnt", "Real"   , 10, 2   , "No"},
			{"BA_carnumcnt", "Real"   , 10, 2   , "No"}
			})
	r = AddRecords(factvw, null, null, {{"Empty Records", id.length}})
	SetDataVectors(factvw+"|", {{"ID",id},
	{"AB_carnumcnt",car_abnumcnt},{"BA_carnumcnt",car_banumcnt}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	CloseView(factvw)
end

	factvw = OpenTable("Factors", "FFB", {carfactor, })
	RunMacro("addfields", factvw, {"AB_carcntfact_"+i2s(info.iter), "BA_carcntfact_"+i2s(info.iter)}, {"r","r","r","r","r","r"})
	SetDataVectors(factvw+"|", {{"AB_carcntfact_"+i2s(info.iter),car_abcntfact},{"BA_carcntfact_"+i2s(info.iter),car_bacntfact}}, {{"Sort Order",{{"ID","Ascending"}}}} )
	CloseView(factvw)

// Skim count/volume along shortest paths to get adjustment factors

	asnvw = OpenTable("asn", "FFB", {flow.dly, })
	jnvw = JoinViews("jnvw", mvw.line+".ID", asnvw+".ID1", )
	SetView(jnvw)
	{abgca,bagca,ab_fft,ba_fft,ab_tt,ba_tt} = GetDataVectors(jnvw + "|", {"AB_FTB_A","BA_FTB_A",asnvw+".AB_Time",asnvw+".BA_Time","AB_AFFTime","BA_AFFTime"}, {{"Sort Order",{{"ID","Ascending"}}}})

	abgctta = (netparam.carpdelay.value * ab_tt) + (ab_fft*(1-netparam.carpdelay.value)) + abgca
	bagctta = (netparam.carpdelay.value * ba_tt) + (ba_fft*(1-netparam.carpdelay.value)) + bagca

	abtca = max(abgca*(netparam.carvot.value/60) - ((netparam.carvot.value/60)*(netparam.carpdelay.value-1) * ab_fft), 0)
	batca = max(bagca*(netparam.carvot.value/60) - ((netparam.carvot.value/60)*(netparam.carpdelay.value-1) * ba_fft), 0)

	SetDataVectors(jnvw + "|", {{"AB_GCTTA",abgctta},{"BA_GCTTA",bagctta}}, {{"Sort Order",{{"ID","Ascending"}}}})
	SetDataVectors(jnvw + "|", {{"AB_TCA",abtca},{"BA_TCA",batca}}, {{"Sort Order",{{"ID","Ascending"}}}})

	CloseView(jnvw)
	CloseView(asnvw)

	RunMacro("update_hnet", 3)

	// Shortest Path Auto
		RunMacro("TCB Init")
		Opts = null
		Opts.Input.Network = net.odme
		Opts.Input.[Origin Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection", "Select * where Centroid = 1"}
		Opts.Input.[Destination Set] = {mvw.linefile+"|"+mvw.node, mvw.node, "Selection"}
		Opts.Input.[Via Set] = {mvw.linefile+"|"+mvw.node, mvw.node}
		Opts.Field.Minimize = "gctta"
		Opts.Field.Nodes = mvw.node+".ID"
		Opts.Field.[Skim Fields] = {{"carcntfact","All"},{"carnumcnt","All"}}
		Opts.Flag = {}
		Opts.Output.[Output Matrix].Label = "Shortest Path"
		Opts.Output.[Output Matrix].[File Name] = skim.odme
		if !RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret) then Return( RunMacro("TCB Closing", ok, True ) )

	sm = OpenMatrix(skim.odme, "True")

// Apply adjustments to ODs
if type = null then do
	nm1 = CreateMatrixCurrency(nm, seed.class[1], seed.ridx, seed.cidx, )

	fmc = RunMacro("CheckMatrixCore", sm, "CarFactor", , )
	tfmc = CreateMatrixCurrency(sm, "carcntfact (Skim)", , , )
	cfmc = CreateMatrixCurrency(sm, "carnumcnt (Skim)", , , )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm1 := nm1 * (fmc)

//Enforce min/max
	minmtx = OpenMatrix(seed.min, "Auto")
	min1 = CreateMatrixCurrency(minmtx, seed.class[1], seed.ridx, seed.cidx,)

	maxmtx = OpenMatrix(seed.max, "Auto")
	max1 = CreateMatrixCurrency(maxmtx, seed.class[1], seed.ridx, seed.cidx,)

	nm1:= max(nm1, min1)
	nm1:= min(nm1, max1)
end

if type = "II" then do
//Create Matrix index of Internals-only zones
	SetView(mvw.node)
	numsel = SelectByQuery("Internals", "Several", "Select * where TAZID < 1000", )
	IIset = mvw.node + "|Internals"
	tazindex = CreateMatrixIndex("Internals", sm, "Both", IIset, "TAZID", "TAZID")  // put a new index (TAZ) to skim table

// Apply adjustments to ODs
	nm1 = CreateMatrixCurrency(nm, seed.class[1], "Internals", "Internals", )

	fmc = RunMacro("CheckMatrixCore", sm, "CarFactor", "Internals", "Internals" )
	tfmc = CreateMatrixCurrency(sm, "carcntfact (Skim)", "Internals", "Internals", )
	cfmc = CreateMatrixCurrency(sm, "carnumcnt (Skim)", "Internals", "Internals", )
	fmc := tfmc / cfmc
	fmc := if fmc = null then 1 else fmc
	nm1 := nm1 * (fmc)


	//Enforce min/max
	minmtx = OpenMatrix(seed.min, "Auto")
	min1 = CreateMatrixCurrency(minmtx, seed.class[1], "Internals", "Internals",)
	maxmtx = OpenMatrix(seed.max, "Auto")
	max1 = CreateMatrixCurrency(maxmtx, seed.class[1], "Internals", "Internals",)

	nm1:= max(nm1, min1)
	nm1:= min(nm1, max1)
end

endMacro


Macro "FratarODs"
shared root, mvw, net, skim, seed, flow, od, info, netparam

extcnt = OpenTable("extcnt", "DBASE", {seed.extcnt, })
tempmtx = "ZZZ.mtx"

	RunMacro("TCB Init")
    Opts = null
    Opts.Input.[Base Matrix Currency] = {od.eiauto, "EI_Pass", "Row ID's", "Col ID's"}
    Opts.Input.[PA View Set] = {eipassfile, "eipass"}
    Opts.Global.[Constraint Type] = "Doubly"
    Opts.Global.Iterations = 100
    Opts.Global.Convergence = 0.01
    Opts.Field.[Core Names Used] = {"EI_Pass"}
    Opts.Field.[P Core Fields] = {"eipass.EI_O"}
    Opts.Field.[A Core Fields] = {"eipass.EI_D"}
    Opts.Output.[Output Matrix].Label = "Fratar Ext"
    Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = tempmtx
    ok = RunMacro("TCB Run Procedure", "Growth Factor", Opts, null)
	if !ok then Return( RunMacro("TCB Closing", ok, True ) )

endMacro

//===================================================

//Reporting
Macro "CalRep" (domap, volfld)
	shared root, mvw, outdir, info, countfile

	if volfld = null then do
		volfld.type = "All"
		volfld.vol = "TotFlow"	//Tot_Truck
		volfld.cnt = "AADT"	//TOTTRK_ADT
	end

	dt = CreateDateTime()
	timestamp = FormatDateTime(dt,"MMMddyyyy_HHmm")

	calrep.output = outdir.rep+"CalRep_"+volfld.vol+"_"+timestamp+".dbf"

	//countfile				// = this will eventually be the 5-YR historic count file that Sumit prepared (STATIONID)

	RunMacro("addfields", mvw.line, {"AbsErr", "Error"}, {"r","r"})
	SetRecordsValues(mvw.line+"|", {{"AbsErr", "Error"}, null}, "Value", {null,null}, null)

	if domap = 1 then do
	RunMacro("addfields", mvw.line, {"dispcnt"}, {"c"})
	SetRecordsValues(mvw.line+"|", {{"dispcnt"}, null}, "Value", {null}, null)
	end
     // Create report file
	outview = CreateTable("Calibration Report", calrep.output, "dBase",
							{{"Type"     , "String" , 20, null, "No"},
							{"Item"      , "String" , 25, null, "No"},
							{"NumObs"    , "Integer", 8 , null, "No"},
							{"TotCnt"    , "Real"   , 10, 2   , "No"},
							{"TotMod"    , "Real"   , 10, 2   , "No"},
							{"AvgCnt"    , "Real"   , 10, 2   , "No"},
							{"AvgMod"    , "Real"   , 10, 2   , "No"},
							{"Tstat"     , "Real"   , 10, 2   , "No"},
							{"AvgErr"    , "Real"   , 10, 2   , "No"},
							{"PctErr"    , "Real"   , 10, 2   , "No"},
							{"PctRMSE"   , "Real"   , 10, 2   , "No"},
							{"MAPE"      , "Real"   , 10, 2   , "No"},
							{"CorrCoef"  , "Real"   , 10, 2   , "No"},
							{"Miles"     ,"Real"    , 10, 2   , "No"},
							{"VMT"       ,"Real"    , 10, 2   , "No"},
							{"AvgCtXMil" ,"Real"    , 10, 2   , "No"}
							})

	calrepinfo = OpenTable("calrepinfo", "FFB", {info.calrep, })
	{Type, Item, Query} = GetDataVectors(calrepinfo + "|", {"Type", "Item", "Query"}, null)
	CloseView(calrepinfo)

	SetView(mvw.line)
	// This part of the code is joining a count database to the *.dbd
	// We will skip over this for now, but will use this later once we start using the 5-YR historical count database with STATIONID
	/*
	countvw = OpenTable("CountVols", "FFB", {info.count, })
	jnvw = JoinViews(mvw.line + countvw, mvw.line+".ID", countvw+".TCID", null)
	SetView(jnvw)
	thisvw = jnvw
	*/
	thisvw = mvw.line

	//use TN_weighted_counts3.csv
  for i = 1 to Query.length do
		NumObs = SelectByQuery("set", "Several", "Select * where (" + Query[i] +") and "+volfld.cnt+" > 0", )
		if NumObs > 0 then do
			{cnt, vol} = GetDataVectors(thisvw + "|set", {volfld.cnt, volfld.vol},{{"Sort Order",{{mvw.line+".ID","Ascending"}}}})
			weight = Vector(NumObs, "Long", {{"Constant", 1}})
			//weight = if dualized = 1 then 1 else 1
			NumObsW = VectorStatistic(weight, "Sum" , )
			totcnt = VectorStatistic(cnt , "Sum" , {"Weight",weight})
			avgcnt = VectorStatistic(cnt , "Mean", {"Weight",weight})
			stdcnt = VectorStatistic(cnt , "Sdev", {"Weight",weight})
			totvol = VectorStatistic(vol , "Sum" , {"Weight",weight})
			avgvol = VectorStatistic(vol , "Mean", {"Weight",weight})
			stdvol = VectorStatistic(vol , "Sdev", {"Weight",weight})
			avgerr = avgvol - avgcnt
			tstat = avgerr / sqrt( (pow(stdcnt,2)/NumObsW) + (pow(stdvol,2)/NumObsW) )
			pcterr = 100*avgerr/avgcnt
			sqerr = pow(vol - cnt,2)
			mse = VectorStatistic(sqerr, "Mean", )
			pctrmse = 100*sqrt(mse)/avgcnt
			pctabserr = abs(vol - cnt)/cnt
			mape = 100*VectorStatistic(pctabserr, "Mean", {"Weight",weight})
			tmp = (cnt - avgcnt)*(vol - avgvol)
			corrcoef = VectorStatistic(tmp, "Sum", )/max(1,(NumObsW - 1)*stdcnt*stdvol)
		end
		if i = 1 then do
			error = vol - cnt
			abserr = abs(error)
			SetDataVectors(thisvw+"|set",{{"AbsErr",abserr}, {"Error",error}}, {{"Sort Order",{{thisvw+".ID","Ascending"}}}})
			fit = pctrmse
			if domap = 1 then do
				adttdv = CreateExpression(thisvw, "adttdv", '(if '+volfld.cnt+'<>null then String('+volfld.cnt+') else "--")+"|"+(if '+volfld.vol+'<>null then Format('+volfld.vol+',"*") else "--")', )
				SetRecordsValues(thisvw+"|", {{"dispcnt"}, null}, "Formula", {"adttdv"},)
			end
		end

		//Query whole network for mileage summation
		AllObs = SelectByQuery("set", "Several", "Select * where (" + Query[i] +")", )
		if nz(AllObs)>0  then do 		//Moves Groups and all other mileage summations
			{miles,vol2} = GetDataVectors(thisvw + "|set", {"Length",volfld.vol},{{"Sort Order",{{thisvw+".ID","Ascending"}}}})
			centline_vect= nz(miles)
			//centline_vect= nz(if Divided = 1 then 0.5* miles else miles)// Centerline mileage calc using divided roadways
			centlinemile= VectorStatistic(centline_vect, "Sum",)       //Network mileage
			vmt_vect= nz(vol2*miles)
			vmt= VectorStatistic(vmt_vect, "Sum",)                    //Network VMT using total mileage
			avgcntmiles= avgcnt* VectorStatistic(miles, "Sum",)       //Avg Count * total mileage
		end
		else do {vmt,avgcntmiles,centlinemile} = {0,0,0} end


		if NumObs = 0 then {totcnt, totvol, avgcnt, avgvol, stdcnt, stdvol, avgerr, tstat, pcterr, sqerr, mse, pctrmse, pctabserr, mape, tmp, corrcoef} = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		if AllObs = 0 then {centlinemile, vmt, avgcntmiles} = {0,0,0}

		AddRecord(outview, {
			{"Type"       , Type[i]}    ,
			{"Item"       , Item[i]}    ,
			{"NumObs"     , NumObs}     ,
			{"TotCnt"     , totcnt}     ,
			{"TotMod"     , totvol}     ,
			{"AvgCnt"     , avgcnt}     ,
			{"AvgMod"     , avgvol}     ,
			{"Tstat"      , tstat}      ,
			{"AvgErr"     , avgerr}     ,
			{"PctErr"     , pcterr}     ,
			{"PctRMSE"    , pctrmse}    ,
			{"MAPE"       , mape}       ,
			{"CorrCoef"   , corrcoef}   ,
			{"Miles"      ,centlinemile},
			{"VMT"        ,vmt}         ,
			{"AvgCtXMil"  ,avgcntmiles} }
		)

	end


DeleteSet("set")

if domap = 1 then do
	expressions = GetExpressions(mvw.line)
	theme_names = GetThemes(mvw.line)
	for j = 1 to expressions.length do if expressions[j] = "adtdtv" then DestroyExpression(mvw.line+".adtdtv") end
	for j = 1 to theme_names.length do if theme_names[j] = "color" or theme_names[j] = "scaled" then DestroyTheme(theme_names[j]) end
	myblue = ColorRGB(0,44204,65535)
	black  = ColorRGB(0,0,0)
	red    = ColorRGB(65535,0,0)
	SetLabels(mvw.line+"|", "dispcnt", {{"Color", myblue},{"Extra Colors", {black}},{"Font", "Arial|10"}})
	if volfld.type = "All" then  clrthm = CreateTheme("color", mvw.line+".Error", "Manual", 10, {{"Values" , {{-1000000, "True", -100000, "False"}, {-100000, "True", -50000, "False"}, {-50000, "True", -25000, "False"}, {-25000, "True", -10000, "False"}, {-10000, "True", 0, "False"}, {0, "True", 10000, "False"}, {10000, "True", 25000, "False"}, {25000, "True", 50000, "False"}, {50000, "True", 100000, "False"}, {100000, "True", 1000000, "True"}} }, {{"Pretty Values", "True"}}})
	if volfld.type <> "All" then clrthm = CreateTheme("color", mvw.line+".Error", "Manual", 10, { {"Values", { {-100000, "True", -9000  , "False"}, {-9000  , "True", -5000 , "False"}, {-5000 , "True", -3000 , "False"}, {-3000 , "True", -1000 , "False"}, {-1000 , "True", 0, "False"}, {0, "True", 1000 , "False"}, {1000 , "True", 3000 , "False"}, {3000 , "True", 5000 , "False"}, {5000 , "True", 9000  , "False"}, {9000  , "True", 100000 , "True"}} }, {{"Pretty Values", "True"}}})
	//clrs = GeneratePalette(black, red, 9, {{"method", "RGB"}})
	clrs = {black, black, black, black, black, black, red, red, red, red, red}
	SetThemeLineColors(clrthm, clrs)
	ShowTheme(, clrthm)
	sclthm = CreateContinuousTheme("scaled", {mvw.line+".AbsErr"},)
	ShowTheme(, sclthm)
end

if info.count <> null then do
	if thisvw = jnvw then CloseView(jnvw)
	CloseView(countvw)
end

SetLayer(mvw.line)
CloseView(outview)
Return(fit)
endMacro

//Batch Macro
Macro "MMA" (mma)
/*
mma.Database , mma.Network , mma.OD , mma.Excl , mma.CurrName , mma.GenCost , mma.Method , mma.Convergence , mma.Iterations ,
mma.NumClass , mma.PCE , mma.VOI , mma.VDF , mma.VDFflds , mma.VDFdef , mma.FlowTable ,
mma.AON.FFTime , mma.CUE.Nconjugate , mma.CUE.iterfile , mma.SUE.error , mma.SUE.function , mma.PUE.time , mma.PUE.path
*/

    RunMacro("TCB Init")
    Opts = null
    Opts.Input.Database = mma.Database
    Opts.Input.Network = mma.Network
    Opts.Input.[OD Matrix Currency] = mma.OD
    Opts.Input.[Exclusion Link Sets] = mma.Excl
    //Opts.Field.[Turn Attributes] = {}
    Opts.Field.[Class Names] = mma.CurrName
	Opts.Field.[Fixed Toll Fields] = mma.GenCost
    //Opts.Field.[Operating Cost Fields] = {"None"}
    //Opts.Field.[PCE Fields] = {"None"}
    Opts.Global.[Load Method] = mma.Method
    Opts.Global.[Loading Multiplier] = 1
    Opts.Global.Convergence = mma.Convergence
    Opts.Global.Iterations = mma.Iterations
    Opts.Global.[Number of Classes] = mma.NumClass
    Opts.Global.[Class PCEs] = mma.PCE
    Opts.Global.[Class VOIs] = mma.VOI
    Opts.Global.[VDF DLL] = mma.VDF
    Opts.Field.[VDF Fld Names] = mma.VDFflds
    Opts.Global.[VDF Defaults] = mma.VDFdef
    Opts.Output.[Flow Table] = mma.FlowTable


	/*
	//Below adds PCE Flows to .net file
	//Logical next set is table export with AB_/BA_/Tot_ prefixes

	Opts.Flag.[Do Flow Saving] = 1
	Opts.Global.[Save Flow Iteration] = 1
	Opts.Field.[Link Flow] = {"AT", "ST", "MT"}
	*/

	//AON - All or Nothing
	if mma.Method = "AON" then do
		Opts.Field.[FF Time] = mma.AON.FFTime
	end

	//CUE - N Conjugate UE
	if mma.Method = "CUE" then do
		Opts.Global.[N Conjugate]   = mma.CUE.Nconjugate
		Opts.Output.[Iteration Log] = mma.CUE.iterfile
	end

	//SUE - Stochastic User Equilibrium
	if mma.Method = "SUE" then do
		Opts.Global.[Stoch Error]         = mma.SUE.error
		Opts.Global.[Stochastic Function] = mma.SUE.function
	end

	//PUE - Path-based UE
	if mma.Method = "PUE" then do
		Opts.Global.[Time Minimum] = mma.PUE.time
		Opts.Output.[Path File] = mma.PUE.path
	end

    ok = RunMacro("TCB Run Procedure", "MMA", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )
	Return(RunMacro("TCB Closing", ok, False))
endMacro

/*
	ptr = OpenFile("C:\\Temp\\P_MMA.txt", "a")
	WriteArray(ptr, mma)
    WriteArray(ptr, Ret)
	CloseFile(ptr)


	thisvw = GetView()
	eia = CreateExpression(thisvw, "eia", "EIAuto_R+EIAuto_C", )
	eis = CreateExpression(thisvw, "eis", "EISUT_R+EISUT_C", )
	eim = CreateExpression(thisvw, "eim", "EIMUT_R+EIMUT_C", )
	SetRecordsValues(thisvw+"|", {{"EIAuto","EISUT","EIMUT"}, null}, "Formula", {"eia","eis","eim"},)

	eea = CreateExpression(thisvw, "eea", "(AutoCnt - EIAuto)/2", )
	ees = CreateExpression(thisvw, "ees", "(SUTCnt - EISUT)/2", )
	eem = CreateExpression(thisvw, "eem", "(MUTCnt - EIMUT)/2", )
	SetRecordsValues(thisvw+"|", {{"EEAuto","EESUT","EEMUT"}, null}, "Formula", {"eea","ees","eem"},)

	arr = GetExpressions(thisvw)
	for i = 1 to arr.length do DestroyExpression(thisvw+"."+arr[i]) end

*/
