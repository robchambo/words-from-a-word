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

  final AdGateway adGateway = NoopAdGateway();
  await adGateway.initialize();

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
