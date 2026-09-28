/// Einstellbare Flood-Fill- / Anti-Alias-Rand-Stärke.
///
/// Höheres [fringeExpandPasses] / niedriges [fringeLuminanceMin] =
/// weniger weiße Punkte, aber eher Überlaufen bei dünnen Linien.
class FloodFillTuning {
  const FloodFillTuning({
    this.hardLineLuminanceMax = 100,
    this.fillRegionLuminanceMin = 150,
    this.fringeLuminanceMin = 112,
    this.fringeExpandPasses = 2,
    this.fringeDiagonals = true,
  });

  /// Standard: dunkle Fills ohne sichtbare AA-Punkte, leichtes Nachziehen.
  static const standard = FloodFillTuning();

  /// Weicher Rand — bei sehr dicken Linien.
  static const soft = FloodFillTuning(
    fringeExpandPasses: 3,
    fringeLuminanceMin: 105,
    fringeDiagonals: true,
  );

  /// Streng an Linien — mehr mögliche Randpunkte, kein Überlaufen.
  static const tight = FloodFillTuning(
    fringeExpandPasses: 0,
    hardLineLuminanceMax: 120,
    fillRegionLuminanceMin: 165,
    fringeDiagonals: false,
  );

  /// Harte Tinte — wird nie übermalt.
  final double hardLineLuminanceMax;

  /// Flood-Fill nur auf klar hellen Flächen.
  final double fillRegionLuminanceMin;

  /// Expand darf nur Pixel heller als dieser Wert einfärben.
  final double fringeLuminanceMin;

  /// Wie oft der Anti-Alias-Rand nachgezogen wird (0 = aus).
  final int fringeExpandPasses;

  /// Auch diagonal expandieren (stärker, mehr Überlaufen).
  final bool fringeDiagonals;
}
