import { env } from '../config/env.js';

/**
 * Proxy LLM Gemini (F-11 / WF-07 — `docs/deskripsi_proyek.md` Bagian 5.6).
 *
 * Ketentuan:
 *   * API key HANYA berada di `.env` server — tidak pernah dikirim ke klien;
 *   * prompt sistem membatasi jawaban pada topik buku dan bahasa Indonesia;
 *   * kegagalan dipetakan ke kode yang jelas agar klien bisa menampilkan
 *     pesan "kuota habis" / "coba lagi" (workflow Bagian 3.5);
 *   * `AI_MOCK=1` → balasan tetap tanpa jaringan (test deterministik);
 *   * tanpa API key → `AI_DISABLED` 503 (aplikasi tetap jalan — keputusan 18).
 */

/** Prompt sistem: bahasa Indonesia + hanya seputar buku (Bagian 5.6). */
const SYSTEM_PROMPT = [
  'Kamu adalah "Storyloka AI", asisten membaca berbahasa Indonesia.',
  'Jawab HANYA seputar buku dan bacaan: cerita, karakter, penulis, genre,',
  'tema, dan rekomendasi bacaan. Jangan keluar dari topik itu.',
  'Jawab ringkas dan jelas (maksimal ±120 kata) dengan format teks biasa.',
].join(' ');

/** Galat berkode — dikirim balik sebagai `{ error: { code, message } }`. */
export class AiError extends Error {
  constructor(code, message, status) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

/** Balasan mock deterministik (tanpa jaringan) untuk `AI_MOCK=1`. */
function mockText(kind, input) {
  if (kind === 'summarize') {
    return `Ringkasan: "${input.title}" karya ${input.author} mengisahkan perjalanan `
      + 'karakter utama yang tumbuh melalui konflik dan persahabatan — '
      + 'dimulai, puncak, hingga penutup yang memberi pelajaran berharga. '
      + '(Balasan mock — AI_MOCK=1.)';
  }
  if (kind === 'recommend') {
    return [
      '5 buku mirip rekomendasimu (balasan mock — AI_MOCK=1):',
      '1. Laskar Pelangi — Andrea Hirata (persahabatan & perjuangan)',
      '2. Negeri 5 Menara — Ahmad Fuadi (anak pesantren mengejar mimpi)',
      '3. Ayat-Ayat Cinta — Habiburrahman El Shirazy (drama keluarga)',
      '4. Perahu Kertas — Dewi Lestari (persahabatan & mimpi)',
      '5. Sang Pemimpi — Andrea Hirata (tekad meraih cita-cita)',
    ].join('\n');
  }
  return `Tentang "${input.message}": jawaban singkat seputar buku sesuai `
    + 'permintaanmu. (Balasan mock — AI_MOCK=1.)';
}

/** Panggil Gemini generateContent; melempar [AiError] bila gagal. */
async function callGemini({ kind, input, prompt }) {
  if (env.aiMock) return mockText(kind, input);
  if (!env.geminiApiKey) {
    throw new AiError(
      'AI_DISABLED',
      'Layanan AI belum diaktifkan di server (API key belum diatur).',
      503,
    );
  }

  let response;
  try {
    response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${env.geminiModel}:generateContent`,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': env.geminiApiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { maxOutputTokens: 600, temperature: 0.4 },
        }),
        signal: AbortSignal.timeout(env.aiTimeoutMs),
      },
    );
  } catch (error) {
    if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
      throw new AiError('AI_TIMEOUT', 'AI tidak merespons (timeout). Coba lagi.', 504);
    }
    throw new AiError('AI_UPSTREAM', 'Layanan AI tidak terjangkau. Coba lagi.', 502);
  }

  if (response.status === 429) {
    throw new AiError('AI_QUOTA', 'Kuota AI habis. Coba lagi beberapa saat lagi.', 429);
  }
  if (!response.ok) {
    throw new AiError('AI_UPSTREAM', `Layanan AI membalas HTTP ${response.status}.`, 502);
  }

  let data;
  try {
    data = await response.json();
  } catch (_) {
    throw new AiError('AI_UPSTREAM', 'Balasan AI tidak terbaca. Coba lagi.', 502);
  }
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const text = parts.map((part) => part.text ?? '').join('').trim();
  if (!text) {
    throw new AiError('AI_UPSTREAM', 'AI tidak memberi jawaban. Coba lagi.', 502);
  }
  return text;
}

function joinHistory(history) {
  if (!Array.isArray(history) || history.length === 0) return '';
  const lines = history
    .slice(-8)
    .map((item) => {
      const role = item?.role === 'assistant' ? 'AI' : 'Pengguna';
      const text = typeof item?.text === 'string' ? item.text.slice(0, 400) : '';
      return `${role}: ${text}`;
    })
    .filter((line) => !line.endsWith(': '));
  return lines.length ? `\nRiwayat percakapan:\n${lines.join('\n')}` : '';
}

/** Tanya-jawab SCR-05 (`POST /ai/chat`). */
export async function chatCompletion({ message, history, context }) {
  const prompt = [
    context ? `Konteks buku: ${context}` : '',
    joinHistory(history),
    `Pertanyaan pengguna: ${message}`,
  ]
    .filter(Boolean)
    .join('\n');
  return callGemini({ kind: 'chat', input: { message }, prompt });
}

/** Ringkasan buku (`POST /ai/summarize` — dipakai SCR-06 & quick action). */
export async function summarizeBook({ title, author, synopsis, notes }) {
  const prompt = [
    'Ringkas buku berikut (maks ±120 kata, bahasa Indonesia):',
    `Judul: ${title}`,
    `Penulis: ${author ?? '-'}`,
    synopsis ? `Sinopsis: ${synopsis}` : '',
    notes?.length ? `Catatan pembaca: ${notes.slice(0, 5).join(' | ')}` : '',
  ]
    .filter(Boolean)
    .join('\n');
  return callGemini({ kind: 'summarize', input: { title, author: author ?? '-' }, prompt });
}

/** Rekomendasi buku mirip (`POST /ai/recommend` — Bagian 5.6). */
export async function recommendBooks({ books }) {
  const lines = (Array.isArray(books) ? books : []).slice(0, 30).map((book) => {
    const genre = book?.genre ? ` (${book.genre})` : '';
    const rating = Number.isFinite(Number(book?.rating)) ? ` rating ${book.rating}/5` : '';
    return `- ${book?.title ?? 'Tanpa judul'}${genre}${rating}`;
  });
  const prompt = [
    'Dari daftar bacaan pengguna berikut, rekomendasikan 5 buku serupa '
      + '(judul, penulis, satu alasan singkat, per poin satu baris):',
    lines.join('\n') || '(daftar kosong — rekomendasikan buku umum berbahasa Indonesia)',
  ].join('\n');
  return callGemini({ kind: 'recommend', input: {}, prompt });
}
