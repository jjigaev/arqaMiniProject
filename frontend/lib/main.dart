import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'api.dart';
import 'diary_controller.dart';
import 'diary_screen.dart';
import 'models.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  DateTime? initial;
  final query = Uri.base.queryParameters['date'];
  if (query != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(query)) {
    final candidate = DateTime.tryParse('${query}T00:00:00Z');
    if (candidate != null &&
        candidate.year >= 2000 &&
        candidate.year <= 2100 &&
        dateKey(candidate) == query) {
      initial = candidate;
    }
  }
  runApp(
    DiaryApp(controller: DiaryController(DiaryApi(), initialDate: initial)),
  );
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key, required this.controller});
  final DiaryController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Дневник смен водителя',
    debugShowCheckedModeBanner: false,
    theme: DiaryTheme.data,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: DiaryScreen(controller: controller),
  );
}
