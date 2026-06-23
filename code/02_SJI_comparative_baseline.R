# install.packages(c("sf", "dplyr", "ggplot2", "scales", "here"))

library(sf)
library(dplyr)
library(ggplot2)
library(scales)
library(here)

city_configs <- list(
  rotterdam = list(
    output_path   = "../data/rotterdam/Liveablility/Neighborhood_groen_netwerk_with_LST.gpkg",
    file_path     = "../data/rotterdam/Liveablility/Neighborhood_groen_netwerk_with_LST.gpkg",
    col_age       = "percentagePersonen65JaarEnOuder",
    col_female    = "PercentageVrouwen",
    col_density   = "bevolkingsdichtheidInwonersPerKm2",
    col_pop       = "aantalInwoners",
    col_lst       = "LSTmean",
    col_dtg       = "gemiddelde_afstand_groen_m",
    title         = "Spatial Justice Index per Neighborhood in Rotterdam",
    caption       = "Source: Leefbaarometer 2024 & CBS Buurtgegevens",
    plot_output   = "spatial_justice_rotterdam.png"
  ),
  # Change these things to guangzhou thing
  guangzhou = list(
    file_path     = "../data/guangzhou/GuangzhouFull.gpkg",
    output_path   = "../data/guangzhou/GuangzhouFull.gpkg",
    col_age       = "Over65Percentagemean",
    col_female    = "FemalePercentagemean",
    col_density   = "PopDensity",
    col_pop       = "PopulationKanton_Pop2022",
    col_lst       = "LSTmean",
    col_dtg       = "walk_dist_to_green_m_mean",
    title         = "Spatial Justice Index per Block in Guangzhou",
    caption       = "Source: OpenStreetMap & WorldPop",
    plot_output   = "spatial_justice_guangzhou.png"
  )
)

clean_cbs <- function(x) {
  x <- as.numeric(x)
  ifelse(x < -90000, NA, x)
}

min_max_scale <- function(x) {
  if(all(is.na(x))) return(x)
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

weights <- c(age = 0.5, fem = 0.3, dens = 1, lst = 1, dtg = 1)

for (city_name in names(city_configs)) {
  cfg <- city_configs[[city_name]]

  # Load data
  city_sf <- st_read(cfg$file_path)

  # Prepare data
  city_ready <- city_sf %>%
    mutate(
      age65_num   = clean_cbs(.data[[cfg$col_age]]),
      female_num  = clean_cbs(.data[[cfg$col_female]]),
      pop_density = clean_cbs(.data[[cfg$col_density]]),
      pop_count   = clean_cbs(.data[[cfg$col_pop]]),
      lst_mean    = clean_cbs(.data[[cfg$col_lst]]),
      dtg_mean    = clean_cbs(.data[[cfg$col_dtg]])
    )

  # Normalize
  city_scaled <- city_ready %>%
    mutate(
      norm_age  = min_max_scale(age65_num),
      norm_fem  = min_max_scale(female_num),
      norm_dens = min_max_scale(pop_density),
      norm_lst  = min_max_scale(lst_mean),
      norm_dtg  = min_max_scale(dtg_mean)
    )

  # Calculate index
  city_index <- city_scaled %>%
    mutate(
      `65plus_score` = 1 - norm_age,
      fem_score      = 1 - norm_fem,
      dens_score     = 1 - norm_dens,
      lst_score      = 1 - norm_lst,
      dtg_score      = 1 - norm_dtg
    ) %>%
    rowwise() %>%
    mutate(
      scores_vector = list(c(`65plus_score`, fem_score, dens_score, lst_score, dtg_score)),
      aantal_na     = sum(is.na(unlist(scores_vector))),

      spatial_justice_index = ifelse(
        is.na(pop_count) | pop_count <= 50 | aantal_na > 1,
        NA,
        sum(unlist(scores_vector) * weights, na.rm = TRUE) / sum(weights[!is.na(unlist(scores_vector))])
      )
    ) %>%
    ungroup()

  # Plot map
  p <- ggplot(data = city_index) +
    geom_sf(aes(fill = spatial_justice_index), color = "white", linewidth = 0.05) +
    scale_fill_viridis_c(
      option = "plasma",
      name = "Spatial Justice\nIndex",
      labels = label_number(accuracy = 0.01),
      na.value = "grey80"
    ) +
    labs(
      title = cfg$title,
      caption = cfg$caption
    ) +
    theme_minimal() +
    theme(
      panel.grid = element_blank(),
      axis.text = element_blank(),
      plot.title = element_text(face = "bold", size = 14),
      legend.position = "right"
    )
  # Print plot
  print(p)
  ggsave(cfg$plot_output, plot = p, width = 10, height = 8, dpi = 300)

  # Save to GeoPackage
  city_gpkg_klaar <- city_index %>%
    select(any_of(names(city_sf)), spatial_justice_index)

  st_write(
    obj = city_gpkg_klaar,
    dsn = cfg$output_path,
    layer = st_layers(cfg$file_path)$name[1],
    delete_layer = TRUE
  )
}
