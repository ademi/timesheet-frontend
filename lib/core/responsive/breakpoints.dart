/// Width-based breakpoints for structural layout decisions.
///
/// Always branch on [LayoutBuilder] `constraints.maxWidth`, not [MediaQuery].
enum DeviceClass {
  phone,
  tablet,
  desktop,
}

class Breakpoints {
  Breakpoints._();

  static const double phone = 600;
  static const double tablet = 1024;
  static const double maxContent = 1200;
  static const double formMaxWidth = 480;

  static DeviceClass classify(double width) {
    if (width < phone) return DeviceClass.phone;
    if (width < tablet) return DeviceClass.tablet;
    return DeviceClass.desktop;
  }
}
