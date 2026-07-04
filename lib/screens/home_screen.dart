import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("server_url", url);
  }

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("server_url") ??
        "https://n8n-642200590.kloudbeansite.com/webhook/call-upload";
  }

  Future<void> _showServerDialog() async {
    final controller = TextEditingController(text: await getServerUrl());

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Server URL"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "https://your-server/webhook",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await saveServerUrl(controller.text.trim());

              if (mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Server URL updated")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CallVault",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text("Automatic Call Sync", style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          //------------------------------------------
          // STATUS
          //------------------------------------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.green,
                    size: 34,
                  ),
                ),

                const SizedBox(width: 18),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Service Running",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        "Monitoring call recordings...",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "ACTIVE",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          //------------------------------------------
          // GRID
          //------------------------------------------
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1.2,
            children: const [
              StatCard(icon: Icons.call, value: "12", title: "Pending Upload"),

              StatCard(
                icon: Icons.cloud_done,
                value: "238",
                title: "Uploaded Today",
              ),

              StatCard(icon: Icons.folder, value: "128", title: "Total Files"),

              StatCard(
                icon: Icons.storage,
                value: "1.4 GB",
                title: "Storage Used",
              ),
            ],
          ),

          const SizedBox(height: 20),

          //------------------------------------------
          // LAST FILE
          //------------------------------------------
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Last Uploaded",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),

                SizedBox(height: 15),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(Icons.audio_file)),
                  title: Text("call_2026_06_27_10_21.mp3"),
                  subtitle: Text("Uploaded 2 min ago"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          //------------------------------------------
          // STORAGE
          //------------------------------------------
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Watching Folder",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),

                SizedBox(height: 10),

                Text(
                  "/Storage/CallRecordings/",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 58),
            ),
            onPressed: () {},
            icon: const Icon(Icons.sync),
            label: const Text("Sync Now", style: TextStyle(fontSize: 17)),
          ),

          const SizedBox(height: 30),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.settings),
        onPressed: _showServerDialog,
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
