/// `1.2.3` 모양의 [version]이 [minVersion]보다 낮은지. 세 숫자를 앞에서부터 본다. 모양이 다르면 막지 않도록 false다.
bool isOlderVersion(String version, String minVersion) {
  final current = _parse(version);
  final minimum = _parse(minVersion);
  if (current == null || minimum == null) {
    return false;
  }
  for (var index = 0; index < current.length; index++) {
    if (current[index] != minimum[index]) {
      return current[index] < minimum[index];
    }
  }
  return false;
}

List<int>? _parse(String version) {
  final parts = version.split('.');
  if (parts.length != 3) {
    return null;
  }
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.contains(null)) {
    return null;
  }
  return numbers.cast<int>();
}
