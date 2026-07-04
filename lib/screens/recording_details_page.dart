import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class RecordingDetailsPage extends StatefulWidget {
  final File file;
  const RecordingDetailsPage({super.key, required this.file});

  @override
  State<RecordingDetailsPage> createState() => _RecordingDetailsPageState();
}

class _RecordingDetailsPageState extends State<RecordingDetailsPage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  bool playing = false;
  String phoneNumber = "Unknown";
  String date = "";
  String time = "";
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    parseFileName();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    print(widget.file);
  }

  void parseFileName() {
    final name = widget.file.path.split('/').last;

    // -----------------------------
    // Phone number
    // -----------------------------
    final phoneMatch = RegExp(r'\((.*?)\)').firstMatch(name);

    if (phoneMatch != null) {
      phoneNumber = phoneMatch.group(1)!;
    }

    // -----------------------------
    // Date & Time
    // Looks for _YYYYMMDDHHMMSS
    // -----------------------------
    final dateMatch = RegExp(r'_(\d{14})').firstMatch(name);

    if (dateMatch != null) {
      final value = dateMatch.group(1)!;

      date =
          "${value.substring(0, 4)}/${value.substring(4, 6)}/${value.substring(6, 8)}";

      time =
          "${value.substring(8, 10)}:${value.substring(10, 12)}:${value.substring(12, 14)}";
    }
  }

  Future<void> play() async {
    if (playing) {
      await player.stop();
      setState(() => playing = false);
      _pulseController.stop();
      _pulseController.reset();
      return;
    }
    await player.play(DeviceFileSource(widget.file.path));
    setState(() => playing = true);
    _pulseController.repeat(reverse: true);
    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => playing = false);
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.uri.pathSegments.last;
    final size = (widget.file.lengthSync() / 1024 / 1024).toStringAsFixed(2);

    const bgColor = Color(0xFF0F0F14);
    const cardColor = Color(0xFF1A1A24);
    const accentColor = Color(0xFF6C63FF);
    const accentGlow = Color(0x446C63FF);
    const labelColor = Color(0xFF8888AA);
    const valueColor = Color(0xFFEEEEFF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: valueColor),
        title: const Text(
          "Recording Details",
          style: TextStyle(
            color: valueColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentGlow, width: 1.2),
            ),
            child: Column(
              children: [
                // Animated icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: playing ? _pulseAnimation.value : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withOpacity(0.12),
                      border: Border.all(
                        color: playing
                            ? accentColor
                            : accentColor.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      playing ? Icons.graphic_eq : Icons.voicemail,
                      size: 40,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  fileName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "$size MB",
                  style: const TextStyle(color: labelColor, fontSize: 13),
                ),
                const SizedBox(height: 28),
                // Play / Stop button
                GestureDetector(
                  onTap: play,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: playing ? const Color(0xFF2A1A4A) : accentColor,
                      boxShadow: playing
                          ? [
                              BoxShadow(
                                color: accentGlow,
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          playing
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: playing ? accentColor : Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          playing ? "Stop" : "Play Recording",
                          style: TextStyle(
                            color: playing ? accentColor : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "DETAILS",
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),

          // ── Info cards ─────────────────────────────────────
          _InfoCard(
            icon: Icons.phone_rounded,
            label: "Phone Number",
            value: phoneNumber,
            accent: accentColor,
          ),
          _InfoCard(
            icon: Icons.calendar_today_rounded,
            label: "Date",
            value: date.isEmpty ? "—" : date,
            accent: accentColor,
          ),
          _InfoCard(
            icon: Icons.access_time_rounded,
            label: "Time",
            value: time.isEmpty ? "—" : time,
            accent: accentColor,
          ),
          _InfoCard(
            icon: Icons.folder_open_rounded,
            label: "Path",
            value: widget.file.path,
            accent: accentColor,
            small: true,
          ),
          _InfoCard(
            icon: Icons.cloud_upload_outlined,
            label: "Upload Status",
            value: "Pending",
            accent: const Color(0xFFFFAA44),
            valueColor: const Color(0xFFFFAA44),
          ),
        ],
      ),
    );
  }
}

// ── Reusable info row card ────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color? valueColor;
  final bool small;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1A1A24);
    const labelColor = Color(0xFF8888AA);
    const defaultValueColor = Color(0xFFEEEEFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: labelColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? defaultValueColor,
                    fontSize: small ? 12 : 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
