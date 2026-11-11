import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppController> loadController() async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await controller.init();
    return controller;
  }

  test(
    'Thai CC Tower is selected on a fresh install and stays available',
    () async {
      final controller = await loadController();
      expect(controller.places.single, Place.thaiCcTower);
      expect(controller.place, Place.thaiCcTower);

      await controller.deletePlace(0);
      expect(controller.place, Place.thaiCcTower);
    },
  );

  test(
    'adds the office preset without changing an existing selection',
    () async {
      const warehouse = Place('Warehouse', 13.8, 100.5, '');
      const branch = Place('Branch', 13.9, 100.6, '');
      SharedPreferences.setMockInitialValues({
        'places': jsonEncode([warehouse.toJson(), branch.toJson()]),
        'selected': 1,
      });

      final controller = await loadController();
      expect(controller.place?.name, branch.name);
      expect(controller.places.last, Place.thaiCcTower);

      await controller.selectPlace(2);
      final reopened = await loadController();
      expect(reopened.place?.isDefaultOffice, isTrue);
      expect(
        reopened.places.where((place) => place.isDefaultOffice),
        hasLength(1),
      );
      expect(reopened.places.map((place) => place.name), [
        warehouse.name,
        branch.name,
        Place.thaiCcTower.name,
      ]);
    },
  );
}
