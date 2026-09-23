import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/app_route_observer.dart';
import '../core/network/api_exception.dart';
import '../core/product/recredit_polling_coordinator.dart';
import 'home_provider.dart';
import 'product_flow_provider.dart';
import 'repository_provider.dart';

/// 等待授信页的轮询器。
///
/// 故意做成全局单例：用户中途返回首页时，轮询不会跟着页面一起销毁，
/// 授信完成后再由它把首页数据刷一遍（与 dali_cash 的常驻协调器一致）。
final recreditPollingCoordinatorProvider = Provider<RecreditPollingCoordinator>(
  (ref) {
    return RecreditPollingCoordinator(
      readStatus: () async {
        final repository = await ref.read(productRepositoryProvider.future);
        final response = await repository.recredit();
        if (!response.isSuccess) {
          throw ApiException(
            type: ApiFailureType.business,
            message: response.message,
            code: response.code,
          );
        }
        return response.data.isGranted;
      },
      currentRoute: () => appRouteObserver.currentRouteName,
      refreshHome: () => ref.read(homeDataProvider.notifier).refresh(),
      runAdmission: (productId) async {
        final flow = await ref.read(productApplicationFlowProvider.future);
        await flow.applyProduct(productId: productId);
      },
      logger: debugPrint,
    );
  },
);
