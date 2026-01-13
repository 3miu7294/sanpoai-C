import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const SanpoApp());
}

class SanpoApp extends StatelessWidget {
  const SanpoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '散歩ルート検索（Python連携）',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SanpoHomePage(),
    );
  }
}

class SanpoHomePage extends StatefulWidget {
  const SanpoHomePage({super.key});

  @override
  State<SanpoHomePage> createState() => _SanpoHomePageState();
}

class _SanpoHomePageState extends State<SanpoHomePage> {
  String resultText = "まだ検索されていません";
  bool isLoading = false;

  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(35.681236, 139.767125),
    zoom: 13,
  );

  Future<void> callApi() async {
    final uri = Uri.http(
      "localhost:8000",
      "/search",
      {"origin": "渋谷", "destination": "新宿", "mode": "high"},
    );

    setState(() {
      isLoading = true;
      resultText = "";
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = response.body;

        dynamic jsonData;
        try {
          jsonData = jsonDecode(body);
        } catch (_) {
          setState(() {
            resultText = "JSON の解析に失敗しました。\nそのまま表示します:\n$body";
          });
          return;
        }

        if (jsonData is Map && jsonData["route"] != null) {
          final List<dynamic> route = List<dynamic>.from(jsonData["route"]);
          final String mode = jsonData["mode"]?.toString() ?? "不明";

          final int pointCount = route.length;
          final start = route.isNotEmpty ? route.first : null;
          final end = route.isNotEmpty ? route.last : null;

          final points = <LatLng>[];
          for (final p in route) {
            if (p is List && p.length == 2) {
              final lat = (p[0] as num).toDouble();
              final lng = (p[1] as num).toDouble();
              points.add(LatLng(lat, lng));
            }
          }

          final buffer = StringBuffer();
          buffer.writeln("モード: $mode");
          buffer.writeln("経路ポイント数: $pointCount");

          LatLng? startLatLng;
          LatLng? endLatLng;

          if (start != null && start is List && start.length == 2) {
            final lat = (start[0] as num).toDouble();
            final lng = (start[1] as num).toDouble();
            startLatLng = LatLng(lat, lng);
            buffer.writeln("出発地点: 緯度 ${start[0]}, 経度 ${start[1]}");
          }
          if (end != null && end is List && end.length == 2) {
            final lat = (end[0] as num).toDouble();
            final lng = (end[1] as num).toDouble();
            endLatLng = LatLng(lat, lng);
            buffer.writeln("到着地点: 緯度 ${end[0]}, 経度 ${end[1]}");
          }

          buffer.writeln("");
          buffer.writeln("▼ 全ポイント一覧");
          for (final p in route) {
            if (p is List && p.length == 2) {
              buffer.writeln("・緯度 ${p[0]}, 経度 ${p[1]}");
            }
          }

          final newPolylines = <Polyline>{
            Polyline(
              polylineId: const PolylineId("route"),
              points: points,
              width: 6,
            ),
          };

          final newMarkers = <Marker>{};
          if (startLatLng != null) {
            newMarkers.add(
              Marker(
                markerId: const MarkerId("start"),
                position: startLatLng,
                infoWindow: const InfoWindow(title: "出発地点"),
              ),
            );
          }
          if (endLatLng != null) {
            newMarkers.add(
              Marker(
                markerId: const MarkerId("destination"),
                position: endLatLng,
                infoWindow: const InfoWindow(title: "目的地"),
              ),
            );
          }

          setState(() {
            resultText = buffer.toString();
            _routePoints = points;
            _polylines = newPolylines;
            _markers = newMarkers;
            if (startLatLng != null) {
              _initialCameraPosition = CameraPosition(
                target: startLatLng,
                zoom: 14,
              );
            }
          });

          if (_mapController != null && _routePoints.isNotEmpty) {
            final bounds = _computeBounds(_routePoints);
            await _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 60),
            );
          }
        } else {
          setState(() {
            resultText = "予期しない形式のデータが返されました:\n$body";
          });
        }
      } else {
        setState(() {
          resultText = "サーバーエラー: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        resultText = "通信エラーが発生しました:\n$e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  LatLngBounds _computeBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("散歩ルート検索アプリ")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : callApi,
              child: Text(isLoading ? "通信中..." : "Python API にアクセス"),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_routePoints.isNotEmpty) {
                      final bounds = _computeBounds(_routePoints);
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 60),
                      );
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text(
              "結果",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  resultText,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


