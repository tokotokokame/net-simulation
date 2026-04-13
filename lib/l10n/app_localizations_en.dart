// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Net.Simulation';

  @override
  String get startSimulation => 'Start Simulation';

  @override
  String get stopSimulation => 'Stop Simulation';

  @override
  String get pauseSimulation => 'Pause Simulation';

  @override
  String get pausedSimulation => 'Paused';

  @override
  String demoTimerLabel(int minutes) {
    return 'Demo: ${minutes}m remaining';
  }

  @override
  String get upgradeToProTitle => 'Upgrade to Pro';

  @override
  String get upgradeToProMessage =>
      'Your free demo session has ended. Upgrade to Pro or register to continue.';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get registerFree => 'Register Free';

  @override
  String get addDevice => 'Add Device';

  @override
  String get deviceSettings => 'Device Settings';

  @override
  String get interfaces => 'Interfaces';

  @override
  String get routing => 'Routing';

  @override
  String get security => 'Security';

  @override
  String get cli => 'CLI';

  @override
  String get statistics => 'Statistics';

  @override
  String get packetSuccessRate => 'Packet Success Rate';

  @override
  String get averageLatency => 'Average Latency';

  @override
  String get bandwidthUtilization => 'Bandwidth Utilization';

  @override
  String get packetLossRate => 'Packet Loss Rate';

  @override
  String get simulateLinkFailure => 'Simulate Link Failure';

  @override
  String get restoreLink => 'Restore Link';

  @override
  String get simulateDeviceCrash => 'Simulate Device Crash';

  @override
  String get restoreDevice => 'Restore Device';

  @override
  String get connectionMode => 'Connection Mode';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get connect => 'Connect';

  @override
  String get totalPackets => 'Total';

  @override
  String get deliveredPackets => 'Delivered';

  @override
  String get droppedPackets => 'Dropped';

  @override
  String get noDevices =>
      'No devices — drag a device from the palette to begin';
}
