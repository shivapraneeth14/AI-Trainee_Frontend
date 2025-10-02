import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Login.dart'; // make sure this path matches your project

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    print("ProfilePage: initState called");
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    print("fetchUserProfile: Starting to fetch user profile");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken'); // using accessToken
    print("fetchUserProfile: Retrieved token: $token");

    if (token == null) {
      print(
        "fetchUserProfile: No token found, setting user=null and stopping loading",
      );
      setState(() {
        user = null;
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse("https://ai-trainee-5.onrender.com/api/me");

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      print("fetchUserProfile: Response status: ${response.statusCode}");
      print("fetchUserProfile: Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          user = data['user']; // backend returns { user: {...} }
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          user = null;
          isLoading = false;
        });
        print("fetchUserProfile: Unauthorized, please re-login");
      } else {
        setState(() {
          user = null;
          isLoading = false;
        });
        print(
          "fetchUserProfile: Error ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("fetchUserProfile: Exception $e");
      setState(() {
        user = null;
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      // Optional: notify backend to invalidate refresh token
      try {
        if (token != null) {
          final url = Uri.parse("https://ai-trainee-5.onrender.com/api/logout");
          final res = await http.post(
            url,
            headers: {
              "Authorization": "Bearer $token",
              "Accept": "application/json",
            },
          );
          print("logout: status=${res.statusCode} body=${res.body}");
        }
      } catch (e) {
        print("logout: request error $e");
      }

      // Clear local token
      await prefs.remove('accessToken');

      // Navigate to Login using pushReplacement (as requested)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      print("logout: exception $e");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print("build: isLoading = $isLoading, user = $user");

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null || user!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Profile"),
          actions: [
            IconButton(
              tooltip: "Logout",
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: const Center(
          child: Text("No profile found. Please log in again."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + Name
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.indigo,
                  child: Text(
                    user!['username']?[0]?.toUpperCase() ?? "?",
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user!['username'] ?? "Unknown",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${user!['sport'] ?? 'N/A'} Enthusiast",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Basic Info
            Text("Email: ${user!['email'] ?? 'N/A'}"),
            Text("Age: ${user!['age'] ?? 'N/A'}"),
            Text("Gender: ${user!['gender'] ?? 'N/A'}"),
            Text("Region: ${user!['region'] ?? 'N/A'}"),
            const Divider(height: 32),

            // Stats (dummy keys – update if needed)
            const Text(
              "Performance Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _statCard(
                  "Workouts",
                  user!['workouts']?.toString() ?? "0",
                  Colors.indigo,
                ),
                _statCard(
                  "Correct Reps",
                  user!['correctReps']?.toString() ?? "0",
                  Colors.green,
                ),
                _statCard(
                  "Wrong Form",
                  user!['wrongForm']?.toString() ?? "0",
                  Colors.red,
                ),
                _statCard("Rank", "#${user!['rank'] ?? '0'}", Colors.orange),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
