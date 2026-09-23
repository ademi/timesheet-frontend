import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../attendance/bindings/attendance_binding.dart';
import '../../billing/bindings/billing_binding.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../documents/data/datasources/documents_remote_datasource.dart';
import '../../documents/data/document_pipeline.dart';
import '../../documents/sync/media_blob_store.dart';
import '../../documents/sync/media_outbox_store.dart';
import '../../documents/sync/media_sync_worker.dart';
import '../../payroll/bindings/payroll_binding.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../jobs/bindings/jobs_binding.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../shifts/data/datasources/shifts_remote_datasource.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../controllers/contractor_visits_controller.dart';
import '../controllers/staff_visits_controller.dart';
import '../controllers/visit_shift_brief_controller.dart';
import '../data/datasources/visits_remote_datasource.dart';
import '../data/repositories/visits_repository.dart';
import '../services/visit_location_service.dart';
import '../sync/outbox_store.dart';
import '../sync/sync_worker.dart';

class VisitsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
  }

  static void ensureShared() {
    BillingBinding.ensureShared();
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<VisitsRemoteDataSource>()) {
      Get.lazyPut<VisitsRemoteDataSource>(
        () =>
            VisitsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VisitsRepository>()) {
      Get.lazyPut<VisitsRepository>(
        () => VisitsRepository(remote: Get.find<VisitsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ShiftsRemoteDataSource>()) {
      Get.lazyPut<ShiftsRemoteDataSource>(
        () =>
            ShiftsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ShiftsRepository>()) {
      Get.lazyPut<ShiftsRepository>(
        () => ShiftsRepository(remote: Get.find<ShiftsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VisitLocationService>()) {
      Get.put<VisitLocationService>(const VisitLocationService());
    }
    if (!Get.isRegistered<OutboxStore>()) {
      Get.put<OutboxStore>(OutboxStore(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<SyncWorker>()) {
      final worker = SyncWorker(
        store: Get.find<OutboxStore>(),
        repository: Get.find<VisitsRepository>(),
        onChanged: () {
          if (Get.isRegistered<ContractorVisitsController>()) {
            Get.find<ContractorVisitsController>().outboxRevision.value++;
          }
        },
        onAcked: (item) {
          if (Get.isRegistered<ContractorVisitsController>()) {
            Get.find<ContractorVisitsController>().onOutboxAcked(item);
          }
        },
        onConflict: (item) {
          if (Get.isRegistered<ContractorVisitsController>()) {
            Get.find<ContractorVisitsController>().onOutboxConflict(item);
          }
        },
      );
      Get.put<SyncWorker>(worker, permanent: true);
      worker.start();
    }
    if (!Get.isRegistered<DocumentsRemoteDataSource>()) {
      Get.lazyPut<DocumentsRemoteDataSource>(
        () => DocumentsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<DocumentPipeline>()) {
      Get.lazyPut<DocumentPipeline>(
        () => DocumentPipeline(remote: Get.find<DocumentsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<MediaBlobStore>()) {
      Get.put<MediaBlobStore>(PathMediaBlobStore(), permanent: true);
    }
    if (!Get.isRegistered<MediaOutboxStore>()) {
      Get.put<MediaOutboxStore>(MediaOutboxStore(GetStorage()), permanent: true);
    }
    if (!Get.isRegistered<MediaSyncWorker>()) {
      final mediaWorker = MediaSyncWorker(
        store: Get.find<MediaOutboxStore>(),
        blobs: Get.find<MediaBlobStore>(),
        pipeline: Get.find<DocumentPipeline>(),
        onChanged: () {
          if (Get.isRegistered<ContractorVisitsController>()) {
            Get.find<ContractorVisitsController>().mediaOutboxRevision.value++;
          }
        },
        onAcked: (item) {
          if (Get.isRegistered<ContractorVisitsController>()) {
            Get.find<ContractorVisitsController>().onMediaOutboxAcked(item);
          }
        },
      );
      Get.put<MediaSyncWorker>(mediaWorker, permanent: true);
      mediaWorker.start();
    }
  }
}

class StaffVisitsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    JobsBinding.ensureShared();
    EngagementsBinding.ensureShared();
    PayrollBinding.ensureShared();
    ClientsBinding.ensureShared();
    AttendanceBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffVisitsController>()) {
      Get.put(
        StaffVisitsController(
          repository: Get.find<VisitsRepository>(),
          shiftsRepository: Get.find<ShiftsRepository>(),
          jobsRepository: Get.find<JobsRepository>(),
          engagementsRepository: Get.find<EngagementsRepository>(),
          clientsRepository: Get.find<ClientsRepository>(),
          session: Get.find<SessionService>(),
          payroll:
              Get.isRegistered<PayrollRepository>()
                  ? Get.find<PayrollRepository>()
                  : null,
        ),
      );
    }
  }
}

class ContractorVisitsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorVisitsController>()) {
      final controller = ContractorVisitsController(
        repository: Get.find<VisitsRepository>(),
        shiftsRepository: Get.find<ShiftsRepository>(),
        session: Get.find<SessionService>(),
        location: Get.find<VisitLocationService>(),
        outbox: Get.find<OutboxStore>(),
        syncWorker: Get.find<SyncWorker>(),
      );
      Get.put(controller);
    }
    if (!Get.isRegistered<VisitShiftBriefController>()) {
      Get.put(VisitShiftBriefController(repo: Get.find<VisitsRepository>()));
    }
  }
}
