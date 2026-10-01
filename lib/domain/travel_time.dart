import 'dart:math' as math;

import 'models.dart';

/// Estima o tempo de deslocamento entre dois pontos.
///
/// O protótipo usa [StraightLineTravelEstimator], que é gratuito e funciona
/// offline. Para produção dá para trocar por uma implementação baseada em
/// OpenRouteService ou OSRM (rotas reais, com plano gratuito) sem mexer no
/// resto do app.
abstract interface class TravelTimeEstimator {
  Duration estimate(GeoPoint from, GeoPoint to);
}

/// Distância em linha reta × fator de correção de ruas ÷ velocidade média.
class StraightLineTravelEstimator implements TravelTimeEstimator {
  const StraightLineTravelEstimator({this.roadFactor = 1.4, this.averageSpeedKmh = 25});

  /// Ruas não são retas: ~1,4× a distância em linha reta é típico em cidade.
  final double roadFactor;

  /// Velocidade média urbana considerando trânsito.
  final double averageSpeedKmh;

  @override
  Duration estimate(GeoPoint from, GeoPoint to) {
    final km = distanceKm(from, to) * roadFactor;
    final minutes = (km / averageSpeedKmh * 60).ceil();
    return Duration(minutes: minutes);
  }

  static double distanceKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }
}
