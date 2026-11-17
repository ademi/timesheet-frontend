/// No-op on non-web platforms.
void Function() subscribeWebVisibilityResume(void Function() onVisible) {
  return () {};
}
