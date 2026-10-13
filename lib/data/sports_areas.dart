import 'package:latlong2/latlong.dart';

/// Sports grounds and courts on campus (OpenStreetMap ways). The tiles fill
/// them in light green but outline them in a darker green; the app traces the
/// outline in the fill colour to hide it, leaving the tiles' own labels (such
/// as "athletics") untouched. Pitches are recoloured in the tiles themselves
/// (see PitchRecolorTileProvider). The Student Activity Center area is
/// left out because it contains the SAC building.
const sportsGroundShapes = <List<LatLng>>[
  // Tennis (way 121436087)
  [
    LatLng(26.1920696, 91.6951046),
    LatLng(26.1920679, 91.6952158),
    LatLng(26.1918503, 91.6952116),
    LatLng(26.1918520, 91.6951004),
    LatLng(26.1920696, 91.6951046),
  ],
  // Volleyball (way 121436090)
  [
    LatLng(26.1920737, 91.6972106),
    LatLng(26.1920702, 91.6973906),
    LatLng(26.1917473, 91.6973828),
    LatLng(26.1917508, 91.6972028),
    LatLng(26.1920737, 91.6972106),
  ],
  // Tennis (way 121436098)
  [
    LatLng(26.1920748, 91.6947738),
    LatLng(26.1920732, 91.6948885),
    LatLng(26.1918546, 91.6948848),
    LatLng(26.1918561, 91.6947701),
    LatLng(26.1920748, 91.6947738),
  ],
  // Tennis (way 121436099)
  [
    LatLng(26.1920761, 91.6947078),
    LatLng(26.1918569, 91.6947040),
    LatLng(26.1918585, 91.6945892),
    LatLng(26.1920777, 91.6945929),
    LatLng(26.1920761, 91.6947078),
  ],
  // Hockey (way 121436114)
  [
    LatLng(26.1923405, 91.6960281),
    LatLng(26.1923311, 91.6970528),
    LatLng(26.1917741, 91.6970464),
    LatLng(26.1917835, 91.6960218),
    LatLng(26.1923405, 91.6960281),
  ],
  // Soccer (way 121436116)
  [
    LatLng(26.1935460, 91.6963973),
    LatLng(26.1935083, 91.6971759),
    LatLng(26.1924217, 91.6971306),
    LatLng(26.1924510, 91.6963426),
    LatLng(26.1935460, 91.6963973),
  ],
  // Volleyball (way 121436147)
  [
    LatLng(26.1920709, 91.6974222),
    LatLng(26.1920677, 91.6976028),
    LatLng(26.1917483, 91.6975920),
    LatLng(26.1917491, 91.6974141),
    LatLng(26.1920709, 91.6974222),
  ],
  // Tennis (way 121436152)
  [
    LatLng(26.1920667, 91.6952817),
    LatLng(26.1920652, 91.6953920),
    LatLng(26.1918481, 91.6953883),
    LatLng(26.1918496, 91.6952781),
    LatLng(26.1920667, 91.6952817),
  ],
  // Athletics (way 144431213)
  [
    LatLng(26.1926758, 91.6974304),
    LatLng(26.1934899, 91.6975027),
    LatLng(26.1936924, 91.6976060),
    LatLng(26.1937844, 91.6980393),
    LatLng(26.1936839, 91.6983784),
    LatLng(26.1934604, 91.6985020),
    LatLng(26.1930180, 91.6984494),
    LatLng(26.1925755, 91.6983968),
    LatLng(26.1923396, 91.6982587),
    LatLng(26.1922511, 91.6979432),
    LatLng(26.1922924, 91.6976671),
    LatLng(26.1924458, 91.6975158),
    LatLng(26.1926758, 91.6974304),
  ],
];
