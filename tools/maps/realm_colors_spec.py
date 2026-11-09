"""The colour each real place reads in on Warhold's real-world maps (the owner, 2026-11-08: colours true to what the
country stands for, never two alike). A country's colour is its flag's or its traditional map colour; a state or
province is drawn in a shade of its country's (PARENT). tools/maps/realm_colors.py writes Data/RealmColors.luau from this,
shading siblings apart and nudging any two realms on one map that read alike."""

COUNTRY = {
    # the British Isles and the West
    "England": "#c8102e", "Scotland": "#1f4e9c", "Wales": "#2e8b3e", "Ireland": "#169b62",
    "France": "#2c4f9e", "Brittany": "#3d3d55", "Netherlands": "#ff7f00", "Germany": "#5a5a5a",
    "Switzerland": "#d52b1e", "Austria": "#e8e0d0", "Italy": "#3a9d5d", "Spain": "#e8b923", "Portugal": "#046a38",
    # the North
    "Norway": "#ba0c2f", "Sweden": "#006aa7", "Denmark": "#c60c30", "Finland": "#4a7fc1", "Iceland": "#02529c",
    "Greenland": "#e57373",
    # the East of Europe
    "Poland": "#dc143c", "Ukraine": "#ffd500", "Belarus": "#4aa564", "Lithuania": "#006a44", "Latvia": "#9e3039",
    "Estonia": "#0072ce", "Czechia": "#11457e", "Slovakia": "#0b4ea2", "Hungary": "#436f4d", "Romania": "#002b7f",
    "Bulgaria": "#00966e", "Serbia": "#c6363c", "Croatia": "#e03a3e", "Bosnia and Herzegovina": "#f2c500",
    "Greece": "#0d5eaf", "Russia": "#3f7a3a",
    # the Near East and North Africa
    "Türkiye": "#e30a17", "Georgia": "#f0f0f0", "Armenia": "#f2a800", "Iran": "#239f40", "Iraq": "#7a1712",
    "Syria": "#4d4d4d", "Saudi Arabia": "#006c35", "Yemen": "#ce1126", "Oman": "#db6a1b", "Egypt": "#c09300",
    "Libya": "#2a7a3e", "Tunisia": "#e70013", "Algeria": "#007a3a", "Morocco": "#c1272d",
    # Africa
    "Mauritania": "#00a95c", "Senegal": "#00853f", "Mali": "#fcd116", "Niger": "#e05206", "Burkina Faso": "#ef2b2d",
    "Ivory Coast": "#f77f00", "Ghana": "#006b3f", "Liberia": "#002868", "Nigeria": "#008751", "Chad": "#002664",
    "Sudan": "#d21034", "South Sudan": "#0f47af", "Ethiopia": "#078930", "Somalia": "#4189dd", "Kenya": "#922529",
    "Uganda": "#fcdc04", "Tanzania": "#1eb53a", "Cameroon": "#007a5e", "Central African Republic": "#003082",
    "Congo": "#009543", "DR Congo": "#007fff", "Angola": "#cc092f", "Zambia": "#198a00", "Zimbabwe": "#ffd200",
    "Mozambique": "#007168", "Botswana": "#6da9d2", "Namibia": "#003580", "South Africa": "#007749",
    "Madagascar": "#fc3d32",
    # Asia
    "Afghanistan": "#3a3a3a", "Pakistan": "#01411c", "India": "#ff9933", "Nepal": "#dc143c", "Tibet": "#8b4513",
    "Xinjiang": "#4aa3c6", "Mongolia": "#7ec8e3", "Kazakhstan": "#00afca", "Kyrgyzstan": "#e8112d",
    "Tajikistan": "#c47a00", "Turkmenistan": "#00843d", "Uzbekistan": "#0099b5", "China": "#de2910",
    "North Korea": "#024fa2", "Japan": "#bc002d", "Myanmar": "#fecb00", "Thailand": "#2d2a6a", "Laos": "#ce1126",
    "Vietnam": "#da251d", "Malaysia": "#010066", "Indonesia": "#ce1126", "Philippines": "#0038a8",
    "Papua New Guinea": "#8b1a1a", "Australia": "#e5a823", "New Zealand": "#00247d",
    # the Americas
    "United States": "#3c5a99", "Canada": "#d52b1e", "Mexico": "#006847", "Cuba": "#002a8f", "Guatemala": "#4997d0",
    "Honduras": "#0073cf", "Costa Rica": "#002b7f", "Colombia": "#fcd116", "Venezuela": "#cf142b",
    "Ecuador": "#ffdd00", "Suriname": "#377e3f", "Brazil": "#009c3b", "Peru": "#d91023", "Bolivia": "#007934",
    "Paraguay": "#d52b1e", "Uruguay": "#7b9fd4", "Chile": "#0039a6", "Argentina": "#75aadb",
    # the ice
    "Antarctica": "#d8e2ea",
    # (2026-11-08: today's grey land)
    "Rwanda": "#20603d", "Kuwait": "#007a3d", "Cape Verde": "#003893", "Mauritius": "#1a206d", "Western Sahara": "#6b8e23", "United Arab Emirates": "#00732f", "Jordan": "#007a3d", "Israel": "#0038b8", "Cyprus": "#d57800", "Belgium": "#fdda24", "Moldova": "#0046ae", "Albania": "#e41e20", "Guyana": "#009e49", "Panama": "#005293", "Bahamas": "#00abc9", "Haiti": "#00209f", "Dominican Republic": "#002d62", "Jamaica": "#009b3a", "Nicaragua": "#0067c6", "El Salvador": "#0f47af", "Falkland Islands": "#012169", "Trinidad and Tobago": "#ce1126", "Fiji": "#68bfe5",
    # (2026-11-08: today's grey land)
    
}

# A state or province: the country whose colour it takes a shade of.
PARENT = {
    # United States
    "Alaska": "United States", "Arizona": "United States", "California": "United States", "Colorado": "United States",
    "Connecticut": "United States", "Florida": "United States", "Iowa": "United States", "Michigan": "United States",
    "Minnesota": "United States", "Montana": "United States", "New Mexico": "United States", "New York": "United States",
    "North Carolina": "United States", "Tennessee": "United States", "Texas": "United States", "Utah": "United States",
    "Washington": "United States", "West Texas": "United States", "Wyoming": "United States",
    "Kenai Peninsula": "United States",
    # Canada
    "Alberta": "Canada", "British Columbia": "Canada", "Manitoba": "Canada", "Newfoundland and Labrador": "Canada",
    "Nova Scotia": "Canada", "Nunavik": "Canada", "Nunavut": "Canada", "Kitikmeot": "Canada",
    "Northern Saskatchewan": "Canada", "Ontario": "Canada", "Quebec": "Canada", "Saskatchewan": "Canada",
    "Yukon": "Canada",
    # Mexico
    "Baja California": "Mexico", "Chihuahua": "Mexico", "Guerrero": "Mexico", "Sonora": "Mexico", "Zacatecas": "Mexico",
    # Brazil
    "Amapá": "Brazil", "Amazonas": "Brazil", "Bahia": "Brazil", "Ceará": "Brazil", "Espírito Santo": "Brazil",
    "Mato Grosso": "Brazil", "Minas Gerais": "Brazil", "Pará": "Brazil", "Rio Grande do Sul": "Brazil",
    "São Paulo": "Brazil", "Western Amazonas": "Brazil",
    # Argentina
    "Buenos Aires": "Argentina", "Córdoba": "Argentina", "Entre Ríos": "Argentina", "La Rioja": "Argentina",
    "Mendoza": "Argentina", "Neuquén": "Argentina", "Patagonia": "Argentina",
    # Bolivia, Peru, Colombia
    "La Paz": "Bolivia", "Chuquisaca": "Bolivia", "Santa Cruz": "Bolivia",
    "Arequipa": "Peru", "Tacna": "Peru", "Antioquia": "Colombia",
    # France, Britain's neighbours, Spain, Italy, the North
    "French Guiana": "France", "Murcia": "Spain", "Emilia-Romagna": "Italy", "Jämtland": "Sweden", "Lapland": "Finland",
    # Russia
    "Moscow": "Russia", "Karelia": "Russia", "Krasnoyarsk": "Russia", "Khabarovsk": "Russia", "Novosibirsk": "Russia",
    "Russian Far East": "Russia", "Saratov": "Russia", "Stavropol": "Russia", "Tyumen": "Russia", "Vologda": "Russia",
    "Yakutia": "Russia", "Yamalo-Nenets": "Russia", "Yaroslavl": "Russia", "Zabaykalsky Krai": "Russia",
    # Ukraine, Türkiye, Kazakhstan
    "Poltava": "Ukraine", "Antalya": "Türkiye", "Aktobe": "Kazakhstan", "Jetisu": "Kazakhstan", "Karaganda": "Kazakhstan",
    # China, India
    "Beijing": "China", "Guangdong": "China", "Heilongjiang": "China", "Jilin": "China", "Qinghai": "China",
    "Shaanxi": "China", "Sichuan": "China", "Yunnan": "China", "Zhejiang": "China",
    "Karnataka": "India", "Rajasthan": "India",
    # the Near East and Africa
    "Dhofar": "Oman", "Cairo": "Egypt", "Agadez": "Niger", "Timbuktu": "Mali", "Lagos": "Nigeria",
    "Kinshasa": "DR Congo", "Kwango": "DR Congo", "Haut-Uélé": "DR Congo",
    "Western Cape": "South Africa", "KwaZulu-Natal": "South Africa",
    # Indonesia, the ice
    "Kalimantan": "Indonesia", "Sulawesi": "Indonesia", "East Antarctica": "Antarctica",
    # (2026-11-08: today's grey land)
    "Taymyr": "Russia", "Magadan": "Russia", "Kolyma": "Russia", "Verkhoyansk": "Russia", "Nenets": "Russia", "Arkhangelsk": "Russia", "Sakhalin": "Russia", "Mindanao": "Philippines", "Northern Territory": "Australia", "Voronezh": "Russia", "Crete": "Greece", "Komi": "Russia", "Evenkia": "Russia", "Buryatia": "Russia", "West Papua": "Indonesia", "Tatarstan": "Russia", "Vilyuysk": "Russia", "Tomsk": "Russia", "Azores": "Portugal", "Puntland": "Somalia", "Madeira": "Portugal", "Fars": "Iran", "Ennedi": "Chad", "Namibe": "Angola", "Medina": "Saudi Arabia", "Borkou": "Chad", "Toliara": "Madagascar", "Fezzan": "Libya", "Karas": "Namibia", "Nampula": "Mozambique", "Darfur": "Sudan", "Tamanrasset": "Algeria", "Sicily": "Italy", "Andalusia": "Spain", "Murmansk": "Russia", "Finnmark": "Norway", "Nordland": "Norway", "Catalonia": "Spain", "Crimea": "Ukraine", "Peloponnese": "Greece", "Nizhny Novgorod": "Russia", "Saint Petersburg": "Russia", "Faroe Islands": "Denmark", "Norrbotten": "Sweden", "Novgorod": "Russia", "Basque Country": "Spain", "Kurdistan Region": "Iraq", "Sardinia": "Italy", "Krasnodar": "Russia", "Trøndelag": "Norway", "Pomerania": "Poland", "Volgograd": "Russia", "Apulia": "Italy", "Algarve": "Portugal", "Hawaii": "United States", "Avannaata": "Greenland", "Qikiqtaaluk": "Canada", "Iqaluit": "Canada", "Aleutian Islands": "United States", "Northwest Territories": "Canada", "Inuvialuit": "Canada", "Banks Island": "Canada", "North Slope": "United States", "Northwest Arctic": "United States", "Bethel": "United States", "Nome": "United States", "Resolute": "Canada", "Guadeloupe": "France", "Kivalliq": "Canada", "Eeyou Istchee": "Canada", "Sahtu": "Canada", "Haida Gwaii": "Canada", "Ohio": "United States", "Puerto Rico": "United States", "Galápagos": "Ecuador", "Rondônia": "Brazil", "Tierra del Fuego": "Argentina", "Chubut": "Argentina", "Antofagasta": "Chile", "Los Lagos": "Chile", "Salta": "Argentina", "Rio de Janeiro": "Brazil", "Bolívar": "Venezuela", "Roraima": "Brazil", "Chukotka": "Russia", "Tasmania": "Australia", "Kamchatka": "Russia", "Queensland": "Australia", "Svalbard": "Norway", "Western Australia": "Australia", "South Dakota": "United States", "Kujalleq": "Greenland", "New Caledonia": "France", "Amur": "Russia", "Novaya Zemlya": "Russia",
    # (2026-11-08: today's grey land)
    "Al Mahrah": "Yemen", "Kigoma": "Tanzania", "Northern State": "Sudan", "Ouargla": "Algeria", "Diana": "Madagascar", "Cyrenaica": "Libya", "Hodh Ech Chargui": "Mauritania", "Kidal": "Mali", "Arusha": "Tanzania", "South Khorasan": "Iran", "Équateur": "DR Congo", "Adamawa": "Nigeria", "Haut-Lomami": "DR Congo", "New Valley": "Egypt", "Adrar": "Algeria",
}

# Historical strengths of today's countries, where history gives one plainly (keys of periods_spec.TRAITS).
TRAIT = {
    "Mongolia": "steppe", "Kazakhstan": "steppe", "Kyrgyzstan": "steppe", "Turkmenistan": "steppe",
    "England": "traders", "Netherlands": "traders", "Portugal": "traders", "Norway": "raiders", "Denmark": "raiders",
    "Sweden": "legions", "Germany": "builders", "Switzerland": "mountain", "Afghanistan": "mountain",
    "Nepal": "mountain", "Tibet": "mountain", "Georgia": "mountain", "Armenia": "mountain", "Ethiopia": "mountain",
    "Russia": "masses", "China": "masses", "India": "masses", "Japan": "walls", "Türkiye": "walls",
    "France": "legions", "United States": "bureau", "Italy": "builders", "Egypt": "builders", "Iran": "bureau",
    "Spain": "faith", "Saudi Arabia": "faith", "Greece": "traders", "Mali": "traders", "Oman": "traders",
}
