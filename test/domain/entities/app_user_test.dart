import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/domain/entities/app_user.dart';

void main() {
  const user = AppUser(
    id: 'u1',
    name: 'Emeka Obi',
    email: 'emeka@farm.ng',
    role: UserRole.farmer,
    phone: '+2348012345678',
    rating: 4.6,
    verified: true,
  );

  group('AppUser.toJson', () {
    test('serialises all fields', () {
      final j = user.toJson();
      expect(j['id'], 'u1');
      expect(j['name'], 'Emeka Obi');
      expect(j['email'], 'emeka@farm.ng');
      expect(j['role'], 'farmer');
      expect(j['phone'], '+2348012345678');
      expect(j['rating'], 4.6);
      expect(j['verified'], true);
    });

    test('null phone serialises as null', () {
      const noPhone = AppUser(id: 'u2', name: 'X', email: 'x@y.ng', role: UserRole.buyer);
      expect(noPhone.toJson()['phone'], isNull);
    });
  });

  group('AppUser.fromJson', () {
    test('round-trip preserves equality', () {
      final restored = AppUser.fromJson(user.toJson());
      expect(restored, equals(user));
    });

    test('defaults role to farmer for unknown value', () {
      final j = {...user.toJson(), 'role': 'unknown_role'};
      final u = AppUser.fromJson(j);
      expect(u.role, UserRole.farmer);
    });

    test('defaults rating to 0 when absent', () {
      final j = user.toJson()..remove('rating');
      expect(AppUser.fromJson(j).rating, 0.0);
    });

    test('defaults verified to false when absent', () {
      final j = user.toJson()..remove('verified');
      expect(AppUser.fromJson(j).verified, isFalse);
    });

    test('maps all UserRole values', () {
      for (final role in UserRole.values) {
        final j = {...user.toJson(), 'role': role.name};
        expect(AppUser.fromJson(j).role, role);
      }
    });
  });

  group('AppUser equality', () {
    test('same id+email+role equals', () {
      const a = AppUser(id: 'u1', name: 'A', email: 'emeka@farm.ng', role: UserRole.farmer);
      const b = AppUser(id: 'u1', name: 'B', email: 'emeka@farm.ng', role: UserRole.farmer, rating: 5.0);
      expect(a, equals(b));
    });

    test('different id not equal', () {
      const a = AppUser(id: 'u1', name: 'A', email: 'a@b.ng', role: UserRole.farmer);
      const b = AppUser(id: 'u2', name: 'A', email: 'a@b.ng', role: UserRole.farmer);
      expect(a, isNot(equals(b)));
    });
  });
}
