import 'package:equatable/equatable.dart';

enum UserRole { farmer, buyer, transporter, admin }

/// Authenticated SmartAgro user (maps to backend `UserDTO`).
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.rating = 0,
    this.verified = false,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
  final double rating;
  final bool verified;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'phone': phone,
        'rating': rating,
        'verified': verified,
      };

  factory AppUser.fromJson(Map<String, dynamic> m) {
    return AppUser(
      id: m['id'] as String,
      name: m['name'] as String,
      email: m['email'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == (m['role'] as String),
        orElse: () => UserRole.farmer,
      ),
      phone: m['phone'] as String?,
      rating: (m['rating'] as num?)?.toDouble() ?? 0,
      verified: m['verified'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, email, role];
}
