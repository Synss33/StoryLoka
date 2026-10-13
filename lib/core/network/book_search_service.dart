import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Hasil pencarian buku online (Google Books / Open Library) — SCR-08.
/// Dipakai untuk mengisi form SCR-07 otomatis (TC-13, F-10).
class OnlineBookResult {
  const OnlineBookResult({
    required this.title,
    this.author = '',
    this.publisher,
    this.year,
    this.isbn,
    this.pages,
    this.cover,
    this.synopsis,
    this.genre,
    this.source = '',
  });

  final String title;
  final String author;
  final String? publisher;
  final int? year;
  final String? isbn;
  final int? pages;
  final String? cover;
  final String? synopsis;
  final String? genre;

  /// Sumber data ("Google Books" / "Open Library") untuk ditampilkan.
  final String source;
}

/// Klien pencarian buku online tanpa API key (keputusan 18: proyek $0).
///
/// Dua sumber dipanggil berurutan; kegagalan satu sumber diabaikan selama
/// sumber lain masih memberi hasil. Interface abstraksi agar pengujian
/// (TC-13) dapat menyuntikkan data palsu tanpa jaringan.
abstract class BookSearchService {
  Future<List<OnlineBookResult>> search(String query);
}

/// Implementasi produksi: Google Books API + Open Library Search API.
class HttpBookSearchService implements BookSearchService {
  HttpBookSearchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 10);

  @override
  Future<List<OnlineBookResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <OnlineBookResult>[];
    final results = <OnlineBookResult>[];
    results.addAll(await _searchGoogleBooks(q));
    results.addAll(await _searchOpenLibrary(q));
    return results;
  }

  /// Google Books API v1 — tanpa key (kuota publik; gagal → daftar kosong).
  Future<List<OnlineBookResult>> _searchGoogleBooks(String q) async {
    try {
      final uri = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes'
        '?q=${Uri.encodeQueryComponent(q)}&maxResults=10&langRestrict=id,en',
      );
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const <OnlineBookResult>[];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const <OnlineBookResult>[];
      final items = decoded['items'];
      if (items is! List) return const <OnlineBookResult>[];

      return items.map<OnlineBookResult?>((raw) {
        if (raw is! Map<String, dynamic>) return null;
        final volume = raw['volumeInfo'];
        if (volume is! Map<String, dynamic>) return null;
        final title = volume['title'];
        if (title is! String || title.trim().isEmpty) return null;

        final authors = volume['authors'];
        final author = authors is List && authors.isNotEmpty
            ? authors.map((a) => '$a').join(', ')
            : '';

        // ISBN: cari identifier jenis ISBN_13/ISBN_10 lebih dulu.
        String? isbn;
        final ids = volume['industryIdentifiers'];
        if (ids is List) {
          for (final id in ids) {
            if (id is Map && id['identifier'] is String) {
              final type = '${id['type']}';
              if (type.contains('ISBN')) {
                isbn = id['identifier'] as String;
                if (type == 'ISBN_13') break;
              }
            }
          }
        }

        int? asInt(Object? value) => value is num ? value.toInt() : null;

        final imageLinks = volume['imageLinks'];
        final thumbnail = imageLinks is Map ? imageLinks['thumbnail'] : null;

        return OnlineBookResult(
          title: title.trim(),
          author: author,
          publisher: volume['publisher'] is String
              ? volume['publisher'] as String
              : null,
          year: asInt(volume['publishedDate'] is String
              ? int.tryParse((volume['publishedDate'] as String).split('-').first)
              : null),
          isbn: isbn,
          pages: asInt(volume['pageCount']),
          cover: thumbnail is String ? thumbnail.replaceAll('http:', 'https:') : null,
          synopsis: volume['description'] is String
              ? volume['description'] as String
              : null,
          source: 'Google Books',
        );
      }).whereType<OnlineBookResult>().toList();
    } catch (_) {
      return const <OnlineBookResult>[];
    }
  }

  /// Open Library Search API — tanpa key.
  Future<List<OnlineBookResult>> _searchOpenLibrary(String q) async {
    try {
      final uri = Uri.parse(
        'https://openlibrary.org/search.json'
        '?q=${Uri.encodeQueryComponent(q)}&limit=10&fields=title,author_name,'
        'publisher,first_publish_year,isbn,number_of_pages_median,cover_i,'
        'subject,first_sentence',
      );
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const <OnlineBookResult>[];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const <OnlineBookResult>[];
      final docs = decoded['docs'];
      if (docs is! List) return const <OnlineBookResult>[];

      return docs.map<OnlineBookResult?>((raw) {
        if (raw is! Map<String, dynamic>) return null;
        final title = raw['title'];
        if (title is! String || title.trim().isEmpty) return null;

        final authors = raw['author_name'];
        final authors2 = authors is List && authors.isNotEmpty
            ? authors.map((a) => '$a').join(', ')
            : '';

        final publishers = raw['publisher'];
        final publisher = publishers is List && publishers.isNotEmpty
            ? '${publishers.first}'
            : null;

        // ISBN: pilih entri pertama yang berbentuk ISBN-13/10 valid.
        String? isbn;
        final isbns = raw['isbn'];
        if (isbns is List) {
          for (final value in isbns) {
            final s = '$value';
            if (s.length == 13 || s.length == 10) {
              isbn = s;
              break;
            }
          }
        }

        final coverId = raw['cover_i'];
        final subjects = raw['subject'];

        return OnlineBookResult(
          title: title.trim(),
          author: authors2,
          publisher: publisher,
          year: raw['first_publish_year'] is num
              ? (raw['first_publish_year'] as num).toInt()
              : null,
          isbn: isbn,
          pages: raw['number_of_pages_median'] is num
              ? (raw['number_of_pages_median'] as num).toInt()
              : null,
          cover: coverId is num
              ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
              : null,
          synopsis: subjects is List && subjects.isNotEmpty
              ? subjects.take(8).map((s) => '$s').join(', ')
              : null,
          genre: subjects is List && subjects.isNotEmpty
              ? '${subjects.first}'
              : null,
          source: 'Open Library',
        );
      }).whereType<OnlineBookResult>().toList();
    } catch (_) {
      return const <OnlineBookResult>[];
    }
  }
}

final bookSearchServiceProvider = Provider<BookSearchService>(
  (ref) => HttpBookSearchService(),
);
