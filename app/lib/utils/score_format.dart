/// 점수를 화면에 보여줄 문자열로 바꾼다. 덤이 있는 한의 점수만 소수점 한 자리가 있다. 예: `72`, `73.5`
String formatScore(double score) {
  if (score == score.roundToDouble()) {
    return score.toInt().toString();
  }
  return score.toStringAsFixed(1);
}
