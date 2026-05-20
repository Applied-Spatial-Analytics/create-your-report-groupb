library(sf)
library(terra)
library(ggplot2)
library(tidyterra)
library(viridis)

# ==========================================
# 1. LOAD & PREPARE DATA
# ==========================================

# Load the Rotterdam buildings (GPKG)
buildings <- st_read("afstand_tot_koelte.gpkg")

# Load the national UHI raster
uhi_nl <- rast("Gevoelstemperatuur2022.tif")

# Ensure CRS alignment (Crucial step!)
if (st_crs(buildings) != st_crs(uhi_nl)) {
  uhi_nl <- project(uhi_nl, crs(buildings))
}

# Crop and Mask the massive NL raster to just the Rotterdam building bounding box
# This speeds up your code drastically
uhi_rotterdam <- crop(uhi_nl, ext(buildings))
uhi_rotterdam <- mask(uhi_rotterdam, vect(st_union(st_convex_hull(buildings))))



# ==========================================
# HEXAGONAL AGGREGATION (Recommended for Clarity)
# ==========================================

# 1. Create a hexagonal grid over Rotterdam
hex_grid <- st_make_grid(buildings, cellsize = 250, square = FALSE) %>%
  st_sf() %>%
  st_filter(buildings) # Keep only hexes that contain buildings

# 2. Calculate the average distance to coolness inside each hexagon
hex_analysis <- st_join(hex_grid, buildings, join = st_intersects) %>%
  group_by(geometry) %>%
  summarize(avg_distance = mean(afstand, na.rm = TRUE))

# 3. Plot Hexagons using Contour Lines for the UHI background
ggplot() +
  # UHI represented as clean topographic heat contours so background isn't messy
  geom_spatraster_contour(data = uhi_rotterdam, aes(color = ..level..), linewidth = 0.6) +
  scale_color_gradient(low = "#fee0d2", high = "#b30000", name = "UHI Heat Contours") +

  # New Scale for the Hexagons
  ggnewscale::new_scale_fill() +

  # Hexagons showing micro-neighborhood access deficits
  geom_sf(data = hex_analysis, aes(fill = avg_distance), alpha = 0.75, color = "white", linewidth = 0.1) +
  scale_fill_viridis_c(option = "plasma", name = "Avg Distance to Coolness (m)") +

  theme_minimal() +
  labs(
    title = "Rotterdam Vulnerability Analysis",
    subtitle = "Aggregated walkability deficits overlaid with UHI isotherms",
    caption = "Hexagon resolution: 250m"
  ) +
  theme(panel.grid = element_blank())
