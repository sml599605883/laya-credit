import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/loan_confirm_data.dart';
import '../providers/loan_confirm_provider.dart';
import '../providers/repository_provider.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// 账号列表页交给调用方的结果（口径对齐 peso_shield 的 `AccountListResult`）。
///
/// 页面负责「拉列表 + 提交选中的账户（换绑）」，但**跳转留给调用方**：
/// 原生申请流程与 H5 桥（订单详情里更换打款账户）共用这一个页面，
/// 各自决定拿到订单详情页地址后是压新 WebView 还是在当前 WebView 里换地址。
sealed class LoanConfirmResult {
  const LoanConfirmResult();
}

/// 用户选中并换绑成功：[url] 是订单详情页地址。
class LoanConfirmAccountChanged extends LoanConfirmResult {
  const LoanConfirmAccountChanged(this.url);

  final String url;
}

/// 用户点了 `Add other payment methods`，要去新增一笔账户（走绑卡页改卡模式）。
class LoanConfirmAddPaymentMethod extends LoanConfirmResult {
  const LoanConfirmAddPaymentMethod();
}

/// 借款确认页（蓝湖稿 `04-01 - 确认借款-选择其它方式`）。
///
/// 页面把后端下发的可选收款账户（`POST /outsulk/heartfelt`）按 `Bank` /
/// `E-wallet` / `Cash Pickup` 分节列出来，选中一笔后点 `Upload` 提交换绑
/// （`POST /outsulk/bathtubs`，成功后打开后端给的订单详情页地址）。
/// 每张账户卡是「渠道 logo + 渠道名 + 右侧单选圈」一行，下面按账户类型分两种：
/// 银行 / 电子钱包是一行 `Receipt Account`（值右对齐），现金网点是等分的
/// `First / Middle / Last Name` 三列；维护中的账户在账户名下方补一行红字提示，
/// **仍可选中**（与绑卡页的单选面板口径一致）。
class LoanConfirmPage extends ConsumerStatefulWidget {
  const LoanConfirmPage({
    required this.productId,
    super.key,
    this.orderNo = '',
  });

  /// 产品 id（`tartarizing`），账户列表按它拉取。
  final String productId;

  /// 订单号（`resex`），提交换绑时回传，由产品申请流程从产品详情带下来。
  final String orderNo;

  @override
  ConsumerState<LoanConfirmPage> createState() => _LoanConfirmPageState();
}

class _LoanConfirmPageState extends ConsumerState<LoanConfirmPage> {
  /// 当前选中的账户 id（文档 `bindId`）。进入时取后端标的默认账户。
  String _selectedId = '';

  /// 已经把哪一份接口数据铺到选中态上，避免 build 里重复初始化。
  LoanConfirmData? _syncedData;

  /// 提交换绑进行中：挡住 `Upload`，避免同一笔订单提交两次。
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final info = ref.watch(loanConfirmProvider(widget.productId));

    info.whenData(_ensureSelection);

    return Scaffold(
      backgroundColor: AppColors.surfaceMint,
      body: Column(
        children: [
          BackNavBar(
            layout: layout,
            title: _navTitle,
            onBack: AppNavigator.pop,
          ),
          Expanded(child: _buildBody(layout, info)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(layout, info),
    );
  }

  /// 页面主体：Loading / Error / 空态 / 分节列表都收在这里。
  Widget _buildBody(AppLayout layout, AsyncValue<LoanConfirmData> info) {
    return info.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: switch (error) {
          ApiException(:final message) => message,
          _ => 'Failed to load, please try again',
        },
        onRetry: () => ref.invalidate(loanConfirmProvider(widget.productId)),
      ),
      data: (data) => SingleChildScrollView(
        padding: layout.edgeInsets(bottom: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.isEmpty)
              _buildEmptyState(layout)
            else
              for (var i = 0; i < data.groups.length; i++)
                if (data.groups[i].accounts.isNotEmpty)
                  ..._buildGroup(layout, data.groups[i], first: i == 0),
            _buildAddMethod(layout),
          ],
        ),
      ),
    );
  }

  /// 没有任何可选账户时的兜底文案；`Add other payment methods` 仍然可点。
  Widget _buildEmptyState(AppLayout layout) {
    return Padding(
      padding: layout.edgeInsets(
        top: AppSpacing.xl,
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
      ),
      child: Text(
        'No payment methods available',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: layout.px(14),
        ),
      ),
    );
  }

  /// 接口数据到位后只初始化一次选中态（用户点过的选择不能被重建覆盖）。
  void _ensureSelection(LoanConfirmData data) {
    if (identical(_syncedData, data)) return;
    _syncedData = data;
    _selectedId = data.selectedId;
  }

  /// 一个分节：分节标题 + 若干张账户卡。
  List<Widget> _buildGroup(
    AppLayout layout,
    LoanAccountGroup group, {
    required bool first,
  }) {
    return [
      Padding(
        padding: layout.edgeInsets(
          top: first ? _groupGapFirst : _groupGap,
          left: AppSpacing.pageHorizontal,
          right: AppSpacing.pageHorizontal,
        ),
        child: Text(
          group.title,
          style: TextStyle(
            color: AppColors.sectionTitle,
            fontSize: layout.px(16),
            fontWeight: FontWeight.w700,
            // 设计稿：`font-size: 16px; line-height: 19px`。
            height: 19 / 16,
          ),
        ),
      ),
      for (final account in group.accounts) _buildAccountCard(layout, account),
    ];
  }

  Widget _buildAccountCard(AppLayout layout, LoanAccount account) {
    final selected = account.id == _selectedId;

    return Padding(
      padding: layout.edgeInsets(
        top: _cardGap,
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: account.name,
        child: GestureDetector(
          key: Key('loan-confirm-card-${account.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedId = account.id),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.loanConfirmCardSelected
                  : AppColors.surface,
              borderRadius: layout.radius(AppSpacing.radiusBanner),
            ),
            padding: layout.edgeInsets(
              top: 17,
              bottom: 16,
              left: 12,
              right: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAccountHeader(layout, account, selected),
                if (account.underMaintenance) ...[
                  SizedBox(height: layout.px(_warningGap)),
                  Text(
                    _maintenanceWarning,
                    // 设计稿 `text_6`：宽 319、固定两行高。
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.loanConfirmWarning,
                      fontSize: layout.px(11),
                      // 设计稿：`font-size: 11px; line-height: 16px`。
                      height: 16 / 11,
                    ),
                  ),
                ],
                SizedBox(
                  height: layout.px(
                    selected ? _dividerGapSelected : _dividerGap,
                  ),
                ),
                _DashedDivider(
                  layout: layout,
                  color: selected
                      ? AppColors.loanConfirmDividerSelected
                      : AppColors.loanConfirmDivider,
                ),
                SizedBox(height: layout.px(_fieldsGap)),
                _buildAccountFields(layout, account, selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 账户卡第一行：渠道 logo + 渠道名 + 右侧单选圈。
  Widget _buildAccountHeader(
    AppLayout layout,
    LoanAccount account,
    bool selected,
  ) {
    return Row(
      children: [
        _buildLogo(layout, account.logoUrl),
        SizedBox(width: layout.px(_logoGap)),
        Expanded(
          child: Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.listItemTitle,
              fontSize: layout.px(16),
              fontWeight: FontWeight.w700,
              // 设计稿：`font-size: 16px; line-height: 16px`。
              height: 1,
            ),
          ),
        ),
        SizedBox(width: layout.px(_nameGap)),
        _buildRadio(layout, selected),
      ],
    );
  }

  /// 渠道 logo（设计稿「蒙版」24x24、4 圆角、`rgba(216,216,216)` 底 + 1pt 描边）。
  ///
  /// 接口还没给 logo 时留底色兜底，不留破图。
  Widget _buildLogo(AppLayout layout, String url) {
    return Container(
      width: layout.px(_logoSize),
      height: layout.px(_logoSize),
      decoration: BoxDecoration(
        color: AppColors.loanConfirmLogoPlaceholder,
        borderRadius: layout.radius(AppSpacing.radiusXs),
        border: Border.all(
          color: AppColors.loanConfirmLogoBorder,
          width: layout.px(1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: RemoteImage(url: url, fit: BoxFit.contain),
    );
  }

  /// 右侧单选圈（设计稿「形状」22x22）：选中态是墨色实心圆 + 白色对勾。
  Widget _buildRadio(AppLayout layout, bool selected) {
    return Image.asset(
      selected
          ? AppAssets.loanConfirmRadioChecked
          : AppAssets.loanConfirmRadioUnchecked,
      width: layout.px(_radioSize),
      height: layout.px(_radioSize),
    );
  }

  /// 账户卡下半部分：收款账号一行，或现金网点的三列姓名。
  Widget _buildAccountFields(
    AppLayout layout,
    LoanAccount account,
    bool selected,
  ) {
    final labelColor = selected
        ? AppColors.loanConfirmFieldLabelSelected
        : AppColors.loanConfirmFieldLabel;

    if (account.kind == LoanAccountKind.cashPickup) {
      return Row(
        children: [
          _buildNameColumn(layout, 'First Name', account.firstName, labelColor),
          _buildNameColumn(
            layout,
            'Middle Name',
            account.middleName,
            labelColor,
          ),
          _buildNameColumn(layout, 'Last Name', account.lastName, labelColor),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _receiptAccountLabel,
          style: TextStyle(
            color: labelColor,
            fontSize: layout.px(14),
            // 设计稿：`font-size: 14px; line-height: 18px`。
            height: 18 / 14,
          ),
        ),
        SizedBox(width: layout.px(AppSpacing.sm)),
        Expanded(
          child: Text(
            account.receiptAccount,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.listItemTitle,
              fontSize: layout.px(14),
              fontWeight: FontWeight.w700,
              // 设计稿：`font-size: 14px; line-height: 20px`。
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }

  /// 现金网点里等分的一列：10pt 灰色字段名 + 14pt 墨色值。
  Widget _buildNameColumn(
    AppLayout layout,
    String label,
    String value,
    Color labelColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: layout.px(10),
              // 设计稿：`font-size: 10px; line-height: 18px`。
              height: 18 / 10,
            ),
          ),
          SizedBox(height: layout.px(_nameValueGap)),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.listItemTitle,
              fontSize: layout.px(14),
              fontWeight: FontWeight.w700,
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }

  /// `Add other payment methods`：整块描边胶囊，加号与文案烘焙在切图里。
  Widget _buildAddMethod(AppLayout layout) {
    return Padding(
      padding: layout.edgeInsets(
        top: _addMethodGap,
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
      ),
      child: Semantics(
        button: true,
        child: GestureDetector(
          key: const Key('loan-confirm-add-method'),
          behavior: HitTestBehavior.opaque,
          onTap: _addPaymentMethod,
          child: Image.asset(
            AppAssets.loanConfirmAddMethod,
            height: layout.px(_addMethodHeight),
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  /// 底部固定操作条：白底 + 上方投影 + 柠檬绿 `Upload`。
  Widget _buildBottomBar(AppLayout layout, AsyncValue<LoanConfirmData> info) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            // 设计稿 `section_8 { box-shadow: 0 -5px 6px rgba(233,233,233,0.5) }`。
            color: AppColors.personalInfoBottomBarShadow,
            blurRadius: layout.px(6),
            offset: Offset(0, layout.px(-5)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: layout.edgeInsets(top: 14, bottom: 14),
          child: Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: UploadButton(
              layout: layout,
              // 没选到账户、列表还没回来或正在提交时按钮置灰。
              enabled:
                  !_isSubmitting &&
                  _selectedId.isNotEmpty &&
                  (info.value?.isEmpty == false),
              fontSize: _uploadFontSize,
              lineHeight: _uploadLineHeight,
              onTap: _upload,
            ),
          ),
        ),
      ),
    );
  }

  /// 提交选中的收款账户：换绑成功后把订单详情页地址回给调用方。
  Future<void> _upload() async {
    if (_selectedId.isEmpty || _isSubmitting) return;
    // TODO(埋点): 点击 Upload 提交换绑需要在 Firebase Analytics 上报事件。

    final orderNo = widget.orderNo.trim();
    if (orderNo.isEmpty) {
      ToastHelper.showError('Order information is missing');
      return;
    }

    setState(() => _isSubmitting = true);
    final loading = ToastHelper.showLoading();
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final response = await repository.changeBankCard(
        orderNo: orderNo,
        bindId: _selectedId,
      );
      if (!mounted) return;

      if (!response.isSuccess) {
        ToastHelper.showError(
          response.message.isNotEmpty
              ? response.message
              : 'Unable to change payment method',
        );
        return;
      }
      if (response.data.isEmpty) {
        ToastHelper.showError('Jump URL is missing');
        return;
      }

      loading();
      AppNavigator.pop<LoanConfirmResult>(
        LoanConfirmAccountChanged(response.data),
      );
    } on ApiException catch (error) {
      if (mounted) ToastHelper.showError(error.message);
    } catch (_) {
      if (mounted) ToastHelper.showError('Unable to change payment method');
    } finally {
      loading();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 新增一笔收款账户：把「去绑卡（改卡模式）」回给调用方。
  void _addPaymentMethod() {
    // TODO(埋点): 点击 Add other payment methods 需要在 Firebase Analytics 上报事件。
    AppNavigator.pop<LoanConfirmResult>(const LoanConfirmAddPaymentMethod());
  }
}

/// 导航标题（设计稿 `text_3`）。
const _navTitle = 'Loan Confirmation';

/// 设计稿 `text_7` / `text_10` 的字段名。
const _receiptAccountLabel = 'Receipt Account';

/// 账户维护中的提示文案（设计稿 `text_6`）。
///
/// 接口只下发 `catchpenny` 状态位、没有下发文案，所以照设计稿写死。
const _maintenanceWarning =
    'The bank is under maintenance. Loans may be delayed. '
    'Please wait or choose another option';

/// 第一个分节标题到导航行的间距（设计稿 `text_4` 的 `margin-top: 26`）。
///
/// 设计稿这个 26 是从导航行（24pt 的图标行）底边起算的，而 [BackNavBar] 的盒子
/// 因为把点击热区补到 40x40，比导航行本身多出 8pt，所以这里折算成 26 - 8。
const _groupGapFirst = 18.0;

/// 后续分节标题到上一张账户卡的间距（设计稿 `text_9` / `text_12` 的 `margin-top: 16`）。
const _groupGap = 16.0;

/// 分节标题到账户卡的间距（设计稿 `section_3` 的 `margin-top: 12`）。
const _cardGap = 12.0;

/// 账户名与维护中提示之间的间距（设计稿 `text_6` 的 `margin-top: 11`）。
const _warningGap = 11.0;

/// 选中卡内「维护中提示 / 账户名」到虚线的间距（设计稿 `image_2` 的 `margin-top: 16`）。
const _dividerGapSelected = 16.0;

/// 未选中卡内账户名到虚线的间距（设计稿 `image_3` 的 `margin-top: 19`）。
const _dividerGap = 19.0;

/// 虚线到账户字段的间距（设计稿 `text-wrapper_2` 的 `margin-top: 16`）。
const _fieldsGap = 16.0;

/// 「Add other payment methods」到账户卡的间距（设计稿 `section_7` 的 `margin-top: 16`）。
const _addMethodGap = 16.0;

/// 渠道 logo 边长（设计稿「蒙版」24x24）。
const _logoSize = 24.0;

/// logo 与账户名之间的间距（设计稿 `text_5` / `text-group_1` 的 `margin-left: 7`）。
const _logoGap = 7.0;

/// 账户名与右侧单选圈之间的最小间距（设计稿 `label_2` 的 `margin-left: 228` 是右对齐的摆法）。
const _nameGap = 12.0;

/// 单选圈直径（设计稿「形状」22x22）。
const _radioSize = 22.0;

/// 现金网点里字段名与值之间的间距（设计稿 `text_14` 的 `margin-top: 2`）。
const _nameValueGap = 2.0;

/// 「Add other payment methods」按钮高度（设计稿「矩形」343x48）。
const _addMethodHeight = 48.0;

/// 本页 `Upload` 文案字号 / 行高（设计稿 `text_19`：14 / 17）。
///
/// 与证件上传页的 16 / 22 不同，是同一张胶囊底图上的两种排版。
const _uploadFontSize = 14.0;
const _uploadLineHeight = 17.0;

/// 账户卡内的虚线分隔（设计稿「路径」318x1）。
///
/// Flutter 没有虚线边框，用 [CustomPainter] 画。设计稿里选中卡是白线、
/// 未选中卡是 `rgba(221,221,221)` 灰线，靠 [color] 切换。
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.layout, required this.color});

  final AppLayout layout;
  final Color color;

  /// 实 4 空 4。
  static const _dash = 4.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.px(1),
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashWidth: layout.px(_dash),
          gapWidth: layout.px(_dash),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gapWidth,
  });

  final Color color;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || dashWidth <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;

    for (var x = 0.0; x < size.width; x += dashWidth + gapWidth) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.gapWidth != gapWidth;
}
