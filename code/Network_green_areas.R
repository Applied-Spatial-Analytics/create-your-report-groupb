library(sf)
library(dplyr)
library(osmdata)
library(sfnetworks)
library(tidygraph)
library(purrr)

# Read data
buurten <- st_read("../data/rotterdam/Liveablility/Neighborhood_data.gpkg")
gebouwen <- st_read("../data/rotterdam/Liveablility/Buildings_Rotterdam.gpkg") %>%
  filter(grepl("woonfunctie", gebruiksdoel, ignore.case = TRUE))
groen_raw <- st_read("../data/rotterdam/Liveablility/Green_areas_OSM.gpkg")

target_crs <- 28992
buurten <- st_transform(buurten, target_crs)
gebouwen <- st_transform(gebouwen, target_crs)
groen_rd <- st_transform(groen_raw, target_crs)

roads <- st_read("../data/rotterdam/Liveablility/Roads_Rotterdam.gpkg") %>%
  st_transform(target_crs) %>%
  st_geometry() %>%
  st_cast("LINESTRING")

groen_filtered <- groen_rd %>%
  mutate(
    oppervlakte_m2 = as.numeric(st_area(.)),
    omtrek_m       = as.numeric(st_perimeter(.))
  ) %>%
  filter(oppervlakte_m2 >= 1000) %>%
  mutate(shape_index = omtrek_m / (2 * pi * sqrt(oppervlakte_m2 / pi))) %>%
  filter(shape_index < 2.2)

# Origins & Destinations
st_agr(gebouwen) <- "constant"
gebouwen_punten <- gebouwen %>%
  st_centroid() %>%
  st_join(buurten %>% select(buurtcode))

groen_randen <- st_cast(groen_filtered, "MULTILINESTRING")
groen_punten <- st_centroid(groen_randen)

netwerk <- as_sfnetwork(roads, directed = FALSE) %>%
  activate("edges") %>%
  mutate(weight = edge_length())

netwerk <- netwerk %>%
  activate("nodes") %>%
  filter(group_components() == 1)

# Distance to Green
afstandsmatrix <- st_network_cost(netwerk, from = gebouwen_punten, to = groen_punten)

gebouwen_punten$afstand_tot_groen <- apply(afstandsmatrix, 1, min, na.rm = TRUE)

# Aggregate to neighborhood level
buurt_groen_afstand <- gebouwen_punten %>%
  st_drop_geometry() %>%
  group_by(buurtcode) %>%
  summarise(
    gemiddelde_afstand_groen_m = mean(afstand_tot_groen, na.rm = TRUE),
    aantal_gebouwen_meegewogen = n()
  )

# Join the result with the neighborhood file
buurten_resultaat <- buurten %>%
  left_join(buurt_groen_afstand, by = "buurtcode")

#
st_write(buurten_resultaat, "../data/rotterdam/Liveablility/Neighborhood_groen_netwerk.gpkg", delete_layer = TRUE)

# Korte inspectie van de eerste resultaten in de console
print(head(buurten_resultaat %>% select(buurtnaam, gemiddelde_afstand_groen_m)))
