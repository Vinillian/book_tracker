/// Opacity of a heatmap cell (0.25..1.0) for a day's [intensity].
///
/// Checkbox and step tasks keep their existing whole-unit scale (0.15 per
/// unit). Duration intensity is expressed in points, where 20 minutes equals
/// one point and three points (60 minutes) reach full saturation.
double heatAlpha(num intensity, {bool isDuration = false}) {
  final raw = isDuration
      ? 0.25 + intensity / 3 * 0.75
      : 0.25 + intensity * 0.15;
  return raw.clamp(0.25, 1.0).toDouble();
}
