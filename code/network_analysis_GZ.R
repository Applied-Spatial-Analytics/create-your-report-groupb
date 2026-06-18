library(sf)
library(dplyr)
library(dodgr) 
library(here)


input_res_path   <- here("create-your-report-groupb/data/Guangzhou/residential_guangzhou.gpkg")
input_green_path <- here("create-your-report-groupb/data/Guangzhou/green_guangzhou.gpkg")
input_ped_path   <- here("create-your-report-groupb/data/Guangzhou/pedestrian_guangzhou.gpkg")
output_grid_path <- here("create-your-report-groupb/data/Guangzhou/residential_walk_dist.gpkg")

# Load Datasets
res   <- st_read(input_res_path)
green <- st_read(input_green_path)

# Reproject to meters for area operations, 
# make grids of 100 meters for residential landuse
res   <- st_transform(res, 32649)
grid  <- st_make_grid(res, cellsize = 100, square = TRUE)
grid  <- st_sf(geometry = grid)
grid_res <- st_intersection(grid, res)
grid_res <- st_make_valid(grid_res)

green <- st_transform(green, 32649)
green <- st_make_valid(green)

# Origins: use the center of the 100x100m grid cell
grid_pts <- st_centroid(grid_res)

# Destinations: Use point_on_surface to ensure the point 
# stays inside massive or irregularly shaped parks
green_pts <- st_point_on_surface(green)

# Transform both to Lat/Lon (EPSG:4326) for dodgr
grid_pts  <- st_transform(grid_pts, 4326)
green_pts <- st_transform(green_pts, 4326)

# Read the pedestrian network
ped_net <- st_read(input_ped_path)
ped_net <- st_transform(ped_net, 4326)

# Convert to X/Y coordinate matrices
from_coords <- st_coordinates(grid_pts)
to_coords   <- st_coordinates(green_pts)

# This converts flat spatial lines into an interconnected mathematical network.
graph <- weight_streetnet(ped_net, wt_profile = "foot")

# Calculate network distance
message("Calculating walking distances to nearest green spaces...")
walk_dists <- dodgr_dists_nearest(
  graph = graph,
  from = from_coords,
  to = to_coords
)

# Extract distance values from the dodgr  
grid_res$walk_dist_to_green_m <- as.numeric(walk_dists$d)

# Save the final dataset
st_write(
  grid_res,
  dsn = output_grid_path,
  layer = "grid_residential_100m",
  delete_dsn = TRUE
)