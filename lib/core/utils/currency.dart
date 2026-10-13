/// Konversi mata uang (F-17, SCR-04): IDR, USD, EUR, JPY.
///
/// Kurs disimpan sebagai `rate_to_idr` — berapa IDR untuk 1 unit mata uang
/// tersebut (1 USD = 16.300 IDR → `16300.0`). Nilai ini sama dengan kolom
/// tabel `rate_cache` dan balasan `GET /rates`.
enum Currency {
  idr('IDR', 'Rupiah Indonesia', 'Rp'),
  usd('USD', 'Dolar AS', r'$'),
  eur('EUR', 'Euro', '€'),
  jpy('JPY', 'Yen Jepang', '¥');

  const Currency(this.code, this.label, this.symbol);

  final String code;
  final String label;
  final String symbol;

  static Currency fromCode(String? code) => Currency.values.firstWhere(
        (c) => c.code == code?.toUpperCase(),
        orElse: () => Currency.idr,
      );
}

/// Kumpulan kurs terhadap IDR pada satu waktu pengambilan.
class RateSnapshot {
  const RateSnapshot({required this.rates, required this.fetchedAt});

  /// Peta `currencyCode` → `rate_to_idr`. IDR selalu hadir bernilai 1.
  final Map<String, double> rates;

  /// Epoch ms saat kurs diambil (untuk label "diperbarui …").
  final int fetchedAt;

  double? rateToIdr(Currency currency) {
    if (currency == Currency.idr) return 1;
    return rates[currency.code];
  }

  /// Membaca snapshot dari balasan `GET /rates`:
  /// `{ rates: { USD: 16300, … }, fetchedAt: 1700000000000 }`.
  static RateSnapshot? fromApi(Map<String, dynamic>? body) {
    if (body == null) return null;
    final raw = body['rates'];
    if (raw is! Map) return null;
    final rates = <String, double>{
      'IDR': 1,
      for (final entry in raw.entries)
        if (entry.value is num) entry.key.toString().toUpperCase(): (entry.value as num).toDouble(),
    };
    if (rates.length < 2) return null; // hanya IDR → tidak berguna
    final fetchedAt = body['fetchedAt'];
    return RateSnapshot(
      rates: rates,
      fetchedAt: fetchedAt is num ? fetchedAt.toInt() : 0,
    );
  }
}

abstract final class CurrencyConverter {
  /// Mengonversi [amount] dari [from] ke [to] memakai [snapshot].
  /// Mengembalikan `null` bila kurs salah satu mata uang tidak tersedia.
  static double? convert({
    required double amount,
    required Currency from,
    required Currency to,
    required RateSnapshot snapshot,
  }) {
    final fromRate = snapshot.rateToIdr(from);
    final toRate = snapshot.rateToIdr(to);
    if (fromRate == null || toRate == null || toRate == 0) return null;
    // Melalui IDR sebagai mata uang jembatan: amount × fromRate / toRate.
    return amount * fromRate / toRate;
  }

  /// Format angka gaya Indonesia: pemisah ribuan titik, desimal koma,
  /// mis. `16.300,50`.
  static String format(double value, {int maxFractionDigits = 2}) {
    final negative = value < 0;
    var abs = value.abs().toStringAsFixed(maxFractionDigits);
    // Hilangkan nol desimal berlebih (16.300,00 → 16.300).
    if (abs.contains('.')) {
      abs = abs.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    final parts = abs.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final dec = parts.length > 1 ? ',${parts[1]}' : '';
    return '${negative ? '-' : ''}$intPart$dec';
  }
}
