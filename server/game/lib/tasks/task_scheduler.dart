/// 예약 작업. `POST /tasks/{name}`으로 대국 서버를 다시 부른다(`docs/server.md`의 예약 작업).
///
/// 경로는 Cloud Tasks에 예약해 둔 작업이 부르므로 이미 쓰는 이름은 바꾸지 않는다.
enum TaskName {
  /// 개발용. 에뮬레이터에서만 경로를 연다. `devPing` API가 예약 작업이 도는지 확인할 때 쓴다.
  devPing;

  String get path => '/tasks/$name';
}

/// 정한 시각에 대국 서버의 예약 작업 경로를 부르게 예약한다.
///
/// 운영은 Cloud Tasks(`CloudTasksScheduler`), 에뮬레이터는 같은 프로세스의 타이머(`LocalTaskScheduler`)다.
/// 예약 시각은 정확하지 않을 수 있고 같은 작업이 두 번 돌 수도 있으므로, 작업은 기록된 시각으로 판정하고 여러 번 돌아도 결과가 같게 만든다.
abstract interface class TaskScheduler {
  /// [runAt]에 [task]를 본문 [payload]로 부르게 한다. 지난 시각이면 바로 부른다.
  ///
  /// [taskId]를 주면 같은 [taskId]로 이미 예약한 적이 있을 때 새로 만들지 않는다. 영문, 숫자, `-`, `_`만 쓴다.
  Future<void> schedule(TaskName task, Map<String, Object?> payload, {required DateTime runAt, String? taskId});
}

/// [taskId]가 Cloud Tasks 작업 이름 규칙에 맞는지.
bool isValidTaskId(String taskId) => RegExp(r'^[A-Za-z0-9_-]{1,500}$').hasMatch(taskId);
