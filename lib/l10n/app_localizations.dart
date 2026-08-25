import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('fr')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  bool get isFrench => locale.languageCode == 'fr';

  String get appTitle => isFrench ? 'Aqua Niveau' : 'Aqua Level';
  String get tankOverview => isFrench ? 'Vue du réservoir' : 'Tank overview';
  String get liveMonitor => isFrench ? "Suivi en direct du niveau d'eau" : 'Live household water monitor';
  String get online => isFrench ? 'En ligne' : 'Online';
  String get notLive => isFrench ? 'Hors ligne' : 'Not live';
  String get unknown => isFrench ? 'Aucune mesure' : 'No reading';
  String relativeTime(Duration age) {
    if (age.isNegative || age.inSeconds < 10) return isFrench ? "à l'instant" : 'Just now';
    if (age.inMinutes < 1) return isFrench ? 'il y a quelques secondes' : 'A few seconds ago';
    if (age.inMinutes < 60) return isFrench ? 'il y a ${age.inMinutes} min' : '${age.inMinutes} min ago';
    if (age.inHours < 24) return isFrench ? 'il y a ${age.inHours} h' : '${age.inHours} hr ago';
    return isFrench ? 'il y a ${age.inDays} j' : '${age.inDays} days ago';
  }
  String savedAt(Object time) => isFrench ? 'Mesuré le $time' : 'Measured $time';
  String get currentLevel => isFrench ? 'Niveau actuel' : 'Current level';
  String get tankCapacity => isFrench ? 'de la capacité du réservoir' : 'of tank capacity';
  String get plentyWater => isFrench ? "Il y a beaucoup d'eau" : 'Plenty of water available';
  String get keepEye => isFrench ? 'Gardez un œil sur le niveau' : 'Keep an eye on the tank';
  String get lastUpdate => isFrench ? 'Dernière mise à jour' : 'Last update';
  String get firmware => isFrench ? 'Micrologiciel' : 'Firmware';
  String updatedAgo(Object seconds) => isFrench ? 'il y a ${seconds}s' : '${seconds}s ago';
  String get updateTip => isFrench ? "Le niveau se met à jour automatiquement lorsque l'application est ouverte." : 'Level updates automatically while this app is open.';
  String get settings => isFrench ? 'Réglages' : 'Settings';
  String get refresh => isFrench ? 'Actualiser' : 'Refresh';
  String get waitingSensor => isFrench ? 'En attente du capteur' : 'Waiting for sensor';
  String get noReading => isFrench ? 'Aucune mesure valide reçue pour le moment.' : 'No valid reading has been received yet.';
  String get sensorNotResponding => isFrench ? 'Le capteur ne répond pas' : 'Sensor not responding';
  String lastReading(Object age) => isFrench ? 'La dernière mesure date de ${age} secondes.' : 'Last reading is ${age} seconds old.';
  String get unreachable => isFrench ? 'ESP32 inaccessible' : 'ESP32 unreachable';
  String get settingsTitle => isFrench ? 'Réglages' : 'Settings';
  String get espAddress => isFrench ? 'Adresse ESP32' : 'ESP32 address';
  String get emptyDistance => isFrench ? 'Distance réservoir vide (cm)' : 'Empty distance (cm)';
  String get fullDistance => isFrench ? 'Distance réservoir plein (cm)' : 'Full distance (cm)';
  String get pollInterval => isFrench ? 'Intervalle de mise à jour (minutes)' : 'Poll interval (minutes)';
  String get saveSettings => isFrench ? 'Enregistrer les réglages' : 'Save settings';
  String get language => isFrench ? 'Langue' : 'Language';
  String get systemLanguage => isFrench ? 'Langue du téléphone' : 'System default';
  String get english => 'English';
  String get french => 'Français';
  String get defaultAddress => 'http://192.168.1.12';
  String get addressRequired => isFrench ? "L'adresse ESP32 est obligatoire." : 'ESP32 address is required.';
  String get validAddress => isFrench ? 'Saisissez une adresse HTTP valide.' : 'Enter a valid HTTP address.';
  String get positiveDistances => isFrench ? 'Les distances doivent être positives.' : 'Distances must be positive.';
  String get distanceOrder => isFrench ? 'La distance vide doit être supérieure à la distance pleine.' : 'Empty distance must be greater than full distance.';
  String get blindZone => isFrench ? 'La distance pleine doit être au moins de 30 cm.' : 'Full distance must be at least 30 cm.';
  String get positiveInterval => isFrench ? "L'intervalle doit être positif." : 'Poll interval must be positive.';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en' || locale.languageCode == 'fr';
  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
