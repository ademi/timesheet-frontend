/// Pure allocation helpers for group shifts (equal-split + sum gates).
///
/// Matches backend `equal_percentage_values`: split 100.00 into hundredths
/// using largest remainder so values always sum exactly to 100.0.

List<double> equalPercentageValues(int n) {
  if (n < 1) {
    throw ArgumentError.value(n, 'n', 'must be >= 1');
  }

  const totalCents = 10000; // 100.00%
  final base = totalCents ~/ n;
  final remainder = totalCents % n;
  return List<double>.generate(
    n,
    (index) => (base + (index < remainder ? 1 : 0)) / 100.0,
    growable: false,
  );
}

double sumValues(Iterable<double> values) {
  var sum = 0.0;
  for (final value in values) {
    sum += value;
  }
  return sum;
}

/// Remaining capacity toward 100%. Negative means over-allocated.
double remainingTo100(Iterable<double> values) => 100.0 - sumValues(values);

bool sumsTo100(Iterable<double> values, {double epsilon = 0.01}) =>
    remainingTo100(values).abs() <= epsilon;

/// Soft UX gate: confirm when the next size would be a "large group".
bool needsLargeGroupConfirm(int nextN) => nextN >= 9;

/// Hard server-aligned cap.
bool atHardCap(int n) => n >= 32;
