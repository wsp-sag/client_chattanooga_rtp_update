##This is a temporary main control file with lots of TODOs to move 
##this whole effort to a package with project specific config and run files

#Rprof()

#-----------------------
#Load packages
#-----------------------
##TODO consider local R installation, with predownloaded packages in that library
library(foreign)
library(reshape)
library(XLConnect)
library(descr)
library(Hmisc)
library(data.table)
library(plyr)

#------------------------------------
#Source functions and config settings
#------------------------------------
source("utilfunc.R")
#TODO function in package to create template config file in a specified location
source("daysim_output_config.R")

progressStart("run DaySim summaries",14)

#-----------------------
#Load data
#-----------------------

#Geographical correspondence
countycorr <- fread(tazcountycorr)

#Load DaySim outputs into Rdata files
progressNextStep("reading hh data")
if(runWrkSchLocationChoice | runVehAvailability | runDayPattern | runTourDestination | runTourMode)
{
  if(prepDaySim)
    readSaveRdata(dshhfile,"dshhdata")
  if(prepSurvey)
    readSaveRdata(surveyhhfile,"survhhdata")
}

progressNextStep("reading person data")
if(runWrkSchLocationChoice | runVehAvailability | runDayPattern | runTourDestination | runTourMode | runTourTOD | runTripMode | runTripTOD)
{
  if(prepDaySim)
    readSaveRdata(dsperfile,"dsperdata")
  if(prepSurvey)
    readSaveRdata(surveyperfile,"survperdata")
}

progressNextStep("reading person day data")
if(runDayPattern)
{
  if(prepDaySim)
    readSaveRdata(dspdayfile,"dspdaydata")
  if(prepSurvey)
    readSaveRdata(surveypdayfile,"survpdaydata")
}

progressNextStep("reading person day tour data")
if(runDayPattern | runTourDestination | runTourMode | runTourTOD | runTripMode)
{
  if(prepDaySim)
    readSaveRdata(dstourfile,"dstourdata")
  if(prepSurvey)
    readSaveRdata(surveytourfile,"survtourdata")
}

progressNextStep("reading person day trip data")
if(runDayPattern | runTripMode | runTripTOD)
{
  if(prepDaySim)
    readSaveRdata(dstripfile,"dstripdata")
  if(prepSurvey)
    readSaveRdata(surveytripfile,"survtripdata")
}

#Optional tour weight adjustment
if(tourAdj)
{
  touradj <- fread(tourAdjFile)
}

#force gc()
gc()

#-----------------------
#Run tabulations
#-----------------------
##TODO split between preparing tables in an R object and then putting them somewhere
##TODO e.g. in a spreadsheet, in a pdf report, etc.

#source("nonhwy.R")

progressNextStep("summarizing work location choice")
if(runWrkSchLocationChoice)
{
  source("wrkschlocation.R")
}
progressNextStep("summarizing vehicle ownership choice")
if(runVehAvailability)
{
  source("vehavailability.R")
}
progressNextStep("summarizing Day pattern")
if(runDayPattern)
{
  source("daypattern.R")
}
progressNextStep("summarizing Destination Choice")
if(runTourDestination)
{
  source("tourdestination.R")
}
progressNextStep("summarizing Trip Destination Choice")
if(runTourDestination)
{
  source("tripdestination.R")
}
progressNextStep("summarizing Tour Mode Choice") 
if(runTourMode)
{
  source("tourmode.R")
}
progressNextStep("summarizing Tour Time of Day Choice") 
if(runTourTOD)
{
  source("tourtod.R")
}
progressNextStep("summarizing Trip Mode Choice") 
if(runTripMode)
{
  source("tripmode.R")
}
progressNextStep("summarizing Trip Time of Day Choice")
if(runTripTOD)
{
  source("triptod.R")
}

progressEnd(outputsDir)

# Rprof(NULL)
# memprof <- summaryRprof()