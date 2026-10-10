import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Clamp für zentriertes Zoom-Blatt (`Alignment.center`, Blatt in [Center]).
///
/// Während der Geste: `boundaryMargin: EdgeInsets.all(double.infinity)` lassen,
/// damit Pinch nicht gegen die Boundary kämpft. Danach hiermit zurückholen,
/// damit das Blatt nicht aus dem Screen verschwindet.
Matrix4 clampCenteredZoomMatrix({
  required Matrix4 input,
  required Size viewport,
  required Size content,
  double resetBelowScale = 1.08,
}) {
  final scale = input.getMaxScaleOnAxis();
  if (scale <= resetBelowScale) {
    return Matrix4.identity();
  }

  final tx = input.storage[12];
  final ty = input.storage[13];
  final scaledW = content.width * scale;
  final scaledH = content.height * scale;

  // Bei Center-Origin: Pan nur soweit, bis die Kanten des gezoomten Contents
  // am Viewport anliegen — nie komplett wegschieben.
  final overflowX = math.max(0.0, (scaledW - viewport.width) / 2);
  final overflowY = math.max(0.0, (scaledH - viewport.height) / 2);
  final clampedTx = tx.clamp(-overflowX, overflowX);
  final clampedTy = ty.clamp(-overflowY, overflowY);

  if (clampedTx == tx && clampedTy == ty) {
    return input;
  }

  final out = Matrix4.copy(input);
  out.storage[12] = clampedTx.toDouble();
  out.storage[13] = clampedTy.toDouble();
  return out;
}
