# Import Africa shapefile
system("v.in.ogr --overwrite input=gisdata/vectors/Africa layer=Africa output=Africa")

# Rasterize Africa at 30 arc-sec resolution
# First, we look at extent and resolution in decimal degree fro GDAL with -g argument
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

# Export
system("r.out.gdal -cm --overwrite input=test1_1_30s \\
             nodata=-9999 \\
			 output=output/test1_1_30s.tif type=Float32 \\
			 createopt='compress=lzw,predictor=2'")

# Plot
Africa <- readOGR("gisdata/vectors/Africa/Africa.shp")
test_in <- raster("gisdata/rasters/test1.1_044.tif")
test_in_crop <- crop(test_in, Africa)
test_in_clip <- mask(test_in_crop, Africa)
test_out <- raster("output/test1_1_30s.tif")
pdf("output/test.pdf", width=10, height=5)
par(mfrow=c(1,2))
plot(test_in_clip, main="Original",
		 xlim=c(-20,60), ylim=c(-40,40))
plot(test_out, main="Interpolated",
		 xlim=c(-20,60), ylim=c(-40,40))
dev.off()
