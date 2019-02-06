#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

# Libraries
list.of.packages = c("rgdal","sp","raster","rgrass7","dataverse","glue")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages) > 0) {install.packages(new.packages)}
lapply(list.of.packages, require, character.only=T)

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
Sys.setenv(LD_LIBRARY_PATH=paste("/usr/lib/grass72/lib", 
																 Sys.getenv("LD_LIBRARY_PATH"),sep=":"))

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
system("g.region -ap vector=Africa res=0:00:30")
system("v.to.rast input=Africa type=area output=Africa use=val value=1")

#=============================================
# Resample with r.resamp.rst using Africa mask

# Import
execGRASS("r.in.gdal", flags=c("overwrite"), 
					input="gisdata/test1.1_044.tif", output="test1_1")

# Resample
execGRASS("g.region", flags=c("a","p"), raster="test1_1")
# The -t flag should be set to use "dnorm independent tension". 
system("r.resamp.rst --overwrite input=test1_1 elevation=test1_1_rst \\
			 ew_res=0.00833 ns_res=0.00833 maskmap=Africa")
system("r.info test1_1_rst")

# Resample to exact resolution 0:00:30
system("g.region -ap res=0:00:30")
system("r.resample --overwrite input=test1_1_rst output=test1_1_30s")

# Export
execGRASS("r.out.gdal", flags=c("overwrite"), input="test1_1_30s",
					output="gisdata/test1_1_30s.tif",
					type="Float32", createopt="compress=lzw,predictor=2")

# Plot
test1 <- raster("gisdata/test1_1_30s.tif")
pdf("output/test1_1_30s.pdf")
plot(test1)
dev.off()


# End