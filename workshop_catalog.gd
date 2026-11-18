extends RefCounted

const JOBS := {"tires":["Pneus",40],"oil":["Vidange",35],"inspection":["Inspection",30],
	"battery":["Batterie",45],"pressure":["Pression",25],"coolant":["Refroidissement",35],
	"brakes":["Plaquettes",48],"muffler":["Silencieux",48],"damper":["Amortisseur",46],
	"shield":["Cache moteur",28],"bearing":["Roulement",52],"puncture":["Crevaison",38],
	"lights":["Feu grillé",26],"belt":["Courroie",36],"wipers":["Essuie-glaces",22],"window":["Vitre électrique",31]}
const UNLOCKS := {"wipers":1,"lights":1,"shield":2,"brakes":2,"belt":3,"puncture":3,
	"muffler":4,"damper":4,"window":5,"bearing":6}
const VENDOR_OFFERS := [
	{"id":"lift","name":"Élévateur rapide","description":"Tous les ponts montent et descendent 60 % plus vite.","price":60,"color":"#99baba"},
	{"id":"counter","name":"Desserte double","description":"Deux surfaces de rangement livrées au bureau. Déplace-les où tu veux en atelier libre.","price":75,"color":"#d6b18a"},
	{"id":"compressor","name":"Compresseur pro","description":"Le réglage de la pression prend deux fois moins de temps avec le manomètre.","price":50,"color":"#b6a9cd"},
	{"id":"impact","name":"Clé à choc pro","description":"Divise par deux le temps de desserrage et de serrage des roues.","price":50,"color":"#c9a482"},
	{"id":"light_cart","name":"Chariot léger","description":"Déplace-toi à ta vitesse normale avec le chariot, même chargé.","price":65,"color":"#a4b9a5"},
	{"id":"lounge","name":"Salle d’attente confort","description":"Les clients perdent leur patience 25 % plus lentement.","price":80,"color":"#a3c4b9"},
	{"id":"loyalty","name":"Contrat fidélité","description":"Un client paie 8 $ de plus s’il est encaissé avant de perdre patience.","price":95,"color":"#d7be8e"},
	{"id":"reception","name":"Renfort à l’accueil","description":"Demain, accueillir un client prend deux fois moins de temps.","price":15,"color":"#d9b5a3","temporary":true},
	{"id":"advertising","name":"Publicité locale","description":"Un client supplémentaire viendra pendant le prochain service.","price":22,"color":"#e2bd87","temporary":true},
	{"id":"tuning","name":"Réglage des ponts","description":"Demain, les ponts fonctionnent 35 % plus vite, en plus de l’élévateur rapide.","price":20,"color":"#a7bebf","temporary":true},
	{"id":"diagnostic","name":"Location d’une valise pro","description":"Demain, inspecter un véhicule prend deux fois moins de temps.","price":18,"color":"#b1b6d3","temporary":true},
	{"id":"oil_recovery","name":"Bac récupérateur","description":"Après la vidange, passe directement à l’huile neuve. Le bac récupère l’huile usée.","price":135,"color":"#dbaf72","unlock_day":3},
	{"id":"service_guarantee","name":"Garantie d’accueil","description":"Protège la première demi-étoile perdue par impatience chaque jour.","price":180,"color":"#c6a7cd","unlock_day":5},
	{"id":"express_shop","name":"Atelier express","description":"Toutes les interventions sur la voiture prennent 30 % moins de temps.","price":240,"color":"#e2bc7d","unlock_day":7},
	{"id":"vending","name":"Distributrice","description":"En salle d’attente, la patience baisse 5 % moins vite. Chaque collation la fige 10 s, jusqu’à 4 fois. Toutes les factures rapportent 5 % de plus.","price":70,"color":"#92bfb0"},
	{"id":"magazines","name":"Porte-magazines","description":"Dans la salle d’attente, la patience baisse 5 % moins vite, même sans lecture.","price":35,"color":"#d3a784"},
]
const PARTS := {
	"brake_pads":["Plaquettes","#9d7281"],"new_muffler":["Silencieux neuf","#adb7b4"],
	"damper_part":["Amortisseur neuf","#c19352"],"shield_part":["Cache moteur","#637882"],
	"bearing_part":["Roulement neuf","#a5b8c5"],"patch":["Rustine","#bb765e"],
	"lamp_front":["Ampoule avant","#ffe5a4"],"lamp_rear":["Ampoule arrière","#df776b"],
	"belt_part":["Courroie neuve","#6f757e"],"wiper_pair":["Paire d’essuie-glaces","#638088"],
	"window_module":["Module de vitre","#76a592"],
}
const SHELVES := {
	"parts_chassis":["brake_pads","new_muffler","damper_part","shield_part","bearing_part","patch"],
	"parts_electric":["lamp_front","lamp_rear","belt_part","wiper_pair","window_module"],
}
const PART_JOBS := {
	"brake_pads":"brakes","new_muffler":"muffler","damper_part":"damper","shield_part":"shield",
	"bearing_part":"bearing","patch":"puncture","lamp_front":"lights","lamp_rear":"lights",
	"belt_part":"belt","wiper_pair":"wipers","window_module":"window",
}
const WINDOW_MODULE_SURCHARGE := 18
const FRONT_WHEELS := [0,2]
const HOOD_ACTIONS := ["inspection","fill_oil","remove_battery","install_battery","fill_coolant","belt_remove","belt_fit"]
const WHEEL_JOBS := ["tires","brakes","bearing","puncture"]
const WHEEL_SIDES := ["avant gauche","arrière gauche","avant droit","arrière droit"]
const PANEL_OFFSETS := {
	"muffler":Vector2(0,2.17),"shield":Vector2(0,-2.20),"belt":Vector2(0.10,-2.24),
	"wipers":Vector2(-0.55,-2.16),"window":Vector2(1.52,0.10),
}
const LIGHT_SWITCH := Vector2(-1.52,0.46)
const WIPER_SWITCH := Vector2(-1.52,-0.82)
const ENGINE_SWITCH := Vector2(-1.52,1.70)
const FRONT_LAMP := Vector2(0.88,-2.16)
const REAR_LAMP := Vector2(0.88,2.16)
