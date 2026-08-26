import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared contract for [SiteFormFields] (standalone site form + onboarding).
abstract class SiteFormHost {
  TextEditingController get siteNameCtrl;
  TextEditingController get siteAddressCtrl;
  TextEditingController get siteCityCtrl;
  TextEditingController get siteStateCtrl;
  TextEditingController get sitePostalCtrl;
  TextEditingController get siteAccessNotesCtrl;
  TextEditingController get siteLatCtrl;
  TextEditingController get siteLngCtrl;

  RxBool get siteIsPrimary;
  RxBool get isGeocoding;
  RxnString get geocodeFormattedAddress;
  RxBool get addressConfirmed;
  RxString get siteCountry;
  RxString get siteState;

  void invalidateSiteAddressConfirm();
  Future<void> lookupSiteAddress();
  void confirmSiteAddress();
  void editSiteAddress();
}
