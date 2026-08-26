extends Resource
class_name NamesDB

var gs

func _init(_gs):
	gs = _gs





var male_first = [
	"Marcus", "Ethan", "Sergio", "Carl", "Morgan", "Lucius", "Jordan",
	"Zavier", "Kaden", "Liam", "Avery", "Noah", "Elijah", "Isaiah",
	"Micah", "Julian", "Adrian", "Malachi", "Xavier", "Miles",
	"Dominic", "Jalen", "Damian", "Roman", "Nolan", "Caleb",
	"Levi", "Josiah", "Nathan", "Aaron", "Cameron", "Bryson",
	"Tyrese", "Darius", "Andre", "Malik", "Jaylen", "Terrence",
	"Devin", "Tristan", "Rylan", "Kyrie", "Emmett", "Desmond",
	"Phoenix", "Asher", "Silas", "Ezra", "Theo", "Grayson",
	"Blake", "Wesley", "Donovan", "Zion", "Kareem", "Omari",
	"Joaquin", "Matteo", "Soren", "Bennett", "Cole", "Ronan"
]

var female_first = [
	"Maya", "Genevieve", "Gabby", "Molly", "Taylor", "Amber", "Victoria",
	"Brigitte", "Leah", "Sarai", "Amina", "Chloe", "Jada", "Selene",
	"Naomi", "Zaria", "Amara", "Jasmine", "Kiara", "Layla",
	"Aria", "Arielle", "Nyla", "Imani", "Talia", "Camila",
	"Elena", "Bianca", "Monroe", "Sloane", "Aubrey", "Mckenna",
	"Riley", "Jocelyn", "Avery", "Mila", "Aaliyah", "Destiny",
	"Brielle", "Teagan", "Autumn", "Kennedy", "Sabrina", "Valeria",
	"Anaya", "Zoe", "Luna", "Isla", "Kelsey", "Malia",
	"Vivian", "Daniela", "Angelina", "Skye", "Nia", "Sienna",
	"Raven", "Phoebe", "Noelle", "Maren", "Esme", "Celeste"
]

var last_names = [
	"Hill", "Baty", "Telcide", "Schade", "Ragland", "Johnson", "Francis",
	"Flores", "Rockefeller", "Brewer", "Jefferson", "Carter", "Nguyen", "Alvarez",
	"Hayes", "Brooks", "Bennett", "Parker", "Coleman", "Hughes",
	"Foster", "Reed", "Murphy", "Powell", "Bailey", "Ward",
	"Richardson", "Barnes", "Simmons", "Jenkins", "Price", "Gray",
	"Watson", "Kelly", "Sanders", "Bell", "Rivera", "Morris",
	"Cook", "Morgan", "Cooper", "Peterson", "Ross", "Henderson",
	"Long", "Diaz", "Torres", "Ramirez", "Myers", "Patel",
	"Shaw", "Woods", "West", "Pierce", "Marshall", "Dean",
	"Hunter", "Fox", "Wells", "Bishop", "Holland", "Burke"
]

func _pick(arr: Array) -> String:
	if arr.is_empty():
		return "Unknown"
	return arr [randi() % arr.size()]

func random_male():
	return _pick(male_first)

func random_female():
	return _pick(female_first)

func random_last():
	return _pick(last_names)







var ancient_male = [
	"Leonidas", "Diodoros", "Akil", "Rameses", "Sargon", "Xerxes",
	"Thales", "Pericles", "Menes", "Amun", "Cassander", "Ajax",
	"Hector", "Odysseus", "Timon", "Cyrus", "Darius", "Ptolemy",
	"Hadrian", "Augustus", "Tiberius", "Marcus", "Lucan", "Nero",
	"Seleucus", "Antiochus", "Nikandros", "Iason", "Aeson", "Theon",
	"Anaxos", "Basil", "Demetrios", "Leontes", "Pharaoh", "Khepri",
	"Seti", "Khafre", "Horemheb", "Osorkon", "Nebamun", "Zimri",
	"Belshazzar", "Ashur", "Nabonidus", "Hanno", "Mago", "Hamilcar",
	"Varro", "Cassius", "Severus", "Drakon", "Ariston", "Euphranor"
]

var ancient_female = [
	"Hypatia", "Nefertari", "Atena", "Ishtar", "Cleopatra", "Myrene",
	"Callista", "Helene", "Eirene", "Thaisa", "Lysandra", "Phoenissa",
	"Damaris", "Cassia", "Octavia", "Sabina", "Aurelia", "Cyrene",
	"Artemisia", "Berenice", "Theodosia", "Nymeria", "Semiramis", "Atossa",
	"Roxana", "Neith", "Khepra", "Merit", "Tiaa", "Henut",
	"Zenobia", "Tamar", "Salome", "Ione", "Melantha", "Elektra",
	"Antigone", "Phaedra", "Ariadne", "Sapphira", "Nerissa", "Livia",
	"Claudia", "Vibia", "Marcia", "Petra", "Iset", "Anippe",
	"Cyra", "Laleh", "Myrto", "Korinna", "Dione", "Selka"
]

var ancient_last = [
	"of Sparta", "of Athens", "of Thebes", "of Troy", "of Babylon",
	"of Memphis", "of Alexandria", "of Corinth", "of Ephesus", "of Tyre",
	"of Sidon", "of Knossos", "of Nineveh", "of Ur", "of Carthage",
	"of Delphi", "of Rhodes", "of Antioch", "of Pergamon", "of Byblos"
]


var medieval_male = [
	"Roland", "Gareth", "Ulric", "Alistair", "Hugh", "Cedric",
	"Edric", "Geoffrey", "Godric", "Oswin", "Percival", "Tristan",
	"Bertram", "Luther", "Edmund", "Rowland", "Baldric", "Leofric",
	"Aldwin", "Thorne", "Willem", "Tobin", "Matthias", "Anselm",
	"Roderic", "Stefan", "Gregor", "Bennet", "Hawkin", "Osmund",
	"Faramond", "Rainer", "Bors", "Gawain", "Lambert", "Eamon",
	"Corwin", "Darian", "Ivor", "Rufus", "Wilfred", "Armand",
	"Tomlin", "Theobald", "Ronan", "Jocelin", "Merek", "Aldous",
	"Hadrian", "Quint", "Remy", "Nicolai", "Blaise", "Tavish"
]

var medieval_female = [
	"Elowen", "Beatrice", "Rowena", "Isolde", "Margery", "Adela",
	"Matilda", "Gwen", "Anwen", "Rosamund", "Eleanor", "Aveline",
	"Ysabel", "Briony", "Maud", "Cecily", "Mirelle", "Sybella",
	"Helisende", "Alys", "Joan", "Clarice", "Odette", "Edyth",
	"Petronilla", "Agnes", "Lucienne", "Sabella", "Maris", "Thea",
	"Freya", "Elspeth", "Morgana", "Tamsin", "Arianne", "Wynne",
	"Amabel", "Corisande", "Rhiannon", "Celestine", "Eira", "Lynette",
	"Millicent", "Aubrielle", "Oriana", "Branwen", "Iseult", "Honora",
	"Seraphine", "Alienor", "Mab", "Leona", "Mirabel", "Eseld"
]

var medieval_last = [
	"Ironforge", "Stonehelm", "Blackshield", "Wolfsbane", "Goodwin",
	"Thornwall", "Ravencrest", "Ashbourne", "Hollowmere", "Brightwood",
	"Stormer", "Wintermere", "Crowley", "Duskbane", "Fairmead",
	"Grimsby", "Kestrel", "Lockwood", "Mireford", "Northcott",
	"Redwyne", "Fenwick", "Highmoor", "Wainwright", "Hawthorne",
	"Vale", "Briar", "Dunwall", "Kingsford", "Marcher", "Bramwell",
	"Frostmere", "Riverhold", "Goldmere", "Underhill", "Whitestone"
]


var industrial_male = [
	"Edwin", "Arthur", "Charles", "Henry", "Walter", "Thomas",
	"Frederick", "Samuel", "Albert", "Louis", "Frank", "George",
	"Benjamin", "Harold", "Victor", "Clarence", "Edward", "Joseph",
	"Bernard", "Oliver", "Percy", "Milton", "Stanley", "Eugene",
	"Howard", "Lester", "Irving", "Clyde", "Raymond", "Vincent",
	"Nathaniel", "Archibald", "Wilbur", "Ernest", "Otis", "Rupert",
	"Theodore", "Elias", "Silas", "Gideon", "Amos", "Jasper",
	"Cornelius", "Harlan", "Elliot", "Martin", "Isaac", "Edgar",
	"Calvin", "Philip", "Rupert", "Benedict", "Lawrence", "Russell"
]

var industrial_female = [
	"Mary", "Clara", "Evelyn", "Agnes", "Rose", "Harriet",
	"Mabel", "Florence", "Edith", "Pearl", "Josephine", "Lillian",
	"Beatrice", "Minnie", "Viola", "Louisa", "Etta", "Dorothy",
	"Nellie", "Frances", "Ada", "Martha", "Ruth", "Helen",
	"Lucille", "Irene", "Bessie", "June", "Cora", "Winifred",
	"Estelle", "Millie", "Sylvia", "Georgia", "Thelma", "Opal",
	"Geneva", "Ida", "Pauline", "Hazel", "Margaret", "Eleanor",
	"Henrietta", "Delia", "Violet", "Matilda", "Miriam", "Sadie",
	"Lenora", "Eliza", "Annie", "Caroline", "Wilma", "Maureen"
]

var industrial_last = [
	"Fairchild", "Whitlock", "Kingsley", "Hawthorne",
	"Pritchard", "Abernathy", "Morrison", "Sinclair", "Pembroke",
	"Carraway", "Wainwright", "Hargrove", "Baxter", "Thatcher",
	"Winslow", "Kensington", "Abbott", "Mercer", "Lowell", "Whitaker",
	"Vander", "Galloway", "Barlow", "Sutter", "Prescott", "Talbot",
	"Remington", "Bellamy", "Crawford", "Ainsworth", "Fletcher", "Davenport"
]


var future_male = [
	"Orion", "Kael", "Zyron", "Aero", "Nova", "Solix",
	"Cypher", "Auron", "Veyr", "Titan", "Riven", "Zarek",
	"Altair", "Jex", "Cassian", "Vector", "Dray", "Zenon",
	"Kairo", "Onyx", "Helio", "Voss", "Raiden", "Nyron",
	"Theron", "Caden-7", "Marek", "Ilios", "Talon", "Axion",
	"Sev", "Rune", "Tarek", "Lucen", "Quillon", "Vael",
	"Korin", "Soren-X", "Dax", "Aether", "Varyn", "Noctis",
	"Rhys", "Eon", "Juno", "Prysm", "Zeph", "Nex",
	"Calix", "Eris", "Torin", "Kest", "Ardin", "Vektor"
]

var future_female = [
	"Lyra", "Seraph", "Vexa", "Nyx", "Astra", "Qira",
	"Nova", "Elara", "Celes", "Vionne", "Iria", "Zyra",
	"Kaia", "Lux", "Vesper", "Solara", "Nexa", "Taryn",
	"Aeon", "Cyra", "Mira-9", "Selix", "Orla", "Rhea",
	"Azura", "Velis", "Kiora", "Sable", "Aurel", "Neve",
	"Iskra", "Noemi", "Lunara", "Vail", "Ophel", "Xanthe",
	"Aris", "Jyn", "Calypso", "Tessera", "Evania", "Halo",
	"Virel", "Ziva", "Oriana", "Myra", "Kess", "Aelin",
	"Vion", "Liora", "Ilya", "Sera", "Talyn", "Vela"
]

var future_last = [
	"Hyperion", "Starborn", "Vector-9", "Prime", "Neonblade",
	"Voidrunner", "Solaris", "Zenith", "Cryptrace", "Aetherline",
	"Null", "Skylattice", "Orbital", "Stratos", "Photon",
	"Helix", "Vantor", "Quasar", "Echo-7", "Drift",
	"Halcyon", "Nightglass", "Synthwave", "Ioncrest", "Auralight",
	"Phase", "Monolith", "Lumen", "Skyforge", "Codeborn",
	"Astrafall", "Pulse", "Silvermesh", "Redshift", "Blackstar",
	"Mechborne", "Chromaforge", "Protocol", "Vectoris", "Ultravale"
]




func random_first_for_era(gender: String, era_name: String) -> String:
	var is_male:= (gender == "Male")

	match era_name:
		"Ancient Era":
			return _pick(ancient_male if is_male else ancient_female)
		"Medieval Era":
			return _pick(medieval_male if is_male else medieval_female)
		"Industrial Era":
			return _pick(industrial_male if is_male else industrial_female)
		"Future Era":
			return _pick(future_male if is_male else future_female)
		_:
			return random_male() if is_male else random_female()




func random_last_for_era(era_name: String) -> String:
	match era_name:
		"Ancient Era":
			return _pick(ancient_last)
		"Medieval Era":
			return _pick(medieval_last)
		"Industrial Era":
			return _pick(industrial_last)
		"Future Era":
			return _pick(future_last)
		_:
			return random_last()




func _canonical_elemental_origin_country(country: String) -> String:
	var clean_country:= str(country).strip_edges()
	match clean_country:
		"Fire Nation":
			return "Fire Nation"
		"Earth Kingdom":
			return "Earth Kingdom"
		"Water Tribe", "Northern Water Tribe", "Southern Water Tribe":
			return "Water Tribe"
		"Air Nomads", "Northern Air Temple", "Southern Air Temple", "Eastern Air Temple", "Western Air Temple":
			return "Air Nomads"
		_:
			return ""
func ancient_locative_last_name(city: String, country: String = "") -> String:
	var clean_city:= str(city).strip_edges()
	if clean_city != "":
		return "of %s" % clean_city
	var elemental_country:= _canonical_elemental_origin_country(country)
	if elemental_country != "":
		return "Of The %s" % elemental_country
	return random_last_for_era("Ancient Era")

func last_name_for_birthplace(era_name: String, city: String, country: String = "") -> String:
	if era_name == "Ancient Era":
		return ancient_locative_last_name(city, country)
	return random_last_for_era(era_name)