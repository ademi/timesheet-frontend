import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminPanelController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final TabController tabController;

  final tabs = const <Tab>[
    Tab(text: 'Employee Management'),
    Tab(text: 'Attendance Report'),
  ];

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}
