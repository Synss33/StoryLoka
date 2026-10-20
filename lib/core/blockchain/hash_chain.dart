import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/block.dart';

/// Hasil validasi rantai hash (workflow Bagian 3.4):
/// `valid` = seluruh blok konsisten; [brokenIndex] menunjuk nomor blok
/// pertama yang rusak (null bila valid).
class ChainValidation {
  const ChainValidation({required this.valid, this.brokenIndex});

  final bool valid;
  final int? brokenIndex;
}

/// Hash chain SHA-256 lokal "Proof of Reading" (F-12 / Bagian 5.7) —
/// **bukan** kripto/NFT.
///
/// ```text
/// review_hash = SHA256(teks ulasan)
/// block       = { index, timestamp, book_id, review_hash,
///                 finished_date, previous_hash }
/// hash        = SHA256(index | timestamp | book_id | review_hash |
///                     finished_date | previous_hash)
/// ```
/// Blok pertama per pengguna memakai [genesisPreviousHash] (64 nol).
abstract final class HashChain {
  /// `previous_hash` blok pertama (idx 0) — 64 karakter nol (Bagian 5.7).
  static const String genesisPreviousHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// SHA-256 dari [text] sebagai heksadesimal lowercase 64 karakter.
  static String sha256Hex(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  /// Hash sebuah blok: SHA-256 seluruh isi field dipisah `|`
  /// (`index | timestamp | book_id | review_hash | finished_date |
  /// previous_hash`) — deskripsi Bagian 5.7.
  static String blockHash(Block block) => sha256Hex(
        '${block.idx}|${block.timestamp}|${block.bookId}|'
        '${block.reviewHash}|${block.finishedDate}|${block.previousHash}',
      );

  /// Membangun blok baru dari ulasan buku yang baru saja selesai.
  ///
  /// [previousHash] = hash blok sebelumnya, atau [genesisPreviousHash]
  /// bila ini blok pertama pengguna.
  static Block buildBlock({
    required int idx,
    required int userId,
    required int bookId,
    required String reviewText,
    required int finishedDate,
    required String previousHash,
    int? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final draft = Block(
      idx: idx,
      userId: userId,
      timestamp: ts,
      bookId: bookId,
      reviewHash: sha256Hex(reviewText),
      finishedDate: finishedDate,
      previousHash: previousHash,
      hash: '',
    );
    return Block(
      idx: draft.idx,
      userId: draft.userId,
      timestamp: draft.timestamp,
      bookId: draft.bookId,
      reviewHash: draft.reviewHash,
      finishedDate: draft.finishedDate,
      previousHash: draft.previousHash,
      hash: blockHash(draft),
    );
  }

  /// Validasi rantai (workflow Bagian 3.4): untuk tiap blok, cocokkan
  /// `previous_hash` dengan blok sebelumnya **dan** hitung ulang `hash`-nya.
  /// Hasil: `Valid`, atau `Tidak Valid` yang menunjuk nomor blok rusak.
  ///
  /// Rantai kosong dianggap valid (belum ada buku selesai).
  static ChainValidation validate(List<Block> blocks) {
    final sorted = [...blocks]..sort((a, b) => a.idx.compareTo(b.idx));

    var expectedIdx = 0;
    var expectedPrevious = genesisPreviousHash;
    for (final block in sorted) {
      // Nomor blok harus berurutan tanpa celah (idx = posisi).
      if (block.idx != expectedIdx) {
        return ChainValidation(valid: false, brokenIndex: block.idx);
      }
      // rantai: previous_hash harus cocok dengan hash blok sebelumnya.
      if (block.previousHash != expectedPrevious) {
        return ChainValidation(valid: false, brokenIndex: block.idx);
      }
      // Integritas isi: hash tersimpan = hitung ulang seluruh field.
      if (blockHash(block) != block.hash) {
        return ChainValidation(valid: false, brokenIndex: block.idx);
      }
      expectedPrevious = block.hash;
      expectedIdx = block.idx + 1;
    }
    return const ChainValidation(valid: true);
  }

  /// Potongan hash tampilan: `8f4a…e91c` (4 + 4 karakter).
  static String shortHash(String hash) {
    if (hash.length <= 8) return hash;
    return '${hash.substring(0, 4)}…${hash.substring(hash.length - 4)}';
  }
}
