Macro "Report"

    RunMacro("G30 File Close All")

	thepath =  "C:\\Chattanooga\\TDM April 2018\\EC2045\\"
	geography = thepath + "Outputs\\2_Networks\\Network_EC_FY2045.dbd"

   	layer = RunMacro("TCB Add DB Layers", geography)
   	line_lyr = layer[2]


	NewFlds = {{"AM_VOC" ,             "real", , , , , },
                   {"OP_VOC" ,             "real", , , , , },
		   {"PM_VOC" ,             "real", , , , , },
		   {"DLY_VOC",             "real", , , , , }}

	RunMacro("TCB Add View Fields", {line_lyr, NewFlds})

        Setlayer(line_lyr)


   	for t = 1 to 3 do
           flow_bin           = {"PM","OP","AM"}
           flow_table         = OpenTable(flow_bin[t] + "_Flow","FFB",{thepath + "\\Outputs\\6_TripTables\\AsnVol_" + flow_bin[t] + "_I2"},)

           //	Calculate delay  & Transfer Outputs

           joinvw         = Joinviews("Joined+View",line_lyr+".ID",flow_bin[t] + "_Flow.ID1",)

           ab_flow        = nz(GetDataVector("Joined+View|","AB_Flow",))
           ba_flow        = nz(GetDataVector("Joined+View|","BA_Flow",))
           ab_cap         = nz(GetDataVector("Joined+View|","AB_" + flow_bin[t] + "CAP",))
           ba_cap         = nz(GetDataVector("Joined+View|","BA_" + flow_bin[t] + "CAP",))
           
           ab_tot_flow       = nz(ab_tot_flow) + ab_flow
           ba_tot_flow       = nz(ba_tot_flow) + ba_flow

           ab_volcap         = ab_flow/ab_cap
           ba_volcap         = ba_flow/ba_cap

           dir               =  nz(GetDataVector("Joined+View|","Dir",))

           if dir = 0 then do
              max_cap = max(ab_volcap,ba_volcap)
           end else if dir = 1 then max_cap = ab_volcap
           else if dir = -1 then max_cap = ba_volcap

//           if vhd < 0 then vhd = vhd*0

           if t=1 then do
              SetDataVector(line_lyr + "|","PM_VOC",max_cap,)
           end else if t = 2 then do
              SetDataVector(line_lyr + "|","OP_VOC",max_cap,)
           end else if t = 3 then do
              SetDataVector(line_lyr + "|","AM_VOC",max_cap,)
           end
           CloseView("Joined+View" )
        end

        Setlayer(line_lyr)
        ab_dly_cap        = nz(GetDataVector(line_lyr+"|","AB_DlyCap",))
        ba_dly_cap        = nz(GetDataVector(line_lyr+"|","BA_DlyCap",))
        ab_dly_volcap     = ab_tot_flow /  ab_dly_cap
        ba_dly_volcap     = ba_tot_flow /  ba_dly_cap

        max_cap           = max(ab_dly_volcap,ba_dly_volcap)

        SetDataVector(line_lyr + "|","DLY_VOC",max_cap,)

    quit:
        Return( RunMacro("TCB Closing", ok, True ))
endMacro