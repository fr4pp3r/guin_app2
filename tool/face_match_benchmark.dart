// Accuracy reporting for the in-app face match score. Pure Dart statistics on
// already-measured scores — never runs TFLite or opens images. Feed it a CSV of
// `same,difference` scores: `same,<score>` / `different,<score>` per line.
import 'dart:io';

/// One measured pair: `samePerson` rows come from same-person images,
/// others from different-person images.
class BenchmarkRow {
  const BenchmarkRow(this.samePerson, this.score);
  final bool samePerson;
  final double score;
}

/// FAR/FRR at each threshold. A row is accepted when `score >= threshold`.
/// A class with no rows yields 0.0 (not NaN).
Map<double, ({double far, double frr})> sweep(
    List<BenchmarkRow> rows, List<double> thresholds) {
  final imposterTotal =
      rows.where((r) => !r.samePerson).length;
  final genuineTotal = rows.where((r) => r.samePerson).length;
  return {
    for (final t in thresholds)
      t: () {
        final impostorsAccepted =
            rows.where((r) => !r.samePerson && r.score >= t).length;
        final genuinesRejected =
            rows.where((r) => r.samePerson && r.score < t).length;
        return (
          far: imposterTotal == 0 ? 0.0 : impostorsAccepted / imposterTotal,
          frr: genuineTotal == 0 ? 0.0 : genuinesRejected / genuineTotal,
        );
      }(),
  };
}

/// Default threshold sweep 0.30→0.70 step 0.05, rendered as an aligned table.
String formatSweep(List<BenchmarkRow> rows) {
  final thresholds = [
    for (double t = 0.30; t <= 0.70 + 1e-9; t += 0.05) double.parse(t.toStringAsFixed(2)),
  ];
  final results = sweep(rows, thresholds);
  final buf = StringBuffer()
    ..writeln('Face match threshold sweep (accept when score >= threshold)')
    ..writeln('Score source: in-app face match (review page)')
    ..writeln('${'threshold'.padRight(10)}${'FAR'.padRight(10)}${'FRR'.padRight(10)}');
  for (final t in thresholds) {
    final r = results[t]!;
    buf.writeln(
        '${t.toStringAsFixed(2).padRight(10)}${r.far.toStringAsFixed(3).padRight(10)}${r.frr.toStringAsFixed(3).padRight(10)}');
  }
  return buf.toString();
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/face_match_benchmark.dart <scores.csv>');
    stderr.writeln('CSV lines: same,<score> or different,<score>; # starts a comment');
    exit(2);
  }
  final rows = <BenchmarkRow>[];
  for (final line in File(args[0]).readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split(',');
    if (parts.length != 2) continue;
    final score = double.tryParse(parts[1].trim());
    if (score == null) continue;
    rows.add(BenchmarkRow(parts[0].trim().toLowerCase() == 'same', score));
  }
  stdout.write(formatSweep(rows));
}
