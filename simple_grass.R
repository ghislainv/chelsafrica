# Import Africa shapefile
system("v.in.ogr --overwrite input=gisdata/vectors/Africa layer=Africa output=Africa")

# Rasterize Africa at 30 arc-sec resolution
system("g.region -ap vector=Africa res=0:00:30")
system("v.to.rast input=Africa type=area output=Africa use=val value=1")

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
system("r.out.gdal --overwrite input=test1_1_30s \\
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
