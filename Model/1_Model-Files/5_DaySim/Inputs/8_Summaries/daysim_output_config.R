#DaySim Version - DelPhi or C#
dsVersion                                 = "C#"

parcelfile                                = "./dummy.dat"
dshhfile                                  = "../Output/_household_2.dat"
dsperfile                                 = "../Output/_person_2.dat"
dspdayfile                                = "../Output/_person_day_2.dat"
dstourfile                                = "../Output/_tour_2.dat"
dstripfile                                = "../Output/_trip_2.dat"

# Chattanooga Regional Travel Survey 2010/2011
surveyhhfile                              = "./data/chc_hrec.dat"
surveyperfile                             = "./data/chc_prec.dat"
surveypdayfile                            = "./data/chc_pday.dat"
surveytourfile                            = "./data/chc_tour.dat"
surveytripfile                            = "./data/chc_trip.dat"

tazcountycorr                             = "./data/county_districts_chattanooga.csv"

wrklocmodelfile                           = "./templates/WrkLocation.csv"
schlocmodelfile                           = "./templates/SchLocation.csv"
vehavmodelfile                            = "./templates/VehAvailability.csv"
daypatmodelfile1                          = "./templates/DayPattern_pday.csv"
daypatmodelfile2                          = "./templates/DayPattern_tour.csv"
daypatmodelfile3                          = "./templates/DayPattern_trip.csv"
tourdestmodelfile                         = "./templates/TourDestination.csv"
tourdestwkbmodelfile                      = "./templates/TourDestination_wkbased.csv"
tripdestmodelfile                         = "./templates/TripDestination.csv"
tourmodemodelfile                         = "./templates/TourMode.csv"
tourtodmodelfile                          = "./templates/TourTOD.csv"
tripmodemodelfile                         = "./templates/TripMode.csv"
triptodmodelfile                          = "./templates/TripTOD.csv"

wrklocmodelout                            = "WrkLocation.xlsm"
schlocmodelout                            = "SchLocation.xlsm"
vehavmodelout                             = "VehAvailability.xlsm"
daypatmodelout                            = "DayPattern.xlsm"
tourdestmodelout                          = c("TourDestination_Escort.xlsm","TourDestination_PerBus.xlsm","TourDestination_Shop.xlsm",
                                              "TourDestination_Meal.xlsm","TourDestination_SocRec.xlsm")
tourdestwkbmodelout                       = "TourDestination_WrkBased.xlsm"
tourmodemodelout                          = "TourMode.xlsm"
tourtodmodelout                           = "TourTOD.xlsm"
tripmodemodelout                          = "TripMode.xlsm"
triptodmodelout                           = "TripTOD.xlsm"

outputsDir                                = "./output"
validationDir                             = ""

prepSurvey                                = TRUE
prepDaySim                                = TRUE

runWrkSchLocationChoice                   = FALSE
runVehAvailability                        = TRUE
runDayPattern                             = FALSE
runTourDestination                        = FALSE
runTourMode                               = TRUE
runTourTOD                                = FALSE
runTripMode                               = FALSE
runTripTOD                                = FALSE

excludeChildren5                          = FALSE
tourAdj                                   = FALSE