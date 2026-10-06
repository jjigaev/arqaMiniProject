import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';
import 'models.dart';

class DiaryController extends ChangeNotifier {
  DiaryController(
    this.repository, {
    DateTime? initialDate,
    String Function()? makeId,
  }) : selectedDate = initialDate ?? DateTime.utc(2026, 10, 2),
       _makeId = makeId ?? const Uuid().v4;
  final DiaryRepository repository;
  final String Function() _makeId;
  DateTime selectedDate;
  DayData? data;
  bool loading = false, saving = false;
  String? error, saveError;
  Map<String, dynamic>? pendingTrip;
  int _request = 0;
  bool _disposed = false;

  Future<void> selectDate(DateTime day) async {
    if (_disposed) return;
    final token = ++_request;
    if (dateKey(day) != dateKey(selectedDate)) data = null;
    selectedDate = DateTime.utc(day.year, day.month, day.day);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.getDay(selectedDate);
      if (_disposed || token != _request) return;
      data = result;
    } on Object catch (failure) {
      if (_disposed || token != _request) return;
      error = failure is ApiException
          ? failure.message
          : 'Не удалось загрузить поездки. Повторите попытку.';
    } finally {
      if (!_disposed && token == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> saveTrip(Map<String, dynamic> fields) async {
    if (saving || _disposed) return false;
    // Freeze both identity and fields while the server outcome is uncertain.
    pendingTrip ??= Map.unmodifiable({'id': _makeId(), ...fields});
    final payload = pendingTrip!;
    saving = true;
    saveError = null;
    notifyListeners();
    try {
      final trip = await repository.createTrip(payload);
      if (_disposed) return true;
      pendingTrip = null;
      await selectDate(diaryDate(trip.start));
      return true;
    } on Object catch (failure) {
      if (_disposed) return false;
      final uncertain = failure is! ApiException || failure.uncertain;
      if (!uncertain) pendingTrip = null;
      saveError = failure is ApiException
          ? failure.message
          : 'Сохранение не подтверждено. Повторите ту же отправку.';
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
