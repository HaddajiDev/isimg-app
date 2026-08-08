import '../models/grade_tree.dart';

/// Where a displayed average came from.
enum AverageSource {
  /// Published by the school — authoritative.
  official,

  /// Computed here from every épreuve of the matière, all notes present.
  computed,

  /// Computed from only the notes posted so far; will move as more land.
  partial,

  /// Includes at least one note the student typed in themselves — a
  /// projection, not a reflection of anything the school has recorded.
  simulated,

  /// Not enough data to compute anything.
  unavailable,
}

class Average {
  final double? value;
  final AverageSource source;

  const Average(this.value, this.source);

  static const none = Average(null, AverageSource.unavailable);

  bool get isEstimate =>
      source == AverageSource.computed ||
      source == AverageSource.partial ||
      source == AverageSource.simulated;

  /// Depends on a note the student invented, so it must be read as a what-if.
  bool get isSimulated => source == AverageSource.simulated;

  bool get hasValue => value != null;
}

/// Recomputes the averages the site leaves blank mid-year.
///
/// Formulas (verified against a released bulletin):
///  - matière   Σ(note × poids) ÷ Σ(poids)     over épreuves that have a note
///  - unité     Σ(moyMatière × coefMatière) ÷ Σ(coefMatière)
///  - semestre  Σ(moyUnité × coefUnité) ÷ Σ(coefUnité)
///  - annuelle  mean of the semester averages
///
/// An official value always wins; computation only fills gaps.
///
/// Two known limits, both inherited from what the site exposes:
///  - Rattrapage ("Rex") épreuves are excluded. How the school merges the
///    control session with the main one isn't documented, and guessing it would
///    silently produce wrong numbers, so those matières keep their official
///    average and are otherwise reported as [AverageSource.unavailable].
///  - Under the CC régime some notes are never published, so a computed average
///    can differ from the eventual official one. Such results are flagged
///    [AverageSource.partial].
class MoyenneCalculator {
  const MoyenneCalculator();

  Average matiereAverage(Matiere matiere) {
    if (matiere.moyenne != null) {
      return Average(matiere.moyenne, AverageSource.official);
    }

    // Presence of a rattrapage means the main-session weights no longer
    // describe the outcome; refuse rather than invent a number.
    if (matiere.epreuves.any((e) => e.isRattrapage)) return Average.none;

    final weighted = matiere.epreuves.where((e) => e.hasNote && (e.poids ?? 0) > 0);
    if (weighted.isEmpty) return Average.none;

    var total = 0.0;
    var weight = 0.0;
    var usedManual = false;
    for (final epreuve in weighted) {
      total += epreuve.effectiveNote! * epreuve.poids!;
      weight += epreuve.poids!;
      usedManual |= epreuve.isManual;
    }
    if (weight <= 0) return Average.none;

    // Renormalising by the weight actually covered turns a half-graded matière
    // into "standing so far" instead of understating it.
    final expected = matiere.epreuves
        .where((e) => (e.poids ?? 0) > 0)
        .fold<double>(0, (sum, e) => sum + e.poids!);
    final isComplete = (expected - weight).abs() < 0.001;

    return Average(
      total / weight,
      // A student-supplied note outranks the complete/partial distinction:
      // the figure is hypothetical either way.
      usedManual
          ? AverageSource.simulated
          : (isComplete ? AverageSource.computed : AverageSource.partial),
    );
  }

  Average uniteAverage(Unite unite) {
    if (unite.moyenne != null) {
      return Average(unite.moyenne, AverageSource.official);
    }
    return _weightedMean(
      unite.matieres.map(
        (m) => (average: matiereAverage(m), weight: m.coefficient),
      ),
    );
  }

  Average semestreAverage(Semestre semestre) {
    return _weightedMean(
      semestre.unites.map(
        (u) => (average: uniteAverage(u), weight: u.coefficient),
      ),
    );
  }

  /// Mean of the semester averages, matching the published annual moyenne.
  Average annualAverage(List<Semestre> semestres) {
    final averages = semestres.map(semestreAverage).where((a) => a.hasValue).toList();
    if (averages.isEmpty) return Average.none;

    final mean =
        averages.fold<double>(0, (sum, a) => sum + a.value!) / averages.length;
    return Average(mean, _worstSource(averages));
  }

  Average _weightedMean(Iterable<({Average average, double? weight})> parts) {
    var total = 0.0;
    var weight = 0.0;
    final used = <Average>[];

    for (final part in parts) {
      final value = part.average.value;
      final w = part.weight;
      if (value == null || w == null || w <= 0) continue;
      total += value * w;
      weight += w;
      used.add(part.average);
    }

    if (weight <= 0) return Average.none;
    return Average(total / weight, _worstSource(used));
  }

  /// An aggregate is only as trustworthy as its shakiest input.
  AverageSource _worstSource(List<Average> parts) {
    if (parts.any((p) => p.source == AverageSource.simulated)) {
      return AverageSource.simulated;
    }
    if (parts.any((p) => p.source == AverageSource.partial)) {
      return AverageSource.partial;
    }
    if (parts.any((p) => p.source == AverageSource.computed)) {
      return AverageSource.computed;
    }
    return AverageSource.official;
  }
}
