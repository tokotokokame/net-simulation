// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Net.Simulation';

  @override
  String get startSimulation => 'シミュレーション開始';

  @override
  String get stopSimulation => 'シミュレーション停止';

  @override
  String get pauseSimulation => 'シミュレーション一時停止';

  @override
  String get pausedSimulation => '一時停止中';

  @override
  String demoTimerLabel(int minutes) {
    return 'デモ: 残り$minutes分';
  }

  @override
  String get upgradeToProTitle => 'プロにアップグレード';

  @override
  String get upgradeToProMessage =>
      '無料デモセッションが終了しました。プロにアップグレードするか、無料登録して続行してください。';

  @override
  String get upgradeToPro => 'プロにアップグレード';

  @override
  String get registerFree => '無料登録して続行';

  @override
  String get addDevice => 'デバイス追加';

  @override
  String get deviceSettings => 'デバイス設定';

  @override
  String get interfaces => 'インターフェース';

  @override
  String get routing => 'ルーティング';

  @override
  String get security => 'セキュリティ';

  @override
  String get cli => 'CLI';

  @override
  String get statistics => '統計';

  @override
  String get packetSuccessRate => 'パケット成功率';

  @override
  String get averageLatency => '平均レイテンシ';

  @override
  String get bandwidthUtilization => '帯域幅使用率';

  @override
  String get packetLossRate => 'パケットロス率';

  @override
  String get simulateLinkFailure => 'リンク障害をシミュレート';

  @override
  String get restoreLink => 'リンクを復旧';

  @override
  String get simulateDeviceCrash => 'デバイスクラッシュをシミュレート';

  @override
  String get restoreDevice => 'デバイスを復旧';

  @override
  String get connectionMode => '接続モード';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get connect => '接続';

  @override
  String get totalPackets => '合計';

  @override
  String get deliveredPackets => '到達';

  @override
  String get droppedPackets => 'ドロップ';

  @override
  String get noDevices => 'デバイスがありません — パレットからデバイスをドラッグしてください';
}
