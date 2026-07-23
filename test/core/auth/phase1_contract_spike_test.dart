import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/data/models/auth/auth_token_model.dart';
import 'package:rostiq/app/data/models/auth/me_context_model.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/app/data/models/visit/visit_gps_body.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';

void main() {
  group('JwtClaims', () {
    test('parses tenant_member claims', () {
      final claims = JwtClaims.fromPayload({
        'sub': '11111111-1111-1111-1111-111111111111',
        'tenant_id': '22222222-2222-2222-2222-222222222222',
        'permissions': ['auth.session', 'jobs.manage'],
        'actor_type': 'tenant_member',
        'tenant_member_id': '44444444-4444-4444-4444-444444444444',
        'iat': 1720000000,
        'exp': 1720003600,
        'typ': 'access',
      });

      expect(claims.isTenantMember, isTrue);
      expect(claims.isContractor, isFalse);
      expect(claims.tenantMemberId, isNotNull);
      expect(claims.contractorId, isNull);
      expect(claims.hasPermission('jobs.manage'), isTrue);
      expect(claims.mustChangePassword, isFalse);
    });

    test('parses contractor claims with mcp', () {
      final claims = JwtClaims.fromPayload({
        'sub': '11111111-1111-1111-1111-111111111111',
        'tenant_id': '22222222-2222-2222-2222-222222222222',
        'permissions': ['auth.session', 'visits.read', 'documents.upload'],
        'actor_type': 'contractor',
        'contractor_id': '33333333-3333-3333-3333-333333333333',
        'iat': 1720000000,
        'exp': 1720003600,
        'typ': 'access',
        'mcp': true,
      });

      expect(claims.isContractor, isTrue);
      expect(claims.contractorId, '33333333-3333-3333-3333-333333333333');
      expect(claims.mustChangePassword, isTrue);
      expect(claims.hasPermission('visits.check_in'), isFalse);
    });
  });

  group('AuthTokenModel V2', () {
    test('parses actor_type and engagements from login body', () {
      final model = AuthTokenModel.fromJson({
        'access_token': 'a',
        'refresh_token': 'r',
        'token_type': 'bearer',
        'must_change_password': false,
        'actor_type': 'contractor',
        'engagements': [
          {
            'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'tenant_id': '22222222-2222-2222-2222-222222222222',
            'tenant_name': 'Acme Care',
            'status': 'active',
          },
        ],
      });

      expect(model.actorType, 'contractor');
      expect(model.engagements, hasLength(1));
      expect(model.engagements.first.tenantName, 'Acme Care');
      expect(model.engagements.first.status, 'active');
    });

    test('tenant member login has empty engagements', () {
      final model = AuthTokenModel.fromJson({
        'access_token': 'a',
        'refresh_token': 'r',
        'actor_type': 'tenant_member',
        'engagements': <Map<String, dynamic>>[],
      });

      expect(model.actorType, 'tenant_member');
      expect(model.engagements, isEmpty);
    });
  });

  group('MeContextModel', () {
    test('parses OpenAPI MeContextResponse shape', () {
      final model = MeContextModel.fromJson({
        'actor_type': 'contractor',
        'tenant_id': '22222222-2222-2222-2222-222222222222',
        'contractor_id': '33333333-3333-3333-3333-333333333333',
        'tenant_member_id': null,
        'engagements': [
          {
            'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'tenant_id': '22222222-2222-2222-2222-222222222222',
            'tenant_name': 'Acme Care',
            'status': 'pending_docs',
          },
        ],
      });

      expect(model.actorType, 'contractor');
      expect(model.engagements.single.status, 'pending_docs');
      // Permissions are JWT-only — me/context does not carry them.
      expect(jsonEncode(model.engagements.first.toJson()), contains('tenant_name'));
    });
  });

  group('VisitGpsBody + documents', () {
    test('VisitGpsBody omits null accuracy and matches OpenAPI', () {
      const body = VisitGpsBody(lat: -33.8688, lng: 151.2093, accuracyM: 12.5);
      expect(body.toJson(), {
        'lat': -33.8688,
        'lng': 151.2093,
        'accuracy_m': 12.5,
      });

      const withoutAccuracy = VisitGpsBody(lat: 1, lng: 2);
      expect(withoutAccuracy.toJson().containsKey('accuracy_m'), isFalse);
    });

    test('UploadUrlResponse parses finalize bootstrap fields', () {
      final upload = UploadUrlResponse.fromJson({
        'document_id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        'upload_url': 'https://storage.example/upload',
        'gcs_object_key': 'contractors/x/passport.pdf',
        'expires_in_seconds': 900,
      });
      expect(upload.documentId, startsWith('dddd'));
      expect(upload.expiresInSeconds, 900);
    });
  });
}
