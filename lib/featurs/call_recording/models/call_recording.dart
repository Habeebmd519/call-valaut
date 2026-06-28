class CallRecording {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  CallRecording({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      "path": path,
      "name": name,
      "size": size,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  factory CallRecording.fromJson(Map<String, dynamic> json) {
    return CallRecording(
      path: json["path"],
      name: json["name"],
      size: json["size"],
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
