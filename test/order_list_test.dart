import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/navigation/app_deep_link.dart';
import 'package:laya_credit/core/navigation/app_navigator.dart';
import 'package:laya_credit/core/navigation/app_route_generator.dart';
import 'package:laya_credit/core/navigation/app_routes.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/product/recredit_polling_coordinator.dart';
import 'package:laya_credit/data/models/order_list_data.dart';
import 'package:laya_credit/data/repositories/order_repository.dart';
import 'package:laya_credit/pages/order_list_page.dart';
import 'package:laya_credit/pages/recredit_page.dart';
import 'package:laya_credit/providers/order_list_provider.dart';
import 'package:laya_credit/providers/recredit_provider.dart';
import 'package:laya_credit/providers/repository_provider.dart';

OrderListItem _item({
  int orderId = 4,
  String productName = 'PG Finance',
  int statusCode = OrderStatusCode.pendingRepay,
  String statusText = 'Outstanding',
  String actionText = 'Repay Now',
  String cardTarget = '/order/detail?orderId=4',
}) {
  return OrderListItem(
    orderId: orderId,
    orderNo: '672024120400405591971039',
    productId: '1',
    productName: productName,
    productLogo: '',
    statusCode: statusCode,
    statusText: statusText,
    amountText: '₱20.000',
    amountLabel: 'Available up to',
    actionText: actionText,
    legacyTarget: '/order/detail?orderId=4',
    dateLabel: 'Due Date',
    dateValue: '29-11-2023',
    overdueDays: 0,
    cardTarget: cardTarget,
    actionTarget: '/repayment-detail?orderNo=x&tab=1',
  );
}

/// 假的订单列表仓库：按页返回预置数据，并记录请求过哪些页。
class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository(this.pages, {this.failPages = const {}});

  /// 每一页的订单，长度即总页数。
  final List<List<OrderListItem>> pages;

  /// 这些页号的请求会失败（用来测「翻页失败」分支）。
  final Set<int> failPages;

  final List<int> requestedPages = [];

  @override
  Future<ApiResponse<OrderListResult>> getOrderList({
    required String status,
    int page = 1,
    int pageSize = 50,
  }) async {
    requestedPages.add(page);
    if (failPages.contains(page)) {
      return const ApiResponse(
        code: 500,
        message: 'Server error',
        data: OrderListResult(items: [], totalPages: 1),
      );
    }
    return ApiResponse(
      code: 0,
      message: 'success',
      data: OrderListResult(
        items: page <= pages.length ? pages[page - 1] : const [],
        totalPages: pages.isEmpty ? 1 : pages.length,
      ),
    );
  }
}

/// 挂一个假仓库，页面即可拿到真实分页逻辑；返回容器方便直接驱动 notifier。
Future<ProviderContainer> _pumpWithRepository(
  WidgetTester tester,
  _FakeOrderRepository repository, {
  Widget child = const MaterialApp(home: OrderListPage()),
}) async {
  final container = ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: child),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('parseOrderListItems', () {
    test('按接口文档字段解析', () {
      final items = parseOrderListItems({
        'kneeing': [
          {
            'gasking': 4,
            'pirate': '672024120400405591971039',
            'podostemon': 1,
            'heartfelt': 'Vplus Pro',
            'bathtubs': 'http://xxx.png',
            'polyphonist': 21,
            'minivan': 'Under Review',
            'grassroots': '₱ 2,000',
            'modest': 'Loan Amount',
            'curitiba': 'Details',
            'rondelle': 'http://xxx/loanDetailUrl',
            'devexity': 'Application Date',
            'hospitalizes': '04-12-2024',
            'ozonic': 0,
            'danubian': '/order/detail?orderId=4',
            'trans': '/repayment-detail?orderNo=xxx&tab=1',
          },
        ],
        'contraception': 1,
      });

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.orderId, 4);
      expect(item.productName, 'Vplus Pro');
      expect(item.statusText, 'Under Review');
      expect(item.amountText, '₱ 2,000');
      expect(item.actionText, 'Details');
      expect(item.cardTarget, '/order/detail?orderId=4');
      expect(item.actionTarget, '/repayment-detail?orderNo=xxx&tab=1');
      // 文档示例的状态码 21（Under Review）不属于 179/180，按终态处理。
      expect(item.statusTone, OrderStatusTone.neutral);
      expect(item.hasAction, isFalse);
      expect(item.isOverdue, isFalse);
    });

    test('缺 danubian 时卡片跳转回落 rondelle', () {
      final items = parseOrderListItems({
        'kneeing': [
          {
            'gasking': 4,
            'polyphonist': 179,
            'rondelle': 'http://xxx/loanDetailUrl',
          },
        ],
      });

      expect(items.single.cardTarget, isEmpty);
      expect(items.single.detailTarget, 'http://xxx/loanDetailUrl');
    });

    test('缺字段时回落空列表而不是抛异常', () {
      expect(parseOrderListItems(null), isEmpty);
      expect(parseOrderListItems(const {}), isEmpty);
      expect(parseOrderListItems(const {'kneeing': 'not-a-list'}), isEmpty);
    });
  });

  group('OrderListItem.statusTone', () {
    test('179 待还款判为进行中并展示主按钮', () {
      final item = _item(statusCode: OrderStatusCode.pendingRepay);
      expect(item.statusTone, OrderStatusTone.active);
      expect(item.isOverdue, isFalse);
      expect(item.hasAction, isTrue);
    });

    test('180 逾期判为逾期并展示主按钮', () {
      final item = _item(
        statusCode: OrderStatusCode.overdue,
        statusText: 'Overdue',
      );
      expect(item.statusTone, OrderStatusTone.overdue);
      expect(item.isOverdue, isTrue);
      expect(item.hasAction, isTrue);
    });

    test('其余状态码判为终态且不展示主按钮', () {
      final item = _item(statusCode: 21, statusText: 'Settled');
      expect(item.statusTone, OrderStatusTone.neutral);
      expect(item.isOverdue, isFalse);
      expect(item.hasAction, isFalse);
    });
  });

  group('订单列表跳转节点', () {
    test('深链 order 别名解析出筛选状态并指向订单列表路由', () {
      final link = const AppDeepLinkParser().parse(
        'ph://laya-credit/ios/AsepticizingCriminalist?butterpaste=6',
      );

      expect(link.kind, AppDeepLinkKind.order);
      expect(link.route, AppRoutes.orderList);
      expect(link.orderStatus, OrderFilterStatus.toRepay);
    });

    test('深链缺 butterpaste 时筛选状态为空，由页面回落全部', () {
      final link = const AppDeepLinkParser().parse(
        'ph://laya-credit/ios/AsepticizingCriminalist',
      );

      expect(link.kind, AppDeepLinkKind.order);
      expect(link.orderStatus, isNull);
    });

    test('订单列表路由已注册', () {
      expect(AppRoutes.isValid(AppRoutes.orderList), isTrue);
    });
  });

  group('订单列表跳转入口', () {
    Future<void> pumpHarness(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWith(
            (ref) async => _FakeOrderRepository(const [[]]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: AppNavigator.navigatorKey,
            onGenerateRoute: AppRouteGenerator.onGenerateRoute,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
    }

    testWidgets('深链 order 目标由统一入口分发到订单列表并带筛选状态', (tester) async {
      await pumpHarness(tester);

      var unhandled = false;
      // 订单列表是压栈页面，openDeepLink 会一直等到它被 pop 才返回，所以这里不等它。
      unawaited(
        AppNavigator.openDeepLink(
          const AppDeepLinkParser().parse(
            'ph://laya-credit/ios/AsepticizingCriminalist?butterpaste=6',
          ),
          onUnhandled: (link) async => unhandled = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(unhandled, isFalse);
      final page = tester.widget<OrderListPage>(find.byType(OrderListPage));
      expect(page.initialStatus, OrderFilterStatus.toRepay);
    });

    testWidgets('深链缺筛选状态时订单列表默认全部', (tester) async {
      await pumpHarness(tester);

      unawaited(
        AppNavigator.openDeepLink(
          const AppDeepLinkParser().parse(
            'ph://laya-credit/ios/AsepticizingCriminalist',
          ),
          onUnhandled: (link) async {},
        ),
      );
      await tester.pumpAndSettle();

      final page = tester.widget<OrderListPage>(find.byType(OrderListPage));
      expect(page.initialStatus, OrderFilterStatus.all);
    });

    testWidgets('没有页面承载的目标交回给调用方处理', (tester) async {
      await pumpHarness(tester);

      AppDeepLink? handled;
      await AppNavigator.openDeepLink(
        const AppDeepLinkParser().parse(
          'ph://laya-credit/ios/UnworshippingPigeonberries',
        ),
        onUnhandled: (link) async => handled = link,
      );

      expect(handled?.kind, AppDeepLinkKind.productDetail);
      expect(find.byType(OrderListPage), findsNothing);
    });
  });

  group('OrderListPage', () {
    Future<void> pumpPage(
      WidgetTester tester,
      List<OrderListItem> items,
    ) async {
      await _pumpWithRepository(tester, _FakeOrderRepository([items]));
    }

    testWidgets('无订单展示空态插画与文案', (tester) async {
      await pumpPage(tester, const []);

      expect(find.byKey(const Key('order-list-empty-image')), findsOneWidget);
      expect(find.text('No information available'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('有订单展示卡片字段与主按钮', (tester) async {
      await pumpPage(tester, [_item()]);

      expect(find.text('PG Finance'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('₱20.000'), findsOneWidget);
      expect(find.text('29-11-2023'), findsOneWidget);
      expect(find.text('Repay Now'), findsOneWidget);
      expect(find.byKey(const Key('order-list-empty-image')), findsNothing);
    });

    testWidgets('终态订单不展示主按钮', (tester) async {
      await pumpPage(tester, [
        _item(statusCode: 21, statusText: 'Settled', actionText: ''),
      ]);

      expect(find.text('Repay Now'), findsNothing);
    });

    testWidgets('卡片原生深链目标分发到等待授信页', (tester) async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWith(
            (ref) async => _FakeOrderRepository([
              [
                _item(
                  cardTarget:
                      'ph://laya-credit/ios/IntervesicularSauder'
                      '?tartarizing=P-3',
                ),
              ],
            ]),
          ),
          recreditPollingCoordinatorProvider.overrideWithValue(
            RecreditPollingCoordinator(
              readStatus: () => Completer<bool>().future,
              currentRoute: () => AppRoutes.recredit,
              refreshHome: () async {},
              runAdmission: (_) async {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: AppNavigator.navigatorKey,
            onGenerateRoute: AppRouteGenerator.onGenerateRoute,
            home: const OrderListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('PG Finance'));
      await tester.pump();
      await tester.pump();

      final page = tester.widget<RecreditPage>(find.byType(RecreditPage));
      expect(page.productId, 'P-3');
    });
  });

  group('订单列表分页', () {
    /// 第一页给足卡片，列表才滚得动。
    List<OrderListItem> firstPage() => [
      for (var i = 0; i < 20; i++) _item(orderId: i),
    ];

    testWidgets('触底请求下一页并把新数据接在后面', (tester) async {
      final repository = _FakeOrderRepository([
        firstPage(),
        [_item(orderId: 99, productName: 'Second Page')],
      ]);
      await _pumpWithRepository(tester, repository);

      expect(repository.requestedPages, [1]);
      expect(find.text('Second Page'), findsNothing);

      await tester.drag(
        find.byKey(const Key('order-list-scroll')),
        const Offset(0, -4000),
      );
      // 触底后请求下一页；转圈是无限动画，这里只 pump 不 settle。
      await tester.pump();
      await tester.pump();

      expect(repository.requestedPages, [1, 2]);
      expect(find.text('Second Page'), findsOneWidget);
      expect(find.text('PG Finance'), findsWidgets);
    });

    testWidgets('只有一页时触底不再请求', (tester) async {
      final repository = _FakeOrderRepository([firstPage()]);
      await _pumpWithRepository(tester, repository);

      await tester.drag(
        find.byKey(const Key('order-list-scroll')),
        const Offset(0, -4000),
      );
      await tester.pump();

      expect(repository.requestedPages, [1]);
      expect(find.byKey(const Key('order-list-load-more')), findsNothing);
    });

    testWidgets('翻页失败保留已加载数据并可重试', (tester) async {
      // 第一页只放一张卡，底部的重试入口才在屏幕内、点得到。
      final repository = _FakeOrderRepository(
        [
          [_item()],
          [_item(orderId: 99, productName: 'Second Page')],
        ],
        failPages: {2},
      );
      final container = await _pumpWithRepository(tester, repository);

      await container.read(orderListProvider('4').notifier).loadMore();
      await tester.pump();
      await tester.pump();

      // 第一页的数据没被清掉，只是多了一个重试入口。
      expect(find.text('PG Finance'), findsOneWidget);
      expect(
        find.byKey(const Key('order-list-load-more-retry')),
        findsOneWidget,
      );

      repository.failPages.clear();
      await tester.tap(find.byKey(const Key('order-list-load-more-retry')));
      await tester.pump();
      await tester.pump();

      expect(repository.requestedPages, [1, 2, 2]);
      expect(find.text('Second Page'), findsOneWidget);
      expect(find.byKey(const Key('order-list-load-more-retry')), findsNothing);
    });
  });
}
