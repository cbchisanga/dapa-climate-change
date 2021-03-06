## Parameters ###
#parallelisation
library(snowfall)
sfInit(parallel=T,cpus=4) #initiate cluster

stop("error")
source("00-monthly-data-anomalies-yearly.R")

setwd("D:/CIAT/_tools/dapa-climate-change/IPCC-CMIP5")

rcp <- "rcp60"
baseDir <- "T:/gcm/cmip5/raw/monthly"
basePer <- "1961_1990"
ens <- "r1i1p1"
outDir <- "X:/VULNERABILITY_ANALYSIS_CC_SAM/ECOCROP_DEVELOPMENT_CC_SAM/climate/4dup"
obsDir <- "S:/observed/gridded_products/cru-ts-v3-21/30yr_averages/1961_1990"
dataset <- "cru"

cat(" \n")
cat("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX \n")
cat("XXXXXXXXX GCM ANOMALIES YEARLY CALCULATION XXXXXXXX \n")
cat("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX \n")
cat(" \n")


curDir <- paste(baseDir, "/historical", sep="")
futDir <- paste(baseDir, "/", rcp, sep="")

gcmStats <- read.table(paste("D:/CIAT/_tools/dapa-climate-change/IPCC-CMIP5", "/data/cmip5-", rcp, "-monthly-data-summary.txt", sep=""), sep="\t", na.strings = "", header = TRUE)
gcmStats <- gcmStats[which(gcmStats$ensemble == ens),]
gcmStats <- gcmStats[which(gcmStats$obs == "no"),]

# Loop around gcms and ensembles
for (i in 1:nrow(gcmStats)){
  
  # Don't include variables without all three variables
  if(!paste(as.matrix(gcmStats)[i,10]) == "ins-var"){
    
    if(!paste(as.matrix(gcmStats)[i,10]) == "ins-yr"){
      
      # Get gcm and ensemble names
      gcm <- paste(as.matrix(gcmStats)[i,2])
      
      # Path of each ensemble
      curEnsDir <- paste(curDir, "/", gcm, "/", ens, sep="")
      
      # Average directory
      curAvgDir <- paste(curEnsDir, "/average/", basePer, sep="")
      
      # #export functions
      sfExport("GCMAnomaliesYearly")
      
      #export variables
      sfExport("rcp")
      sfExport("gcm")
      sfExport("ens")
      sfExport("futDir")
      sfExport("curAvgDir")
      sfExport("basePer")
      sfExport("outDir")
      
      cat(" .> ", paste("\t ", gcm, sep=""), "\t\n")
      
      for (i in 2006:2099) {      
        
        controlIntpol <- function(i) { #define a new function
          library(raster)
          
          GCMAnomaliesYearly(rcp, gcm, ens, i, futDir, curAvgDir, basePer, outDir)
        }
        
        system.time(sfSapply(as.vector(2006:2099), controlIntpol))
        
      }
      
      
      
    }
  }
}
cat("GCM Anomalies Process Done!")

#stop the cluster calculation
sfStop()




# #export functions
sfExport("GCMCalcFutureYearly")

#export variables
sfExport("rcp")
sfExport("ens")
sfExport("outDir")
sfExport("obsDir")
sfExport("dataset")

for (i in 1:nrow(gcmStats)){
  
  gcm <- paste(as.matrix(gcmStats)[i,2])
  sfExport("gcm")    
  
  controlIntpol <- function(i) { #define a new function
    
    library(raster)
    cat(" .> ", paste("\t ", i, sep=""), "\tdone!\n")
    GCMCalcFutureYearly(rcp, i, ens, outDir, obsDir, dataset)
    
  }
  
  system.time(sfSapply(as.vector(paste(as.matrix(gcmStats)[1:nrow(gcmStats),2])), controlIntpol))
  
}

}

#stop the cluster calculation
sfStop()

cat("GCM Disaggregation Process Done!")
