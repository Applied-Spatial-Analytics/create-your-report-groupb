# install.packages(c("sf", "dplyr", "ggplot2", "scales"))

library(sf)
library(dplyr)
library(ggplot2)
library(scales)

# Read data from the GeoPackage file
gpkg_bestand <- "data/KantonData.gpkg"
buurten_sf <- st_read(gpkg_bestand)

clean_cbs <- function(x) {
  x <- as.numeric(x)
  ifelse(x < -90000, NA, x)
}

# Prepare data
buurten_ready <- buurten_sf %>%
  mutate(

    #fys_num      = clean_cbs(rotterdam_liveability_2024_fys),
    #soc_num      = clean_cbs(rotterdam_liveability_2024_soc),
    #age65_num    = clean_cbs(percentagePersonen65JaarEnOuder),
    #heritage_num = clean_cbs(percentageMetHerkomstlandNederland),
    #rent_num     = clean_cbs(percentageHuurwoningen),
    #welfare_abs  = clean_cbs(aantalPersonenMetEenAlgBijstandsuitkeringTot),
    #inhabitants  = clean_cbs(aantalInwoners),
    #green_num    = clean_cbs(gemiddelde_afstand_groen_m),
#
    ## Heritage outside NL
    #percentageOutsideNL = 100 - heritage_num,
#
    ## Percentage welfare
    #percentageWelfare = ifelse(inhabitants > 0, (welfare_abs / inhabitants) * 100, NA)
    
    age65_num = clean_cbs(Over65Percentagemean),
    female_num = clean_cbs(FemalePercentagemean),
    pop_density = clean_cbs(PopDensity)

  )

# Normalize data function
min_max_scale <- function(x) {
  if(all(is.na(x))) return(x)
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

# Actually normalize the data
buurten_scaled <- buurten_ready %>%
  mutate(
    #norm_fys       = min_max_scale(fys_num),
    #norm_soc       = min_max_scale(soc_num),
    #norm_65plus    = min_max_scale(age65_num),
    #norm_outside_nl = min_max_scale(percentageOutsideNL),
    #norm_rent      = min_max_scale(rent_num),
    #norm_welfare  = min_max_scale(percentageWelfare),
    #norm_green      = min_max_scale(green_num)
    
    norm_age = min_max_scale(age65_num),
    norm_fem = min_max_scale(female_num),
    norm_dens = min_max_scale(pop_density)
  )

# Calculate Spatial Justice Index
buurten_index <- buurten_scaled %>%
  mutate(
    ## Positive indicators
    #fys_score       = norm_fys,
    #soc_score       = norm_soc,
#
    ## Negative indicators are inverted
    `65plus_score`  = 1 - norm_age,
    fem_score = 1 - norm_fem,
    dens_score = 1 - norm_dens
    #outside_nl_score = 1 - norm_outside_nl,
    #rent_score      = 1 - norm_rent,
    #welfare_score  = 1 - norm_welfare,
    #green_score      = 1 - norm_green

    ) %>%
    rowwise() %>%
    mutate(
    # Weighted average
    scores_vector = list(c(`65plus_score`,
                             fem_score, dens_score)),
    aantal_na = sum(is.na(unlist(scores_vector))),

    spatial_justice_index = ifelse(aantal_na >= 4,
                                   NA,
                                   mean(unlist(scores_vector), na.rm = TRUE))
  ) %>%
  ungroup()

# Plot the map
ggplot(data = buurten_index) +
  geom_sf(aes(fill = spatial_justice_index), color = "white", linewidth = 0.05) +

  scale_fill_viridis_c(
    option = "plasma",
    name = "Spatial Justice\nIndex",
    labels = label_number(accuracy = 0.01),
    na.value = "grey80" # Color if all data is missing in the neighborhood
  ) +

  # Formatting of the map
  labs(
    title = "Spatial Justice Index per Neighborhood in Guangzhou",
    subtitle = "Combined index of liveability, demography and social-economic status",
    caption = "Index is between 0 (least favorable) and 1 (most favorable)\nNeigborhoods with few avaialable measurements are grey\nSource: WorldPop.org"
  ) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.text = element_blank(),
    plot.title = element_text(face = "bold", size = 14),
    #subtitle = element_text(size = 11, color = "grey30"),
    legend.position = "right"
  )

buurten_gpkg_klaar <- buurten_index %>%
  select(any_of(names(buurten_sf)), spatial_justice_index)

st_write(
  obj = buurten_gpkg_klaar,
  dsn = gpkg_bestand,
  layer = "spatial_justice_index",
  delete_layer = TRUE # Overschrijft de laag als je de code nogmaals runt
)

# ggsave("spatial_justice_rotterdam.png", width = 10, height = 8, dpi = 300)
