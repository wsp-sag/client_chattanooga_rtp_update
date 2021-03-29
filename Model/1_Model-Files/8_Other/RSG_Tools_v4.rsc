
//Dataview Tools
Macro "addfields" (dataview, newfldnames, typeflags)
//Add a new field to a dataview; does not overwrite
//RunMacro("addfields", mvw.node, {"Delay", "Centroid", "Notes"}, {"r","i","c"})
	fd = newfldnames.length
	dim fldtypes[fd]
	
	if TypeOf(typeflags) = "array" then do 
		for i = 1 to newfldnames.length do
			if typeflags[i] = "r" then fldtypes[i] = {"Real", 12, 2}
			if typeflags[i] = "i" then fldtypes[i] = {"Integer", 10, 3}
			if typeflags[i] = "c" then fldtypes[i] = {"String", 16, null}
		end
	end
	
	if TypeOf(typeflags) = "string" then do 
		for i = 1 to newfldnames.length do
			if typeflags = "r" then fldtypes[i] = {"Real", 12, 2}
			if typeflags = "i" then fldtypes[i] = {"Integer", 10, 3}
			if typeflags = "c" then fldtypes[i] = {"String", 16, null}
		end
	end

	SetView(dataview)
   struct = GetTableStructure(dataview)

	dim snames[1]
   for i = 1 to struct.length do
      struct[i] = struct[i] + {struct[i][1]}
	snames = snames + {struct[i][1]}
   end

	modtab = 0
   for i = 1 to newfldnames.length do
      pos = ArrayPosition(snames, {newfldnames[i]}, )
      if pos = 0 then do
         newstr = newstr + {{newfldnames[i], fldtypes[i][1], fldtypes[i][2], fldtypes[i][3], 
					"false", null, null, null, null}}
         modtab = 1
      end
   end

   if modtab = 1 then do
      newstr = struct + newstr
      ModifyTable(dataview, newstr)
   end
endMacro

Macro "dropfields" (dataview, fldnames)
//Remove field in a dataview
//RunMacro("dropfields", mvw.node, {"Delay","Centroid","Notes"})

   struct = GetTableStructure(dataview)

   for i = 1 to struct.length do
      struct[i] = struct[i] + {struct[i][1]}
      pos = ArrayPosition(fldnames, {struct[i][1]}, )
      if pos = 0 then do
          newstr = newstr + {struct[i]}
      end
      else modtab = 1
   end

   if modtab = 1 then do
      ModifyTable(dataview, newstr)
   end
endMacro

Macro "renamefields" (dataview, oldfldnames, newfldnames)
//Rename field in a dataview; throws error if new name is duplicate
//RunMacro("renamefields", mvw.node, {"Delay","Notes"},{"SigDelay","Info"})
	struct = GetTableStructure(dataview)
	dupefld = 0
	modtab = 0
	
	//Check that newfieldnames dont not exist
	for i = 1 to struct.length do
		pos = ArrayPosition(newfldnames, {struct[i][1]}, )
		if pos <> 0 then do
			dupefld = 1
			goto skip	//duplicate name found
		end	
	end
		
		//Find & replace oldfieldname
	for numflds = 1 to oldfldnames.length do
		for i = 1 to struct.length do
			pos = ArrayPosition({oldfldnames[numflds]}, {struct[i][1]}, )	//might not be the best string array comparison
			if pos <> 0 then do
				struct[i][1] = newfldnames[numflds]
				modtab = 1
			end	
		end
	end

	if modtab = 1 then do
		ModifyTable(dataview, struct)
	end

skip:
if dupefld = 1 then ShowMessage("Cannot rename - duplicate found")
endMacro

Macro "TableStatistics" (view, outfilename)
outvw = ComputeStatistics(view+"|", "Summary", outfilename, "dBASE", {{"Strings", "False"}})
Return(outvw)
endMacro

Macro "AggregateTable" (vwset, groupfld, aggflds, outbin)
/*
	vwset = tourvw+"|"
	groupfld = "TAZID"
	aggflds = {{"WorkTours","sum",},{"Wrk_LoIncWrk","sum",},{"Wrk_MidIncWrk","sum",},{"Wrk_HighIncWrk","sum",},{"Wrk_College","sum",},{"Wrk_Other","sum",},{"SchoolTours","sum",},{"Schl_School","sum",},{"Schl_Other","sum",},{"OtherTours","sum",},{"Othr_ShrtMnt","sum",},{"Othr_LngMnt","sum",},{"Othr_Discrtn","sum",},{"Othr_College","sum",}}
	outbin = mcdir+"TAZ_temp.bin"
*/
	aggvw = AggregateTable("AggTable",vwset,"FFB",outbin,groupfld,aggflds,)
	Return(aggvw)
endMacro

Macro "JoinCopy" (vw1, vw2, jnfld1, jnfld2, fldarr)
//Transfer vw1 fields to vw2, Assumes a One-to-Many join
on notfound do
		on NotFound default
		ShowMessage("JoinCopy Error: Missing field")
		Return(0)
end

//Add fields from vw1 to vw2
for i=1 to fldarr.length do
	fldspec = GetFieldFullSpec(vw1,fldarr[i])
	if fldspec = null then throw("JoinCopy Error: " + fldarr[i])
	fldinfoarr = GetFieldInfo(fldspec)
	if fldinfoarr[1] = "String" then RunMacro("addfields", vw2, {fldarr[i]}, "s")
	if fldinfoarr[1] = "Integer" then RunMacro("addfields", vw2, {fldarr[i]}, "i")
	if fldinfoarr[1] = "Real" then RunMacro("addfields", vw2, {fldarr[i]}, "r")
end

jnvw = JoinViews(vw1 + vw2, vw1+"."+jnfld1, vw2+"."+jnfld2, {{"O",null}})	//One-to-Many join
for i=1 to fldarr.length do
	SetRecordsValues(jnvw+"|", {{vw2+"."+fldarr[i]}, null}, "Formula", {vw1+"."+fldarr[i]},) 
end
CloseView(jnvw)
Return(1)
endMacro

Macro "AddMissingRecords" (vw1, vw2, fld1, sel)
SetView(vw2)
nqry = SelectByQuery("qry", "Several", "Select * where "+sel,)
if nqry = 0 then Return()
vec = GetDataVector(vw2+"|qry", fld1, {{"Sort Order",{{fld1,"Ascending"}}}})
arr = VectorToArray(vec)

for i=1 to arr.length do
rh = AddRecord(vw1, {
		{fld1, arr[i]}
     })

end
endMacro

//Network Scenario Management
Dbox "GetMasterNet" Title: "Select Master Network & Scenario"
Init do
	shared root, netpath
	HideItem("ScenView")
	layer_names = GetLayerNames()  
	netmenu = layer_names		
endItem

text "Master Network Line Layer" 2, 2	
	button "MNetBrowse" 34, 4, 6.5 Prompt:"Browse" do
       	on escape goto endhere
		netfile = ChooseFile({{"Master Network", "*.dbd"}}, "Choose the masternet layer", {,{"Initial Directory", root.mod + "\\Inputs\\Network\\"},})
     	netpathname = SplitPath(netfile)
		netpath = netpathname[1] + netpathname[2]
     	netname = netpathname[3] + netpathname[4]
     	netmenu = netmenu + {netname}
     	mnidx = netmenu.length
		
		//Get Scenario*.txt files from Masternet folder
		scninfo = GetDirectoryInfo(netpathname[1] + netpathname[2] + "\\Scenarios\\*.txt", "File")
		scnmenu = null
		for i=1 to scninfo.length do scnmenu = scnmenu + {scninfo[i][1]} end
	endhere:
	endItem
	
	popdown menu "Network" 2, 4, 27 list:netmenu variable:mnidx do 
		netfile = GetLayerDB(netmenu[mnidx])
		
		//Get Scenario*.txt files from Masternet folder
		netpathname = SplitPath(netfile)
		netpath = netpathname[1] + netpathname[2]
		scninfo = GetDirectoryInfo(netpath + "\\Scenarios\\*.txt", "File")
		scnmenu = null
		for i=1 to scninfo.length do scnmenu = scnmenu + {scninfo[i][1]} end
	endItem

	
	
text "Identify Highway Network Scenario" 2, 7	
   button "ScenBrowse" 34, 9, 6.5 Prompt:"Browse" do
       	on escape goto endhere
		scnfile = ChooseFile({{"Scenario File", "*.txt"}}, "Choose the Scenario definition file", {,{"Initial Directory", root.mod + "\\Inputs\\Network\\Scenarios"},})
     	scnpart = SplitPath(scnfile)
     	scnname = scnpart[3] + scnpart[4]
     	scnmenu = scnmenu + {scnname}
     	scnidx = scnmenu.length
		ShowItem("ScenView")
	endhere:
	endItem
	
	popdown menu "NS" 2, 9, 27 list:scnmenu variable:scnidx do 
		scnfile = netpath + "\\Scenarios\\" + scnmenu[scnidx]
		ShowItem("ScenView")
	endItem

	Button "ScenView" 2, 11, 6.5 Prompt:"View" do
		status = RunProgram("notepad " + scnfile, )
	endItem 
	
	Button "OK" 8, 16, 9, 1 Default do
		scenario = scnmenu[scnidx]
		masternet = netmenu[mnidx]
		//ShowMessage(masternet + "|" + scenario +"\n" + netfile +"|"+ scnfile)
		Return({netfile, scnfile})
	endItem 

    Button "Cancel" 19, same, 9, 1 Cancel do return() endItem
EndDbox

Macro "m2a" (masternet, scenario, outlinefile, rtsfile)
	//Processes Scenario.txt & Project.bin files on a Master/Complete network to produce a Scenario/Output Network
	/*
	outscennet = ChooseFileName({{"Standard", "*.dbd"}}, "Choose name for new network file", {,{"Initial Directory", indir.hwy},{"Suggested Name","Network_"+scnname}, })
	RunMacro("m2a", mvw.masternet, mvw.scnfile, outscennet) 
	*/

	//{masternet, scenario} = RunDbox("GetMasterNet")
	if scenario = null then Return()
	
	//Assumes Project *.bin files are in masternet folder
	scnpathname = SplitPath(scenario)
	scnname = scnpathname[3]
	netpathname = SplitPath(masternet)
	netpath = netpathname[1] + netpathname[2]
	projinfo = GetDirectoryInfo(netpath + "Projects\\*.bin", "File")
	
	//Open & Read Scenario File to get Projects
	ptr = OpenFile(scenario, "r")
	projlist = ReadArray(ptr)
	
	//Add Masternet to map, clear sets, then copy/open as linevw_output .dbd
	mvw.masternet = RunMacro("AddLayer", masternet, "Line")
	sets_list = GetSets(mvw.masternet)
	for i=1 to sets_list.length do
		if sets_list[i] = "addnet" then DeleteSet("addnet")
		if sets_list[i] = "dropnet" then DeleteSet("dropnet")
	end
	
	CopyDatabase(masternet, outlinefile)
	DropLayer(null, mvw.masternet)

	mvw.line = RunMacro("AddLayer", outlinefile, "Line")
	mvw.node = GetNodeLayer(mvw.line)
	mvw.line = RenameLayer(mvw.line, "Network_"+scnname, {{"Permanent", "True"}})
	mvw.node = RenameLayer(mvw.node, "Node", {{"Permanent", "True"}})
	
	//Add .rts file to absorb edits
	if GetFileInfo(rtsfile) <> null then do
		outrtsfile = RunMacro("UpdateRTS", rtsfile, outlinefile)
		mvw.rts = RunMacro("AddLayer", outrtsfile, "rts")
	end
	
	//If Project List & Project.bin names match, then addproject
	SetView(mvw.line)
	for i = 1 to projlist.length do
		if left(projlist[i],1) = ";" or left(projlist[i],2) = " ;" or projlist[i] = null then goto skip
		project = Word(projlist[i], 1)
		for j = 1 to projinfo.length do 
			projfile = netpath + "Projects\\" + projinfo[j][1]
			projpath = SplitPath(netpath + projinfo[j][1])
			projname = projpath[3]
				if project = projname then RunMacro("addproject", mvw, projfile, projname)
				else if project = "Base" then RunMacro("addproject", mvw, null, "Base", )
		end
	skip:
	end
	
	
	//Remove all links not in addnet set - this causes route layer update prompt
	SetView(mvw.line)
	numdrop = SetInvert("dropnet", "addnet")
	DeleteRecordsInSet("dropnet")
	
	
	//ShowMessage(GetLastError({{"Reference Info", "False"}}))
	SetView(mvw.line)
	sets_list = GetSets(mvw.line)
	for i=1 to sets_list.length do
		if sets_list[i] = "addnet" then DeleteSet("addnet")
		if sets_list[i] = "dropnet" then DeleteSet("dropnet")
	end
	
	if GetFileInfo(rtsfile) <> null then do
		SetView(mvw.rts)
		DropLayer(null, mvw.rts)
	end
	DropLayer(null, mvw.line)
	layers = GetLayers()
	if layers = null then do
		thismap = GetMap()
		CloseMap(thismap)
	end
	
	//SetSelectDisplay("True")

endMacro

Macro "addproject" (mvw, projectfile, projectname)
//Process project.bin field

	SetView(mvw.line)
	if projectname = "Base" then do SelectByQuery("addnet", "More", "Select * where Base > 0") Return() end
	
	//Verify that project file has correct fields
	projvw = OpenTable("projvw", "FFB", {projectfile, })
	SetView(projvw)
	{fldnms, fldspcs} = GetFields(projvw, "All")
	dim checkfld[4]
	for i = 1 to fldspcs.length do
		if fldnms[i] = "Action" then checkfld[1] = 1
		if fldnms[i] = "ID" then checkfld[2] = 1
		if fldnms[i] = "Field_Name" then checkfld[3] = 1
		if fldnms[i] = "Field_Value" then checkfld[4] = 1	
	end
	if checkfld[1]*checkfld[2]*checkfld[3]*checkfld[4] <> 1 then throw("Field Names missing in project : " + projectfile)
	
//Get all Add Actions
	SelectByQuery("projadd", "Several", "Select * where Action = 'Add'")
	addlinks = GetDataVector(projvw+"|projadd", "ID", null)
	if addlinks.length = 0 then goto skipadd
	addlinksarr = V2A(addlinks)
	
	SetView(mvw.line)
	addlen = SelectByIDs("addnet", "More", addlinksarr)
	if addlinks.length <> addlinksarr.length then throw("Link does not exist in project: " + projectfile)
	
	skipadd:
	SetView(projvw)
	DeleteSet("projadd")
	
//Step through Modify Actions
	SetView(projvw)
	SelectByQuery("projmod", "Several", "Select * where Action = 'Modify'")
	modlinks = GetDataVector(projvw+"|projmod", "ID", null)
	if modlinks.length = 0 then goto skipmod
	
	rec = GetFirstRecord(projvw+"|projmod", null)
	while rec <> null do		
		linerec = LocateRecord(mvw.line+"|", "ID", {projvw.ID}, {{"Exact", "True"}})
		if linerec <> null then SetRecord(mvw.line, linerec) else do ShowMessage("Cannot modify Link ID "+string(projvw.ID)+". Link does not exist!") goto skipmod end
		fldnametest = projvw.Field_Name
		fldvaluetest = projvw.Field_Value
		fldtype = GetFieldType(mvw.line+"."+projvw.Field_Name)
		if fldtype = "String" then SetRecordValues(mvw.line, linerec, { {projvw.Field_Name,projvw.Field_Value} })
		else if fldtype = "Integer" then SetRecordValues(mvw.line, linerec, { {projvw.Field_Name,s2i(projvw.Field_Value)} })
		else if fldtype = "Real" then SetRecordValues(mvw.line, linerec, { {projvw.Field_Name,s2r(projvw.Field_Value)} })
		else Throw("Field does not exist in layer: "+ projvw.Field_Name)
        rec = GetNextRecord(projvw+"|projmod", null, null)
     end

	skipmod:
	SetView(projvw)
	DeleteSet("projmod")
	
//Step through Node Actions
	SetView(projvw)
	SelectByQuery("projnode", "Several", "Select * where Action = 'Node'")
	modlinks = GetDataVector(projvw+"|projnode", "ID", null)
	if modlinks.length = 0 then goto skipnode
	
	rec = GetFirstRecord(projvw+"|projnode", null)
	while rec <> null do		
		linerec = LocateRecord(mvw.node+"|", "ID", {projvw.ID}, {{"Exact", "True"}})
		if linerec <> null then SetRecord(mvw.node, linerec) else do ShowMessage("Cannot modify Node ID "+string(projvw.ID)+". Node does not exist!") goto skipnode end
		fldnametest = projvw.Field_Name
		fldvaluetest = projvw.Field_Value
		fldtype = GetFieldType(mvw.node+"."+projvw.Field_Name)
		if fldtype = "String" then SetRecordValues(mvw.node, linerec, { {projvw.Field_Name,projvw.Field_Value} })
		else if fldtype = "Integer" then SetRecordValues(mvw.node, linerec, { {projvw.Field_Name,s2i(projvw.Field_Value)} })
		else if fldtype = "Real" then SetRecordValues(mvw.node, linerec, { {projvw.Field_Name,s2r(projvw.Field_Value)} })
		else Throw("Field does not exist in layer: "+ projvw.Field_Name)
        rec = GetNextRecord(projvw+"|projnode", null, null)
     end

	skipnode:
	SetView(projvw)
	DeleteSet("projnode")

//Remove Deleted Links
	SetView(projvw)
	SelectByQuery("projdrop", "Several", "Select * where Action = 'Remove' or Action = 'Delete'")
	droplinks = GetDataVector(projvw+"|projdrop", "ID", null)
	if droplinks.length = 0 then goto skipdel
	droplinksarr = V2A(droplinks)
	
	SetView(mvw.line)
	droplen = SelectByIDs("dropnet", "More", droplinksarr)
	if droplinks.length <> droplinksarr.length then do throw("Link does not exist in project: " + projectfile) goto skipdel end
	DeleteRecordsInSet("dropnet")
	
	skipdel:
	SetView(projvw)
	DeleteSet("projdrop")
	
	Return()
endMacro

Macro "shp2dbd"
//Convert .shp to a TC6 .dbd file and expand on any truncated field names
//Developed for MACOG 11/22/13 - All inputs are currently hard-coded (fieldnames, projection)
on escape, notfound do
		on escape default
		on NotFound default
		Return()
end
	
//fieldtypes = (r)eal   , (i)nteger     , or (c)haracter
{r, i, c} = {"r", "i", "c"}

//USER INPUT: label name of output dbd
label = "TN_TAZ"

//USER INPUT: fieldnames & fieldtypes
//ID	Shape_Leng	Shape_Area	
shp_fieldnames = {"ID", "Area", "ID:1", "Shape_Leng", "Shape_Area"}
				//aAreaType  , aCounty  , aTOTPOP  ,aHHPOP   ,aGQPOP    ,aHH   ,aHU   ,aAVGHHSIZE   ,aAVG_MEDHH     ,aWRKR_PER_    ,aVEH_PER_H   ,aSTD_PER_H   ,aPCT_HH_W_     ,aEnroll_K1    ,aUniv_Stdn    ,aUniv_Enro    ,aEnrUOn   ,aEnrUOff   ,aEnrUPT   ,aBasic_Emp   ,aIndust_Em       ,aRetail_Em   ,aServic_Em    ,aFarm_Emp   ,aTOTEMP
old_fieldnames = {"aAreaType", "aCounty", "aTOTPOP", "aHHPOP",  "aGQPOP", "aHH", "aHU", "aAVGHHSIZE",   "aAVG_MEDHH",  "aWRKR_PER_", "aVEH_PER_H", "aSTD_PER_H",   "aPCT_HH_W_", "aEnroll_K1" ,  "aUniv_Stdn",  "aUniv_Enro", "aEnrUOn", "aEnrUOff", "aEnrUPT", "aBasic_Emp", "aIndust_Em"    , "aRetail_Em",  "aServic_Em", "aFarm_Emp", "aTOTEMP"}
new_fieldnames = {"AreaType" , "County" , "TOTPOP" ,  "HHPOP",  "GQPOP" ,  "HH",  "HU", "AVGHHSIZE" , "AVG_MEDHHINC", "WRKR_PER_HH", "VEH_PER_HH", "STD_PER_HH", "PCT_HH_W_SR" ,  "Enroll_K12", "Univ_Stdnts", "Univ_Enroll",  "EnrUOn",  "EnrUOff",  "EnrUPT",  "Basic_Emp", "Industrial_Emp", "Retail_Emp", "Service_Emp", "Farm_Emp" , "TOTEMP"}
fieldtypes     = {c          , i        , i        ,i        ,i         ,i     ,r     , r           ,r              ,r             ,r            ,r            ,r              ,i             ,i             ,r             ,i         ,i          ,i         ,i            ,i                ,i            ,i             ,i           ,i}

//Get shapefile & output directory
map_name = GetMap()
shapefile = ChooseFile({{"Shapefile (*.shp)", "*.shp"}}, "Select an ESRI Shapefile", null)
shppath = SplitPath(shapefile)
initdir = shppath[1] + shppath[2]
filename = shppath[3]
dbdfinal = ChooseFileName({{"Standard (*.dbd)", "*.dbd"}}, "New dbd filename", {,{"Initial Directory", initdir}, {"Suggested Name", label},}) 
dbdtemp = "C:\\Temp\\temp.dbd"


//Convert to dbd, several additional options can be used
ImportArcViewShape(shapefile, dbdtemp, { {"Label", label}, {"Layer Name", label}, {"Optimize", "True"}, {"Projection", "nad83:1301", {"units=us-ft"}} })

//Add Layer to Map
file_layers = GetDBLayers(dbdtemp)
file_info = GetDBInfo(dbdtemp)
if map_name = null then map_name = CreateMap("My DBD Export", {{"Scope", file_info[1]}, {"Auto Project", "True"}})
dbdvw = AddLayer(null, file_layers[1], dbdtemp, file_layers[1]) //Some issues if node layer & need to add line layer


//Export again to .dbd to set ID field?
dbdfields = GetFields(dbdvw, "All")
newfields = shp_fieldnames + new_fieldnames
ExportGeography(dbdvw, dbdfinal, {{"Field Spec", dbdfields[2]},{"Field Name", newfields},{"ID Field",dbdfields[2][3]},{"Label", label},{"Layer Name", label}})
DropLayer(,dbdvw)
dbdlayers = GetDBLayers(dbdfinal)
dbdvw = AddLayer( , label, dbdfinal, dbdlayers[1])
SetLayer(dbdvw)
RunMacro("dropfields", dbdvw, {"ID:1", "Shape_Leng", "Shape_Area"})

ShowMessage("dbd Conversion Complete!")
endMacro

Macro "dbd2shp"
//Convert TC6 .dbd to ESRI .shp ; used solely with Erich Rentz MACOG toolbox to avoid fieldname truncation
//Developed for MACOG 11/22/13 - All inputs are currently hard-coded
//Best for most users to just use ExportArcViewShape()
shared root, mvw, rundir

if rundir = null then do
	datetime = GetDateAndTime()
	thisyear = right(datetime, 4)
	thismon = right(left(datetime,7),3)
	thisday = right(left(datetime,10),2)
	runname = "Run_"+thismon+thisday+thisyear
	rundir = root.mod+"\\Outputs\\"+runname+"\\"
end

dirinfo = GetDirectoryInfo(left(rundir,len(rundir)-1), "Directory")
if dirinfo = null then status = RunProgram("cmd /c mkdir " + rundir,)
dirinfo = GetDirectoryInfo(rundir+"shp", "Directory")
if dirinfo = null then status = RunProgram("cmd /c mkdir " +rundir+"shp",)
	
mvw.taz = RunMacro("AddLayer", mvw.tazfile, "Area")
tazpath = SplitPath(mvw.tazfile)
csvtaz = rundir+"shp\\"+tazpath[3]+".csv"
shptaz = rundir+"shp\\"+tazpath[3]+".shp"
shptazdbf = rundir+"shp\\"+tazpath[3]+".dbf"

//TAZ export
{taznms, tazspcs} = GetFields(mvw.taz, "All")
SetMapProjection(null, "utm", {"zone=19", "ellps=GRS80"})
{projname, projparams} = GetMapProjection()
ExportArcViewShape(mvw.taz, shptaz, {{"Fields", taznms},{"Projection", projname, projparams}})
tazshpvw = OpenTable("TAZShp", "DBASE", {shptazdbf, })
{tazshpnms, tazshpspcs} = GetFields(tazshpvw, "All")
CloseView(tazshpvw)
tazcsv = CreateTable("shpexport", csvtaz, "CSV", 
			{{"TC_field_name"     , "String", 20, null, "No"},
			 {"TC_type"           , "String", 20, null, "No"},
			 {"TC_width"          , "String", 20, null, "No"},
			 {"TC_decimal"        , "String", 20, null, "No"},
			 {"ESRI_type"         , "String", 20, null, "No"},
			 {"ESRI_precision"    , "String", 20, null, "No"},
			 {"ESRI_scale"        , "String", 20, null, "No"},
			 {"ESRI_length"       , "String", 20, null, "No"},
			 {"ESRI_alias"        , "String", 20, null, "No"},
			 {"ESRI_modfield_name", "String", 20, null, "No"}})

AddRecord(tazcsv, {
		{"TC_field_name"     ,"TC_field_name"     },
		{"TC_type"           ,"TC_type"           },
		{"TC_width"          ,"TC_width"          },
		{"TC_decimal"        ,"TC_decimal"        },
		{"ESRI_type"         ,"ESRI_type"         },
		{"ESRI_precision"    ,"ESRI_precision"    },
		{"ESRI_scale"        ,"ESRI_scale"        },
		{"ESRI_length"       ,"ESRI_length"       },
		{"ESRI_alias"        ,"ESRI_alias"        },
		{"ESRI_modfield_name","ESRI_modfield_name" }})
		
for i = 1 to tazspcs.length do
	tazinfo = GetFieldInfo(tazspcs[i])
	etype = if tazinfo[1] = "Integer" then "LONG" 
		else if tazinfo[1] = "Real" then "DOUBLE" 
		else if tazinfo[1] = "String" then "TEXT"
	AddRecord(tazcsv, {
		{"TC_field_name" , tazshpnms[i]}                                    ,
		{"TC_type"       , tazinfo[1]}                                      ,
		{"TC_width"      , i2s(tazinfo[2])}                                 ,
		{"TC_decimal"    , if etype = "DOUBLE" then i2s(tazinfo[3]) else ""},
		{"ESRI_type"     , etype}                                           ,
		{"ESRI_precision", if etype <> "TEXT" then i2s(tazinfo[2]) else ""} ,
		{"ESRI_scale"    , if etype = "DOUBLE" then i2s(tazinfo[3]) else ""},
		{"ESRI_length"   , if etype = "TEXT" then i2s(tazinfo[2]) else ""}  ,
		{"ESRI_alias"    , taznms[i]}                                       ,
		{"ESRI_modfield_name", tazshpnms[i]}})
end

//Line Export, shp.dbf cannot have more than 83 columns
mvw.line = RunMacro("AddLayer", mvw.linefile, "Line")	
linepath = SplitPath(mvw.linefile)
csvline = rundir+"shp\\"+linepath[3]+".csv"
shpline = rundir+"shp\\"+linepath[3]+".shp"
shplinedbf = rundir+"shp\\"+linepath[3]+".dbf"

{linenms, linespcs} = GetFields(mvw.line, "All")
ExportArcViewShape(mvw.line, shpline, {{"Fields", linenms},{"Projection", projname, projparams}})
lineshpvw = OpenTable("LineShp", "DBASE", {shplinedbf, })
{lineshpnms, lineshpspcs} = GetFields(lineshpvw, "All")
CloseView(lineshpvw)

	linecsv = CreateTable("shpexport", csvline, "CSV", 
			{{"TC_field_name"     , "String", 20, null, "No"},
			 {"TC_type"           , "String", 20, null, "No"},
			 {"TC_width"          , "String", 20, null, "No"},
			 {"TC_decimal"        , "String", 20, null, "No"},
			 {"ESRI_type"         , "String", 20, null, "No"},
			 {"ESRI_precision"    , "String", 20, null, "No"},
			 {"ESRI_scale"        , "String", 20, null, "No"},
			 {"ESRI_length"       , "String", 20, null, "No"},
			 {"ESRI_alias"        , "String", 20, null, "No"},
			 {"ESRI_modfield_name", "String", 20, null, "No"}})

AddRecord(linecsv, {
		{"TC_field_name"     ,"TC_field_name"     },
		{"TC_type"           ,"TC_type"           },
		{"TC_width"          ,"TC_width"          },
		{"TC_decimal"        ,"TC_decimal"        },
		{"ESRI_type"         ,"ESRI_type"         },
		{"ESRI_precision"    ,"ESRI_precision"    },
		{"ESRI_scale"        ,"ESRI_scale"        },
		{"ESRI_length"       ,"ESRI_length"       },
		{"ESRI_alias"        ,"ESRI_alias"        },
		{"ESRI_modfield_name","ESRI_modfield_name" }})
		
for i = 1 to linespcs.length do
	lineinfo = GetFieldInfo(linespcs[i])
	etype = if lineinfo[1] = "Integer" then "LONG" 
		else if lineinfo[1] = "Real" then "DOUBLE" 
		else if lineinfo[1] = "String" then "TEXT"
	AddRecord(linecsv, {
		{"TC_field_name" , lineshpnms[i]}                                    ,
		{"TC_type"       , lineinfo[1]}                                      ,
		{"TC_width"      , i2s(lineinfo[2])}                                 ,
		{"TC_decimal"    , if etype = "DOUBLE" then i2s(lineinfo[3]) else ""},
		{"ESRI_type"     , etype}                                            ,
		{"ESRI_precision", if etype <> "TEXT" then i2s(lineinfo[2]) else ""} ,
		{"ESRI_scale"    , if etype = "DOUBLE" then i2s(lineinfo[3]) else ""},
		{"ESRI_length"   , if etype = "TEXT" then i2s(lineinfo[2]) else ""}  ,
		{"ESRI_alias"    , linenms[i]}                                       ,
		{"ESRI_modfield_name", lineshpnms[i]}})
end

CloseView(tazcsv)
CloseView(linecsv)
layers = GetLayerNames()
for i=1 to layers.length do if layers[i] = mvw.line then DropLayer(null, mvw.line) end
for i=1 to layers.length do if layers[i] = mvw.taz then DropLayer(null, mvw.taz) end
layers = GetLayerNames()
if layers = null then CloseMap(GetMap())
ShowMessage("shp Export Complete!")
endMacro


Macro "Parent2Client"
shared root
dirinfo = GetDirectoryInfo("C:\\Temp", "Directory")
if dirinfo = null then status = RunProgram("cmd /c mkdir " + "C:\\Temp ",)
	
if root.mod = null then do on escape goto endhere1 root.mod = ChooseDirectory("Choose the Client TransCAD Directory", ) endhere1: end
if root.par = null then do on escape goto endhere2 root.par = ChooseDirectory("Choose the Parent TransCAD Directory", ) endhere2: end

paraddin = root.par +"\\Add Ins"
parinput = root.par +"\\Inputs"
parmodel = root.par +"\\Model"
parcal = root.par +"\\Outputs\\CalRep"

pathaddin = root.mod+"\\Add Ins"
pathinput = root.mod+"\\Inputs"
pathmodel = root.mod+"\\Model"
pathcal = root.mod+"\\Outputs\\CalRep"

if root.mod = null or root.par = null then Return()
status = RunProgram("cmd /c robocopy "+root.par+" "+root.mod+" /is /R:0 /W:0 /NS /NC /NDL /NJH /TEE /log:C:\\Temp\\rcopy00.txt",)
status = RunProgram("cmd /c robocopy "+paraddin+" "+pathaddin+" /s /e /is /R:0 /W:0 /NS /NC /NDL /NJH /TEE /log:C:\\Temp\\rcopy01.txt",)
status = RunProgram("cmd /c robocopy "+parinput+" "+pathinput+" /s /e /is /R:0 /W:0 /NS /NC /NDL /NJH /TEE /log:C:\\Temp\\rcopy02.txt",)
status = RunProgram("cmd /c robocopy "+parmodel+" "+pathmodel+" /s /e /is /R:0 /W:0 /NS /NC /NDL /NJH /TEE /log:C:\\Temp\\rcopy03.txt",)
status = RunProgram("cmd /c robocopy "+parcal+" "+pathcal+" /s /e /is /R:0 /W:0 /NS /NC /NDL /NJH /TEE /log:C:\\Temp\\rcopy04.txt",)


//check txt for errors
ptr00 = OpenFile("C:\\Temp\\rcopy00.txt", "r")
line00 = ReadArray(ptr00)
word00 = Word(line00[line00.length-8], 6)
if s2i(word00) > 0 then throw("Error copying "+root.par)

ptr01 = OpenFile("C:\\Temp\\rcopy01.txt", "r")
line01 = ReadArray(ptr01)
word01 = Word(line01[line01.length-8], 6)
if s2i(word01) > 0 then throw("Error copying "+paraddin)

ptr02 = OpenFile("C:\\Temp\\rcopy02.txt", "r")
line02 = ReadArray(ptr02)
word02 = Word(line02[line02.length-8], 1)
if s2i(word02) <> modelnum.length then throw("Error copying "+parinput)

ptr03 = OpenFile("C:\\Temp\\rcopy03.txt", "r")
line03 = ReadArray(ptr03)
word03 = Word(line03[line03.length-8], 1)
if s2i(word03) <> modelnum.length then throw("Error copying "+parmodel)

ptr04 = OpenFile("C:\\Temp\\rcopy04.txt", "r")
line04 = ReadArray(ptr04)
word04 = Word(line04[line04.length-8], 1)
if s2i(word04) <> modelnum.length then throw("Error copying "+parcal)

ShowMessage("Parent -> Client Copied - Please Reload Dialog")
Return()
endMacro

Macro "Client2Parent"
shared root, runname
dirinfo = GetDirectoryInfo("C:\\Temp", "Directory")
if dirinfo = null then status = RunProgram("cmd /c mkdir " + "C:\\Temp ",)
	
if root.mod = null then do on escape goto endhere1 root.mod = ChooseDirectory("Choose the Client TransCAD Directory", ) endhere1: end
if root.par = null then do on escape goto endhere2 root.par = ChooseDirectory("Choose the Parent TransCAD Directory", ) endhere2: end

paroutput = root.par +"\\Outputs\\"+runname
pathoutput = root.mod+"\\Outputs\\"+runname

if root.mod = null or root.par = null then Return()
status = RunProgram("cmd /c robocopy "+pathoutput+" "+paroutput+" /s /e /is /R:0 /W:0 /MOVE /NS /NC /NDL /NJH /TEE /log:C:\\Temp\\rcopy05.txt",)

//check txt for errors
ptr05 = OpenFile("C:\\Temp\\rcopy05.txt", "r")
line05 = ReadArray(ptr05)
word05 = Word(line05[line05.length-8], 6)
if s2i(word05) > 0 then throw("Error moving "+root.par+"\\Outputs\\"+runname)

ShowMessage("Client Output -> Parent Successful!")
endMacro

Macro "NHPN2HPMS" (F_SYS, URB_CODE)
//Converts National Highway Planning Network variables (HPMS 2010 FC & Urban Code) into HPMS 2000 Functional Classes

//https://www.fhwa.dot.gov/policyinformation/hpms/fieldmanual/HPMS_2014.pdf

/*
HPMS 2000 FUNCCLASS
RURAL
1 = Principal Arterial-Interstate
2 = Principal Arterial-Other
6 = Minor Arterial
7 = Major Collector
8 = Minor Collector
9 = Local
URBAN
11 = Principal Arterial-Interstate
12 = Principal Arterial-Other ; Freeways & Expressways
14 = Principal Arterial-Other
16 = Minor Arterial
17 = Collector
19 = Local
*/

/*
HPMS 2010

1 = Interstate
2 = Principal Arterial-Other ; Freeways & Expressways
3 = Principal Arterial-Other
4 = Minor Arterial
5 = Major Collector
6 = Minor Collector
7 = Local
*/

HPMS2k_FC = 
if F_SYS = 1 and URB_CODE = 99999 then 1
else if F_SYS = 1 and URB_CODE < 99999 then 11

else if (F_SYS = 2 or F_SYS = 3) and URB_CODE = 99999 then 2
else if F_SYS = 2 and URB_CODE < 99999 then 12
else if F_SYS = 3 and URB_CODE < 99999 then 14

else if F_SYS = 4 and URB_CODE = 99999 then 6
else if F_SYS = 4 and URB_CODE < 99999 then 16

else if F_SYS = 5 and URB_CODE = 99999 then 7
else if (F_SYS = 5 or F_SYS = 6) and URB_CODE < 99999 then 17
else if F_SYS = 6 and URB_CODE = 99999 then 8

else if F_SYS = 7 and URB_CODE = 99999 then 9
else if F_SYS = 7 and URB_CODE < 99999 then 19
else 0

Return(HPMS2k_FC)
endMacro


//Route File System
Macro "UpdateRTS" (rtsfile, linefile) 
//Copies TransCAD rts to linefile folder
//Configures .rts to link to linefile

//compatibility issues (TC7) when scenario network is not identical to master network?

//Hardcoded
/*
hardcode = null
if hardcode <> null then do
	rtsfile = "C:\\Model\\1_Model-Files\\1_MasterNet\\Transit\\Base\\TransitRouteSystem.rts"
	//rtsfile = "C:\\Model\\1_Model-Files\\1_MasterNet\\Transit\\EC\\TransitRouteSystem.rts"
	//rtsfile = "C:\\Model\\1_Model-Files\\1_MasterNet\\Transit\\FY\\TransitRouteSystem.rts"
	linefile = "C:\\Model\\1_Model-Files\\1_MasterNet\\Chatt_Master_081917.dbd"
	arr = GetDBLayers(linefile)
	linevw = arr[2]
	ModifyRouteSystem(rtsfile, {{"Geography", linefile, linevw}})
end
*/

arr = GetDBLayers(linefile)
linevw = arr[2]
lineparts = Splitpath(linefile)
linedir = lineparts[1] + lineparts[2]

//Move rts to linefile path
rsinfo = GetRouteSystemFiles(rtsfile)
rtsparts = SplitPath(rtsfile)
rspath = rtsparts[1] + rtsparts[2]
//ShowArray(rsinfo)

for i=1 to rsinfo[1].length do
	oldf = JoinStrings({rspath,rsinfo[1][i]},"")
	outf = JoinStrings({linedir,rsinfo[1][i]},"")
	if oldf <> outf then CopyFile(oldf, outf)
end

//Modify Route System
newrtsfile = linedir + rtsparts[3] + rtsparts[4]	//new rts file location
ModifyRouteSystem(newrtsfile, {{"Geography", linefile, linevw}})
Return(newrtsfile)
endMacro


//Mapping
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

Macro "Complete"
map_name = GetMap()
SetMapRedraw(map_name, "True")
SetSelectDisplay("True")

ShowMessage("Complete!")
endMacro

Macro "CloseAll"
    // close all files in workspace
    map_arr=GetMaps()
    if ArrayLength(map_arr)>0 then do
        open_maps=ArrayLength(map_arr[1])
        for mm=1 to open_maps do
            CloseMap(map_arr[1][mm])
        end
    end

    On NotFound goto no_more_eds
    still_more_eds:
        CloseEditor()
        goto still_more_eds

    no_more_eds:
        On NotFound default

    view_arr=GetViews()
    if ArrayLength(view_arr)>0 then do
        open_views=ArrayLength(view_arr[1])
        for vv = 1 to open_views do
            CloseView(view_arr[1][vv])
        end
    end
endMacro

//Old DropMap
Macro "DropMap_v0"
on escape, notfound, error do
		on escape default
		on NotFound default
		on error default
		ShowMessage("Error with DropMap")
		goto skip
end

	shared mvw
	maparr = GetMaps()
	if maparr = null then goto skip
	
	for map = 1 to maparr[1].length do
		SetMap(maparr[1][map])
		layers = GetLayerNames()
		for i=1 to layers.length do if layers[i] = mvw.rts then DropLayer(null, mvw.rts) end
		for i=1 to layers.length do if layers[i] = mvw.line then DropLayer(null, mvw.line) end
		for i=1 to layers.length do if layers[i] = mvw.taz then DropLayer(null, mvw.taz) end
		layers = GetLayerNames()
		if layers = null then CloseMap(GetMap())
	end

	viewnames = GetViews()
	if viewnames = null then goto skip
	for i=1 to viewnames[1].length do CloseView(viewnames[1][i]) end
	skip:
endMacro

Macro "Intersection_Density" (tazfile, linefile, buffer)
	shared mvw
	//Input: taz .dbd, line+node .dbd, buffer (in miles)
	//Output: TAZ Field [IntDens] in Intersections per Square Mile
	//Intersections defined as nodes with 3+ links
	
	if tazfile = null then do
		buffer = 0.25 //(uses TC default, typically miles)
		tazfile = "C:\\Path\\tazlayer.dbd"
		linefile = "C:\\Path\\linelayer.dbd"
	end
	
	mvw.taz = RunMacro("AddLayer", tazfile, "Area")
	mvw.line = RunMacro("AddLayer", linefile, "Line")	
	mvw.node = GetNodeLayer(mvw.line)
	
     from_fld = CreateNodeField(mvw.line, "FROM_ID", mvw.node+".ID", "From", )
     to_fld = CreateNodeField(mvw.line, "TO_ID", mvw.node+".ID", "To", )
     
	 // Create fields on intersection layer
	 RunMacro("addfields", mvw.taz, {"IntDens"}, {"r"})
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
     
	 // Aggregates nodes to TAZ using a .25 buffer; TAZ "IntDens" = Sum all LEGS
     ColumnAggregate(mvw.taz+"|", buffer, mvw.node+"|", {{"IntDens", "Sum", "LEGS", }}, null)
    
	// Computes Intersection Density = Legs/Area (Square Mile)
     rec = GetFirstRecord(mvw.taz + "|", null)
     while rec <> null do
          mvw.taz.IntDens = mvw.taz.IntDens / mvw.taz.Area
          rec = GetNextRecord(mvw.taz + "|", null, null)
     end

endMacro


//Matrix
Macro "CheckMatrixCore" (mtx, thiscore, rowindex, colindex)
     coreexists = 0
     corenames = GetMatrixCoreNames(mtx)
     for i = 1 to corenames.length do
          if lower(corenames[i]) = lower(thiscore) then do 
		  coreexists = 1
		  goto jump
		  end
     end
	 
     if coreexists <> 1 then AddMatrixCore(mtx, thiscore)
	 
	 jump:
	 mc = CreateMatrixCurrency(mtx, thiscore, rowindex, colindex, null)
	 Return(mc)
endMacro

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

Macro "ForceMatrixIndex" (mtx, rowidx, colidx, view, qry, newid)
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
		newidx = CreateMatrixIndex(rowidx, mtx, "Both", view+"|"+rowidx, "ID", newid, {{"Allow non-matrix entries", "True"}})
		Return(newidx)
	end
endMacro

Macro "ExportMatrixCores" (mtx)
//mtx = "E:\\TSTM_V3\\Freight_Obs\\IE.mtx"
mtx = "C:\\TSTM_V3\\Data\\Freight_Obs\\EI.mtx"

path = SplitPath(mtx)
outfolder = path[1] + path[2]

mat = OpenMatrix(mtx, "Auto")
matrix_cores = GetMatrixCoreNames(mat)

for i=1 to matrix_cores.length do
	mc = CreateMatrixCurrency(mat, matrix_cores[i], null, null, null)
	mathand = CopyMatrix(mc, {
		{"File Name", outfolder + matrix_cores[i] +".mtx"},
		{"Label", matrix_cores[i]},
		{"Cores", {i}}
	 })
end
endMacro

Macro "MatrixSums" (mtx, logfile, type)
 mtxvw = OpenMatrix(mtx, "Auto")
 matrix_cores = GetMatrixCoreNames(mtxvw)
 matstats = MatrixStatistics(mtxvw, )
 
 SumCore1 = matstats[1][2].Sum
 if type = "Total" then do
	SumCore2 = matstats[2][2].Sum
	SumCore3 = matstats[3][2].Sum
	SumCore4 = matstats[4][2].Sum
	SumCore5 = matstats[5][2].Sum
	SumCore6 = matstats[6][2].Sum
end

ptr = OpenFile(logfile, "a")
ar_log = { r2s(SumCore1), }
if type = "Total" then ar_log = { r2s(SumCore1) +" \t " + r2s(SumCore2) +" \t "+ r2s(SumCore3)+" \t "+ r2s(SumCore4)+" \t "+ r2s(SumCore5)+" \t "+ r2s(SumCore6), }
WriteArray(ptr, ar_log)
CloseFile(ptr) 
endMacro

Macro "CommonValueCore" (mtxfile, corename, tazvw, field, nodevw)
	SetView(tazvw)
	vec = GetDataVector(tazvw+"|", field, )
	svec = SortVector(vec, {{"Unique", "True"}})
	sarr = V2A(svec)
	
	//Makes assumption on skim index: TAZID, Origin, Destination
	//Assumes tazvw field "NodeID" corresp
	mat = OpenMatrix(mtxfile,)
	
	for i=1 to sarr.length do
		sval = if TypeOf(sarr[i]) = "string" then sarr[i]
			else if TypeOf(sarr[i]) = "int" then i2s(sarr[i])
			else if TypeOf(sarr[i]) = "double" then r2s(sarr[i])
			else skip
		RunMacro("CheckMatrixIndex", mat, "CVtemp", "CVtemp", tazvw, "Select * where "+field+" = "+sval, "TAZID", "NodeID")
		mccv = RunMacro("CheckMatrixCore", mat, corename, "CVtemp", "CVtemp")
		mccv := 1
		SetMatrixIndex(mat, "Origin", "Destination")
		DeleteMatrixIndex(mat, "CVtemp")
	skip:
	end

endMacro

//String
Macro "str2fld" (str)
parts = ParseString(str, " ")
if parts.length > 1 then outstr = JoinStrings({"[",str,"]"},"") else outstr = str
Return(outstr)
endMacro


//Balance
Macro "BalanceAvg" (file, view, arrp, arra)
    RunMacro("TCB Init")
    Opts = null
    Opts.Input.[Data View Set] = {file, view} //{input_path + "Empty_Prods-Attrs.bin", "Empty_Prods-Attrs"}
    Opts.Field.[Vector 1] = arrp //{"HBW_P"}
    Opts.Field.[Vector 2] = arra //{"HBW_A"}
    Opts.Global.[Holding Method] = {"Weighted Sum"}
    Opts.Global.[Percent Weight] = {50}
		//if writing to output table:
	//Opts.Global.[Store Type] = "Real"
    //Opts.Output.[Output Table] = output_path + "Balance.bin"
    ok = RunMacro("TCB Run Procedure", "Balance", Opts, &Ret)
    if !ok then Return( RunMacro("TCB Closing", ok, True ) )
endMacro


//Custom
Macro "LoadParams" (paramsfile, filetype)
paramvw = OpenTable("Parameters", "DBASE", {paramsfile, })
rec = GetFirstRecord(paramvw+"|", null)
params = {}

if filetype = null then do
	while rec <> null do
		key = paramvw.KEY
		params.(key).value = paramvw.VALUE
		params.(key).minimum = paramvw.MIN
		params.(key).maximum = paramvw.MAX
		params.(key).file = paramsfile
		//params.(key).tstat = paramvw.DOTSTAT
		//params.(key).tagainst = paramvw.TAGAINST
		
		rec = GetNextRecord(paramvw+"|", null, null)	
	end
	CloseView(paramvw)
end

if filetype = "mdl" then do
	while rec <> null do
		key = string(paramvw.ALT)+"_"+paramvw.SPEC

		{coeff, asc, theta} = {paramvw.COEFF, paramvw.ASC, paramvw.THETA}
		val = if paramvw.COEFF <> null then coeff
				else if paramvw.ASC <> null then asc
				else if paramvw.THETA <> null then theta
		valtype = if paramvw.COEFF <> null then "COEFF" 
				else if paramvw.ASC <> null then "ASC" 
				else if paramvw.THETA <> null then "THETA"

		params.(key).value   = val
		params.(key).valtype = valtype
		params.(key).file    = paramsfile
		//params.(key).tstat = paramvw.DOTSTAT
		//params.(key).tagainst = paramvw.TAGAINST
		
		rec = GetNextRecord(paramvw+"|", null, null)	
	end
	CloseView(paramvw)
end	

if filetype = "freight" then do
	while rec <> null do
		key = paramvw.Commodity
		params.(key).a = paramvw.A
		params.(key).b = paramvw.B
		params.(key).c = paramvw.C
		params.(key).file = paramsfile
		
		rec = GetNextRecord(paramvw+"|", null, null)	
	end
	CloseView(paramvw)
end	

Return(params)
endMacro

Macro "tbl2mdl" (mdlopt, mtxopt)
{tablefile, mdlfile, sourcetype, zonalvw, zonalid} = mdlopt
{mtxvw1,mtxrow1,mtxcol1,mtxvw2,mtxrow2,mtxcol2} = mtxopt

//if zonalid = null then zonalid = GetIDField(zonalvw)
thispath = SplitPath(tablefile)
mdllabel = thispath[3]

tablevw = OpenTable("Parameters", "DBASE", {tablefile, })
SetView(tablevw)
nalts = SelectByQuery("alts", "Several", "Select * where TYPE = 'Alt'",)
nbetas = SelectByQuery("betas", "Several", "Select * where TYPE <> 'Alt'",)
{ALT, ALTNAME, ASC, PARENT, THETA} = GetDataVectors(tablevw+"|alts", {"ALT", "SPEC", "ASC", "PARENT", "THETA"}, )
{ALTNUM, SPEC, COEFF, TYPE} = GetDataVectors(tablevw+"|betas", {"ALT", "SPEC", "COEFF", "TYPE"}, )
CloseView(tablevw)

//Header & Field Names
fptr = OpenFile(mdlfile, "w")
WriteLine(fptr, 'model label="'+mdllabel+'" version=1.5')
for i=1 to nbetas do Writeline(fptr, '  field name='+string(ALTNUM[i])+"_"+SPEC[i]) end

//Source Name
if zonalvw <> null then WriteLine(fptr, '  source name=Data1 type='+sourcetype+' primary=True view="' + zonalvw + '" idfield=' +zonalid)
if mtxvw1 <> null then WriteLine(fptr, '  source name=Matrix1 type=Matrix primary=True file=' + mtxvw1 + ' filelabel=tazmat rowindex="'+mtxrow1+'" colindex="'+mtxcol1+'"')
if mtxvw2 <> null then WriteLine(fptr, '  source name=Matrix2 type=Matrix file=' + mtxvw2 + ' filelabel="Shortest Path" rowindex="'+mtxrow2+'" colindex="'+mtxcol2+'"')
WriteLine(fptr, '  segment name=*')

//Betas
for i=1 to nbetas do Writeline(fptr, '    term name='+string(ALTNUM[i])+"_"+SPEC[i]+' coefficient=' + string(COEFF[i])) end

//Alts & Specs
for n=1 to nalts do
	if THETA[n] <> null and PARENT[n] <> null then WriteLine(fptr, '    alternative name=' + ALTNAME[n] + ' parent=' +PARENT[n] + ' theta='+string(THETA[n]))
	else if THETA[n] <> null and PARENT[n] = null then WriteLine(fptr, '    alternative name=' + ALTNAME[n] + ' theta='+string(THETA[n]))
	else if PARENT[n] <> null and ASC[n] <> null then WriteLine(fptr, '    alternative name=' + ALTNAME[n] + ' parent=' +PARENT[n]+ ' asc='+string(ASC[n]))
	else if PARENT[n] <> null and ASC[n] = null then WriteLine(fptr, '    alternative name=' + ALTNAME[n] + ' parent=' +PARENT[n])
	else if PARENT[n] = null and ASC[n] = null then WriteLine(fptr, '    alternative name=' + ALTNAME[n])
	else WriteLine(fptr, '    alternative name=' + ALTNAME[n] + ' asc='+string(ASC[n]))
	
	for i=1 to nbetas do 
		if ALTNUM[i] = n and TYPE[i] = "Matrix1" then WriteLine(fptr, '      data source=Matrix1 spec=' + SPEC[i] + ' term=' + string(ALTNUM[i])+"_"+SPEC[i] + ' type=Matrix')
		else if ALTNUM[i] = n and TYPE[i] = "Matrix2" then WriteLine(fptr, '      data source=Matrix2 spec=' + SPEC[i] + ' term=' + string(ALTNUM[i])+"_"+SPEC[i] + ' type=Matrix')
		else if ALTNUM[i] = n then WriteLine(fptr, '      data source=Data1 spec=' + SPEC[i] + ' term=' + string(ALTNUM[i])+"_"+SPEC[i] + ' type=' + TYPE[i])
	end
end

endMacro

Macro "dat2bin" (datfile, binfile, type)
//Input: tab-delimited .dat
//Output: TransCAD .bin & viewname
/*
thisdat = "C:\\Temp\\test_input.dat"
thisbin = "C:\\Temp\\test_output.bin"
thisbin_view = RunMacro("dat2bin", thisdat, thisbin, "tab")
v = GetDataVector(thisbin_view, ...
*/
tempfile = GetTempFileName(".csv")
if GetFileInfo(datfile)	= null then throw("Error: "+ datfile +" does not exist")

if type = null or type = "tab" then do
	//F (single file/directory), R (overwrite read only), Y (no prompts)
	status = RunProgram("cmd /c ECHO F|xcopy "+datfile+" "+tempfile+" /R /Y",)
	
	csvvw = OpenTable("csvvw", "CSV", {tempfile, null})
	binvw = ExportView(csvvw+"|", "FFB", binfile, null, null)
	Return(binvw)
end

//Not working yet
if type = "space" then do
	datptr = OpenFile(datfile, "r")
	arr = ReadArray(datptr)

	fptr = OpenFile(csvfile, "w")
	WriteArraySeparated(fptr, arr, " ", '\"')
	
	csvvw = OpenTable("csvvw", "CSV", {csvfile, null})
	binvw = ExportView(csvvw+"|", "FFB", binfile, null, null)
	Return(binvw)
end
endMacro

Macro "csv2bin" (csvfile, binfile)
	csvvw = OpenTable("csvvw", "CSV", {csvfile, null})
	binvw = ExportView(csvvw+"|", "FFB", binfile, null, null)
	Return(binvw)
endMacro

Macro "RenameMDL" (file, replace, outstr)
	// Update .mdl files for TAZ view name
	mdl = OpenFile(file, "r")
	readarr = ReadSizedArray(mdl, 2500)
	Closefile(mdl)
	
	excl = {null}	//exclude nulls
	linesarray = ArrayExclude(readarr, excl)
	
	for i = 1 to linesarray.length do
		s = Substitute(linesarray[i], replace, outstr, 1)
		if s <> linesarray[i] then goto Quit
	end

	Return()
	
	Quit:
	linesarray[i] = s
	mdl = OpenFile(file, "w")
	WriteArray(mdl, linesarray)
	CloseFile(mdl)
endMacro

Macro "NestedLogitApp" (in_value)
	invw        = in_value[1]
	infilename  = in_value[2]
	inid        = in_value[3]
	modfilename = in_value[4]
	outfilename = in_value[5]
	tazvw       = in_value[6]
     
     dataset = {infilename, invw} 
     if invw = tazvw then dataset = {infilename+ "|"+ invw, invw}
	 
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

Macro "NCDOT_VMT_Growth"
//Generate data for Table 3-2 in SPOT Program Management Report 05-18-16
//VMT Growth by County & Class [Freeway, Arterial, Collector, Local]

//Unknown Counties: {"241","281","291","550","590","640","710","740","800","810"}
cntynum  = {"001"     ,"003"      ,"005"      ,"007"  ,"009" ,"011"  ,"013"     ,"015"   ,"017"   ,"019"      ,"021"     ,"023"  ,"025"     ,"027"     ,"029"   ,"031"     ,"033"    ,"035"    ,"037"    ,"039"     ,"041"   ,"043" ,"045"      ,"047"     ,"049"   ,"051"       ,"053"      ,"055" ,"057"     ,"059"  ,"061"   ,"063"   ,"065"      ,"067"    ,"069"     ,"071"   ,"073"  ,"075"   ,"077"      ,"079"   ,"081"     ,"083"    ,"085"    ,"087"    ,"089"      ,"091"     ,"093" ,"095" ,"097"    ,"099"    ,"101"     ,"103"  ,"105","107"   ,"109"    ,"111"     ,"113"  ,"115"    ,"117"   ,"119"        ,"121"     ,"123"       ,"125"  ,"127" ,"129"        ,"131"        ,"133"   ,"135"   ,"137"    ,"139"       ,"141"   ,"143"       ,"145"   ,"147" ,"149" ,"151"     ,"153"     ,"155"    ,"157"       ,"159"  ,"161"       ,"163"    ,"165"     ,"167"   ,"169"   ,"171"  ,"173"  ,"175"         ,"177"    ,"179"  ,"181"  ,"183" ,"185"   ,"187"       ,"189"    ,"191"  ,"193"   ,"195"   ,"197"   ,"199"}
cntyname = {"Alamance","Alexander","Alleghany","Anson","Ashe","Avery","Beaufort","Bertie","Bladen","Brunswick","Buncombe","Burke","Cabarrus","Caldwell","Camden","Carteret","Caswell","Catawba","Chatham","Cherokee","Chowan","Clay","Cleveland","Columbus","Craven","Cumberland","Currituck","Dare","Davidson","Davie","Duplin","Durham","Edgecombe","Forsyth","Franklin","Gaston","Gates","Graham","Granville","Greene","Guilford","Halifax","Harnett","Haywood","Henderson","Hertford","Hoke","Hyde","Iredell","Jackson","Johnston","Jones","Lee","Lenoir","Lincoln","McDowell","Macon","Madison","Martin","Mecklenburg","Mitchell","Montgomery","Moore","Nash","New_Hanover","Northampton","Onslow","Orange","Pamlico","Pasquotank","Pender","Perquimans","Person","Pitt","Polk","Randolph","Richmond","Robeson","Rockingham","Rowan","Rutherford","Sampson","Scotland","Stanly","Stokes","Surry","Swain","Transylvania","Tyrrell","Union","Vance","Wake","Warren","Washington","Watauga","Wayne","Wilkes","Wilson","Yadkin","Yancey"}

//FC listed for reference
//Connectors: {98, 99}
fcnum  = {1        , 2        , 3         , 4         , 5          , 6          , 7}
fcname = {"Freeway", "Freeway", "Arterial", "Arterial", "Collector", "Collector", "Local"}

thisvw = GetView()
growthtxt = "E:\\Project\\NCDOT\\NCSTM_Gen2.3\\Model\\scenarios\\P4_Growth_Network\\vmt_growth.txt"
fptr = OpenFile(growthtxt, "w")
WriteLine(fptr, "County Freeway Arterial Collector Local")

//Calculate VMT
RunMacro("addfields", thisvw, {"VMT"}, {"r"})
vmtx = CreateExpression(thisvw, "vmtx", "Length * (AB_0FlowDly + BA_0FlowDly)", )
SetRecordsValues(thisvw+"|", {{"VMT"}, null}, "Formula", {vmtx},)

for i = 1 to cntnum.length do
	fsel = SelectByQuery("fwy", "Several", "Select * where County = "+cntynum+" and (NCSTM_FuncCl = 1 or NCSTM_FuncCl = 2)",)
	if fsel = 0 then fwyvmt = 0.0
	if fsel > 0 then do
		{vmtv} = GetDataVectors(thisvw+"|fwy", {"VMT"}, )
		fwyvmt = VectorStatistic(vmtv , "Sum" , null)
	end
	
	asel = SelectByQuery("art", "Several", "Select * where County = "+cntynum+" and (NCSTM_FuncCl = 3 or NCSTM_FuncCl = 4)",)
	if asel = 0 then artvmt = 0.0
	if asel > 0 then do
		{vmtv} = GetDataVectors(thisvw+"|art", {"VMT"}, )
		artvmt = VectorStatistic(vmtv , "Sum" , null)
	end
	
	csel = SelectByQuery("coll", "Several", "Select * where County = "+cntynum+" and (NCSTM_FuncCl = 5 or NCSTM_FuncCl = 6)",)
	if csel = 0 then collvmt = 0.0
	if csel > 0 then do
		{vmtv} = GetDataVectors(thisvw+"|coll", {"VMT"}, )
		collvmt = VectorStatistic(vmtv , "Sum" , null)
	end
	
	lsel = SelectByQuery("local", "Several", "Select * where County = "+cntynum+" and (NCSTM_FuncCl = 7)",)
	if lsel = 0 then locvmt = 0.0
	if lsel > 0 then do
		{vmtv} = GetDataVectors(thisvw+"|local", {"VMT"}, )
		locvmt = VectorStatistic(vmtv , "Sum" , null)
	end

	WriteLine(fptr, cntyname+" "+r2s(fwyvmt)+" "+r2s(artvmt)+" "+r2s(collvmt)+" "+r2s(locvmt))
end

ShowMessage("VMT Calc Complete")
endMacro

//Debugging
Macro "debug00"
//path = "C:\\TSTM_V3\\Data\\Freight_Obs\\EI_Obs\\"
//path = "C:\\TSTM_V3\\Data\\Freight_Obs\\IE_Obs\\"
path = "C:\\TSTM_V3\\Data\\Freight_Obs\\II_Obs\\"
rowidx = "TS_Centroid"

thisvw = GetView()
//corresp = path + "Freight_Corresp.bin"

SetView(thisvw)
set = SelectByQuery(rowidx, "Several", "Select * where "+rowidx+" <> null", )

flds = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36","37","38","39","40","41","501","502","503"}

for i=1 to flds.length do
	mtxfile = path + "Commodity " + flds[i] +".mtx"
	thismtx = OpenMatrix(mtxfile, "Auto")
	
	newidx = CreateMatrixIndex(rowidx, thismtx, "Both", thisvw+"|"+rowidx, "HADI_ID", rowidx, {{"Allow non-matrix entries", "True"}})
end

ShowMessage("Index Done!")
endMacro

Macro "debug01"
type = "Total"
scen = "Base"

EIflds = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36","37","38","39","40","41","43","503"}
IEflds = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36","37","38","39","40","41","43","503"}
IIFlds = {"1","2","3","4","5","6","7","8","9","10","11","12","13",     "15","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36","37","38","39","40","41","43","503"}
	
if type = "EI" then do
	path = "E:\\TSTM_V3\\2_Scenarios\\"+scen+"\\Outputs\\6_FreightModel\\EI_Trips\\"
	logfile = "E:\\TSTM_V3\\EITrips.txt"

	for i=1 to EIflds.length do
		thismtx = path + "Com" + EIflds[i]+"_EI.mtx"
		RunMacro("MatrixSums", thismtx, logfile, type)
	end
end

if type = "IE" then do
	path = "E:\\TSTM_V3\\2_Scenarios\\"+scen+"\\Outputs\\6_FreightModel\\IE_Trips\\"
	logfile = "E:\\TSTM_V3\\IETrips.txt"

	for i=1 to EIflds.length do
		thismtx = path + "Com" + EIflds[i]+"_IE.mtx"
		RunMacro("MatrixSums", thismtx, logfile, type)
	end
end

if type = "II" then do
	path = "E:\\TSTM_V3\\2_Scenarios\\"+scen+"\\Outputs\\6_FreightModel\\II_Trips\\"
	logfile = "E:\\TSTM_V3\\IITrips.txt"

	for i=1 to EIflds.length do
		thismtx = path + "Com" + EIflds[i]+"_II.mtx"
		RunMacro("MatrixSums", thismtx, logfile, type)
	end
end

if type = "Total" then do
	path = "E:\\TSTM_V3\\2_Scenarios\\"+scen+"\\Outputs\\6_FreightModel\\"
	logfile = "E:\\TSTM_V3\\Freight_Trips.txt"

	for i=1 to EIflds.length do
		thismtx = path + "Comm" + EIflds[i]+".mtx"
		RunMacro("MatrixSums", thismtx, logfile, type)
	end
end

endMacro

Macro "ApplyFactors"
iip = {0.1980, 0.2744, 0.5276}
iis = {0.1980, 0.2744, 0.5276}
iim = {0.1980, 0.2744, 0.5276}
ep = {0.167, 0.222, 0.611}
es = {0.162, 0.222, 0.616}
em = {0.152, 0.204, 0.644}

mtxfile = "C:\\Projects\\Chattanooga\\Model\\1_Model-Files\\4_Pivot\\Seed_ODME_R5.mtx"
mtxfile = "C:\\Users\\steven.trevino\\Dropbox\\RSG\\Chattanooga\\Update_13March2017\\EE\\EE_2035.mtx"

thismtx = OpenMatrix(mtxfile, "Auto")
mcII = CreateMatrixCurrencies(thismtx, "Internals", "Internals", null)
mcII.AM_Pass := mcII.AutoTrips * iip[1]
mcII.PM_Pass := mcII.AutoTrips * iip[2]
mcII.OP_Pass := mcII.AutoTrips * iip[3]
mcII.AM_SUT  :=  mcII.SUTrk * iis[1]
mcII.PM_SUT  :=  mcII.SUTrk * iis[2]
mcII.OP_SUT  :=  mcII.SUTrk * iis[3]
mcII.AM_MUT  :=  mcII.MUTrk * iim[1]
mcII.PM_MUT  :=  mcII.MUTrk * iim[2]
mcII.OP_MUT  :=  mcII.MUTrk * iim[3]

mcEI = CreateMatrixCurrencies(thismtx, "Externals", "Internals", null)
mcEI.AM_Pass := mcEI.AutoTrips * ep[1]
mcEI.PM_Pass := mcEI.AutoTrips * ep[2]
mcEI.OP_Pass := mcEI.AutoTrips * ep[3]
mcEI.AM_SUT  :=  mcEI.SUTrk * es[1]
mcEI.PM_SUT  :=  mcEI.SUTrk * es[2]
mcEI.OP_SUT  :=  mcEI.SUTrk * es[3]
mcEI.AM_MUT  :=  mcEI.MUTrk * em[1]
mcEI.PM_MUT  :=  mcEI.MUTrk * em[2]
mcEI.OP_MUT  :=  mcEI.MUTrk * em[3]


mcIE = CreateMatrixCurrencies(thismtx, "Internals", "Externals", null)
mcIE.AM_Pass := mcIE.AutoTrips * ep[1]
mcIE.PM_Pass := mcIE.AutoTrips * ep[2]
mcIE.OP_Pass := mcIE.AutoTrips * ep[3]
mcIE.AM_SUT  :=  mcIE.SUTrk * es[1]
mcIE.PM_SUT  :=  mcIE.SUTrk * es[2]
mcIE.OP_SUT  :=  mcIE.SUTrk * es[3]
mcIE.AM_MUT  :=  mcIE.MUTrk * em[1]
mcIE.PM_MUT  :=  mcIE.MUTrk * em[2]
mcIE.OP_MUT  :=  mcIE.MUTrk * em[3]


thismtx = OpenMatrix(mtxfile, "Auto")
mcEE = CreateMatrixCurrencies(thismtx, "Externals", "Externals", null)
mcEE.AM_Pass := mcEE.AutoTrips * ep[1]
mcEE.PM_Pass := mcEE.AutoTrips * ep[2]
mcEE.OP_Pass := mcEE.AutoTrips * ep[3]
mcEE.AM_SUT  :=  mcEE.SUTrk * es[1]
mcEE.PM_SUT  :=  mcEE.SUTrk * es[2]
mcEE.OP_SUT  :=  mcEE.SUTrk * es[3]
mcEE.AM_MUT  :=  mcEE.MUTrk * em[1]
mcEE.PM_MUT  :=  mcEE.MUTrk * em[2]

ShowMessage("Factors Finished!")
endMacro
