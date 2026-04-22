import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'engine/level_loader.dart';
import 'providers/settings_provider.dart';
import 'providers/game_provider.dart';
import 'providers/rewards_provider.dart';
import 'services/achievement_engine.dart';
import 'services/ad_gateway.dart';
import 'services/audio_service.dart';
import 'services/consent_service.dart';
import 'services/mobile_ads_gateway.dart';
import 'services/purchases_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await LevelLoader.preload();

  final settings = SettingsProvider();
  await settings.load();

  final rewards = RewardsProvider();
  await rewards.load();

  final achievements = AchievementEngine(rewards);
  rewards.attachAchievementEngine(achievements);

  // Consent must run before ad init so AdMob can respect the user's choice.
  // The UMP SDK handles personalised-vs-non-personalised signalling internally
  // based on the status ConsentService records — we initialise the gateway
  // either way so non-personalised ads still serve if consent is denied.
  await ConsentService.instance.initialize();

  final AdGateway adGateway = MobileAdsGateway();
  await adGateway.initialize();

  await PurchasesService.instance.initialize(rewards);

  await AudioService.instance.initialize();

  final gameProvider = GameProvider(rewards: rewards);
  gameProvider.attachAchievementEngine(achievements);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<RewardsProvider>.value(value: rewards),
        Provider<AdGateway>.value(value: adGateway),
        ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
      ],
      child: const SlovaApp(),
    ),
  );
}
