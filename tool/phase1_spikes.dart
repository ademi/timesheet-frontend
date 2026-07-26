import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dio/dio.dart';
import 'package:rostiq/app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:rostiq/app/data/datasources/remote/document_remote_datasource.dart';
import 'package:rostiq/app/data/models/auth/login_request_model.dart';
import 'package:rostiq/app/data/models/auth/switch_tenant_request_model.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';
import 'package:rostiq/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

/// Phase 1 live spikes against a running API (default http://localhost:8000).
///
/// Usage examples:
/// ```bash
/// dart run tool/phase1_spikes.dart health
/// dart run tool/phase1_spikes.dart member --email OWNER@x --password SECRET
/// dart run tool/phase1_spikes.dart contractor --email C@x --password SECRET --tenant TENANT_UUID
/// dart run tool/phase1_spikes.dart document --email C@x --password SECRET --owner OWNER_UUID
/// dart run tool/phase1_spikes.dart checkin --email C@x --password SECRET --visit VISIT_UUID --lat -33.86 --lng 151.20
/// ```
Future<void> main(List<String> args) async {
  final baseUrl = Platform.environment['API_BASE_URL'] ?? 'http://localhost:8000';
  if (args.isEmpty) {
    _usage();
    exit(64);
  }

  final command = args.first;
  final flags = _parseFlags(args.skip(1).toList());

  final plain = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  switch (command) {
    case 'health':
      await _health(plain);
    case 'member':
      await _spikeMember(plain, flags);
    case 'contractor':
      await _spikeContractor(plain, flags);
    case 'context':
      await _spikeContextParity(plain, flags);
    case 'document':
      await _spikeDocument(plain, flags);
    case 'checkin':
      await _spikeCheckIn(plain, flags);
    default:
      stderr.writeln('Unknown command: $command');
      _usage();
      exit(64);
  }
}

void _usage() {
  stdout.writeln('''
Phase 1 spikes (API_BASE_URL default http://localhost:8000)

  health
  member --email <id> --password <pw>
  contractor --email <id> --password <pw> [--tenant <uuid>]
  context --email <id> --password <pw>
  document --email <id> --password <pw> --owner <contractor_uuid> [--category passport_id]
  checkin --email <id> --password <pw> --visit <uuid> --lat <n> --lng <n> [--accuracy 12.5]
''');
}

Map<String, String> _parseFlags(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    final value = (i + 1 < args.length && !args[i + 1].startsWith('--'))
        ? args[++i]
        : 'true';
    out[key] = value;
  }
  return out;
}

Future<void> _health(Dio plain) async {
  final health = await plain.get<Map<String, dynamic>>('/health');
  final ready = await plain.get<Map<String, dynamic>>('/ready');
  final openapi = await plain.get<Map<String, dynamic>>('/openapi.json');
  stdout.writeln('health: ${health.data}');
  stdout.writeln('ready: ${ready.data}');
  stdout.writeln(
    'openapi: ${openapi.data?['info']?['title']} '
    '${openapi.data?['info']?['version']} '
    '(${(openapi.data?['paths'] as Map?)?.length ?? 0} paths)',
  );
}

Future<(AuthRemoteDataSource, Dio)> _authClients(
  Dio plain,
  String accessToken,
) async {
  final authDio = Dio(plain.options.copyWith());
  authDio.options.headers['Authorization'] = 'Bearer $accessToken';
  final ds = AuthRemoteDataSource(plainDio: plain, authenticatedDio: authDio);
  return (ds, authDio);
}

JwtClaims _claimsFromAccess(String accessToken) {
  final payload = JWT.decode(accessToken).payload;
  final map = payload is Map<String, dynamic>
      ? payload
      : Map<String, dynamic>.from(payload as Map);
  return JwtClaims.fromPayload(map);
}

Future<void> _spikeMember(Dio plain, Map<String, String> flags) async {
  final email = flags['email'];
  final password = flags['password'];
  if (email == null || password == null) {
    throw ArgumentError('member requires --email and --password');
  }

  final ds = AuthRemoteDataSource(plainDio: plain, authenticatedDio: plain);
  final tokens = await ds.login(
    LoginRequestModel(identifier: email, password: password),
  );
  final claims = _claimsFromAccess(tokens.accessToken);

  stdout.writeln('LOGIN actor_type(body)=${tokens.actorType}');
  stdout.writeln('LOGIN engagements=${tokens.engagements.length}');
  stdout.writeln('JWT actor_type=${claims.actorType}');
  stdout.writeln('JWT tenant_member_id=${claims.tenantMemberId}');
  stdout.writeln('JWT contractor_id=${claims.contractorId}');
  stdout.writeln('JWT permissions=${claims.permissions}');
  stdout.writeln('JWT mcp=${claims.mustChangePassword}');

  if (claims.actorType != 'tenant_member') {
    throw StateError('Expected tenant_member, got ${claims.actorType}');
  }
  stdout.writeln('SPIKE OK: tenant_member login → JWT claims → admin shell eligible');
}

Future<void> _spikeContractor(Dio plain, Map<String, String> flags) async {
  final email = flags['email'];
  final password = flags['password'];
  if (email == null || password == null) {
    throw ArgumentError('contractor requires --email and --password');
  }

  var ds = AuthRemoteDataSource(plainDio: plain, authenticatedDio: plain);
  var tokens = await ds.login(
    LoginRequestModel(identifier: email, password: password),
  );
  var claims = _claimsFromAccess(tokens.accessToken);

  stdout.writeln('LOGIN actor_type=${tokens.actorType}');
  stdout.writeln(
    'LOGIN engagements=${jsonEncode(tokens.engagements.map((e) => e.toJson()).toList())}',
  );
  stdout.writeln('JWT actor_type=${claims.actorType} contractor_id=${claims.contractorId}');

  if (claims.actorType != 'contractor') {
    throw StateError('Expected contractor, got ${claims.actorType}');
  }

  final tenantId = flags['tenant'] ??
      (tokens.engagements.length > 1 ? tokens.engagements.last.tenantId : null);

  if (tenantId != null) {
    final clients = await _authClients(plain, tokens.accessToken);
    ds = clients.$1;
    final switched = await ds.switchTenant(
      SwitchTenantRequestModel(tenantId: tenantId),
    );
    claims = _claimsFromAccess(switched.accessToken);
    stdout.writeln('SWITCH-TENANT new tenant_id(JWT)=${claims.tenantId}');
    stdout.writeln('SWITCH-TENANT tokens rotated=true');
    tokens = switched;
  } else {
    stdout.writeln('SWITCH-TENANT skipped (pass --tenant or multi-engagement account)');
  }

  stdout.writeln('SPIKE OK: contractor login → engagements → switch-tenant (if provided)');
}

Future<void> _spikeContextParity(Dio plain, Map<String, String> flags) async {
  final email = flags['email'];
  final password = flags['password'];
  if (email == null || password == null) {
    throw ArgumentError('context requires --email and --password');
  }

  final loginDs = AuthRemoteDataSource(plainDio: plain, authenticatedDio: plain);
  final tokens = await loginDs.login(
    LoginRequestModel(identifier: email, password: password),
  );
  final clients = await _authClients(plain, tokens.accessToken);
  final context = await clients.$1.getMeContext();

  stdout.writeln('login.actor_type=${tokens.actorType}');
  stdout.writeln('context.actor_type=${context.actorType}');
  stdout.writeln('login.engagements=${tokens.engagements.length}');
  stdout.writeln('context.engagements=${context.engagements.length}');
  stdout.writeln('context.tenant_id=${context.tenantId}');
  stdout.writeln('context.contractor_id=${context.contractorId}');
  stdout.writeln('context.tenant_member_id=${context.tenantMemberId}');

  if (tokens.actorType != null && tokens.actorType != context.actorType) {
    throw StateError('actor_type mismatch login vs me/context');
  }
  stdout.writeln('SPIKE OK: me/context parity with login body (actor + engagements)');
}

Future<void> _spikeDocument(Dio plain, Map<String, String> flags) async {
  final email = flags['email'];
  final password = flags['password'];
  final ownerId = flags['owner'];
  if (email == null || password == null || ownerId == null) {
    throw ArgumentError('document requires --email --password --owner');
  }

  final loginDs = AuthRemoteDataSource(plainDio: plain, authenticatedDio: plain);
  final tokens = await loginDs.login(
    LoginRequestModel(identifier: email, password: password),
  );
  final clients = await _authClients(plain, tokens.accessToken);
  final docs = DocumentRemoteDataSource(authenticatedDio: clients.$2);

  final bytes = Uint8List.fromList(utf8.encode('phase1-spike-passport'));
  final doc = await docs.uploadBytes(
    request: UploadUrlRequest(
      ownerType: 'contractor',
      ownerId: ownerId,
      filename: 'phase1-spike.txt',
      contentType: 'text/plain',
      sizeBytes: bytes.length,
      category: flags['category'] ?? 'passport_id',
    ),
    bytes: bytes,
  );

  stdout.writeln('document.id=${doc.id}');
  stdout.writeln('document.scan_status=${doc.scanStatus}');
  stdout.writeln('SPIKE OK: upload-url → PUT → finalize');
}

Future<void> _spikeCheckIn(Dio plain, Map<String, String> flags) async {
  final email = flags['email'];
  final password = flags['password'];
  final visitId = flags['visit'];
  final lat = double.tryParse(flags['lat'] ?? '');
  final lng = double.tryParse(flags['lng'] ?? '');
  if (email == null ||
      password == null ||
      visitId == null ||
      lat == null ||
      lng == null) {
    throw ArgumentError('checkin requires --email --password --visit --lat --lng');
  }

  final loginDs = AuthRemoteDataSource(plainDio: plain, authenticatedDio: plain);
  final tokens = await loginDs.login(
    LoginRequestModel(identifier: email, password: password),
  );
  final clients = await _authClients(plain, tokens.accessToken);
  final visits = VisitsRemoteDataSource(authenticatedDio: clients.$2);

  final accuracy = double.tryParse(flags['accuracy'] ?? '');
  final result = await visits.checkIn(
    id: visitId,
    body: VisitGpsBody(lat: lat, lng: lng, accuracyM: accuracy),
    idempotencyKey: 'spike-checkin-$visitId',
  );

  stdout.writeln('checkin.visit_id=${result.visitId}');
  stdout.writeln('checkin.status=${result.status}');
  stdout.writeln('checkin.time_entry_id=${result.timeEntryId}');
  stdout.writeln('SPIKE OK: visit check-in with {lat,lng,accuracy_m}');
}
