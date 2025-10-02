import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  String? error;
  String? accessToken;
  String? userId;
  List<dynamic> results = [];

  static const String baseUrl = "https://ai-trainee-5.onrender.com"; // Node.js server

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null) {
        setState(() {
          error = "Not authenticated. Please log in.";
          isLoading = false;
        });
        return;
      }
      final id = _extractUserIdFromJwt(token);
      if (id == null) {
        setState(() {
          error = "Invalid token. Please log in again.";
          isLoading = false;
        });
        return;
      }
      setState(() {
        accessToken = token;
        userId = id;
      });
      await _fetchResults(id, token);
    } catch (e) {
      setState(() {
        error = "Unexpected error: $e";
        isLoading = false;
      });
    }
  }

  String? _extractUserIdFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) normalized += '=';
      final decoded = utf8.decode(base64.decode(normalized));
      final map = jsonDecode(decoded);
      return map["_id"] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchResults(String id, String token) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final uri = Uri.parse("$baseUrl/api/results?userId=$id");
    try {
      final res = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final fetched = (body["results"] as List?) ?? [];
        setState(() {
          results = fetched;
          isLoading = false;
        });
      } else if (res.statusCode == 401) {
        setState(() {
          error = "Unauthorized. Please log in again.";
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Failed to load results (${res.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Network error: $e";
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> get latestResult {
    if (results.isEmpty) {
      return {
        "confidence": 0,
        "reps": 0,
        "sets": 0,
        "symmetry": "N/A",
        "correction": "N/A",
        "calories": 0,
        "duration": 0,
        "suggestion": "N/A",
        "motivation": "N/A",
        "isCorrect": false,
        "badge": "N/A",
        "cheatDetected": false,
      };
    }
    return results.first as Map<String, dynamic>;
  }

  List<FlSpot> _generatePerformanceChart(num confidence) {
    final c = confidence.toDouble();
    return [
      FlSpot(0, (c - 8).clamp(0, 100).toDouble()),
      FlSpot(1, (c - 5).clamp(0, 100).toDouble()),
      FlSpot(2, (c - 2).clamp(0, 100).toDouble()),
      FlSpot(3, (c - 1).clamp(0, 100).toDouble()),
      FlSpot(4, c.clamp(0, 100).toDouble()),
    ];
  }

  Widget _metricCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementBadge(String badge) {
    Color bgColor, borderColor, textColor;
    switch (badge.toLowerCase()) {
      case "gold":
        bgColor = const Color(0xFFFFF8E1);
        borderColor = const Color(0xFFFFD700);
        textColor = const Color(0xFFFFA000);
        break;
      case "silver":
        bgColor = const Color(0xFFEFEFEF);
        borderColor = Colors.grey;
        textColor = Colors.black87;
        break;
      default:
        bgColor = const Color(0xFFFFF7E6);
        borderColor = const Color(0xFFF39C12);
        textColor = const Color(0xFFD35400);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text(
        "🏅 $badge Badge",
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = latestResult;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        appBar: AppBar(title: const Text("Athlete Dashboard")),
        body: Center(
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: const Text("Athlete Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (userId != null && accessToken != null) {
                _fetchResults(userId!, accessToken!);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Performance Chart
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) {
                              final labels = [
                                "Day 1",
                                "Day 2",
                                "Day 3",
                                "Day 4",
                                "Today",
                              ];
                              if (v.toInt() < labels.length) {
                                return Text(
                                  labels[v.toInt()],
                                  style: const TextStyle(fontSize: 12),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 10,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _generatePerformanceChart(
                            (data['confidence'] ?? 0) as num,
                          ),
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.lightGreen],
                          ),
                          barWidth: 4,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Metrics
              Row(
                children: [
                  _metricCard(
                    "Confidence",
                    "${data['confidence'] ?? 0}%",
                    Colors.green,
                    Icons.show_chart,
                  ),
                  _metricCard(
                    "Reps",
                    "${data['reps'] ?? 0}",
                    Colors.blue,
                    Icons.fitness_center,
                  ),
                  _metricCard(
                    "Sets",
                    "${data['sets'] ?? 0}",
                    Colors.orange,
                    Icons.repeat,
                  ),
                ],
              ),
              Row(
                children: [
                  _metricCard(
                    "Calories",
                    "${data['calories'] ?? 0}",
                    Colors.red,
                    Icons.local_fire_department,
                  ),
                  _metricCard(
                    "Duration",
                    "${data['duration'] ?? 0}s",
                    Colors.purple,
                    Icons.timer,
                  ),
                  _metricCard(
                    "Symmetry",
                    "${data['symmetry'] ?? 'N/A'}",
                    Colors.teal,
                    Icons.accessibility,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // Achievements & Cheat Detection
              _achievementBadge("${data['badge'] ?? 'N/A'}"),
              const SizedBox(height: 12),
              Text(
                "Cheat Detected: ${(data['cheatDetected'] ?? false) ? "⚠️ Yes" : "No"}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (data['cheatDetected'] ?? false)
                      ? Colors.red
                      : Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text("Correction: ${data['correction'] ?? 'N/A'}"),
              Text("Suggestion: ${data['suggestion'] ?? 'N/A'}"),
              Text("Motivation: ${data['motivation'] ?? 'N/A'}"),

              // Optional: Raw results
              if (results.isNotEmpty)
                ExpansionTile(
                  title: const Text("View All Results (Raw)"),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(results),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
