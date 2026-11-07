import 'package:flutter_test/flutter_test.dart';
import '../../tool/face_match_benchmark.dart';

void main() {
  const rows = [
    BenchmarkRow(true, 0.81),
    BenchmarkRow(true, 0.64),
    BenchmarkRow(true, 0.44),
    BenchmarkRow(false, 0.41),
    BenchmarkRow(false, 0.22),
    BenchmarkRow(false, 0.77),
  ];

  test('sweep at 0.5: far 1/3, frr 1/3', () {
    final r = sweep(rows, [0.5])[0.5]!;
    expect(r.far, closeTo(1 / 3, 1e-9)); // 0.77 impostor accepted
    expect(r.frr, closeTo(1 / 3, 1e-9)); // 0.44 genuine rejected
  });

  test('formatSweep has header and one line per threshold (0.30..0.70)', () {
    final out = formatSweep(rows);
    final lines = out.trim().split('\n');
    expect(out, contains('threshold'));
    expect(out, contains('FAR'));
    expect(out, contains('FRR'));
    // 3 header/note lines + 9 thresholds = 12
    expect(lines.length, 12);
    expect(out, contains('0.30'));
    expect(out, contains('0.70'));
  });

  test('empty rows yield 0.0, not NaN', () {
    final r = sweep(const [], [0.5])[0.5]!;
    expect(r.far, 0.0);
    expect(r.frr, 0.0);
    final out = formatSweep(const []);
    expect(out.contains('NaN'), isFalse);
  });
}
