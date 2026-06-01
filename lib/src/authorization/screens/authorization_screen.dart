import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../shared/models/feature_record.dart';
import '../../shared/widgets/empty_state.dart';

const _permissionGroups = [
  _PermissionGroup(section: 'pos', label: 'Kasir', children: []),
  _PermissionGroup(section: 'purchases', label: 'Pembelian', children: []),
  _PermissionGroup(
    section: 'returns',
    label: 'Retur',
    children: [
      _PermissionMenu(section: 'purchase-returns', label: 'Retur Pembelian'),
      _PermissionMenu(section: 'sales-returns', label: 'Retur Penjualan'),
    ],
  ),
  _PermissionGroup(section: 'reports', label: 'Laporan', children: []),
  _PermissionGroup(
    section: 'master',
    label: 'Master Data',
    children: [
      _PermissionMenu(section: 'inventory', label: 'Inventaris'),
      _PermissionMenu(section: 'customers', label: 'Pelanggan'),
      _PermissionMenu(section: 'suppliers', label: 'Suplier'),
    ],
  ),
  _PermissionGroup(
    section: 'account',
    label: 'Manajemen Akun',
    children: [
      _PermissionMenu(section: 'users', label: 'Pengguna'),
      _PermissionMenu(section: 'roles', label: 'Role'),
      _PermissionMenu(section: 'authorization', label: 'Otorisasi'),
    ],
  ),
];

class _PermissionMenu {
  const _PermissionMenu({required this.section, required this.label});

  final String section;
  final String label;
}

class _PermissionGroup extends _PermissionMenu {
  const _PermissionGroup({
    required super.section,
    required super.label,
    required this.children,
  });

  final List<_PermissionMenu> children;
}

class AuthorizationScreen extends StatefulWidget {
  const AuthorizationScreen({super.key});

  @override
  State<AuthorizationScreen> createState() => _AuthorizationScreenState();
}

class _AuthorizationScreenState extends State<AuthorizationScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final controller = AppScope.of(context);
    Future.microtask(() async {
      await controller.loadFeatureRecords('/api/roles');
      await controller.loadFeatureRecords('/api/role-permissions');
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final permissions = controller.featureRecords('/api/role-permissions');
    final roles = _roleOptions(controller);

    return Column(
      children: [
        Expanded(
          child: controller.isBusy && roles.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : roles.isEmpty
              ? const EmptyState(
                  icon: Icons.admin_panel_settings,
                  title: 'Belum Ada Role',
                  message: 'Data role akan muncul di sini.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: roles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    final rolePermissions = permissions
                        .where((record) => record.values['role'] == role.$1)
                        .toList(growable: false);
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.admin_panel_settings),
                        ),
                        title: Text(role.$2),
                        subtitle: Text(
                          '${rolePermissions.where((record) => record.values['can_view'] == true).length} Menu Aktif',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openRoleDialog(context, role),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<(String, String)> _roleOptions(AppController controller) {
    final records = controller.featureRecords('/api/roles');
    if (records.isNotEmpty) {
      return records
          .map(
            (record) => (
              record.values['kode']?.toString() ?? '',
              record.values['nama']?.toString() ??
                  record.values['kode']?.toString() ??
                  '',
            ),
          )
          .where((role) => role.$1.isNotEmpty)
          .toList(growable: false);
    }
    return const [
      ('kasir', 'Kasir'),
      ('manajer', 'Manajer'),
      ('administrator', 'Administrator'),
    ];
  }

  Future<void> _openRoleDialog(
    BuildContext context,
    (String, String) role,
  ) async {
    final controller = AppScope.of(context);
    final allowedSections = _allPermissionMenus
        .map((menu) => menu.section)
        .toSet();
    final permissions = {
      for (final record
          in controller
              .featureRecords('/api/role-permissions')
              .where(
                (record) =>
                    record.values['role'] == role.$1 &&
                    allowedSections.contains(record.values['section']),
              ))
        record.values['section'] as String: _PermissionDraft.fromRecord(record),
    };
    for (final menu in _allPermissionMenus) {
      permissions.putIfAbsent(
        menu.section,
        () => _PermissionDraft(role: role.$1, section: menu.section),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final narrow = MediaQuery.sizeOf(context).width < 640;
          final content = SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final group in _permissionGroups)
                  _PermissionGroupCard(
                    group: group,
                    permissions: permissions,
                    onChanged: () => setState(() {}),
                  ),
              ],
            ),
          );
          final actions = [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                for (final draft in permissions.values) {
                  await controller.saveFeatureRecord(
                    '/api/role-permissions',
                    draft.toBody(),
                    id: draft.id,
                  );
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Simpan'),
            ),
          ];
          if (narrow) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(title: Text('Otorisasi ${role.$2}')),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
                bottomNavigationBar: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final action in actions) ...[
                          action,
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return AlertDialog(
            title: Text('Otorisasi ${role.$2}'),
            content: SizedBox(width: 720, child: content),
            actions: actions,
          );
        },
      ),
    );
  }

  List<_PermissionMenu> get _allPermissionMenus {
    return [
      for (final group in _permissionGroups)
        if (group.children.isEmpty) group else ...group.children,
    ];
  }
}

class _PermissionGroupCard extends StatelessWidget {
  const _PermissionGroupCard({
    required this.group,
    required this.permissions,
    required this.onChanged,
  });

  final _PermissionGroup group;
  final Map<String, _PermissionDraft> permissions;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            if (group.children.isEmpty)
              _PermissionRow(
                label: group.label,
                draft: permissions[group.section]!,
                onChanged: onChanged,
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            for (final child in group.children)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 6),
                child: _PermissionRow(
                  label: child.label,
                  draft: permissions[child.section]!,
                  onChanged: onChanged,
                  childRow: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.draft,
    required this.onChanged,
    this.childRow = false,
  });

  final String label;
  final _PermissionDraft draft;
  final VoidCallback onChanged;
  final bool childRow;

  @override
  Widget build(BuildContext context) {
    final toggles = [
      _PermissionCheckbox(
        label: 'Lihat',
        value: draft.canView,
        onChanged: (value) {
          draft.canView = value;
          onChanged();
        },
      ),
      _PermissionCheckbox(
        label: 'Tambah',
        value: draft.canCreate,
        onChanged: (value) {
          draft.canCreate = value;
          onChanged();
        },
      ),
      _PermissionCheckbox(
        label: 'Edit',
        value: draft.canUpdate,
        onChanged: (value) {
          draft.canUpdate = value;
          onChanged();
        },
      ),
      _PermissionCheckbox(
        label: 'Hapus',
        value: draft.canDelete,
        onChanged: (value) {
          draft.canDelete = value;
          onChanged();
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final labelWidget = Row(
          children: [
            if (childRow) ...[
              const Icon(Icons.subdirectory_arrow_right, size: 16),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: childRow ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
          ],
        );

        if (narrow) {
          return Row(
            children: [
              Expanded(child: labelWidget),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: toggles),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: labelWidget),
            for (final toggle in toggles) toggle,
          ],
        );
      },
    );
  }
}

class _PermissionCheckbox extends StatelessWidget {
  const _PermissionCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: value,
            onChanged: (value) => onChanged(value ?? false),
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDraft {
  _PermissionDraft({
    this.id,
    required this.role,
    required this.section,
    this.canView = false,
    this.canCreate = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  factory _PermissionDraft.fromRecord(FeatureRecord record) {
    return _PermissionDraft(
      id: record.id,
      role: record.values['role'] as String,
      section: record.values['section'] as String,
      canView: record.values['can_view'] == true,
      canCreate: record.values['can_create'] == true,
      canUpdate: record.values['can_update'] == true,
      canDelete: record.values['can_delete'] == true,
    );
  }

  final int? id;
  final String role;
  final String section;
  bool canView;
  bool canCreate;
  bool canUpdate;
  bool canDelete;

  Map<String, Object?> toBody() {
    return {
      'role': role,
      'section': section,
      'can_view': canView,
      'can_create': canCreate,
      'can_update': canUpdate,
      'can_delete': canDelete,
    };
  }
}
