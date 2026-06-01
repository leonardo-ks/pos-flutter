enum UserRole { cashier, manager, administrator }

extension UserRoleLabel on UserRole {
  String get label {
    return switch (this) {
      UserRole.cashier => 'Kasir',
      UserRole.manager => 'Manajer',
      UserRole.administrator => 'Administrator',
    };
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.roleValue = '',
  });

  final int id;
  final String name;
  final UserRole role;
  final String roleValue;

  String get permissionRole => roleValue.isEmpty ? role.apiValue : roleValue;

  factory AppUser.fromJson(Map<String, Object?> json) {
    final roleValue = json['role'] as String;
    return AppUser(
      id: json['id'] as int,
      name: json['nama'] as String,
      role: UserRoleApi.fromApi(roleValue),
      roleValue: roleValue,
    );
  }
}

extension UserRoleApi on UserRole {
  String get apiValue {
    return switch (this) {
      UserRole.cashier => 'kasir',
      UserRole.manager => 'manajer',
      UserRole.administrator => 'administrator',
    };
  }

  static UserRole fromApi(String value) {
    return switch (value.toLowerCase()) {
      'kasir' => UserRole.cashier,
      'manajer' => UserRole.manager,
      'administrator' => UserRole.administrator,
      _ => UserRole.cashier,
    };
  }
}
