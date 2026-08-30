/// Profile requirement keys for Care plan clinical documents (V040).
class ClinicalKeys {
  static const behaviourSupportPlanDoc = 'behaviour_support_plan_doc';
  static const nutritionChecklist = 'nutrition_checklist';
  static const hazardChecklist = 'hazard_checklist';
  static const bspOnFile = 'bsp_on_file';
  static const nutritionChecklistOnFile = 'nutrition_checklist_on_file';
  static const hazardChecklistOnFile = 'hazard_checklist_on_file';

  /// Existing patient requirement (V020) — medical report upload row.
  static const medicalReport = 'medical_report';

  static const documentCategoryBsp = 'behaviour_support_plan';
  static const documentCategoryNutrition = 'nutrition_checklist';
  static const documentCategoryHazard = 'hazard_checklist';
  static const documentCategoryMedical = 'medical_report';

  static const onFileKeys = {
    bspOnFile,
    nutritionChecklistOnFile,
    hazardChecklistOnFile,
  };

  static const carePlanOwnedClinicalKeys = {
    behaviourSupportPlanDoc,
    nutritionChecklist,
    hazardChecklist,
    bspOnFile,
    nutritionChecklistOnFile,
    hazardChecklistOnFile,
  };
}
