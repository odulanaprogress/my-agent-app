import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // e.g., 'agent', 'admin'
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    Object? createdAtField = map['createdAt'];
    DateTime createdAtValue;

    if (createdAtField is DateTime) {
      createdAtValue = createdAtField;
    } else if (createdAtField is String) {
      createdAtValue = DateTime.tryParse(createdAtField) ?? DateTime.now();
    } else if (createdAtField is Timestamp) {
      createdAtValue = createdAtField.toDate();
    } else {
      createdAtValue = DateTime.now();
    }

    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'agent',
      createdAt: createdAtValue,
    );
  }
}
