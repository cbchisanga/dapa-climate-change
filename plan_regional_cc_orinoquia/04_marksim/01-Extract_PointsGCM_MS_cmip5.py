# ---------------------------------------------------------------------------------
# Author: Carlos Navarro
# Date: September 13th, 2010
# Purpose: Extraction by mask, diseggregated, interpolated or downscaled surfaces
# Note: If process is interrupted, you must be erase the last processed period
# ----------------------------------------------------------------------------------

import arcgisscripting, os, sys, string, glob
gp = arcgisscripting.create(9.3)

#Syntax
if len(sys.argv) < 7:
	os.system('cls')
	print "\n Too few args"
	print "   - ie: python 01-Extract_PointsGCM_MS.py \\dapadfs\data_cluster_2\gcm\cmip5 26 D:\CIAT\Workspace\Soil_Kenya_shp\Soil_kenya.shp D:\Workspace\Request\Request_brodriguez 30s downscaled"
	sys.exit(1)

#Set variables
dirbase = sys.argv[1]
scenario = sys.argv[2]
mask = sys.argv[3]
dirout = sys.argv[4]
resolution = sys.argv[5]
type = sys.argv[6]

os.system('cls')

print "~~~~~~~~~~~~~~~~~~~~~~"
print " EXTRACT BY MASK GCM  "
print "~~~~~~~~~~~~~~~~~~~~~~"

#Get lists 
# periodlist = "2010_2039" , "2040_2069", # "2020_2049", "2030_2059", "2040_2069", "2050_2079", "2060_2089", "2070_2099"
modellist = sorted(os.listdir(dirbase + "\\" + type + "\\rcp_" + scenario + "\\global_" + str(resolution)))
variablelist = "tmin", "tmax", "prec"
print "Available models: " + str(modellist)

for model in modellist:
	# for period in periodlist:
	period = "2020_2049"  ### Cambiar
	print "\n---> Processing: " + "rcp_" + scenario + " " + type + " global_" + str(resolution) + " " + model + " " + period + "\n"
	diroutpoints = dirout + "\\_extract_" + "rcp_" + scenario 
	if not os.path.exists(diroutpoints):
		os.system('mkdir ' + diroutpoints)	
	
	if not os.path.exists(diroutpoints + "\\rcp_" + scenario + "_" + model + "_" + period + "_done.txt"):
		for month in range (1, 12 + 1, 1):
			for variable in variablelist:
				
				gp.workspace = dirbase + "\\" + type + "\\rcp_" + scenario + "\\global_" + str(resolution) + "\\" + model + "\\r1i1p1\\" + period
				raster = gp.workspace + "\\" + variable + "_" + str(month) #sorted(gp.ListRasters(variable + "*", "GRID"))
				
				# for raster in rasters:
				#OutRaster = diroutraster + "\\" + raster
				#gp.clip_management(raster,"-100 -60 -30 23 ",OutRaster)
				InPointsFC = mask 
				OutPointsFC = diroutpoints + "\\rcp_" + scenario + "_" + model + "_" + period + "_" + os.path.basename(raster) + ".dbf"

				if not os.path.exists(OutPointsFC):
					print "\tExtracting .. " + os.path.basename(raster)
					#Check out Spatial Analyst extension license
					gp.CheckOutExtension("Spatial")

					#Process: Cell Statistics...
					gp.Sample_sa(raster, InPointsFC, OutPointsFC, "")
				else:
					print "\t" + os.path.basename(raster) + " extracted"
		
		print "\n"
		for month in range (1, 12 + 1, 1):
			for variable in variablelist:
				dbf = diroutpoints + "\\rcp_" + scenario + "_" + model + "_" + period + "_" + variable + "_" + str(month) + ".dbf"

				if not os.path.basename(dbf)[-10:] == "tmin_1.dbf":
					print "\tJoining .. " + os.path.basename(dbf)
					InData = diroutpoints + "\\rcp_" + scenario + "_" + model + "_" + period + "_tmin_1.dbf"
					fields = os.path.basename(dbf)[:-4].split("_")[-2:]
					gp.joinfield (InData, "mask", dbf, "mask", fields[0] + "_" + fields[1])
					os.remove(dbf)
		
		xmlList = sorted(glob.glob(diroutpoints + "\\rcp_" + scenario + "_" + model + "_" + period + "*.xml"))
		for xml in xmlList:
			os.remove(xml)
		
		checkTXT = open(diroutpoints + "\\rcp_" + scenario + "_" + model + "_" + period + "_done.txt", "w")
		checkTXT.close()
print "done!!!" 