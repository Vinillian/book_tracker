/// Opacity of a heatmap cell (0.25..1.0) for a day's [intensity].
///
/// Checkbox/step-only intensity uses its historical unit scale. The current
/// mixed-task heatmap uses the time-point scale for every tracked row: each
/// checkbox/step unit and each 20 minutes contributes one point; three points
/// reach full saturation.
double heatAlpha(num intensity, {bool isDuration = false}) {
  final raw = isDuration
      ? 0.25 + intensity / 3 * 0.75
      : 0.25 + intensity * 0.15;
  return raw.clamp(0.25, 1.0).toDouble();
}
