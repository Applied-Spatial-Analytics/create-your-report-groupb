# This is all from Gemini so have to check it later

library(sf)          # For vector data (polygons)
library(terra)       # For raster data (UHI grid)
library(ggplot2)     # For plotting
library(tidyterra)   # Smooth ggplot integration for raster data
library(viridis)     # Beautiful, colorblind-friendly palettes

# ==========================================
# 1. LOAD YOUR DATA
# ==========================================
# Load neighborhood polygons (e.g., GeoJSON or Shapefile)
income_zones <- st_read("path_to_your_neighborhoods.geojson")

# Load UHI effect raster (e.g., Land Surface Temperature GeoTIFF)
uhi_raster <- rast("path_to_your_uhi_raster.tif")

# ==========================================
# 2. ALIGN COORDINATE REFERENCE SYSTEMS (CRS)
# ==========================================
# Check if they match. If not, project the raster to match the vector data
if (st_crs(income_zones) != st_crs(uhi_raster)) {
  uhi_raster <- project(uhi_raster, crs(income_zones))
}

# Optional: Crop the UHI raster to the exact boundaries of your income dataset
uhi_raster <- crop(uhi_raster, income_zones, mask = TRUE)

# ==========================================
# 3. BUILD THE LAYERED MAP
# ==========================================
ggplot() +
  # LAYER 1: Income Gradient Background (Vector Polygons)
  geom_sf(data = income_zones, aes(fill = median_income), color = "white", linewidth = 0.2) +
  scale_fill_viridis_c(
    option = "mako",
    name = "Median Income ($)",
    labels = scales::label_comma()
  ) +

  # LAYER 2: UHI Hotspots (Raster Overlap with Transparency)
  # 'tidyterra' allows us to use geom_spatraster directly over geom_sf
  geom_spatraster(data = uhi_raster, aes(fill = ..lyr.1..), alpha = 0.5) +
  scale_fill_gradientn(
    colors = c("transparent", "orange", "red", "darkred"),
    name = "UHI Temp (°C)",
    na.value = "transparent" # Hides raster pixels outside the city
  ) +

  # BEAUTIFICATION
  theme_minimal() +
  labs(
    title = "Socio-Economic Distribution & Urban Heat Island Overlay",
    subtitle = "Analyzing UHI exposure against neighborhood income",
    caption = "Data sources: Census Bureau & Satellite Thermal Imagery"
  ) +
  theme(
    legend.position = "right",
    panel.grid = element_blank() # Clean look without gridlines
  )
