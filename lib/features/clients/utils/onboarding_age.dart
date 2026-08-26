/// Whether [dob] is under 18 years old relative to [today] (defaults to now).
bool isUnder18(DateTime dob, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    age -= 1;
  }
  return age < 18;
}
