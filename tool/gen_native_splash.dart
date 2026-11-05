// tool/gen_native_splash.dart
//
// Generates the per-flavor NATIVE (cold-start) splash artwork from a client's
// sheikh photo, so the Android native splash matches the Flutter SplashPage
// (gold-ring circular avatar on the flavor background) — cold start then reads
// as one continuous screen instead of two.
//
// Output: a full-bleed OPAQUE PNG (filled with the flavor background colour)
// holding a gold-ring circular crop of the sheikh photo, centred.
//
// Why opaque, not transparent: Android 12+ renders `windowSplashScreenAnimatedIcon`
// in one of two modes. A transparent/foreground-only icon is TRIMMED and scaled
// up to a small foreground slot, which pushes the gold ring to the mask edge
// where the launcher's icon shape (a squircle on Pixel) shaves its corners. An
// OPAQUE icon is treated as "icon with background": the full image is scaled to
// the 240dp circle and masked there, so the ring (at ~57% of the canvas) stays
// well inside the mask and never gets clipped. The baked colour equals the
// splash `color:`, so the masked disc is invisible against the splash background
// — only the gold-ring avatar shows, matching the Flutter SplashPage _Avatar.
//
// Usage: dart run tool/gen_native_splash.dart <client> [faceBiasY]
//   client    — clients/<client>/sheikh.png and client.json must exist
//   faceBiasY — vertical crop bias 0..1 (0 = top, 0.5 = centre, default 0.42;
//               portraits put the face above centre, so bias slightly up to
//               avoid cropping the top of the head).
//
// Called by tool/prepare_client.sh. Output path (staged, git-ignored):
//   assets/generated/native_splash.png
// ignore_for_file: depend_on_referenced_packages
// (dev-only tool script; `image` is resolved transitively, not a lib/ dep.)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// Canvas + geometry. Android 12+ scales the opaque icon to a 240dp circle and
// masks it there, so the ring at _outerDiameter/_canvas (~57%) stays clear of
// the mask edge.
const int _canvas = 1152; // recommended android_12 image size
const int _outerDiameter = 660; // gold ring outer Ø (~57% of canvas)
const int _ring = 18; // ring thickness (matches Flutter's ~2.5% of Ø)

// Gold ring colour — AppColors.gold (#FFB300).
final _gold = img.ColorRgba8(0xFF, 0xB3, 0x00, 0xFF);

// Reads PRIMARY_COLOR ("0xAARRGGBB") from clients/<client>/client.json and
// returns it as an opaque image colour — the flavor splash background.
img.Color _flavorColor(String client) {
  final jsonFile = File('clients/$client/client.json');
  if (!jsonFile.existsSync()) {
    stderr.writeln('error: no client.json at ${jsonFile.path}');
    exit(1);
  }
  final map = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
  final raw = (map['PRIMARY_COLOR'] as String).replaceFirst('0x', '');
  final v = int.parse(raw, radix: 16);
  return img.ColorRgba8((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, 0xFF);
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/gen_native_splash.dart <client> [faceBiasY]',
    );
    exit(1);
  }
  final client = args[0];
  final faceBiasY = args.length > 1 ? double.parse(args[1]) : 0.42;

  final srcPath = 'clients/$client/sheikh.png';
  final srcFile = File(srcPath);
  if (!srcFile.existsSync()) {
    stderr.writeln('error: no sheikh photo at $srcPath');
    exit(1);
  }

  final src =
      img.decodePng(srcFile.readAsBytesSync()) ??
      img.decodeImage(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('error: could not decode $srcPath');
    exit(1);
  }

  // 1) Cover-crop the photo to a square, biased vertically toward the face.
  final side = math.min(src.width, src.height);
  final x0 = ((src.width - side) / 2).round();
  final y0 = ((src.height - side) * faceBiasY).round().clamp(
    0,
    src.height - side,
  );
  final square = img.copyCrop(src, x: x0, y: y0, width: side, height: side);

  // 2) Resize to the inner photo diameter (inside the ring). Force an alpha
  //    channel: opaque source photos (e.g. medhat, no alpha) otherwise can't be
  //    circle-masked — setting alpha would be a no-op and the square corners
  //    would show.
  final photoD = _outerDiameter - 2 * _ring;
  final photo = img
      .copyResize(square, width: photoD, height: photoD)
      .convert(numChannels: 4);

  // 3) Opaque canvas filled with the flavor background colour (see header note
  //    on why opaque). The masked disc is invisible against the matching splash
  //    `color:`, so only the gold-ring avatar reads.
  final canvas = img.Image(width: _canvas, height: _canvas, numChannels: 4);
  img.fill(canvas, color: _flavorColor(client));

  final cx = _canvas ~/ 2;
  final cy = _canvas ~/ 2;

  // 4) Gold ring as an ANNULUS. The interior stays the flavor colour so the
  //    photo's transparent cut-out areas (e.g. ahmed) show the flavor colour,
  //    matching the Flutter _Avatar (ClipOval over the flavor background).
  final outerR = _outerDiameter / 2;
  final innerR = photoD / 2; // ring sits flush against the photo circle
  for (var y = cy - _outerDiameter ~/ 2; y <= cy + _outerDiameter ~/ 2; y++) {
    for (var x = cx - _outerDiameter ~/ 2; x <= cx + _outerDiameter ~/ 2; x++) {
      final dx = x - cx + 0.5;
      final dy = y - cy + 0.5;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d >= innerR && d <= outerR) {
        canvas.setPixel(x, y, _gold);
      }
    }
  }

  // 5) Mask the photo to its circle (alpha 0 outside), then composite it into
  //    the ring. Transparent photo pixels remain transparent.
  final r = photoD / 2;
  for (var y = 0; y < photoD; y++) {
    for (var x = 0; x < photoD; x++) {
      final dx = x - r + 0.5;
      final dy = y - r + 0.5;
      if (dx * dx + dy * dy > r * r) {
        photo.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  img.compositeImage(
    canvas,
    photo,
    dstX: cx - photoD ~/ 2,
    dstY: cy - photoD ~/ 2,
  );

  final outDir = Directory('assets/generated');
  outDir.createSync(recursive: true);
  final outPath = 'assets/generated/native_splash.png';
  File(outPath).writeAsBytesSync(img.encodePng(canvas));

  final ringPct = (_outerDiameter / _canvas * 100).round();
  stdout.writeln('Generated $outPath for "$client"');
  stdout.writeln(
    '  canvas ${_canvas}px (opaque flavor bg), ring Ø $_outerDiameter '
    '(~$ringPct% — inside the 240dp mask), photo Ø $photoD, faceBiasY $faceBiasY',
  );
}
