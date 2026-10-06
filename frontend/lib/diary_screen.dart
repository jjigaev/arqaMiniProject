import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'diary_controller.dart';
import 'models.dart';
import 'theme.dart';
import 'trip_form.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.controller});
  final DiaryController controller;
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _scroll = ScrollController();
  late final SemanticsHandle _semantics;
  DiaryController get diary => widget.controller;
  @override
  void initState() {
    super.initState();
    _semantics = SemanticsBinding.instance.ensureSemantics();
    unawaited(diary.selectDate(diary.selectedDate));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _semantics.dispose();
    diary.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: diary.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Выберите день',
    );
    if (date != null && mounted) await diary.selectDate(date);
  }

  Future<void> _addTrip() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TripForm(controller: diary),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Поездка сохранена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _addButton() => FilledButton.icon(
    key: const Key('add-trip'),
    onPressed: _addTrip,
    icon: Icon(diary.pendingTrip == null ? Icons.add : Icons.replay),
    label: Text(
      diary.pendingTrip == null ? 'Добавить поездку' : 'Продолжить добавление',
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: diary,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        return Scaffold(
          bottomNavigationBar: narrow
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: _addButton(),
                  ),
                )
              : null,
          body: SafeArea(
            child: Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                  narrow ? 20 : 42,
                  narrow ? 22 : 32,
                  narrow ? 20 : 42,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: DiaryTheme.pageMax,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(narrow),
                        SizedBox(height: narrow ? 24 : 42),
                        _dayNavigation(narrow),
                        SizedBox(height: narrow ? 20 : 24),
                        if (diary.pendingTrip != null && !diary.saving) ...[
                          const _Notice(
                            icon: Icons.info_outline,
                            text:
                                'Сохранение поездки не подтверждено. Откройте форму и повторите отправку.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (diary.error != null) ...[
                          _Notice(
                            icon: Icons.cloud_off_outlined,
                            text: diary.error!,
                            action: OutlinedButton(
                              onPressed: diary.loading
                                  ? null
                                  : () => diary.selectDate(diary.selectedDate),
                              child: const Text('Повторить'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (diary.data != null) ...[
                          if (diary.loading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                semanticsLabel: 'Обновляем поездки',
                              ),
                            ),
                          _workspace(diary.data!, narrow),
                        ] else if (diary.loading)
                          const SizedBox(
                            height: 380,
                            child: Center(
                              child: CircularProgressIndicator(
                                semanticsLabel: 'Загружаем выбранный день',
                              ),
                            ),
                          )
                        else if (diary.error != null)
                          const SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                'Поездки появятся после восстановления связи.',
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          '₸ · Тенге     Время поездок: UTC+5',
                          style: TextStyle(
                            color: DiaryTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _header(bool narrow) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: DiaryTheme.coral,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.route_outlined,
          color: DiaryTheme.onCoral,
          size: 25,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дневник смен',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 3),
            Text(
              'Поездки. Доход. Всё под рукой.',
              style: TextStyle(fontSize: 12, color: DiaryTheme.muted),
            ),
          ],
        ),
      ),
      if (!narrow) ...[const SizedBox(width: 20), _addButton()],
    ],
  );

  Widget _dayNavigation(bool narrow) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 14,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE', 'ru').format(diary.selectedDate).toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: DiaryTheme.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: DateFormat('d MMMM', 'ru').format(diary.selectedDate),
                  style: TextStyle(
                    fontSize: narrow ? 32 : 42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ' ${diary.selectedDate.year}',
                  style: TextStyle(
                    fontSize: narrow ? 20 : 24,
                    color: DiaryTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('previous-day'),
            tooltip: 'Предыдущий день',
            onPressed: diary.selectedDate.isAfter(DateTime.utc(2000))
                ? () => diary.selectDate(
                    diary.selectedDate.subtract(const Duration(days: 1)),
                  )
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.calendar_today_outlined, size: 17),
            label: Text(narrow ? 'Календарь' : 'Выбрать день'),
          ),
          IconButton(
            key: const Key('next-day'),
            tooltip: 'Следующий день',
            onPressed: diary.selectedDate.isBefore(DateTime.utc(2100, 12, 31))
                ? () => diary.selectDate(
                    diary.selectedDate.add(const Duration(days: 1)),
                  )
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );

  Widget _workspace(DayData data, bool narrow) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summary(data, true),
          const SizedBox(height: 20),
          _tripList(data),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: constraints.maxWidth < 1000 ? 265 : 310,
            child: _summary(data, false),
          ),
          const SizedBox(width: 24),
          Expanded(child: _tripList(data)),
        ],
      ),
    );
  }

  Widget _money(Money value, double size, {Color? color}) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      '${value.display} ₸',
      style: DiaryTheme.number(size, color: color),
    ),
  );

  Widget _summary(DayData data, bool narrow) {
    final s = data.summary;
    final count = Intl.plural(
      s.count,
      locale: 'ru',
      one: '${s.count} поездка',
      few: '${s.count} поездки',
      many: '${s.count} поездок',
      other: '${s.count} поездок',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(narrow ? 20 : 28),
          decoration: BoxDecoration(
            color: DiaryTheme.incomeSurface,
            borderRadius: BorderRadius.circular(DiaryTheme.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'На руки за день',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: narrow ? 8 : 12),
              _money(s.net, narrow ? 50 : 52),
              const SizedBox(height: 8),
              const Text(
                'Ваш доход после комиссии',
                style: TextStyle(fontSize: 12),
              ),
              if (!narrow) ...[
                const SizedBox(height: 28),
                Text('$count за день', style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(narrow ? 20 : 24),
          decoration: BoxDecoration(
            color: DiaryTheme.surface,
            borderRadius: BorderRadius.circular(DiaryTheme.radius),
          ),
          child: Column(
            children: [
              if (narrow && s.revenue.minor < 100000000)
                Row(
                  children: [
                    Expanded(child: _metric('Выручка', s.revenue)),
                    const SizedBox(width: 16),
                    Expanded(child: _metric('Комиссия', s.commission)),
                  ],
                )
              else ...[
                _metric('Выручка', s.revenue, inline: !narrow),
                const SizedBox(height: 18),
                _metric('Комиссия', s.commission, inline: !narrow),
              ],
              Padding(
                padding: EdgeInsets.symmetric(vertical: narrow ? 12 : 18),
                child: const Divider(height: 1, color: DiaryTheme.border),
              ),
              _paymentMetric('Наличные', s.cash, DiaryTheme.cash),
              const SizedBox(height: 14),
              _paymentMetric('Карта', s.card, DiaryTheme.primary),
              SizedBox(height: narrow ? 12 : 18),
              Semantics(
                label:
                    'Соотношение выручки: наличные ${s.cash.display} тенге, карта ${s.card.display} тенге',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: s.revenue.minor == 0
                            ? [
                                const Expanded(
                                  child: ColoredBox(color: DiaryTheme.border),
                                ),
                              ]
                            : [
                                if (s.cash.minor > 0)
                                  Expanded(
                                    flex: s.cash.minor,
                                    child: const ColoredBox(
                                      color: DiaryTheme.coral,
                                    ),
                                  ),
                                if (s.card.minor > 0)
                                  Expanded(
                                    flex: s.card.minor,
                                    child: const ColoredBox(
                                      color: DiaryTheme.primary,
                                    ),
                                  ),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Разбивка выручки по оплате',
                style: TextStyle(fontSize: 11, color: DiaryTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, Money value, {bool inline = false}) {
    if (inline && value.minor < 100000000) {
      return Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: DiaryTheme.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _money(value, 23),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: DiaryTheme.muted),
        ),
        const SizedBox(height: 4),
        _money(value, 23),
      ],
    );
  }

  Widget _paymentMetric(String label, Money value, Color color) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 12),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: _money(value, 18),
        ),
      ),
    ],
  );
  String _time(DateTime instant) =>
      DateFormat('HH:mm').format(diaryTime(instant));
  String _range(List<Trip> trips) {
    var end = trips.first.end;
    for (final trip in trips.skip(1)) {
      if (trip.end.isAfter(end)) end = trip.end;
    }
    final days = diaryDate(end).difference(diaryDate(trips.first.start)).inDays;
    return '${_time(trips.first.start)} — ${_time(end)}${days > 0 ? ' (+$days д.)' : ''}';
  }

  Widget _tripList(DayData data) => LayoutBuilder(
    builder: (context, constraints) {
      final table =
          constraints.maxWidth >= 640 &&
          data.trips.every((trip) => trip.amount.minor < 100000000);
      return Container(
        decoration: BoxDecoration(
          color: DiaryTheme.surface,
          borderRadius: BorderRadius.circular(DiaryTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ВАШ ДЕНЬ В ДЕТАЛЯХ',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: DiaryTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Поездки',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: DiaryTheme.cardSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${data.trips.length}',
                              style: DiaryTheme.number(
                                14,
                                color: DiaryTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (data.trips.isNotEmpty)
                        Text(
                          _range(data.trips),
                          style: const TextStyle(
                            fontSize: 12,
                            color: DiaryTheme.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (data.trips.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      size: 40,
                      color: DiaryTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'В этот день поездок пока нет',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Добавьте поездку — итоги рассчитаются автоматически.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _addTrip,
                      child: const Text('Добавить поездку'),
                    ),
                  ],
                ),
              )
            else ...[
              if (table)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: _columns(
                    ['Время поездки', 'Оплата', 'Сумма', 'Комиссия', 'На руки']
                        .map(
                          (label) => Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: DiaryTheme.muted,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              for (final trip in data.trips) ...[
                const Divider(
                  height: 1,
                  indent: 24,
                  endIndent: 24,
                  color: DiaryTheme.border,
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _tripRow(trip, table),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
  Widget _columns(List<Widget> children) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(flex: 17, child: children[0]),
      const SizedBox(width: 12),
      Expanded(
        flex: 12,
        child: Align(alignment: Alignment.centerLeft, child: children[1]),
      ),
      const SizedBox(width: 12),
      for (var i = 2; i < children.length; i++) ...[
        Expanded(
          flex: 13,
          child: Align(alignment: Alignment.centerRight, child: children[i]),
        ),
        if (i < children.length - 1) const SizedBox(width: 12),
      ],
    ],
  );
  Widget _tripRow(Trip trip, bool table) {
    final cash = trip.payment == 'cash';
    final payment = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cash ? DiaryTheme.cashSurface : DiaryTheme.cardSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        cash ? 'Наличные' : 'Карта',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cash ? DiaryTheme.cash : DiaryTheme.primary,
        ),
      ),
    );
    final differentDay =
        dateKey(diaryDate(trip.start)) != dateKey(diaryDate(trip.end));
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_time(trip.start)} — ${_time(trip.end)}',
          style: DiaryTheme.number(table ? 14 : 16),
        ),
        const SizedBox(height: 4),
        Text(
          '${trip.minutes < 1 ? '<1' : trip.minutes} мин',
          style: const TextStyle(fontSize: 11, color: DiaryTheme.muted),
        ),
        if (differentDay)
          Text(
            'до ${DateFormat('dd/MM/yyyy').format(diaryTime(trip.end))}',
            style: const TextStyle(fontSize: 11, color: DiaryTheme.muted),
          ),
      ],
    );
    final net = trip.net;
    if (table) {
      return _columns([
        time,
        payment,
        _money(trip.amount, 16),
        _money(trip.commission, 14, color: DiaryTheme.muted),
        _money(net, 17, color: DiaryTheme.primary),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: time),
            const SizedBox(width: 8),
            payment,
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final amounts = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сумма ${trip.amount.display} ₸',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Комиссия ${trip.commission.display} ₸',
                  style: const TextStyle(fontSize: 11, color: DiaryTheme.muted),
                ),
              ],
            );
            final income = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'На руки',
                  style: TextStyle(fontSize: 11, color: DiaryTheme.muted),
                ),
                const SizedBox(height: 3),
                _money(net, 20, color: DiaryTheme.primary),
              ],
            );
            // Large legal amounts retain readable text instead of two squeezed columns.
            if (constraints.maxWidth < 260 || trip.amount.minor >= 100000000) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  amounts,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: income),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 3, child: amounts),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: income),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiaryTheme.surface,
        border: Border.all(color: DiaryTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: DiaryTheme.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
