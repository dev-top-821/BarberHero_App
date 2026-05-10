import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';

/// Weekly working-hours editor. One row per day with a toggle + start/end
/// time pickers. Save replaces all slots atomically via PUT /barber/availability.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

// Monday-first ordering, matching how slots are shown elsewhere in the app.
const _days = <String>[
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];
const _dayLabels = <String, String>{
  'MONDAY': 'Monday',
  'TUESDAY': 'Tuesday',
  'WEDNESDAY': 'Wednesday',
  'THURSDAY': 'Thursday',
  'FRIDAY': 'Friday',
  'SATURDAY': 'Saturday',
  'SUNDAY': 'Sunday',
};

class _DayState {
  bool isActive;
  TimeOfDay start;
  TimeOfDay end;
  _DayState({required this.isActive, required this.start, required this.end});
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _loadError;

  final Map<String, _DayState> _state = {
    for (final d in _days)
      d: _DayState(
        isActive: false,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 0),
      ),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final slots = await api.getMyAvailability();
      for (final slot in slots) {
        final day = slot.dayOfWeek;
        if (!_state.containsKey(day)) continue;
        _state[day] = _DayState(
          isActive: slot.isActive,
          start: _parse(slot.startTime),
          end: _parse(slot.endTime),
        );
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load your hours.';
      });
    }
  }

  Future<void> _save() async {
    // Basic validation: for active days, end must be after start.
    for (final entry in _state.entries) {
      final s = entry.value;
      if (!s.isActive) continue;
      if (_toMinutes(s.end) <= _toMinutes(s.start)) {
        setState(() => _error =
            'On ${_dayLabels[entry.key]}, end time must be after start time.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);

    final payload = _days.map((d) {
      final s = _state[d]!;
      return {
        'dayOfWeek': d,
        'startTime': _formatSlot(s.start),
        'endTime': _formatSlot(s.end),
        'isActive': s.isActive,
      };
    }).toList();

    try {
      await api.setAvailability(payload);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Working hours saved.')));
      setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  Future<void> _pickTime(String day, bool isStart) async {
    final current = isStart ? _state[day]!.start : _state[day]!.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _state[day]!.start = picked;
      } else {
        _state[day]!.end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Working Hours')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(message: _loadError!, onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _InfoCard(),
              const SizedBox(height: 16),
              ..._days.map(_dayRow),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayRow(String day) {
    final s = _state[day]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dayLabels[day]!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: s.isActive,
                onChanged: (v) => setState(() => s.isActive = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (s.isActive) ...[
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TimePickerTile(
                    label: 'Start',
                    value: s.start,
                    onTap: () => _pickTime(day, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePickerTile(
                    label: 'End',
                    value: s.end,
                    onTap: () => _pickTime(day, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ───

  TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  String _formatSlot(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.schedule_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Customers can book you only during the hours you enable.",
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
