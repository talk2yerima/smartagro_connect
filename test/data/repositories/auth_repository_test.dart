import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/core/errors/failures.dart';
import 'package:smartagro_connect/data/repositories/auth_repository.dart';
import 'package:smartagro_connect/data/services/firestore_service.dart';
import 'package:smartagro_connect/data/services/secure_token_store.dart';
import 'package:smartagro_connect/domain/entities/app_user.dart';

class MockSecureTokenStore extends Mock implements SecureTokenStore {}

class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  late MockSecureTokenStore tokenStore;
  late MockFirestoreService firestore;
  late AuthRepository repo;

  setUp(() async {
    tokenStore = MockSecureTokenStore();
    firestore = MockFirestoreService();

    when(() => tokenStore.writeTokens(access: any(named: 'access')))
        .thenAnswer((_) async {});
    when(() => tokenStore.clear()).thenAnswer((_) async {});
    when(() => tokenStore.writeValue(any(), any())).thenAnswer((_) async {});
    when(() => tokenStore.readValue(any())).thenAnswer((_) async => null);
    when(() => tokenStore.removeValue(any())).thenAnswer((_) async {});

    repo = AuthRepository(secure: tokenStore, firestore: firestore);
  });

  // ── currentSessionUser ──────────────────────────────────────────────────────
  group('currentSessionUser', () {
    test('returns null when no session stored', () {
      expect(repo.currentSessionUser, isNull);
    });

    test('returns user after successful login', () async {
      await repo.loginWithEmail(email: 'test@farm.ng', password: 'secret1');
      expect(repo.currentSessionUser, isNotNull);
      expect(repo.currentSessionUser!.email, 'test@farm.ng');
    });
  });

  // ── loginWithEmail ──────────────────────────────────────────────────────────
  group('loginWithEmail', () {
    test('returns a demo AppUser with given email', () async {
      final user = await repo.loginWithEmail(
        email: 'farmer@demo.ng',
        password: 'password123',
      );
      expect(user.email, 'farmer@demo.ng');
      expect(user.role, UserRole.farmer);
      expect(user.id, isNotEmpty);
    });

    test('defaults role to farmer', () async {
      final user = await repo.loginWithEmail(
        email: 'x@x.ng',
        password: 'password',
      );
      expect(user.role, UserRole.farmer);
    });

    test('respects demoRole parameter', () async {
      final user = await repo.loginWithEmail(
        email: 'buyer@demo.ng',
        password: 'password',
        demoRole: UserRole.buyer,
      );
      expect(user.role, UserRole.buyer);
    });

    test('throws AuthFailure when password is too short', () async {
      expect(
        () => repo.loginWithEmail(email: 'a@b.ng', password: '123'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('writes access token to store', () async {
      await repo.loginWithEmail(email: 'a@b.ng', password: 'longenough');
      verify(() => tokenStore.writeTokens(access: any(named: 'access')))
          .called(1);
    });

    test('persists user to secure storage', () async {
      await repo.loginWithEmail(email: 'a@b.ng', password: 'longenough');
      verify(() => tokenStore.writeValue('session_user_json', any())).called(1);
    });

    test('different emails produce different user ids', () async {
      final a =
          await repo.loginWithEmail(email: 'aaa@b.ng', password: 'pass1234');
      final b =
          await repo.loginWithEmail(email: 'bbb@b.ng', password: 'pass1234');
      expect(a.id, isNot(equals(b.id)));
    });
  });

  // ── registerWithEmail ───────────────────────────────────────────────────────
  group('registerWithEmail', () {
    test('creates user with supplied name, email, role', () async {
      final user = await repo.registerWithEmail(
        name: 'Ngozi Okonkwo',
        email: 'ngozi@farm.ng',
        password: 'pass1234',
        role: UserRole.transporter,
      );
      expect(user.name, 'Ngozi Okonkwo');
      expect(user.email, 'ngozi@farm.ng');
      expect(user.role, UserRole.transporter);
    });

    test('new registrant is not verified', () async {
      final user = await repo.registerWithEmail(
        name: 'Test',
        email: 't@t.ng',
        password: 'secret99',
        role: UserRole.buyer,
      );
      expect(user.verified, isFalse);
    });

    test('persists user to secure storage', () async {
      await repo.registerWithEmail(
        name: 'Tola',
        email: 'tola@t.ng',
        password: 'pass1234',
        role: UserRole.farmer,
      );
      verify(() => tokenStore.writeValue('session_user_json', any())).called(1);
    });
  });

  // ── logout ──────────────────────────────────────────────────────────────────
  group('logout', () {
    test('clears session user from secure storage', () async {
      await repo.loginWithEmail(email: 'a@b.ng', password: 'pass1234');
      await repo.logout();
      verify(() => tokenStore.removeValue('session_user_json')).called(1);
    });

    test('clears token store', () async {
      await repo.logout();
      verify(() => tokenStore.clear()).called(1);
    });

    test('currentSessionUser is null after logout', () async {
      await repo.loginWithEmail(email: 'a@b.ng', password: 'pass1234');
      await repo.logout();
      expect(repo.currentSessionUser, isNull);
    });
  });

  // ── sendPasswordReset ───────────────────────────────────────────────────────
  group('sendPasswordReset', () {
    test('completes without throwing', () async {
      await expectLater(
        repo.sendPasswordReset('user@demo.ng'),
        completes,
      );
    });
  });

  // ── googleSignIn ────────────────────────────────────────────────────────────
  group('googleSignIn', () {
    test('returns a buyer user', () async {
      final user = await repo.googleSignIn();
      expect(user.role, UserRole.buyer);
    });

    test('persists user to secure storage', () async {
      await repo.googleSignIn();
      verify(() => tokenStore.writeValue('session_user_json', any())).called(1);
    });
  });
}
