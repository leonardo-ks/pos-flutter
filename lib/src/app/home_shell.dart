import 'package:flutter/material.dart';

import '../auth/models/app_user.dart';
import '../authorization/screens/authorization_screen.dart';
import '../core/theme/app_theme.dart';
import '../customers/screens/customer_screen.dart';
import '../inventory/screens/inventory_screen.dart';
import '../pos/screens/pos_screen.dart';
import '../purchases/screens/purchase_screen.dart';
import '../reports/screens/reports_screen.dart';
import '../returns/screens/returns_screen.dart';
import '../shared/widgets/app_tab_scaffold.dart';
import '../shared/widgets/feature_table_screen.dart';
import 'app_controller.dart';
import 'app_destination.dart';
import 'app_scope.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final sections = controller.availableSections;
    final activeSection =
        sections.contains(controller.selectedSection) || sections.isEmpty
        ? controller.selectedSection
        : sections.first;
    final activeDestination = AppDestination.fromSection(activeSection);
    final selectedIndex = sections.indexOf(activeSection);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compactShell;
        final content = _sectionBody(activeSection);
        final appBar = AppBar(
          title: Text(activeDestination.label),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Center(
                child: Text(
                  '${controller.currentUser!.name} - ${controller.currentUser!.role.label}',
                  style: context.textTheme.labelLarge,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Keluar',
              onPressed: controller.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        );

        if (compact) {
          return Scaffold(
            appBar: appBar,
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) {
                controller.selectSection(sections[index]);
              },
              destinations: [
                for (final section in sections)
                  _navigationDestination(AppDestination.fromSection(section)),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              SizedBox(
                width: constraints.maxWidth >= AppBreakpoints.wideShell
                    ? 264
                    : 228,
                child: _SideNavigation(
                  sections: sections,
                  selectedSection: controller.selectedSection,
                  onSelected: controller.selectSection,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  NavigationDestination _navigationDestination(AppDestination destination) {
    return NavigationDestination(
      icon: Icon(destination.icon),
      label: destination.label,
    );
  }

  Widget _sectionBody(AppSection section) {
    return switch (section) {
      AppSection.pos => const PosScreen(),
      AppSection.purchases => const PurchaseScreen(),
      AppSection.returns => const ReturnsScreen(),
      AppSection.reports => const ReportsScreen(),
      AppSection.master => const MasterDataScreen(),
      AppSection.users => const AccountManagementScreen(),
    };
  }
}

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tabs = <AppTabItem>[
      if (controller.canViewMenu('inventory'))
        const AppTabItem(label: 'Inventaris', child: InventoryScreen()),
      if (controller.canViewMenu('customers'))
        const AppTabItem(label: 'Pelanggan', child: CustomerScreen()),
      if (controller.canViewMenu('suppliers'))
        const AppTabItem(
          label: 'Suplier',
          child: FeatureTableScreen(
            title: 'Suplier',
            subtitle: 'Kelola data pemasok.',
            path: '/api/suppliers',
            permissionSection: 'suppliers',
            showHeader: false,
            fields: [
              FeatureField('kode', 'Kode'),
              FeatureField('nama', 'Nama'),
              FeatureField('alamat', 'Alamat'),
              FeatureField('telepon', 'Telepon', phone: true),
              FeatureField('keterangan', 'Keterangan'),
            ],
          ),
        ),
    ];

    return AppTabScaffold(
      tabs: tabs,
      emptyMessage: 'Tidak Ada Menu Master Data.',
    );
  }
}

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tabs = <AppTabItem>[
      if (controller.canViewMenu('users'))
        const AppTabItem(
          label: 'Pengguna',
          child: FeatureTableScreen(
            title: 'Manajemen',
            subtitle: 'Kelola pengguna dan role akses.',
            path: '/api/users',
            permissionSection: 'users',
            showHeader: false,
            labelKeys: ['nama'],
            summaryKeys: [],
            fields: [
              FeatureField('nama', 'Nama'),
              FeatureField('username', 'Username'),
              FeatureField('email', 'Email'),
              FeatureField(
                'role',
                'Role',
                referencePath: '/api/roles',
                referenceValueKey: 'kode',
                referenceLabelKeys: ['nama', 'kode'],
              ),
            ],
          ),
        ),
      if (controller.canViewMenu('roles'))
        const AppTabItem(
          label: 'Role',
          child: FeatureTableScreen(
            title: 'Role',
            subtitle: 'Kelola role pengguna.',
            path: '/api/roles',
            permissionSection: 'roles',
            showHeader: false,
            labelKeys: ['nama'],
            summaryKeys: [],
            fields: [
              FeatureField('kode', 'Kode'),
              FeatureField('nama', 'Nama'),
              FeatureField('keterangan', 'Keterangan'),
            ],
          ),
        ),
      if (controller.canViewMenu('authorization'))
        const AppTabItem(label: 'Otorisasi', child: AuthorizationScreen()),
    ];

    return AppTabScaffold(
      tabs: tabs,
      emptyMessage: 'Tidak Ada Akses Manajemen.',
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.sections,
    required this.selectedSection,
    required this.onSelected,
  });

  final List<AppSection> sections;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: _SideNavigationTile(
              destination: AppDestination.fromSection(section),
              selected: section == selectedSection,
              onTap: () => onSelected(section),
            ),
          ),
      ],
    );
  }
}

class _SideNavigationTile extends StatelessWidget {
  const _SideNavigationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? context.colors.secondaryContainer : null;
    final foreground = selected
        ? context.colors.onSecondaryContainer
        : context.colors.onSurface;

    return Material(
      color: background,
      borderRadius: AppRadius.card,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.lg),
              Icon(destination.icon, size: 22, color: foreground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  destination.label,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
