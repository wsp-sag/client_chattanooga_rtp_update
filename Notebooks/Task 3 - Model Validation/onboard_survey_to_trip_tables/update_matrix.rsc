
Macro "RUN"

  // expanded survey
  tripscsv = "C:\\Model\\2_Scenarios\\TransitTrip.csv"
  // taz bind file
  mvw.tazbin = "C:\\Model\\2_Scenarios\\Base_TC7\\Outputs\\1_TAZ\\CHCRPA_TAZ_20Apr17.BIN"
  // mtx to save the outputs
  od.transitam = "C:\\Model\\2_Scenarios\\TransitTrip_AM.mtx"
  od.transitpm = "C:\\Model\\2_Scenarios\\TransitTrip_PM.mtx"
  od.transitop = "C:\\Model\\2_Scenarios\\TransitTrip_OP.mtx"

  //Expand Trips
  tripvw = OpenTable("tripvw", "CSV", {tripscsv})
  factrips = CreateExpression(tripvw, "factrips", "TREXPFAC*1", {"Integer", 1, 0})

  // //Time of Day
  // trtime = CreateExpression(tripvw, "trtime", "if (HALF = 1) then ARRTM else DEPTM", {"Integer", 4, 0})
  // rsgtod = CreateExpression(tripvw, "rsgtod", "if trtime >= 0 and trtime < 360 then 3 else if trtime >= 360 and trtime < 540 then 1 else if trtime >= 540 and trtime < 900 then 3 else if trtime >= 900 and trtime < 1080 then 2 else if trtime >= 1080 and trtime <= 1440 then 3" , {"Integer", 1, 0})

  // core01= " if rsgtod = 1 and (PATHTYPE = 3) then 'Local'"
  // core02= " else if rsgtod = 2 and (PATHTYPE = 3) then 'Local'"
  // core03= " else if rsgtod = 3 and (PATHTYPE = 3) then 'Local'"
  // core04= " else if rsgtod = 1 and (PATHTYPE = 7) then 'Shuttle'"
  // core05= " else if rsgtod = 2 and (PATHTYPE = 7) then 'Shuttle'"
  corestr= " if TREXPFAC = 1 then 'Local'"
  core_fld = CreateExpression(tripvw, "core_fld", corestr, {"String", 10, 0})

  //DaySim O/D TAZ fields
  {oTAZ, dTAZ} = {"TAZ_ID_LEFT", "TAZ_ID_DEST"}
  tazvw = OpenTable("tazvw", "FFB", {mvw.tazbin, })
  tazinfo = GetTableStructure(tazvw)
  tazIDfield = tazinfo[1][1]

  //Create OD matrix & fill 0s
  tranam = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.transitam}, {"Label", "TripTable"},{"Tables", {"Local", "Shuttle"}} })
  tranpm = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.transitpm}, {"Label", "TripTable"},{"Tables", {"Local", "Shuttle"}} })
  tranop = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Origin"},{tazvw+"|",tazvw+"."+tazIDfield, "Destination"}, {{"File Name", od.transitop}, {"Label", "TripTable"},{"Tables", {"Local", "Shuttle"}} })


  //Transit
  SetView(tripvw)
  numsel = SelectByQuery("sel", "Several", "Select * where TOD = 'AM'", )
  UpdateMatrixFromView(tranam, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

  numsel = SelectByQuery("sel", "Several", "Select * where TOD = 'PM'", )
  UpdateMatrixFromView(tranpm, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

  numsel = SelectByQuery("sel", "Several", "Select * where TOD = 'OP'", )
  UpdateMatrixFromView(tranop, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

  DeleteSet("sel")

  CloseView(tazvw)
  arr = GetExpressions(tripvw)
  for i = 1 to arr.length do DestroyExpression(tripvw+"."+arr[i]) end
  CloseView(tripvw)

endMacro