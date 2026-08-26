import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/utils/site_geocode_apply.dart';

void main() {
  late TextEditingController lat;
  late TextEditingController lng;
  late RxnString formatted;
  late RxBool confirmed;

  setUp(() {
    lat = TextEditingController();
    lng = TextEditingController();
    formatted = RxnString();
    confirmed = false.obs;
  });

  tearDown(() {
    lat.dispose();
    lng.dispose();
  });

  test('rejects low confidence and clears coords', () {
    final outcome = applyGeocodeResponse(
      result: const GeocodeResponse(
        latitude: -33.86,
        longitude: 151.2,
        formattedAddress: 'Vague',
        confidence: 'low',
      ),
      latCtrl: lat,
      lngCtrl: lng,
      formattedAddress: formatted,
      addressConfirmed: confirmed,
      addressFallback: '1 Test St, Sydney',
    );
    expect(outcome.accepted, isFalse);
    expect(outcome.errorMessage, contains('low confidence'));
    expect(lat.text, isEmpty);
    expect(lng.text, isEmpty);
    expect(formatted.value, isNull);
    expect(confirmed.value, isFalse);
  });

  test('accepts medium/high/null confidence and sets coords', () {
    for (final confidence in <String?>['high', 'medium', null]) {
      lat.clear();
      lng.clear();
      formatted.value = null;
      final outcome = applyGeocodeResponse(
        result: GeocodeResponse(
          latitude: -33.86,
          longitude: 151.2,
          formattedAddress: '1 Test St, Sydney NSW',
          confidence: confidence,
        ),
        latCtrl: lat,
        lngCtrl: lng,
        formattedAddress: formatted,
        addressConfirmed: confirmed,
        addressFallback: '1 Test St, Sydney',
      );
      expect(outcome.accepted, isTrue, reason: 'confidence=$confidence');
      expect(outcome.errorMessage, isNull);
      expect(lat.text, '-33.86');
      expect(lng.text, '151.2');
    }
  });
}
