/// Snake species from the Figma "Snake Guide" (based on published surveys of
/// Guwahati — Purkayastha 2018 — and the Gauhati University campus — Gogoi et
/// al. 2023). Photos are from Wikimedia Commons; see [photoCredits].
class Species {
  final String id;
  final String name;
  final String latin;
  final bool venomous;
  final String about;
  const Species(this.id, this.name, this.latin, this.venomous, this.about);

  String get photo => 'assets/snakes/$id.jpg';
}

const species = <Species>[
  // Venomous · 8
  Species(
    'cobra',
    'Monocled Cobra',
    'Naja kaouthia',
    true,
    "Identified by the round 'monocle' mark on its hood. Will raise its body and hood when it feels cornered.",
  ),
  Species(
    'king_cobra',
    'King Cobra',
    'Ophiophagus hannah',
    true,
    "The world's longest venomous snake; rare on campus but sighted near the green belt. Give it a wide berth.",
  ),
  Species(
    'banded_krait',
    'Banded Krait',
    'Bungarus fasciatus',
    true,
    'Broad black and yellow bands with a ridged back. Calm by day, active at night; its bite can be painless but is dangerous.',
  ),
  Species(
    'black_krait',
    'Greater Black Krait',
    'Bungarus niger',
    true,
    'Glossy, plain dark body with a pale belly. Active at night and easily mistaken for non-venomous snakes. Treat as dangerous.',
  ),
  Species(
    'lesser_black_krait',
    'Lesser Black Krait',
    'Bungarus lividus',
    true,
    'Slim and dark brown with a lighter belly. Nocturnal; a bite can be painless at first but is dangerous.',
  ),
  Species(
    'gumprecht',
    "Gumprecht's Green Pit Viper",
    'Trimeresurus gumprechti',
    true,
    'Bright green with a triangular head and yellow eyes, resting in bushes. Bites cause severe pain and swelling.',
  ),
  Species(
    'salazar',
    "Salazar's Pit Viper",
    'Trimeresurus salazar',
    true,
    'Green with a reddish-brown stripe along each side. Lives in shrubs and low branches; never reach into foliage.',
  ),
  Species(
    'red_necked',
    'Red-necked Keelback',
    'Rhabdophis subminiatus',
    true,
    'Olive body with a red or orange neck, found near water. Its bite can cause serious bleeding; treat as venomous.',
  ),
  // Non-venomous · 16
  Species(
    'rat',
    'Indian Rat Snake',
    'Ptyas mucosa',
    false,
    'Long and fast-moving, often mistaken for a cobra when it rears up. Non-venomous and helps control rodents.',
  ),
  Species(
    'korros',
    'Indo-Chinese Rat Snake',
    'Ptyas korros',
    false,
    'Slender, quick and olive-brown, often near water. Non-venomous; eats rodents and frogs.',
  ),
  Species(
    'wolf',
    'Common Wolf Snake',
    'Lycodon aulicus',
    false,
    'Small and banded — frequently confused with the venomous krait. Active at night around hostels.',
  ),
  Species(
    'keelback',
    'Checkered Keelback',
    'Fowlea piscator',
    false,
    'Found near drains, ponds and the lake-side path. Flattens its head when threatened but is not dangerous.',
  ),
  Species(
    'buff',
    'Buff-striped Keelback',
    'Amphiesma stolatum',
    false,
    'Small, with pale stripes along the back and dark bars on the sides. Non-venomous; hunts frogs in damp grass.',
  ),
  Species(
    'vine',
    'Green Vine Snake',
    'Ahaetulla sp.',
    false,
    'Thin, bright green, lives in hedges and low branches. Mildly rear-fanged but not medically significant to humans.',
  ),
  Species(
    'trinket_rad',
    'Copper-headed Trinket Snake',
    'Coelognathus radiatus',
    false,
    'Copper-orange head with black stripes near the neck. Fast and may flatten its neck when threatened; non-venomous.',
  ),
  Species(
    'trinket',
    'Common Trinket Snake',
    'Coelognathus helena',
    false,
    'Tan-olive with dark cross-bands near the head. Non-venomous; often found in stone piles and gardens.',
  ),
  Species(
    'bronzeback',
    'Painted Bronzeback',
    'Dendrelaphis proarchos',
    false,
    'Slender tree snake with a bronze back and a pale side stripe. Very fast; mildly venomous but harmless to people.',
  ),
  Species(
    'flying',
    'Ornate Flying Snake',
    'Chrysopelea ornata',
    false,
    'Green-yellow with black bars and orange-red spots. Glides between trees; mildly venomous but not dangerous.',
  ),
  Species(
    'kukri',
    'White-barred Kukri Snake',
    'Oligodon albocinctus',
    false,
    'Small and reddish-brown with thin pale bands, often mistaken for a krait. Non-venomous; feeds on eggs.',
  ),
  Species(
    'green_cat',
    'Green Cat Snake',
    'Boiga cyanea',
    false,
    'Bright green with a bluish throat and big eyes; active at night in trees. Mildly venomous, not dangerous to people.',
  ),
  Species(
    'mock_viper',
    'Common Mock Viper',
    'Psammodynastes pulverulentus',
    false,
    'Small brown snake with a wide, viper-like head, but not a true viper. Mildly venomous, harmless to people.',
  ),
  Species(
    'rainbow',
    'Rainbow Water Snake',
    'Enhydris enhydris',
    false,
    'Olive-brown water snake of ponds and drains. Mildly venomous, not dangerous to people.',
  ),
  Species(
    'python',
    'Burmese Python',
    'Python bivittatus',
    false,
    'Large, thick-bodied and patterned; a constrictor, not venomous. Keep back and call the guard; never handle.',
  ),
  Species(
    'blind',
    'Brahminy Blindsnake',
    'Indotyphlops braminus',
    false,
    'Tiny, shiny black worm-like snake found in soil and flowerpots. Non-venomous.',
  ),
];

Species speciesById(String id) => species.firstWhere((s) => s.id == id);

/// Non-venomous campus snakes that are often mistaken for a venomous one, with
/// the venomous look-alike and how to tell them apart. The scanner shows this
/// whenever it names the harmless one, because a photo can fool it too.
const venomousLookAlikes = <String, (String, String)>{
  'wolf': ('banded_krait', 'Kraits have a raised ridge along the back and broad, even bands; wolf snakes have a flat head and thin pale bands.'),
  'kukri': ('banded_krait', 'Kraits have a raised ridge along the back and broad, even bands; kukri snakes are small with thin pale bands.'),
  'trinket': ('banded_krait', 'Kraits have a raised ridge along the back and broad, even black-and-yellow bands.'),
  'rat': ('cobra', 'Only cobras spread a hood; rat snakes have big eyes and dark bars on the lips.'),
  'korros': ('cobra', 'Only cobras spread a hood; rat snakes have big eyes and dark bars on the lips.'),
  'keelback': ('red_necked', 'A red or orange neck means Red-necked Keelback, which is venomous.'),
  'buff': ('red_necked', 'A red or orange neck means Red-necked Keelback, which is venomous.'),
  'rainbow': ('red_necked', 'A red or orange neck means Red-necked Keelback, which is venomous.'),
  'mock_viper': ('salazar', 'True pit vipers have a heat pit between the eye and nostril and a very triangular head.'),
  'vine': ('gumprecht', 'Green pit vipers are thick-bodied with a triangular head; vine snakes are very thin with a pointed snout.'),
  'green_cat': ('gumprecht', 'Green pit vipers are thick-bodied with a triangular head and a heat pit between the eye and nostril.'),
  'bronzeback': ('lesser_black_krait', 'Kraits are glossy and dark with a raised ridge along the back; bronzebacks are slim with a pale side stripe.'),
  'blind': ('lesser_black_krait', 'Blind snakes are tiny and worm-like; even young kraits are longer with a distinct head.'),
};

const photoCredits =
    'Photos from Wikimedia Commons. Banded Krait — Lawrence Hylton, CC BY 4.0 · Greater Black Krait — lovelymon lamin, CC0 · '
    'Lesser Black Krait — Sp.herp, CC BY-SA 3.0 · Gumprecht\'s Green Pit Viper — Rushen, CC BY-SA 2.0 · Salazar\'s Pit Viper — '
    'Aamod Zambre & Chintan Seth, CC BY 4.0 · Red-necked Keelback — W.A. Djatmiko, CC BY-SA 3.0 · Indo-Chinese Rat Snake — '
    'Christoph Moning, CC BY 4.0 · Buff-striped Keelback — Dr. Raju Kasambe, CC BY-SA 4.0 · Copper-headed Trinket Snake — '
    'Rushenb, CC BY-SA 4.0 · Common Trinket Snake — Irvin calicut, CC BY-SA 3.0 · Painted Bronzeback — Santulan Mahanta, '
    'CC BY-SA 4.0 · Ornate Flying Snake — Shagil Kannur, CC BY-SA 3.0 · White-barred Kukri Snake — steve kharmawphlang, CC BY 2.0 · '
    'Green Cat Snake — Chris Oldnall, CC BY-SA 4.0 · Common Mock Viper — Caroline Jones, CC BY 2.0 · Rainbow Water Snake — '
    'Srikaanth Sekar, CC BY 2.0 · Burmese Python — Shadow Ayush, CC BY-SA 4.0 · Brahminy Blindsnake — MH Herpetology, CC BY 4.0. '
    'Monocled Cobra, King Cobra, Indian Rat Snake, Common Wolf Snake, Checkered Keelback, Green Vine Snake: Wikimedia Commons contributors.';
