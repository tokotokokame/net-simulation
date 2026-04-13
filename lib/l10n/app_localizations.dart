import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Net.Simulation'**
  String get appTitle;

  /// No description provided for @startSimulation.
  ///
  /// In en, this message translates to:
  /// **'Start Simulation'**
  String get startSimulation;

  /// No description provided for @stopSimulation.
  ///
  /// In en, this message translates to:
  /// **'Stop Simulation'**
  String get stopSimulation;

  /// No description provided for @pauseSimulation.
  ///
  /// In en, this message translates to:
  /// **'Pause Simulation'**
  String get pauseSimulation;

  /// No description provided for @pausedSimulation.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedSimulation;

  /// No description provided for @demoTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Demo: {minutes}m remaining'**
  String demoTimerLabel(int minutes);

  /// No description provided for @upgradeToProTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToProTitle;

  /// No description provided for @upgradeToProMessage.
  ///
  /// In en, this message translates to:
  /// **'Your free demo session has ended. Upgrade to Pro or register to continue.'**
  String get upgradeToProMessage;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @registerFree.
  ///
  /// In en, this message translates to:
  /// **'Register Free'**
  String get registerFree;

  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get addDevice;

  /// No description provided for @deviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Device Settings'**
  String get deviceSettings;

  /// No description provided for @interfaces.
  ///
  /// In en, this message translates to:
  /// **'Interfaces'**
  String get interfaces;

  /// No description provided for @routing.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get routing;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @cli.
  ///
  /// In en, this message translates to:
  /// **'CLI'**
  String get cli;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @packetSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'Packet Success Rate'**
  String get packetSuccessRate;

  /// No description provided for @averageLatency.
  ///
  /// In en, this message translates to:
  /// **'Average Latency'**
  String get averageLatency;

  /// No description provided for @bandwidthUtilization.
  ///
  /// In en, this message translates to:
  /// **'Bandwidth Utilization'**
  String get bandwidthUtilization;

  /// No description provided for @packetLossRate.
  ///
  /// In en, this message translates to:
  /// **'Packet Loss Rate'**
  String get packetLossRate;

  /// No description provided for @simulateLinkFailure.
  ///
  /// In en, this message translates to:
  /// **'Simulate Link Failure'**
  String get simulateLinkFailure;

  /// No description provided for @restoreLink.
  ///
  /// In en, this message translates to:
  /// **'Restore Link'**
  String get restoreLink;

  /// No description provided for @simulateDeviceCrash.
  ///
  /// In en, this message translates to:
  /// **'Simulate Device Crash'**
  String get simulateDeviceCrash;

  /// No description provided for @restoreDevice.
  ///
  /// In en, this message translates to:
  /// **'Restore Device'**
  String get restoreDevice;

  /// No description provided for @connectionMode.
  ///
  /// In en, this message translates to:
  /// **'Connection Mode'**
  String get connectionMode;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @totalPackets.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalPackets;

  /// No description provided for @deliveredPackets.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveredPackets;

  /// No description provided for @droppedPackets.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get droppedPackets;

  /// No description provided for @noDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices — drag a device from the palette to begin'**
  String get noDevices;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
