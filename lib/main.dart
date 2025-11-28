import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  Future<void> callApi() async {
    final uri = Uri.parse(
      "http://127.0.0.1:8000/search?origin=渋谷&destination=新宿&mode=high",
    );

    setState(() {
      isLoading = true;
      resultText = "";
    });

    try {
      final response = await http.get(uri);

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

          final buffer = StringBuffer();
          buffer.writeln("モード: $mode");
          buffer.writeln("経路ポイント数: $pointCount");

          if (start != null && start is List && start.length == 2) {
            buffer.writeln("出発地点: 緯度 ${start[0]}, 経度 ${start[1]}");
          }
          if (end != null && end is List && end.length == 2) {
            buffer.writeln("到着地点: 緯度 ${end[0]}, 経度 ${end[1]}");
          }

          buffer.writeln("");
          buffer.writeln("▼ 全ポイント一覧");
          for (final p in route) {
            if (p is List && p.length == 2) {
              buffer.writeln("・緯度 ${p[0]}, 経度 ${p[1]}");
            }
          }

          setState(() {
            resultText = buffer.toString();
          });
        } else {
          setState(() {
            resultText = "予期しない形式のデータが返されました:\n$body";
          });
        }
      } else {
        setState(() {
          resultText =
              "サーバーエラー: ${response.statusCode}\n${response.body}";
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
            const SizedBox(height: 20),
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