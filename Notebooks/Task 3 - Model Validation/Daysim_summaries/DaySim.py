
import pandas as pd
import numpy as np
import os
import math
import yaml



class DaysimSummary:
    
    
    def __init__(self):

        with open("DaySim_config.yaml", "r") as yamlfile:
            config = yaml.load(yamlfile, Loader=yaml.FullLoader)
        

        path = config["path"]
        self.excludeChildren5 = config["excludeChildren5"]

        self.countycorr = pd.read_csv(config["taz_dist_xref"])
        self.hhdata = pd.read_csv(os.path.join(path, "_household_2.dat"), sep = '\t')
        self.perdata = pd.read_csv(os.path.join(path, "_person_2.dat"), sep = '\t') 
        self.tripdata  = pd.read_csv(os.path.join(path, "_trip_2.dat"), sep = '\t')
        self.tourdata  = pd.read_csv(os.path.join(path, "_tour_2.dat"), sep = '\t')
        self.pdaydata = pd.read_csv(os.path.join(path, "_person_day_2.dat"), sep = '\t')
        
        if config["runVehAvailability"]:
            print ("runVehAvailability = True, loading data...")
            self.hhdata_vehavail = self.prep_vehavail()
            
        if config["runWrkSchLocationChoice"]:
            print ("runWrkSchLocationChoice = True, loading data...")
            self.perdata_wrkschloc = self.prep_wrkschloc()
            
        if config["runTripMode"]:   
            print ("runTripMode = True, loading data...")
            self.tripdata_trip_mode = self.prep_trip_mode()
            
        if config["runTourMode"]:
            print ("runTourMode = True, loading data...")
            self.tourdata_tour_mode = self.prep_tour_mode()
            
        if config["runTripDestination"]:   
            print ("runTripDestination = True, loading data...")
            self.tripdata_trip_destination = self.prep_trip_destination()
            
        if config["runTourDestination"]:
            print ("runTourDestination = True, loading data...")
            self.tourdata_tour_destination = self.prep_tour_destination()
            
        if config["runTripTOD"]:
            print ("runTripTOD = True, loading data...")
            self.tripdata_trip_tod = self.prep_trip_tod()
            
        if config["runTourTOD"]:
            print ("runTourTOD = True, loading data...")
            self.tourdata_tour_tod = self.prep_tour_tod()
            
        if config["runDayPattern"]:   
            print ("runDayPattern = True, loading data...")
            self.pdaydata_day_pattern_pday = self.prep_day_pattern_pday()
            self.pdaydata_day_pattern_tour = self.prep_day_pattern_tour()
            self.pdaydata_day_pattern_trip = self.prep_day_pattern_trip()
        
        
        
    def prep_vehavail(self):
        
        """ prepare household data for vehicle availability summaries"""
        hhdata = self.hhdata
        perdata = self.perdata
        
        hhdata["hhvehcat"] = np.where(hhdata.hhvehs>4, 4, hhdata.hhvehs)
        perdata["hh16cat"] = np.where(perdata.pagey>=16, 1, 0)  #potential drivers
        aggper = perdata.groupby("hhno")["hh16cat"].sum() 
        hhdata = pd.merge(hhdata, aggper, on="hhno", how="left")
        hhdata["hh16cat"] = np.where(hhdata.hh16cat>4, 4, hhdata.hh16cat)
        hhdata["inccat"] = pd.cut(hhdata["hhincome"], 
                              bins=[0,15000,50000,75000,float("inf")], 
                              labels=["0K-15K", "15K-50K", "50K-75K", ">75K"], 
                              right=True)
        hhdata = (hhdata.merge(self.countycorr, 
                              left_on="hhtaz", 
                              right_on="TAZID", 
                              how="left").
                              rename(columns={"District": "hhcounty"}))
        
        return hhdata

    
    
    def prep_wrkschloc(self):

        """ prepare person data for work school location summaries"""
        hhdata = self.hhdata
        perdata = self.perdata

        perdata = perdata.merge(hhdata, on="hhno", how="left")
        perdata["wrkr"] = np.where((perdata.pwtyp>0) & (perdata.pwtaz!=0), 1, 0)
        perdata["outhmwrkr"] = np.where((perdata.pwtaz>0) & (perdata.hhparcel!=perdata.pwpcl), 1, 0)
        perdata["wrkrtyp"] = np.where(perdata.pptyp==1, "FT", 
                                      np.where(perdata.pptyp==2, "PT","NotFTPT"))
        perdata["wrkrtyp"] = perdata["wrkrtyp"].astype(pd.CategoricalDtype(categories=["FT","PT","NotFTPT"]))
        perdata["wrkdistcat"] = pd.cut(perdata["pwaudist"], 
                                       bins=range(0, 90),  
                                       right=True,
                                       labels=list(range(0, 89)))
        perdata["wrktimecat"] = pd.cut(perdata["pwautime"], 
                                       bins=range(0, 90),  
                                       right=True,
                                       labels=list(range(0, 89)))
        perdata["wrkdistcat"] = np.where(perdata.pwtaz<0, 91, perdata.wrkdistcat)
        perdata["wrktimecat"] = np.where(perdata.pwtaz<0, 91, perdata.wrktimecat)
        perdata["stud"] = np.where((perdata.pptyp.isin([5,6,7])) & (perdata.pstaz!=0), 1, 0)
        perdata["outhmstud"] = np.where((perdata.pstaz>0) & (perdata.hhparcel!=perdata.pspcl), 1, 0)
        perdata["stutyp"] = np.where(perdata.pptyp==5, "UniStu",
                                     np.where(perdata.pptyp==6, "Stu16",
                                     np.where(perdata.pptyp==7, "Ch515", "NotStdu")))
        perdata["stutyp"] = perdata["stutyp"].astype(pd.CategoricalDtype(categories=["Ch515","Stu16","UniStu","NotStdu"]))
        perdata["schdistcat"] = pd.cut(perdata["psaudist"], 
                                       bins=range(0, 90),  
                                       right=True,
                                       labels=list(range(0, 89)))
        perdata["schtimecat"] = pd.cut(perdata["psautime"], 
                                       bins=range(0, 90),  
                                       right=True,
                                       labels=list(range(0, 89)))
        perdata["schdistcat"] = np.where(perdata.pstaz<0, 91, perdata.schdistcat)
        perdata["schtimecat"] = np.where(perdata.pstaz<0, 91, perdata.schtimecat)
        countycorr_dict = self.countycorr.set_index("TAZID")["District"].to_dict()
        perdata["hhcounty"] = perdata["hhtaz"].map(countycorr_dict)
        perdata["pwcounty"] = perdata["pwtaz"].map(countycorr_dict)
        perdata["pscounty"] = perdata["pstaz"].map(countycorr_dict)
        perdata["pwcounty"] = np.where(perdata.pwtaz<0, 13, perdata.pwcounty)
        perdata["pscounty"] = np.where(perdata.pstaz<0, 13, perdata.pscounty)    
        perdata["wfh"] = np.where((perdata.wrkr==1) & (perdata.hhparcel==perdata.pwpcl), 1, 0)
        perdata["sfh"] = np.where((perdata.stud==1) & (perdata.hhparcel==perdata.pspcl), 1, 0)
        perdata["pwautime"] = np.where(perdata.pwautime<0, np.NaN, perdata.pwautime)
        perdata["pwaudist"] = np.where(perdata.pwaudist<0, np.NaN, perdata.pwaudist)
        perdata["psautime"] = np.where(perdata.psautime<0, np.NaN, perdata.psautime)
        perdata["psaudist"] = np.where(perdata.psaudist<0, np.NaN, perdata.psaudist)

        return perdata
    
    
    @staticmethod
    def prep_trmode(tripdata):

        tripdata['tripmode'] = 'no mode'
        tripdata.loc[tripdata['mode'] == 1, 'tripmode'] = 'Walk'
        tripdata.loc[tripdata['mode'] == 2, 'tripmode'] = 'Bike'
        tripdata.loc[tripdata['mode'] == 3, 'tripmode'] = 'Drive Alone'
        tripdata.loc[tripdata['mode'] == 4, 'tripmode'] = 'Shared Ride 2'
        tripdata.loc[tripdata['mode'] == 5, 'tripmode'] = 'Shared Ride 3+'
        tripdata.loc[(tripdata['mode'] == 6) & (tripdata['pathtype'] == 3) , 'tripmode'] = 'Transit-local bus'
        tripdata.loc[(tripdata['mode'] == 6) & (tripdata['pathtype'] == 4) , 'tripmode'] = 'Transit-light rail'
        tripdata.loc[(tripdata['mode'] == 6) & (tripdata['pathtype'] == 5) , 'tripmode'] = 'Transit-premium bus'
        tripdata.loc[(tripdata['mode'] == 6) & (tripdata['pathtype'] == 6) , 'tripmode'] = 'Transit-commuter rail'
        tripdata.loc[(tripdata['mode'] == 6) & (tripdata['pathtype'] == 7) , 'tripmode'] = 'Transit-ferry'
        tripdata.loc[tripdata['mode'] == 8, 'tripmode'] = 'School Bus'

        return tripdata

    
    @staticmethod
    def prep_tomode(tourdata):

        tourdata['tourmode'] = 'no mode'
        tourdata.loc[tourdata['tmodetp'] == 1, 'tourmode'] = 'Walk'
        tourdata.loc[tourdata['tmodetp'] == 2, 'tourmode'] = 'Bike'
        tourdata.loc[tourdata['tmodetp'] == 3, 'tourmode'] = 'Drive Alone'
        tourdata.loc[tourdata['tmodetp'] == 4, 'tourmode'] = 'Shared Ride 2'
        tourdata.loc[tourdata['tmodetp'] == 5, 'tourmode'] = 'Shared Ride 3+'
        tourdata.loc[tourdata['tmodetp'] == 6, 'tourmode'] = 'Walk-Transit'
        tourdata.loc[tourdata['tmodetp'] == 7, 'tourmode'] = 'Drive-Transit'
        tourdata.loc[tourdata['tmodetp'] == 8, 'tourmode'] = 'School Bus'
        
        return tourdata
    
 

    def prep_trip_mode(self):

        """ prepare tripdata for trip mode summaries
            1 Work 
            2 School 
            3 Escort
            4 Personal_Business
            5 Shop
            6 Meal
            7 SocRec
            8 Workbased  
        """
        perdata = self.perdata
        tripdata = self.tripdata
        tourdata = self.tourdata

        perdata = perdata[["hhno","pno","pptyp","psexpfac"]]
        tourdata = pd.merge(tourdata, perdata, on =["hhno","pno"], how="left")    
        tourdata["pdpurp2"] = np.where(tourdata.parent==0, tourdata.pdpurp, 8)   # workbased trips

        tourdata = self.prep_tomode(tourdata)
        tripdata = self.prep_trmode(tripdata)

        tourdata = tourdata[["hhno","pno","tour","tourmode","pdpurp2","pptyp","psexpfac"]]
        tripdata = pd.merge(tripdata, tourdata, on=["hhno","pno","tour"], how="left")

        if self.excludeChildren5:
            tripdata = tripdata[tripdata["pptyp"]<8]

        return tripdata

    
    
    def prep_trip_destination(self):
        
        """ prepare tripdata for trip destination summaries
            0 none/home
            2 Work
            2 School
            3 Escort
            4 Personal_Business
            5 Shop
            6 Meal
            7 SocRec
            8 recreational
            9 medical
        """
        countycorr_dict = self.countycorr.set_index("TAZID")["District"].to_dict()
        hhdata = self.hhdata
        perdata = self.perdata
        tripdata = self.tripdata
        
        hhdata["hhcounty"] = hhdata["hhtaz"].map(countycorr_dict)
        perdata = perdata.merge(hhdata, on="hhno", how="left")
        perdata = perdata[["hhno","pno","pptyp","hhtaz","hhcounty","pwtaz","psexpfac"]]

        tripdata = pd.merge(tripdata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            tripdata = tripdata[tripdata["pptyp"]<8]

        tripdata["ocounty"] = tripdata["otaz"].map(countycorr_dict)
        tripdata["dcounty"] = tripdata["dtaz"].map(countycorr_dict)
        tripdata["distcat"] = pd.cut(tripdata["travdist"], 
                                        bins=range(0, 91),  
                                        right=True,
                                        labels=list(range(0, 90)))
        tripdata["timecat"] = pd.cut(tripdata["travtime"], 
                                        bins=range(0, 91),  
                                        right=True,
                                        labels=list(range(0, 90)))
        tripdata["wrkrtyp"] = np.where(tripdata.pptyp==1, "FT", 
                                       np.where(tripdata.pptyp==2, "PT","NotFTPT"))
        tripdata["wrkrtyp"] = tripdata["wrkrtyp"].astype(pd.CategoricalDtype(categories=["FT","PT","NotFTPT"]))
        tripdata["travtime"] = np.where(tripdata.travtime<0, np.NaN, tripdata.travtime)
        tripdata["travdist"] = np.where(tripdata.travdist<0, np.NaN, tripdata.travdist)

        return tripdata
    
    
    
    def prep_tour_mode(self):

        """ prepare tourdata for tour mode summaries
            1 Work 
            2 School 
            3 Escort
            4 Personal_Business
            5 Shop
            6 Meal
            7 SocRec
            8 Workbased  
        """
        perdata = self.perdata
        tripdata = self.tripdata
        tourdata = self.tourdata
        hhdata = self.hhdata
        

        hhdata["vehcat"] = np.where(hhdata.hhvehs>0, ">0-Veh HHs", "0-Veh HHs")
        hhdata = hhdata[["hhno","vehcat"]]
        perdata = pd.merge(perdata, hhdata, on="hhno",how="left")
        perdata = perdata[["hhno","pno","pptyp","vehcat","psexpfac"]]

        tourdata = self.prep_tomode(tourdata)

        tourdata = pd.merge(tourdata, perdata, on =["hhno","pno"], how="left")
        if self.excludeChildren5:
            tourdata = tourdata[tourdata["pptyp"]<8]
        tourdata["pdpurp"] = np.where(tourdata.pdpurp==8, 7, tourdata.pdpurp)   # combine recreational 8 with socail 7
        tourdata["pdpurp"] = np.where(tourdata.pdpurp==9, 4, tourdata.pdpurp)   # combine medical 8 with personal business 4
        tourdata["pdpurp2"] = np.where(tourdata.parent==0, tourdata.pdpurp, 8)   # workbased trips

        wrktours = tourdata[tourdata["pdpurp"]==1]
        wrktours = wrktours[["hhno","pno","tour","tourmode"]]
        wrktours = wrktours.rename(columns={"tour":"parent", "tourmode":"parenttourmode"})
        wrkbasedtours = tourdata[tourdata["parent"]>0]
        wrkbasedtours = pd.merge(wrkbasedtours,wrktours,on=["hhno","pno","parent"],how="left")

        nonwrkbasedtours = tourdata[tourdata["parent"]==0].copy()
        nonwrkbasedtours.loc[:,"parenttourmode"]=0

        wrkbasedtours = wrkbasedtours[nonwrkbasedtours.columns]
        tourdata = pd.concat([nonwrkbasedtours,wrkbasedtours])

        return tourdata
    
    
    
    
    def prep_tour_destination(self):
        
        """ prepare tour data for tour destination summaries
            1 Work 
            2 School 
            3 Escort
            4 Personal_Business
            5 Shop
            6 Meal
            7 SocRec
            8 Workbased
        """
        countycorr_dict = self.countycorr.set_index("TAZID")["District"].to_dict()
        hhdata = self.hhdata
        perdata = self.perdata
        tourdata = self.tourdata
        
        hhdata["hhcounty"] = hhdata["hhtaz"].map(countycorr_dict)
        perdata = perdata.merge(hhdata, on="hhno", how="left")
        perdata = perdata[["hhno","pno","pptyp","hhtaz","hhcounty","pwtaz","psexpfac"]]

        tourdata = pd.merge(tourdata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            tourdata = tourdata[tourdata["pptyp"]<8]

        tourdata["pdpurp"] = np.where(tourdata.pdpurp==8, 7, tourdata.pdpurp)   # combine recreational 8 with socail 7
        tourdata["pdpurp"] = np.where(tourdata.pdpurp==9, 4, tourdata.pdpurp)   # combine medical 8 with personal business 4
        tourdata["pdpurp2"] = np.where(tourdata.parent==0, tourdata.pdpurp, 8)   # workbased trips
        tourdata["ocounty"] = tourdata["totaz"].map(countycorr_dict)
        tourdata["dcounty"] = tourdata["tdtaz"].map(countycorr_dict)
        tourdata["distcat"] = pd.cut(tourdata["tautodist"], 
                                        bins=range(0, 91),  
                                        right=True,
                                        labels=list(range(0, 90)))
        tourdata["timecat"] = pd.cut(tourdata["tautotime"], 
                                        bins=range(0, 91),  
                                        right=True,
                                        labels=list(range(0, 90)))
        tourdata["wrkrtyp"] = np.where(tourdata.pptyp==1, "FT", 
                                       np.where(tourdata.pptyp==2, "PT","NotFTPT"))
        tourdata["wrkrtyp"] = tourdata["wrkrtyp"].astype(pd.CategoricalDtype(categories=["FT","PT","NotFTPT"]))
        tourdata["tautodist"] = np.where(tourdata.tautodist<0, np.NaN, tourdata.tautodist)
        tourdata["tautotime"] = np.where(tourdata.tautotime<0, np.NaN, tourdata.tautotime)

        return tourdata
    
    
    
    def prep_trip_tod(self):

        """ prepare trip data for trip time of day summaries"""
        perdata = self.perdata
        tripdata = self.tripdata
        
        perdata = perdata[["hhno","pno","pptyp","psexpfac"]]
        tripdata = pd.merge(tripdata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            tripdata = tripdata[tripdata["pptyp"]<8]
        tripdata["dephr"] = (tripdata["deptm"]/100).apply(math.trunc)
        tripdata["depmin"] = tripdata["deptm"]-tripdata["dephr"]*100

        if len(tripdata[tripdata["depmin"]>60]["depmin"])>0:
            tripdata["deptime"] = tripdata["deptm"]/60
            tripdata["arrtime"] = tripdata["arrtm"]/60
            tripdata["durdest"] = tripdata["endacttm"]-tripdata["arrtm"]
        else:
            tripdata["deptime"] = tripdata["dephr"]+tripdata["depmin"]/60
            tripdata["arrhr"] = (tripdata["arrtm"]/100).apply(math.trunc)
            tripdata["arrmin"] = tripdata["arrtm"]-tripdata["arrhr"]*100
            tripdata["arrtime"] = tripdata["arrhr"]+tripdata["arrmin"]/60
            tripdata["durdest"] = (
                                   ((tripdata["endacttm"]/100).apply(math.trunc)-(tripdata["arrtm"]/100).apply(math.trunc))*60
                                   +(tripdata["endacttm"]-(tripdata["endacttm"]/100).apply(math.trunc)*100)
                                   -(tripdata["arrtm"]-(tripdata["arrtm"]/100).apply(math.trunc)*100)
                                   )

        tripdata["durdest"] = np.where(tripdata.durdest<0,tripdata.durdest+1440,tripdata.durdest)   
        tripdata["durdest"] = tripdata["durdest"]/60

        tripdata = tripdata.sort_values(by=["hhno","pno","tour","half"], ascending=True)
        tripdata["maxtripno"] = tripdata.groupby(["hhno","pno","tour","half"])["tseg"].transform('max')

        cats = [0] + np.arange(3, 28.5, 0.5).tolist()
        tripdata["arrtimecat"] = pd.cut(tripdata["arrtime"], 
                                            bins=cats,  
                                            right=True,
                                            labels=cats[:-1])
        tripdata["deptimecat"] = pd.cut(tripdata["deptime"], 
                                            bins=cats,  
                                            right=True,
                                            labels=cats[:-1])
        cats = [0] + np.arange(0.5, 24.5, 0.5).tolist()
        tripdata["durdestcat"] = pd.cut(tripdata["durdest"], 
                                            bins=cats,  
                                            right=True,
                                            labels=cats[:-1])

        tripdata["arrflag"] = 0
        tripdata["depflag"] = 0
        tripdata["durflag"] = 0

        tripdata.loc[(tripdata["half"]==1) & (tripdata["tseg"]!=tripdata["maxtripno"]), "arrflag"] = 1
        tripdata.loc[(tripdata["half"]==2) & (tripdata["tseg"]!=1), "depflag"] = 1
        tripdata.loc[(tripdata["tseg"]<tripdata["maxtripno"]), "durflag"] = 1

        return tripdata
    
    
    
    def prep_tour_tod(self):

        """ prepare tour data for tour time of day summaries"""
        perdata = self.perdata
        tourdata = self.tourdata
        
        perdata = perdata[["hhno","pno","pptyp","psexpfac"]]
        tourdata = pd.merge(tourdata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            tourdata = tourdata[tourdata["pptyp"]<8]

        tourdata["pdpurp2"] = np.where(tourdata.pdpurp>2, 3, tourdata.pdpurp)    
        tourdata["pdpurp2"] = np.where(tourdata.pdpurp==0, 0, tourdata.pdpurp2)       
        tourdata["pdpurp2"] = np.where(tourdata.parent>0, 4, tourdata.pdpurp2)

        tourdata["deppdhr"] = (tourdata["tlvdest"]/100).apply(math.trunc)
        tourdata["deppdmin"] = tourdata["tlvdest"]-tourdata["deppdhr"]*100

        if len(tourdata[tourdata["deppdmin"]>60]["deppdmin"])>0:
            tourdata["deptime"] = tourdata["tlvdest"]/60
            tourdata["arrtime"] = tourdata["tardest"]/60
        else:
            tourdata["deptime"] = tourdata["deppdhr"]+tourdata["deppdmin"]/60
            tourdata["arrpdhr"] = (tourdata["tardest"]/100).apply(math.trunc)
            tourdata["arrpdmin"] = tourdata["tardest"]-tourdata["arrpdhr"]*100
            tourdata["arrtime"] = tourdata["arrpdhr"]+tourdata["arrpdmin"]/60

        tourdata["durdest"] = tourdata["deptime"]-tourdata["arrtime"]

        cats = [0] + np.arange(3, 28.5, 0.5).tolist()
        tourdata["arrtimecat"] = pd.cut(tourdata["arrtime"], 
                                            bins=cats,  
                                            right=True,
                                            labels=cats[:-1])
        tourdata["deptimecat"] = pd.cut(tourdata["deptime"], 
                                            bins=cats,  
                                            right=True,
                                            labels=cats[:-1])
        cats = [0] + np.arange(0.5, 25, 0.5).tolist()
        tourdata["durdestcat"] = pd.cut(tourdata["durdest"], 
                                            bins=cats,  
                                            right=True,
                                            labels=cats[:-1])
        return tourdata    
    
    
    
    def prep_perdata(self, perdata, hhdata):

        """ prepare person data for day pattern summaries"""

        countycorr_dict = self.countycorr.set_index("TAZID")["District"].to_dict()
        hhdata["hhcounty"] = hhdata["hhtaz"].map(countycorr_dict)
        hhdata["inccat"] = pd.cut(hhdata["hhincome"], 
                                  bins=[0,15000,50000,75000,float("inf")], 
                                  labels=["0K-15K", "15K-50K", "50K-75K", ">75K"], 
                                  right=True)
        perdata["hh16cat"] = np.where(perdata.pagey>=16, 1, 0)
        aggper = perdata.groupby("hhno")["hh16cat"].sum() 
        hhdata = pd.merge(hhdata, aggper, on="hhno", how="left")
        hhdata["hh16cat"] = np.where(hhdata.hh16cat>4, 4, hhdata.hh16cat)
        hhdata["vehsuf"] = np.where(hhdata.hhvehs==0, 1, 0)
        hhdata["vehsuf"] = np.where((hhdata.hhvehs>0)&(hhdata.hhvehs<hhdata.hh16cat), 2, hhdata.vehsuf)
        hhdata["vehsuf"] = np.where((hhdata.hhvehs>0)&(hhdata.hhvehs==hhdata.hh16cat), 3, hhdata.vehsuf)
        hhdata["vehsuf"] = np.where((hhdata.hhvehs>0)&(hhdata.hhvehs>hhdata.hh16cat), 4, hhdata.vehsuf)

        hhdata = hhdata[["hhno","hhcounty","inccat","vehsuf"]]
        perdata = pd.merge(perdata, hhdata, on="hhno", how="left")

        return perdata
    
    

    def prep_day_pattern_pday(self):

        """ prepare person day data for day pattern summaries"""
    
        perdata = self.perdata
        hhdata = self.hhdata
        pdaydata = self.pdaydata

        perdata = self.prep_perdata(perdata, hhdata)
        perdata = perdata[["hhno","pno","pptyp","hhcounty","inccat","vehsuf","psexpfac"]]

        pdaydata = pd.merge(pdaydata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            pdaydata = pdaydata[pdaydata["pptyp"]<8]

        pdaydata["pbtours"] = pdaydata["pbtours"]+pdaydata["metours"]
        pdaydata["sotours"] = pdaydata["sotours"]+pdaydata["retours"]    
        pdaydata["pbstops"] = pdaydata["pbstops"]+pdaydata["mestops"]   
        pdaydata["sostops"] = pdaydata["sostops"]+pdaydata["restops"] 

        pdaydata["tottours"] = (pdaydata["wktours"]
                                +pdaydata["sctours"]
                                +pdaydata["estours"]
                                +pdaydata["pbtours"]
                                +pdaydata["shtours"]
                                +pdaydata["mltours"]
                                +pdaydata["sotours"])
        pdaydata["tottours"] =  np.where(pdaydata.tottours>3, 3, pdaydata.tottours)
        pdaydata["totstops"] = (pdaydata["wkstops"]
                                +pdaydata["scstops"]
                                +pdaydata["esstops"]
                                +pdaydata["pbstops"]
                                +pdaydata["shstops"]
                                +pdaydata["mlstops"]
                                +pdaydata["sostops"])

        pdaydata["tourstop"] = 0
        pdaydata.loc[(pdaydata["tottours"]==0) & (pdaydata["totstops"]==0), "tourstop"] = 0
        pdaydata.loc[(pdaydata["tottours"]==1) & (pdaydata["totstops"]==0), "tourstop"] = 1
        pdaydata.loc[(pdaydata["tottours"]==1) & (pdaydata["totstops"]==1), "tourstop"] = 2
        pdaydata.loc[(pdaydata["tottours"]==1) & (pdaydata["totstops"]==2), "tourstop"] = 3
        pdaydata.loc[(pdaydata["tottours"]==1) & (pdaydata["totstops"]>=3), "tourstop"] = 4
        pdaydata.loc[(pdaydata["tottours"]==2) & (pdaydata["totstops"]==0), "tourstop"] = 5
        pdaydata.loc[(pdaydata["tottours"]==2) & (pdaydata["totstops"]==1), "tourstop"] = 6
        pdaydata.loc[(pdaydata["tottours"]==2) & (pdaydata["totstops"]==2), "tourstop"] = 7
        pdaydata.loc[(pdaydata["tottours"]==2) & (pdaydata["totstops"]>=3), "tourstop"] = 8
        pdaydata.loc[(pdaydata["tottours"]==3) & (pdaydata["totstops"]==0), "tourstop"] = 9
        pdaydata.loc[(pdaydata["tottours"]==3) & (pdaydata["totstops"]==1), "tourstop"] = 10
        pdaydata.loc[(pdaydata["tottours"]==3) & (pdaydata["totstops"]==2), "tourstop"] = 11
        pdaydata.loc[(pdaydata["tottours"]==3) & (pdaydata["totstops"]>=3), "tourstop"] = 12

        pdaydata["wktostp"] = 0
        pdaydata.loc[(pdaydata["wktours"]==0) & (pdaydata["wkstops"]==0), "wktostp"] = 1
        pdaydata.loc[(pdaydata["wktours"]==0) & (pdaydata["wkstops"]>=1), "wktostp"] = 2
        pdaydata.loc[(pdaydata["wktours"]>=1) & (pdaydata["wkstops"]==0), "wktostp"] = 3
        pdaydata.loc[(pdaydata["wktours"]>=1) & (pdaydata["wkstops"]>=1), "wktostp"] = 4

        pdaydata["sctostp"] = 0
        pdaydata.loc[(pdaydata["sctours"]==0) & (pdaydata["scstops"]==0), "sctostp"] = 1
        pdaydata.loc[(pdaydata["sctours"]==0) & (pdaydata["scstops"]>=1), "sctostp"] = 2
        pdaydata.loc[(pdaydata["sctours"]>=1) & (pdaydata["scstops"]==0), "sctostp"] = 3
        pdaydata.loc[(pdaydata["sctours"]>=1) & (pdaydata["scstops"]>=1), "sctostp"] = 4  

        pdaydata["estostp"] = 0
        pdaydata.loc[(pdaydata["estours"]==0) & (pdaydata["esstops"]==0), "estostp"] = 1
        pdaydata.loc[(pdaydata["estours"]==0) & (pdaydata["esstops"]>=1), "estostp"] = 2
        pdaydata.loc[(pdaydata["estours"]>=1) & (pdaydata["esstops"]==0), "estostp"] = 3
        pdaydata.loc[(pdaydata["estours"]>=1) & (pdaydata["esstops"]>=1), "estostp"] = 4 

        pdaydata["pbtostp"] = 0
        pdaydata.loc[(pdaydata["pbtours"]==0) & (pdaydata["pbstops"]==0), "pbtostp"] = 1
        pdaydata.loc[(pdaydata["pbtours"]==0) & (pdaydata["pbstops"]>=1), "pbtostp"] = 2
        pdaydata.loc[(pdaydata["pbtours"]>=1) & (pdaydata["pbstops"]==0), "pbtostp"] = 3
        pdaydata.loc[(pdaydata["pbtours"]>=1) & (pdaydata["pbstops"]>=1), "pbtostp"] = 4 

        pdaydata["shtostp"] = 0
        pdaydata.loc[(pdaydata["shtours"]==0) & (pdaydata["shstops"]==0), "shtostp"] = 1
        pdaydata.loc[(pdaydata["shtours"]==0) & (pdaydata["shstops"]>=1), "shtostp"] = 2
        pdaydata.loc[(pdaydata["shtours"]>=1) & (pdaydata["shstops"]==0), "shtostp"] = 3
        pdaydata.loc[(pdaydata["shtours"]>=1) & (pdaydata["shstops"]>=1), "shtostp"] = 4 

        pdaydata["mltostp"] = 0
        pdaydata.loc[(pdaydata["mltours"]==0) & (pdaydata["mlstops"]==0), "mltostp"] = 1
        pdaydata.loc[(pdaydata["mltours"]==0) & (pdaydata["mlstops"]>=1), "mltostp"] = 2
        pdaydata.loc[(pdaydata["mltours"]>=1) & (pdaydata["mlstops"]==0), "mltostp"] = 3
        pdaydata.loc[(pdaydata["mltours"]>=1) & (pdaydata["mlstops"]>=1), "mltostp"] = 4 

        pdaydata["sotostp"] = 0
        pdaydata.loc[(pdaydata["sotours"]==0) & (pdaydata["sostops"]==0), "sotostp"] = 1
        pdaydata.loc[(pdaydata["sotours"]==0) & (pdaydata["sostops"]>=1), "sotostp"] = 2
        pdaydata.loc[(pdaydata["sotours"]>=1) & (pdaydata["sostops"]==0), "sotostp"] = 3
        pdaydata.loc[(pdaydata["sotours"]>=1) & (pdaydata["sostops"]>=1), "sotostp"] = 4 

        pdaydata["wktopt"] = np.where(pdaydata.wktours>3, 3, pdaydata.wktours)
        pdaydata["sctopt"] = np.where(pdaydata.sctours>3, 3, pdaydata.sctours)
        pdaydata["estopt"] = np.where(pdaydata.estours>3, 3, pdaydata.estours)
        pdaydata["pbtopt"] = np.where(pdaydata.pbtours>3, 3, pdaydata.pbtours)
        pdaydata["shtopt"] = np.where(pdaydata.shtours>3, 3, pdaydata.shtours)
        pdaydata["mltopt"] = np.where(pdaydata.mltours>3, 3, pdaydata.mltours)
        pdaydata["sotopt"] = np.where(pdaydata.sotours>3, 3, pdaydata.sotours)

        return pdaydata

    
    
    def prep_day_pattern_tour(self):

        """ prepare tour data for day pattern summaries"""
        
        tourdata = self.tourdata
        perdata = self.perdata
        hhdata = self.hhdata

        perdata = self.prep_perdata(perdata, hhdata)

        tourdata = pd.merge(tourdata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            tourdata = tourdata[tourdata["pptyp"]<8]

        tourdata["pdpurp"] = np.where(tourdata.pdpurp==8, 7, tourdata.pdpurp) 
        tourdata["pdpurp"] = np.where(tourdata.pdpurp==9, 4, tourdata.pdpurp)  
        tourdata["ftwind"] = np.where(tourdata.pptyp==1, 1, 2)  

        tourdata["stcat"] = np.where(tourdata.subtrs>3, 3, tourdata.subtrs)
        tourdata["stops"] = tourdata["tripsh1"]+tourdata["tripsh2"]-2
        tourdata["stopscat"] = np.where(tourdata.stops>6, 6, tourdata.stops)
        tourdata["h1stopscat"] = np.where((tourdata.tripsh1-1)>6, 6, tourdata.tripsh1-1)
        tourdata["h2stopscat"] = np.where((tourdata.tripsh2-1)>6, 6, tourdata.tripsh2-1)
        tourdata["pdpurp2"] = np.where(tourdata.parent==0, tourdata.pdpurp, 8)

        return tourdata

    
    def prep_day_pattern_trip(self):

        """ prepare trip data for day pattern summaries"""
        
        tripdata = self.tripdata
        perdata = self.perdata
        hhdata = self.hhdata

        perdata = self.prep_perdata(perdata, hhdata)
        
        tripdata = pd.merge(tripdata, perdata, on=["hhno","pno"], how="left")
        if self.excludeChildren5:
            tripdata = tripdata[tripdata["pptyp"]<8]

        tripdata["dpurp"] = np.where(tripdata.dpurp==8, 7, tripdata.dpurp) 
        tripdata["dpurp"] = np.where(tripdata.dpurp==9, 4, tripdata.dpurp) 
        tripdata["dpurp"] = np.where(tripdata.dpurp==0, 8, tripdata.dpurp) 

        countycorr_dict = self.countycorr.set_index("TAZID")["District"].to_dict()
        tripdata["ocounty"] = tripdata["otaz"].map(countycorr_dict)

        return tripdata       
    
      
     
    @staticmethod
    def summary_func(data, Var1, Var2, weights, subsetvar=False, subsetval=0):

        if subsetvar:
            data = data[data[subsetvar]==subsetval]

        summary = (data.groupby([Var1,Var2])[weights].
                            sum().
                            reset_index().
                            pivot_table(values=weights, 
                                        index=Var1,
                                        columns=Var2,
                                        fill_value=0))
        return summary

    
    def summary_vehavail(self, sum_by_var):
        hhdata = self.hhdata_vehavail
        summary = self.summary_func(hhdata, sum_by_var, "hhvehcat", "hhexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_wrkschloc_trip_length(self, subsetvar):
        perdata = self.perdata_wrkschloc
        if subsetvar== "wrkr":
            summary = self.summary_func(perdata, "wrkdistcat", "wrkrtyp", "psexpfac", subsetvar=subsetvar, subsetval=1)
        elif subsetvar== "stud":
            summary = self.summary_func(perdata, "schdistcat", "stutyp", "psexpfac", subsetvar=subsetvar, subsetval=1) 
        return summary
    
    def summary_wrkschloc_trip_duration(self, subsetvar):
        perdata = self.perdata_wrkschloc
        if subsetvar== "wrkr":
            summary = self.summary_func(perdata, "wrktimecat", "wrkrtyp", "psexpfac", subsetvar=subsetvar, subsetval=1)
        elif subsetvar== "stud":
            summary = self.summary_func(perdata, "schtimecat", "stutyp", "psexpfac", subsetvar=subsetvar, subsetval=1) 
        return summary
    
    def summary_wrkschloc_county_flow(self, subsetvar):
        perdata = self.perdata_wrkschloc
        if subsetvar== "wrkr":
            summary = self.summary_func(perdata, "hhcounty", "pwcounty", "psexpfac", subsetvar=subsetvar, subsetval=1)
        elif subsetvar== "stud":
            summary = self.summary_func(perdata, "hhcounty", "pscounty", "psexpfac", subsetvar=subsetvar, subsetval=1) 
        return summary
    
    def summary_wrkschloc_at_home(self, subsetvar):
        perdata = self.perdata_wrkschloc
        if subsetvar== "wfh":
            summary = self.summary_func(perdata, "hhcounty", "wrkrtyp", "psexpfac", subsetvar=subsetvar, subsetval=1)
        elif subsetvar== "sfh":
            summary = self.summary_func(perdata, "hhcounty", "stutyp", "psexpfac", subsetvar=subsetvar, subsetval=1) 
        return summary

    def summary_trip_mode(self, purpose):
        tripdata = self.tripdata_trip_mode
        column_order = ['Drive Alone', 'Shared Ride 2', 'Shared Ride 3+', 'Drive-Transit', 'Walk-Transit',
                        'Bike','Walk','School Bus']
        index_order = ['Drive Alone', 'Shared Ride 2', 'Shared Ride 3+', 
                       'Transit-local bus', 'Transit-light rail', 'Transit-premium bus','Transit-commuter rail',
                       'Transit-ferry','School Bus','Bike','Walk']
        summary = (self.summary_func(tripdata, "tripmode", "tourmode", "psexpfac", subsetvar="pdpurp2", subsetval=purpose).
                        reindex(columns=column_order,
                                   index=index_order).
                        fillna(0))
        return summary
    
    def summary_tour_mode(self, purpose):
        tourdata = self.tourdata_tour_mode
        column_order = ["0-Veh HHs", ">0-Veh HHs"]
        index_order = ['Drive Alone', 'Shared Ride 2', 'Shared Ride 3+', 'Drive-Transit', 'Walk-Transit',
                        'Bike','Walk','School Bus']
        summary = (self.summary_func(tourdata, "tourmode", "vehcat", "psexpfac", subsetvar="pdpurp2", subsetval=purpose).
                        reindex(columns=column_order,
                                   index=index_order).
                        fillna(0))
        return summary
    
    def summary_trip_destination(self, sum_by_var):
        tripdata = self.tripdata_trip_destination       
        summary = self.summary_func(tripdata, sum_by_var, "dpurp", "psexpfac", subsetvar=False, subsetval=0)
        return summary

    
    def summary_tour_destination(self, sum_by_var):
        tourdata = self.tourdata_tour_destination       
        summary = self.summary_func(tourdata, sum_by_var, "pdpurp2", "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_tour_destination_county_flow(self, purpose):
        tourdata = self.tourdata_tour_destination       
        summary = self.summary_func(tourdata, "ocounty", "dcounty", "psexpfac", subsetvar="pdpurp2", subsetval=purpose)
        return summary
    
    def summary_trip_tod(self, sum_by_var, filter_by_var):
        tripdata = self.tripdata_trip_tod    
        summary = self.summary_func(tripdata, sum_by_var, "dpurp", "psexpfac", subsetvar=filter_by_var, subsetval=1)
        return summary

    def summary_tour_tod(self, sum_by_var):
        tourdata = self.tourdata_tour_tod    
        summary = self.summary_func(tourdata, sum_by_var, "pdpurp2", "psexpfac", subsetvar=False, subsetval=0)
        return summary

    def summary_tour_tod_purpose(self, sum_by_var, purpose):
        tourdata = self.tourdata_tour_tod  
        column_order = list(range(1, 9))
        summary = (self.summary_func(tourdata, sum_by_var, "pptyp", "psexpfac", subsetvar="pdpurp2", subsetval=purpose).
                        reindex(columns=column_order).
                        fillna(0))
        return summary
    
    def summary_day_pattern_num_of_tours(self):
        pdaydata = self.pdaydata_day_pattern_pday
        summary = self.summary_func(pdaydata, "tottours", "pptyp", "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_day_pattern_tour_stops(self):
        pdaydata = self.pdaydata_day_pattern_pday
        summary = self.summary_func(pdaydata, "tourstop", "pptyp", "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_day_pattern_tour_stops_by_purpose(self, purpose):
        pdaydata = self.pdaydata_day_pattern_pday
        summary = self.summary_func(pdaydata, purpose, "pptyp", "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_day_pattern_tours_by_purpose(self, purpose):
        pdaydata = self.pdaydata_day_pattern_pday
        summary = self.summary_func(pdaydata, purpose, "pptyp", "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_day_pattern_subtours(self):
        pdaydata = self.pdaydata_day_pattern_tour
        summary = self.summary_func(pdaydata, "stcat", "ftwind", "psexpfac", subsetvar="pdpurp", subsetval=1)
        return summary
        
    def summary_day_pattern_subtours_by_purpose(self):
        pdaydata = self.pdaydata_day_pattern_tour
        pdaydata = pdaydata[pdaydata["parent"]>=1]
        index_order = list(range(1, 8))
        summary = (self.summary_func(pdaydata, "pdpurp", "ftwind", "psexpfac", subsetvar=False, subsetval=0).
                        reindex(index=index_order).
                        fillna(0))
        return summary
 
    def summary_day_pattern_stops_by_tour_purpose(self, sum_by_var):
        pdaydata = self.pdaydata_day_pattern_tour
        summary = self.summary_func(pdaydata, sum_by_var, "pdpurp", "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_day_pattern_tours_by_tour_purpose(self, sum_by_var):
        pdaydata = self.pdaydata_day_pattern_tour
        summary = self.summary_func(pdaydata, "pdpurp2", sum_by_var, "psexpfac", subsetvar=False, subsetval=0)
        return summary
    
    def summary_day_pattern_stops_by_stop_purpose(self, sum_by_var1, sum_by_var2):
        pdaydata = self.pdaydata_day_pattern_pday
        summary = self.summary_func(pdaydata, sum_by_var1, sum_by_var2, "psexpfac", subsetvar=False, subsetval=0)
        summary.columns = summary.columns.astype(str)
        summary = summary.reset_index()
        summary["purpose"] = sum_by_var1
        summary = summary.drop(columns=sum_by_var1, index=0)
        return summary
    
    def summary_day_pattern_stops_by_stop_purpose_agg(self, sum_by_var2):
        summary = pd.concat([self.summary_day_pattern_stops_by_stop_purpose("wkstops", sum_by_var2),
                            self.summary_day_pattern_stops_by_stop_purpose("scstops", sum_by_var2),
                            self.summary_day_pattern_stops_by_stop_purpose("esstops", sum_by_var2),
                            self.summary_day_pattern_stops_by_stop_purpose("pbstops", sum_by_var2),
                            self.summary_day_pattern_stops_by_stop_purpose("shstops", sum_by_var2),
                            self.summary_day_pattern_stops_by_stop_purpose("mlstops", sum_by_var2),
                            self.summary_day_pattern_stops_by_stop_purpose("sostops", sum_by_var2)])
        return summary
    
    def summary_day_pattern_trips_by_destination_purpose(self, sum_by_var):
        pdaydata = self.pdaydata_day_pattern_trip
        summary = self.summary_func(pdaydata, "dpurp", sum_by_var, "psexpfac", subsetvar=False, subsetval=0)
        return summary


if __name__ == '__main__':

    DaySim = DaysimSummary()



