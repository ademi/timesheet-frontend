import 'dart:html' as html;

/// Fires [onVisible] when the tab becomes visible again (web tab reopen / focus).
///
/// Flutter's [AppLifecycleState.resumed] is unreliable on web; this covers
/// refresh-on-resume for browser tabs.
void Function() subscribeWebVisibilityResume(void Function() onVisible) {
  void listener(html.Event _) {
    if (html.document.visibilityState == 'visible') {
      onVisible();
    }
  }

  html.document.addEventListener('visibilitychange', listener);
  return () => html.document.removeEventListener('visibilitychange', listener);
}
