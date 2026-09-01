/// Canonical support specialist type keys for [support_plan_specialists] JSON.
abstract final class SupportPlanSpecialistTypes {
  static const supportCoordinator = 'support_coordinator';
  static const behaviouralTherapist = 'behavioural_therapist';
  static const speechTherapist = 'speech_therapist';
  static const occupationalTherapist = 'occupational_therapist';
  static const physiotherapist = 'physiotherapist';
  static const other = 'other';

  static const labels = <String, String>{
    supportCoordinator: 'Support coordinator',
    behaviouralTherapist: 'Behavioural therapist',
    speechTherapist: 'Speech therapist',
    occupationalTherapist: 'Occupational therapist',
    physiotherapist: 'Physiotherapist',
    other: 'Other specialist',
  };

  static const pickerTypes = <String>[
    supportCoordinator,
    behaviouralTherapist,
    speechTherapist,
    occupationalTherapist,
    physiotherapist,
    other,
  ];

  static bool isValid(String type) => labels.containsKey(type);

  static String label(String type, {String? customLabel}) {
    if (type == other && customLabel != null && customLabel.trim().isNotEmpty) {
      return customLabel.trim();
    }
    return labels[type] ?? type;
  }

  static String nameFieldLabel(String type) =>
      type == supportCoordinator ? 'SC name' : 'Specialist name';
}
