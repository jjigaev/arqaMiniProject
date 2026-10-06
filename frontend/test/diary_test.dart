import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shift_diary/api.dart';
import 'package:shift_diary/diary_controller.dart';
import 'package:shift_diary/main.dart';
import 'package:shift_diary/models.dart';
import 'package:shift_diary/trip_form.dart';

DayData emptyDay(DateTime date) => DayData(
  date: date,
  summary: DaySummary(
    count: 0,
    revenue: const Money(0),
    commission: const Money(0),
    net: const Money(0),
    cash: const Money(0),
    card: const Money(0),
  ),
  trips: [],
);

class FakeRepository implements DiaryRepository {
  Future<DayData> Function(DateTime)? load;
  final sent = <Map<String, dynamic>>[];
  bool failOnce = false;
  @override
  Future<DayData> getDay(DateTime day) =>
      load?.call(day) ?? Future.value(emptyDay(day));
  @override
  Future<Trip> createTrip(Map<String, dynamic> payload) async {
    sent.add(Map.of(payload));
    if (failOnce && sent.length == 1) {
      throw const ApiException('Ответ не получен', uncertain: true);
    }
    return Trip.fromJson(payload);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  test('money input accepts decimals and rejects malformed typing/pastes', () {
    final formatter = MoneyInputFormatter();
    const old = TextEditingValue(text: '1250');
    for (final text in [
      '1250a',
      '1 250',
      '-5',
      '1e3',
      '12.345',
      '1,2.3',
      '123\n',
      '10000000000',
    ]) {
      expect(
        formatter.formatEditUpdate(old, TextEditingValue(text: text)),
        old,
      );
    }
    for (final text in ['', '0', '1250.', '1250,50', '1250.50']) {
      final next = TextEditingValue(text: text);
      expect(formatter.formatEditUpdate(old, next), next);
    }
  });
  test('money stays exact and formats fractions', () {
    expect(Money.parse('0,10').minor + Money.parse('0.20').minor, 30);
    expect(Money.parse('2400.05').api, '2400.05');
    expect(Money.parse('2400.05').display, '2\u00a0400,05');
    expect(() => Money.parse('10.001'), throwsFormatException);
    expect(() => Money.parse('-1'), throwsFormatException);
  });
  test('business date uses UTC+5 independently of browser timezone', () {
    expect(
      dateKey(diaryDate(DateTime.parse('2026-09-30T19:00:00Z'))),
      '2026-10-01',
    );
    expect(
      dateKey(diaryDate(DateTime.parse('2026-10-01T18:59:59Z'))),
      '2026-10-01',
    );
  });
  test('late response cannot replace the new date', () async {
    final old = Completer<DayData>(), next = Completer<DayData>();
    final repository = FakeRepository()
      ..load = (date) => date.day == 1 ? old.future : next.future;
    final controller = DiaryController(repository);
    final firstRequest = controller.selectDate(DateTime.utc(2026, 10, 1));
    final nextRequest = controller.selectDate(DateTime.utc(2026, 10, 2));
    next.complete(emptyDay(DateTime.utc(2026, 10, 2)));
    await nextRequest;
    old.complete(emptyDay(DateTime.utc(2026, 10, 1)));
    await firstRequest;
    expect(controller.data!.date.day, 2);
    expect(controller.loading, false);
    controller.dispose();
  });
  test('uncertain retry freezes identity and payload', () async {
    final repository = FakeRepository()..failOnce = true;
    final controller = DiaryController(repository, makeId: () => 'fixed-id');
    final fields = <String, dynamic>{
      'start': '2026-10-01T03:10:00Z',
      'end': '2026-10-01T03:32:00Z',
      'amount': '2400.00',
      'commission': '360.00',
      'payment': 'card',
    };
    expect(await controller.saveTrip(fields), false);
    expect(controller.pendingTrip!['id'], 'fixed-id');
    expect(await controller.saveTrip({...fields, 'amount': '9999.00'}), true);
    expect(repository.sent[1], repository.sent[0]);
    expect(controller.pendingTrip, null);
    expect(dateKey(controller.selectedDate), '2026-10-01');
    controller.dispose();
  });
  test('HTTP 200 replay is successful creation', () async {
    final payload = <String, dynamic>{
      'id': 'fixed-id',
      'start': '2026-10-01T03:10:00Z',
      'end': '2026-10-01T03:32:00Z',
      'amount': '2400.00',
      'commission': '360.00',
      'payment': 'card',
    };
    final api = DiaryApi(
      client: MockClient((_) async => http.Response(jsonEncode(payload), 200)),
    );
    expect((await api.createTrip(payload)).id, 'fixed-id');
  });
  testWidgets('cold API can answer after the normal timeout', (tester) async {
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    addTearDown(client.close);
    final api = DiaryApi(
      client: client,
      readTimeout: const Duration(seconds: 90),
    );
    var completed = false;
    final request = api.getDay(DateTime.utc(2026, 10, 1)).then((day) {
      completed = true;
      return day;
    });
    await tester.pump(const Duration(seconds: 60));
    expect(completed, false);
    response.complete(
      http.Response(
        jsonEncode({
          'date': '2026-10-01',
          'timezone': 'Asia/Qyzylorda',
          'currency': 'KZT',
          'summary': {
            'trip_count': 0,
            'revenue': '0.00',
            'commission': '0.00',
            'net': '0.00',
            'cash': '0.00',
            'card': '0.00',
          },
          'trips': [],
        }),
        200,
      ),
    );
    await tester.pump();
    expect((await request).summary.count, 0);
  });
  testWidgets(
    'read timeout is bounded and POST stays uncertain at 15 seconds',
    (tester) async {
      final client = MockClient((_) => Completer<http.Response>().future);
      addTearDown(client.close);
      final api = DiaryApi(
        client: client,
        readTimeout: const Duration(seconds: 90),
      );
      final read = expectLater(
        api.getDay(DateTime.utc(2026, 10, 1)),
        throwsA(
          isA<ApiException>().having((e) => e.uncertain, 'uncertain', false),
        ),
      );
      var writeFailed = false;
      final write = expectLater(
        api
            .createTrip({'id': 'pending'})
            .whenComplete(() => writeFailed = true),
        throwsA(
          isA<ApiException>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
      await tester.pump(const Duration(seconds: 16));
      await write;
      expect(writeFailed, true);
      await tester.pump(const Duration(seconds: 75));
      await read;
    },
  );
  testWidgets('day navigation and empty state are visible', (tester) async {
    final controller = DiaryController(FakeRepository());
    await tester.pumpWidget(DiaryApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('В этот день поездок пока нет'), findsOneWidget);
    await tester.tap(find.byKey(const Key('previous-day')));
    await tester.pumpAndSettle();
    expect(find.text('1 октября 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('form validates and saves through controller', (tester) async {
    final repository = FakeRepository();
    await tester.pumpWidget(DiaryApp(controller: DiaryController(repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-trip')));
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('save-trip'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Введите сумму с точностью до двух знаков'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('trip-amount')), '1500,50');
    await tester.enterText(find.byKey(const Key('trip-commission')), '225,05');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.sent.single['amount'], '1500.50');
    expect(repository.sent.single['start'], '2026-10-02T03:00:00.000Z');
    expect(find.text('Поездка сохранена'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('calendar and precise 24-hour time save an overnight trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeRepository();
    await tester.pumpWidget(DiaryApp(controller: DiaryController(repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-trip')));
    await tester.pumpAndSettle();
    expect(find.text('02/10/2026'), findsNWidgets(2));

    Future<void> pickTime(String key, String hour, String minute) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), hour);
      await tester.enterText(fields.at(1), minute);
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
    }

    await pickTime('trip-start-time', '23', '57');
    await tester.enterText(find.byKey(const Key('trip-amount')), '1250,50');
    await tester.enterText(find.byKey(const Key('trip-amount')), 'abc');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('trip-amount')))
          .controller!
          .text,
      '1250,50',
    );
    await tester.enterText(find.byKey(const Key('trip-commission')), '187.58');
    await tester.enterText(find.byKey(const Key('trip-commission')), '-10');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('trip-commission')))
          .controller!
          .text,
      '187.58',
    );
    final save = find.byKey(const Key('save-trip'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Окончание должно быть позже начала'), findsOneWidget);
    expect(repository.sent, isEmpty);

    final endDate = find.byKey(const Key('trip-end-date'));
    await tester.ensureVisible(endDate);
    await tester.tap(endDate);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('3', skipOffstage: true));
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();
    expect(find.text('03/10/2026'), findsOneWidget);
    await pickTime('trip-end-time', '00', '06');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.sent.single['start'], '2026-10-02T18:57:00.000Z');
    expect(repository.sent.single['end'], '2026-10-02T19:06:00.000Z');
    expect(repository.sent.single['amount'], '1250.50');
    expect(repository.sent.single['commission'], '187.58');
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow view has no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeRepository()
      ..load = (day) async => DayData(
        date: day,
        summary: DaySummary(
          count: 1,
          revenue: const Money(310000),
          commission: const Money(46500),
          net: const Money(263500),
          cash: const Money(0),
          card: const Money(310000),
        ),
        trips: [
          Trip(
            id: 'overnight',
            start: DateTime.parse('2026-10-02T18:50:00Z'),
            end: DateTime.parse('2026-10-02T19:15:00Z'),
            amount: const Money(310000),
            commission: const Money(46500),
            payment: 'card',
          ),
        ],
      );
    await tester.pumpWidget(DiaryApp(controller: DiaryController(repository)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('add-trip')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading failure keeps a working retry', (tester) async {
    var attempts = 0;
    final repository = FakeRepository()
      ..load = (day) async {
        if (++attempts == 1) throw const ApiException('Нет связи с сервером');
        return emptyDay(day);
      };
    await tester.pumpWidget(DiaryApp(controller: DiaryController(repository)));
    await tester.pumpAndSettle();
    expect(find.text('Нет связи с сервером'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('В этот день поездок пока нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets('full large amounts and actions remain usable at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeRepository()
        ..load = (day) async => DayData(
          date: day,
          summary: DaySummary(
            count: 1,
            revenue: Money.parse('9999999999.99'),
            commission: Money.parse('1234567890.12'),
            net: Money.parse('8765432109.87'),
            cash: Money.parse('9999999999.99'),
            card: const Money(0),
          ),
          trips: [
            Trip(
              id: 'large-overnight',
              start: DateTime.parse('2026-10-02T18:50:00Z'),
              end: DateTime.parse('2026-10-02T19:15:00Z'),
              amount: Money.parse('9999999999.99'),
              commission: Money.parse('1234567890.12'),
              payment: 'cash',
            ),
          ],
        );
      await tester.pumpWidget(
        DiaryApp(controller: DiaryController(repository)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('23:50 — 00:15 (+1 д.)'), findsOneWidget);
      expect(find.text('до 03/10/2026'), findsOneWidget);
      expect(
        find.text('Сумма 9\u00a0999\u00a0999\u00a0999,99 ₸'),
        findsOneWidget,
      );
      expect(
        find.text('Комиссия 1\u00a0234\u00a0567\u00a0890,12 ₸'),
        findsOneWidget,
      );
      final add = find.byKey(const Key('add-trip'));
      expect(add, findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Новая поездка'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('day range uses the latest end even when trips overlap', (
    tester,
  ) async {
    final repository = FakeRepository()
      ..load = (day) async => DayData(
        date: day,
        summary: emptyDay(day).summary,
        trips: [
          Trip(
            id: 'long',
            start: DateTime.parse('2026-10-02T03:00:00Z'),
            end: DateTime.parse('2026-10-03T05:00:00Z'),
            amount: const Money(10000),
            commission: const Money(1000),
            payment: 'cash',
          ),
          Trip(
            id: 'short',
            start: DateTime.parse('2026-10-02T04:00:00Z'),
            end: DateTime.parse('2026-10-02T04:30:00Z'),
            amount: const Money(20000),
            commission: const Money(2000),
            payment: 'card',
          ),
        ],
      );
    await tester.pumpWidget(DiaryApp(controller: DiaryController(repository)));
    await tester.pumpAndSettle();
    expect(find.text('08:00 — 10:00 (+1 д.)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
