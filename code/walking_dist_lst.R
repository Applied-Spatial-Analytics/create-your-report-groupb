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
    outline_file = here("data/rotterdam/rotterdam_outline.gpkg"),
    input_file   = here("data/rotterdam/bag_rotterdam_woonfunctie.gpkg"),
    dist_file    = here("data/rotterdam/afstand_tot_koelte.gpkg"),
    lst_file     = here("data/rotterdam/lst_rotterdam_hot.tif"),
    max_dist     = 500,
    worst_dist   = 400,
    caption      = "Hexagon resolution: 300m | Border thickness increases with distance to green. Purple = Critical threshold exceeded.",
    plot_output  = "Report/maps/vulnerability_rotterdam.png"
  ),
  guangzhou = list(
    name         = "Guangzhou",
    epsg_target  = 4490,
    outline_file = here("data/guangzhou/GZ_Center_neighborhoods.gpkg"),
    input_file   = here("data/guangzhou/residential_walk_dist.gpkg"),
    dist_file    = NULL,
    lst_file     = here("data/guangzhou/lst_guangzhou_hot.tif"),
    max_dist     = 1500,
    worst_dist   = 1500,
    caption      = "Hexagon resolution: 300m | Border thickness increases with distance to green. Purple = Critical threshold exceeded.",
    plot_output  = "Report/maps/vulnerability_guangzhou.png"
  )
)

# -------------------------------------------------------------------------
# Global / Shared LST Break Calculation
# -------------------------------------------------------------------------
message("Calculating a uniform temperature scale across all cities...")
global_mins <- c()
global_maxs <- c()

for (city_name in names(city_configs)) {
  temp_rast <- terra::rast(city_configs[[city_name]]$lst_file)
  global_mins <- c(global_mins, terra::global(temp_rast, "min", na.rm = TRUE)[1,1])
  global_maxs <- c(global_maxs, terra::global(temp_rast, "max", na.rm = TRUE)[1,1])
}

shared_lst_breaks <- pretty(c(min(global_mins), max(global_maxs)), n = 10)
message("Unified Temperature Range: ", min(shared_lst_breaks), "°C to ", max(shared_lst_breaks), "°C")
# -------------------------------------------------------------------------

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
    
    residential <- raw_data %>%
      filter(sapply(gebruiksdoel, function(x) any(grepl("woonfunctie", x, ignore.case = TRUE))))
    
    buildings_joined <- st_join(residential, afstand %>% select(Legenda), join = st_within, left = TRUE)
    
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
    base_data <- grid_res %>%
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
  
  # 4. Grid Generation & Analysis (Preserving Complete Hexagons)
  hex_grid <- st_make_grid(base_data, cellsize = 300, square = FALSE) %>%
    st_sf()
  
  intersecting_indices <- st_intersects(hex_grid, city_outline, sparse = FALSE)
  hex_grid <- hex_grid[intersecting_indices[, 1], ]
  
  hex_analysis <- st_join(hex_grid, base_data, join = st_intersects) %>%
    group_by(geometry) %>%
    summarize(
      avg_distance  = mean(distance_num, na.rm = TRUE),
      contains_park = any(Legenda == "Koele plek", na.rm = TRUE),
      .groups       = "drop"
    ) %>%
    filter(!is.na(avg_distance)) %>%
    mutate(
      plot_distance = ifelse(avg_distance > cfg$max_dist, cfg$max_dist, avg_distance),
      line_type = ifelse(avg_distance > cfg$worst_dist, "dashed", "solid")
    ) %>%
    arrange(avg_distance)
  
  if (city_name == "guangzhou") {
    lst_coverage <- terra::extract(lst_trimmed, terra::vect(hex_analysis), fun = mean, na.rm = TRUE)
    hex_analysis <- hex_analysis %>%
      mutate(lst_check = lst_coverage[, 2]) %>%
      filter(!is.na(lst_check) & !is.nan(lst_check))
  }
  
  # 5. Generate Plots with Border-Based Visualization
  map_bbox <- st_bbox(hex_analysis)
  
  p <- ggplot() +
    # LST Base Layer
    geom_spatraster_contour_filled(data = lst_trimmed, alpha = 0.75, breaks = shared_lst_breaks) +
    scale_fill_brewer(palette = "YlOrRd", name = "LST (°C)", direction = 1) +
    
    # Establish separate scale matrix for Hex elements
    ggnewscale::new_scale_color() +
    
    # Draw Ordered Hexagons
    geom_sf(
      data = hex_analysis,
      fill = NA,
      aes(color = line_type, linewidth = plot_distance),
      linetype = "solid"
    ) +
    # Scale: Linewidth
    scale_linewidth_continuous(
      name = "Walking Distance\nto Green Space",
      limits = c(0, cfg$max_dist),
      range = c(0.4, 1.6),
      labels = function(x) paste0(round(x), "m")
    ) +
    # Scale: Color (Fixed: Explicitly matches break and label vector lengths)
    scale_color_manual(
      name = "Threshold Status",
      values = c("solid" = "#444444", "dashed" = "purple"),
      breaks = "dashed",
      labels = paste0("Critical Threshold (>", cfg$worst_dist, "m)")
    ) +
    
    # City boundary baseline layout over layer stack
    geom_sf(data = city_outline, fill = NA, color = "black", linewidth = 0.9) +
    
    coord_sf(xlim = c(map_bbox[["xmin"]], map_bbox[["xmax"]]), 
             ylim = c(map_bbox[["ymin"]], map_bbox[["ymax"]]), expand = TRUE) +
    theme_void() +
    labs(
      title = paste(cfg$name, "Residential Climate Vulnerability Hotspots"), 
      subtitle = "Hexagonal overlay scaling border thickness by distance | Purple Lines = Critical Distance", 
      caption = cfg$caption
    ) +
    theme(
      plot.title = element_text(face = "bold", size = 14, margin = margin(b = 4)),
      plot.subtitle = element_text(size = 10, color = "#444444", margin = margin(b = 12)),
      legend.position = "right",
      legend.title = element_text(size = 9, face = "bold"),
      legend.text = element_text(size = 8),
      legend.spacing.y = unit(0.2, "cm")
    ) +
    # Keeps legend indicators solid and clear
    guides(
      color = guide_legend(order = 1, override.aes = list(linewidth = 1.2)),
      linewidth = guide_legend(order = 2, override.aes = list(color = "#444444"))
    )
  # 6. Export and Save Plots
  message("Saving plot to: ", cfg$plot_output)
  dir.create(dirname(cfg$plot_output), recursive = TRUE, showWarnings = FALSE)
  
  ggsave(
    filename = cfg$plot_output,
    plot = p,
    width = 11,
    height = 8,
    dpi = 300,
    bg = "white"
  )
}