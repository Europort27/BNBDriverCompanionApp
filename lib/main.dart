import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';

/// Initialises the app's dependencies, then starts the UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  final dependencies = AppDependencies.create();
  await dependencies.settings.load();
  await dependencies.scanner.init();

  runApp(BnbDriverApp(dependencies: dependencies));
}
