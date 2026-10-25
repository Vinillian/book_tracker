/// Opacity of a heatmap cell (0.25..1.0) for a day's [intensity].
///
/// Checkbox and step tasks count whole units, 0.15 per unit. A duration task
/// counts minutes, so it is scaled instead: the cell is fully saturated at an
/// hour a day (#112).
double heatAlpha(int intensity, {bool isDuration = false}) {
  final raw = isDuration ? 0.25 + intensity / 60 * 0.75 : 0.25 + intensity * 0.15;
  return raw.clamp(0.25, 1.0).toDouble();
}
