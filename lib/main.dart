// lib/main.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  log('Net.Simulation v4 starting', name: 'App');
  runApp(
    const ProviderScope(
      child: NetSimulationApp(),
    ),
  );
}
