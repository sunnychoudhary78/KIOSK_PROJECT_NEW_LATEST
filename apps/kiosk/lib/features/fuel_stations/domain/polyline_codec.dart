/// Decodes a Google encoded polyline into lat/lng pairs.
List<({double lat, double lng})> decodePolyline(String encoded) {
  if (encoded.isEmpty) {
    return const [];
  }

  final points = <({double lat, double lng})>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var result = 0;
    var shift = 0;
    int b;
    do {
      if (index >= encoded.length) {
        return points;
      }
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    result = 0;
    shift = 0;
    do {
      if (index >= encoded.length) {
        return points;
      }
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add((lat: lat / 1e5, lng: lng / 1e5));
  }

  return points;
}
