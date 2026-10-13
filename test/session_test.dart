import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/security/session.dart';

/// Uji aturan sesi token (F-02): acak, masa berlaku 7 hari, kedaluwarsa.
void main() {
  test('token baru: 64 heksadesimal acak dan unik', () {
    final t1 = SessionRules.newToken();
    final t2 = SessionRules.newToken();
    expect(t1.length, 64);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(t1), isTrue);
    expect(t1, isNot(equals(t2)));
  });

  test('sesi berlaku 7 hari dan isExpired tepat di batasnya', () {
    final now = DateTime(2026, 10, 10, 12);
    final session = SessionRules.create(7, now: now);

    expect(session.userId, 7);
    expect(
      session.expiresAt,
      now.add(const Duration(days: 7)).millisecondsSinceEpoch,
    );
    expect(session.isExpired(now: now), isFalse);
    expect(
      session.isExpired(now: now.add(const Duration(days: 6, hours: 23))),
      isFalse,
    );
    expect(
      session.isExpired(now: now.add(const Duration(days: 7))),
      isTrue,
    );
  });

  test('tryParse: valid → model; rusak/kosong → null (paksa login ulang)',
      () {
    final session = SessionRules.create(3);
    expect(SessionInfo.tryParse(session.toJson())?.token, session.token);
    expect(SessionInfo.tryParse(null), isNull);
    expect(SessionInfo.tryParse(''), isNull);
    expect(SessionInfo.tryParse('bukan-json'), isNull);
    expect(SessionInfo.tryParse('{"token":"x"}'), isNull);
  });
}
