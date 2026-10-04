import 'roster_composer_args.dart';

/// Corrected stepped wizard order for the unified rostering composer.
///
/// Clients → When (+ Repeat collect) → Place (+ optional Travel) →
/// Support → Forms → Workers + Publish.
enum ComposerStep {
  clients,
  when,
  place,
  support,
  forms,
  workers,
}

extension ComposerStepX on ComposerStep {
  String get title => switch (this) {
    ComposerStep.clients => 'Clients',
    ComposerStep.when => 'When',
    ComposerStep.place => 'Place',
    ComposerStep.support => 'Support',
    ComposerStep.forms => 'Forms',
    ComposerStep.workers => 'Workers',
  };

  String get shortLabel => switch (this) {
    ComposerStep.clients => '1. Clients',
    ComposerStep.when => '2. When',
    ComposerStep.place => '3. Place',
    ComposerStep.support => '4. Support',
    ComposerStep.forms => '5. Forms',
    ComposerStep.workers => '6. Workers',
  };

  int get index => ComposerStep.values.indexOf(this);

  bool get isFirst => this == ComposerStep.clients;
  bool get isLast => this == ComposerStep.workers;

  ComposerStep? get previous {
    final i = index;
    if (i <= 0) return null;
    return ComposerStep.values[i - 1];
  }

  ComposerStep? get next {
    final i = index;
    if (i >= ComposerStep.values.length - 1) return null;
    return ComposerStep.values[i + 1];
  }

  /// Map legacy focus / deep-link args onto a step.
  static ComposerStep fromFocus(ComposerFocusSection focus) => switch (focus) {
    ComposerFocusSection.people => ComposerStep.clients,
    ComposerFocusSection.publish => ComposerStep.workers,
    ComposerFocusSection.plan => ComposerStep.clients,
  };
}
