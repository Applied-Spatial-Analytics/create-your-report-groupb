import rasterio
from rasterio.features import geometry_mask
import geopandas as gpd
import numpy as np


def generate_cdsm(dsm_path, dem_path, bag_path, output_path, buffer_dist=1.0, height_thresh=2.5):
    """
    Generates a Canopy Digital Surface Model (CDSM) by subtracting a DEM from a DSM
    and masking out building footprints.
    """

    # 1. Load the rasters as masked arrays to handle AHN NoData values cleanly
    with rasterio.open(dsm_path) as src_dsm, rasterio.open(dem_path) as src_dem:
        # Verify alignment
        if src_dsm.shape != src_dem.shape or src_dsm.transform != src_dem.transform:
            raise ValueError("DSM and DEM dimensions or transforms do not match.")

        # Read data, masking out NoData values automatically
        dsm = src_dsm.read(1, masked=True)
        dem = src_dem.read(1, masked=True)
        meta = src_dsm.meta.copy()
        transform = src_dsm.transform
        bounds = src_dsm.bounds

    # 2. Calculate nDSM (Height of all above-ground features)
    ndsm = dsm - dem

    # Fill the masked NoData areas back with 0 for the final output
    ndsm = ndsm.filled(0)

    # 3. Load BAG buildings, using the raster bounds to only load what is necessary
    print("Loading and clipping BAG data...")
    bag_gdf = gpd.read_file(bag_path, bbox=bounds)

    # Buffer the polygons to handle roof overhangs
    print(f"Buffering buildings by {buffer_dist}m...")
    bag_buffered = bag_gdf.geometry.buffer(buffer_dist)

    # 4. Create a boolean mask of the buildings (True where pixels fall INSIDE a building)
    print("Rasterizing building mask...")
    building_mask = geometry_mask(
        geometries=bag_buffered,
        out_shape=ndsm.shape,
        transform=transform,
        invert=True  # invert=True makes inside polygons True, outside False
    )

    # 5. Apply the masks
    print("Applying thresholds...")
    # Zero out building pixels
    ndsm[building_mask] = 0

    # Zero out noise, cars, and low vegetation (below the height threshold)
    ndsm[ndsm < height_thresh] = 0

    # Ensure no negative values remain from slight DEM/DSM interpolation differences
    ndsm[ndsm < 0] = 0

    # 6. Write the final CDSM to disk
    print("Writing output CDSM...")
    meta.update(
        dtype=rasterio.float32,
        nodata=0.0,
        compress='deflate'  # Highly recommended to compress large AHN GeoTIFFs
    )

    with rasterio.open(output_path, 'w', **meta) as dst:
        dst.write(ndsm.astype(rasterio.float32), 1)

    print(f"CDSM successfully saved to {output_path}")


# --- Execution Example ---
if __name__ == "__main__":
    dsm_file = "path/to/AHN4_DSM_Rotterdam.tif"
    dem_file = "path/to/AHN4_DEM_Rotterdam.tif"
    bag_file = "path/to/BAG_panden_Rotterdam.gpkg"  # GeoPackage or Shapefile
    out_file = "path/to/Rotterdam_CDSM.tif"

    generate_cdsm(
        dsm_path=dsm_file,
        dem_path=dem_file,
        bag_path=bag_file,
        output_path=out_file,
        buffer_dist=1.0,  # 1 meter buffer for overhangs
        height_thresh=2.5  # Drop anything shorter than 2.5 meters
    )