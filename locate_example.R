rm(list=ls())
library(raster)
library(sp)
library(rgdal)
library(sf)
library(ggplot2)
library(geosphere)
source("functions/data_manager.R")
source("functions/localization.R")

###EDIT THESE VALUES
infile <- "../data/DATA-20200911T200454Z-001"
outpath <- "../output/"

tags <- read.csv(paste(infile,"DATA/nodes/Tags.csv",sep="/"), as.is=TRUE, na.strings=c("NA", "")) #uppercase node letters

all_data <- load_data(infile)
beep_data <- all_data[[1]][[1]]
#beep_data <- beep_data[beep_data$Time > as.POSIXct("2020-08-10"),]

#nodes <- node_file(all_data[[2]][[1]])
###looking for a file with the column names NodeId, lat, lng IN THAT ORDER
nodes <- read.csv(paste(infile,"DATA/nodes/Nodes1.csv",sep="/"), as.is=TRUE, na.strings=c("NA", "")) #uppercase node letters

beep_data <- beep_data[beep_data$NodeId %in% toupper(nodes$NodeId),] #c("326317", "326584", "3282fa", "3285ae", "3288f4")

###UNCOMMENT THESE AND FILL WITH YOUR DESIRED VALUES IF YOU WANT YOUR OUTPUT AS ONLY A SUBSET OF THE DATA
#channel <- a vector of RadioId value(s)
#tag_id <- a vector of TagId value(s)
#n_tags <- how many tags go into the "top tags"
#freq <- The interval of the added datetime variable. Any character string that would be accepted by seq.Date or seq.POSIXt

#EXAMPLE POSSIBLE VALUES
tag_id <- tags$TagId
#
#channel <- c(2)
freq <- c("5 min", "10 min")

max_nodes <- 0 #how many nodes should be used in the localization calculation?
df <- merge_df(beep_data, nodes)

resampled <- advanced_resampled_stats(beep_data, nodes, freq[1])
p3 = ggplot(data=resampled, aes(x=freq, y=max_rssi, group=NodeId, colour=NodeId)) +
  geom_line()

locations <- weighted_average(freq[1], beep_data, nodes)
#multi_freq <- lapply(freq, weighted_average, beeps=beep_data, node=nodes) 
#export_locs(freq, beep_data, nodes, outpath)

locations$ID <- paste(locations$TagId, locations$freq, sep="_")
locations <- locations[!duplicated(locations$ID),]
locations <- cbind(locations, locations@coords)

time <- "1 day"
move <- as.data.table(locations)[, .(Lat = mean(avg_y), Lon = mean(avg_x), std_lat = sd(avg_y), std_lon = sd(avg_x), .N), by = .(cut(freq, time),TagId)] #V = mean(SolarVolts), , 
move$lowlat <- move$Lat - move$std_lat
move$uplat <- move$Lat + move$std_lat
move$lowlon <- move$Lon - move$std_lon
move$uplon <- move$Lon + move$std_lon
move$d <- distVincentyEllipsoid(cbind(move$lowlon, move$lowlat), cbind(move$uplon, move$uplat))
move$d <- (move$d)/1000

nodes_spatial <- nodes
coordinates(nodes_spatial) <- 3:2
crs(nodes_spatial) <- CRS("+proj=longlat +datum=WGS84") 

#boulder_df <- locations[,c("TagId","avg_x","avg_y")]
#coordinates(boulder_df) <- 2:3
#utm <- CRS(paste0("+proj=utm +zone=", locations$zone[1], "+datum=WGS84"))
#crs(boulder_df) <- utm
#boulder_df_geog <- spTransform(locations, proj4string(nodes_spatial))
my_locs <- locations[,1]
locs <- st_as_sf(my_locs)
my_nodes <- st_as_sf(nodes_spatial)

ggplot() + 
  #geom_point(data=my_locs, aes(x=long,y=lat))
  #  ggmap(ph_basemap) +
  #geom_sf(data = locs, aes(colour=TagId), inherit.aes = FALSE) + 
  geom_sf(data = my_nodes) +
  geom_text(data = nodes, aes(x=lng, y=lat, label = NodeId), size = 5)
