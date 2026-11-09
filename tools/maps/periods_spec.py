"""Warhold's start dates (the owner, 2026-11-08: key moments as the great medieval strategy games bookmark them, four to
start, more after launch). Each realm: (name, lon, lat, colour, trait). Positions are the realm's seat (its capital or
heartland), from the historical record; colours follow each realm's traditional map colour or banner. Traits are keys of
TRAITS (or None). History only: these are real states and years, no game's own names or text."""

# Trait keys are Data/Traits.luau's (the one list).

PERIODS = [
    dict(key="867", year=867, name="The Age of Vikings",
         blurb="Norse longships raid every coast; the Abbasid caliphate and Byzantium hold the old world's heart.",
         realms=[
            ("Wessex", -1.3, 51.1, "#c8102e", None),
            ("Northumbria", -1.6, 54.9, "#7a1f2b", None),
            ("Mercia", -1.8, 52.6, "#8c2f39", None),
            ("Alba", -3.9, 56.4, "#1f4e9c", "mountain"),
            ("Norway", 10.4, 60.4, "#3a6ea5", "raiders"),
            ("Denmark", 9.5, 55.7, "#a61c3c", "raiders"),
            ("Svealand", 17.6, 59.9, "#2b5aa8", "raiders"),
            ("Ireland", -7.6, 53.3, "#2e8b57", None),
            ("West Francia", 2.3, 48.8, "#2c4f9e", "legions"),
            ("East Francia", 10.0, 50.1, "#5a5a5a", "legions"),
            ("Middle Francia", 6.1, 49.1, "#7b8fb8", None),
            ("Asturias", -5.8, 43.3, "#b22234", "mountain"),
            ("Emirate of Córdoba", -4.8, 37.9, "#1d7a46", "builders"),
            ("Papal States", 12.5, 41.9, "#e8d48a", "faith"),
            ("Benevento", 14.8, 41.1, "#9c6b30", None),
            ("Venice", 12.3, 45.4, "#c69214", "traders"),
            ("Great Moravia", 17.1, 49.0, "#8a4f9e", None),
            ("Bulgaria", 26.9, 43.3, "#3c8d3c", None),
            ("Byzantium", 28.98, 41.0, "#6a1b9a", "walls"),
            ("Khazar Khaganate", 47.0, 46.4, "#c9a227", "steppe"),
            ("Rus' of Novgorod", 31.3, 58.5, "#2f6b3a", None),
            ("Volga Bulgaria", 49.1, 54.9, "#4f8f6f", None),
            ("Abbasid Caliphate", 44.4, 33.3, "#1b1b1b", "bureau"),
            ("Tulunid Egypt", 31.2, 30.0, "#7fae3c", None),
            ("Idrisids", -5.0, 34.0, "#2f8f6f", None),
            ("Aghlabids", 10.1, 35.7, "#5f9e4a", None),
            ("Saffarids", 61.5, 31.0, "#b5651d", None),
            ("Armenia", 44.5, 40.2, "#d2691e", "mountain"),
            ("Tang China", 108.9, 34.3, "#d4a017", "bureau"),
            ("Tibet", 91.1, 29.6, "#8b4513", "mountain"),
            ("Uyghur Khaganate", 87.6, 43.8, "#5f9ea0", "steppe"),
            ("Kyrgyz Khaganate", 92.0, 51.7, "#6b8e23", "steppe"),
            ("Silla", 129.2, 35.8, "#4169e1", None),
            ("Balhae", 128.0, 43.5, "#556b2f", None),
            ("Japan", 135.8, 35.0, "#bc002d", "walls"),
            ("Nanzhao", 100.2, 25.6, "#9acd32", "mountain"),
            ("Pala Empire", 85.1, 25.6, "#ff8c00", None),
            ("Rashtrakutas", 77.0, 17.2, "#e9967a", "legions"),
            ("Pratiharas", 78.0, 26.2, "#cd853f", None),
            ("Chola", 79.1, 10.8, "#c71585", "traders"),
            ("Srivijaya", 104.7, -3.0, "#20b2aa", "traders"),
            ("Khmer", 103.9, 13.4, "#b8860b", "builders"),
            ("Champa", 108.3, 15.9, "#cd5c5c", None),
            ("Ghana Empire", -7.9, 15.7, "#daa520", "traders"),
            ("Kanem", 14.0, 13.5, "#a0522d", None),
            ("Makuria", 30.6, 18.2, "#8fbc8f", None),
            ("Aksum", 38.7, 14.1, "#228b22", None),
            ("Tiwanaku", -68.7, -16.6, "#d2b48c", "mountain"),
            ("Maya Cities", -89.6, 20.7, "#008b8b", None),
            ("Mississippian", -90.1, 38.6, "#8b7355", None),
            # (Europe's smaller realms, so the continent's own map has enough to fight over)
            ("Brittany", -2.8, 48.1, "#3d3d55", None),
            ("Aquitaine", 0.3, 45.0, "#4b6cb7", None),
            ("Bavaria", 11.6, 48.1, "#4f86c6", None),
            ("Saxony", 11.0, 51.5, "#6b7b8c", "legions"),
            ("Kingdom of Italy", 9.2, 45.5, "#3a9d5d", None),
            ("Pamplona", -1.6, 42.8, "#c23b22", "mountain"),
            ("Gwynedd", -3.9, 53.0, "#2e8b3e", "mountain"),
            ("Frisia", 5.8, 53.2, "#ff8c1a", "raiders"),
            ("Croatia", 16.0, 45.8, "#e03a3e", None),
            ("Serbia", 20.5, 44.0, "#8b2b3c", None),
            ("Polans", 17.0, 52.4, "#dc143c", None),
            ("Obotrites", 11.4, 53.6, "#7a8a6a", None),
            ("Prussians", 21.0, 54.7, "#5c4033", None),
            ("Finns", 25.0, 61.5, "#4a7fc1", None),
            # (Africa and the Americas, researched 2026-11-08: the continents' own maps get their own realms)
            ("Takrur", -14.0, 16.6, "#4b5320", None),  # Africa: Senegal River kingdom, in Arabic sources from the 9th-10th c.
            ("Senegambian Stone Circles", -15.0, 13.7, "#9e9e7a", None),  # Africa: Wassu/Sine Ngayène megalith builders, c. 700-1100
            ("Jenne-Jeno", -4.5, 13.9, "#a67b5b", "traders"),  # Africa: Inland Niger Delta trade city, flourishing c. 800-900
            ("Gao", 0.0, 16.3, "#8b0000", "traders"),  # Africa: Kawkaw (Gao), Songhai kingdom named by al-Yaqubi c. 872
            ("Tuareg", 6.5, 21.0, "#4169e1", None),  # Africa: Sanhaja/Tuareg Berber herders of the Aïr and Hoggar
            ("Igbo-Ukwu", 7.0, 6.0, "#6a5acd", None),  # Africa: Igbo-Ukwu bronze culture (Nri), 9th-10th c.
            ("Rustamids", 1.3, 35.4, "#b8860b", None),  # Africa: Ibadi imamate at Tahert, 776-909
            ("Fezzan (Zawila)", 15.1, 26.2, "#deb887", "traders"),  # Africa: Ibadi Berber trade town of Zawila, 9th c.
            ("Tubu", 18.5, 21.0, "#a52a2a", None),  # Africa: Teda/Tubu people of Tibesti, in early Arabic geography
            ("Alodia", 32.6, 15.6, "#4f6d7a", None),  # Africa: Christian Nubian kingdom, capital Soba, c. 500-1500
            ("Beja", 36.5, 19.5, "#996633", None),  # Africa: Beja kingdoms of the Red Sea Hills, listed by al-Yaqubi
            ("Harla", 42.0, 9.3, "#7b3f00", None),  # Africa: Harla culture of the Harar plateau, 6th-13th c.
            ("Shanga", 40.9, -2.2, "#e76f51", "traders"),  # Africa: early Swahili town on Pate Island, c. 750-1400
            ("Unguja Ukuu", 39.4, -6.4, "#9b5de5", "traders"),  # Africa: early Swahili port on Zanzibar, 7th-10th c.
            ("Comoros (Dembeni)", 43.35, -11.7, "#90be6d", "traders"),  # Africa: Dembeni-phase trading villages of the Comoros, 9th-10th c. (seat on Grande Comore; Mayotte too small for the map)
            ("Vazimba", 47.3, -19.3, "#577590", None),  # Africa: early inhabitants of Madagascar's highlands in Malagasy tradition
            ("Chibuene", 35.35, -22.0, "#ffb4a2", "traders"),  # Africa: Mozambique coast trading site, 7th-10th c.
            ("Toutswe", 27.1, -22.5, "#6d597a", None),  # Africa: Toutswe cattle chiefdoms of eastern Botswana, c. 700-1300
            ("San", 21.5, -23.5, "#c8ad7f", None),  # Africa: San hunter-gatherers of the Kalahari
            ("Khoikhoi", 19.5, -33.0, "#8d6e63", None),  # Africa: Khoikhoi herders of the Cape
            ("Kalomo", 26.5, -17.0, "#43aa8b", None),  # Africa: Kalomo culture of southern Zambia, c. 700-1300
            ("Kisalian (Upemba)", 26.6, -8.5, "#3d405b", None),  # Africa: Sanga/Kisalian culture of the Upemba Depression, 8th-14th c.
            ("Urewe", 34.0, -0.5, "#f28482", None),  # Africa: Urewe iron-working culture of the Lake Victoria basin
            ("Mongo", 20.0, -1.0, "#2d6a4f", None),  # Africa: Bantu farmers and forest foragers of the Congo basin
            ("Xochicalco", -99.3, 18.8, "#8b4513", "walls"),  # North America: fortified Epiclassic city, c. 650-900
            ("Zapotecs", -96.4, 16.95, "#ff8c00", None),  # North America: Zapotec city-states of the Oaxaca valley after Monte Albán
            ("La Quemada", -102.8, 22.45, "#bc8f8f", "walls"),  # North America: hilltop citadel of the Chalchihuites frontier, c. 500-900
            ("Huastecs", -98.4, 22.0, "#556b2f", None),  # North America: Huastec Maya-speakers of the Gulf coast
            ("Tikal", -89.62, 17.22, "#2f4f4f", None),  # North America: Maya city, last dated monument 869
            ("Lenca", -87.8, 14.3, "#6b8e23", None),  # North America: Lenca chiefdoms of Honduras
            ("Nicoya", -85.4, 10.3, "#9370db", None),  # North America: Greater Nicoya chiefdoms (Costa Rica/Nicaragua)
            ("Coclé", -80.4, 8.5, "#f0c419", None),  # North America: Gran Coclé gold-working chiefdoms, Sitio Conte c. 750-1000
            ("Taíno", -70.7, 19.0, "#ff6347", None),  # North America: Ostionoid ancestors of the Taíno on Hispaniola
            ("Guanahatabey", -83.6, 22.5, "#708090", None),  # North America: archaic foragers of western Cuba
            ("Igneri", -61.5, 16.2, "#9acd32", None),  # North America: Arawak-speaking Lesser Antilles islanders before the Kalinago
            ("Hohokam", -111.9, 33.4, "#cd853f", "builders"),  # North America: canal-building farmers of the Salt and Gila rivers
            ("Ancestral Puebloans", -107.96, 36.06, "#e9d8a6", None),  # North America: Pueblo I villages, Chaco Canyon's early great houses
            ("Mogollon", -108.0, 32.8, "#6b4226", None),  # North America: Mogollon/Mimbres pithouse villages
            ("Fremont", -111.8, 39.2, "#8fbc8f", None),  # North America: Fremont culture of Utah, c. 700-1300
            ("Patayan", -115.2, 32.8, "#daa06d", None),  # North America: lower Colorado River peoples (Yuman ancestors)
            ("Chumash", -119.7, 34.5, "#1e90ff", "traders"),  # North America: Chumash plank-canoe chiefdoms of the Santa Barbara Channel
            ("Coast Salish", -122.5, 49.2, "#2e8b57", None),  # North America: Marpole-phase villages of the Fraser delta
            ("Haida", -132.1, 53.3, "#dc143c", None),  # North America: Haida of Haida Gwaii
            ("Plains Woodland", -98.0, 41.0, "#c5b358", None),  # North America: Plains Woodland villages of Nebraska/Kansas
            ("Avonlea", -105.5, 50.5, "#7b68ee", None),  # North America: Avonlea bison hunters of the northern Plains, c. 200-1300
            ("Coles Creek", -91.4, 31.6, "#6495ed", None),  # North America: mound-building culture of the lower Mississippi, 700-1200
            ("Weeden Island", -84.5, 30.2, "#ff7f50", None),  # North America: Weeden Island culture of the Florida panhandle
            ("St. Johns", -81.3, 29.6, "#4b0082", None),  # North America: St. Johns culture (Timucua ancestors) of northeast Florida
            ("Calusa", -81.86, 26.42, "#20b2aa", None),  # North America: Calusa of southwest Florida, Mound Key
            ("Effigy Mound", -90.8, 43.2, "#228b22", None),  # North America: Effigy Mound culture of Wisconsin, c. 700-1100
            ("Point Peninsula", -76.0, 43.5, "#6a0dad", None),  # North America: Point Peninsula culture of New York/Ontario
            ("Eastern Algonquians", -71.5, 42.5, "#8b8b00", None),  # North America: Eastern Algonquian peoples of New England
            ("Laurel", -93.0, 48.5, "#5f9ea0", None),  # North America: Laurel culture of the Rainy River/Lake Superior
            ("Cree", -77.5, 51.5, "#87ceeb", None),  # North America: Algonquian hunters of the James Bay forests
            ("Dene", -120.0, 62.5, "#36454f", None),  # North America: Athabaskan (Dene) peoples of the Mackenzie basin
            ("Dorset", -84.0, 68.5, "#b0c4de", None),  # North America: Dorset (Paleo-Inuit) of the eastern Arctic, Igloolik core
            ("Birnirk", -156.6, 71.2, "#add8e6", None),  # North America: Birnirk whalers of Point Barrow, Thule forerunners
            ("Aleuts", -166.5, 53.9, "#4f7942", None),  # North America: Unangan (Aleut) of the Aleutian Islands
            ("Beothuk", -56.0, 49.0, "#e2725b", None),  # North America: Little Passage complex, Beothuk ancestors of Newfoundland
            ("Wari", -74.2, -13.05, "#8b0000", "mountain"),  # South America: Wari empire of the central Andes, c. 600-1000
            ("Sicán", -79.7, -6.5, "#ffd700", "builders"),  # South America: Lambayeque/Sicán culture, Batán Grande from c. 800
            ("Manteño", -80.7, -1.0, "#20b2aa", "traders"),  # South America: Manteño seafaring traders of coastal Ecuador, from c. 800
            ("Quitu-Cara", -78.0, 0.45, "#6b8e23", "mountain"),  # South America: Quitu and Cara chiefdoms of highland Ecuador
            ("Muisca", -73.4, 5.5, "#daa520", None),  # South America: Muisca chiefdoms of the Bogotá plateau
            ("Tairona", -73.9, 11.0, "#ffa07a", "mountain"),  # South America: Tairona towns of the Sierra Nevada de Santa Marta
            ("Calima", -76.5, 3.9, "#cd5c5c", None),  # South America: Calima culture (Sonso period) of Colombia's Cauca valley
            ("Timoto-Cuica", -71.1, 8.6, "#5b8db8", "mountain"),  # South America: terrace farmers of the Venezuelan Andes
            ("Valencia Culture", -67.8, 10.1, "#7e57c2", None),  # South America: mound villages around Lake Valencia, Venezuela
            ("Arauquinoid", -66.0, 7.5, "#1b7f5a", None),  # South America: Arauquinoid chiefdoms of the middle Orinoco
            ("Lokono", -58.0, 6.3, "#006400", None),  # South America: Arawak (Lokono) peoples of the Guiana coast
            ("Aristé", -51.2, 2.5, "#ff69b4", None),  # South America: Aristé culture of Amapá, megalith and urn burials
            ("Marajoara", -49.5, -0.9, "#c04000", "builders"),  # South America: mound-building chiefdoms of Marajó, c. 400-1300
            ("Paredão", -60.0, -3.2, "#e9967a", None),  # South America: Paredão-phase mound villages near Manaus, c. 700-1200
            ("Casarabe", -64.9, -14.7, "#3cb371", "builders"),  # South America: Casarabe causeway towns of the Llanos de Mojos, 500-1400
            ("Acre Geoglyphs", -67.5, -9.9, "#556b2f", None),  # South America: earthwork-builders of western Amazonia (Acre)
            ("Cumancaya", -74.4, -8.4, "#4169e1", None),  # South America: Cumancaya culture of the Ucayali (Panoan ancestors)
            ("Atacameño", -68.2, -22.9, "#8b5a7a", "traders"),  # South America: San Pedro de Atacama oasis people, Tiwanaku trade partners
            ("Aguada", -66.5, -27.5, "#708090", None),  # South America: Aguada culture of northwest Argentina, c. 650-950
            ("Diaguita", -70.6, -30.0, "#ff4500", None),  # South America: Las Ánimas/early Diaguita of Chile's Elqui valley
            ("Huarpe", -67.3, -32.8, "#f4a460", None),  # South America: Huarpe farmers of Cuyo
            ("Comechingón", -64.5, -31.4, "#8fbc8f", None),  # South America: Comechingón of the Córdoba hills
            ("Guaycuru", -60.5, -24.5, "#cd853f", None),  # South America: Guaycuruan foragers of the Gran Chaco
            ("Querandí", -58.7, -35.0, "#bdb76b", None),  # South America: Querandí hunters of the Pampas
            ("Charrúa", -56.0, -32.5, "#87ceeb", None),  # South America: Charrúa of Uruguay
            ("Mapuche", -72.6, -38.7, "#0033a0", None),  # South America: Pitrén-phase Mapuche of Araucanía
            ("Puelche", -66.0, -39.5, "#deb887", None),  # South America: Puelche (Günün a künna) of northern Patagonia
            ("Tehuelche", -69.0, -45.5, "#a9a9a9", None),  # South America: Tehuelche guanaco hunters of Patagonia
            ("Chonos", -73.0, -45.5, "#2f4f4f", None),  # South America: Chonos canoe people of the Aysén archipelagos
            ("Selk'nam", -68.6, -54.0, "#c0c0c0", None),  # South America: Selk'nam of Tierra del Fuego
            ("Guarani", -56.5, -25.5, "#228b22", None),  # South America: Tupi-Guarani farming villages of the Paraná basin
            ("Taquara", -51.5, -28.8, "#6a5acd", None),  # South America: Taquara/Itararé pit-house villages (southern Jê ancestors)
            ("Sambaqui", -48.7, -27.6, "#f5deb3", None),  # South America: Sambaqui shell-mound builders of the Santa Catarina coast
            ("Aratu", -39.5, -12.5, "#b5651d", None),  # South America: Aratu village tradition of Bahia
            ("Akwẽ", -48.0, -15.0, "#9b870c", None),  # South America: Jê-speaking peoples of the Brazilian cerrado
            # (2026-11-08: real realms for the grey land, tools/maps/coverage.py's holes)
            ("Guanches", -16.5, 28.3, "#d4a373", "mountain"),  # africa: d4a373", "mountain"),  # Wikipedia: Guanches (Canary Islands natives, here long before 1402)
            ("Ghadames", 9.5, 30.13, "#e0c068", "traders"),  # africa: e0c068", "traders"),  # Wikipedia: Ghadames (Berber oasis city on the trans-Saharan route)
            ("Masufa", -5.0, 23.6, "#b08d57", "traders"),  # africa: b08d57", "traders"),  # Wikipedia: Masufa (Sanhaja Berber tribe of the western Sahara, Taghaza salt road)
            ("Mbuti", 28.5, 1.5, "#4e7d3a", None),  # africa: 4e7d3a", None),  # Wikipedia: Mbuti people (forest foragers of the Ituri)
            ("Aka", 17.8, 3.6, "#6a994e", None),  # africa: 6a994e", None),  # Wikipedia: Aka people (Mbenga foragers of the Lobaye/Sangha forest)
            ("Baka", 14.5, 3.0, "#386641", None),  # africa: 386641", None),  # Wikipedia: Baka people (Cameroon and Gabon) (forest foragers of southeast Cameroon)
            ("Bongo", 11.5, -1.5, "#2a9d8f", None),  # africa: 2a9d8f", None),  # Wikipedia: Bongo people (Gabon) (forest foragers of Gabon)
            ("Kwadi", 13.0, -15.0, "#bc6c25", None),  # africa: bc6c25", None),  # Wikipedia: Kwadi people (Khoe-Kwadi foragers and herders of southwest Angola)
            ("!Kung", 19.0, -18.0, "#dda15e", None),  # africa: dda15e", None),  # Wikipedia: !Kung people (Ju-speaking San of northern Namibia and southeast Angola)
            ("Nama", 17.5, -26.5, "#a0785a", None),  # africa: a0785a", None),  # Wikipedia: Nama people (Khoekhoe herders of southern Namibia)
            ("Damara", 15.5, -21.5, "#7f5539", None),  # africa: 7f5539", None),  # Wikipedia: Damara people (ancient inhabitants of central and northwest Namibia)
            ("Mahra", 51.8, 15.9, "#9c6644", None),  # africa: 9c6644", None),  # Wikipedia: Mahra tribe (South Arabian people of al-Mahrah, eastern Yemen)
            ("Tayy", 41.7, 27.5, "#c9b458", "steppe"),  # africa: c9b458", "steppe"),  # Wikipedia: Tayy (Arab tribe of Jabal Aja and Salma, Ha'il)
            ("Midrarid dynasty", -4.27, 31.28, "#7a9e3b", "traders"),  # africa: 7a9e3b", "traders"),  # Wikipedia: Midrarid dynasty (Sijilmasa, 823-977)
            ("Lamtuna", -12.3, 21.0, "#5e548e", None),  # africa: 5e548e", None),  # Wikipedia: Lamtuna (Sanhaja tribe of the Mauritanian Adrar)
            ("Lawata", 21.3, 29.1, "#bfa46f", None),  # africa: bfa46f", None),  # Wikipedia: Lawata (Berber tribe of Cyrenaica and Awjila)
            ("Zaghawa", 22.5, 15.3, "#8c5e3c", None),  # africa: 8c5e3c", None),  # Wikipedia: Zaghawa people (named by al-Yaqubi, 872)
            ("Melingoi", 22.4, 37.0, "#5b8e7d", "mountain"),  # africa: 5b8e7d", "mountain"),  # Wikipedia: Melingoi (Slavic tribe of the Taygetus, 9th c.)
            ("Emirate of Melitene", 38.3, 38.35, "#4d7c0f", "raiders"),  # africa: 4d7c0f", "raiders"),  # Wikipedia: Emirate of Melitene (Arab border emirate, to 934)
            ("Alavids", 52.35, 36.47, "#3a7d44", "faith"),  # africa: 3a7d44", "faith"),  # Wikipedia: Alavids (Zaydi state of Tabaristan, from 864)
            ("Tahirid dynasty", 58.8, 36.2, "#1f6f8b", None),  # africa: 1f6f8b", None),  # Wikipedia: Tahirid dynasty (Khorasan, Nishapur, 821-873)
            ("Imamate of Oman", 57.53, 22.93, "#b5172f", "faith"),  # africa: b5172f", "faith"),  # Wikipedia: Imamate of Oman (second Ibadi imamate, Nizwa)
            ("Ukhaidhirids", 47.3, 24.15, "#8d99ae", None),  # africa: 8d99ae", None),  # Wikipedia: Ukhaidhirids (al-Yamama, from c. 866)
            ("Yufirids", 43.9, 15.5, "#6d6875", "mountain"),  # africa: 6d6875", "mountain"),  # Wikipedia: Yufirid dynasty (Shibam Kawkaban/Sanaa, 847-997)
            ("Ziyadid dynasty", 43.32, 14.2, "#e9c46a", None),  # africa: e9c46a", None),  # Wikipedia: Ziyadid dynasty (Zabid, 819-1018)
            ("Gwich'in", -141.0, 67.5, "#4a6741", None),  # americas: 4a6741', None),  # Wikipedia: Gwich'in
            ("Koyukon", -156.5, 65.6, "#7d6b91", None),  # americas: researched 2026-11-08
            ("Tlingit", -135.4, 58.8, "#b03a2e", "raiders"),  # americas: researched 2026-11-08
            ("Taltheilei", -104.0, 61.5, "#8a9a5b", None),  # americas: researched 2026-11-08
            ("Dane-zaa", -118.5, 56.2, "#996633", None),  # americas: researched 2026-11-08
            ("Karuk", -123.5, 41.4, "#5d8aa8", None),  # americas: researched 2026-11-08
            ("Cochimí", -112.3, 26.6, "#c2b280", None),  # americas: researched 2026-11-08
            ("Mi'kmaq", -65.3, 46.6, "#1c4f82", None),  # americas: 1c4f82', None),  # Wikipedia: Mi'kmaq
            ("Point Revenge", -60.4, 54.0, "#6e7f80", None),  # americas: researched 2026-11-08
            ("Kaska", -128.5, 59.5, "#7a5c3e", None),  # americas: researched 2026-11-08
            ("Ahtna", -145.3, 62.1, "#b87333", None),  # americas: researched 2026-11-08
            ("Juntunen", -85.0, 46.6, "#5f7f5f", None),  # americas: researched 2026-11-08
            ("Kawésqar", -74.3, -51.0, "#3f5f7f", None),  # americas: researched 2026-11-08
            ("Goitacá", -41.3, -21.75, "#a0522d", None),  # americas: researched 2026-11-08
            ("Timbira", -46.5, -6.5, "#b8860b", None),  # americas: researched 2026-11-08
            ("Tremembé", -39.8, -3.2, "#e07b39", None),  # americas: researched 2026-11-08
            ("Paresí", -57.5, -13.0, "#6b8e23", None),  # americas: researched 2026-11-08
            ("Bororo", -55.5, -16.5, "#c71585", None),  # americas: researched 2026-11-08
            ("Yanomami", -64.0, 2.5, "#2e8b57", None),  # americas: researched 2026-11-08
            ("Ticuna", -69.3, -3.0, "#8b0000", None),  # americas: researched 2026-11-08
            ("Chané", -62.8, -19.3, "#daa520", None),  # americas: researched 2026-11-08
            ("Apurinã", -65.2, -8.0, "#556b2f", None),  # americas: researched 2026-11-08
            ("Sapucaí", -46.8, -21.3, "#9370db", None),  # americas: researched 2026-11-08
            ("Karajá", -50.3, -9.5, "#cd5c5c", None),  # americas: researched 2026-11-08
            ("Punuk", -170.3, 63.6, "#9fb6cd", None),  # americas: researched 2026-11-08
            ("Norton", -161.8, 60.8, "#8b6f47", None),  # americas: researched 2026-11-08
            ("Kachemak", -151.5, 59.6, "#4682b4", None),  # americas: researched 2026-11-08
            ("Blackduck", -97.0, 53.0, "#2f2f4f", None),  # americas: researched 2026-11-08
            ("Samanids", 66.96, 39.65, "#3b7d3b", "bureau"),  # asia: 3b7d3b", "bureau"),       # Wikipedia: Samanid Empire (Nasr I at Samarkand from 864)
            ("Tahirids", 58.8, 36.2, "#2f4f7f", None),  # asia: 2f4f7f", None),             # Wikipedia: Tahirid dynasty (821-873, Nishapur)
            ("Afrighids", 60.75, 41.7, "#6f4e37", None),  # asia: 6f4e37", None),           # Wikipedia: Afrighids (Khwarazmshahs at Kath)
            ("Oghuz Yabgu State", 62.0, 45.6, "#8fbc8f", "steppe"),  # asia: 8fbc8f", "steppe"),  # Wikipedia: Oghuz Yabgu State (750-1055, Yangikent)
            ("Karluk Yabgu State", 75.2, 42.8, "#5f9ea0", "steppe"),  # asia: 5f9ea0", "steppe"),  # Wikipedia: Karluk Yabgu State (756-940, Suyab)
            ("Kimek Khaganate", 80.2, 50.4, "#a0a060", "steppe"),  # asia: a0a060", "steppe"),  # Wikipedia: Kimek-Kipchak confederation (743-1035)
            ("Pechenegs", 54.0, 50.5, "#b5a642", "steppe"),  # asia: b5a642", "steppe"),        # Wikipedia: Pechenegs (Volga-Ural steppe until 889)
            ("Bashkirs", 56.5, 54.0, "#4f8f4f", None),  # asia: 4f8f4f", None),             # Wikipedia: Bashkirs (Sallam the Interpreter, 9th c.)
            ("Kingdom of Khotan", 79.9, 37.1, "#c9a227", None),  # asia: c9a227", None),    # Wikipedia: Kingdom of Khotan
            ("Guiyi Circuit", 94.66, 40.14, "#b22222", None),  # asia: b22222", None),      # Wikipedia: Guiyi Circuit (Zhang Yichao at Shazhou, 848-1036)
            ("Habbarids", 68.98, 25.88, "#2e8b57", None),  # asia: 2e8b57", None),          # Wikipedia: Habbari dynasty (Sindh, al-Mansura, 854-1011)
            ("Emirate of Multan", 71.47, 30.2, "#556b2f", None),  # asia: 556b2f", None),   # Wikipedia: Emirate of Multan (Banu Munabbih)
            ("Tatars", 112.0, 47.5, "#5e8fa8", "steppe"),  # asia: 5e8fa8", "steppe"),          # Wikipedia: Tatar confederation (8th c.-1202)
            ("Khitans", 119.4, 43.97, "#4682b4", "steppe"),  # asia: 4682b4", "steppe"),        # Wikipedia: Khitan people (Shira Muren, pre-Liao)
            ("Shiwei", 122.5, 51.5, "#6b8fa3", None),  # asia: 6b8fa3", None),              # Wikipedia: Shiwei
            ("Kurykans", 106.5, 53.5, "#7f9f8f", None),  # asia: 7f9f8f", None),            # Wikipedia: Kurykans
            ("Mansi", 62.5, 61.3, "#5b7c99", None),  # asia: 5b7c99", None),           # Wikipedia: Mansi people
            ("Khanty", 70.5, 60.5, "#3f6f8f", None),  # asia: 3f6f8f", None),          # Wikipedia: Khanty
            ("Selkups", 82.0, 59.3, "#6a8caf", None),  # asia: 6a8caf", None),         # Wikipedia: Selkup people
            ("Kets", 90.5, 62.5, "#4a6b5a", None),  # asia: 4a6b5a", None),            # Wikipedia: Kets
            ("Evenks", 112.0, 64.0, "#2e6f6f", None),  # asia: 2e6f6f", None),         # Wikipedia: Evenks
            ("Yukaghirs", 138.0, 67.5, "#7a8b99", None),  # asia: 7a8b99", None),      # Wikipedia: Yukaghir people
            ("Chukchi", 172.0, 67.5, "#9ab0c4", None),  # asia: 9ab0c4", None),        # Wikipedia: Chukchi people
            ("Siberian Yupiks", -170.5, 65.8, "#b0c4de", "raiders"),  # asia: b0c4de", "raiders"),  # Wikipedia: Siberian Yupik (Old Bering Sea/Punuk ancestors)
            ("Koryaks", 160.5, 62.0, "#6f7f8f", None),  # asia: 6f7f8f", None),        # Wikipedia: Koryaks
            ("Itelmens", 157.0, 53.3, "#4b7f6a", None),  # asia: 4b7f6a", None),       # Wikipedia: Itelmens
            ("Nivkh", 140.4, 52.8, "#3b5f7f", None),  # asia: 3b5f7f", None),          # Wikipedia: Nivkh people
            ("Okhotsk culture", 144.27, 44.0, "#5f7fa0", "raiders"),  # asia: 5f7fa0", "raiders"),  # Wikipedia: Okhotsk culture (5th-13th c.)
            ("Emishi", 140.5, 40.5, "#8b6f47", "mountain"),  # asia: 8b6f47", "mountain"),        # Wikipedia: Emishi (north of Shiwa, Gangyo revolt 878)
            ("Lamuri", 95.4, 5.55, "#2a9d8f", "traders"),  # asia: 2a9d8f", "traders"),          # Wikipedia: Lamuri Kingdom (Ramni, 9th c. Arab sources)
            ("Arakan", 93.15, 20.45, "#e1ad01", None),  # asia: e1ad01", None),             # Wikipedia: Lemro period (Arakan kingdom of the Lemro valley, from 818)
            ("Medang", 110.4, -7.6, "#d4a373", "builders"),  # asia: d4a373", "builders"),        # Wikipedia: Mataram Kingdom (Medang, central Java)
            ("Motu", 147.2, -9.45, "#e76f51", "traders"),  # asia: e76f51", "traders"),     # Wikipedia: Motu people
            ("Chimbu", 144.97, -6.02, "#386641", "mountain"),  # asia: 386641", "mountain"),  # Wikipedia: Chimbu people
            ("Sentani", 140.5, -2.6, "#2a9d8f", None),  # asia: 2a9d8f", None),        # Wikipedia: Sentani people
            ("Biak", 136.05, -1.05, "#264653", "raiders"),  # asia: 264653", "raiders"),    # Wikipedia: Biak people
            ("Noongar", 117.2, -33.3, "#8c4a2f", None),  # asia: 8c4a2f", None),       # Wikipedia: Noongar
            ("Martu", 121.5, -22.5, "#d2691e", None),  # asia: d2691e", None),         # Wikipedia: Martu people
            ("Warlpiri", 131.0, -20.6, "#a0522d", None),  # asia: a0522d", None),      # Wikipedia: Warlpiri
            ("Arrernte", 133.9, -23.7, "#cd853f", None),  # asia: cd853f", None),      # Wikipedia: Arrernte people
            ("Tiwi", 130.9, -11.6, "#7a5230", "raiders"),  # asia: 7a5230", "raiders"),     # Wikipedia: Tiwi people
            ("Yolngu", 136.4, -12.6, "#9b2d20", None),  # asia: 9b2d20", None),         # Wikipedia: Yolngu
            ("Kuku Yalanji", 145.2, -16.2, "#556b2f", None),  # asia: 556b2f", None),  # Wikipedia: Kuku Yalanji
            ("Wiradjuri", 147.0, -33.0, "#6b4226", None),  # asia: 6b4226", None),     # Wikipedia: Wiradjuri
            ("Dharug", 150.9, -33.8, "#a52a2a", None),  # asia: a52a2a", None),        # Wikipedia: Dharug
            ("Kulin", 145.0, -37.7, "#4f6d7a", None),  # asia: 4f6d7a", None),         # Wikipedia: Kulin
            ("Palawa", 146.8, -42.0, "#2f4f4f", None),  # asia: 2f4f4f", None),        # Wikipedia: Aboriginal Tasmanians
            ("Kanak", 165.4, -21.3, "#2d6a4f", None),  # asia: 2d6a4f", None),         # Wikipedia: Kanak people
            ("Amis", 121.4, 23.5, "#e9c46a", None),  # asia: e9c46a", None),           # Wikipedia: Amis people
            ("Andamanese", 92.75, 12.3, "#5c4033", None),  # asia: 5c4033", None),     # Wikipedia: Andamanese peoples
            ("Sámi", 20.5, 69.3, "#d9442b", None),  # europe: d9442b", None),  # Wikipedia: Sámi people (Ohthere's "Finnas", 9th c.)
            ("Bjarmians", 41.0, 64.6, "#7c5a3a", "traders"),  # europe: 7c5a3a", "traders"),  # Wikipedia: Bjarmaland
            ("Burtas", 45.2, 52.3, "#a0703c", None),  # europe: a0703c", None),  # Wikipedia: Burtas
            ("Hålogaland", 14.6, 68.6, "#4a6f8a", "raiders"),  # europe: 4a6f8a", "raiders"),  # Wikipedia: Hålogaland (Ohthere's home, petty kingdom)
            ("Terfinns", 33.5, 68.8, "#b85c38", None),  # europe: b85c38", None),  # Wikipedia: Ohthere of Hålogaland (Terfinnas of Kola)
            ("Kvens", 24.5, 65.8, "#5b7f3a", None),  # europe: 5b7f3a", None),  # Wikipedia: Kvenland
            ("Perm", 45.5, 61.6, "#8a6d3b", None),  # europe: 8a6d3b", None),  # Wikipedia: Komi peoples (chronicle "Perm" of the Vychegda)
            ("Pechera", 45.5, 67.4, "#6a5a4a", None),  # europe: 6a5a4a", None),  # Wikipedia: Pechora (people)
            ("Karelians", 31.0, 62.0, "#3f7f6f", None),  # europe: 3f7f6f", None),  # Wikipedia: Karelians
            ("Ves", 37.8, 60.0, "#5f8f4f", None),  # europe: 5f8f4f", None),  # Wikipedia: Ves (people) (Beloozero, Primary Chronicle s.a. 862)
            ("Muroma", 42.0, 55.6, "#7f5f8f", None),  # europe: 7f5f8f", None),  # Wikipedia: Muroma
            ("Mordvins", 44.6, 54.3, "#9f4f3f", None),  # europe: 9f4f3f", None),  # Wikipedia: Mordvins
            ("Kiev", 30.5, 50.4, "#2f6b5a", None),  # europe: 2f6b5a", None),  # Wikipedia: Askold and Dir
            ("Severians", 31.3, 51.6, "#4f7f2f", None),  # europe: 4f7f2f", None),  # Wikipedia: Severians
            ("Krivichs", 29.0, 55.0, "#3f6f4f", None),  # europe: 3f6f4f", None),  # Wikipedia: Krivichs
            ("Volhynians", 24.3, 50.9, "#6f8f5f", None),  # europe: 6f8f5f", None),  # Wikipedia: Volhynians
            ("White Croats", 24.5, 48.8, "#c04040", None),  # europe: c04040", None),  # Wikipedia: White Croats
            ("Magyars", 31.8, 46.8, "#2e7d32", "steppe"),  # europe: 2e7d32", "steppe"),  # Wikipedia: Etelköz (Hungarian homeland before 895)
            ("Vyatichi", 36.5, 54.0, "#5f5f3f", None),  # europe: 5f5f3f", None),  # Wikipedia: Vyatichi
            ("Kasogs", 38.6, 44.8, "#3f8f8f", "mountain"),  # europe: 3f8f8f", "mountain"),  # Wikipedia: Kasogs
            ("Alania", 44.2, 43.6, "#b08f3f", "mountain"),  # europe: b08f3f", "mountain"),  # Wikipedia: Alania
            ("Estonians", 25.5, 58.7, "#2f5f9f", None),  # europe: 2f5f9f", None),  # Wikipedia: Ancient Estonia
            ("Geats", 14.5, 57.8, "#4f6fbf", None),  # europe: 4f6fbf", None),  # Wikipedia: Geats
            ("Hordaland", 5.6, 60.6, "#5a7fa5", "raiders"),  # europe: 5a7fa5", "raiders"),  # Wikipedia: Petty kingdoms of Norway (Eirik of Hordaland)
            ("Faroe Islands", -6.8, 62.0, "#3f5f8f", None),  # europe: 3f5f8f", None),  # Wikipedia: History of the Faroe Islands
            ("Emirate of Crete", 25.1, 35.3, "#2f7f4f", "raiders"),  # europe: 2f7f4f", "raiders"),  # Wikipedia: Emirate of Crete
            ("Paulicians", 38.1, 39.4, "#8f2f2f", "faith"),  # europe: 8f2f2f", "faith"),  # Wikipedia: Tephrike
            ("Trøndelag", 10.9, 63.8, "#2f5f7f", None),  # europe: 2f5f7f", None),  # Wikipedia: Haakon Grjotgardsson (jarl of Hlaðir)
        ]),
    dict(key="1066", year=1066, name="The Norman Conquest",
         blurb="Three claimants race for England's crown while the Seljuks rise and Byzantium braces.",
         realms=[
            ("England", -0.1, 51.5, "#c8102e", "legions"),
            ("Normandy", -0.4, 49.2, "#e03c31", "raiders"),
            ("Scotland", -3.2, 56.0, "#1f4e9c", "mountain"),
            ("France", 2.3, 48.8, "#2c4f9e", "legions"),
            ("Norway", 10.4, 63.4, "#3a6ea5", "raiders"),
            ("Denmark", 12.6, 55.7, "#a61c3c", "raiders"),
            ("Sweden", 17.6, 59.9, "#2b5aa8", None),
            ("Ireland", -7.6, 53.3, "#2e8b57", None),
            ("Holy Roman Empire", 9.0, 50.6, "#d9b41a", "legions"),
            ("Poland", 19.9, 50.1, "#dc143c", None),
            ("Hungary", 19.0, 47.5, "#7f3f98", "steppe"),
            ("Bohemia", 14.4, 50.1, "#5b6c8a", None),
            ("Croatia", 16.0, 45.8, "#b03a2e", None),
            ("Kievan Rus'", 30.5, 50.4, "#2f6b3a", "masses"),
            ("Novgorod", 31.3, 58.5, "#4a7d4f", "traders"),
            ("Byzantium", 28.98, 41.0, "#6a1b9a", "walls"),
            ("Venice", 12.3, 45.4, "#c69214", "traders"),
            ("Papal States", 12.5, 41.9, "#e8d48a", "faith"),
            ("Castile", -4.7, 41.6, "#b22234", None),
            ("León", -5.6, 42.6, "#9b2335", None),
            ("Aragon", -0.9, 41.6, "#e8b923", None),
            ("Taifa of Seville", -6.0, 37.4, "#1d7a46", None),
            ("Almoravids", -8.0, 31.6, "#3b7a57", "faith"),
            ("Zirids", 10.1, 35.7, "#5f9e4a", None),
            ("Fatimid Caliphate", 31.2, 30.0, "#2e8b2e", "bureau"),
            ("Seljuk Empire", 51.4, 35.7, "#2d6e8f", "steppe"),
            ("Georgia", 44.8, 41.7, "#c0392b", "mountain"),
            ("Armenia", 44.5, 40.2, "#d2691e", "mountain"),
            ("Cumans", 40.0, 48.0, "#c9a227", "steppe"),
            ("Volga Bulgaria", 49.1, 54.9, "#4f8f6f", None),
            ("Ghaznavids", 68.4, 33.6, "#8b5a2b", None),
            ("Song China", 114.3, 34.8, "#d4a017", "bureau"),
            ("Liao", 116.4, 42.0, "#4682b4", "steppe"),
            ("Western Xia", 106.2, 38.5, "#b5a642", None),
            ("Goryeo", 126.5, 37.9, "#4169e1", None),
            ("Japan", 135.8, 35.0, "#bc002d", "walls"),
            ("Dai Viet", 105.8, 21.0, "#cd5c5c", None),
            ("Khmer", 103.9, 13.4, "#b8860b", "builders"),
            ("Pagan", 94.9, 21.2, "#e1ad01", "builders"),
            ("Chola", 79.1, 10.8, "#c71585", "traders"),
            ("Western Chalukyas", 76.0, 16.0, "#e9967a", None),
            ("Pala Empire", 85.1, 25.6, "#ff8c00", None),
            ("Ghana Empire", -7.9, 15.7, "#daa520", "traders"),
            ("Kanem", 14.0, 13.5, "#a0522d", None),
            ("Ethiopia", 39.0, 12.0, "#228b22", "mountain"),
            ("Toltecs", -99.3, 20.1, "#008b8b", None),
            ("Cahokia", -90.1, 38.6, "#8b7355", None),
            ("Chimú", -79.0, -8.1, "#d2b48c", None),
            # (Europe's smaller realms, so the continent's own map has enough to fight over)
            ("Brittany", -2.8, 48.1, "#3d3d55", None),
            ("Aquitaine", 0.3, 45.0, "#4b6cb7", None),
            ("Burgundy", 4.8, 47.3, "#8b1a4a", None),
            ("Flanders", 3.2, 51.2, "#f2c500", "traders"),
            ("Saxony", 11.0, 51.5, "#6b7b8c", None),
            ("Bavaria", 11.6, 48.1, "#4f86c6", None),
            ("Tuscany", 11.2, 43.8, "#2a7f62", None),
            ("Norman Sicily", 13.4, 38.1, "#2a9d8f", "raiders"),
            ("Apulia", 16.9, 41.1, "#d2691e", None),
            ("Navarre", -1.6, 42.8, "#c23b22", "mountain"),
            ("Barcelona", 2.2, 41.4, "#e8a000", "traders"),
            ("Wales", -3.9, 53.0, "#2e8b3e", "mountain"),
            ("Duklja", 19.3, 42.4, "#8b2b3c", None),
            ("Pomerania", 14.5, 53.4, "#4d6b8a", None),
            ("Prussians", 21.0, 54.7, "#5c4033", None),
            ("Finns", 25.0, 61.5, "#4a7fc1", None),
            # (Africa and the Americas, researched 2026-11-08: the continents' own maps get their own realms)
            ("Takrur", -14.0, 16.6, "#4b5320", None),  # Africa: Takrur, its king War Jabi a Muslim ally of the Almoravids
            ("Senegambian Stone Circles", -15.0, 13.7, "#9e9e7a", None),  # Africa: Senegambian megalith builders, to c. 1100
            ("Mali (Manden)", -8.4, 11.9, "#cc5500", None),  # Africa: Mande chiefdoms of Kangaba; al-Bakri (1068) names a Muslim king of Mallal
            ("Jenne-Jeno", -4.5, 13.9, "#a67b5b", "traders"),  # Africa: Inland Niger Delta trade city
            ("Gao", 0.0, 16.3, "#8b0000", "traders"),  # Africa: Songhai kingdom of Gao, described by al-Bakri
            ("Tuareg", 6.5, 21.0, "#4169e1", None),  # Africa: Tuareg Berbers of the Aïr and Hoggar
            ("Kano", 8.5, 12.0, "#3cb371", None),  # Africa: Hausa state of Kano, founded by Bagauda c. 999 (Kano Chronicle)
            ("Ife", 4.56, 7.48, "#6a5acd", None),  # Africa: Yoruba city of Ile-Ife, rising from the 11th c.
            ("Hammadids", 4.8, 35.8, "#8a9a5b", "walls"),  # Africa: Hammadid emirate, Qal'at Beni Hammad, 1014-1152
            ("Maghrawa of Fez", -5.0, 34.0, "#708090", None),  # Africa: Zenata Maghrawa emirs of Fez until the Almoravids took it c. 1070
            ("Banu Hilal", 13.2, 32.0, "#c19a6b", "raiders"),  # Africa: Arab Banu Hilal tribes overrunning Ifriqiya from 1050s
            ("Fezzan (Banu Khattab)", 15.1, 26.2, "#deb887", "traders"),  # Africa: Banu Khattab Ibadi dynasty at Zawila, 918-1172
            ("Tubu", 18.5, 21.0, "#a52a2a", None),  # Africa: Teda/Tubu people of Tibesti
            ("Makuria", 30.6, 18.2, "#8fbc8f", None),  # Africa: Christian Nubian kingdom at Old Dongola (in periods_spec for 867 only)
            ("Alodia", 32.6, 15.6, "#4f6d7a", None),  # Africa: Christian Nubian kingdom at Soba
            ("Beja", 36.5, 19.5, "#996633", None),  # Africa: Beja of the Red Sea Hills
            ("Sultanate of Shewa", 39.9, 9.0, "#2a9d8f", None),  # Africa: Makhzumi sultanate of Shewa (trad. 896-1285)
            ("Zeila", 43.3, 11.2, "#f4a261", "traders"),  # Africa: Muslim port of Zeila on the Gulf of Aden
            ("Mogadishu", 45.2, 2.1, "#3a86ff", "traders"),  # Africa: Benadir port city, founded by the 10th c.
            ("Manda", 40.8, -2.2, "#e76f51", "traders"),  # Africa: Swahili town of the Lamu archipelago, 9th-13th c.
            ("Kilwa", 39.45, -8.95, "#b5179e", "traders"),  # Africa: Kilwa Sultanate, founded c. 957 by Ali ibn al-Hassan
            ("Mahilaka", 48.1, -13.7, "#90be6d", "traders"),  # Africa: walled Islamic trading town of northwest Madagascar, 11th-14th c.
            ("Vazimba", 47.3, -19.3, "#577590", None),  # Africa: early highland inhabitants of Madagascar in Malagasy tradition
            ("Talaky", 45.3, -25.0, "#f9844a", None),  # Africa: Talaky-phase herding villages of southern Madagascar, 11th-14th c.
            ("Chibuene", 35.35, -22.0, "#ffb4a2", "traders"),  # Africa: Mozambique coast trading site
            ("K2 (Bambandyanalo)", 29.4, -22.2, "#6d597a", "traders"),  # Africa: K2 capital in the Limpopo valley, c. 1000-1220
            ("San", 21.5, -23.5, "#c8ad7f", None),  # Africa: San hunter-gatherers of the Kalahari
            ("Khoikhoi", 19.5, -33.0, "#8d6e63", None),  # Africa: Khoikhoi herders of the Cape
            ("Blackburn culture", 30.5, -28.5, "#264653", None),  # Africa: Blackburn-phase farmers of KwaZulu-Natal, Nguni ancestors
            ("Kalomo", 26.5, -17.0, "#43aa8b", None),  # Africa: Kalomo culture of southern Zambia
            ("Kisalian (Upemba)", 26.6, -8.5, "#3d405b", None),  # Africa: Kisalian culture of the Upemba Depression
            ("Ntusi", 31.4, 0.0, "#f28482", None),  # Africa: Ntusi, cattle and grain centre of western Uganda, c. 1000-1500
            ("Mongo", 20.0, -1.0, "#2d6a4f", None),  # Africa: Bantu farmers and forest foragers of the Congo basin
            ("Mixtecs", -97.36, 17.28, "#d2691e", None),  # North America: Mixtec kingdom of Tilantongo, in the codices; Eight Deer Jaguar Claw born 1063
            ("Aztatlán", -105.0, 21.8, "#cd5c5c", "traders"),  # North America: Aztatlán trading towns of the Nayarit-Sinaloa coast, c. 850-1350
            ("Maya Cities", -89.6, 20.7, "#00a86b", "builders"),  # North America: Chichén Itzá and the Yucatec Maya cities at their height
            ("Lenca", -87.8, 14.3, "#6b8e23", None),  # North America: Lenca chiefdoms of Honduras
            ("Nicoya", -85.4, 10.3, "#9370db", None),  # North America: Greater Nicoya chiefdoms
            ("Coclé", -80.4, 8.5, "#f0c419", None),  # North America: Gran Coclé chiefdoms of Panama
            ("Taíno", -70.7, 19.0, "#ff6347", None),  # North America: Taíno chiefdoms of Hispaniola
            ("Guanahatabey", -83.6, 22.5, "#708090", None),  # North America: archaic foragers of western Cuba
            ("Igneri", -61.5, 16.2, "#9acd32", None),  # North America: Arawak-speaking Lesser Antilles islanders
            ("Ancestral Puebloans", -107.96, 36.06, "#e9d8a6", "builders"),  # North America: Chaco Canyon great houses at their peak, c. 1030-1130
            ("Hohokam", -111.9, 33.4, "#cd853f", "builders"),  # North America: Hohokam canal towns, Snaketown
            ("Mogollon", -108.0, 32.8, "#6b4226", None),  # North America: Classic Mimbres Mogollon, c. 1000-1130
            ("Fremont", -111.8, 39.2, "#8fbc8f", None),  # North America: Fremont culture of Utah
            ("Chumash", -119.7, 34.5, "#1e90ff", "traders"),  # North America: Chumash of the Santa Barbara Channel
            ("Coast Salish", -122.5, 49.2, "#2e8b57", None),  # North America: Coast Salish of the Fraser delta and Puget Sound
            ("Haida", -132.1, 53.3, "#dc143c", None),  # North America: Haida of Haida Gwaii
            ("Central Plains Tradition", -98.5, 40.0, "#c5b358", None),  # North America: Central Plains tradition earthlodge villages, c. 1000-1400
            ("Avonlea", -105.5, 50.5, "#7b68ee", None),  # North America: Avonlea bison hunters of the northern Plains
            ("Middle Missouri", -100.8, 46.8, "#a0522d", None),  # North America: Middle Missouri villages (Mandan/Hidatsa ancestors), from c. 1000
            ("Etowah", -84.8, 34.1, "#b03060", None),  # North America: Mississippian mound centre in Georgia, from c. 1000
            ("Spiro", -94.6, 35.3, "#ff4500", "traders"),  # North America: Caddoan Mississippian centre at Spiro, Oklahoma
            ("Coles Creek", -91.4, 31.6, "#6495ed", None),  # North America: Coles Creek mound culture of the lower Mississippi
            ("Fort Ancient", -83.5, 39.0, "#e9967a", None),  # North America: Fort Ancient villages of the Ohio valley, from c. 1000
            ("Owasco", -76.5, 42.6, "#6a0dad", None),  # North America: Owasco culture (Iroquoian ancestors), c. 1000-1300
            ("Eastern Algonquians", -71.5, 42.5, "#8b8b00", None),  # North America: Eastern Algonquian peoples of New England
            ("St. Johns", -81.3, 29.6, "#4b0082", None),  # North America: St. Johns culture of northeast Florida
            ("Calusa", -81.86, 26.42, "#20b2aa", None),  # North America: Calusa of southwest Florida
            ("Cree", -77.5, 51.5, "#87ceeb", None),  # North America: Algonquian hunters of the James Bay forests
            ("Dene", -120.0, 62.5, "#36454f", None),  # North America: Athabaskan (Dene) peoples of the Mackenzie basin
            ("Thule", -156.6, 71.2, "#add8e6", None),  # North America: Thule (Inuit ancestors) whalers of north Alaska, from c. 1000
            ("Dorset", -84.0, 68.5, "#b0c4de", None),  # North America: Late Dorset (Paleo-Inuit) of the eastern Arctic
            ("Norse Greenland", -50.8, 64.2, "#c8102e", None),  # North America: Norse Western Settlement (Nuuk fjord), from c. 985; Eastern Settlement lies off the map edge
            ("Aleuts", -166.5, 53.9, "#4f7942", None),  # North America: Unangan (Aleut) of the Aleutian Islands
            ("Beothuk", -56.0, 49.0, "#e2725b", None),  # North America: Beothuk ancestors of Newfoundland
            ("Tiwanaku", -68.7, -16.6, "#c2a878", "mountain"),  # South America: Tiwanaku in its last phase, collapsing c. 1000-1100 (in periods_spec for 867 only)
            ("Killke", -71.97, -13.52, "#b22222", "mountain"),  # South America: Killke culture of the Cusco valley, c. 900-1200
            ("Pachacamac", -76.85, -12.25, "#800080", "faith"),  # South America: Ychsma lordship and the oracle of Pachacamac
            ("Manteño", -80.7, -1.0, "#20b2aa", "traders"),  # South America: Manteño seafaring traders of coastal Ecuador
            ("Quitu-Cara", -78.0, 0.45, "#6b8e23", "mountain"),  # South America: Quitu and Cara chiefdoms of highland Ecuador
            ("Muisca", -73.4, 5.5, "#daa520", None),  # South America: Muisca chiefdoms of the Bogotá plateau
            ("Tairona", -73.9, 11.0, "#ffa07a", "mountain"),  # South America: Tairona towns of the Sierra Nevada de Santa Marta
            ("Timoto-Cuica", -71.1, 8.6, "#5b8db8", "mountain"),  # South America: terrace farmers of the Venezuelan Andes
            ("Valencia Culture", -67.8, 10.1, "#7e57c2", None),  # South America: mound villages around Lake Valencia
            ("Arauquinoid", -66.0, 7.5, "#1b7f5a", None),  # South America: Arauquinoid chiefdoms of the middle Orinoco
            ("Lokono", -58.0, 6.3, "#006400", None),  # South America: Arawak (Lokono) peoples of the Guiana coast
            ("Aristé", -51.2, 2.5, "#ff69b4", None),  # South America: Aristé culture of Amapá
            ("Marajoara", -49.5, -0.9, "#c04000", "builders"),  # South America: mound-building chiefdoms of Marajó
            ("Tapajós (Santarém)", -54.7, -2.5, "#8b4513", None),  # South America: Tapajó chiefdom at Santarém, from c. 1000
            ("Amazon Polychrome (Guarita)", -60.0, -3.2, "#e9967a", None),  # South America: Guarita-phase towns of the central Amazon, from c. 900
            ("Casarabe", -64.9, -14.7, "#3cb371", "builders"),  # South America: Casarabe causeway towns of the Llanos de Mojos
            ("Cumancaya", -74.4, -8.4, "#4169e1", None),  # South America: Cumancaya culture of the Ucayali
            ("Atacameño", -68.2, -22.9, "#8b5a7a", "traders"),  # South America: San Pedro de Atacama oasis people
            ("Santa María", -66.05, -26.7, "#708090", None),  # South America: Santa María culture of the Calchaquí valleys, c. 1000-1470
            ("Diaguita", -70.6, -30.0, "#ff4500", None),  # South America: Diaguita of the Elqui and Limarí valleys, from c. 1000
            ("Huarpe", -67.3, -32.8, "#f4a460", None),  # South America: Huarpe farmers of Cuyo
            ("Comechingón", -64.5, -31.4, "#8fbc8f", None),  # South America: Comechingón of the Córdoba hills
            ("Guaycuru", -60.5, -24.5, "#cd853f", None),  # South America: Guaycuruan foragers of the Gran Chaco
            ("Querandí", -58.7, -35.0, "#bdb76b", None),  # South America: Querandí hunters of the Pampas
            ("Charrúa", -56.0, -32.5, "#87ceeb", None),  # South America: Charrúa of Uruguay
            ("Mapuche", -72.6, -38.7, "#0033a0", None),  # South America: Mapuche (El Vergel culture, from c. 1000) of Araucanía
            ("Tehuelche", -69.0, -45.5, "#a9a9a9", None),  # South America: Tehuelche guanaco hunters of Patagonia
            ("Chonos", -73.0, -45.5, "#2f4f4f", None),  # South America: Chonos canoe people of Aysén
            ("Selk'nam", -68.6, -54.0, "#c0c0c0", None),  # South America: Selk'nam of Tierra del Fuego
            ("Guarani", -56.5, -25.5, "#228b22", None),  # South America: Guarani farming villages of the Paraná basin
            ("Taquara", -51.5, -28.8, "#6a5acd", None),  # South America: Taquara/Itararé pit-house villages
            ("Tupinambá", -43.3, -22.6, "#ff6347", None),  # South America: Tupinambá (Tupi) villages of the southeast Brazilian coast
            ("Aratu", -39.5, -12.5, "#b5651d", None),  # South America: Aratu village tradition of Bahia
            ("Akwẽ", -48.0, -15.0, "#9b870c", None),  # South America: Jê-speaking peoples of the cerrado
            ("Xinguano", -53.2, -12.2, "#ff7f50", None),  # South America: Upper Xingu villages (Kuikuro ancestors)
            # (2026-11-08: real realms for the grey land, tools/maps/coverage.py's holes)
            ("Guanches", -16.5, 28.3, "#d4a373", "mountain"),  # africa: d4a373", "mountain"),  # Wikipedia: Guanches (Canary Islands natives, here long before 1402)
            ("Ghadames", 9.5, 30.13, "#e0c068", "traders"),  # africa: e0c068", "traders"),  # Wikipedia: Ghadames (Berber oasis city on the trans-Saharan route)
            ("Masufa", -5.0, 23.6, "#b08d57", "traders"),  # africa: b08d57", "traders"),  # Wikipedia: Masufa (Sanhaja Berber tribe of the western Sahara, Taghaza salt road)
            ("Mbuti", 28.5, 1.5, "#4e7d3a", None),  # africa: 4e7d3a", None),  # Wikipedia: Mbuti people (forest foragers of the Ituri)
            ("Aka", 17.8, 3.6, "#6a994e", None),  # africa: 6a994e", None),  # Wikipedia: Aka people (Mbenga foragers of the Lobaye/Sangha forest)
            ("Baka", 14.5, 3.0, "#386641", None),  # africa: 386641", None),  # Wikipedia: Baka people (Cameroon and Gabon) (forest foragers of southeast Cameroon)
            ("Bongo", 11.5, -1.5, "#2a9d8f", None),  # africa: 2a9d8f", None),  # Wikipedia: Bongo people (Gabon) (forest foragers of Gabon)
            ("Kwadi", 13.0, -15.0, "#bc6c25", None),  # africa: bc6c25", None),  # Wikipedia: Kwadi people (Khoe-Kwadi foragers and herders of southwest Angola)
            ("!Kung", 19.0, -18.0, "#dda15e", None),  # africa: dda15e", None),  # Wikipedia: !Kung people (Ju-speaking San of northern Namibia and southeast Angola)
            ("Nama", 17.5, -26.5, "#a0785a", None),  # africa: a0785a", None),  # Wikipedia: Nama people (Khoekhoe herders of southern Namibia)
            ("Damara", 15.5, -21.5, "#7f5539", None),  # africa: 7f5539", None),  # Wikipedia: Damara people (ancient inhabitants of central and northwest Namibia)
            ("Mahra", 51.8, 15.9, "#9c6644", None),  # africa: 9c6644", None),  # Wikipedia: Mahra tribe (South Arabian people of al-Mahrah, eastern Yemen)
            ("Tayy", 41.7, 27.5, "#c9b458", "steppe"),  # africa: c9b458", "steppe"),  # Wikipedia: Tayy (Arab tribe of Jabal Aja and Salma, Ha'il)
            ("Guddala", -16.0, 21.5, "#6c757d", None),  # africa: 6c757d", None),  # Wikipedia: Guddala (Sanhaja tribe of the Atlantic Sahara, Yahya ibn Ibrahim's people)
            ("Zaghawa", 22.5, 15.3, "#8c5e3c", None),  # africa: 8c5e3c", None),  # Wikipedia: Zaghawa people (named by al-Yaqubi, 872)
            ("Banu Sulaym", 20.5, 32.0, "#c19a6b", "raiders"),  # africa: c19a6b", "raiders"),  # Wikipedia: Banu Sulaym (moved into Cyrenaica from c. 1050; already in the 1187/1241 lists)
            ("Banu Kanz", 32.9, 24.1, "#c08552", None),  # africa: c08552", None),  # Wikipedia: Banu Kanz (Kanz al-Dawla emirs of Aswan, from 1004)
            ("Begho", -2.6, 8.2, "#e76f51", "traders"),  # africa: e76f51", "traders"),  # Wikipedia: Begho (gold-trade town of the forest edge, 11th-18th c.)
            ("Kingdom of Damot", 37.75, 6.85, "#606c38", None),  # africa: 606c38", None),  # Wikipedia: Kingdom of Damot (southern Ethiopia, 10th-13th c.)
            ("Imamate of Oman", 57.53, 22.93, "#b5172f", "faith"),  # africa: b5172f", "faith"),  # Wikipedia: Imamate of Oman (second Ibadi imamate, Nizwa)
            ("Seljuks of Kerman", 57.08, 30.28, "#2b9348", "steppe"),  # africa: 2b9348", "steppe"),  # Wikipedia: Kerman Seljuk Sultanate (1041-1187)
            ("Shabankara", 54.3, 29.0, "#9e2a2b", "mountain"),  # africa: 9e2a2b", "mountain"),  # Wikipedia: Shabankara (Kurdish rulers of Fars, c. 1030-1355)
            ("Qarmatians", 49.6, 25.4, "#3d405b", "raiders"),  # africa: 3d405b", "raiders"),  # Wikipedia: Qarmatians (state of Bahrayn at al-Ahsa, 899-1077)
            ("Sulayhid dynasty", 44.2, 15.35, "#6d597a", None),  # africa: 6d597a", None),  # Wikipedia: Sulayhid dynasty (Sanaa, 1047-1138)
            ("Sharifate of Mecca", 39.83, 21.42, "#2d6a4f", "faith"),  # africa: 2d6a4f", "faith"),  # Wikipedia: Sharifate of Mecca (from 967)
            ("Marwanids", 41.0, 38.1, "#7f4f24", None),  # africa: 7f4f24", None),  # Wikipedia: Marwanids (Diyar Bakr) (Mayyafariqin, 990-1085)
            ("Mazyadids", 44.42, 32.48, "#a68a64", None),  # africa: a68a64", None),  # Wikipedia: Mazyadids (Banu Asad emirs of central Iraq, 961-1150)
            ("Gwich'in", -141.0, 67.5, "#4a6741", None),  # americas: 4a6741', None),  # Wikipedia: Gwich'in
            ("Koyukon", -156.5, 65.6, "#7d6b91", None),  # americas: researched 2026-11-08
            ("Tlingit", -135.4, 58.8, "#b03a2e", "raiders"),  # americas: researched 2026-11-08
            ("Taltheilei", -104.0, 61.5, "#8a9a5b", None),  # americas: researched 2026-11-08
            ("Dane-zaa", -118.5, 56.2, "#996633", None),  # americas: researched 2026-11-08
            ("Karuk", -123.5, 41.4, "#5d8aa8", None),  # americas: researched 2026-11-08
            ("Cochimí", -112.3, 26.6, "#c2b280", None),  # americas: researched 2026-11-08
            ("Mi'kmaq", -65.3, 46.6, "#1c4f82", None),  # americas: 1c4f82', None),  # Wikipedia: Mi'kmaq
            ("Point Revenge", -60.4, 54.0, "#6e7f80", None),  # americas: researched 2026-11-08
            ("Kaska", -128.5, 59.5, "#7a5c3e", None),  # americas: researched 2026-11-08
            ("Ahtna", -145.3, 62.1, "#b87333", None),  # americas: researched 2026-11-08
            ("Juntunen", -85.0, 46.6, "#5f7f5f", None),  # americas: researched 2026-11-08
            ("Kawésqar", -74.3, -51.0, "#3f5f7f", None),  # americas: researched 2026-11-08
            ("Goitacá", -41.3, -21.75, "#a0522d", None),  # americas: researched 2026-11-08
            ("Timbira", -46.5, -6.5, "#b8860b", None),  # americas: researched 2026-11-08
            ("Tremembé", -39.8, -3.2, "#e07b39", None),  # americas: researched 2026-11-08
            ("Paresí", -57.5, -13.0, "#6b8e23", None),  # americas: researched 2026-11-08
            ("Bororo", -55.5, -16.5, "#c71585", None),  # americas: researched 2026-11-08
            ("Yanomami", -64.0, 2.5, "#2e8b57", None),  # americas: researched 2026-11-08
            ("Ticuna", -69.3, -3.0, "#8b0000", None),  # americas: researched 2026-11-08
            ("Chané", -62.8, -19.3, "#daa520", None),  # americas: researched 2026-11-08
            ("Apurinã", -65.2, -8.0, "#556b2f", None),  # americas: researched 2026-11-08
            ("Sapucaí", -46.8, -21.3, "#9370db", None),  # americas: researched 2026-11-08
            ("Karajá", -50.3, -9.5, "#cd5c5c", None),  # americas: researched 2026-11-08
            ("Yup'ik", -161.8, 60.8, "#8b6f47", None),  # americas: 8b6f47', None),  # Wikipedia: Yup'ik
            ("Kachemak", -151.5, 59.6, "#4682b4", None),  # americas: researched 2026-11-08
            ("Blackduck", -94.0, 51.5, "#2f2f4f", None),  # americas: researched 2026-11-08
            ("Old Women's", -113.0, 50.0, "#9b7653", None),  # americas: 9b7653', None),  # Wikipedia: Old Women's phase
            ("Puelche", -64.5, -40.5, "#deb887", None),  # americas: researched 2026-11-08
            ("Potiguara", -35.4, -6.9, "#ff8c69", None),  # americas: researched 2026-11-08
            ("Western Kara-Khanids", 66.96, 39.65, "#8b5a2b", "steppe"),  # asia: 8b5a2b", "steppe"),  # Wikipedia: Kara-Khanid Khanate (west, Samarkand)
            ("Eastern Kara-Khanids", 75.25, 42.75, "#a0522d", "steppe"),  # asia: a0522d", "steppe"),  # Wikipedia: Kara-Khanid Khanate (east, Balasagun)
            ("Kipchaks", 68.0, 50.0, "#b5a642", "steppe"),  # asia: b5a642", "steppe"),          # Wikipedia: Kipchaks
            ("Bashkirs", 56.5, 54.0, "#4f8f4f", None),  # asia: 4f8f4f", None),             # Wikipedia: Bashkirs (Sallam the Interpreter, 9th c.)
            ("Kingdom of Qocho", 89.5, 42.85, "#5f9ea0", "traders"),  # asia: 5f9ea0", "traders"),  # Wikipedia: Kingdom of Qocho (843-1335)
            ("Tsongkha", 101.78, 36.62, "#8b4513", "faith"),  # asia: 8b4513", "faith"),        # Wikipedia: Tsongkha (997-1104, Qingtang)
            ("Guge", 79.8, 31.5, "#a0522d", "mountain"),  # asia: a0522d", "mountain"),            # Wikipedia: Guge
            ("Kyrgyz Khaganate", 91.5, 53.7, "#6b8e23", "steppe"),  # asia: 6b8e23", "steppe"),  # Wikipedia: Yenisei Kyrgyz
            ("Keraites", 104.0, 47.5, "#7f8fa8", "steppe"),  # asia: 7f8fa8", "steppe"),         # Wikipedia: Keraites (Christian from 1007)
            ("Tatars", 116.5, 48.3, "#5e8fa8", "steppe"),  # asia: 5e8fa8", "steppe"),          # Wikipedia: Tatar confederation (8th c.-1202)
            ("Jurchens", 129.6, 46.3, "#6b8e5a", None),  # asia: 6b8e5a", None),             # Wikipedia: Jurchen people (Wanyan under Wugunai)
            ("Mansi", 62.5, 61.3, "#5b7c99", None),  # asia: 5b7c99", None),           # Wikipedia: Mansi people
            ("Khanty", 70.5, 60.5, "#3f6f8f", None),  # asia: 3f6f8f", None),          # Wikipedia: Khanty
            ("Selkups", 82.0, 59.3, "#6a8caf", None),  # asia: 6a8caf", None),         # Wikipedia: Selkup people
            ("Kets", 90.5, 62.5, "#4a6b5a", None),  # asia: 4a6b5a", None),            # Wikipedia: Kets
            ("Evenks", 112.0, 64.0, "#2e6f6f", None),  # asia: 2e6f6f", None),         # Wikipedia: Evenks
            ("Yukaghirs", 138.0, 67.5, "#7a8b99", None),  # asia: 7a8b99", None),      # Wikipedia: Yukaghir people
            ("Chukchi", 172.0, 67.5, "#9ab0c4", None),  # asia: 9ab0c4", None),        # Wikipedia: Chukchi people
            ("Siberian Yupiks", -170.5, 65.8, "#b0c4de", "raiders"),  # asia: b0c4de", "raiders"),  # Wikipedia: Siberian Yupik (Old Bering Sea/Punuk ancestors)
            ("Koryaks", 160.5, 62.0, "#6f7f8f", None),  # asia: 6f7f8f", None),        # Wikipedia: Koryaks
            ("Itelmens", 157.0, 53.3, "#4b7f6a", None),  # asia: 4b7f6a", None),       # Wikipedia: Itelmens
            ("Nivkh", 140.4, 52.8, "#3b5f7f", None),  # asia: 3b5f7f", None),          # Wikipedia: Nivkh people
            ("Nenets", 70.0, 68.0, "#8fa8b8", None),  # asia: 8fa8b8", None),                # Wikipedia: Nenets
            ("Okhotsk culture", 144.27, 44.0, "#5f7fa0", "raiders"),  # asia: 5f7fa0", "raiders"),  # Wikipedia: Okhotsk culture (5th-13th c.)
            ("Ukhaidhirids", 47.3, 23.0, "#9c6b30", None),  # asia: 9c6b30", None),        # Wikipedia: Ukhaidhirids (867-11th c., al-Khidrima)
            ("Chaulukyas", 72.1, 23.85, "#d2691e", "builders"),  # asia: d2691e", "builders"),     # Wikipedia: Chaulukya dynasty (Anahilapataka)
            ("Eastern Gangas", 84.0, 18.6, "#ff7f50", "builders"),  # asia: ff7f50", "builders"),  # Wikipedia: Eastern Ganga dynasty (Vajrahasta V, Kalinganagara)
            ("Dali", 100.2, 25.6, "#9acd32", "mountain"),  # asia: 9acd32", "mountain"),           # Wikipedia: Dali Kingdom (937-1253)
            ("Champa", 109.1, 13.9, "#cd5c5c", None),  # asia: cd5c5c", None),               # Wikipedia: Champa (Vijaya)
            ("Srivijaya", 104.7, -3.0, "#20b2aa", "traders"),  # asia: 20b2aa", "traders"),       # Wikipedia: Srivijaya
            ("Lamuri", 95.4, 5.55, "#2a9d8f", "traders"),  # asia: 2a9d8f", "traders"),          # Wikipedia: Lamuri Kingdom (Ramni, 9th c. Arab sources)
            ("Kediri", 112.0, -7.8, "#d4a373", None),  # asia: d4a373", None),               # Wikipedia: Kediri Kingdom (1042-1222)
            ("Bali", 115.3, -8.5, "#e5989b", None),  # asia: e5989b", None),                 # Wikipedia: Bali Kingdom (Warmadewa, Anak Wungsu)
            ("Po-ni", 114.9, 4.9, "#f4a261", "traders"),  # asia: f4a261", "traders"),            # Wikipedia: Po-ni
            ("Butuan", 125.54, 8.95, "#3a86ff", "traders"),  # asia: 3a86ff", "traders"),         # Wikipedia: Rajahnate of Butuan
            ("Tondo", 120.97, 14.62, "#ffbe0b", "traders"),  # asia: ffbe0b", "traders"),         # Wikipedia: Tondo (historical polity)
            ("Motu", 147.2, -9.45, "#e76f51", "traders"),  # asia: e76f51", "traders"),     # Wikipedia: Motu people
            ("Chimbu", 144.97, -6.02, "#386641", "mountain"),  # asia: 386641", "mountain"),  # Wikipedia: Chimbu people
            ("Sentani", 140.5, -2.6, "#2a9d8f", None),  # asia: 2a9d8f", None),        # Wikipedia: Sentani people
            ("Biak", 136.05, -1.05, "#264653", "raiders"),  # asia: 264653", "raiders"),    # Wikipedia: Biak people
            ("Noongar", 117.2, -33.3, "#8c4a2f", None),  # asia: 8c4a2f", None),       # Wikipedia: Noongar
            ("Martu", 121.5, -22.5, "#d2691e", None),  # asia: d2691e", None),         # Wikipedia: Martu people
            ("Warlpiri", 131.0, -20.6, "#a0522d", None),  # asia: a0522d", None),      # Wikipedia: Warlpiri
            ("Arrernte", 133.9, -23.7, "#cd853f", None),  # asia: cd853f", None),      # Wikipedia: Arrernte people
            ("Tiwi", 130.9, -11.6, "#7a5230", "raiders"),  # asia: 7a5230", "raiders"),     # Wikipedia: Tiwi people
            ("Yolngu", 136.4, -12.6, "#9b2d20", None),  # asia: 9b2d20", None),         # Wikipedia: Yolngu
            ("Kuku Yalanji", 145.2, -16.2, "#556b2f", None),  # asia: 556b2f", None),  # Wikipedia: Kuku Yalanji
            ("Wiradjuri", 147.0, -33.0, "#6b4226", None),  # asia: 6b4226", None),     # Wikipedia: Wiradjuri
            ("Dharug", 150.9, -33.8, "#a52a2a", None),  # asia: a52a2a", None),        # Wikipedia: Dharug
            ("Kulin", 145.0, -37.7, "#4f6d7a", None),  # asia: 4f6d7a", None),         # Wikipedia: Kulin
            ("Palawa", 146.8, -42.0, "#2f4f4f", None),  # asia: 2f4f4f", None),        # Wikipedia: Aboriginal Tasmanians
            ("Kanak", 165.4, -21.3, "#2d6a4f", None),  # asia: 2d6a4f", None),         # Wikipedia: Kanak people
            ("Amis", 121.4, 23.5, "#e9c46a", None),  # asia: e9c46a", None),           # Wikipedia: Amis people
            ("Andamanese", 92.75, 12.3, "#5c4033", None),  # asia: 5c4033", None),     # Wikipedia: Andamanese peoples
            ("Icelandic Commonwealth", -21.0, 64.2, "#2a5f9e", None),  # europe: 2a5f9e", None),  # Wikipedia: Icelandic Commonwealth
            ("Sámi", 20.5, 69.3, "#d9442b", None),  # europe: d9442b", None),  # Wikipedia: Sámi people (Ohthere's "Finnas", 9th c.)
            ("Bjarmians", 41.0, 64.6, "#7c5a3a", "traders"),  # europe: 7c5a3a", "traders"),  # Wikipedia: Bjarmaland
            ("Pechera", 45.5, 67.4, "#6a5a4a", None),  # europe: 6a5a4a", None),  # Wikipedia: Pechora (people)
            ("Terfinns", 33.5, 68.8, "#b85c38", None),  # europe: b85c38", None),  # Wikipedia: Ohthere of Hålogaland (Terfinnas of Kola)
            ("Kvens", 24.5, 65.8, "#5b7f3a", None),  # europe: 5b7f3a", None),  # Wikipedia: Kvenland
            ("Karelians", 31.0, 62.0, "#3f7f6f", None),  # europe: 3f7f6f", None),  # Wikipedia: Karelians
            ("Perm", 45.5, 61.6, "#8a6d3b", None),  # europe: 8a6d3b", None),  # Wikipedia: Komi peoples (chronicle "Perm" of the Vychegda)
            ("Mordvins", 44.6, 54.3, "#9f4f3f", None),  # europe: 9f4f3f", None),  # Wikipedia: Mordvins
            ("Burtas", 45.2, 52.3, "#a0703c", None),  # europe: a0703c", None),  # Wikipedia: Burtas
            ("Muroma", 42.0, 55.6, "#7f5f8f", None),  # europe: 7f5f8f", None),  # Wikipedia: Muroma
            ("Polotsk", 28.8, 55.5, "#6b8e5a", None),  # europe: 6b8e5a", None),  # Wikipedia: Principality of Polotsk (Vseslav)
            ("Chernigov", 31.3, 51.5, "#4f7f2f", None),  # europe: 4f7f2f", None),  # Wikipedia: Principality of Chernigov (Sviatoslav II)
            ("Tmutarakan", 36.8, 45.2, "#3f6f8f", "traders"),  # europe: 3f6f8f", "traders"),  # Wikipedia: Tmutarakan
            ("Alania", 44.2, 43.6, "#b08f3f", "mountain"),  # europe: b08f3f", "mountain"),  # Wikipedia: Alania
            ("Kasogs", 39.2, 44.5, "#3f8f8f", "mountain"),  # europe: 3f8f8f", "mountain"),  # Wikipedia: Kasogs
            ("Pechenegs", 27.5, 46.0, "#a07a3a", "steppe"),  # europe: a07a3a", "steppe"),  # Wikipedia: Pechenegs
            ("Estonians", 25.5, 58.7, "#2f5f9f", None),  # europe: 2f5f9f", None),  # Wikipedia: Ancient Estonia
            ("Latgalians", 26.8, 56.5, "#9f2f4f", None),  # europe: 9f2f4f", None),  # Wikipedia: Latgalians
            ("Earldom of Orkney", -3.3, 59.1, "#5f4f8f", "raiders"),  # europe: 5f4f8f", "raiders"),  # Wikipedia: Earl of Orkney (Paul and Erlend Thorfinnsson)
            ("Faroe Islands", -6.8, 62.0, "#3f5f8f", None),  # europe: 3f5f8f", None),  # Wikipedia: History of the Faroe Islands
            ("Jämtland", 14.6, 63.2, "#4f8fbf", None),  # europe: 4f8fbf", None),  # Wikipedia: Jämtland (Jamtamót)
            ("Mirdasids", 37.2, 36.2, "#4f8f2f", None),  # europe: 4f8f2f", None),  # Wikipedia: Mirdasid dynasty (Aleppo)
            ("Uqaylids", 43.1, 36.3, "#8f7f2f", None),  # europe: 8f7f2f", None),  # Wikipedia: Uqaylid dynasty (Mosul)
            ("Vyatichi", 36.5, 54.0, "#5f5f3f", None),  # europe: 5f5f3f", None),  # Wikipedia: Vyatichi
            ("Yotvingians", 23.3, 53.6, "#6f4f2f", None),  # europe: 6f4f2f", None),  # Wikipedia: Yotvingians
            ("Judicate of Arborea", 8.6, 39.9, "#c0a030", None),  # europe: c0a030", None),  # Wikipedia: Judicate of Arborea
            ("Taifa of Denia", -0.1, 38.8, "#3f8f5f", "raiders"),  # europe: 3f8f5f", "raiders"),  # Wikipedia: Taifa of Dénia
            ("County of Provence", 5.45, 43.5, "#e0b020", None),  # europe: e0b020", None),  # Wikipedia: County of Provence
        ]),
    dict(key="1187", year=1187, name="The Third Crusade",
         blurb="Saladin has taken Jerusalem; the kings of the West take the cross.",
         realms=[
            ("Angevin Empire", -0.5, 47.4, "#c8102e", "legions"),
            ("France", 2.3, 48.8, "#2c4f9e", None),
            ("Scotland", -3.2, 56.0, "#1f4e9c", "mountain"),
            ("Ireland", -7.6, 53.3, "#2e8b57", None),
            ("Norway", 10.4, 63.4, "#3a6ea5", None),
            ("Denmark", 12.6, 55.7, "#a61c3c", None),
            ("Sweden", 17.6, 59.9, "#2b5aa8", None),
            ("Holy Roman Empire", 9.0, 50.6, "#d9b41a", "legions"),
            ("Sicily", 13.4, 38.1, "#2a9d8f", "traders"),
            ("Venice", 12.3, 45.4, "#c69214", "traders"),
            ("Genoa", 8.9, 44.4, "#b03060", "traders"),
            ("Papal States", 12.5, 41.9, "#e8d48a", "faith"),
            ("Castile", -4.7, 41.6, "#b22234", "faith"),
            ("León", -5.6, 42.6, "#9b2335", None),
            ("Aragon", -0.9, 41.6, "#e8b923", None),
            ("Portugal", -8.6, 40.2, "#006847", None),
            ("Almohad Caliphate", -8.0, 31.6, "#3b7a57", "faith"),
            ("Poland", 19.9, 50.1, "#dc143c", None),
            ("Hungary", 19.0, 47.5, "#7f3f98", None),
            ("Bohemia", 14.4, 50.1, "#5b6c8a", None),
            ("Serbia", 20.5, 43.3, "#8b2b3c", None),
            ("Bulgaria", 25.6, 43.1, "#3c8d3c", None),
            ("Byzantium", 28.98, 41.0, "#6a1b9a", "walls"),
            ("Sultanate of Rûm", 32.5, 37.9, "#2d6e8f", "steppe"),
            ("Kingdom of Jerusalem", 35.2, 31.8, "#f0f0e0", "faith"),
            ("Ayyubid Sultanate", 31.2, 30.0, "#e6b800", "faith"),
            ("Georgia", 44.8, 41.7, "#c0392b", "mountain"),
            ("Vladimir-Suzdal", 40.4, 56.1, "#2f6b3a", None),
            ("Novgorod", 31.3, 58.5, "#4a7d4f", "traders"),
            ("Kiev", 30.5, 50.4, "#3d8b5a", None),
            ("Cumans", 40.0, 48.0, "#c9a227", "steppe"),
            ("Abbasid Caliphate", 44.4, 33.3, "#1b1b1b", "bureau"),
            ("Khwarazm", 60.6, 41.4, "#6f4e37", "steppe"),
            ("Ghurids", 64.4, 34.4, "#8b5a2b", "mountain"),
            ("Kara-Khitai", 75.0, 42.8, "#4682b4", "steppe"),
            ("Mongol Tribes", 108.0, 48.0, "#7ec8e3", "steppe"),
            ("Jin", 116.4, 39.9, "#c0a060", "legions"),
            ("Southern Song", 120.2, 30.3, "#d4a017", "bureau"),
            ("Western Xia", 106.2, 38.5, "#b5a642", None),
            ("Tibet", 91.1, 29.6, "#8b4513", "mountain"),
            ("Goryeo", 126.5, 37.9, "#4169e1", None),
            ("Japan", 135.8, 35.0, "#bc002d", "walls"),
            ("Dai Viet", 105.8, 21.0, "#cd5c5c", None),
            ("Khmer", 103.9, 13.4, "#b8860b", "builders"),
            ("Chola", 79.1, 10.8, "#c71585", "traders"),
            ("Ghana Empire", -7.9, 15.7, "#daa520", None),
            ("Ethiopia", 39.0, 12.0, "#228b22", "mountain"),
            ("Chimú", -79.0, -8.1, "#d2b48c", None),
            ("Cahokia", -90.1, 38.6, "#8b7355", None),
            # (Europe's smaller realms, so the continent's own map has enough to fight over)
            ("Brittany", -2.8, 48.1, "#3d3d55", None),
            ("Burgundy", 4.8, 47.3, "#8b1a4a", None),
            ("Flanders", 3.2, 51.2, "#f2c500", "traders"),
            ("Toulouse", 1.4, 43.6, "#d4a017", None),
            ("Navarre", -1.6, 42.8, "#c23b22", "mountain"),
            ("Wales", -3.9, 53.0, "#2e8b3e", "mountain"),
            ("Saxony", 11.0, 51.5, "#6b7b8c", None),
            ("Bavaria", 11.6, 48.1, "#4f86c6", None),
            ("Austria", 16.4, 48.2, "#e8e0d0", None),
            ("Pomerania", 14.5, 53.4, "#4d6b8a", None),
            ("Prussians", 21.0, 54.7, "#5c4033", None),
            ("Finns", 25.0, 61.5, "#4a7fc1", None),
            ("Bosnia", 18.4, 43.9, "#f2c500", "mountain"),
            ("Galicia-Volhynia", 24.0, 49.8, "#3d8b5a", None),
            ("Polotsk", 28.8, 55.5, "#6b8e5a", None),
            ("Smolensk", 32.0, 54.8, "#4a7d6a", None),
            # (Africa and the Americas, researched 2026-11-08: the continents' own maps get their own realms)
            ("Takrur", -14.0, 16.6, "#4b5320", None),  # Africa: Muslim kingdom of Takrur on the Senegal River (al-Idrisi, 1154)
            ("Mali (Manden)", -8.4, 11.9, "#cc5500", None),  # Africa: Mande chiefdoms of Kangaba, before Sundiata
            ("Jenne", -4.5, 13.9, "#a67b5b", "traders"),  # Africa: Jenne, Inland Niger Delta trade city
            ("Gao", 0.0, 16.3, "#8b0000", "traders"),  # Africa: Songhai kingdom of Gao (Za/Zuwa dynasty)
            ("Tuareg", 6.5, 21.0, "#4169e1", None),  # Africa: Tuareg Berbers of the Aïr and Hoggar
            ("Kano", 8.5, 12.0, "#3cb371", None),  # Africa: Hausa state of Kano (Kano Chronicle)
            ("Ife", 4.56, 7.48, "#6a5acd", None),  # Africa: classical Ile-Ife, bronze and terracotta heads, c. 1100-1400
            ("Kanem", 14.0, 13.5, "#a0522d", None),  # Africa: Sayfawa Kanem at Njimi (in periods_spec for the other dates, not 1187)
            ("Daju", 24.3, 13.0, "#9acd32", None),  # Africa: Daju kingdom of Darfur's Jebel Marra, c. 12th-15th c.
            ("Tubu", 18.5, 21.0, "#a52a2a", None),  # Africa: Teda/Tubu people of Tibesti
            ("Banu Ghaniya", 8.8, 34.4, "#4682b4", "raiders"),  # Africa: Almoravid heirs invading Ifriqiya from 1184
            ("Banu Sulaym", 20.5, 32.0, "#c19a6b", "raiders"),  # Africa: Arab Banu Sulaym tribes of Cyrenaica and Tripolitania
            ("Makuria", 30.6, 18.2, "#8fbc8f", None),  # Africa: Christian Nubian kingdom at Old Dongola
            ("Alodia", 32.6, 15.6, "#4f6d7a", None),  # Africa: Christian Nubian kingdom at Soba
            ("Beja", 36.5, 19.5, "#996633", None),  # Africa: Beja of the Red Sea Hills
            ("Sultanate of Shewa", 39.9, 9.0, "#2a9d8f", None),  # Africa: Makhzumi sultanate of Shewa
            ("Zeila", 43.3, 11.2, "#f4a261", "traders"),  # Africa: Muslim port of Zeila
            ("Mogadishu", 45.2, 2.1, "#3a86ff", "traders"),  # Africa: Benadir port city
            ("Mombasa", 39.6, -4.0, "#e76f51", "traders"),  # Africa: Swahili town of Mombasa, described by al-Idrisi (1154)
            ("Kilwa", 39.45, -8.95, "#b5179e", "traders"),  # Africa: Kilwa Sultanate, controlling the Sofala gold trade
            ("Mahilaka", 48.1, -13.7, "#90be6d", "traders"),  # Africa: walled Islamic trading town of northwest Madagascar
            ("Vazimba", 47.3, -19.3, "#577590", None),  # Africa: early highland inhabitants of Madagascar
            ("Talaky", 45.3, -25.0, "#f9844a", None),  # Africa: Talaky-phase villages of southern Madagascar
            ("Sofala", 34.75, -20.15, "#ffb4a2", "traders"),  # Africa: Sofala, gold port of the Zambezi-Limpopo hinterland
            ("K2 (Bambandyanalo)", 29.4, -22.2, "#6d597a", "traders"),  # Africa: K2 capital in the Limpopo valley, before Mapungubwe (c. 1220)
            ("San", 21.5, -23.5, "#c8ad7f", None),  # Africa: San hunter-gatherers of the Kalahari
            ("Khoikhoi", 19.5, -33.0, "#8d6e63", None),  # Africa: Khoikhoi herders of the Cape
            ("Blackburn culture", 30.5, -28.5, "#264653", None),  # Africa: Nguni ancestors of KwaZulu-Natal
            ("Kalomo", 26.5, -17.0, "#43aa8b", None),  # Africa: Kalomo culture of southern Zambia
            ("Kisalian (Upemba)", 26.6, -8.5, "#3d405b", None),  # Africa: Kisalian culture of the Upemba Depression
            ("Ntusi", 31.4, 0.0, "#f28482", None),  # Africa: Ntusi of western Uganda
            ("Mongo", 20.0, -1.0, "#2d6a4f", None),  # Africa: Bantu farmers and forest foragers of the Congo basin
            ("Culhuacan", -99.11, 19.33, "#4682b4", None),  # North America: Culhua heirs of the Toltecs in the Valley of Mexico after Tula's fall (c. 1150)
            ("Zapotecs", -96.4, 16.95, "#ff8c00", None),  # North America: Zapotec lordships of Mitla and Zaachila
            ("Aztatlán", -105.0, 21.8, "#cd5c5c", "traders"),  # North America: Aztatlán trading towns of the Nayarit-Sinaloa coast
            ("Maya Cities", -89.6, 20.7, "#008b8b", None),  # North America: Yucatec Maya cities between Chichén Itzá's decline and Mayapán
            ("Lenca", -87.8, 14.3, "#6b8e23", None),  # North America: Lenca chiefdoms of Honduras
            ("Nicoya", -85.4, 10.3, "#9370db", None),  # North America: Greater Nicoya (Chorotega) chiefdoms
            ("Coclé", -80.4, 8.5, "#f0c419", None),  # North America: Gran Coclé chiefdoms of Panama
            ("Taíno", -70.7, 19.0, "#ff6347", None),  # North America: Taíno chiefdoms of Hispaniola, ball courts and cacicazgos
            ("Guanahatabey", -83.6, 22.5, "#708090", None),  # North America: archaic foragers of western Cuba
            ("Igneri", -61.5, 16.2, "#9acd32", None),  # North America: Arawak-speaking Lesser Antilles islanders
            ("Ancestral Puebloans", -108.5, 37.2, "#e9d8a6", "builders"),  # North America: Mesa Verde cliff-dwelling communities, c. 1150-1280
            ("Hohokam", -111.9, 33.4, "#cd853f", "builders"),  # North America: Classic Hohokam platform-mound towns
            ("Mogollon", -108.0, 32.8, "#6b4226", None),  # North America: post-Mimbres Mogollon villages
            ("Fremont", -111.8, 39.2, "#8fbc8f", None),  # North America: Fremont culture of Utah
            ("Chumash", -119.7, 34.5, "#1e90ff", "traders"),  # North America: Chumash of the Santa Barbara Channel
            ("Coast Salish", -122.5, 49.2, "#2e8b57", None),  # North America: Coast Salish of the Fraser delta and Puget Sound
            ("Haida", -132.1, 53.3, "#dc143c", None),  # North America: Haida of Haida Gwaii
            ("Central Plains Tradition", -98.5, 40.0, "#c5b358", None),  # North America: Central Plains tradition earthlodge villages
            ("Middle Missouri", -100.8, 46.8, "#a0522d", None),  # North America: Middle Missouri villages of the Dakotas
            ("Etowah", -84.8, 34.1, "#b03060", None),  # North America: Mississippian mound centre in Georgia
            ("Spiro", -94.6, 35.3, "#ff4500", "traders"),  # North America: Caddoan Mississippian centre at Spiro
            ("Coles Creek", -91.4, 31.6, "#6495ed", None),  # North America: late Coles Creek mound culture, turning Plaquemine c. 1200
            ("Fort Ancient", -83.5, 39.0, "#e9967a", None),  # North America: Fort Ancient villages of the Ohio valley
            ("Oneota", -91.2, 43.5, "#228b22", None),  # North America: Oneota villages of the upper Mississippi, from c. 1150
            ("Owasco", -76.5, 42.6, "#6a0dad", None),  # North America: Owasco culture (Iroquoian ancestors)
            ("Eastern Algonquians", -71.5, 42.5, "#8b8b00", None),  # North America: Eastern Algonquian peoples of New England
            ("Fort Walton", -84.3, 30.5, "#ff7f50", None),  # North America: Fort Walton Mississippian chiefdoms of the Florida panhandle
            ("Calusa", -81.86, 26.42, "#20b2aa", None),  # North America: Calusa of southwest Florida
            ("Cree", -77.5, 51.5, "#87ceeb", None),  # North America: Algonquian hunters of the James Bay forests
            ("Dene", -120.0, 62.5, "#36454f", None),  # North America: Athabaskan (Dene) peoples of the Mackenzie basin
            ("Thule", -156.6, 71.2, "#add8e6", None),  # North America: Thule whalers of north Alaska, about to spread east
            ("Dorset", -84.0, 68.5, "#b0c4de", None),  # North America: Late Dorset of the eastern Arctic
            ("Norse Greenland", -50.8, 64.2, "#c8102e", None),  # North America: Norse Western Settlement (Nuuk fjord); bishopric at Garðar in the east
            ("Aleuts", -166.5, 53.9, "#4f7942", None),  # North America: Unangan (Aleut) of the Aleutian Islands
            ("Beothuk", -56.0, 49.0, "#e2725b", None),  # North America: Beothuk ancestors of Newfoundland
            ("Killke", -71.97, -13.52, "#b22222", "mountain"),  # South America: Killke culture of the Cusco valley, before the Inca dynasty
            ("Lupaca", -69.9, -15.9, "#191970", "mountain"),  # South America: Aymara lordship of Chucuito on Lake Titicaca, after Tiwanaku
            ("Charka", -65.8, -19.5, "#a0522d", "mountain"),  # South America: Charka/Qaraqara Aymara lordships of the Potosí highlands
            ("Pachacamac", -76.85, -12.25, "#800080", "faith"),  # South America: Ychsma lordship and the oracle of Pachacamac
            ("Manteño", -80.7, -1.0, "#20b2aa", "traders"),  # South America: Manteño seafaring traders of coastal Ecuador
            ("Quitu-Cara", -78.0, 0.45, "#6b8e23", "mountain"),  # South America: Quitu and Cara chiefdoms of highland Ecuador
            ("Muisca", -73.4, 5.5, "#daa520", None),  # South America: Muisca chiefdoms of the Bogotá plateau
            ("Tairona", -73.9, 11.0, "#ffa07a", "mountain"),  # South America: Tairona towns, Ciudad Perdida
            ("Calima", -76.5, 3.9, "#cd5c5c", None),  # South America: Calima culture (Sonso period) of the Cauca valley
            ("Timoto-Cuica", -71.1, 8.6, "#5b8db8", "mountain"),  # South America: terrace farmers of the Venezuelan Andes
            ("Valencia Culture", -67.8, 10.1, "#7e57c2", None),  # South America: mound villages around Lake Valencia
            ("Lokono", -58.0, 6.3, "#006400", None),  # South America: Arawak (Lokono) peoples of the Guiana coast
            ("Aristé", -51.2, 2.5, "#ff69b4", None),  # South America: Aristé culture of Amapá
            ("Marajoara", -49.5, -0.9, "#c04000", "builders"),  # South America: late Marajoara mound chiefdoms
            ("Tapajós (Santarém)", -54.7, -2.5, "#8b4513", None),  # South America: Tapajó chiefdom at Santarém
            ("Amazon Polychrome (Guarita)", -60.0, -3.2, "#e9967a", None),  # South America: Guarita-phase towns of the central Amazon
            ("Casarabe", -64.9, -14.7, "#3cb371", "builders"),  # South America: Casarabe causeway towns of the Llanos de Mojos
            ("Cumancaya", -74.4, -8.4, "#4169e1", None),  # South America: Cumancaya culture of the Ucayali
            ("Atacameño", -68.2, -22.9, "#8b5a7a", "traders"),  # South America: San Pedro de Atacama oasis people
            ("Santa María", -66.05, -26.7, "#708090", None),  # South America: Santa María culture of the Calchaquí valleys
            ("Diaguita", -70.6, -30.0, "#ff4500", None),  # South America: Diaguita of the Elqui and Limarí valleys
            ("Huarpe", -67.3, -32.8, "#f4a460", None),  # South America: Huarpe farmers of Cuyo
            ("Comechingón", -64.5, -31.4, "#8fbc8f", None),  # South America: Comechingón of the Córdoba hills
            ("Guaycuru", -60.5, -24.5, "#cd853f", None),  # South America: Guaycuruan foragers of the Gran Chaco
            ("Querandí", -58.7, -35.0, "#bdb76b", None),  # South America: Querandí hunters of the Pampas
            ("Charrúa", -56.0, -32.5, "#87ceeb", None),  # South America: Charrúa of Uruguay
            ("Mapuche", -72.6, -38.7, "#0033a0", None),  # South America: Mapuche (El Vergel culture) of Araucanía
            ("Tehuelche", -69.0, -45.5, "#a9a9a9", None),  # South America: Tehuelche guanaco hunters of Patagonia
            ("Chonos", -73.0, -45.5, "#2f4f4f", None),  # South America: Chonos canoe people of Aysén
            ("Selk'nam", -68.6, -54.0, "#c0c0c0", None),  # South America: Selk'nam of Tierra del Fuego
            ("Guarani", -56.5, -25.5, "#228b22", None),  # South America: Guarani farming villages of the Paraná basin
            ("Taquara", -51.5, -28.8, "#6a5acd", None),  # South America: Taquara/Itararé pit-house villages
            ("Tupinambá", -43.3, -22.6, "#ff6347", None),  # South America: Tupinambá villages of the southeast Brazilian coast
            ("Akwẽ", -48.0, -15.0, "#9b870c", None),  # South America: Jê-speaking peoples of the cerrado
            ("Xinguano", -53.2, -12.2, "#ff7f50", None),  # South America: Upper Xingu villages (Kuikuro ancestors)
            # (2026-11-08: real realms for the grey land, tools/maps/coverage.py's holes)
            ("Guanches", -16.5, 28.3, "#d4a373", "mountain"),  # africa: d4a373", "mountain"),  # Wikipedia: Guanches (Canary Islands natives, here long before 1402)
            ("Ghadames", 9.5, 30.13, "#e0c068", "traders"),  # africa: e0c068", "traders"),  # Wikipedia: Ghadames (Berber oasis city on the trans-Saharan route)
            ("Masufa", -5.0, 23.6, "#b08d57", "traders"),  # africa: b08d57", "traders"),  # Wikipedia: Masufa (Sanhaja Berber tribe of the western Sahara, Taghaza salt road)
            ("Mbuti", 28.5, 1.5, "#4e7d3a", None),  # africa: 4e7d3a", None),  # Wikipedia: Mbuti people (forest foragers of the Ituri)
            ("Aka", 17.8, 3.6, "#6a994e", None),  # africa: 6a994e", None),  # Wikipedia: Aka people (Mbenga foragers of the Lobaye/Sangha forest)
            ("Baka", 14.5, 3.0, "#386641", None),  # africa: 386641", None),  # Wikipedia: Baka people (Cameroon and Gabon) (forest foragers of southeast Cameroon)
            ("Bongo", 11.5, -1.5, "#2a9d8f", None),  # africa: 2a9d8f", None),  # Wikipedia: Bongo people (Gabon) (forest foragers of Gabon)
            ("Kwadi", 13.0, -15.0, "#bc6c25", None),  # africa: bc6c25", None),  # Wikipedia: Kwadi people (Khoe-Kwadi foragers and herders of southwest Angola)
            ("!Kung", 19.0, -18.0, "#dda15e", None),  # africa: dda15e", None),  # Wikipedia: !Kung people (Ju-speaking San of northern Namibia and southeast Angola)
            ("Nama", 17.5, -26.5, "#a0785a", None),  # africa: a0785a", None),  # Wikipedia: Nama people (Khoekhoe herders of southern Namibia)
            ("Damara", 15.5, -21.5, "#7f5539", None),  # africa: 7f5539", None),  # Wikipedia: Damara people (ancient inhabitants of central and northwest Namibia)
            ("Mahra", 51.8, 15.9, "#9c6644", None),  # africa: 9c6644", None),  # Wikipedia: Mahra tribe (South Arabian people of al-Mahrah, eastern Yemen)
            ("Tayy", 41.7, 27.5, "#c9b458", "steppe"),  # africa: c9b458", "steppe"),  # Wikipedia: Tayy (Arab tribe of Jabal Aja and Salma, Ha'il)
            ("Guddala", -16.0, 21.5, "#6c757d", None),  # africa: 6c757d", None),  # Wikipedia: Guddala (Sanhaja tribe of the Atlantic Sahara, Yahya ibn Ibrahim's people)
            ("Banu Kanz", 32.9, 24.1, "#c08552", None),  # africa: c08552", None),  # Wikipedia: Banu Kanz (Kanz al-Dawla emirs of Aswan, from 1004)
            ("Begho", -2.6, 8.2, "#e76f51", "traders"),  # africa: e76f51", "traders"),  # Wikipedia: Begho (gold-trade town of the forest edge, 11th-18th c.)
            ("Kingdom of Damot", 37.75, 6.85, "#606c38", None),  # africa: 606c38", None),  # Wikipedia: Kingdom of Damot (southern Ethiopia, 10th-13th c.)
            ("Nabhani dynasty", 57.3, 22.97, "#b5172f", None),  # africa: b5172f", None),  # Wikipedia: Nabhani dynasty (Oman, Bahla, 1154-1624)
            ("Kingdom of Ormus", 57.1, 27.1, "#118ab2", "traders"),  # africa: 118ab2", "traders"),  # Wikipedia: Kingdom of Ormus (Old Hormuz on the Minab coast)
            ("Salghurids", 52.53, 29.6, "#9e2a2b", None),  # africa: 9e2a2b", None),  # Wikipedia: Salghurids (atabegs of Fars, Shiraz, 1148-1282)
            ("Nizari Ismaili state", 50.58, 36.44, "#370617", "mountain"),  # africa: 370617", "mountain"),  # Wikipedia: Nizari Ismaili state (Alamut, 1090-1256)
            ("Uyunid dynasty", 49.6, 25.4, "#3d405b", None),  # africa: 3d405b", None),  # Wikipedia: Uyunid dynasty (al-Ahsa, 1076-1253)
            ("Sharifate of Mecca", 39.83, 21.42, "#2d6a4f", "faith"),  # africa: 2d6a4f", "faith"),  # Wikipedia: Sharifate of Mecca (from 967)
            ("Zaydi Imamate", 43.76, 16.94, "#4a4e69", "mountain"),  # africa: 4a4e69", "mountain"),  # Wikipedia: Imams of Yemen (al-Mansur Abdallah, imam from 1187, Sa'dah)
            ("Artuqids", 40.73, 37.31, "#d4a017", None),  # africa: d4a017", None),  # Wikipedia: Artuqids (Mardin and Hasankeyf, 1101-1409)
            ("Gwich'in", -141.0, 67.5, "#4a6741", None),  # americas: 4a6741', None),  # Wikipedia: Gwich'in
            ("Koyukon", -156.5, 65.6, "#7d6b91", None),  # americas: researched 2026-11-08
            ("Tlingit", -135.4, 58.8, "#b03a2e", "raiders"),  # americas: researched 2026-11-08
            ("Taltheilei", -104.0, 61.5, "#8a9a5b", None),  # americas: researched 2026-11-08
            ("Dane-zaa", -118.5, 56.2, "#996633", None),  # americas: researched 2026-11-08
            ("Karuk", -123.5, 41.4, "#5d8aa8", None),  # americas: researched 2026-11-08
            ("Cochimí", -112.3, 26.6, "#c2b280", None),  # americas: researched 2026-11-08
            ("Mi'kmaq", -65.3, 46.6, "#1c4f82", None),  # americas: 1c4f82', None),  # Wikipedia: Mi'kmaq
            ("Point Revenge", -60.4, 54.0, "#6e7f80", None),  # americas: researched 2026-11-08
            ("Kaska", -128.5, 59.5, "#7a5c3e", None),  # americas: researched 2026-11-08
            ("Ahtna", -145.3, 62.1, "#b87333", None),  # americas: researched 2026-11-08
            ("Juntunen", -85.0, 46.6, "#5f7f5f", None),  # americas: researched 2026-11-08
            ("Kawésqar", -74.3, -51.0, "#3f5f7f", None),  # americas: researched 2026-11-08
            ("Goitacá", -41.3, -21.75, "#a0522d", None),  # americas: researched 2026-11-08
            ("Timbira", -46.5, -6.5, "#b8860b", None),  # americas: researched 2026-11-08
            ("Tremembé", -39.8, -3.2, "#e07b39", None),  # americas: researched 2026-11-08
            ("Paresí", -57.5, -13.0, "#6b8e23", None),  # americas: researched 2026-11-08
            ("Bororo", -55.5, -16.5, "#c71585", None),  # americas: researched 2026-11-08
            ("Yanomami", -64.0, 2.5, "#2e8b57", None),  # americas: researched 2026-11-08
            ("Ticuna", -69.3, -3.0, "#8b0000", None),  # americas: researched 2026-11-08
            ("Chané", -62.8, -19.3, "#daa520", None),  # americas: researched 2026-11-08
            ("Apurinã", -65.2, -8.0, "#556b2f", None),  # americas: researched 2026-11-08
            ("Sapucaí", -46.8, -21.3, "#9370db", None),  # americas: researched 2026-11-08
            ("Karajá", -50.3, -9.5, "#cd5c5c", None),  # americas: researched 2026-11-08
            ("Yup'ik", -161.8, 60.8, "#8b6f47", None),  # americas: 8b6f47', None),  # Wikipedia: Yup'ik
            ("Koniag", -152.8, 57.6, "#4682b4", None),  # americas: researched 2026-11-08
            ("Selkirk", -95.0, 55.0, "#2f2f4f", None),  # americas: researched 2026-11-08
            ("Old Women's", -113.0, 50.0, "#9b7653", None),  # americas: 9b7653', None),  # Wikipedia: Old Women's phase
            ("Puelche", -64.5, -40.5, "#deb887", None),  # americas: researched 2026-11-08
            ("Potiguara", -35.4, -6.9, "#ff8c69", None),  # americas: researched 2026-11-08
            ("Aratu", -39.5, -12.5, "#b5651d", None),  # americas: researched 2026-11-08
            ("Warao", -61.6, 9.0, "#20b2aa", None),  # americas: researched 2026-11-08
            ("Kipchaks", 66.0, 50.0, "#b5a642", "steppe"),  # asia: b5a642", "steppe"),          # Wikipedia: Kipchaks
            ("Bashkirs", 56.5, 53.5, "#4f8f4f", None),  # asia: 4f8f4f", None),             # Wikipedia: Bashkirs (Sallam the Interpreter, 9th c.)
            ("Kingdom of Qocho", 89.5, 42.85, "#5f9ea0", "traders"),  # asia: 5f9ea0", "traders"),  # Wikipedia: Kingdom of Qocho (843-1335)
            ("Naimans", 90.5, 47.5, "#8fa0b8", "steppe"),  # asia: 8fa0b8", "steppe"),           # Wikipedia: Naimans
            ("Keraites", 103.0, 47.5, "#7f8fa8", "steppe"),  # asia: 7f8fa8", "steppe"),         # Wikipedia: Keraites (Christian from 1007)
            ("Merkits", 106.5, 51.0, "#6f8f7f", "steppe"),  # asia: 6f8f7f", "steppe"),          # Wikipedia: Merkit
            ("Tatars", 117.5, 48.0, "#5e8fa8", "steppe"),  # asia: 5e8fa8", "steppe"),          # Wikipedia: Tatar confederation (8th c.-1202)
            ("Oirats", 98.5, 51.5, "#9f7fbf", None),  # asia: 9f7fbf", None),                # Wikipedia: Oirats (forest people, west of Baikal)
            ("Kyrgyz Khaganate", 91.5, 53.7, "#6b8e23", "steppe"),  # asia: 6b8e23", "steppe"),  # Wikipedia: Yenisei Kyrgyz
            ("Guge", 79.8, 31.5, "#a0522d", "mountain"),  # asia: a0522d", "mountain"),            # Wikipedia: Guge
            ("Mansi", 62.5, 61.3, "#5b7c99", None),  # asia: 5b7c99", None),           # Wikipedia: Mansi people
            ("Khanty", 70.5, 60.5, "#3f6f8f", None),  # asia: 3f6f8f", None),          # Wikipedia: Khanty
            ("Selkups", 82.0, 59.3, "#6a8caf", None),  # asia: 6a8caf", None),         # Wikipedia: Selkup people
            ("Kets", 90.5, 62.5, "#4a6b5a", None),  # asia: 4a6b5a", None),            # Wikipedia: Kets
            ("Evenks", 112.0, 64.0, "#2e6f6f", None),  # asia: 2e6f6f", None),         # Wikipedia: Evenks
            ("Yukaghirs", 138.0, 67.5, "#7a8b99", None),  # asia: 7a8b99", None),      # Wikipedia: Yukaghir people
            ("Chukchi", 172.0, 67.5, "#9ab0c4", None),  # asia: 9ab0c4", None),        # Wikipedia: Chukchi people
            ("Siberian Yupiks", -170.5, 65.8, "#b0c4de", "raiders"),  # asia: b0c4de", "raiders"),  # Wikipedia: Siberian Yupik (Old Bering Sea/Punuk ancestors)
            ("Koryaks", 160.5, 62.0, "#6f7f8f", None),  # asia: 6f7f8f", None),        # Wikipedia: Koryaks
            ("Itelmens", 157.0, 53.3, "#4b7f6a", None),  # asia: 4b7f6a", None),       # Wikipedia: Itelmens
            ("Nivkh", 140.4, 52.8, "#3b5f7f", None),  # asia: 3b5f7f", None),          # Wikipedia: Nivkh people
            ("Nenets", 70.0, 68.0, "#8fa8b8", None),  # asia: 8fa8b8", None),                # Wikipedia: Nenets
            ("Nganasans", 97.0, 72.0, "#a8b8c8", None),  # asia: a8b8c8", None),             # Wikipedia: Nganasans
            ("Satsumon culture", 142.9, 42.9, "#8b6f47", None),  # asia: 8b6f47", None),     # Wikipedia: Satsumon culture (7th-13th c.)
            ("Nabhanids", 57.3, 22.97, "#c0392b", None),  # asia: c0392b", None),            # Wikipedia: Nabhani dynasty (from 1154, Bahla)
            ("Eldiguzids", 48.5, 34.8, "#4b0082", "legions"),  # asia: 4b0082", "legions"),       # Wikipedia: Eldiguzids (atabegs of Azerbaijan, Hamadan)
            ("Uyunids", 49.6, 25.4, "#9c6b30", None),  # asia: 9c6b30", None),               # Wikipedia: Uyunid Emirate (1076-1253, al-Ahsa)
            ("Chahamanas", 74.63, 26.45, "#e9967a", "legions"),  # asia: e9967a", "legions"),     # Wikipedia: Chahamanas of Shakambhari (Prithviraj III, Ajmer)
            ("Chaulukyas", 72.1, 23.85, "#d2691e", "builders"),  # asia: d2691e", "builders"),     # Wikipedia: Chaulukya dynasty (Anahilapataka)
            ("Gahadavalas", 82.97, 25.32, "#cd853f", None),  # asia: cd853f", None),         # Wikipedia: Gahadavala dynasty (Jayachandra, Varanasi)
            ("Kakatiyas", 79.58, 17.97, "#8b008b", "walls"),  # asia: 8b008b", "walls"),        # Wikipedia: Kakatiya dynasty (Warangal)
            ("Pagan", 94.9, 21.2, "#e1ad01", "builders"),  # asia: e1ad01", "builders"),           # Wikipedia: Pagan Kingdom (Sithu II)
            ("Dali", 100.2, 25.6, "#9acd32", "mountain"),  # asia: 9acd32", "mountain"),           # Wikipedia: Dali Kingdom (937-1253)
            ("Champa", 109.1, 13.9, "#cd5c5c", None),  # asia: cd5c5c", None),               # Wikipedia: Champa (Vijaya)
            ("Srivijaya", 103.6, -1.6, "#20b2aa", "traders"),  # asia: 20b2aa", "traders"),       # Wikipedia: Srivijaya
            ("Lamuri", 95.4, 5.55, "#2a9d8f", "traders"),  # asia: 2a9d8f", "traders"),          # Wikipedia: Lamuri Kingdom (Ramni, 9th c. Arab sources)
            ("Kediri", 112.0, -7.8, "#d4a373", None),  # asia: d4a373", None),               # Wikipedia: Kediri Kingdom (1042-1222)
            ("Bali", 115.3, -8.5, "#e5989b", None),  # asia: e5989b", None),                 # Wikipedia: Bali Kingdom (Warmadewa, Anak Wungsu)
            ("Po-ni", 114.9, 4.9, "#f4a261", "traders"),  # asia: f4a261", "traders"),            # Wikipedia: Po-ni
            ("Butuan", 125.54, 8.95, "#3a86ff", "traders"),  # asia: 3a86ff", "traders"),         # Wikipedia: Rajahnate of Butuan
            ("Tondo", 120.97, 14.62, "#ffbe0b", "traders"),  # asia: ffbe0b", "traders"),         # Wikipedia: Tondo (historical polity)
            ("Motu", 147.2, -9.45, "#e76f51", "traders"),  # asia: e76f51", "traders"),     # Wikipedia: Motu people
            ("Chimbu", 144.97, -6.02, "#386641", "mountain"),  # asia: 386641", "mountain"),  # Wikipedia: Chimbu people
            ("Sentani", 140.5, -2.6, "#2a9d8f", None),  # asia: 2a9d8f", None),        # Wikipedia: Sentani people
            ("Biak", 136.05, -1.05, "#264653", "raiders"),  # asia: 264653", "raiders"),    # Wikipedia: Biak people
            ("Noongar", 117.2, -33.3, "#8c4a2f", None),  # asia: 8c4a2f", None),       # Wikipedia: Noongar
            ("Martu", 121.5, -22.5, "#d2691e", None),  # asia: d2691e", None),         # Wikipedia: Martu people
            ("Warlpiri", 131.0, -20.6, "#a0522d", None),  # asia: a0522d", None),      # Wikipedia: Warlpiri
            ("Arrernte", 133.9, -23.7, "#cd853f", None),  # asia: cd853f", None),      # Wikipedia: Arrernte people
            ("Tiwi", 130.9, -11.6, "#7a5230", "raiders"),  # asia: 7a5230", "raiders"),     # Wikipedia: Tiwi people
            ("Yolngu", 136.4, -12.6, "#9b2d20", None),  # asia: 9b2d20", None),         # Wikipedia: Yolngu
            ("Kuku Yalanji", 145.2, -16.2, "#556b2f", None),  # asia: 556b2f", None),  # Wikipedia: Kuku Yalanji
            ("Wiradjuri", 147.0, -33.0, "#6b4226", None),  # asia: 6b4226", None),     # Wikipedia: Wiradjuri
            ("Dharug", 150.9, -33.8, "#a52a2a", None),  # asia: a52a2a", None),        # Wikipedia: Dharug
            ("Kulin", 145.0, -37.7, "#4f6d7a", None),  # asia: 4f6d7a", None),         # Wikipedia: Kulin
            ("Palawa", 146.8, -42.0, "#2f4f4f", None),  # asia: 2f4f4f", None),        # Wikipedia: Aboriginal Tasmanians
            ("Kanak", 165.4, -21.3, "#2d6a4f", None),  # asia: 2d6a4f", None),         # Wikipedia: Kanak people
            ("Amis", 121.4, 23.5, "#e9c46a", None),  # asia: e9c46a", None),           # Wikipedia: Amis people
            ("Andamanese", 92.75, 12.3, "#5c4033", None),  # asia: 5c4033", None),     # Wikipedia: Andamanese peoples
            ("Icelandic Commonwealth", -21.0, 64.2, "#2a5f9e", None),  # europe: 2a5f9e", None),  # Wikipedia: Icelandic Commonwealth
            ("Sámi", 20.5, 69.3, "#d9442b", None),  # europe: d9442b", None),  # Wikipedia: Sámi people (Ohthere's "Finnas", 9th c.)
            ("Bjarmians", 41.0, 64.6, "#7c5a3a", "traders"),  # europe: 7c5a3a", "traders"),  # Wikipedia: Bjarmaland
            ("Pechera", 45.5, 67.4, "#6a5a4a", None),  # europe: 6a5a4a", None),  # Wikipedia: Pechora (people)
            ("Terfinns", 33.5, 68.8, "#b85c38", None),  # europe: b85c38", None),  # Wikipedia: Ohthere of Hålogaland (Terfinnas of Kola)
            ("Kvens", 24.5, 65.8, "#5b7f3a", None),  # europe: 5b7f3a", None),  # Wikipedia: Kvenland
            ("Karelians", 31.0, 62.0, "#3f7f6f", None),  # europe: 3f7f6f", None),  # Wikipedia: Karelians
            ("Perm", 45.5, 61.6, "#8a6d3b", None),  # europe: 8a6d3b", None),  # Wikipedia: Komi peoples (chronicle "Perm" of the Vychegda)
            ("Mordvins", 44.6, 54.3, "#9f4f3f", None),  # europe: 9f4f3f", None),  # Wikipedia: Mordvins
            ("Burtas", 45.2, 52.3, "#a0703c", None),  # europe: a0703c", None),  # Wikipedia: Burtas
            ("Ryazan", 40.1, 54.4, "#7f3f5f", None),  # europe: 7f3f5f", None),  # Wikipedia: Principality of Ryazan
            ("Chernigov", 31.3, 51.5, "#4f7f2f", None),  # europe: 4f7f2f", None),  # Wikipedia: Principality of Chernigov (Sviatoslav II)
            ("Novgorod-Seversky", 33.3, 52.0, "#6f8f3f", None),  # europe: 6f8f3f", None),  # Wikipedia: Principality of Novgorod-Seversk (Igor Svyatoslavich)
            ("Alania", 44.2, 43.6, "#b08f3f", "mountain"),  # europe: b08f3f", "mountain"),  # Wikipedia: Alania
            ("Circassians", 39.2, 44.5, "#3f8f8f", "mountain"),  # europe: 3f8f8f", "mountain"),  # Wikipedia: Zygii (Zichia)
            ("Estonians", 25.5, 58.7, "#2f5f9f", None),  # europe: 2f5f9f", None),  # Wikipedia: Ancient Estonia
            ("Latgalians", 26.8, 56.5, "#9f2f4f", None),  # europe: 9f2f4f", None),  # Wikipedia: Latgalians
            ("Earldom of Orkney", -3.3, 59.1, "#5f4f8f", "raiders"),  # europe: 5f4f8f", "raiders"),  # Wikipedia: Earl of Orkney (Paul and Erlend Thorfinnsson)
            ("Faroe Islands", -6.8, 62.0, "#3f5f8f", None),  # europe: 3f5f8f", None),  # Wikipedia: History of the Faroe Islands
            ("County of Tripoli", 35.85, 34.43, "#d8d0a0", "faith"),  # europe: d8d0a0", "faith"),  # Wikipedia: County of Tripoli
            ("Principality of Antioch", 36.2, 36.2, "#b0a070", "faith"),  # europe: b0a070", "faith"),  # Wikipedia: Principality of Antioch
            ("Armenian Cilicia", 35.9, 37.4, "#e07020", "mountain"),  # europe: e07020", "mountain"),  # Wikipedia: Armenian Principality of Cilicia
            ("Cyprus", 33.4, 35.2, "#8f6fbf", None),  # europe: 8f6fbf", None),  # Wikipedia: Isaac Komnenos of Cyprus
            ("Zengids", 43.1, 36.3, "#5f2f2f", None),  # europe: 5f2f2f", None),  # Wikipedia: Zengid dynasty (Mosul)
            ("Banu Marin", -2.5, 33.6, "#8f6f2f", "steppe"),  # europe: 8f6f2f", "steppe"),  # Wikipedia: Marinid Sultanate (Zenata nomads before 1215)
            ("Judicate of Arborea", 8.6, 39.9, "#c0a030", None),  # europe: c0a030", None),  # Wikipedia: Judicate of Arborea
            ("Yotvingians", 23.3, 53.6, "#6f4f2f", None),  # europe: 6f4f2f", None),  # Wikipedia: Yotvingians
            ("Brodnici", 28.2, 46.4, "#8f8f5f", None),  # europe: 8f8f5f", None),  # Wikipedia: Brodnici
        ]),
    dict(key="1241", year=1241, name="The Mongol Invasion",
         blurb="The Great Khan's armies ride from Korea to the gates of Vienna.",
         realms=[
            ("Mongol Empire", 102.8, 47.2, "#7ec8e3", "steppe"),
            ("Golden Horde", 45.0, 48.5, "#e1b12c", "steppe"),
            ("Chagatai Khanate", 76.0, 43.0, "#5dade2", "steppe"),
            ("England", -0.1, 51.5, "#c8102e", "legions"),
            ("France", 2.3, 48.8, "#2c4f9e", "legions"),
            ("Scotland", -3.2, 56.0, "#1f4e9c", "mountain"),
            ("Norway", 10.4, 63.4, "#3a6ea5", None),
            ("Denmark", 12.6, 55.7, "#a61c3c", None),
            ("Sweden", 17.6, 59.9, "#2b5aa8", None),
            ("Holy Roman Empire", 9.0, 50.6, "#d9b41a", "legions"),
            ("Teutonic Order", 20.5, 54.7, "#2b2b2b", "faith"),
            ("Lithuania", 25.3, 54.7, "#c0b030", "masses"),
            ("Poland", 19.9, 50.1, "#dc143c", None),
            ("Hungary", 19.0, 47.5, "#7f3f98", None),
            ("Bohemia", 14.4, 50.1, "#5b6c8a", None),
            ("Venice", 12.3, 45.4, "#c69214", "traders"),
            ("Genoa", 8.9, 44.4, "#b03060", "traders"),
            ("Papal States", 12.5, 41.9, "#e8d48a", "faith"),
            ("Sicily", 13.4, 38.1, "#2a9d8f", None),
            ("Castile", -4.7, 41.6, "#b22234", "faith"),
            ("Aragon", -0.9, 41.6, "#e8b923", "traders"),
            ("Portugal", -8.6, 40.2, "#006847", None),
            ("Emirate of Granada", -3.6, 37.2, "#1d7a46", "walls"),
            ("Marinids", -5.0, 34.0, "#3b7a57", None),
            ("Hafsids", 10.2, 36.8, "#5f9e4a", None),
            ("Novgorod", 31.3, 58.5, "#4a7d4f", "traders"),
            ("Bulgaria", 25.6, 43.1, "#3c8d3c", None),
            ("Nicaea", 29.7, 40.4, "#6a1b9a", "walls"),
            ("Latin Empire", 28.98, 41.0, "#c0c0c0", None),
            ("Sultanate of Rûm", 32.5, 37.9, "#2d6e8f", None),
            ("Ayyubid Sultanate", 31.2, 30.0, "#e6b800", "faith"),
            ("Georgia", 44.8, 41.7, "#c0392b", "mountain"),
            ("Abbasid Caliphate", 44.4, 33.3, "#1b1b1b", "bureau"),
            ("Delhi Sultanate", 77.2, 28.6, "#228b22", "legions"),
            ("Southern Song", 120.2, 30.3, "#d4a017", "bureau"),
            ("Tibet", 91.1, 29.6, "#8b4513", "mountain"),
            ("Goryeo", 126.5, 37.9, "#4169e1", "walls"),
            ("Japan", 135.8, 35.0, "#bc002d", "walls"),
            ("Dai Viet", 105.8, 21.0, "#cd5c5c", None),
            ("Khmer", 103.9, 13.4, "#b8860b", "builders"),
            ("Pagan", 94.9, 21.2, "#e1ad01", None),
            ("Pandya", 78.1, 9.9, "#c71585", "traders"),
            ("Mali Empire", -8.0, 12.6, "#daa520", "traders"),
            ("Kanem", 14.0, 13.5, "#a0522d", None),
            ("Ethiopia", 39.0, 12.0, "#228b22", "mountain"),
            ("Aztec Lands", -99.1, 19.4, "#008b8b", None),
            ("Cahokia", -90.1, 38.6, "#8b7355", None),
            ("Chimú", -79.0, -8.1, "#d2b48c", None),
            # (Europe's smaller realms, so the continent's own map has enough to fight over)
            ("Brittany", -2.8, 48.1, "#3d3d55", None),
            ("Burgundy", 4.8, 47.3, "#8b1a4a", None),
            ("Flanders", 3.2, 51.2, "#f2c500", "traders"),
            ("Navarre", -1.6, 42.8, "#c23b22", "mountain"),
            ("Wales", -3.9, 53.0, "#2e8b3e", "mountain"),
            ("Saxony", 11.0, 51.5, "#6b7b8c", None),
            ("Bavaria", 11.6, 48.1, "#4f86c6", None),
            ("Austria", 16.4, 48.2, "#e8e0d0", None),
            ("Pomerania", 14.5, 53.4, "#4d6b8a", None),
            ("Bosnia", 18.4, 43.9, "#f2c500", "mountain"),
            ("Galicia-Volhynia", 24.0, 49.8, "#3d8b5a", None),
            ("Vladimir", 40.4, 56.1, "#2f6b3a", None),
            ("Smolensk", 32.0, 54.8, "#4a7d6a", None),
            ("Livonian Order", 24.1, 56.9, "#4d4d4d", "faith"),
            ("Epirus", 20.8, 39.6, "#9b59b6", "mountain"),
            ("Serbia", 20.5, 43.3, "#8b2b3c", None),
            # (Africa and the Americas, researched 2026-11-08: the continents' own maps get their own realms)
            ("Takrur", -14.0, 16.6, "#4b5320", None),  # Africa: Takrur on the Senegal River, soon to fall under Mali
            ("Djenné", -4.5, 13.9, "#a67b5b", "traders"),  # Africa: Djenné, Inland Niger Delta trade city, Great Mosque by tradition c. 1240
            ("Gao", 0.0, 16.3, "#8b0000", "traders"),  # Africa: Songhai kingdom of Gao
            ("Tuareg", 6.5, 21.0, "#4169e1", None),  # Africa: Tuareg Berbers of the Aïr and Hoggar
            ("Kano", 8.5, 12.0, "#3cb371", None),  # Africa: Hausa state of Kano
            ("Ife", 4.56, 7.48, "#6a5acd", None),  # Africa: classical Ile-Ife
            ("Daju", 24.3, 13.0, "#9acd32", None),  # Africa: Daju kingdom of Darfur
            ("Tubu", 18.5, 21.0, "#a52a2a", None),  # Africa: Teda/Tubu people of Tibesti
            ("Zayyanids", -1.3, 34.9, "#800020", "walls"),  # Africa: Zayyanid kingdom of Tlemcen, independent of the Almohads from 1236
            ("Almohad Caliphate", -8.0, 31.6, "#1f5f3f", "faith"),  # Africa: rump Almohad caliphate at Marrakesh until 1269 (in periods_spec for 1187)
            ("Banu Sulaym", 20.5, 32.0, "#c19a6b", "raiders"),  # Africa: Arab Banu Sulaym tribes of Cyrenaica
            ("Makuria", 30.6, 18.2, "#8fbc8f", None),  # Africa: Christian Nubian kingdom at Old Dongola
            ("Alodia", 32.6, 15.6, "#4f6d7a", None),  # Africa: Christian Nubian kingdom at Soba
            ("Beja", 36.5, 19.5, "#996633", None),  # Africa: Beja of the Red Sea Hills
            ("Sultanate of Shewa", 39.9, 9.0, "#2a9d8f", None),  # Africa: Makhzumi sultanate of Shewa, ended by Ifat 1285
            ("Zeila", 43.3, 11.2, "#f4a261", "traders"),  # Africa: Muslim port of Zeila (Adal)
            ("Mogadishu", 45.2, 2.1, "#3a86ff", "traders"),  # Africa: Sultanate of Mogadishu, a leading Benadir port by the 13th c. (Yaqut, c. 1220)
            ("Mombasa", 39.6, -4.0, "#e76f51", "traders"),  # Africa: Swahili town of Mombasa
            ("Kilwa", 39.45, -8.95, "#b5179e", "traders"),  # Africa: Kilwa Sultanate
            ("Mahilaka", 48.1, -13.7, "#90be6d", "traders"),  # Africa: walled Islamic trading town of northwest Madagascar
            ("Vazimba", 47.3, -19.3, "#577590", None),  # Africa: early highland inhabitants of Madagascar
            ("Talaky", 45.3, -25.0, "#f9844a", None),  # Africa: Talaky-phase villages of southern Madagascar
            ("Sofala", 34.75, -20.15, "#ffb4a2", "traders"),  # Africa: Sofala gold port
            ("Mapungubwe", 29.4, -22.2, "#ffd700", "traders"),  # Africa: Kingdom of Mapungubwe, c. 1220-1290
            ("San", 21.5, -23.5, "#c8ad7f", None),  # Africa: San hunter-gatherers of the Kalahari
            ("Khoikhoi", 19.5, -33.0, "#8d6e63", None),  # Africa: Khoikhoi herders of the Cape
            ("Nguni", 30.5, -28.5, "#264653", None),  # Africa: Nguni ancestors of KwaZulu-Natal
            ("Kalomo", 26.5, -17.0, "#43aa8b", None),  # Africa: Kalomo culture of southern Zambia
            ("Kisalian (Upemba)", 26.6, -8.5, "#3d405b", None),  # Africa: Kisalian culture of the Upemba Depression
            ("Ntusi", 31.4, 0.0, "#f28482", None),  # Africa: Ntusi of western Uganda
            ("Sirikwa", 35.3, 0.5, "#84a59d", None),  # Africa: Sirikwa cattle-keepers of the Kenyan Rift highlands, from c. 1200
            ("Mongo", 20.0, -1.0, "#2d6a4f", None),  # Africa: Bantu farmers and forest foragers of the Congo basin
            ("Zapotecs", -96.4, 16.95, "#ff8c00", None),  # North America: Zapotec lordships of Mitla and Zaachila
            ("Aztatlán", -105.0, 21.8, "#cd5c5c", "traders"),  # North America: Aztatlán trading towns of the Nayarit-Sinaloa coast
            ("Paquimé", -107.95, 30.37, "#c04000", "builders"),  # North America: Casas Grandes (Paquimé), Medio period from c. 1200
            ("Mayapán", -89.46, 20.63, "#00a86b", "walls"),  # North America: walled Maya capital of the Yucatán League, c. 1220-1440
            ("K'iche'", -91.1, 15.0, "#800080", "mountain"),  # North America: K'iche' Maya of the Guatemalan highlands, early kingdom
            ("Lenca", -87.8, 14.3, "#6b8e23", None),  # North America: Lenca chiefdoms of Honduras
            ("Nicoya", -85.4, 10.3, "#9370db", None),  # North America: Greater Nicoya (Chorotega) chiefdoms
            ("Coclé", -80.4, 8.5, "#f0c419", None),  # North America: Gran Coclé chiefdoms of Panama
            ("Taíno", -70.7, 19.0, "#ff6347", None),  # North America: Classic Taíno chiefdoms of Hispaniola
            ("Igneri", -61.5, 16.2, "#9acd32", None),  # North America: Igneri (Troumassoid) islanders of the Lesser Antilles; Kalinago (Cayo) only from c. 1250
            ("Ancestral Puebloans", -108.5, 37.2, "#e9d8a6", "builders"),  # North America: Mesa Verde cliff palaces at their height
            ("Hohokam", -111.9, 33.4, "#cd853f", "builders"),  # North America: Classic Hohokam platform-mound towns
            ("Fremont", -111.8, 39.2, "#8fbc8f", None),  # North America: late Fremont culture of Utah
            ("Chumash", -119.7, 34.5, "#1e90ff", "traders"),  # North America: Chumash of the Santa Barbara Channel
            ("Coast Salish", -122.5, 49.2, "#2e8b57", None),  # North America: Coast Salish of the Fraser delta and Puget Sound
            ("Haida", -132.1, 53.3, "#dc143c", None),  # North America: Haida of Haida Gwaii
            ("Central Plains Tradition", -98.5, 40.0, "#c5b358", None),  # North America: Central Plains tradition earthlodge villages
            ("Middle Missouri", -100.8, 46.8, "#a0522d", None),  # North America: Middle Missouri villages of the Dakotas
            ("Moundville", -87.6, 33.0, "#b03060", "builders"),  # North America: Moundville, Mississippian capital in Alabama, c. 1120-1450
            ("Spiro", -94.6, 35.3, "#ff4500", "traders"),  # North America: Caddoan Mississippian centre at Spiro
            ("Plaquemine", -91.4, 31.6, "#6495ed", None),  # North America: Plaquemine mound culture (Natchez ancestors), from c. 1200
            ("Fort Ancient", -83.5, 39.0, "#e9967a", None),  # North America: Fort Ancient villages of the Ohio valley
            ("Oneota", -91.2, 43.5, "#228b22", None),  # North America: Oneota villages of the upper Mississippi
            ("Owasco", -76.5, 42.6, "#6a0dad", None),  # North America: late Owasco (Iroquoian ancestors)
            ("Pee Dee", -79.9, 35.2, "#c71585", None),  # North America: Pee Dee Mississippian chiefdom at Town Creek, North Carolina
            ("Eastern Algonquians", -71.5, 42.5, "#8b8b00", None),  # North America: Eastern Algonquian peoples of New England
            ("Fort Walton", -84.3, 30.5, "#ff7f50", None),  # North America: Fort Walton chiefdoms, Lake Jackson mounds
            ("Calusa", -81.86, 26.42, "#20b2aa", None),  # North America: Calusa of southwest Florida
            ("Cree", -77.5, 51.5, "#87ceeb", None),  # North America: Algonquian hunters of the James Bay forests
            ("Dene", -120.0, 62.5, "#36454f", None),  # North America: Athabaskan (Dene) peoples of the Mackenzie basin
            ("Thule", -156.6, 71.2, "#add8e6", None),  # North America: Thule (Inuit ancestors), spreading east across the Arctic
            ("Dorset", -84.0, 68.5, "#b0c4de", None),  # North America: last Dorset of the eastern Arctic
            ("Norse Greenland", -50.8, 64.2, "#c8102e", None),  # North America: Norse Western Settlement (Nuuk fjord), under Norway from 1261
            ("Aleuts", -166.5, 53.9, "#4f7942", None),  # North America: Unangan (Aleut) of the Aleutian Islands
            ("Beothuk", -56.0, 49.0, "#e2725b", None),  # North America: Beothuk of Newfoundland
            ("Kingdom of Cusco", -71.97, -13.52, "#e4002b", "mountain"),  # South America: early Inca kingdom of Cusco, dynasty from c. 1200
            ("Lupaca", -69.9, -15.9, "#191970", "mountain"),  # South America: Aymara lordship of Chucuito on Lake Titicaca
            ("Charka", -65.8, -19.5, "#a0522d", "mountain"),  # South America: Charka/Qaraqara Aymara lordships
            ("Pachacamac", -76.85, -12.25, "#800080", "faith"),  # South America: Ychsma lordship and the oracle of Pachacamac
            ("Manteño", -80.7, -1.0, "#20b2aa", "traders"),  # South America: Manteño seafaring traders of coastal Ecuador
            ("Quitu-Cara", -78.0, 0.45, "#6b8e23", "mountain"),  # South America: Quitu and Cara chiefdoms of highland Ecuador
            ("Muisca", -73.4, 5.5, "#daa520", None),  # South America: Muisca confederation of the Bogotá plateau
            ("Tairona", -73.9, 11.0, "#ffa07a", "mountain"),  # South America: Tairona towns, Ciudad Perdida
            ("Calima", -76.5, 3.9, "#cd5c5c", None),  # South America: Calima culture (Sonso period) of the Cauca valley
            ("Timoto-Cuica", -71.1, 8.6, "#5b8db8", "mountain"),  # South America: terrace farmers of the Venezuelan Andes
            ("Valencia Culture", -67.8, 10.1, "#7e57c2", None),  # South America: mound villages around Lake Valencia
            ("Lokono", -58.0, 6.3, "#006400", None),  # South America: Arawak (Lokono) peoples of the Guiana coast
            ("Aristé", -51.2, 2.5, "#ff69b4", None),  # South America: Aristé culture of Amapá
            ("Marajoara", -49.5, -0.9, "#c04000", "builders"),  # South America: late Marajoara mound chiefdoms (to c. 1300)
            ("Tapajós (Santarém)", -54.7, -2.5, "#8b4513", None),  # South America: Tapajó chiefdom at Santarém
            ("Amazon Polychrome (Guarita)", -60.0, -3.2, "#e9967a", None),  # South America: Guarita-phase towns of the central Amazon
            ("Casarabe", -64.9, -14.7, "#3cb371", "builders"),  # South America: Casarabe causeway towns of the Llanos de Mojos
            ("Cumancaya", -74.4, -8.4, "#4169e1", None),  # South America: Ucayali river peoples (Panoan, Shipibo ancestors)
            ("Atacameño", -68.2, -22.9, "#8b5a7a", "traders"),  # South America: San Pedro de Atacama oasis people
            ("Santa María", -66.05, -26.7, "#708090", None),  # South America: Santa María culture of the Calchaquí valleys
            ("Diaguita", -70.6, -30.0, "#ff4500", None),  # South America: Diaguita of the Elqui and Limarí valleys
            ("Huarpe", -67.3, -32.8, "#f4a460", None),  # South America: Huarpe farmers of Cuyo
            ("Comechingón", -64.5, -31.4, "#8fbc8f", None),  # South America: Comechingón of the Córdoba hills
            ("Guaycuru", -60.5, -24.5, "#cd853f", None),  # South America: Guaycuruan foragers of the Gran Chaco
            ("Querandí", -58.7, -35.0, "#bdb76b", None),  # South America: Querandí hunters of the Pampas
            ("Charrúa", -56.0, -32.5, "#87ceeb", None),  # South America: Charrúa of Uruguay
            ("Mapuche", -72.6, -38.7, "#0033a0", None),  # South America: Mapuche (El Vergel culture) of Araucanía
            ("Tehuelche", -69.0, -45.5, "#a9a9a9", None),  # South America: Tehuelche guanaco hunters of Patagonia
            ("Chonos", -73.0, -45.5, "#2f4f4f", None),  # South America: Chonos canoe people of Aysén
            ("Selk'nam", -68.6, -54.0, "#c0c0c0", None),  # South America: Selk'nam of Tierra del Fuego
            ("Guarani", -56.5, -25.5, "#228b22", None),  # South America: Guarani farming villages of the Paraná basin
            ("Taquara", -51.5, -28.8, "#6a5acd", None),  # South America: Taquara/Itararé pit-house villages
            ("Tupinambá", -43.3, -22.6, "#ff6347", None),  # South America: Tupinambá villages of the southeast Brazilian coast
            ("Akwẽ", -48.0, -15.0, "#9b870c", None),  # South America: Jê-speaking peoples of the cerrado
            ("Xinguano", -53.2, -12.2, "#ff7f50", None),  # South America: Upper Xingu garden towns (Kuikuro ancestors)
            # (2026-11-08: real realms for the grey land, tools/maps/coverage.py's holes)
            ("Guanches", -16.5, 28.3, "#d4a373", "mountain"),  # africa: d4a373", "mountain"),  # Wikipedia: Guanches (Canary Islands natives, here long before 1402)
            ("Ghadames", 9.5, 30.13, "#e0c068", "traders"),  # africa: e0c068", "traders"),  # Wikipedia: Ghadames (Berber oasis city on the trans-Saharan route)
            ("Masufa", -5.0, 23.6, "#b08d57", "traders"),  # africa: b08d57", "traders"),  # Wikipedia: Masufa (Sanhaja Berber tribe of the western Sahara, Taghaza salt road)
            ("Mbuti", 28.5, 1.5, "#4e7d3a", None),  # africa: 4e7d3a", None),  # Wikipedia: Mbuti people (forest foragers of the Ituri)
            ("Aka", 17.8, 3.6, "#6a994e", None),  # africa: 6a994e", None),  # Wikipedia: Aka people (Mbenga foragers of the Lobaye/Sangha forest)
            ("Baka", 14.5, 3.0, "#386641", None),  # africa: 386641", None),  # Wikipedia: Baka people (Cameroon and Gabon) (forest foragers of southeast Cameroon)
            ("Bongo", 11.5, -1.5, "#2a9d8f", None),  # africa: 2a9d8f", None),  # Wikipedia: Bongo people (Gabon) (forest foragers of Gabon)
            ("Kwadi", 13.0, -15.0, "#bc6c25", None),  # africa: bc6c25", None),  # Wikipedia: Kwadi people (Khoe-Kwadi foragers and herders of southwest Angola)
            ("!Kung", 19.0, -18.0, "#dda15e", None),  # africa: dda15e", None),  # Wikipedia: !Kung people (Ju-speaking San of northern Namibia and southeast Angola)
            ("Nama", 17.5, -26.5, "#a0785a", None),  # africa: a0785a", None),  # Wikipedia: Nama people (Khoekhoe herders of southern Namibia)
            ("Damara", 15.5, -21.5, "#7f5539", None),  # africa: 7f5539", None),  # Wikipedia: Damara people (ancient inhabitants of central and northwest Namibia)
            ("Mahra", 51.8, 15.9, "#9c6644", None),  # africa: 9c6644", None),  # Wikipedia: Mahra tribe (South Arabian people of al-Mahrah, eastern Yemen)
            ("Tayy", 41.7, 27.5, "#c9b458", "steppe"),  # africa: c9b458", "steppe"),  # Wikipedia: Tayy (Arab tribe of Jabal Aja and Salma, Ha'il)
            ("Guddala", -16.0, 21.5, "#6c757d", None),  # africa: 6c757d", None),  # Wikipedia: Guddala (Sanhaja tribe of the Atlantic Sahara, Yahya ibn Ibrahim's people)
            ("Ouargla", 5.33, 31.95, "#b7b7a4", "traders"),  # africa: b7b7a4", "traders"),  # Wikipedia: Ouargla (Ibadi Berber oasis city)
            ("Banu Kanz", 32.9, 24.1, "#c08552", None),  # africa: c08552", None),  # Wikipedia: Banu Kanz (Kanz al-Dawla emirs of Aswan, from 1004)
            ("Begho", -2.6, 8.2, "#e76f51", "traders"),  # africa: e76f51", "traders"),  # Wikipedia: Begho (gold-trade town of the forest edge, 11th-18th c.)
            ("Kingdom of Damot", 37.75, 6.85, "#606c38", None),  # africa: 606c38", None),  # Wikipedia: Kingdom of Damot (southern Ethiopia, 10th-13th c.)
            ("Mpemba", 14.3, -6.0, "#457b9d", None),  # africa: 457b9d", None),  # Wikipedia: Mpemba (Kongo's predecessor confederation, from at least the 13th c.)
            ("Nabhani dynasty", 57.3, 22.97, "#b5172f", None),  # africa: b5172f", None),  # Wikipedia: Nabhani dynasty (Oman, Bahla, 1154-1624)
            ("Kingdom of Ormus", 57.1, 27.1, "#118ab2", "traders"),  # africa: 118ab2", "traders"),  # Wikipedia: Kingdom of Ormus (Old Hormuz on the Minab coast)
            ("Qutlugh-Khanids", 57.08, 30.28, "#2b9348", None),  # africa: 2b9348", None),  # Wikipedia: Qutlugh-Khanids (Kerman, 1222-1306)
            ("Salghurids", 52.53, 29.6, "#9e2a2b", None),  # africa: 9e2a2b", None),  # Wikipedia: Salghurids (atabegs of Fars, Shiraz, 1148-1282)
            ("Nizari Ismaili state", 50.58, 36.44, "#370617", "mountain"),  # africa: 370617", "mountain"),  # Wikipedia: Nizari Ismaili state (Alamut, 1090-1256)
            ("Uyunid dynasty", 49.6, 25.4, "#3d405b", None),  # africa: 3d405b", None),  # Wikipedia: Uyunid dynasty (al-Ahsa, 1076-1253)
            ("Rasulid dynasty", 44.02, 13.58, "#c1121f", "traders"),  # africa: c1121f", "traders"),  # Wikipedia: Rasulid dynasty (Yemen, Ta'izz/Zabid, 1229-1454)
            ("Sharifate of Mecca", 39.83, 21.42, "#2d6a4f", "faith"),  # africa: 2d6a4f", "faith"),  # Wikipedia: Sharifate of Mecca (from 967)
            ("Artuqids", 40.73, 37.31, "#d4a017", None),  # africa: d4a017", None),  # Wikipedia: Artuqids (Mardin and Hasankeyf, 1101-1409)
            ("Principality of Achaea", 21.35, 37.83, "#0353a4", "legions"),  # africa: 0353a4", "legions"),  # Wikipedia: Principality of Achaea (Andravida, 1205-1432)
            ("Duchy of Athens", 23.73, 37.97, "#f4a261", None),  # africa: f4a261", None),  # Wikipedia: Duchy of Athens (1205-1458)
            ("Gwich'in", -141.0, 67.5, "#4a6741", None),  # americas: 4a6741', None),  # Wikipedia: Gwich'in
            ("Koyukon", -156.5, 65.6, "#7d6b91", None),  # americas: researched 2026-11-08
            ("Tlingit", -135.4, 58.8, "#b03a2e", "raiders"),  # americas: researched 2026-11-08
            ("Taltheilei", -104.0, 61.5, "#8a9a5b", None),  # americas: researched 2026-11-08
            ("Dane-zaa", -118.5, 56.2, "#996633", None),  # americas: researched 2026-11-08
            ("Karuk", -123.5, 41.4, "#5d8aa8", None),  # americas: researched 2026-11-08
            ("Cochimí", -112.3, 26.6, "#c2b280", None),  # americas: researched 2026-11-08
            ("Mi'kmaq", -65.3, 46.6, "#1c4f82", None),  # americas: 1c4f82', None),  # Wikipedia: Mi'kmaq
            ("Point Revenge", -60.4, 54.0, "#6e7f80", None),  # americas: researched 2026-11-08
            ("Kaska", -128.5, 59.5, "#7a5c3e", None),  # americas: researched 2026-11-08
            ("Ahtna", -145.3, 62.1, "#b87333", None),  # americas: researched 2026-11-08
            ("Juntunen", -85.0, 46.6, "#5f7f5f", None),  # americas: researched 2026-11-08
            ("Kawésqar", -74.3, -51.0, "#3f5f7f", None),  # americas: researched 2026-11-08
            ("Goitacá", -41.3, -21.75, "#a0522d", None),  # americas: researched 2026-11-08
            ("Timbira", -46.5, -6.5, "#b8860b", None),  # americas: researched 2026-11-08
            ("Tremembé", -39.8, -3.2, "#e07b39", None),  # americas: researched 2026-11-08
            ("Paresí", -57.5, -13.0, "#6b8e23", None),  # americas: researched 2026-11-08
            ("Bororo", -55.5, -16.5, "#c71585", None),  # americas: researched 2026-11-08
            ("Yanomami", -64.0, 2.5, "#2e8b57", None),  # americas: researched 2026-11-08
            ("Ticuna", -69.3, -3.0, "#8b0000", None),  # americas: researched 2026-11-08
            ("Chané", -62.8, -19.3, "#daa520", None),  # americas: researched 2026-11-08
            ("Apurinã", -65.2, -8.0, "#556b2f", None),  # americas: researched 2026-11-08
            ("Sapucaí", -46.8, -21.3, "#9370db", None),  # americas: researched 2026-11-08
            ("Karajá", -50.3, -9.5, "#cd5c5c", None),  # americas: researched 2026-11-08
            ("Yup'ik", -161.8, 60.8, "#8b6f47", None),  # americas: 8b6f47', None),  # Wikipedia: Yup'ik
            ("Koniag", -152.8, 57.6, "#4682b4", None),  # americas: researched 2026-11-08
            ("Selkirk", -95.0, 55.0, "#2f2f4f", None),  # americas: researched 2026-11-08
            ("Old Women's", -113.0, 50.0, "#9b7653", None),  # americas: 9b7653', None),  # Wikipedia: Old Women's phase
            ("Puelche", -64.5, -40.5, "#deb887", None),  # americas: researched 2026-11-08
            ("Potiguara", -35.4, -6.9, "#ff8c69", None),  # americas: researched 2026-11-08
            ("Aratu", -39.5, -12.5, "#b5651d", None),  # americas: researched 2026-11-08
            ("Warao", -61.6, 9.0, "#20b2aa", None),  # americas: researched 2026-11-08
            ("Nizari Ismailis", 50.6, 36.45, "#2f2f2f", "mountain"),  # asia: 2f2f2f", "mountain"),  # Wikipedia: Nizari Ismaili state (Alamut, 1090-1256)
            ("Kingdom of Qocho", 89.5, 42.85, "#5f9ea0", "traders"),  # asia: 5f9ea0", "traders"),  # Wikipedia: Kingdom of Qocho (843-1335)
            ("Oirats", 98.5, 51.5, "#9f7fbf", None),  # asia: 9f7fbf", None),                # Wikipedia: Oirats (forest people, west of Baikal)
            ("Guge", 79.8, 31.5, "#a0522d", "mountain"),  # asia: a0522d", "mountain"),            # Wikipedia: Guge
            ("Mansi", 62.5, 61.3, "#5b7c99", None),  # asia: 5b7c99", None),           # Wikipedia: Mansi people
            ("Khanty", 70.5, 60.5, "#3f6f8f", None),  # asia: 3f6f8f", None),          # Wikipedia: Khanty
            ("Selkups", 82.0, 59.3, "#6a8caf", None),  # asia: 6a8caf", None),         # Wikipedia: Selkup people
            ("Kets", 90.5, 62.5, "#4a6b5a", None),  # asia: 4a6b5a", None),            # Wikipedia: Kets
            ("Evenks", 112.0, 64.0, "#2e6f6f", None),  # asia: 2e6f6f", None),         # Wikipedia: Evenks
            ("Yukaghirs", 138.0, 67.5, "#7a8b99", None),  # asia: 7a8b99", None),      # Wikipedia: Yukaghir people
            ("Chukchi", 172.0, 67.5, "#9ab0c4", None),  # asia: 9ab0c4", None),        # Wikipedia: Chukchi people
            ("Siberian Yupiks", -170.5, 65.8, "#b0c4de", "raiders"),  # asia: b0c4de", "raiders"),  # Wikipedia: Siberian Yupik (Old Bering Sea/Punuk ancestors)
            ("Koryaks", 160.5, 62.0, "#6f7f8f", None),  # asia: 6f7f8f", None),        # Wikipedia: Koryaks
            ("Itelmens", 157.0, 53.3, "#4b7f6a", None),  # asia: 4b7f6a", None),       # Wikipedia: Itelmens
            ("Nivkh", 140.4, 52.8, "#3b5f7f", None),  # asia: 3b5f7f", None),          # Wikipedia: Nivkh people
            ("Nenets", 70.0, 68.0, "#8fa8b8", None),  # asia: 8fa8b8", None),                # Wikipedia: Nenets
            ("Nganasans", 97.0, 72.0, "#a8b8c8", None),  # asia: a8b8c8", None),             # Wikipedia: Nganasans
            ("Yakuts", 129.7, 62.0, "#5a7d9a", None),  # asia: 5a7d9a", None),               # Wikipedia: Yakuts (to the middle Lena from the 13th c.)
            ("Ainu", 142.9, 42.9, "#8b6f47", None),  # asia: 8b6f47", None),                 # Wikipedia: Ainu people (Ainu culture from 13th c.)
            ("Nabhanids", 57.3, 22.97, "#c0392b", None),  # asia: c0392b", None),            # Wikipedia: Nabhani dynasty (from 1154, Bahla)
            ("Uyunids", 49.6, 25.4, "#9c6b30", None),  # asia: 9c6b30", None),               # Wikipedia: Uyunid Emirate (1076-1253, al-Ahsa)
            ("Chaulukyas", 72.1, 23.85, "#d2691e", "builders"),  # asia: d2691e", "builders"),     # Wikipedia: Chaulukya dynasty (Anahilapataka)
            ("Kakatiyas", 79.58, 17.97, "#8b008b", "walls"),  # asia: 8b008b", "walls"),        # Wikipedia: Kakatiya dynasty (Warangal)
            ("Eastern Gangas", 85.88, 20.46, "#ff7f50", "builders"),  # asia: ff7f50", "builders"),  # Wikipedia: Eastern Ganga dynasty (Vajrahasta V, Kalinganagara)
            ("Dali", 100.2, 25.6, "#9acd32", "mountain"),  # asia: 9acd32", "mountain"),           # Wikipedia: Dali Kingdom (937-1253)
            ("Sukhothai", 99.7, 17.0, "#ff6f61", None),  # asia: ff6f61", None),             # Wikipedia: Sukhothai Kingdom (founded 1238)
            ("Champa", 109.1, 13.9, "#cd5c5c", None),  # asia: cd5c5c", None),               # Wikipedia: Champa (Vijaya)
            ("Dharmasraya", 101.6, -1.1, "#20b2aa", "traders"),  # asia: 20b2aa", "traders"),     # Wikipedia: Dharmasraya (successor of Srivijaya)
            ("Lamuri", 95.4, 5.55, "#2a9d8f", "traders"),  # asia: 2a9d8f", "traders"),          # Wikipedia: Lamuri Kingdom (Ramni, 9th c. Arab sources)
            ("Singhasari", 112.65, -7.9, "#d4a373", None),  # asia: d4a373", None),          # Wikipedia: Singhasari (1222-1292)
            ("Bali", 115.3, -8.5, "#e5989b", None),  # asia: e5989b", None),                 # Wikipedia: Bali Kingdom (Warmadewa, Anak Wungsu)
            ("Po-ni", 114.9, 4.9, "#f4a261", "traders"),  # asia: f4a261", "traders"),            # Wikipedia: Po-ni
            ("Butuan", 125.54, 8.95, "#3a86ff", "traders"),  # asia: 3a86ff", "traders"),         # Wikipedia: Rajahnate of Butuan
            ("Tondo", 120.97, 14.62, "#ffbe0b", "traders"),  # asia: ffbe0b", "traders"),         # Wikipedia: Tondo (historical polity)
            ("Motu", 147.2, -9.45, "#e76f51", "traders"),  # asia: e76f51", "traders"),     # Wikipedia: Motu people
            ("Chimbu", 144.97, -6.02, "#386641", "mountain"),  # asia: 386641", "mountain"),  # Wikipedia: Chimbu people
            ("Sentani", 140.5, -2.6, "#2a9d8f", None),  # asia: 2a9d8f", None),        # Wikipedia: Sentani people
            ("Biak", 136.05, -1.05, "#264653", "raiders"),  # asia: 264653", "raiders"),    # Wikipedia: Biak people
            ("Noongar", 117.2, -33.3, "#8c4a2f", None),  # asia: 8c4a2f", None),       # Wikipedia: Noongar
            ("Martu", 121.5, -22.5, "#d2691e", None),  # asia: d2691e", None),         # Wikipedia: Martu people
            ("Warlpiri", 131.0, -20.6, "#a0522d", None),  # asia: a0522d", None),      # Wikipedia: Warlpiri
            ("Arrernte", 133.9, -23.7, "#cd853f", None),  # asia: cd853f", None),      # Wikipedia: Arrernte people
            ("Tiwi", 130.9, -11.6, "#7a5230", "raiders"),  # asia: 7a5230", "raiders"),     # Wikipedia: Tiwi people
            ("Yolngu", 136.4, -12.6, "#9b2d20", None),  # asia: 9b2d20", None),         # Wikipedia: Yolngu
            ("Kuku Yalanji", 145.2, -16.2, "#556b2f", None),  # asia: 556b2f", None),  # Wikipedia: Kuku Yalanji
            ("Wiradjuri", 147.0, -33.0, "#6b4226", None),  # asia: 6b4226", None),     # Wikipedia: Wiradjuri
            ("Dharug", 150.9, -33.8, "#a52a2a", None),  # asia: a52a2a", None),        # Wikipedia: Dharug
            ("Kulin", 145.0, -37.7, "#4f6d7a", None),  # asia: 4f6d7a", None),         # Wikipedia: Kulin
            ("Palawa", 146.8, -42.0, "#2f4f4f", None),  # asia: 2f4f4f", None),        # Wikipedia: Aboriginal Tasmanians
            ("Kanak", 165.4, -21.3, "#2d6a4f", None),  # asia: 2d6a4f", None),         # Wikipedia: Kanak people
            ("Amis", 121.4, 23.5, "#e9c46a", None),  # asia: e9c46a", None),           # Wikipedia: Amis people
            ("Andamanese", 92.75, 12.3, "#5c4033", None),  # asia: 5c4033", None),     # Wikipedia: Andamanese peoples
            ("Icelandic Commonwealth", -21.0, 64.2, "#2a5f9e", None),  # europe: 2a5f9e", None),  # Wikipedia: Icelandic Commonwealth
            ("Sámi", 20.5, 69.3, "#d9442b", None),  # europe: d9442b", None),  # Wikipedia: Sámi people (Ohthere's "Finnas", 9th c.)
            ("Terfinns", 33.5, 68.8, "#b85c38", None),  # europe: b85c38", None),  # Wikipedia: Ohthere of Hålogaland (Terfinnas of Kola)
            ("Pechera", 45.5, 67.4, "#6a5a4a", None),  # europe: 6a5a4a", None),  # Wikipedia: Pechora (people)
            ("Karelians", 31.0, 62.0, "#3f7f6f", None),  # europe: 3f7f6f", None),  # Wikipedia: Karelians
            ("Kvens", 24.5, 65.8, "#5b7f3a", None),  # europe: 5b7f3a", None),  # Wikipedia: Kvenland
            ("Tavastians", 24.5, 61.0, "#4a7fc1", None),  # europe: 4a7fc1", None),  # Wikipedia: Tavastians
            ("Perm", 45.5, 61.6, "#8a6d3b", None),  # europe: 8a6d3b", None),  # Wikipedia: Komi peoples (chronicle "Perm" of the Vychegda)
            ("Beloozero", 37.8, 60.0, "#5f8f4f", None),  # europe: 5f8f4f", None),  # Wikipedia: Principality of Beloozero
            ("Mordvins", 44.6, 54.3, "#9f4f3f", None),  # europe: 9f4f3f", None),  # Wikipedia: Mordvins
            ("Ryazan", 40.1, 54.4, "#7f3f5f", None),  # europe: 7f3f5f", None),  # Wikipedia: Principality of Ryazan
            ("Chernigov", 31.3, 51.5, "#4f7f2f", None),  # europe: 4f7f2f", None),  # Wikipedia: Principality of Chernigov (Sviatoslav II)
            ("Circassians", 39.2, 44.5, "#3f8f8f", "mountain"),  # europe: 3f8f8f", "mountain"),  # Wikipedia: Zygii (Zichia)
            ("Earldom of Orkney", -3.3, 59.1, "#5f4f8f", "raiders"),  # europe: 5f4f8f", "raiders"),  # Wikipedia: Earl of Orkney (Paul and Erlend Thorfinnsson)
            ("Desmond", -8.5, 51.9, "#2e8b57", None),  # europe: 2e8b57", None),  # Wikipedia: Kingdom of Desmond
            ("Toulouse", 1.4, 43.6, "#d4a017", None),  # europe: d4a017", None),  # Wikipedia: Raymond VII of Toulouse
            ("Minorca", 3.8, 40.0, "#2f7f4f", None),  # europe: 2f7f4f", None),  # Wikipedia: Sa'id ibn Hakam al-Qurashi (Islamic Menorca, Aragonese tributary 1231-1287)
            ("Kingdom of Candia", 25.1, 35.3, "#c69a30", "traders"),  # europe: c69a30", "traders"),  # Wikipedia: Kingdom of Candia (Venetian Crete)
            ("Kingdom of Cyprus", 33.4, 35.2, "#8f6fbf", None),  # europe: 8f6fbf", None),  # Wikipedia: Kingdom of Cyprus (Lusignan)
            ("County of Tripoli", 35.85, 34.43, "#d8d0a0", "faith"),  # europe: d8d0a0", "faith"),  # Wikipedia: County of Tripoli
            ("Principality of Antioch", 36.2, 36.2, "#b0a070", "faith"),  # europe: b0a070", "faith"),  # Wikipedia: Principality of Antioch
            ("Armenian Cilicia", 35.9, 37.4, "#e07020", "mountain"),  # europe: e07020", "mountain"),  # Wikipedia: Armenian Principality of Cilicia
            ("Mosul", 43.1, 36.3, "#5f2f2f", None),  # europe: 5f2f2f", None),  # Wikipedia: Badr al-Din Lu'lu'
            ("Empire of Trebizond", 39.7, 41.0, "#9b2f8f", "mountain"),  # europe: 9b2f8f", "mountain"),  # Wikipedia: Empire of Trebizond
            ("Faroe Islands", -6.8, 62.0, "#3f5f8f", None),  # europe: 3f5f8f", None),  # Wikipedia: History of the Faroe Islands
            ("Judicate of Arborea", 8.6, 39.9, "#c0a030", None),  # europe: c0a030", None),  # Wikipedia: Judicate of Arborea
            ("Yotvingians", 23.3, 53.6, "#6f4f2f", None),  # europe: 6f4f2f", None),  # Wikipedia: Yotvingians
            ("Zavolochye Chud", 41.0, 63.5, "#6f6f3f", None),  # europe: 6f6f3f", None),  # Wikipedia: Zavoloshka Chud
        ]),
]
