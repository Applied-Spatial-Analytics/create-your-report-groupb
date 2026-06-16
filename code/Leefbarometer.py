import pandas as pd

# 1. Load the original dataset
file_path = "C:/Users/annas/create-your-report-groupb/Liveablility/Leefbaarometer-scores_buurten.csv"
df = pd.read_csv(file_path)

# 2. Find the most recent year in the dataset
most_recent_year = df['jaar'].max()

# 3. Filter for Rotterdam (wk_code starts with 'WK0599') and the most recent year
# Rotterdam's official CBS municipality code is 0599
rotterdam_latest_df = df[
    (df['bu_code'].str.startswith('BU0599', na=False)) &
    (df['jaar'] == most_recent_year)
]

# 4. Save the extracted data to a new CSV file
output_file = "C:/Users/annas/create-your-report-groupb/Liveablility/rotterdam_liveability_2024.csv"
rotterdam_latest_df.to_csv(output_file, index=False)

print(f"Successfully extracted {len(rotterdam_latest_df)} neighborhoods for Rotterdam.")
print(f"Saved the output to '{output_file}'")