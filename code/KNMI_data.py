import requests
import pandas as pd
import os

API_KEY = "eyJvcmciOiI1ZTU1NGUxOTI3NGE5NjAwMDEyYTNlYjEiLCJpZCI6IjlhNjg4Y2RmYmJhZDQxMDdiNjAzYWNhNWMxNWI0OTIzIiwiaCI6Im11cm11cjEyOCJ9"
DATASET_NAME = "hourly-in-situ-meteorological-observations-validated"
DATASET_VERSION = "1.0"
DOWNLOAD_DIR = "./knmi_data"

os.makedirs(DOWNLOAD_DIR, exist_ok=True)

start_date = "2025-07-15 00:00"
end_date = "2025-07-24 23:00"

date_range = pd.date_range(start=start_date, end=end_date, freq="h")

headers = {
    "Authorization": API_KEY
}

for dt in date_range:
    date_str = dt.strftime("%Y%m%d")
    hour_str = dt.strftime("%H")
    filename = f"hourly-observations-validated-{date_str}-{hour_str}.nc"

    url_endpoint = f"https://api.dataplatform.knmi.nl/open-data/v1/datasets/{DATASET_NAME}/versions/{DATASET_VERSION}/files/{filename}/url"

    response = requests.get(url_endpoint, headers=headers)

    if response.status_code == 200:
        download_url = response.json().get("temporaryDownloadUrl")

        file_path = os.path.join(DOWNLOAD_DIR, filename)
        file_response = requests.get(download_url)

        with open(file_path, "wb") as f:
            f.write(file_response.content)

        print(f"Gedownload: {filename}")
    else:
        print(f"Fout bij {filename}: {response.status_code} - {response.text}")

print("Alle bestanden zijn binnengehaald!")