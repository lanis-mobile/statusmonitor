/// Resolves "now" as UTC unix seconds. Tests pin this via [fixedNow].
class Clock {
  Clock({int? fixedNow}) : _fixedNow = fixedNow;

  final int? _fixedNow;

  int get nowSeconds =>
      _fixedNow ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  DateTime get nowUtc =>
      DateTime.fromMillisecondsSinceEpoch(nowSeconds * 1000, isUtc: true);
}
