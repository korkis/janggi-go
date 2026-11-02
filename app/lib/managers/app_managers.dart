import 'auth_manager.dart';

/// 앱 수명 동안 유지하는 Manager. `repositories`를 설정한 뒤에 설정한다.
late AppManagers managers;

class AppManagers {
  final AuthManager authManager;

  AppManagers({required this.authManager});

  factory AppManagers.createDefault() => AppManagers(authManager: AuthManager());
}
