# install.packages(c("sf", "dplyr", "ggplot2", "scales"x, "here"))

library(sf)
library(dplyr)
library(ggplot2)
library(scales)
library(here)

# Paths for files
gpkg_bestand <- here("data", "rotterdam", "Neighborhood_groen_netwerk.gpkg")
plot_output  <- here("code", "spatial_justice_rotterdam_complete.png")

buurten_sf <- st_read(gpkg_bestand)

# Functions
clean_cbs <- function(x) {
  x <- as.numeric(x)
  ifelse(x < -90000, NA, x)
}

min_max_scale <- function(x) {
  if(all(is.na(x))) return(x)
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

# Prepare data
buurten_ready <- buurten_sf %>%
  mutate(

    fys_num      = clean_cbs(rotterdam_liveability_2024_fys),
    soc_num      = clean_cbs(rotterdam_liveability_2024_soc),
    age65_num    = clean_cbs(percentagePersonen65JaarEnOuder),
    heritage_num = clean_cbs(percentageMetHerkomstlandNederland),
    rent_num     = clean_cbs(percentageHuurwoningen),
    welfare_abs  = clean_cbs(aantalPersonenMetEenAlgBijstandsuitkeringTot),
    inhabitants  = clean_cbs(aantalInwoners),
    green_num    = clean_cbs(gemiddelde_afstand_groen_m),

    # Heritage outside NL
    percentageOutsideNL = 100 - heritage_num,
    # Percentage welfare
    percentageWelfare = ifelse(inhabitants > 0, (welfare_abs / inhabitants) * 100, NA)

  )

# Normalize the data
buurten_scaled <- buurten_ready %>%
  mutate(
    norm_fys       = min_max_scale(fys_num),
    norm_soc       = min_max_scale(soc_num),
    norm_65plus    = min_max_scale(age65_num),
    norm_outside_nl = min_max_scale(percentageOutsideNL),
    norm_rent      = min_max_scale(rent_num),
    norm_welfare  = min_max_scale(percentageWelfare),
    norm_green      = min_max_scale(green_num)
  )

weights <- c(
  fys        = 2,
  soc        = 1,
  age65      = 0.5,
  outside_nl = 0.5,
  rent       = 1,
  welfare    = 0.5,
  green      = 2
)

# Calculate Spatial Justice Index
buurten_index <- buurten_scaled %>%
  mutate(
    # Positive indicators
    fys_score       = norm_fys,
    soc_score       = norm_soc,

    # Negative indicators are inverted
    `65plus_score`  = 1 - norm_65plus,
    outside_nl_score = 1 - norm_outside_nl,
    rent_score      = 1 - norm_rent,
    welfare_score  = 1 - norm_welfare,
    green_score      = 1 - norm_green
  ) %>%
  rowwise() %>%

  mutate(
    # Weighted average
    scores_vector = list(c(fys_score, soc_score, `65plus_score`,
                           outside_nl_score, rent_score, welfare_score, green_score)),
    aantal_na = sum(is.na(unlist(scores_vector))),

    spatial_justice_index = ifelse(
      is.na(inhabitants) | inhabitants <= 50 | aantal_na >= 4,
      NA,
      sum(unlist(scores_vector) * weights, na.rm = TRUE) / sum(weights[!is.na(unlist(scores_vector))])
    )
  ) %>%
  ungroup()

# Plot the map

p <- ggplot(data = buurten_index) +
  geom_sf(aes(fill = spatial_justice_index), color = "white", linewidth = 0.05) +

  scale_fill_viridis_c(
    option = "plasma",
    name = "Spatial Justice\nIndex",
    labels = label_number(accuracy = 0.01),
    na.value = "grey80"
  ) +
  labs(
    title = "Spatial Justice Index per Neighborhood in Rotterdam (Complete Model)",
    subtitle = "Comprehensive index of liveability, demography, and socioeconomic status",
    caption = paste0("Source: Leefbaarometer 2024 & CBS Buurtgegevens")
  ) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.text = element_blank(),
    plot.title = element_text(face = "bold", size = 14),
    subtitle = element_text(size = 11, color = "grey30"),
    legend.position = "right"
  )

print(p)
ggsave(plot_output, plot = p, width = 10, height = 8, dpi = 300)


buurten_gpkg_klaar <- buurten_index %>%
  select(any_of(names(buurten_sf)), spatial_justice_index)

st_write(
  obj = buurten_gpkg_klaar,
  dsn = gpkg_bestand,
  layer = "Neighborhood_groen_netwerk",
  delete_layer = TRUE
)

# ggsave("spatial_justice_rotterdam.png", width = 10, height = 8, dpi = 300)
