#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

# Libraries
library("rgrass7")

#======================================
# GRASS location

Sys.setenv(LD_LIBRARY_PATH=paste("/usr/lib/grass72/lib", Sys.getenv("LD_LIBRARY_PATH"),sep=":"))

# Initialize GRASS
initGRASS(gisBase="/usr/lib/grass72",home=tempdir(), 
		  gisDbase="grassdata",
		  location="chelsafrica_aea",mapset="PERMANENT",
		  override=TRUE)

# Reproject input climate data
system("gdalwarp -overwrite -s_srs EPSG:4326 -t_srs WKT/Africa_Albers_Equal_Area_Conic.prj \\
       -tr 50000 50000 -tap \\
	   -r bilinear -co 'COMPRESS=LZW' -co 'PREDICTOR=2' \\
	   gisdata/rasters/test1.1_044.tif output/test1_1_50km.tif")

# Reproject Africa
system("ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs WKT/Africa_Albers_Equal_Area_Conic.prj \\
	   -f 'ESRI Shapefile' -lco ENCODING=UTF-8 \\
	   output/Africa_aea.shp gisdata/vectors/Africa/Africa.shp")

# Import data into grass
system("r.in.gdal --overwrite input=output/test1_1_50km.tif output=test1_1")
system("v.in.ogr --o input=output/Africa_aea.shp output=Africa")

# Rasterize Africa at 1km res
system("g.region -ap vector=Africa res=1000")
system("v.to.rast input=Africa type=area output=Africa use=val value=1")

# Resample with RST
system("g.region -ap raster=test1_1")
# Note: use maskmap=Africa to save computation time
system("r.resamp.rst --overwrite input=test1_1 elevation=test1_1_rst \\
			 ew_res=1000 ns_res=1000 maskmap=Africa")
system("r.info test1_1_rst")

# Resample with bicubic and compare
system("g.region -ap raster=Africa")
system("r.resamp.interp --overwrite method=bicubic input=test1_1 \\
	   output=test1_1_interp")

# Compute diff
system("r.mapcalc --o 'diff = 100*(test1_1_interp-test1_1_rst)/(test1_1_interp)'")

# Export results
system("g.region -ap raster=diff")
system("r.out.gdal -cmf --overwrite input=diff \\
       nodata=-9999 \\
	   output=output/diff.tif type=Int16 \\
	   createopt='compress=lzw,predictor=2' ")

# Plot difference
library(rgdal)
library(raster)
Africa <- readOGR("output/Africa_aea.shp")
diff <- raster("output/diff.tif")
pdf("output/diff.pdf", width=10, height=10)
plot(diff)
dev.off()

