#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

# Libraries
library("rgrass7")

#=================================
# Download data for country border

# Data directory
dir.create("data/GAUL", recursive=TRUE)

# Global Administrative Unit Layer from FAO
# http://ref.data.fao.org/map?entryId=f7e7adb0-88fd-11da-a88f-000d939bc5d8
d_gaul <- "https://ndownloader.figshare.com/files/9570037?private_link=9d724ab4d7c771f2bf87"
download.file(url=d_gaul,destfile="data/GAUL/gaul.zip",method="wget",quiet=TRUE)
unzip("data/GAUL/gaul.zip", exdir="data/GAUL")

#======================================
# Create new grass location in Lat-Long

# New grass location
#dir.create("grassdata")
#system("grass72 -c epsg:4326 grassdata/chelsafrica")  # Ignore errors

# Connect R to grass location
# Make sure that /usr/lib/grass72/lib is in your PATH in RStudio
# On Linux, find the path to GRASS GIS with: $ grass72 --config path
# It should be somethin like: "/usr/lib/grass72"
# On Windows, find the path to GRASS GIS with: C:\>grass72.bat --config path
# If you use OSGeo4W, it should be: "C:\OSGeo4W\apps\grass\grass-7.2"
Sys.setenv(LD_LIBRARY_PATH=paste("/usr/lib/grass72/lib", Sys.getenv("LD_LIBRARY_PATH"),sep=":"))

# Initialize GRASS
initGRASS(gisBase="/usr/lib/grass72",home=tempdir(), 
					gisDbase="grassdata",
					location="chelsafrica",mapset="PERMANENT",
					override=TRUE)

#======================================
# Africa continent boundaries

# Import ctry country data into GRASS
# Snapping is necessary
# See https://en.wikipedia.org/wiki/Decimal_degrees 
# for correspondance between dd and meters (0.0001 dd ~ 4.3 m)
system("v.in.ogr --o -o input=data/GAUL/G2013_2012_0.shp output=ctry snap=0.0001")

# List of African countries
list_ctry_Africa <- c("Algeria","Angola","Benin","Botswana","Burkina Faso","Burundi","Cameroon",
					  "Cape Verde","Central African Republic","Chad","Comoros","Congo","Côte d''Ivoire",
					  "Democratic Republic of the Congo","Djibouti","Egypt","Equatorial Guinea",
					  "Eritrea","Ethiopia","Gabon","Gambia","Ghana","Guinea","Guinea-Bissau",
					  "Kenya","Lesotho","Liberia","Libya","Madagascar","Malawi","Mali",
					  "Mauritania","Mayotte","Morocco","Mozambique","Namibia","Niger","Nigeria","Rwanda",
					  "Sao Tome and Principe","Senegal","Sierra Leone","Somalia","South Africa",
					  "Swaziland","Togo","Tunisia","Uganda","United Republic of Tanzania",
					  "Zambia","Zimbabwe","South Sudan","Sudan","Malawi","Western Sahara",
					  "Hala''ib triangle","Ilemi triangle","Ma''tan al-Sarra","Abyei")

ctry_Africa <- paste0("('", paste0(list_ctry_Africa, collapse="','"), "')")
system(paste0("v.extract --o -d input=ctry where=\"ADM0_NAME IN ",ctry_Africa,"\" output=Africa new=0"))

# Export
system("v.out.ogr --o input=Africa output=data/Africa.shp")

# Rasterize Africa at 30 arc-sec resolution
# First, we look at extent and resolution in decimal degree for GDAL with -g argument
system("g.region -apg vector=Africa res=0:00:30")
# system("v.to.rast -d input=Africa type=area output=Africa use=val value=1")
# In place of v.to.rast use of gdal_rasterize with -at argument
system("gdal_rasterize -burn 1 -at -a_nodata 255 \\
       -te -25.3666666666667 -46.9833333333333 51.4166666666667 37.55 \\
       -tr 0.00833333333333333 0.00833333333333333 -ot Byte \\
	   -co 'COMPRESS=LZW' -co 'PREDICTOR=2' \\
	   gisdata/vectors/Africa/Africa.shp \\
	   output/Africa.tif")
# Import with r.in.gdal
system ("r.in.gdal --overwrite input=output/Africa.tif output=Africa")
system("g.region -ap raster=Africa")

#=============================================
# Resample with r.resamp.rst using Africa mask

# Import climate
system("r.in.gdal --overwrite input=gisdata/rasters/test1.1_044.tif output=test1_1")

# Resample with RST
system("g.region -ap raster=test1_1")
# Note: use maskmap=Africa to save computation time
system("r.resamp.rst --overwrite input=test1_1 elevation=test1_1_rst \\
			 ew_res=0.00833 ns_res=0.00833 maskmap=Africa")
system("r.info test1_1_rst")

# Resample to exact resolution 0:00:30
system("g.region -ap res=0:00:30")
system("r.resample --overwrite input=test1_1_rst output=test1_1_30s")

# Export in Float
execGRASS("r.out.gdal", flags=c("overwrite"), input="test1_1_30s",
		  nodata=-9999,
		  output="output/test1_1_30s.tif",
		  type="Float32", createopt="compress=lzw,predictor=2")

# # Export in Int
# execGRASS("r.out.gdal", flags=c("overwrite","f"), input="test1_1_30s",
# 		  nodata=-9999,
# 		  output="output/test1_1_30s.tif",
# 		  type="Int32", createopt="compress=lzw,predictor=2")

# Resample with bicubic and compare
system("g.region -ap raster=Africa")
system("r.resamp.interp --overwrite method=bicubic input=test1_1 \\
	   output=test1_1_interp_")
system("r.mask raster=Africa")
system("r.mapcalc --o 'test1_1_interp = test1_1_interp_'")
system("r.mask -r")
system("r.info test1_1_interp")

# Export interp
execGRASS("r.out.gdal", flags=c("overwrite","f"), input="test1_1_interp",
		  nodata=-9999,
		  output="output/test1_1_interp.tif",
		  type="Float32", createopt="compress=lzw,predictor=2")

# Compute diff
system("r.mapcalc --o 'diff = 100*(test1_1_interp-test1_1_30s)'") 

# Export diff
system("r.out.gdal -cmf --overwrite input=diff \\
       nodata=-9999 \\
	   output=output/diff.tif type=Int16 \\
	   createopt='compress=lzw,predictor=2' ")

# Plot
library(rgdal)
library(raster)
Africa <- readOGR("gisdata/vectors/Africa/Africa.shp")
test_in <- raster("gisdata/rasters/test1.1_044.tif")
test_in_crop <- crop(test_in, Africa)
test_in_clip <- mask(test_in_crop, Africa)

# RST
test_out <- raster("output/test1_1_30s.tif")
pdf("output/test_rst.pdf", width=10, height=5)
par(mfrow=c(1,2),mar=c(3,3,4,4))
plot(test_in_clip, main="Original",
	 xlim=c(-20,60), ylim=c(-40,40))
plot(test_out, main="Interpolated rst",
	 xlim=c(-20,60), ylim=c(-40,40))
#plot(Africa, add=TRUE, col="transparent")
dev.off()

# Bicubic
test_out <- raster("output/test1_1_interp.tif")
pdf("output/test_interp.pdf", width=10, height=5)
par(mfrow=c(1,2),mar=c(3,3,4,4))
plot(test_in_clip, main="Original",
	 xlim=c(-20,60), ylim=c(-40,40))
plot(test_out, main="Interpolated bicubic",
	 xlim=c(-20,60), ylim=c(-40,40))
#plot(Africa, add=TRUE, col="transparent")
dev.off()

# Plot difference
diff <- raster("output/diff.tif")
pdf("output/diff.pdf", width=10, height=10)
plot(diff, main="Differences bicubic/RST")
dev.off()

# End