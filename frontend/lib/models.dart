/// Exact money in integer minor units. Never use double for amounts.
class Money {
  const Money(this.minor);
  final int minor;

  static Money parse(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(
      r'^(\d{1,10})(?:\.(\d{1,2}))?$',
    ).firstMatch(normalized);
    if (match == null) {
      throw const FormatException('Введите сумму с точностью до двух знаков');
    }
    final minor =
        int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '').padRight(2, '0'));
    if (minor > 999999999999) {
      throw const FormatException('Сумма слишком большая');
    }
    return Money(minor);
  }

  factory Money.fromApi(String value) {
    // Totals may be larger than a single trip; still stay within JS safe integers.
    final match = RegExp(r'^(\d+)\.(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Некорректная сумма в ответе сервера');
    }
    final minor = int.parse(match[1]!) * 100 + int.parse(match[2]!);
    if (minor > 9007199254740991) {
      throw const FormatException('Итоговая сумма слишком большая');
    }
    return Money(minor);
  }

  String get api =>
      '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
  String get display {
    final whole = (minor ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '\u00a0',
    );
    final fraction = minor % 100 == 0
        ? ''
        : ',${(minor % 100).toString().padLeft(2, '0')}';
    return '$whole$fraction';
  }
}

DateTime diaryTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 5));
DateTime diaryDate(DateTime instant) {
  final wall = diaryTime(instant);
  return DateTime.utc(wall.year, wall.month, wall.day);
}

String dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class Trip {
  Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.commission,
    required this.payment,
  });
  final String id;
  final DateTime start, end;
  final Money amount, commission;
  final String payment;
  int get minutes => end.difference(start).inMinutes;
  Money get net => Money(amount.minor - commission.minor);
  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    amount: Money.fromApi(json['amount'] as String),
    commission: Money.fromApi(json['commission'] as String),
    payment: json['payment'] as String,
  );
}

class DaySummary {
  DaySummary({
    required this.count,
    required this.revenue,
    required this.commission,
    required this.net,
    required this.cash,
    required this.card,
  });
  final int count;
  final Money revenue, commission, net, cash, card;
  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
    count: json['trip_count'] as int,
    revenue: Money.fromApi(json['revenue'] as String),
    commission: Money.fromApi(json['commission'] as String),
    net: Money.fromApi(json['net'] as String),
    cash: Money.fromApi(json['cash'] as String),
    card: Money.fromApi(json['card'] as String),
  );
}

class DayData {
  DayData({required this.date, required this.summary, required this.trips});
  final DateTime date;
  final DaySummary summary;
  final List<Trip> trips;
  factory DayData.fromJson(Map<String, dynamic> json) {
    if (json['timezone'] != 'Asia/Qyzylorda' || json['currency'] != 'KZT') {
      throw const FormatException('Неподдерживаемая валюта или часовой пояс');
    }
    return DayData(
      date: DateTime.parse('${json['date']}T00:00:00Z'),
      summary: DaySummary.fromJson(json['summary'] as Map<String, dynamic>),
      trips: (json['trips'] as List)
          .map((trip) => Trip.fromJson(trip as Map<String, dynamic>))
          .toList(),
    );
  }
}
