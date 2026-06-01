import 'package:flutter/material.dart';

import 'app_controller.dart';

class AppDestination {
  const AppDestination({
    required this.section,
    required this.label,
    required this.icon,
  });

  final AppSection section;
  final String label;
  final IconData icon;

  static const all = [
    AppDestination(
      section: AppSection.pos,
      label: 'Kasir',
      icon: Icons.point_of_sale,
    ),
    AppDestination(
      section: AppSection.purchases,
      label: 'Pembelian',
      icon: Icons.shopping_cart_checkout,
    ),
    AppDestination(
      section: AppSection.returns,
      label: 'Retur',
      icon: Icons.assignment_return,
    ),
    AppDestination(
      section: AppSection.reports,
      label: 'Laporan',
      icon: Icons.bar_chart,
    ),
    AppDestination(
      section: AppSection.master,
      label: 'Master',
      icon: Icons.dataset,
    ),
    AppDestination(
      section: AppSection.users,
      label: 'Manajemen',
      icon: Icons.manage_accounts,
    ),
  ];

  static AppDestination fromSection(AppSection section) {
    return all.firstWhere((destination) => destination.section == section);
  }
}
