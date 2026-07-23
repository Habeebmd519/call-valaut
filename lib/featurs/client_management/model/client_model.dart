class ClientModel {
  final String id;
  final String clientName;
  final String phoneNumber;

  const ClientModel({
    required this.id,
    required this.clientName,
    required this.phoneNumber,
  });

  ClientModel copyWith({String? id, String? clientName, String? phoneNumber}) {
    return ClientModel(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'client_name': clientName, 'phone_number': phoneNumber};
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id']?.toString() ?? '',
      clientName: map['client_name']?.toString() ?? '',
      phoneNumber: map['phone_number']?.toString() ?? '',
    );
  }
}
