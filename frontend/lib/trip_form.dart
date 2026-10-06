import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'diary_controller.dart';
import 'models.dart';
import 'theme.dart';

/// Reject invalid edits/pastes as a whole rather than silently changing money.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      RegExp(r'^[0-9]{0,10}([.,][0-9]{0,2})?$').stringMatch(newValue.text) ==
          newValue.text
      ? newValue
      : oldValue;
}

class TripForm extends StatefulWidget {
  const TripForm({super.key, required this.controller});
  final DiaryController controller;
  @override
  State<TripForm> createState() => _TripFormState();
}

class _TripFormState extends State<TripForm> {
  final _form = GlobalKey<FormState>();
  late DateTime _start, _end;
  final _amount = TextEditingController(),
      _commission = TextEditingController();
  final _focus = List.generate(3, (_) => FocusNode());
  String _payment = 'card';
  bool _dirty = false, _allowClose = false, _submitted = false;
  DiaryController get diary => widget.controller;

  @override
  void initState() {
    super.initState();
    final pending = diary.pendingTrip;
    final day = diary.selectedDate;
    _start = pending == null
        ? DateTime.utc(day.year, day.month, day.day, 8)
        : diaryTime(DateTime.parse(pending['start'] as String));
    _end = pending == null
        ? DateTime.utc(day.year, day.month, day.day, 8, 25)
        : diaryTime(DateTime.parse(pending['end'] as String));
    _amount.text = pending?['amount'] as String? ?? '';
    _commission.text = pending?['commission'] as String? ?? '';
    _payment = pending?['payment'] as String? ?? 'card';
  }

  @override
  void dispose() {
    for (final field in [_amount, _commission]) {
      field.dispose();
    }
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  String? _validateEnd() =>
      _end.isAfter(_start) ? null : 'Окончание должно быть позже начала';

  Future<void> _pickDate(bool start) async {
    final value = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: start ? 'Дата начала' : 'Дата окончания',
    );
    if (date == null || !mounted) return;
    _changeTime(
      start,
      DateTime.utc(date.year, date.month, date.day, value.hour, value.minute),
    );
  }

  Future<void> _pickTime(bool start) async {
    final value = start ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: start ? 'Время начала' : 'Время окончания',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    _changeTime(
      start,
      DateTime.utc(value.year, value.month, value.day, time.hour, time.minute),
    );
  }

  void _changeTime(bool start, DateTime value) {
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
      _dirty = true;
    });
    if (_submitted) _form.currentState!.validate();
  }

  String? _validateAmount(String? value) {
    try {
      if (Money.parse(value ?? '').minor <= 0) {
        return 'Сумма должна быть больше нуля';
      }
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String? _validateCommission(String? value) {
    try {
      final commission = Money.parse(value ?? '');
      final amount = Money.parse(_amount.text);
      if (commission.minor > amount.minor) {
        return 'Комиссия не может превышать сумму';
      }
      return null;
    } on FormatException {
      return 'Введите комиссию от 0 до суммы поездки';
    }
  }

  Future<void> _close() async {
    if (diary.saving) return;
    if (_dirty && diary.pendingTrip == null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Закрыть форму?'),
          content: const Text('Введённая поездка ещё не сохранена.'),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Продолжить ввод'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Закрыть форму'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) {
      setState(() => _allowClose = true);
      Navigator.pop(context, false);
    }
  }

  Future<void> _save() async {
    _submitted = true;
    if (diary.pendingTrip == null && !_form.currentState!.validate()) {
      final failures = [
        _validateEnd(),
        _validateAmount(_amount.text),
        _validateCommission(_commission.text),
      ];
      _focus[failures.indexWhere((failure) => failure != null)].requestFocus();
      return;
    }
    final fields =
        diary.pendingTrip ??
        {
          'start': _start.subtract(const Duration(hours: 5)).toIso8601String(),
          'end': _end.subtract(const Duration(hours: 5)).toIso8601String(),
          'amount': Money.parse(_amount.text).api,
          'commission': Money.parse(_commission.text).api,
          'payment': _payment,
        };
    final saved = await diary.saveTrip(fields);
    if (saved && mounted) {
      setState(() => _allowClose = true);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: diary,
    builder: (context, _) {
      final locked = diary.pendingTrip != null;
      return PopScope(
        canPop: _allowClose,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DiaryTheme.radius),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ВАШ ЖУРНАЛ',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: DiaryTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Новая поездка',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть форму',
                          onPressed: diary.saving ? null : _close,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Время UTC+5. Комиссия вводится суммой в тенге.',
                      style: TextStyle(color: DiaryTheme.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _dateTimeRow('Начало поездки', true, locked),
                    const SizedBox(height: 18),
                    _dateTimeRow('Окончание поездки', false, locked),
                    const SizedBox(height: 18),
                    _field(
                      'Сумма, ₸',
                      'trip-amount',
                      _amount,
                      _focus[1],
                      _validateAmount,
                      locked,
                    ),
                    const SizedBox(height: 18),
                    _field(
                      'Комиссия, ₸',
                      'trip-commission',
                      _commission,
                      _focus[2],
                      _validateCommission,
                      locked,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Способ оплаты',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'card',
                          label: Text('Карта'),
                          icon: Icon(Icons.credit_card_outlined),
                        ),
                        ButtonSegment(
                          value: 'cash',
                          label: Text('Наличные'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                      ],
                      selected: {_payment},
                      onSelectionChanged: locked
                          ? null
                          : (selection) => setState(() {
                              _payment = selection.first;
                              _dirty = true;
                            }),
                    ),
                    if (diary.saveError != null) ...[
                      const SizedBox(height: 18),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          diary.saveError!,
                          style: const TextStyle(color: DiaryTheme.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    FilledButton(
                      key: const Key('save-trip'),
                      onPressed: diary.saving ? null : _save,
                      child: SizedBox(
                        height: 20,
                        child: diary.saving
                            ? const SizedBox(
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DiaryTheme.surface,
                                  semanticsLabel: 'Сохраняем поездку',
                                ),
                              )
                            : Text(
                                locked
                                    ? 'Повторить отправку'
                                    : 'Сохранить поездку',
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: diary.saving ? null : _close,
                      child: Text(
                        locked ? 'Закрыть и повторить позже' : 'Отмена',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _dateTimeRow(String label, bool start, bool locked) {
    final value = start ? _start : _end;
    final prefix = start ? 'trip-start' : 'trip-end';
    return FormField<DateTime>(
      validator: (_) => start ? null : _validateEnd(),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final date = OutlinedButton.icon(
                key: Key('$prefix-date'),
                onPressed: locked ? null : () => _pickDate(start),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Semantics(
                  label: start ? 'Дата начала' : 'Дата окончания',
                  child: Text(DateFormat('dd/MM/yyyy').format(value)),
                ),
              );
              final time = OutlinedButton.icon(
                key: Key('$prefix-time'),
                focusNode: start ? null : _focus[0],
                onPressed: locked ? null : () => _pickTime(start),
                icon: const Icon(Icons.schedule, size: 18),
                label: Semantics(
                  label: start ? 'Время начала' : 'Время окончания',
                  child: Text(DateFormat('HH:mm').format(value)),
                ),
              );
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [date, const SizedBox(height: 8), time],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: date),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: time),
                ],
              );
            },
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Text(
              field.errorText!,
              style: const TextStyle(color: DiaryTheme.danger, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    String label,
    String key,
    TextEditingController field,
    FocusNode focus,
    String? Function(String?) validator,
    bool locked,
  ) => TextFormField(
    key: Key(key),
    controller: field,
    focusNode: focus,
    readOnly: locked,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [MoneyInputFormatter()],
    validator: validator,
    onChanged: (_) => _dirty = true,
    decoration: InputDecoration(labelText: label, hintText: '0,00'),
  );
}
