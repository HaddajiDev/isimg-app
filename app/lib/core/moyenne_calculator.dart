import '../models/grade_tree.dart';

enum AverageSource {
  official,

  computed,

  partial,

  simulated,

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

  bool get isSimulated => source == AverageSource.simulated;

  bool get hasValue => value != null;
}

class MoyenneCalculator {
  const MoyenneCalculator();

  Average matiereAverage(Matiere matiere) {
    if (matiere.moyenne != null) {
      return Average(matiere.moyenne, AverageSource.official);
    }

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

    final expected = matiere.epreuves
        .where((e) => (e.poids ?? 0) > 0)
        .fold<double>(0, (sum, e) => sum + e.poids!);
    final isComplete = (expected - weight).abs() < 0.001;

    return Average(
      total / weight,

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
