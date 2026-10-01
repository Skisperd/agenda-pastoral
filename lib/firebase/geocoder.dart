import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// Converte endereço em coordenadas.
abstract interface class Geocoder {
  Future<GeoPoint?> find(String address);
}

/// Nominatim (OpenStreetMap): gratuito, limite de 1 consulta por segundo.
/// Só é chamado quando o membro salva o cadastro.
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<GeoPoint?> find(String address) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': address,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'br',
    });
    final response = await _client.get(uri, headers: {'Accept-Language': 'pt-BR'});
    if (response.statusCode != 200) {
      throw StateError('Serviço de mapas indisponível (${response.statusCode}). Tente de novo.');
    }
    final results = jsonDecode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    return GeoPoint(double.parse(first['lat'] as String), double.parse(first['lon'] as String));
  }
}
