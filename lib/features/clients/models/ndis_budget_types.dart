/// NDIS plan budget category keys (ndis_budget_type).
abstract final class NdisBudgetType {
  static const core = 'core';
  static const capacityBuilding = 'capacity_building';
  static const capital = 'capital';
  static const other = 'other';

  static const labels = <String, String>{
    core: 'Core supports',
    capacityBuilding: 'Capacity building',
    capital: 'Capital supports',
    other: 'Other budget',
  };

  static bool isValid(String type) => labels.containsKey(type);
}
