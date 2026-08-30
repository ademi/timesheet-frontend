/// CL-06 Strengths & Needs section keys (keep aligned with backend sn_schemas.py).
abstract final class StrengthsNeedsKeys {
  StrengthsNeedsKeys._();

  static const statusDraft = 'draft';
  static const statusSubmitted = 'submitted';
  static const statusSuperseded = 'superseded';

  static const allSectionKeys = [
    livingSkills,
    informalSupports,
    decisionMaking,
    culturalBackground,
    prioritiesGoals,
    lifestyleAspirations,
    learningStyle,
    communication,
    mobility,
    cultureValuesBeliefs,
    physicalLocation,
    decisionMakingBackground,
    familyCircumstances,
    mentalIllness,
    socialIsolation,
    socioEconomic,
    complexMedical,
    substanceMisuse,
    complexCommunication,
    challengingBehaviour,
    housing,
    health,
    educationEmployment,
    guardianship,
    alcoholDrugsServices,
    criminalJustice,
    otherServices,
  ];

  /// Default import excludes D8-sensitive keys until RBAC ships.
  static const defaultImportKeys = [
    prioritiesGoals,
    livingSkills,
    informalSupports,
    culturalBackground,
    communication,
    complexMedical,
    challengingBehaviour,
    mobility,
    lifestyleAspirations,
    learningStyle,
    physicalLocation,
    health,
  ];

  static const sensitiveSectionKeys = {
    mentalIllness,
    substanceMisuse,
    criminalJustice,
    familyCircumstances,
    alcoholDrugsServices,
  };

  static const livingSkills = 'living_skills';
  static const informalSupports = 'informal_supports';
  static const decisionMaking = 'decision_making';
  static const culturalBackground = 'cultural_background';
  static const prioritiesGoals = 'priorities_goals';
  static const lifestyleAspirations = 'lifestyle_aspirations';
  static const learningStyle = 'learning_style';
  static const communication = 'communication';
  static const mobility = 'mobility';
  static const cultureValuesBeliefs = 'culture_values_beliefs';
  static const physicalLocation = 'physical_location';
  static const decisionMakingBackground = 'decision_making_background';
  static const familyCircumstances = 'family_circumstances';
  static const mentalIllness = 'mental_illness';
  static const socialIsolation = 'social_isolation';
  static const socioEconomic = 'socio_economic';
  static const complexMedical = 'complex_medical';
  static const substanceMisuse = 'substance_misuse';
  static const complexCommunication = 'complex_communication';
  static const challengingBehaviour = 'challenging_behaviour';
  static const housing = 'housing';
  static const health = 'health';
  static const educationEmployment = 'education_employment';
  static const guardianship = 'guardianship';
  static const alcoholDrugsServices = 'alcohol_drugs_services';
  static const criminalJustice = 'criminal_justice';
  static const otherServices = 'other_services';

  static String labelFor(String key) => _labels[key] ?? key;

  static const _labels = {
    livingSkills: 'Living skills',
    informalSupports: 'Informal supports',
    decisionMaking: 'Decision making',
    culturalBackground: 'Cultural background',
    prioritiesGoals: 'Priorities and goals',
    lifestyleAspirations: 'Lifestyle aspirations',
    learningStyle: 'Learning style',
    communication: 'Communication',
    mobility: 'Mobility',
    cultureValuesBeliefs: 'Culture, values and beliefs',
    physicalLocation: 'Physical location',
    decisionMakingBackground: 'Decision making background',
    familyCircumstances: 'Family circumstances',
    mentalIllness: 'Mental illness',
    socialIsolation: 'Social isolation',
    socioEconomic: 'Socio-economic factors',
    complexMedical: 'Complex medical',
    substanceMisuse: 'Substance misuse',
    complexCommunication: 'Complex communication',
    challengingBehaviour: 'Challenging behaviour',
    housing: 'Housing',
    health: 'Health',
    educationEmployment: 'Education and employment',
    guardianship: 'Guardianship',
    alcoholDrugsServices: 'Alcohol and drugs services',
    criminalJustice: 'Criminal justice',
    otherServices: 'Other services',
  };

  static const sectionGroups = [
    (
      title: 'Living and daily life',
      keys: [
        livingSkills,
        informalSupports,
        decisionMaking,
        housing,
        health,
        educationEmployment,
        guardianship,
      ],
    ),
    (
      title: 'Culture and preferences',
      keys: [
        culturalBackground,
        cultureValuesBeliefs,
        lifestyleAspirations,
        learningStyle,
        prioritiesGoals,
      ],
    ),
    (
      title: 'Communication and mobility',
      keys: [
        communication,
        complexCommunication,
        mobility,
        physicalLocation,
      ],
    ),
    (
      title: 'Social and wellbeing',
      keys: [
        socialIsolation,
        socioEconomic,
        complexMedical,
        decisionMakingBackground,
      ],
    ),
    (
      title: 'Behaviour',
      keys: [challengingBehaviour],
    ),
    (
      title: 'Additional context',
      keys: [
        familyCircumstances,
        mentalIllness,
        substanceMisuse,
        alcoholDrugsServices,
        criminalJustice,
        otherServices,
      ],
    ),
  ];
}
