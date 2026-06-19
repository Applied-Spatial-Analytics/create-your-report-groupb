import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import seaborn as sns

def FilterData(write = False):
    # Inlezen van de data (CSV)
    df = pd.read_csv('Wijk_buurt_data_cbs_2025/Observations.csv', sep=';')

    # Unieke buurten in Rotterdam (BU0599)
    UniekeBuurten = df['WijkenEnBuurten'].unique()
    UniekeBuurtenRotterdam = []
    for buurt in UniekeBuurten:
        if buurt.startswith('BU0599'):
            UniekeBuurtenRotterdam.append(buurt)

    # Filteren op Rotterdam (BU0599) en Gemiddeld inkomen (M000223)
    rotterdam_income = df[df['WijkenEnBuurten'].isin(UniekeBuurtenRotterdam) & df['Measure'].eq('M001642')]

    # Weergave van de gefilterde data
    print(rotterdam_income[['WijkenEnBuurten', 'Measure', 'Value']])

    # Opslaan van de gefilterde data naar een nieuw CSV-bestand
    if write:
        rotterdam_income.to_csv('Rotterdam_Gemiddeld_WOZ-Waarden.csv', index=False)

    return rotterdam_income[['WijkenEnBuurten', 'Value']]

def GPKG_to_CSV():
    # Inlezen van de data (GPKG)
    df = gpd.read_file('datasets_klimaateffectatlas/GevoelstemperatuurBuurt_2022.gpkg')

    df[['buurtcode', '_mean']].to_csv('GevoelstemperatuurBuurt_2022.csv', index=False)

    return df[['buurtcode', '_mean']]

def PlotData(mean_woz, mean_temp):
    x = mean_woz['WijkenEnBuurten']
    y = mean_woz['Value']
    
    mean_temp.sort_values('buurtcode', inplace=True)

    z = []
    for i in range(len(mean_temp)):
        if mean_temp['buurtcode'][i] in x.values:
            z.append(mean_temp['_mean'][i])
            

    plt.figure(figsize=(10, 6))
    plt.plot(x, y, linestyle='-', color='b')
    plt.plot(x, z, linestyle='-', color='r')
    plt.title('Gemiddelde WOZ-waarden in Rotterdam Tegen Gevoelstemperatuur')
    plt.xlabel('Buurten')
    plt.ylabel('Gemiddelde WOZ-waarde')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

def main():
    mean_woz = FilterData()
    mean_temp = GPKG_to_CSV()
    PlotData(mean_woz, mean_temp)

if __name__ == "__main__":
    main()