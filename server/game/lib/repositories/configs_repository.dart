import '../clock.dart';
import '../config.dart';
import '../firebase/firestore_client.dart';
import '../models/app_config.dart';

/// Firestore `configs/{configId}`.
class ConfigsRepository {
  final FirestoreClient firestore;
  final Clock clock;

  AppConfig? _cachedAppConfig;

  // [_cachedAppConfig]를 읽은 시각.
  DateTime? _appConfigLoadedAt;

  ConfigsRepository({required this.firestore, this.clock = utcNow});

  static const collection = 'configs';
  static const appConfigId = 'app';

  /// `configs/app`. [appConfigCacheDuration] 동안은 메모리 캐시를 쓴다. 문서가 없으면 [StateError]를 던진다.
  Future<AppConfig> getAppConfig() async {
    final now = clock();
    final cached = _cachedAppConfig;
    final loadedAt = _appConfigLoadedAt;
    if (cached != null && loadedAt != null && now.difference(loadedAt) < appConfigCacheDuration) {
      return cached;
    }
    final data = await firestore.getDocument('$collection/$appConfigId');
    if (data == null) {
      throw StateError('configs/app 문서가 없습니다');
    }
    final config = AppConfig.fromJson(data);
    _cachedAppConfig = config;
    _appConfigLoadedAt = now;
    return config;
  }
}
