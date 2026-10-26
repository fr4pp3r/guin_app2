#!/usr/bin/env dart
/// CiteEase ERD generator — Times New Roman 12, landscape, multi-page.
/// Outputs: erd/out/CiteEase_ERD.svg, erd/out/CiteEase_ERD_Part1.svg, erd/out/CiteEase_ERD_Part2.svg,
///         erd/out/CiteEase_ERD.html, erd/out/README_Connections.txt
library;

import 'dart:io';
import 'src/schema.dart';
import 'src/rels.dart';
import 'src/draw.dart';

const pw = 720.0; // 10 in
const ph = 540.0; // 7.5 in
const m = 18.0;   // margin

const String headCss = '''
<style>
  @page { size: 10in 7.5in; margin: 0.25in; }
  svg { page-break-after: always; }
  svg:last-child { page-break-after: auto; }
  text.t { font-family: 'Times New Roman', Times, serif; font-size: 12pt; }
</style>
''';

String header(String title, String subtitle) =>
  '<g class="hdr">'
  '${text(m, 14, title, bold: true)}'
  '${text(m, 28, subtitle)}'
  '${line(m, 34, pw - m, 34)}'
  '</g>';

String footer(int p, int n) =>
  text(pw - m, ph - 10, 'Page $p of $n | CiteEase ERD | Times New Roman, 12pt',
      anchor: 'end');

String legend() {
  final b = StringBuffer();
  const lx = m, ly = ph - 128;
  b.write(rect(lx, ly, 192, 118, fill: '#fff'));
  b.write(text(lx + 6, ly + 14, 'LEGEND', bold: true));
  b.write(line(lx, ly + 18, lx + 192, ly + 18));
  // PK
  b.write(text(lx + 6, ly + 32, 'PK', bold: true, fill: '#0b3d91'));
  b.write(text(lx + 28, ly + 32, 'Primary Key'));
  // FK
  b.write(rect(lx + 6, ly + 38, 16, 10, fill: '#f2f7fc', stroke: '#222'));
  b.write(text(lx + 14, ly + 45, 'FK', bold: true, fill: '#0b3d91'));
  b.write(text(lx + 28, ly + 45, 'Foreign Key'));
  // deprecated
  b.write(text(lx + 6, ly + 59, 'old_attr (deprecated)', deco: 'line-through', fill: '#666'));
  b.write(text(lx + 136, ly + 59, 'Deprecated/unused'));
  // migration
  b.write(text(lx + 6, ly + 73, 'attr *', bold: false));
  b.write(text(lx + 40, ly + 73, 'Added by migration'));
  // logical
  b.write(line(lx + 6, ly + 83, lx + 22, ly + 83, dash: '4 3'));
  b.write(text(lx + 28, ly + 87, 'Logical / app-level (no FK)'));
  // cardinality
  b.write(text(lx + 6, ly + 101, '(1)', bold: true));
  b.write(line(lx + 18, ly + 98, lx + 38, ly + 98));
  b.write(text(lx + 44, ly + 101, '(M)', bold: true));
  b.write(text(lx + 56, ly + 101, '1 : M'));
  // connector
  b.write(circle(lx + 14, ly + 112, 'R#'));
  b.write(text(lx + 28, ly + 116, 'Cross-page connector'));
  return b.toString();
}

String sym(String s) => s == '1' ? '(1)' : '(M)';

String connLine(Box aBox, double ax, double ay, Box bBox, double bx, double by,
    Paint p, {String dash = '', bool rev = false}) {
  // draw polyline; caller passes preferred route points conceptually
  // use straight-ish routed orthogonal segments stored implicitly
  final midx = (ax + bx) / 2;
  // We'll build via the public line helper by writing path
  final d = dash.isEmpty ? '' : ' stroke-dasharray="$dash"';
  final sw = dash.isEmpty ? 1.0 : 1.2;
  // path: ax,ay -> midx,ay -> midx,by -> bx,by (elbow)
  p.add('<path d="M ${f(ax)} ${f(ay)} L ${f(midx)} ${f(ay)} L ${f(midx)} ${f(by)} L ${f(bx)} ${f(by)}" '
      'fill="none" stroke="#222" stroke-width="$sw"$d/>');
  // ticks
  final x1 = ax > bx ? -1.0 : 1.0; // direction
  if (rev) {
    tick(p, bx, by, -x1, 0);
    tick(p, bx + (bx > ax ? -10 : 10), by, -x1, 0);
    tick(p, ax, ay, x1, 0);
  } else {
    tick(p, ax, ay, -x1, 0);
    tick(p, bx, by, x1, 0);
  }
  // cardinality labels
  final tx1x = ax + (ax > bx ? -14 : 6), ty1 = ay - 3;
  final tx2x = bx + (bx > ax ? 6 : -14), ty2 = by - 3;
  p.add(text(tx1x, ty1, sym(rev ? 'M' : '1'), bold: true));
  p.add(text(tx2x, ty2, sym(rev ? '1' : 'M'), bold: true));
  return '';
}

void tick(Paint p, double x, double y, double dx, double dy) {
  // perpendicular tick for vertical/horizontal segments
  if (dy == 0) {
    // horizontal line; tick vertical
    p.add(line(x, y - 5, x, y + 5, stroke: '#222'));
  } else {
    p.add(line(x - 5, y, x + 5, y, stroke: '#222'));
  }
}

String svgOpen(String title) =>
  '<?xml version="1.0" encoding="UTF-8"?>\n'
  '<svg xmlns="http://www.w3.org/2000/svg" width="10in" height="7.5in" '
  'viewBox="0 0 $pw $ph">\n'
  '<defs><style>.t { font-family: "Times New Roman", Times, serif; font-size: 12pt; }</style></defs>\n'
  '<rect width="100%" height="100%" fill="#fff"/>\n'
  '$headCss\n'
  '<g font-family="Times New Roman, Times, serif" font-size="12pt">';

String svgClose() => '</g>\n</svg>\n';

void main() {
  final dir = Directory('erd/out');
  dir.createSync(recursive: true);

  // Group definitions
  final userM = ['users_profile', 'kyc_guarantors'];
  final refM = ['barangay_config', 'document_fees', 'emergency_hotlines', 'announcements'];
  final docM = ['document_requests', 'barangay_id_details', 'indigency_details', 'cedula_details'];
  final payM = ['payments', 'document_versions', 'document_verifications', 'document_print_copies'];
  final incM = ['incident_reports', 'incident_updates', 'incident_attachments', 'identity_access_logs'];
  final sysM = ['notifications', 'audit_logs', 'role_permissions'];

  // PART 1: User management, reference, document requests core
  final boxes1 = <Box>[];
  // users_profile centered-top area conceptually; split into 2 columns to save width
  boxes1.add(Box(table('users_profile'), m, 42, split: 2));
  boxes1.add(Box(table('kyc_guarantors'), boxes1[0].x + boxes1[0].w + 36, 42));
  boxes1.add(Box(table('barangay_config'), m, boxes1[0].y + boxes1[0].h + 24));
  boxes1.add(Box(table('document_fees'), boxes1[2].x + boxes1[2].w + 18, boxes1[0].y + boxes1[0].h + 24));
  boxes1.add(Box(table('emergency_hotlines'), boxes1[3].x + boxes1[3].w + 18, boxes1[0].y + boxes1[0].h + 24));
  boxes1.add(Box(table('announcements'), boxes1[4].x + boxes1[4].w + 18, boxes1[0].y + boxes1[0].h + 24));
  boxes1.add(Box(table('document_requests'), m, boxes1[2].y + boxes1[2].h + 28, split: 3));
  // detail tables below/left
  boxes1.add(Box(table('barangay_id_details'), boxes1[6].x, boxes1[6].y + boxes1[6].h + 20));
  boxes1.add(Box(table('indigency_details'), boxes1[7].x + boxes1[7].w + 16, boxes1[6].y + boxes1[6].h + 20));
  boxes1.add(Box(table('cedula_details'), boxes1[8].x + boxes1[8].w + 16, boxes1[6].y + boxes1[6].h + 20));

  // PART 2: payments/verification/print, incidents, system
  final boxes2 = <Box>[];
  boxes2.add(Box(table('payments'), m, 42));
  boxes2.add(Box(table('document_versions'), boxes2[0].x + boxes2[0].w + 18, 42));
  boxes2.add(Box(table('document_verifications'), m, boxes2[0].y + boxes2[0].h + 22));
  boxes2.add(Box(table('document_print_copies'), boxes2[2].x + boxes2[2].w + 18, boxes2[2].y, split: 2));
  boxes2.add(Box(table('incident_reports'), m, boxes2[2].y + boxes2[2].h + 28, split: 2));
  boxes2.add(Box(table('incident_updates'), boxes2[4].x, boxes2[4].y + boxes2[4].h + 18));
  boxes2.add(Box(table('incident_attachments'), boxes2[5].x + boxes2[5].w + 16, boxes2[4].y + boxes2[4].h + 18));
  boxes2.add(Box(table('identity_access_logs'), boxes2[6].x + boxes2[6].w + 16, boxes2[4].y + boxes2[4].h + 18));
  boxes2.add(Box(table('notifications'), boxes2[4].x + boxes2[4].w + 36, 42));
  boxes2.add(Box(table('audit_logs'), boxes2[4].x + boxes2[4].w + 36, boxes2[8].y + boxes2[8].h + 18, split: 2));
  boxes2.add(Box(table('role_permissions'), boxes2[4].x + boxes2[4].w + 36, boxes2[9].y + boxes2[9].h + 18));

  // Build map name -> box for drawing connections
  Map<String, Box> m1 = {for (var b in boxes1) b.t.name: b};
  Map<String, Box> m2 = {for (var b in boxes2) b.t.name: b};

  // Draw part 1
  final p1 = Paint();
  p1.add(svgOpen(''));
  p1.add(header('CiteEase Thesis Project — Entity-Relationship Diagram (ERD)',
      'Part 1 of 2 | Functional Groups: User Management, KYC/Guarantors, Reference Data, Document Requests & Detail Tables'));
  // draw connections on part 1
  drawConn(p1, m1, rel('R1'), [m1['users_profile']!, m1['document_requests']!], side: 'left');
  drawConn(p1, m1, rel('R7'), [m1['users_profile']!, m1['kyc_guarantors']!], side: 'top');
  drawConn(p1, m1, rel('R8'), [m1['users_profile']!, m1['users_profile']!], side: 'right', self: true);
  drawConn(p1, m1, rel('R4'), [m1['users_profile']!, m1['announcements']!], side: 'top');
  drawConn(p1, m1, rel('R5'), [m1['users_profile']!, m1['emergency_hotlines']!], side: 'top');
  drawConn(p1, m1, rel('R16'), [m1['document_requests']!, m1['barangay_id_details']!], side: 'bottom');
  drawConn(p1, m1, rel('R17'), [m1['document_requests']!, m1['indigency_details']!], side: 'bottom');
  drawConn(p1, m1, rel('R18'), [m1['document_requests']!, m1['cedula_details']!], side: 'bottom');
  drawConn(p1, m1, rel('R27'), [m1['document_fees']!, m1['document_requests']!], side: 'top', dashed: true);
  // render boxes
  for (var b in boxes1) p1.add(b.render());
  // cross-page connectors: add circles to boxes that have relationships continuing elsewhere
  // attach connector strip entries for relationships to part 2
  _attachStrip(m1['users_profile']!, [rel('R2'), rel('R3'), rel('R6'), rel('R9'), rel('R10'), rel('R11'), rel('R12'), rel('R13'), rel('R14'), rel('R15'), rel('R23')]);
  _attachStrip(m1['document_requests']!, [rel('R19'), rel('R20'), rel('R21'), rel('R22'), rel('R23')]);
  // re-render affected boxes on top? no; we need to rebuild. Instead render before adding strips; easier to rebuild layout with strips.
  p1.add(legend());
  p1.add(footer(1, 2));
  p1.add(svgClose());
  File('erd/out/CiteEase_ERD_Part1.svg').writeAsStringSync(p1.svg);

  // rebuild part 1 with strips properly attached
  final boxes1b = <Box>[];
  final users = Box(table('users_profile'), m, 42, split: 2, strip: [rel('R2'), rel('R3'), rel('R6'), rel('R9'), rel('R10'), rel('R11'), rel('R12'), rel('R13'), rel('R14'), rel('R15'), rel('R23')]);
  final kycg = Box(table('kyc_guarantors'), users.x + users.w + 36, 42);
  boxes1b.add(users); boxes1b.add(kycg);
  final bconf = Box(table('barangay_config'), m, users.y + users.h + 24);
  final bfees = Box(table('document_fees'), bconf.x + bconf.w + 18, users.y + users.h + 24);
  final bhot = Box(table('emergency_hotlines'), bfees.x + bfees.w + 18, users.y + users.h + 24);
  final bann = Box(table('announcements'), bhot.x + bhot.w + 18, users.y + users.h + 24);
  boxes1b.add(bconf); boxes1b.add(bfees); boxes1b.add(bhot); boxes1b.add(bann);
  final dreq = Box(table('document_requests'), m, bconf.y + bconf.h + 28, split: 3, strip: [rel('R19'), rel('R20'), rel('R21'), rel('R22'), rel('R23')]);
  boxes1b.add(dreq);
  final bid = Box(table('barangay_id_details'), dreq.x, dreq.y + dreq.h + 20);
  final ind = Box(table('indigency_details'), bid.x + bid.w + 16, dreq.y + dreq.h + 20);
  final ced = Box(table('cedula_details'), ind.x + ind.w + 16, dreq.y + dreq.h + 20);
  boxes1b.add(bid); boxes1b.add(ind); boxes1b.add(ced);
  Map<String, Box> m1b = {for (var b in boxes1b) b.t.name: b};
  final p1b = Paint();
  p1b.add(svgOpen(''));
  p1b.add(header('CiteEase Thesis Project — Entity-Relationship Diagram (ERD)',
      'Part 1 of 2 | User Management, KYC/Guarantors, Reference Data, Document Requests & Detail Tables'));
  drawConn(p1b, m1b, rel('R1'), [m1b['users_profile']!, m1b['document_requests']!], side: 'left');
  drawConn(p1b, m1b, rel('R7'), [m1b['users_profile']!, m1b['kyc_guarantors']!], side: 'top');
  drawConn(p1b, m1b, rel('R8'), [m1b['users_profile']!, m1b['users_profile']!], side: 'right', self: true);
  drawConn(p1b, m1b, rel('R4'), [m1b['users_profile']!, m1b['announcements']!], side: 'top');
  drawConn(p1b, m1b, rel('R5'), [m1b['users_profile']!, m1b['emergency_hotlines']!], side: 'top');
  drawConn(p1b, m1b, rel('R16'), [m1b['document_requests']!, m1b['barangay_id_details']!], side: 'bottom');
  drawConn(p1b, m1b, rel('R17'), [m1b['document_requests']!, m1b['indigency_details']!], side: 'bottom');
  drawConn(p1b, m1b, rel('R18'), [m1b['document_requests']!, m1b['cedula_details']!], side: 'bottom');
  drawConn(p1b, m1b, rel('R27'), [m1b['document_fees']!, m1b['document_requests']!], side: 'top', dashed: true);
  for (var b in boxes1b) p1b.add(b.render());
  p1b.add(legend());
  p1b.add(footer(1, 2));
  p1b.add(svgClose());
  File('erd/out/CiteEase_ERD_Part1.svg').writeAsStringSync(p1b.svg);

  // Part 2
  final boxes2b = <Box>[];
  boxes2b.add(Box(table('payments'), m, 42));
  boxes2b.add(Box(table('document_versions'), boxes2b[0].x + boxes2b[0].w + 18, 42));
  boxes2b.add(Box(table('document_verifications'), m, boxes2b[0].y + boxes2b[0].h + 22));
  boxes2b.add(Box(table('document_print_copies'), boxes2b[2].x + boxes2b[2].w + 18, boxes2b[2].y, split: 2));
  boxes2b.add(Box(table('incident_reports'), m, boxes2b[2].y + boxes2b[2].h + 28, split: 2));
  boxes2b.add(Box(table('incident_updates'), boxes2b[4].x, boxes2b[4].y + boxes2b[4].h + 18));
  boxes2b.add(Box(table('incident_attachments'), boxes2b[5].x + boxes2b[5].w + 16, boxes2b[4].y + boxes2b[4].h + 18));
  boxes2b.add(Box(table('identity_access_logs'), boxes2b[6].x + boxes2b[6].w + 16, boxes2b[4].y + boxes2b[4].h + 18));
  boxes2b.add(Box(table('notifications'), pw - m - 200, 42));
  boxes2b.add(Box(table('audit_logs'), pw - m - 200, boxes2b[8].y + boxes2b[8].h + 18, split: 2));
  boxes2b.add(Box(table('role_permissions'), pw - m - 200, boxes2b[9].y + boxes2b[9].h + 18));
  Map<String, Box> m2b = {for (var b in boxes2b) b.t.name: b};
  final p2 = Paint();
  p2.add(svgOpen(''));
  p2.add(header('CiteEase Thesis Project — Entity-Relationship Diagram (ERD)',
      'Part 2 of 2 | Payments, Document Verification & Print Copies, Incident Reporting, Notifications, Audit Logs & Role Permissions'));
  drawConn(p2, m2b, rel('R19'), [m1b['document_requests']!, m2b['payments']!], side: 'cross', dashed: false, cross: true);
  drawConn(p2, m2b, rel('R20'), [m1b['document_requests']!, m2b['document_versions']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R21'), [m1b['document_requests']!, m2b['document_verifications']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R22'), [m1b['document_requests']!, m2b['document_print_copies']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R23'), [m1b['document_requests']!, m2b['audit_logs']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R2'), [m1b['users_profile']!, m2b['payments']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R3'), [m1b['users_profile']!, m2b['notifications']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R6'), [m1b['users_profile']!, m2b['audit_logs']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R9'), [m1b['users_profile']!, m2b['incident_reports']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R13'), [m1b['users_profile']!, m2b['document_versions']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R14'), [m1b['users_profile']!, m2b['document_verifications']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R15'), [m1b['users_profile']!, m2b['document_print_copies']!], side: 'cross', cross: true);
  drawConn(p2, m2b, rel('R24'), [m2b['incident_reports']!, m2b['incident_updates']!], side: 'bottom');
  drawConn(p2, m2b, rel('R25'), [m2b['incident_reports']!, m2b['incident_attachments']!], side: 'bottom');
  drawConn(p2, m2b, rel('R26'), [m2b['incident_reports']!, m2b['identity_access_logs']!], side: 'bottom');
  drawConn(p2, m2b, rel('R28'), [m1b['users_profile']!, m2b['role_permissions']!], side: 'cross', dashed: true, cross: true);
  drawConn(p2, m2b, rel('R29'), [m2b['document_verifications']!, m2b['document_print_copies']!], side: 'top', dashed: true);
  for (var b in boxes2b) p2.add(b.render());
  // add R-id circles on part 2 for incoming connections
  _addExternal(p2, m2b, rel('R19'), m1b['document_requests']!);
  _addExternal(p2, m2b, rel('R20'), m1b['document_requests']!);
  _addExternal(p2, m2b, rel('R21'), m1b['document_requests']!);
  _addExternal(p2, m2b, rel('R22'), m1b['document_requests']!);
  _addExternal(p2, m2b, rel('R23'), m1b['document_requests']!);
  _addExternal(p2, m2b, rel('R2'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R3'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R6'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R9'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R13'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R14'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R15'), m1b['users_profile']!);
  _addExternal(p2, m2b, rel('R28'), m1b['users_profile']!);
  p2.add(legend());
  p2.add(footer(2, 2));
  p2.add(svgClose());
  File('erd/out/CiteEase_ERD_Part2.svg').writeAsStringSync(p2.svg);

  // combined HTML for Word import
  final html = '<!DOCTYPE html><html><head><meta charset="utf-8">${headCss}</head><body>'
    '${File('erd/out/CiteEase_ERD_Part1.svg').readAsStringSync()}'
    '${File('erd/out/CiteEase_ERD_Part2.svg').readAsStringSync()}'
    '</body></html>';
  File('erd/out/CiteEase_ERD.html').writeAsStringSync(html);

  // Relationship index
  final idx = StringBuffer();
  idx.writeln('CiteEase ERD — Relationship Index');
  idx.writeln('Times New Roman, 12pt | All relationships from setup.sql + documented FKs');
  idx.writeln('');
  for (final r in fkList) {
    idx.writeln('${r.id}: ${r.parent} (1) —< ${r.child} (M)  ${r.dagger ? "[1:1-app]" : ""}  ${r.logical ? "[logical/no-FK]" : ""}');
    idx.writeln('   FK/Join: ${r.cols.join(', ')}');
    idx.writeln('');
  }
  idx.writeln('Entities: ${tables.length} tables (21). Columns marked * = added by migration (20261017_name_fields, 20261018_id_back_url).');
  idx.writeln('(deprecated) = unused/deprecated by schema notes.');
  File('erd/out/README_Connections.txt').writeAsStringSync(idx.toString());

  print('Done. Output in erd/out/');
}

void _attachStrip(Box b, List<Rel> rs) {
  // We rebuild boxes with strip; placeholder.
}

void _addExternal(Paint p, Map<String, Box> m2b, Rel r, Box from) {
  final to = m2b[r.child] ?? m2b[r.parent];
  if (to == null) return;
  final cr = circleR(r.id);
  // place near left side pointing in
  final cx = to.x - 16;
  final cy = to.y + headH + 28;
  p.add('<g><line x1="${f(cx + cr)}" y1="${f(cy)}" x2="${f(to.x)}" y2="${f(cy)}" stroke="#0b3d91" stroke-dasharray="4 3"/>' 
      '${circle(cx, cy, r.id, dashed: true)}' 
      '${text(cx, cy + cr + 12, from.t.name, anchor: "middle")}</g>');
}

void drawConn(Paint p, Map<String, Box> m, Rel r, List<Box> pair,
    {String side = 'right', bool self = false, bool dashed = false, bool cross = false}) {
  if (pair.length != 2) return;
  final a = pair[0], b = pair[1];
  final sw = dashed ? '1.2' : '1';
  final d = dashed ? ' stroke-dasharray="4 3"' : '';
  if (self) {
    // small loop on right side of users_profile
    final x = a.x + a.w, y = a.y + headH + 14;
    p.add('<path d="M ${f(x)} ${f(y)} L ${f(x+26)} ${f(y)} L ${f(x+26)} ${f(y+40)} L ${f(x)} ${f(y+40)}" '
        'fill="none" stroke="#222" stroke-width="$sw"$d/>');
    p.add(text(x+30, y+10, r.id, bold: true, fill: '#0b3d91'));
    p.add(text(x+8, y-3, '(1)', bold: true));
    p.add(text(x+8, y+53, '(M)', bold: true));
    p.add(text(x+30, y+54, r.child == r.parent ? 'kyc_reviewed_by' : r.cols.join(','), fill: '#333'));
    return;
  }
  if (side == 'top') {
    final ax = a.x + a.w / 2, ay = a.y;
    final bx = b.x + b.w / 2, by = b.y + b.h;
    p.add('<path d="M ${f(ax)} ${f(ay)} L ${f(ax)} ${f(ay - 14)} L ${f(bx)} ${f(by + 14)} L ${f(bx)} ${f(by)}" '
        'fill="none" stroke="#222" stroke-width="$sw"$d/>');
    p.add(text(ax - 14, ay - 18, '(1)', bold: true));
    p.add(text(bx - 14, by + 28, '(M)', bold: true));
    p.add(text(ax, ay - 30, r.id, anchor: 'middle', bold: true, fill: '#0b3d91'));
    return;
  }
  if (side == 'bottom') {
    final ax = a.x + a.w / 2, ay = a.y + a.h;
    final bx = b.x + b.w / 2, by = b.y;
    p.add('<path d="M ${f(ax)} ${f(ay)} L ${f(ax)} ${f(ay + 14)} L ${f(bx)} ${f(by - 14)} L ${f(bx)} ${f(by)}" '
        'fill="none" stroke="#222" stroke-width="$sw"$d/>');
    p.add(text(ax - 14, ay + 28, '(1)', bold: true));
    p.add(text(bx - 14, by - 18, '(M)', bold: true));
    p.add(text(ax, ay + 40, r.id, anchor: 'middle', bold: true, fill: '#0b3d91'));
    return;
  }
  if (side == 'left') {
    final ax = a.x, ay = a.y + a.h / 2;
    final bx = b.x + b.w, by = b.y + b.h / 2;
    p.add('<path d="M ${f(ax)} ${f(ay)} L ${f(ax - 16)} ${f(ay)} L ${f(bx + 16)} ${f(by)} L ${f(bx)} ${f(by)}" '
        'fill="none" stroke="#222" stroke-width="$sw"$d/>');
    p.add(text(ax - 30, ay - 3, '(1)', bold: true));
    p.add(text(bx + 20, by - 3, '(M)', bold: true));
    p.add(text(ax - 30, ay + 12, r.id, bold: true, fill: '#0b3d91'));
    return;
  }
  // cross-page: draw dashed connector with label and pointer; actual target on other page indicated by circles
  if (cross) {
    final ax = a.x + a.w / 2, ay = a.y + a.h;
    // curve down and out to indicate continuation
    p.add('<path d="M ${f(ax)} ${f(ay)} C ${f(ax)} ${f(ay + 40)} ${f(ax + 60)} ${f(ay + 40)} ${f(ax + 80)} ${f(ay + 40)}" '
        'fill="none" stroke="#0b3d91" stroke-width="1.4" stroke-dasharray="4 3"/>');
    p.add(text(ax + 84, ay + 44, r.id, bold: true, fill: '#0b3d91'));
    p.add(text(ax - 14, ay + 14, '(1)', bold: true));
    p.add(text(ax + 88, ay + 30, '→ Part 2', bold: true));
    return;
  }
}
