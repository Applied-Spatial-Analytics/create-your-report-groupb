# THIS IS ALL GEMINI FOR NOW :)

import pandas as pd
import json

# 1. Inlezen van de metadata (JSON) om de buurtcodes naar namen te vertalen
with open('D-85618NED.json', 'r') as f:
    metadata = json.load(f)

# Maak een dictionary van Code -> Naam
code_to_name = {item['Identifier']: item['Title'] for item in metadata['Dimensions'][0]['CodeList']}

# 2. Inlezen van de data (CSV)
df = pd.read_csv('Observations.csv', sep=';')

# 3. Filteren op Rotterdam (BU0599) en Gemiddeld inkomen (M000223)
rotterdam_income = df[
    (df['WijkenEnBuurten'].str.startswith('BU0599')) &
    (df['Measure'] == 'M000223')
].copy()

# 4. Namen toevoegen en kolommen opschonen
rotterdam_income['Buurtnaam'] = rotterdam_income['WijkenEnBuurten'].map(code_to_name)
result = rotterdam_income[['WijkenEnBuurten', 'Buurtnaam', 'Value']].copy()
result.columns = ['Buurtcode', 'Buurtnaam', 'Gemiddeld_Inkomen_x1000']

# 5. Sorteren en opslaan
result = result.sort_values('Buurtnaam')
result.to_csv('inkomen_per_buurt_rotterdam.csv', index=False)