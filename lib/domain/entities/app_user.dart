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
    this.location,
    this.avatarUrl,
    this.rating = 0,
    this.verified = false,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
  final String? location;
  final String? avatarUrl;
  final double rating;
  final bool verified;

  AppUser copyWith({
    String? name,
    String? phone,
    String? location,
    String? avatarUrl,
    double? rating,
    bool? verified,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'phone': phone,
        'location': location,
        'avatarUrl': avatarUrl,
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
      location: m['location'] as String?,
      avatarUrl: m['avatarUrl'] as String?,
      rating: (m['rating'] as num?)?.toDouble() ?? 0,
      verified: m['verified'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, email, role];
}
