import 'package:latlong2/latlong.dart';

/// Sports pitches on campus (OpenStreetMap ways). The map tiles draw these in
/// a strong teal; the app paints them over in a soft light green instead.
const pitchShapes = <List<LatLng>>[
  // Basketball pitch (way 121436121)
  [
    LatLng(26.1920618, 91.6977061),
    LatLng(26.1920623, 91.6978827),
    LatLng(26.1917652, 91.6978798),
    LatLng(26.1917680, 91.6977006),
    LatLng(26.1920618, 91.6977061),
  ],
  // Basketball pitch B (way 121436139)
  [
    LatLng(26.1920718, 91.6979318),
    LatLng(26.1920682, 91.6981085),
    LatLng(26.1917725, 91.6981075),
    LatLng(26.1917753, 91.6979282),
    LatLng(26.1920718, 91.6979318),
  ],
  // Cricket pitch (way 684576017)
  [
    LatLng(26.1913951, 91.6959848),
    LatLng(26.1914055, 91.6976118),
    LatLng(26.1910690, 91.6976060),
    LatLng(26.1910275, 91.6976752),
    LatLng(26.1900594, 91.6977214),
    LatLng(26.1900439, 91.6974733),
    LatLng(26.1898730, 91.6972483),
    LatLng(26.1897384, 91.6972310),
    LatLng(26.1896918, 91.6959559),
    LatLng(26.1913951, 91.6959848),
  ],
  // Basketball pitch (way 684576022)
  [
    LatLng(26.1880726, 91.7001388),
    LatLng(26.1877516, 91.7001388),
    LatLng(26.1877516, 91.7003638),
    LatLng(26.1880675, 91.7003407),
    LatLng(26.1880726, 91.7001388),
  ],
];
