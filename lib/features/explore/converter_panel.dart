import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/rates_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/world_clock.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/storyloka_card.dart';
import '../profile/profile_screen.dart' show formatDateTime;

/// Konverter mata uang (F-17, SCR-04): IDR, USD, EUR, JPY.
///
/// Kurs dari `GET /rates` (backend) dan di-cache di SQLite `rate_cache`
/// untuk pemakaian offline; label "diperbarui …" memakai `fetchedAt`.
class CurrencyPanel extends ConsumerStatefulWidget {
  const CurrencyPanel({super.key});

  @override
  ConsumerState<CurrencyPanel> createState() => _CurrencyPanelState();
}

class _CurrencyPanelState extends ConsumerState<CurrencyPanel> {
  final _amount = TextEditingController(text: '100');
  Currency _from = Currency.usd;
  Currency _to = Currency.idr;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final rates = ref.watch(ratesProvider);

    return rates.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenMargin),
        child: LoadingSkeleton.list(count: 2),
      ),
      error: (error, _) => ErrorState(
        title: 'Kurs Tidak Tersedia',
        message: 'Gagal memuat kurs dari server maupun cache lokal.',
        onRetry: () => ref.invalidate(ratesProvider),
      ),
      data: (result) {
        if (result == null) {
          return const EmptyState(
            icon: Icons.currency_exchange_outlined,
            title: 'Kurs Belum Pernah Dimuat',
            description:
                'Sambungkan internet sekali untuk mengambil kurs, '
                'lalu tersimpan offline.',
          );
        }
        final snapshot = result.snapshot;
        final amount = double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
        final converted = CurrencyConverter.convert(
          amount: amount,
          from: _from,
          to: _to,
          snapshot: snapshot,
        );

        return StorylokaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mata Uang', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.cardGap),
              TextField(
                key: const ValueKey<String>('currency-amount'),
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Jumlah (harga buku)',
                  hintText: 'mis. 100',
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              Row(
                children: [
                  Expanded(
                    child: _CurrencyDropdown(
                      value: _from,
                      label: 'Dari',
                      onChanged: (value) => setState(() => _from = value!),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('swap-currency'),
                    tooltip: 'Tukar mata uang',
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => setState(() {
                      final tmp = _from;
                      _from = _to;
                      _to = tmp;
                    }),
                  ),
                  Expanded(
                    child: _CurrencyDropdown(
                      value: _to,
                      label: 'Ke',
                      onChanged: (value) => setState(() => _to = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: p.primary50,
                  borderRadius: AppRadius.mediumAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key: const ValueKey<String>('currency-result'),
                      converted == null
                          ? 'Kurs tidak tersedia'
                          : '${_from.symbol} ${CurrencyConverter.format(amount)} '
                              '= ${_to.symbol} ${CurrencyConverter.format(converted)}',
                      style: AppTypography.h2.copyWith(color: p.primary600),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      result.fromCache
                          ? '📦 Data offline — diperbarui '
                              '${snapshot.fetchedAt == 0 ? '(kurs bawaan)' : formatDateTime(snapshot.fetchedAt)}'
                          : '✓ Diperbarui ${formatDateTime(snapshot.fetchedAt)}',
                      key: const ValueKey<String>('rates-updated-at'),
                      style: AppTypography.caption.copyWith(color: p.neutral500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.grid),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(ratesProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Segarkan Kurs'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final Currency value;
  final String label;
  final ValueChanged<Currency?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Currency>(
          value: value,
          isExpanded: true,
          items: [
            for (final currency in Currency.values)
              DropdownMenuItem(
                value: currency,
                child: Text('${currency.code} · ${currency.label}'),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Konverter zona waktu (F-18, SCR-04): WIB, WITA, WIT, London (DST).
///
/// Konteks: jadwal book club, read-a-thon, atau rilis buku global.
class TimePanel extends ConsumerStatefulWidget {
  const TimePanel({super.key});

  @override
  ConsumerState<TimePanel> createState() => _TimePanelState();
}

class _TimePanelState extends ConsumerState<TimePanel> {
  /// Waktu acuan dilabeli WIB (sesuai kebutuhan pengguna Indonesia).
  late DateTime _reference = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final converted = WorldClock.convertAll(_reference);

    return StorylokaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zona Waktu', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.micro),
          Text(
            'Untuk jadwal book club, read-a-thon, dan rilis buku global.',
            style: AppTypography.body2.copyWith(color: p.neutral500),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          OutlinedButton.icon(
            key: const ValueKey<String>('pick-reference-time'),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(
              key: const ValueKey<String>('reference-label'),
              '${WorldClock.formatTanggal(_reference)} · '
              '${WorldClock.formatHm(_reference)} WIB',
            ),
            onPressed: _pickReference,
          ),
          const SizedBox(height: AppSpacing.cardGap),
          for (final zone in WorldZone.values) ...[
            _ZoneRow(zone: zone, time: converted[zone]!),
            if (zone != WorldZone.values.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Future<void> _pickReference() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reference,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reference),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _reference = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone, required this.time});

  final WorldZone zone;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isLondon = zone == WorldZone.london;
    final dst = isLondon && WorldClock.londonOffset(DateTime.now()) == const Duration(hours: 1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.grid),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.code, style: AppTypography.h3),
                Text(
                  isLondon
                      ? '${zone.label}${dst ? " (BST)" : " (GMT)"}'
                      : zone.label,
                  style: AppTypography.caption.copyWith(color: p.neutral500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                key: ValueKey<String>('zone-${zone.code}'),
                WorldClock.formatHm(time),
                style: AppTypography.h2.copyWith(color: p.primary600),
              ),
              Text(
                WorldClock.formatTanggal(time),
                style: AppTypography.caption.copyWith(color: p.neutral500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
