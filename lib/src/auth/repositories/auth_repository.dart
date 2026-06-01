import '../../shared/api/api_client.dart';
import '../models/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login({required String username, required String password});
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final user = await _apiClient.post<AppUser>(
      '/api/auth/login',
      {'username': username, 'password': password},
      (data) {
        final map = data as Map<String, Object?>;
        _apiClient.setBearerToken(map['token'] as String);
        return AppUser.fromJson(map['user'] as Map<String, Object?>);
      },
    );
    _apiClient.setUserId(user.id);
    return user;
  }
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._users);

  final List<AppUser> _users;

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final role = username.contains('admin')
        ? UserRole.administrator
        : username.contains('manajer')
        ? UserRole.manager
        : UserRole.cashier;
    return _users.firstWhere((user) => user.role == role);
  }
}
