import geopandas as gpd
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
# ------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------
gpkg_file = "Rotterdam_data/Liveablility/Neighborhood_groen_netwerk_with_LST.gpkg"  # Path to your GeoPackage file
layer_name = "neighborhood_groen_netwerk"  # Set layer name if needed

# ------------------------------------------------------------------
# Read GeoPackage
# ------------------------------------------------------------------
if layer_name:
    gdf = gpd.read_file(gpkg_file, layer=layer_name)
else:
    gdf = gpd.read_file(gpkg_file)

# ------------------------------------------------------------------
# Display basic information
# ------------------------------------------------------------------
print("Number of records:", len(gdf))
print("Columns:")
print(gdf.columns)

# ------------------------------------------------------------------
# Store attributes in a Pandas DataFrame
# ------------------------------------------------------------------
df = pd.DataFrame(gdf.drop(columns="geometry"))

print("\nFirst rows:")
print(df.head())

# ------------------------------------------------------------------
# Convert to NumPy array (optional)
# ------------------------------------------------------------------
numpy_table = df.to_numpy()

print("\nShape of NumPy array:", numpy_table.shape)
print(numpy_table[:5])

plt.figure(figsize=(10, 6))
plt.scatter(df['LSTmean'], df['spatial_justice_index'], alpha=0.5)
plt.title('Relationship between Land Surface Temperature and Spatial Justice Index')
plt.xlabel('Land Surface Temperature (LSTmean)')
plt.ylabel('Spatial Justice Index')
plt.grid(True)
plt.show()