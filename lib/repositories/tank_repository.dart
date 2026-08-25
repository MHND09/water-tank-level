import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_models.dart';

abstract interface class TankRepository {
  Future<PingResponse> ping();
  Future<LevelResponse> getLevel();
}

class HttpTankRepository implements TankRepository {
  HttpTankRepository(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse(baseUrl).replace(path: '${Uri.parse(baseUrl).path}$path');

  @override
  Future<PingResponse> ping() async {
    final response = await _client.get(_uri('/ping')).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw Exception('Ping failed (${response.statusCode}).');
    return PingResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<LevelResponse> getLevel() async {
    final response = await _client.get(_uri('/level')).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw Exception('Level request failed (${response.statusCode}).');
    return LevelResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class FakeTankRepository implements TankRepository {
  FakeTankRepository({this.response = const LevelResponse(distanceCm: 55, ageSeconds: 3, status: LevelStatus.ok, firmware: 'fake-1.0')});
  final LevelResponse response;
  @override
  Future<PingResponse> ping() async => const PingResponse(status: 'ok', firmware: 'fake-1.0');
  @override
  Future<LevelResponse> getLevel() async => response;
}
