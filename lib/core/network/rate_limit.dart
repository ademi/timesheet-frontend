import 'package:dio/dio.dart';

/// Extra key: number of 429 → wait → retry cycles already performed.
const String kRateLimitRetriedExtra = 'rate_limit_retried';

/// Default wait when the API returns 429 without a usable hint.
const Duration kDefaultRateLimitDelay = Duration(seconds: 1);

/// Cap for automatic interceptor / refresh retries (avoids multi-minute hangs).
const Duration kMaxAutoRateLimitDelay = Duration(seconds: 60);

/// Parses [Retry-After] (seconds or HTTP-date) and body `retry_after`.
///
/// Supports public `{ "retry_after": N }` and authenticated
/// `{ "code": "rate_limit_exceeded", "retry_after": N }` payloads.
Duration? rateLimitDelayFromResponse(Response? response) {
  if (response == null) return null;

  final header = response.headers.value('retry-after');
  final fromHeader = _parseRetryAfterHeader(header);
  if (fromHeader != null) return fromHeader;

  return rateLimitDelayFromBody(response.data);
}

/// Body-only parse (useful when only the JSON map is available).
Duration? rateLimitDelayFromBody(Object? data) {
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);

  final direct = _parseRetryAfterValue(map['retry_after']);
  if (direct != null) return direct;

  final detail = map['detail'];
  if (detail is Map) {
    final nested = _parseRetryAfterValue(
      Map<String, dynamic>.from(detail)['retry_after'],
    );
    if (nested != null) return nested;
  }
  return null;
}

/// Prefer server hint; otherwise [fallback]. Clamped to [max] for auto-retry.
Duration effectiveRateLimitDelay(
  Duration? serverHint, {
  Duration fallback = kDefaultRateLimitDelay,
  Duration max = kMaxAutoRateLimitDelay,
}) {
  final raw = serverHint ?? fallback;
  if (raw.isNegative) return fallback;
  return raw > max ? max : raw;
}

Duration? _parseRetryAfterHeader(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final asInt = int.tryParse(trimmed);
  if (asInt != null) {
    if (asInt < 0) return null;
    return Duration(seconds: asInt);
  }

  // HTTP-date form is uncommon for API 429s; accept ISO-8601 if provided.
  final date = DateTime.tryParse(trimmed);
  if (date == null) return null;
  final delta = date.toUtc().difference(DateTime.now().toUtc());
  if (delta.isNegative) return Duration.zero;
  return delta;
}

Duration? _parseRetryAfterValue(Object? value) {
  if (value == null) return null;
  if (value is int) {
    if (value < 0) return null;
    return Duration(seconds: value);
  }
  if (value is num) {
    final seconds = value.round();
    if (seconds < 0) return null;
    return Duration(seconds: seconds);
  }
  if (value is String) {
    final asInt = int.tryParse(value.trim());
    if (asInt == null || asInt < 0) return null;
    return Duration(seconds: asInt);
  }
  return null;
}
