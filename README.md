# Comparative Spatial Justice and Urban Heat Resilience: Rotterdam vs. Guangzhou

This repository contains the computational pipeline and analytical workflows for evaluating the relationship between urban green infrastructure allocation, socioeconomic vulnerability, and Land Surface Temperature (LST).

## Repository Architecture

To replicate the study, your local directory must be structured as follows. Create a `/data` folder in your root directory.

```text
├── code/
│   ├── 01_SJI_complete_rotterdam.R   # Full-resolution SJI for Rotterdam
│   ├── 02_SJI_comparative_baseline.R # Simplified, harmonized SJI for both cities
│   └── 03_network_thermal_analysis.R # Network routing, hex-aggregation, and UHI plotting
├── data/                             # User-created local data directory
│   ├── rotterdam/                    # Place downloaded Rotterdam files here
│   └── guangzhou/                    # Place downloaded Guangzhou files here
└── README.md                         # Project documentation
```

## Data Requirements & Acquisition

Because raw data are not hosted in this repository, you must download the source files directly from the providers below and place them into their respective subfolders within /data.


**1. Rotterdam Data**
- Socioeconomic Indicators: Download the neighborhood data from the [CBS StatLine Portaal](https://www.cbs.nl/nl-nl/cijfers/detail/86165NED).

- Physical Livability: Download the open dataset from the [Leefbaarometer 2024 Open Data Portal](https://www.leefbaarometer.nl/page/Opendata).

- Building Footprints (BAG): Use the [PDOK Services Plugin](https://plugins.qgis.org/plugins/pdokservicesplugin/) in QGIS to download building functions and layers for the Rotterdam study area.

- Network & Green Infrastructure: Use the [QuickOSM Plugin](https://plugins.qgis.org/plugins/QuickOSM/) in QGIS to download keys highway and green areas for Rotterdam.

**2. Guangzhou Data**

- Demographic Density: Download the gridded population raster from the [WorldPop Open Spatial Repository](https://www.worldpop.org/datacatalog/).

- Network & Green Infrastructure: Use the [QuickOSM Plugin](https://plugins.qgis.org/plugins/QuickOSM/) in QGIS to extract building footprints, residential land use, pedestrian paths, and green spaces from OpenStreetMap.

**3. Data available for both Rotterdam and Guangzhou**

- Create an account in USGS Earth Explorer (https://earthexplorer.usgs.gov/)

- Set an area around Rotterdam/Guangzhou with small percentage of cloud coverage (e.g., < 40%)

- Set the search criteria to Landsat 8/9 Collection 2 Level-2 Surface Temperature satellite imagery

- Download the ST_B10 file from the Surface Temperature data package

## Execution Workflow

All scripts are written in R and utilize relative paths Ensure your working directory is set to the project root before executing.

1. Pre-processing: Download and crop all spatial data layers (including LST rasters) to your respective city administrative boundaries.

2. Run Spatial Justice Index:

- To analyze Rotterdam with its full suite of local indicators, execute `code/01_SJI_complete_rotterdam.R`.

- To run the comparative model across both cities, execute `code/02_SJI_comparative_baseline.R`.

3. Run Spatial Routing and Thermal Overlays: Execute `code/03_network_thermal_analysis.R`. This script processes the pedestrian networks, calculates distance thresholds, aggregates data into spatial hexagons, and generates final correlation plots against the LST layers.
