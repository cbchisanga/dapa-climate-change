#Julian Ramirez-Villegas
#February 2012
#CIAT / CCAFS / UoL
stop("Do not run whole thing")

#libraries
library(maptools); library(rgdal); library(raster)
data(wrld_simpl)

src.dir<-"D:/_tools/dapa-climate-change/trunk/PhD/0007-crop-modelling/scripts"
#src.dir <- "/home/jramirez/dapa-climate-change/PhD/0007-crop-modelling/scripts"
source(paste(src.dir,"/gridding-functions.R",sep=""))

#set the working folder
bDir <- "F:/PhD-work/crop-modelling/GLAM/climate-signals-yield"
#bDir <- "/andromeda_data1/jramirez/crop-modelling/GLAM/climate-signals-yield"
cropName <- "sorg-rabi"
cd <- paste(bDir,"/",toupper(cropName),sep="")

##   2.2. Create a 1x1 min resolution raster with the 1x1 degree cells
cDir <- cd

dumm <- raster(paste(bDir,"/0_base_grids/igp_dummy.asc",sep=""))
dumm[] <- 1:ncell(dumm)

msk <- raster(paste(bDir,"/0_base_grids/india-1min-msk.asc",sep=""))
xy <- xyFromCell(msk,which(!is.na(msk[])))
cells <- unique(cellFromXY(dumm,xy))
dumm[] <- NA; dumm[cells] <- 1
dumm[which(!is.na(dumm[]))] <- 1:length(which(!is.na(dumm[])))

#create high resolution raster with values of coarse cells
if (!file.exists(paste(bDir,"/0_base_grids/india-1min-1d_cells.asc",sep=""))) {
  rs_c <- raster(msk)
  rs_c <- resample(dumm,rs_c,method="ngb")
  rs_c <- writeRaster(rs_c,paste(bDir,"/0_base_grids/india-1min-1d_cells.asc",sep=""),format='ascii')
} else {
  rs_c <- raster(paste(bDir,"/0_base_grids/india-1min-1d_cells.asc",sep=""))
}

#   2.3. Calculate areas per pixel
if (!file.exists(paste(bDir,"/0_base_grids/india-1min-1d_cells_area.asc",sep=""))) {
  rs_a <- area(rs)
  rs_a <- writeRaster(rs_a,paste(bDir,"/0_base_grids/india-1min-1d_cells_area.asc",sep=""),
                         format='ascii',overwrite=T)
} else {
  rs_a <- raster(paste(bDir,"/0_base_grids/india-1min-1d_cells_area.asc",sep=""))
}

rs_dis <- raster(paste(bDir,"/0_base_grids/india-1min-disid.asc",sep=""))
method <- "fou"
outDir <- paste(cDir,"/raster/gridded/",method,sep="")
if (!file.exists(outDir)) {dir.create(outDir,recursive=T)}

xy <- xyFromCell(dumm,which(!is.na(dumm[])))
xy <- data.frame(CELL=which(!is.na(dumm[])),xy)

#   2.4. parallelise years and grid the data
#o
library(snowfall)
sfInit(parallel=T,cpus=15) #initiate cluster

#export functions
sfExport("weightValues")

#export variables
sfExport("cDir")
sfExport("outDir")
sfExport("method")
sfExport("rs_dis")
sfExport("rs_c")
sfExport("rs_a")
sfExport("dumm")
sfExport("xy")

#run the control function
system.time(sfSapply(as.vector(66:98), controlGridding))

#stop the cluster
sfStop()



