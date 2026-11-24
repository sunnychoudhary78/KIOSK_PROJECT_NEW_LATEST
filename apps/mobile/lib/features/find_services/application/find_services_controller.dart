import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/find_services/data/find_services_catalog.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';

class FindServicesState {
  const FindServicesState({
    this.categories = const [],
    this.loading = false,
    this.error,
  });

  final List<LocalServiceCategory> categories;
  final bool loading;
  final String? error;
}

class FindServicesNotifier extends Notifier<FindServicesState> {
  @override
  FindServicesState build() => const FindServicesState();

  Future<void> load() async {
    state = const FindServicesState(loading: true);
    try {
      final result = await ref.read(apiClientProvider).get('/local-services');
      state = FindServicesState(categories: _parseCategories(result));
    } on ApiException catch (error) {
      // Prefer live API so admin panel changes show up. Bundle only if UAT
      // still rejects citizen (403) before that deploy lands.
      if (_shouldUseBundledCatalog(error)) {
        state = const FindServicesState(
          categories: FindServicesCatalog.categories,
        );
        return;
      }
      state = FindServicesState(error: error.toString());
    } catch (error) {
      state = FindServicesState(error: error.toString());
    }
  }

  bool _shouldUseBundledCatalog(ApiException error) {
    if (error.statusCode == 403) return true;
    final message = error.message.toLowerCase();
    return message.contains('principal type not allowed') ||
        error.code == 'forbidden';
  }

  List<LocalServiceCategory> _parseCategories(Map<String, dynamic> result) {
    final raw = result['categories'];
    final categories = <LocalServiceCategory>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          categories.add(
            LocalServiceCategory.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return categories;
  }
}

final findServicesProvider =
    NotifierProvider<FindServicesNotifier, FindServicesState>(
  FindServicesNotifier.new,
);
