import '../../../core/services/token_storage.dart';
import '../datasources/remote/document_remote_datasource.dart';

class DocumentRepository {
  DocumentRepository({
    required DocumentRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final DocumentRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;

  DocumentRemoteDataSource get remote => _remote;
}
