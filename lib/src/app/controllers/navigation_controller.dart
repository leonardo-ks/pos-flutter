// ignore_for_file: prefer_initializing_formals
// (private fields can't be named parameters, so the initializer list is required)
import 'package:flutter/foundation.dart';

import '../app_controller.dart' show AppSection;

class NavigationController extends ChangeNotifier {
  NavigationController({
    required bool Function(AppSection section) canView,
    required void Function(AppSection section) onEnterSection,
  })  : _canView = canView,
        _onEnterSection = onEnterSection;

  final bool Function(AppSection section) _canView;
  final void Function(AppSection section) _onEnterSection;

  AppSection _selectedSection = AppSection.pos;
  AppSection get selectedSection => _selectedSection;

  void selectSection(AppSection section) {
    if (!_canView(section)) return;
    if (_selectedSection == section) return;
    _selectedSection = section;
    notifyListeners();
    _onEnterSection(section);
  }

  void reset() {
    _selectedSection = AppSection.pos;
  }
}
