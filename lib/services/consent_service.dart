import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Normalised result of a consent / tracking prompt.
enum ConsentResult {
  granted,
  denied,
  notDetermined,
  notApplicable,
}

/// Wraps App Tracking Transparency (iOS) and the Google User Messaging
/// Platform (UMP) consent flow for GDPR regions.
///
/// Usage: await [ConsentService.instance.initialize] once at app start
/// before any ad load, then gate personalised ads on
/// [personalisedAdsAllowed].
class ConsentService {
  ConsentService._();

  static final ConsentService instance = ConsentService._();

  ConsentResult _att = ConsentResult.notDetermined;
  ConsentResult _ump = ConsentResult.notDetermined;

  ConsentResult get att => _att;
  ConsentResult get ump => _ump;

  /// Personalised ads are allowed only when neither layer has denied
  /// consent. `notApplicable` (e.g. Android has no ATT, or UMP says the
  /// user is outside a consent region) is treated as OK.
  static bool personalisedAdsAllowed({
    required ConsentResult att,
    required ConsentResult ump,
  }) {
    bool ok(ConsentResult r) =>
        r == ConsentResult.granted || r == ConsentResult.notApplicable;
    return ok(att) && ok(ump);
  }

  /// Runs the ATT prompt (iOS only) followed by the UMP consent flow.
  Future<void> initialize() async {
    await _runAtt();
    await _runUmp();
  }

  Future<void> _runAtt() async {
    if (!Platform.isIOS) {
      _att = ConsentResult.notApplicable;
      return;
    }
    try {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      switch (status) {
        case TrackingStatus.authorized:
          _att = ConsentResult.granted;
          break;
        case TrackingStatus.denied:
        case TrackingStatus.restricted:
          _att = ConsentResult.denied;
          break;
        case TrackingStatus.notDetermined:
        case TrackingStatus.notSupported:
          _att = ConsentResult.notDetermined;
          break;
      }
    } catch (e) {
      debugPrint('ConsentService ATT error: $e');
      _att = ConsentResult.notDetermined;
    }
  }

  Future<void> _runUmp() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          final available =
              await ConsentInformation.instance.isConsentFormAvailable();
          if (available) {
            final formCompleter = Completer<void>();
            ConsentForm.loadConsentForm(
              (ConsentForm form) {
                form.show((_) {
                  if (!formCompleter.isCompleted) formCompleter.complete();
                });
              },
              (formError) {
                debugPrint(
                    'ConsentService UMP form load error: ${formError.message}');
                if (!formCompleter.isCompleted) formCompleter.complete();
              },
            );
            await formCompleter.future;
          }
          final status =
              await ConsentInformation.instance.getConsentStatus();
          switch (status) {
            case ConsentStatus.obtained:
              _ump = ConsentResult.granted;
              break;
            case ConsentStatus.required:
              _ump = ConsentResult.denied;
              break;
            case ConsentStatus.notRequired:
              _ump = ConsentResult.notApplicable;
              break;
            case ConsentStatus.unknown:
              _ump = ConsentResult.notDetermined;
              break;
          }
        } catch (e) {
          debugPrint('ConsentService UMP success-path error: $e');
          _ump = ConsentResult.notDetermined;
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (formError) {
        debugPrint('ConsentService UMP update error: ${formError.message}');
        _ump = ConsentResult.notDetermined;
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }
}
