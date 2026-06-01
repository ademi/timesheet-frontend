# Timesheet Frontend — Security & Fix Plan v1

> **Scope:** Issues FE-01 through FE-10, excluding FE-09 (handled separately).
> Cross-references the backend fix plan at `backend/docs/fix-plan-v1.md`.
>
> **Constraint:** Development phase — no backwards-compatibility required.
> **Executor:** Apply tasks in the order listed. Tasks are self-contained unless a
> "Deployment coordination" note says otherwise.

---

## TASK FE-1 — FE-07: Extract a Shared `TokenStorage` Service

**Severity:** Medium  
**Why first:** Tasks FE-2, FE-3, and FE-5 all depend on this. Creating it now avoids
re-touching the same files three times.

**Files to create/edit:**
- **CREATE** `lib/core/services/token_storage.dart`
- **EDIT** `lib/core/network/auth_interceptor.dart`
- **EDIT** `lib/app/data/repositories/auth_repository.dart`
- **EDIT** `lib/app/bindings/auth_binding.dart`

---

### Step 1 — Create `lib/core/services/token_storage.dart`

Create this file from scratch. It wraps `GetStorage` for now; Task FE-5 will swap the
implementation to `flutter_secure_storage` by only editing this one file.

```dart
import 'package:get_storage/get_storage.dart';

import '../constants/app_constants.dart';

/// Single source of truth for persisting and reading auth tokens.
/// Swap the implementation here when migrating to flutter_secure_storage.
class TokenStorage {
  TokenStorage({required GetStorage storage}) : _storage = storage;

  final GetStorage _storage;

  String? get accessToken => _storage.read<String>(StorageKeys.accessToken);
  String? get refreshToken => _storage.read<String>(StorageKeys.refreshToken);

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(StorageKeys.accessToken, accessToken);
    await _storage.write(StorageKeys.refreshToken, refreshToken);
  }

  void clear() {
    _storage.remove(StorageKeys.accessToken);
    _storage.remove(StorageKeys.refreshToken);
  }
}
```

---

### Step 2 — Update `lib/core/network/auth_interceptor.dart`

Replace `GetStorage` dependency with `TokenStorage`. The constructor signature changes;
all logic stays the same.

```dart
// BEFORE — constructor and fields:
AuthInterceptor({
  required GetStorage storage,
  required Dio plainDio,
  required Dio authenticatedDio,
})  : _storage = storage,
      _plainDio = plainDio,
      _authenticatedDio = authenticatedDio;

final GetStorage _storage;

// All references to _storage.read<String>(StorageKeys.accessToken)
// All references to _storage.read<String>(StorageKeys.refreshToken)
// All references to _storage.write(...)
// All references to _storage.remove(...)
```

```dart
// AFTER — constructor and fields:
AuthInterceptor({
  required TokenStorage storage,      // <-- type change
  required Dio plainDio,
  required Dio authenticatedDio,
})  : _storage = storage,
      _plainDio = plainDio,
      _authenticatedDio = authenticatedDio;

final TokenStorage _storage;          // <-- type change
```

Then replace each low-level storage call:

| Find (old) | Replace with (new) |
|---|---|
| `_storage.read<String>(StorageKeys.accessToken)` | `_storage.accessToken` |
| `_storage.read<String>(StorageKeys.refreshToken)` | `_storage.refreshToken` |
| `await _storage.write(StorageKeys.accessToken, tokens.accessToken)` → inside `_persistTokens` | `await _storage.persist(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)` |
| `await _storage.write(StorageKeys.refreshToken, tokens.refreshToken)` | *(removed — covered by persist())* |
| `_storage.remove(StorageKeys.accessToken)` → inside `_clearTokens` | `_storage.clear()` |
| `_storage.remove(StorageKeys.refreshToken)` | *(removed — covered by clear())* |

The `_persistTokens` and `_clearTokens` private methods become:

```dart
Future<void> _persistTokens(AuthTokenModel tokens) async {
  await _storage.persist(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
  );
}

void _clearTokens() {
  _storage.clear();
}
```

Add import at the top of the file:
```dart
import '../services/token_storage.dart';
```

Remove the now-unused imports:
```dart
// DELETE these two lines:
import 'package:get_storage/get_storage.dart';
// (StorageKeys is no longer referenced directly in this file)
import '../constants/app_constants.dart'; // only if StorageKeys was the only usage
```

---

### Step 3 — Update `lib/app/data/repositories/auth_repository.dart`

Replace `GetStorage` with `TokenStorage` throughout.

```dart
// BEFORE
class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required GetStorage storage,
  }) : _remote = remote,
       _storage = storage;

  final AuthRemoteDataSource _remote;
  final GetStorage _storage;

  Future<void> _persistTokens(AuthTokenModel tokens) async {
    await _storage.write(StorageKeys.accessToken, tokens.accessToken);
    await _storage.write(StorageKeys.refreshToken, tokens.refreshToken);
  }

  void _clearTokens() {
    _storage.remove(StorageKeys.accessToken);
    _storage.remove(StorageKeys.refreshToken);
  }
```

```dart
// AFTER
class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required TokenStorage storage,     // <-- type change
  }) : _remote = remote,
       _storage = storage;

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;         // <-- type change

  Future<void> _persistTokens(AuthTokenModel tokens) async {
    await _storage.persist(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  void _clearTokens() {
    _storage.clear();
  }
```

Also update the `logout()` method — replace:
```dart
final refresh = _storage.read<String>(StorageKeys.refreshToken);
```
with:
```dart
final refresh = _storage.refreshToken;
```

Add import at the top:
```dart
import '../../../core/services/token_storage.dart';
```

Remove the now-unused imports:
```dart
// DELETE:
import 'package:get_storage/get_storage.dart';
import '../../../core/constants/app_constants.dart'; // if StorageKeys was only usage
```

---

### Step 4 — Update `lib/app/bindings/auth_binding.dart`

Wire up the new `TokenStorage`:

```dart
// BEFORE — inside dependencies():
final storage = GetStorage();

if (!Get.isRegistered<ApiClient>()) {
  Get.put<ApiClient>(ApiClient(storage), permanent: true);
}
// ...
Get.put<AuthRepository>(
  AuthRepository(
    remote: Get.find<AuthRemoteDataSource>(),
    storage: storage,
  ),
  permanent: true,
);
```

```dart
// AFTER — inside dependencies():
final rawStorage = GetStorage();

if (!Get.isRegistered<TokenStorage>()) {
  Get.put<TokenStorage>(TokenStorage(storage: rawStorage), permanent: true);
}
if (!Get.isRegistered<ApiClient>()) {
  Get.put<ApiClient>(ApiClient(rawStorage, Get.find<TokenStorage>()), permanent: true);
}
// ...
Get.put<AuthRepository>(
  AuthRepository(
    remote: Get.find<AuthRemoteDataSource>(),
    storage: Get.find<TokenStorage>(),
  ),
  permanent: true,
);
```

Note: `ApiClient` now receives `TokenStorage` too — update that in the next step.

---

### Step 5 — Update `lib/core/network/api_client.dart`

The `ApiClient` constructs `AuthInterceptor` which now needs `TokenStorage`.

```dart
// BEFORE
class ApiClient {
  ApiClient._(GetStorage storage)
      : plainDio = Dio(...),
        dio = Dio(...) {
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        ...
      ),
    );
  }

  factory ApiClient(GetStorage storage) {
    return _instance ??= ApiClient._(storage);
  }
```

```dart
// AFTER
class ApiClient {
  ApiClient._(GetStorage rawStorage, TokenStorage tokenStorage)
      : plainDio = Dio(...),
        dio = Dio(...) {
    dio.interceptors.add(
      AuthInterceptor(
        storage: tokenStorage,          // <-- TokenStorage
        plainDio: plainDio,
        authenticatedDio: dio,
      ),
    );
  }

  factory ApiClient(GetStorage rawStorage, TokenStorage tokenStorage) {
    return _instance ??= ApiClient._(rawStorage, tokenStorage);
  }
```

Add import:
```dart
import '../services/token_storage.dart';
```

---

## TASK FE-2 — FE-02: Switch `verifyPin` and `setPin` to Authenticated Dio

**Severity:** Critical  
**⚠ Deployment coordination:** This change MUST be deployed at the same time as
backend Task 11 (C-03). Deploying either one without the other will break clock-in/out.

**File:** `lib/app/data/datasources/remote/auth_remote_datasource.dart`

The `AuthRemoteDataSource` constructor already receives both `_plainDio` and
`_authenticatedDio`. Only the call-site Dio selection needs to change.

### Exact change

```dart
// BEFORE
Future<VerifyPinResponseModel> verifyPin(VerifyPinRequestModel request) async {
  final response = await _plainDio.post<Map<String, dynamic>>(   // <-- wrong
    AppConstants.verifyPinPath,
    data: request.toJson(),
  );
  ...
}

Future<String> setPin(SetPinRequestModel request) async {
  try {
    final response = await _plainDio.post<Map<String, dynamic>>(  // <-- wrong
      AppConstants.setPinPath,
      data: request.toJson(),
    );
    ...
```

```dart
// AFTER
Future<VerifyPinResponseModel> verifyPin(VerifyPinRequestModel request) async {
  final response = await _authenticatedDio.post<Map<String, dynamic>>( // <-- correct
    AppConstants.verifyPinPath,
    data: request.toJson(),
  );
  ...
}

Future<String> setPin(SetPinRequestModel request) async {
  try {
    final response = await _authenticatedDio.post<Map<String, dynamic>>( // <-- correct
      AppConstants.setPinPath,
      data: request.toJson(),
    );
    ...
```

No other changes needed. The `AuthInterceptor` attached to `_authenticatedDio` handles
attaching the `Authorization: Bearer` header automatically.

---

## TASK FE-3 — FE-03 + FE-04: First-Login Password Change Flow

**Severity:** Critical  
**⚠ Deployment coordination:** Tasks FE-3 and backend Task 10 (C-04+C-05) must deploy
together. Deploying the backend first leaves users stuck at a must-change-password flag
the app does not understand.

**What needs to happen:**
1. `AuthTokenModel` gains a `mustChangePassword` field.
2. After login, if `mustChangePassword == true`, route to a new `FirstLoginView` instead
   of home/admin.
3. `FirstLoginView` calls `POST /v1/auth/complete_first_login` with the new password.
4. On success, clear old tokens, persist the new tokens from the response, navigate to
   the normal destination.
5. Delete the existing `changePassword()` method in `AuthRemoteDataSource` (it called
   the endpoint being removed). Add a proper `completeFirstLogin()` method instead.

---

### Step 1 — Update `lib/app/data/models/auth/auth_token_model.dart`

```dart
// BEFORE
class AuthTokenModel {
  const AuthTokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
      };

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}
```

```dart
// AFTER
class AuthTokenModel {
  const AuthTokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.mustChangePassword = false,   // <-- new field
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool mustChangePassword;       // <-- new field

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
      };

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      mustChangePassword:               // <-- parse new field
          json['must_change_password'] as bool? ?? false,
    );
  }
}
```

---

### Step 2 — Create `lib/app/data/models/auth/first_login_request_model.dart`

```dart
class FirstLoginRequestModel {
  const FirstLoginRequestModel({required this.newPassword});

  final String newPassword;

  Map<String, dynamic> toJson() => {'new_password': newPassword};
}
```

---

### Step 3 — Update `lib/app/data/datasources/remote/auth_remote_datasource.dart`

**3a.** Add the new `completeFirstLogin()` method and **delete** the old `changePassword()`:

```dart
// DELETE this entire method:
Future<String> changePassword(ChangePasswordRequestModel request) async {
  final response = await _authenticatedDio.post<Map<String, dynamic>>(
    '/v1/auth/set_initial_password',     // endpoint being removed
    data: request.toJson(),
  );
  ...
}
```

```dart
// ADD this new method in its place:

/// Calls POST /v1/auth/complete_first_login (requires Bearer access token).
/// Used when the server returns must_change_password=true on login.
Future<AuthTokenModel> completeFirstLogin(
  FirstLoginRequestModel request,
) async {
  try {
    final response = await _authenticatedDio.post<Map<String, dynamic>>(
      '/v1/auth/complete_first_login',
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty complete_first_login response',
      );
    }
    return AuthTokenModel.fromJson(data);
  } on DioException catch (e) {
    final authErr = parseAuthError(e);
    if (authErr != null) throw authErr;
    rethrow;
  }
}
```

**3b.** Add import at the top of the file (if not already there):

```dart
import '../../models/auth/first_login_request_model.dart';
```

**3c.** Remove the import for `change_password_request_model.dart` since `changePassword` is
deleted and `ChangePasswordRequestModel` is no longer used here:

```dart
// DELETE:
import '../../models/auth/change_password_request_model.dart';
```

---

### Step 4 — Update `lib/app/data/repositories/auth_repository.dart`

Add a `completeFirstLogin()` method:

```dart
// ADD after the existing login() method:

Future<AuthTokenModel> completeFirstLogin(String newPassword) async {
  try {
    return await _remote.completeFirstLogin(
      FirstLoginRequestModel(newPassword: newPassword),
    );
  } on DioException catch (e) {
    final authErr = parseAuthError(e);
    if (authErr != null) throw authErr;
    rethrow;
  }
}
```

Add import at the top:
```dart
import '../datasources/remote/auth_remote_datasource.dart'; // already there
import '../models/auth/first_login_request_model.dart';
```

---

### Step 5 — Update `lib/app/controllers/auth_controller.dart`

After a successful login, check `mustChangePassword` before navigating:

```dart
// BEFORE — inside login():
await _authRepository.login(
  emailController.text.trim(),
  passwordController.text,
);
if (Get.isRegistered<PushNotificationService>()) {
  await Get.find<PushNotificationService>().registerCurrentDeviceToken();
}
final gateway = Get.find<GatewayController>();
final destination =
    gateway.selectedRole.value == UserRole.admin
        ? AppRoutes.adminPanel
        : AppRoutes.home;
Get.offAllNamed(destination);
```

```dart
// AFTER — inside login():
final tokens = await _authRepository.loginWithTokens(
  emailController.text.trim(),
  passwordController.text,
);
if (Get.isRegistered<PushNotificationService>()) {
  await Get.find<PushNotificationService>().registerCurrentDeviceToken();
}
if (tokens.mustChangePassword) {
  Get.offAllNamed(AppRoutes.firstLogin);
  return;
}
final gateway = Get.find<GatewayController>();
final destination =
    gateway.selectedRole.value == UserRole.admin
        ? AppRoutes.adminPanel
        : AppRoutes.home;
Get.offAllNamed(destination);
```

This requires `AuthRepository.login()` to return the `AuthTokenModel` (currently it
returns `void`). Rename the current `login()` to `loginWithTokens()` and return the
token:

In `auth_repository.dart`, change:

```dart
// BEFORE
Future<void> login(String identifier, String password) async {
  try {
    final tokens = await _remote.login(
      LoginRequestModel(
        identifier: identifier,
        password: password,
        tenantId: AppConstants.tenantId,
      ),
    );
    await _persistTokens(tokens);
  } on DioException catch (e) {
    ...
  }
}
```

```dart
// AFTER
Future<AuthTokenModel> loginWithTokens(String identifier, String password) async {
  try {
    final tokens = await _remote.login(
      LoginRequestModel(
        identifier: identifier,
        password: password,
        tenantId: AppConstants.tenantId,  // Note: FE-01 will remove this later
      ),
    );
    await _persistTokens(tokens);
    return tokens;
  } on DioException catch (e) {
    final authErr = parseAuthError(e);
    if (authErr != null) throw authErr;
    rethrow;
  }
}
```

Also add import at the top of `auth_repository.dart`:
```dart
import '../models/auth/auth_token_model.dart';
```

---

### Step 6 — Add `firstLogin` route to `lib/app/routes/app_routes.dart`

```dart
// ADD:
static const firstLogin = '/first-login';
```

---

### Step 7 — Create `lib/app/controllers/first_login_controller.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/models/auth/auth_error_model.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'gateway_controller.dart';

class FirstLoginController extends GetxController {
  FirstLoginController({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;

  void togglePasswordVisibility() => isPasswordVisible.toggle();
  void toggleConfirmPasswordVisibility() => isConfirmPasswordVisible.toggle();

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    return null;
  }

  String? validateConfirm(String? value) {
    if (value != newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      await _authRepository.completeFirstLogin(newPasswordController.text);
      final gateway = Get.find<GatewayController>();
      final destination = gateway.selectedRole.value == UserRole.admin
          ? AppRoutes.adminPanel
          : AppRoutes.home;
      Get.offAllNamed(destination);
    } on AuthErrorModel catch (e) {
      Get.snackbar(
        'Error',
        e.detail,
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on DioException catch (e) {
      final parsed = parseAuthError(e);
      Get.snackbar(
        'Error',
        parsed?.detail ?? e.message ?? 'Failed to set password. Please try again.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
```

---

### Step 8 — Create `lib/app/views/first_login_view.dart`

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/first_login_controller.dart';
import '../themes/app_colors.dart';

class FirstLoginView extends StatelessWidget {
  const FirstLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FirstLoginController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Password'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: controller.formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset_rounded,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Create your password',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account requires a new password before you can continue.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSubtle),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Obx(() => TextFormField(
                        controller: controller.newPasswordController,
                        obscureText: !controller.isPasswordVisible.value,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              controller.isPasswordVisible.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: controller.togglePasswordVisibility,
                          ),
                        ),
                        validator: controller.validatePassword,
                      )),
                  const SizedBox(height: 16),
                  Obx(() => TextFormField(
                        controller: controller.confirmPasswordController,
                        obscureText: !controller.isConfirmPasswordVisible.value,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              controller.isConfirmPasswordVisible.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: controller.toggleConfirmPasswordVisibility,
                          ),
                        ),
                        validator: controller.validateConfirm,
                      )),
                  const SizedBox(height: 28),
                  Obx(() => ElevatedButton(
                        onPressed:
                            controller.isLoading.value ? null : controller.submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: controller.isLoading.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Set Password',
                                style: TextStyle(color: Colors.white)),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### Step 9 — Create `lib/app/bindings/first_login_binding.dart`

```dart
import 'package:get/get.dart';

import '../controllers/first_login_controller.dart';
import '../data/repositories/auth_repository.dart';

class FirstLoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FirstLoginController>(
      () => FirstLoginController(authRepository: Get.find<AuthRepository>()),
    );
  }
}
```

---

### Step 10 — Register the route in `lib/app/routes/app_pages.dart`

Add import at the top of `app_pages.dart`:
```dart
import '../bindings/first_login_binding.dart';
import '../views/first_login_view.dart';
```

Add a new `GetPage` entry inside `routes` (after the login entry):
```dart
GetPage(
  name: AppRoutes.firstLogin,
  page: () => const FirstLoginView(),
  binding: FirstLoginBinding(),
  transition: Transition.fadeIn,
),
```

---

## TASK FE-4 — FE-01: Remove Hardcoded `tenantId` and `branchId`

**Severity:** Critical  
**Context:** The hardcoded UUIDs in `AppConstants` make the app structurally
single-tenant. The backend already resolves the tenant server-side from the user's
credentials when `tenant_id` is omitted. The `branchId` filter for the employee list
must come from the logged-in user's profile instead of a constant.

**Files to edit:**
- `lib/core/constants/app_constants.dart`
- `lib/app/data/models/auth/login_request_model.dart`
- `lib/app/data/repositories/auth_repository.dart` (already edited in FE-3)
- `lib/app/data/datasources/remote/attendance_remote_datasource.dart`
- `lib/app/data/repositories/attendance_repository.dart`
- `lib/app/controllers/attendance_controller.dart`

---

### Step 1 — Update `lib/core/constants/app_constants.dart`

Remove the hardcoded `tenantId` and `branchId`:

```dart
// BEFORE
abstract final class AppConstants {
  // ...
  static const String tenantId = 'a0000001-0001-4001-8001-000000000001';
  static const String branchId = 'a0000001-0001-4001-8001-000000000002';
  static const String attendanceSource = 'gps';
}
```

```dart
// AFTER — remove the two hardcoded lines entirely:
abstract final class AppConstants {
  // ...
  // tenantId removed — resolved server-side from credentials at login
  // branchId removed — comes from the user's profile after login
  static const String attendanceSource = 'gps';
}
```

---

### Step 2 — Update `lib/app/data/models/auth/login_request_model.dart`

Make `tenantId` optional so the server resolves it automatically:

```dart
// BEFORE
class LoginRequestModel {
  const LoginRequestModel({
    required this.identifier,
    required this.password,
    required this.tenantId,
  });

  final String identifier;
  final String password;
  final String tenantId;

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
        'tenant_id': tenantId,
      };
}
```

```dart
// AFTER
class LoginRequestModel {
  const LoginRequestModel({
    required this.identifier,
    required this.password,
    this.tenantId,              // <-- now optional
  });

  final String identifier;
  final String password;
  final String? tenantId;       // <-- nullable

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'identifier': identifier,
      'password': password,
    };
    if (tenantId != null) map['tenant_id'] = tenantId;
    return map;
  }
}
```

---

### Step 3 — Update `lib/app/data/repositories/auth_repository.dart`

Remove the `tenantId: AppConstants.tenantId` argument from the `LoginRequestModel`
constructor call inside `loginWithTokens()` (renamed in Task FE-3 Step 5):

```dart
// BEFORE
final tokens = await _remote.login(
  LoginRequestModel(
    identifier: identifier,
    password: password,
    tenantId: AppConstants.tenantId,   // <-- remove this
  ),
);
```

```dart
// AFTER
final tokens = await _remote.login(
  LoginRequestModel(
    identifier: identifier,
    password: password,
    // tenantId omitted — server resolves from credentials
  ),
);
```

If `AppConstants` is no longer imported in `auth_repository.dart` after removing this
reference, delete that import line.

---

### Step 4 — Store `branchId` from the login response

The backend returns user/profile data in the JWT payload including the tenant's default
branch. The simplest approach for now is to store `branchId` in `TokenStorage` after
login. First, the backend login response must expose the branch. Assuming that is handled
by the backend (the JWT payload already contains `branch_id` or the login response body
includes it), update `AuthTokenModel`:

```dart
// ADD field to AuthTokenModel:
final String? defaultBranchId;

// In fromJson:
defaultBranchId: json['branch_id'] as String?,

// In constructor:
this.defaultBranchId,
```

Then in `TokenStorage`, add branch storage:

```dart
// In token_storage.dart — ADD:
String? get branchId => _storage.read<String>('branch_id');

Future<void> persist({
  required String accessToken,
  required String refreshToken,
  String? branchId,            // <-- add optional param
}) async {
  await _storage.write(StorageKeys.accessToken, accessToken);
  await _storage.write(StorageKeys.refreshToken, refreshToken);
  if (branchId != null) {
    await _storage.write('branch_id', branchId);
  }
}

void clear() {
  _storage.remove(StorageKeys.accessToken);
  _storage.remove(StorageKeys.refreshToken);
  _storage.remove('branch_id');
}
```

Update `_persistTokens` in `auth_repository.dart`:

```dart
Future<void> _persistTokens(AuthTokenModel tokens) async {
  await _storage.persist(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    branchId: tokens.defaultBranchId,
  );
}
```

> **Fallback:** If the backend does not yet return `branch_id` in the login response,
> store an empty string and add a `null` guard in the datasource — the employee list
> call then omits the `branch_id` filter until the backend supports it.

---

### Step 5 — Update `lib/app/data/datasources/remote/attendance_remote_datasource.dart`

Accept `branchId` as a parameter instead of reading the constant:

```dart
// BEFORE
Future<List<EmployeeModel>> getEmployees() async {
  final response = await _dio.get<List<dynamic>>(
    '/v1/employees/clocked-in-status',
    queryParameters: {'branch_id': AppConstants.branchId},  // <-- remove
  );
  ...
}
```

```dart
// AFTER
Future<List<EmployeeModel>> getEmployees({String? branchId}) async {
  final response = await _dio.get<List<dynamic>>(
    '/v1/employees/clocked-in-status',
    queryParameters: branchId != null ? {'branch_id': branchId} : null,
  );
  ...
}
```

---

### Step 6 — Update `lib/app/data/repositories/attendance_repository.dart`

Pass the `branchId` through from `TokenStorage`:

```dart
// BEFORE
Future<List<EmployeeModel>> fetchEmployees() {
  return _remote.getEmployees();
}
```

```dart
// AFTER
class AttendanceRepository {
  AttendanceRepository({
    required AttendanceRemoteDataSource remote,
    required TokenStorage tokenStorage,  // <-- add dependency
  }) : _remote = remote,
       _tokenStorage = tokenStorage;

  final AttendanceRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  Future<List<EmployeeModel>> fetchEmployees() {
    return _remote.getEmployees(branchId: _tokenStorage.branchId);
  }
  ...
}
```

Add import:
```dart
import '../../../core/services/token_storage.dart';
```

---

### Step 7 — Update `lib/app/bindings/home_binding.dart`

Wire `TokenStorage` into `AttendanceRepository`:

```dart
// BEFORE
Get.put<AttendanceRepository>(
  AttendanceRepository(
    remote: Get.find<AttendanceRemoteDataSource>(),
  ),
  permanent: true,
);
```

```dart
// AFTER
Get.put<AttendanceRepository>(
  AttendanceRepository(
    remote: Get.find<AttendanceRemoteDataSource>(),
    tokenStorage: Get.find<TokenStorage>(),   // <-- add
  ),
  permanent: true,
);
```

---

## TASK FE-5 — FE-05: Encrypted Token Storage (`flutter_secure_storage`)

**Severity:** High  
**Prerequisite:** Task FE-1 must be completed first (TokenStorage service must exist).

By completing Task FE-1, swapping the storage backend is now a single-file change.

---

### Step 1 — Add dependency to `pubspec.yaml`

```yaml
dependencies:
  # ... existing deps ...
  flutter_secure_storage: ^9.2.4
```

Run:
```
flutter pub get
```

---

### Step 2 — Rewrite `lib/core/services/token_storage.dart`

Replace the entire file contents. The public API (`.accessToken`, `.refreshToken`,
`.branchId`, `.persist()`, `.clear()`) is unchanged so no other file needs editing.

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single source of truth for persisting and reading auth tokens.
/// Uses flutter_secure_storage (iOS Keychain / Android Keystore).
class TokenStorage {
  TokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyBranch = 'branch_id';

  // Cached in-memory after first read to avoid repeated async reads on hot path.
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedBranchId;

  // Synchronous getters return the in-memory cache.
  // Call loadFromStorage() once at app startup to warm the cache.
  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;
  String? get branchId => _cachedBranchId;

  /// Call once at startup (before any API calls) to warm the in-memory cache.
  Future<void> loadFromStorage() async {
    _cachedAccessToken = await _storage.read(key: _keyAccess);
    _cachedRefreshToken = await _storage.read(key: _keyRefresh);
    _cachedBranchId = await _storage.read(key: _keyBranch);
  }

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
    String? branchId,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    if (branchId != null) _cachedBranchId = branchId;
    await _storage.write(key: _keyAccess, value: accessToken);
    await _storage.write(key: _keyRefresh, value: refreshToken);
    if (branchId != null) await _storage.write(key: _keyBranch, value: branchId);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedBranchId = null;
    await _storage.deleteAll();
  }
}
```

---

### Step 3 — Update `lib/app/bindings/auth_binding.dart`

`TokenStorage` no longer needs `GetStorage` to be injected into it. Update the
constructor call:

```dart
// BEFORE
final rawStorage = GetStorage();
if (!Get.isRegistered<TokenStorage>()) {
  Get.put<TokenStorage>(TokenStorage(storage: rawStorage), permanent: true);
}
if (!Get.isRegistered<ApiClient>()) {
  Get.put<ApiClient>(ApiClient(rawStorage, Get.find<TokenStorage>()), permanent: true);
}
```

```dart
// AFTER
if (!Get.isRegistered<TokenStorage>()) {
  Get.put<TokenStorage>(TokenStorage(), permanent: true);   // no arg
}
if (!Get.isRegistered<ApiClient>()) {
  Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
}
```

Remove the `GetStorage` import and instantiation from `auth_binding.dart` if it is no
longer used for anything else.

---

### Step 4 — Update `lib/core/network/api_client.dart`

`ApiClient` no longer needs `GetStorage` (only `TokenStorage`):

```dart
// BEFORE
class ApiClient {
  ApiClient._(GetStorage rawStorage, TokenStorage tokenStorage) ...
  factory ApiClient(GetStorage rawStorage, TokenStorage tokenStorage) ...
```

```dart
// AFTER
class ApiClient {
  ApiClient._(TokenStorage tokenStorage) ...
  factory ApiClient(TokenStorage tokenStorage) ...
```

Remove `import 'package:get_storage/get_storage.dart';` from `api_client.dart` if
`GetStorage` is no longer referenced there.

---

### Step 5 — Call `loadFromStorage()` at app startup in `lib/main.dart`

```dart
// BEFORE
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  ...
  runApp(const YemenGateApp());
}
```

```dart
// AFTER
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();            // keep until full GetStorage migration is done
  final tokenStorage = TokenStorage();
  await tokenStorage.loadFromStorage();
  Get.put<TokenStorage>(tokenStorage, permanent: true);
  ...
  runApp(const YemenGateApp());
}
```

> With `TokenStorage` registered globally from `main()`, the `auth_binding.dart`
> `isRegistered` guard will prevent double-instantiation.

---

## TASK FE-6 — FE-08: Fix Silent 401 in `_loadEmployees`

**Severity:** Medium  
**File:** `lib/app/controllers/attendance_controller.dart`

The 401 status code is swallowed silently leaving the screen with no employees and no
error. The `AuthInterceptor` already handles token refresh and redirects on a second
consecutive 401, so reaching this catch block with a 401 means the session is
definitively expired and the interceptor has already redirected. The `return` is
therefore dead code that should be removed.

### Exact change

```dart
// BEFORE
} on DioException catch (e) {
  if (e.response?.statusCode == 401) return;   // <-- silent swallow
  Get.offAllNamed(AppRoutes.login);
}
```

```dart
// AFTER
} on DioException catch (e) {
  // 401s are handled by AuthInterceptor (redirect to login on retry failure).
  // Any other network error also redirects so the user can re-authenticate.
  Get.snackbar(
    'Session expired',
    'Please log in again.',
    snackPosition: SnackPosition.BOTTOM,
  );
  Get.offAllNamed(AppRoutes.login);
}
```

---

## TASK FE-7 — FE-10: Proactive Token Refresh on App Resume

**Severity:** Low  
**Files:** `lib/core/services/token_storage.dart`, `lib/main.dart`

When the app is foregrounded after a long background, the access token may be near
expiry. Rather than letting the first API call fail and trigger a refresh mid-action,
decode the token locally and refresh proactively if within 5 minutes of expiry.

---

### Step 1 — Add `dart_jsonwebtoken` dependency to `pubspec.yaml`

```yaml
dependencies:
  # ...
  dart_jsonwebtoken: ^2.8.4
```

Run: `flutter pub get`

---

### Step 2 — Add a `needsProactiveRefresh()` helper to `TokenStorage`

```dart
// ADD to lib/core/services/token_storage.dart:

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Returns true if the stored access token expires within [thresholdSeconds].
/// Returns false if token is absent, invalid, or not near expiry.
bool needsProactiveRefresh({int thresholdSeconds = 300}) {
  final token = _cachedAccessToken;
  if (token == null) return false;
  try {
    final jwt = JWT.decode(token);   // decode without verifying — no secret on client
    final exp = jwt.payload['exp'];
    if (exp is! int) return false;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    return DateTime.now().toUtc().isAfter(
          expiresAt.subtract(Duration(seconds: thresholdSeconds)),
        );
  } catch (_) {
    return false;
  }
}
```

---

### Step 3 — Mix `WidgetsBindingObserver` into the app root

Update `lib/main.dart` and `YemenGateApp`:

```dart
// Add WidgetsBindingObserver mixin to a stateful wrapper:

class YemenGateApp extends StatefulWidget {
  const YemenGateApp({super.key});

  @override
  State<YemenGateApp> createState() => _YemenGateAppState();
}

class _YemenGateAppState extends State<YemenGateApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshToken();
    }
  }

  Future<void> _maybeRefreshToken() async {
    final tokenStorage = Get.find<TokenStorage>();
    if (!tokenStorage.needsProactiveRefresh()) return;
    final refreshToken = tokenStorage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      final client = Get.find<ApiClient>();
      final newTokens = await executeRefreshRequest(client.plainDio, refreshToken);
      await tokenStorage.persist(
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
      );
    } catch (_) {
      // If proactive refresh fails, the next real API call will trigger
      // the AuthInterceptor's refresh-or-logout flow as normal.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Timesheet',           // FE-09: branding handled separately
      debugShowCheckedModeBanner: false,
      // ... rest of existing theme config ...
    );
  }
}
```

Add the required imports in `main.dart`:
```dart
import 'app/data/datasources/remote/auth_remote_datasource.dart';
import 'core/network/api_client.dart';
import 'core/services/token_storage.dart';
```

---

## TASK FE-8 — FE-06: Certificate Pinning

**Severity:** High  
**Note:** Certificate pinning requires access to the backend server's TLS certificate
public key (specifically the SPKI hash). This task defines the implementation pattern;
the executor must substitute the actual hash after extracting it from the certificate.

---

### Step 1 — Extract the certificate's public key hash

Run this command against the production host (from a trusted network):

```bash
openssl s_client -connect timesheetbackend.deepdownidea.com:443 -servername timesheetbackend.deepdownidea.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

Note the resulting base64 string — this is the SPKI pin.

---

### Step 2 — Add dependency to `pubspec.yaml`

```yaml
dependencies:
  # ...
  dio_pinning_interceptor: ^1.0.0
```

> **Alternative:** If `dio_pinning_interceptor` is unavailable or outdated at execution
> time, use `http_certificate_pinning: ^4.0.0` which works with Dio's `httpClientAdapter`.

Run: `flutter pub get`

---

### Step 3 — Update `lib/core/network/api_client.dart`

Add the pinning interceptor to both `plainDio` and `dio`:

```dart
import 'package:dio_pinning_interceptor/dio_pinning_interceptor.dart';

class ApiClient {
  // Replace "PASTE_BASE64_SPKI_PIN_HERE" with the hash from Step 1.
  static const _spkiPin = 'PASTE_BASE64_SPKI_PIN_HERE';

  ApiClient._(TokenStorage tokenStorage)
      : plainDio = Dio(BaseOptions(...)),
        dio = Dio(BaseOptions(...)) {

    plainDio.interceptors.add(
      DioPinningInterceptor(allowedSHAFingerprints: [_spkiPin]),
    );

    dio.interceptors.add(
      DioPinningInterceptor(allowedSHAFingerprints: [_spkiPin]),
    );
    dio.interceptors.add(
      AuthInterceptor(
        storage: tokenStorage,
        plainDio: plainDio,
        authenticatedDio: dio,
      ),
    );
  }
  ...
}
```

> **Important:** Keep the pinning interceptor before the `AuthInterceptor` in the
> interceptor chain so a TLS violation fails the request before the auth header is sent.

---

## Summary — Deployment Coordination

The following tasks have hard coupling with backend changes and must be deployed together:

| Frontend Task | Backend Task | What breaks if split |
|---|---|---|
| FE-2 (Task FE-2) | Backend Task 11 (C-03) | All clock-in/out fails with 401 |
| FE-3 (Task FE-3, steps 3–10) | Backend Task 10 (C-04+C-05) | First-login users can't set password; may be locked out |

All other tasks (FE-1, FE-4 through FE-8) are safe to deploy independently.

---

## Task Execution Order

```
FE-1  →  FE-2  →  FE-3  →  FE-4  →  FE-5  →  FE-6  →  FE-7  →  FE-8
```

FE-1 must be first (shared TokenStorage foundation).
FE-5 must come after FE-1 (replaces the storage backend inside TokenStorage).
FE-4 must come after FE-3 (reuses `loginWithTokens` rename introduced in FE-3).
All others are independent once FE-1 is done.
