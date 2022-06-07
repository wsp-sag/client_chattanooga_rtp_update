# Post-processing PopSynIII output to generate a fully expanded synthetic population
# general and gq tables are joined into a unified population file at this stage
# Binny M Paul, binny.mathewpaul@rsginc.com
# ----------------------------------------------------------------------------------
#################################################################################################################

#UseR inputs
outDir <- "E:\\Projects\\ChattanoogaMPO\\ChattanoogaPopSyn\\chattanooga\\PopSyn2045\\outputs\\"
region <- "Chattanooga TPO"              #Region Name  			   
serverName <- "SDMDLPPW01"               #SQL Server
dbName <- "Chattanooga"               	 #PopSyn Database
metaGeography <- "Region"                #Geography designated as meta geography ID
scenario <- "BaseYear"						       #Specify scenario being validated

#Load libraries
#install.packages("RODBC")
library(RODBC)
#install.packages("dplyr")
library(dplyr)


#Open connection to PopSyn SQL server
connectionstring <- paste("Driver={SQL Server};Server=",serverName,";Database=",dbName,";Trusted_Connection=yes;", sep="")
channel <- odbcDriverConnect(connection=connectionstring)

# Read PopSyn output files from server
synpop_hh <- sqlQuery(channel,"SELECT * FROM dbo.synpop_hh")
synpop_person <- sqlQuery(channel,"SELECT * FROM dbo.synpop_person")
synpop_hh_gq <- sqlQuery(channel,"SELECT * FROM dbo.synpop_hh_gq")
synpop_person_gq <- sqlQuery(channel,"SELECT * FROM dbo.synpop_person_gq")
geogCWalk <- sqlQuery(channel,"SELECT * FROM dbo.geographicCWalk  ORDER BY MZ_ID")


# Combine output files
colnames(synpop_hh_gq) <- colnames(synpop_hh)
households <- rbind(synpop_hh,synpop_hh_gq)
colnames(synpop_person_gq) <- colnames(synpop_person)
persons <- rbind(synpop_person,synpop_person_gq)

maxNP <- max(households$np)

hh.expanded <- households[rep(row.names(households), households$finalweight), ]
per.expanded <- persons[rep(row.names(persons), persons$finalweight), ]

# Add unique HH ID
hh.expanded <- cbind(hhid=1:nrow(hh.expanded), hh.expanded)
per.expanded <- cbind(hhid=1:nrow(per.expanded), per.expanded)
per.expanded$hhid <- 0  # initialize

for(i in 1:maxNP){
  hhsample <- hh.expanded[hh.expanded$np>=i,]
  per.expanded$hhid[per.expanded$sporder==i] <- hhsample$hhid
}

# Set the finalweight to 1
hh.expanded$finalweight <- 1
per.expanded$finalweight <- 1

# Write output files
write.csv(hh.expanded, paste(outDir, "households.csv", sep = ""))
write.csv(per.expanded, paste(outDir, "persons.csv", sep = ""))
write.csv(geogCWalk, paste(outDir, "geographicCWalk.csv", sep = ""))

#fin
