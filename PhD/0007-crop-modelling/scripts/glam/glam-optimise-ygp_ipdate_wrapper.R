#Julian Ramirez-Villegas
#UoL / CCAFS / CIAT
#June 2012


glam_optimise_ygp_ipdate_wrapper <- function(this_run) {
  #get the run details
  sid <- runs_ref$SID[this_run]
  zone <- runs_ref$RUN[this_run]
  seed <- runs_ref$SEED[this_run]
  expID <- runs_ref$EXPID[this_run]
  
  #check the existence of three parameters needed for sourcing this script
  if (class(try(get("src.dir"),silent=T)) == "try-error") {
    stop("src.dir needs to be set")
  }
  
  if (class(try(get("bDir"),silent=T)) == "try-error") {
    stop("bDir needs to be set")
  }
  
  if (class(try(get("maxiter"),silent=T)) == "try-error") {
    stop("maxiter (max. num. iterations) needs to be set")
  }
  
  if (class(try(get("zone"),silent=T)) == "try-error") {
    stop("zone to be calibrated needs to be set")
  }
  
  #Read in a dummy GLAM parameter file and create a new one based on a new parameter for
  #running and optimising GLAM
  
  #source all needed functions
  source(paste(src.dir,"/glam/glam-parFile-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-soil-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-runfiles-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-soil-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-make_wth.R",sep=""))
  source(paste(src.dir,"/glam/glam-optimise-functions.R",sep=""))
  source(paste(src.dir,"/signals/climateSignals-functions.R",sep=""))
  
  #input directories and model
  cropName <- "gnut"
  cDir <- paste(bDir,"/model-runs/",toupper(cropName),sep="")
  pDir <- paste(cDir,"/params",sep="") #parameter files
  
  #load cell details
  #cells <- read.csv(paste(bDir,"/climate-signals-yield/",toupper(cropName),"/signals/cells-process.csv",sep=""))
  cells <- read.csv(paste(cDir,"/inputs/calib-cells-selection-",selection,".csv",sep=""))
  
  #ci <- 1
  ciList <- which(cells$ZONE == zone)
  for (ci in ciList) {
    #get run setup
    #files that were generated
    setup <- list()
    setup$BDIR <- bDir
    setup$SCRATCH <- scratch
    setup$USE_SCRATCH <- use_scratch
    setup$CELL <- cells$CELL[ci]
    setup$ZONE <- cells$ZONE[ci]
    setup$METHOD <- "lin"
    setup$CROPNAME <- "gnut"
    setup$CAL_DIR <- paste(setup$BDIR,"/model-runs/",toupper(setup$CROPNAME),"/calib/exp-",expID,sep="")
    setup$YIELD_FILE <- paste(cDir,"/inputs/ascii/obs/yield_",setup$CELL,"_",setup$METHOD,".txt",sep="")
    setup$YGP_FILE <- "nofile"
    setup$SOW_FILE_RFD <- paste(cDir,"/inputs/ascii/sow/sowing_",setup$CELL,"_start.txt",sep="")
    setup$SOW_FILE_IRR <- paste(cDir,"/inputs/ascii/sow/sowing_",setup$CELL,"_irr.txt",sep="")
    setup$WTH_DIR_RFD <- paste(cDir,"/inputs/ascii/wth/rfd_",setup$CELL,sep="")
    setup$WTH_DIR_IRR <- paste(cDir,"/inputs/ascii/wth/irr_",setup$CELL,sep="")
    setup$WTH_ROOT <- "ingc"
    setup$SOL_FILE <- paste(cDir,"/inputs/ascii/soil/soiltypes_",setup$CELL,".txt",sep="")
    setup$SOL_GRID <- paste(cDir,"/inputs/ascii/soil/soilcodes_",setup$CELL,".txt",sep="")
    setup$SIM_NAME <- paste("fcal_",setup$CELL,sep="")
    setup$PRE_SEAS <- "OR" #OR: original input data, RF: rainfed by default, IR: irrigated by default
    
    #if using scratch directory instead of nfs
    if (use_scratch) {setup$SCRATCH <- paste(setup$SCRATCH,"/exp-",expID,sep="")}
    
    cat("\nprocessing cell",setup$CELL,"\n")
    
    #get defaults (parameter set)
    params <- GLAM_get_default(x=cells,cell=setup$CELL,parDir=pDir)
    params$glam_param.mod_mgt$ISYR <- 1966 #start year
    params$glam_param.mod_mgt$IEYR <- 1993 #end year
    params$glam_param.mod_mgt$IASCII <- 1 #output only to .out file
    params$glam_param.sim_ctr$NDSLA <- 1
    
    #load list of parameters to optimise, ranges, and number of steps
    opt_rules <- read.table(paste(pDir,"/optimisation-rules.txt",sep=""),sep="\t",header=T)
    #reorder optim rules
    if (!is.na(seed)) {
      set.seed(seed)
      reord <- sample(1:nrow(opt_rules),replace=F)
      opt_rules <- opt_rules[reord,]
      row.names(opt_rules) <- 1:nrow(opt_rules)
    }
    
    #extract irrigation rates
    irDir <- paste(cDir,"/irrigated_ratio",sep="")
    library(raster)
    ir_stk <- stack(paste(irDir,"/raw-",1966:1993,".asc",sep=""))
    ir_vls <- extract(ir_stk,cbind(X=cells$X[which(cells$CELL==setup$CELL)],Y=cells$Y[which(cells$CELL==setup$CELL)]))
    ir_vls <- as.numeric(ir_vls)
    ir_vls <- data.frame(YEAR=1966:1993,IRATIO=ir_vls)
    ir_vls$IRATIO[which(ir_vls$IRATIO > 1)] <- 1
    
    
    ###############################################
    # final calibration of IPDATE and YGP
    ###############################################
    
    ###############################################
    #load the calib.csv, last iteration
    cal_data <- read.csv(paste(setup$CAL_DIR,"/z",setup$ZONE,"_rfd_irr/calib.csv",sep=""))
    optimal <- cal_data[which(cal_data$iter==maxiter),]
    
    #update the parameter set
    for (rw in 1:nrow(optimal)) {
      pname <- paste(optimal$param[rw])
      where <- paste(optimal$sect[rw])
      
      if (pname == "TB" | pname == "TO" | pname == "TM") {
        params[[where]][[paste(pname,"FLWR",sep="")]][,"Value"] <- optimal$opt_val[rw]
        params[[where]][[paste(pname,"PODF",sep="")]][,"Value"] <- optimal$opt_val[rw]
        params[[where]][[paste(pname,"LMAX",sep="")]][,"Value"] <- optimal$opt_val[rw]
        params[[where]][[paste(pname,"HARV",sep="")]][,"Value"] <- optimal$opt_val[rw]
      } else {
        params[[where]][[pname]][,"Value"] <- optimal$opt_val[rw]
      }
    }
    
    
    ######################################################
    #now optimise the planting date
    ######################################################
    #which and where is the param
    parname <- "IPDATE"
    where <- "glam_param.spt_mgt"
    
    if (!file.exists(paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/iter-",tolower(parname),"/output.RData",sep=""))) {
      #reset lists of output parameters
      optimal <- list(); optimised <- list()
      
      # get the planting date from Sacks et al. (2010)
      rs <- raster(paste(bDir,"/climate-signals-yield/",toupper(cropName),"/0_base_grids/igp_dummy.tif",sep=""))
      
      # get longitude and latitude (row and column)
      cells$COL <- colFromX(rs,cells$X)
      cells$ROW <- rowFromY(rs,cells$Y)
      
      #load the planting date rasters
      sow_rs <- raster(paste(bDir,"/climate-signals-yield/",toupper(cropName),"/calendar/",tolower(cropName),"/plant_start_lr.tif",sep=""))
      sow_re <- raster(paste(bDir,"/climate-signals-yield/",toupper(cropName),"/calendar/",tolower(cropName),"/plant_end_lr.tif",sep=""))
      
      #grab the planting data into the cells matrix
      cells$SOW_START <- round(extract(sow_rs,cbind(X=cells$X,Y=cells$Y)),0)
      cells$SOW_END <- round(extract(sow_re,cbind(X=cells$X,Y=cells$Y)),0)
      
      #get the initial and final reported sowing dates
      sow_i <- cells$SOW_START[which(cells$CELL == setup$CELL)]
      sow_f <- cells$SOW_END[which(cells$CELL == setup$CELL)]
      
      #if either the final sowing date would result in an incomplete weather series
      #just reduce the day of harvest so that the maximum
      if ((sow_i+120) < 365) {
        if (sow_f < sow_i) {sow_f <- 365-120}
      }
      
      #if the initial sowing date + 120 is greater than 365 then i need to generate a new
      #weather series, this should be done as follows
      #1. create an alternate weather series
      #2. change the wthdir in the SETUP list
      #3. write a new sowing file (rainfed)
      #4. change the sowing file thing in the SETUP list
      #5. update sow_i and sow_f
      if ((sow_i+120) > 365) {
        #create an alternative weather series so that it still catches the planting date,
        #yet solving the issue with the final harvest date
        icells <- cells; icells$SOW_DATE <- sow_i
        altWthDir <- paste(setup$CAL_DIR,"/altered_wth/rfd_a",setup$CELL,sep="")
        if (!file.exists(altWthDir)) {dir.create(altWthDir,recursive=T)}
        wthDataDir <- paste(bDir,"/../climate-data/gridcell-data/IND",sep="") #folder with gridded data
        owthDir <- make_wth(x=icells,cell=setup$CELL,wthDir=altWthDir,wthDataDir,
                            fields=list(CELL="CELL",X="X",Y="Y",SOW_DATE="SOW_DATE"))
        
        #update setup
        setup$WTH_DIR_RFD <- owthDir$WTH_DIR
        #setup$WTH_DIR_IRR <- owthDir$WTH_DIR
        
        #update values
        rng <- 365-sow_i+sow_f
        sow_i <- owthDir$SOW_DATE
        sow_f <- sow_i+rng
      }
      
      sow_seq <- seq(sow_i,sow_f,by=1)
      nstep <- length(sow_seq)
      
      #set the planting date file to NA, so to pass the configuration check
      setup$SOW_FILE_RFD <- "nofile"
      
      #put these data in the parameter file
      params[[where]][[parname]][,"Value"] <- sow_i
      params[[where]][[parname]][,"Min"] <- sow_i
      params[[where]][[parname]][,"Max"] <- sow_f
      
      optimised[[parname]] <- GLAM_optimise_loc(GLAM_params=params,RUN_setup=setup,sect=where,
                                                param=parname,n.steps=nstep,iter=tolower(parname),
                                                iratio=ir_vls)
      
      optimal[[parname]] <- optimised[[parname]]$VALUE[which(optimised[[parname]]$RMSE == min(optimised[[parname]]$RMSE))]
      cat(parname,":",optimal[[parname]],"\n")
      if (length(optimal[[parname]]) > 1) {optimal[[parname]] <- optimal[[parname]][round(length(optimal[[parname]])/2,0)]}
      
      #save the two outputs
      save(list=c("optimised","optimal"),file=paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/iter-",tolower(parname),"/output.RData",sep=""))
      
      #update the parameter set to -99 and replace the planting date file
      cells$SOW_DATE <- optimal$IPDATE
      sdate_odir <- paste(setup$CAL_DIR,"/optim_ipdate",sep="")
      if (!file.exists(sdate_odir)) {dir.create(sdate_odir)}
      
      osowFile <- paste(sdate_odir,"/opt_",setup$SIM_NAME,".txt",sep="")
      osowFile <- write_sowdates(x=cells,outfile=osowFile,cell=c(setup$CELL),
                                 fields=list(CELL="CELL",COL="COL",ROW="ROW",SOW_DATE="SOW_DATE"))
      
      #update setup list
      setup$SOW_FILE_RFD <- osowFile
      
      #set IPDATE again to file input
      params[[where]][[parname]][,"Value"] <- -99
      params[[where]][[parname]][,"Min"] <- -99
      params[[where]][[parname]][,"Max"] <- -99
      
      if (plot_all) {
        #now make the plot
        plotsDir <- paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/plots",sep="")
        if (!file.exists(plotsDir)) {dir.create(plotsDir)}
        
        tiff(paste(plotsDir,"/",tolower(parname),".tif",sep=""),res=300,compression="lzw",height=1000,
             width=1250,pointsize=8)
        par(mar=c(3,3,2,1))
        plot(optimised[[parname]]$VALUE,optimised[[parname]]$RMSE,ty="l",
             main=paste(parname," :: ",optimal[[parname]],sep=""),
             xlab="Parameter value",ylab="RMSE (kg/ha)")
        grid(nx=10,ny=10)
        abline(v=optimal[[parname]],col="red",lty=2,lwd=0.8)
        dev.off()
      }
    }
    
    
    #################################################################################
    #run the optimiser for YGP, 20 steps
    parname <- "YGP"
    where <- "glam_param.ygp"
    nstep <- 100
    params[[where]][[parname]][,"Min"] <- 0.01
    params[[where]][[parname]][,"Max"] <- 1.00
    
    if (!file.exists(paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/iter-",tolower(parname),"/output.RData",sep=""))) {
      # reset lists of output parameters
      optimal <- list(); optimised <- list()
      
      optimised[[parname]] <- GLAM_optimise_loc(GLAM_params=params,RUN_setup=setup,sect=where,
                                                param=parname,n.steps=nstep,iter=tolower(parname),
                                                iratio=ir_vls)
      
      optimal[[parname]] <- optimised[[parname]]$VALUE[which(optimised[[parname]]$RMSE == min(optimised[[parname]]$RMSE))]
      cat(parname,":",optimal[[parname]],"\n")
      if (length(optimal[[parname]]) > 1) {optimal[[parname]] <- optimal[[parname]][round(length(optimal[[parname]])/2,0)]}
      
      save(list=c("optimised","optimal"),file=paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/iter-",tolower(parname),"/output.RData",sep=""))
      
      if (plot_all) {
        tiff(paste(plotsDir,"/",tolower(parname),".tif",sep=""),res=300,compression="lzw",height=1000,
             width=1250,pointsize=8)
        par(mar=c(3,3,2,1))
        plot(optimised[[parname]]$VALUE,optimised[[parname]]$RMSE,ty="l",
             main=paste(parname," :: ",optimal[[parname]],sep=""),
             xlab="Parameter value",ylab="RMSE (kg/ha)")
        grid(nx=10,ny=10)
        abline(v=optimal[[parname]],col="red",lty=2,lwd=0.8)
        dev.off()
      }
      
    }
  }
}



