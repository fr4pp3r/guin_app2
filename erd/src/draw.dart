/// CiteEase ERD — SVG drawing primitives with real Times New Roman metrics.
library;

import 'schema.dart';
import 'rels.dart';

// ---------------------------------------------------------------------------
// Times New Roman (Times-Roman) advance widths, units per 1000 em.
// ---------------------------------------------------------------------------
const Map<int, int> _tw = {
  32: 250, 33: 333, 34: 408, 35: 500, 36: 500, 37: 833, 38: 778, 39: 180,
  40: 333, 41: 333, 42: 500, 43: 564, 44: 250, 45: 333, 46: 250, 47: 278,
  48: 500, 49: 500, 50: 500, 51: 500, 52: 500, 53: 500, 54: 500, 55: 500,
  56: 500, 57: 500, 58: 278, 59: 278, 60: 564, 61: 564, 62: 564, 63: 444,
  64: 915,
  65: 722, 66: 667, 67: 667, 68: 722, 69: 611, 70: 556, 71: 722, 72: 722,
  73: 333, 74: 389, 75: 722, 76: 611, 77: 889, 78: 722, 79: 778, 80: 667,
  81: 778, 82: 722, 83: 667, 84: 611, 85: 722, 86: 667, 87: 944, 88: 667,
  89: 667, 90: 611,
  91: 333, 92: 278, 93: 333, 94: 469, 95: 500, 96: 333,
  97: 444, 98: 500, 99: 444, 100: 500, 101: 444, 102: 333, 103: 500,
  104: 500, 105: 278, 106: 278, 107: 500, 108: 278, 109: 778, 110: 500,
  111: 500, 112: 500, 113: 500, 114: 333, 115: 389, 116: 278, 117: 500,
  118: 500, 119: 722, 120: 500, 121: 500, 122: 444,
  123: 480, 124: 200, 125: 480, 126: 541,
  8216: 333, 8217: 333, 8220: 500, 8221: 500, 8211: 500, 8212: 1000,
  8218: 333, 8226: 350, 8230: 1000, 8260: 266, 8364: 500,
  8224: 500, 8225: 500, 8240: 1000, 8249: 333, 8250: 333,
  8482: 1000, 65533: 500, 9733: 700,
};

const double fs = 12; // font size — nothing below 12 pt anywhere

double textW(String s, {bool bold = false}) {
  var u = 0;
  for (final code in s.codeUnits) {
    u += _tw[code] ?? 500;
  }
  final w = u / 1000 * fs;
  return bold ? w * 1.05 : w;
}

String esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Word wrap on spaces, breaking at underscores when a token still overflows.
List<String> wrap(String s, double maxW) {
  final out = <String>[];
  var line = '';
  for (final raw in s.split(' ')) {
    var tok = raw;
    // break oversized single tokens at underscores
    while (textW(tok) > maxW && tok.contains('_')) {
      final i = tok.lastIndexOf('_', tok.length - 1);
      final head = tok.substring(0, i);
      if (line.isEmpty && textW('$head') <= maxW) {
        // try to keep prefix on current (empty) line
      }
      if (textW('$line$head'.trim()) <= maxW || line.isEmpty) {
        line = line.isEmpty ? head : '$line $head';
        out.add(line);
        line = '';
        tok = tok.substring(i + 1);
      } else {
        out.add(line);
        line = '';
      }
    }
    final cand = line.isEmpty ? tok : '$line $tok';
    if (textW(cand) <= maxW) {
      line = cand;
    } else {
      if (line.isNotEmpty) out.add(line);
      line = tok;
    }
  }
  if (line.isNotEmpty) out.add(line);
  return out.isEmpty ? [''] : out;
}

// ---------------------------------------------------------------------------
// Layout constants (all in pt; page = 720 x 540 = 10 x 7.5 in landscape)
// ---------------------------------------------------------------------------
const double rowH = 15;
const double headH = 21;
const double pad = 8;
const double colGap = 14;
const double markW = 20; // PK / FK column
const double nameGap = 4;
const double typeGap = 10;

class Paint {
  final StringBuffer _b = StringBuffer();
  void add(String s) => _b.write(s);
  String get svg => _b.toString();
}

String text(double x, double y, String s,
    {String anchor = 'start',
    bool bold = false,
    String fill = '#111',
    String? deco,
    String cls = 't'}) {
  final b = bold ? ' font-weight="bold"' : '';
  final d = deco != null ? ' text-decoration="$deco"' : '';
  return '<text x="${f(x)}" y="${f(y)}" text-anchor="$anchor" '
      'class="$cls"$b fill="$fill"$d>${esc(s)}</text>';
}

String f(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2);

String rect(double x, double y, double w, double h,
    {String fill = 'none', String stroke = '#222', double sw = 1, String? dash}) {
  final d = dash != null ? ' stroke-dasharray="$dash"' : '';
  return '<rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}" '
      'fill="$fill" stroke="$stroke" stroke-width="$sw"$d/>';
}

String line(double x1, double y1, double x2, double y2,
    {String stroke = '#222', double sw = 1, String? dash, String cap = 'butt'}) {
  final d = dash != null ? ' stroke-dasharray="$dash"' : '';
  return '<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" '
      'stroke="$stroke" stroke-width="$sw" stroke-linecap="$cap"$d/>';
}

// ---------------------------------------------------------------------------
// Entity box
// ---------------------------------------------------------------------------
class Box {
  final Tbl t;
  final double x, y;
  final int split;
  final List<Rel> strip; // circular connectors drawn inside the box footer
  late final List<List<Col>> groups;
  late final List<double> colW;
  late final double w, h;
  late final double stripH;

  Box(this.t, this.x, this.y, {this.split = 1, this.strip = const []}) {
    final n = t.cols.length;
    final per = (n / split).ceil();
    groups = [
      for (var i = 0; i < split; i++)
        t.cols.sublist(i * per, i * per + per > n ? n : i * per + per)
    ].where((g) => g.isNotEmpty).toList();

    colW = groups.map((g) {
      var nameW = 0.0, typeW = 0.0;
      for (final c in g) {
        nameW = nameW > textW(_nameOf(c)) ? nameW : textW(_nameOf(c));
        typeW = typeW > textW(c.displayType) ? typeW : textW(c.displayType);
      }
      return pad + markW + nameGap + nameW + typeGap + typeW + pad;
    }).toList();

    w = colW.reduce((a, b) => a + b) + (colW.length - 1) * colGap;
    final rows = groups.map((g) => g.length).reduce((a, b) => a > b ? a : b);
    stripH = _stripLayout().isEmpty
        ? 0
        : _stripLayout().fold<double>(0, (a, s) => a + s.$1) + pad;
    h = headH + rows * rowH + pad + stripH;
  }

  String _nameOf(Col c) =>
      c.name + (c.dep ? ' (deprecated)' : '') + (c.mig ? ' *' : '');

  /// Returns (rowHeight, <circle, lines>) entries for the connector strip.
  List<(double, List<(String, List<String>)>)> _stripLayout() {
    if (strip.isEmpty) return [];
    final inner = w - 2 * pad;
    // choose the wrap (1..n per row) that yields the shortest strip
    List<(double, List<(String, List<String>)>)> best = [];
    var bestH = 1e9;
    for (var per = 1; per <= strip.length; per++) {
      final pitch = inner / per;
      final r = <(double, List<(String, List<String>)>)>[];
      for (var i = 0; i < strip.length; i += per) {
        var rowMax = 0.0;
        final items = <(String, List<String>)>[];
        for (var j = i; j < i + per && j < strip.length; j++) {
          final lbl = strip[j].child;
          final lines = wrap(lbl, pitch - 4);
          final lh = lines.length * 15.0;
          rowMax = 26 + 3 + lh;
          items.add((strip[j].id, lines));
        }
        r.add((rowMax + 3, items));
      }
      final tot = r.fold<double>(0, (a, s) => a + s.$1);
      if (tot < bestH) {
        bestH = tot;
        best = r;
      }
    }
    return best;
  }

  double get bodyY => y + headH;
  double get stripTop => y + h - stripH;

  String render() {
    final b = StringBuffer();
    b.write(rect(x, y, w, h, fill: '#fff'));
    // header
    b.write(rect(x, y, w, headH, fill: '#dbe5ef', stroke: '#222'));
    b.write(line(x, y + headH, x + w, y + headH));
    b.write(text(x + w / 2, y + headH - 6, t.name, anchor: 'middle', bold: true));

    // attribute columns
    final rows = groups.map((g) => g.length).reduce((a, b) => a > b ? a : b);
    var cx = x;
    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      final cw = colW[gi];
      if (gi > 0) b.write(line(cx - colGap / 2, y + headH, cx - colGap / 2, y + headH + rows * rowH, stroke: '#bbb'));
      for (var ri = 0; ri < g.length; ri++) {
        final c = g[ri];
        final ry = y + headH + ri * rowH;
        if (c.kind == 'fk') {
          b.write(rect(cx, ry, cw, rowH, fill: '#f2f7fc', stroke: 'none'));
        }
        final baseline = ry + rowH - 3.5;
        final mark = c.kind == 'pk' ? 'PK' : (c.kind == 'fk' ? 'FK' : '');
        if (mark.isNotEmpty) {
          b.write(text(cx + pad, baseline, mark, bold: true, fill: '#0b3d91'));
        }
        final nm = _nameOf(c);
        b.write(text(cx + pad + markW, baseline, nm,
            bold: c.kind == 'pk'));
        b.write(text(cx + cw - pad, baseline, c.displayType, anchor: 'end',
            fill: c.dep ? '#666' : '#111',
            deco: c.dep ? 'line-through' : null));
      }
      cx += cw + colGap;
    }

    // connector strip
    if (strip.isNotEmpty) {
      final sl = _stripLayout();
      b.write(line(x, stripTop, x + w, stripTop, stroke: '#88a', dash: '4 3'));
      final inner = w - 2 * pad;
      final per = sl.first.$2.length;
      final pitch = inner / per;
      var sy = stripTop + pad / 2;
      for (final (rh, items) in sl) {
        for (var i = 0; i < items.length; i++) {
          final (cid, lines) = items[i];
          final cxp = x + pad + pitch * (i + 0.5);
          b.write(circle(cxp, sy + 13, cid));
          for (var li = 0; li < lines.length; li++) {
            b.write(text(cxp, sy + 26 + 3 + li * 15 + 11, lines[li],
                anchor: 'middle'));
          }
        }
        sy += rh;
      }
    }
    return b.toString();
  }
}

/// Circular connector: R-id inside, counterpart table name rendered below by
/// the caller (or inside an entity strip / beside an external list).
String circle(double cx, double cy, String id, {bool dashed = false}) {
  final r = (textW(id, bold: true) / 2 + 6).clamp(13.0, 20.0);
  final d = dashed ? ' stroke-dasharray="3 2"' : '';
  return '<circle cx="${f(cx)}" cy="${f(cy)}" r="${f(r)}" fill="#fff" '
      'stroke="#0b3d91" stroke-width="1.4"$d/>'
      '${text(cx, cy + 4.2, id, anchor: 'middle', bold: true, fill: '#0b3d91')}';
}

double circleR(String id) => (textW(id, bold: true) / 2 + 6).clamp(13.0, 20.0);
