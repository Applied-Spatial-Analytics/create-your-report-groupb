library(sf)
library(terra)
library(dplyr)
library(ggplot2)
library(tidyterra)
library(ggnewscale)
library(stringr)
library(here)

city_configs <- list(
  rotterdam = list(
    name         = "Rotterdam",
    epsg_target  = 28992, 
    outline_file = here("create-your-report-groupb/data/Rotterdam_data/RT_livability_datasets/Neighborhood_data.gpkg"),
    input_file   = here("create-your-report-groupb/data/Rotterdam_data/RT_livability_datasets/bag_rotterdam_woonfunctie.gpkg"),
    dist_file    = here("create-your-report-groupb/data/Rotterdam_data/datasets_klimaateffectatlas/afstand_tot_koelte.gpkg"),
    lst_file     = here("create-your-report-groupb/data/LST_files/lst_rotterdam_hot.tif"),
    max_dist     = 500,
    worst_dist   = 400,
    caption      = "Hexagon resolution: 300m | Dark outlines = >400m walk to green", # Updated caption
    plot_output  = "create-your-report-groupb/Report/maps/vulnerability_rotterdam.png"
  ),
  guangzhou = list(
    name         = "Guangzhou",
    epsg_target  = 4490, 
    outline_file = here("create-your-report-groupb/data/Guangzhou/GZ_Center_neighborhoods.gpkg"),
    input_file   = here("create-your-report-groupb/data/Guangzhou/residential_walk_dist.gpkg"),
    dist_file    = NULL, 
    lst_file     = here("create-your-report-groupb/data/LST_files/lst_guangzhou_hot.tif"),
    max_dist     = 1500,
    worst_dist   = 1500,
    caption      = "Hexagon resolution: 300m | Dark outlines = >1500m walk to green", # Updated caption
    plot_output  = "create-your-report-groupb/Report/maps/vulnerability_guangzhou.png"
  )
)

for (city_name in names(city_configs)) {
  cfg <- city_configs[[city_name]]
  message("\nProcessing: ", cfg$name)
  
  # 1. Load Outline & Enforce CRS
  city_outline <- st_read(cfg$outline_file) %>% st_make_valid() %>% st_union()
  if (is.na(st_crs(city_outline)$epsg) || st_crs(city_outline)$epsg != cfg$epsg_target) {
    city_outline <- st_transform(city_outline, cfg$epsg_target)
  }
  
  # 2. Handle City-Specific Data Branching
  if (city_name == "rotterdam") {
    afstand  <- st_read(cfg$dist_file) %>% st_make_valid() %>% st_transform(st_crs(city_outline))
    raw_data <- st_read(cfg$input_file) %>% st_make_valid() %>% st_transform(st_crs(city_outline))
    
    # Structural filter + spatial clip
    residential <- raw_data %>%
      filter(sapply(gebruiksdoel, function(x) any(grepl("woonfunctie", x, ignore.case = TRUE)))) %>%
      st_filter(city_outline)
    
    # Extract distances via join
    buildings_joined <- st_join(residential, afstand %>% select(Legenda), join = st_within, left = TRUE)
    
    # Fallback to nearest feature if outside poly
    na_idx <- is.na(buildings_joined$Legenda)
    if (any(na_idx)) {
      nearest_idx <- st_nearest_feature(buildings_joined[na_idx, ], afstand)
      buildings_joined$Legenda[na_idx] <- afstand$Legenda[nearest_idx]
    }
    
    base_data <- buildings_joined %>%
      mutate(distance_num = case_when(
        Legenda == "Koele plek" ~ 0,
        TRUE ~ as.numeric(str_extract(Legenda, "\\d{3,4}|\\d+"))
      ))
    
  } else if (city_name == "guangzhou") {
    grid_res <- st_read(cfg$input_file) %>% st_make_valid()
    if (st_crs(grid_res) != st_crs(city_outline)) {
      city_outline <- st_transform(city_outline, st_crs(grid_res))
    }
    
    base_data <- st_filter(grid_res, city_outline) %>%
      mutate(
        distance_num = walk_dist_to_green_m,
        Legenda = ifelse(walk_dist_to_green_m == 0, "Koele plek", "Buiten park")
      )
  }
  
  # 3. Process LST Raster Matrix
  lst_data      <- terra::rast(cfg$lst_file)
  lst_data      <- terra::aggregate(lst_data, fact = 2, fun = "mean")
  
  target_crs    <- st_crs(base_data)$wkt
  lst_data_proj <- terra::project(lst_data, target_crs, method = "bilinear")
  
  lst_trimmed   <- terra::crop(lst_data_proj, terra::vect(city_outline)) %>% 
    terra::mask(terra::vect(city_outline))
  
  # Dynamic Break Logic
  lst_min <- floor(terra::global(lst_trimmed, "min", na.rm = TRUE)[1,1])
  lst_max <- ceiling(terra::global(lst_trimmed, "max", na.rm = TRUE)[1,1])
  lst_breaks <- seq(lst_min, lst_max, length.out = 8)
  
  # 4. Grid Generation & Analysis
  hex_grid <- st_make_grid(base_data, cellsize = 300, square = FALSE) %>%
    st_sf() %>%
    st_filter(base_data)
  
  hex_analysis <- st_join(hex_grid, base_data, join = st_intersects) %>%
    group_by(geometry) %>%
    summarize(
      avg_distance  = mean(distance_num, na.rm = TRUE),
      contains_park = any(Legenda == "Koele plek", na.rm = TRUE),
      .groups       = "drop"
    ) %>%
    mutate(
      plot_distance = ifelse(avg_distance > cfg$max_dist, cfg$max_dist, avg_distance)
      # CHANGED: Removed the rule that overrode park grids to NA, leaving true 0m distances intact
    )
  
  if (city_name == "guangzhou") {
    lst_coverage <- terra::extract(lst_trimmed, terra::vect(hex_analysis), fun = mean, na.rm = TRUE)
    hex_analysis <- hex_analysis %>%
      mutate(lst_check = lst_coverage[, 2]) %>%
      filter(!is.na(lst_check) & !is.nan(lst_check))
  }
  
  # 5. Generate and Export Plots
  map_bbox <- st_bbox(city_outline)
  
  p <- ggplot() +
    geom_spatraster_contour_filled(data = lst_trimmed, alpha = 0.5, breaks = lst_breaks) +
    scale_fill_brewer(palette = "YlOrRd", name = "LST (°C)", direction = 1) +
    
    ggnewscale::new_scale_fill() +
    
    geom_sf(data = hex_analysis, aes(fill = plot_distance), alpha = 0.35, color = "white", linewidth = 0.01) +
    # CHANGED: Removed na.value = "#006d2c" so it scales cleanly down to 0 using the standard BuPu gradient
    scale_fill_distiller(palette = "BuPu", direction = 1, name = "Avg Walk Distance\nto Green (m)", limits = c(0, cfg$max_dist)) +
    
    geom_sf(data = hex_analysis %>% filter(avg_distance > cfg$worst_dist), fill = NA, color = "#333333", linewidth = 0.5) +
    geom_sf(data = city_outline, fill = NA, color = "black", linewidth = 0.8) +
    coord_sf(xlim = c(map_bbox[["xmin"]], map_bbox[["xmax"]]), ylim = c(map_bbox[["ymin"]], map_bbox[["ymax"]]), expand = TRUE) +
    theme_void() +
    labs(title = paste(cfg$name, "Residential Climate Vulnerability Hotspots"), subtitle = "Walking distance to green spaces overlaid on Land Surface Temperature (LST)", caption = cfg$caption) +
    theme(plot.title = element_text(face = "bold", size = 14), legend.position = "right")
  
  print(p)
  ggsave(cfg$plot_output, plot = p, width = 10, height = 8, dpi = 300)
}