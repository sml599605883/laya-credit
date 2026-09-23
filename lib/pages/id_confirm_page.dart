import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/report/report.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/identity_recognition.dart';
import '../providers/product_flow_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/certification_scaffold.dart';
import '../widgets/remote_image.dart';
import '../widgets/upload_button.dart';

/// 导航标题（设计稿 `text_10`）。
const _navTitle = 'ID Verification';

/// 引导段落相对导航行的下移量（设计稿：导航行底边 78 -> 段落顶边 112）。
///
/// 比证件上传页多 8pt：两张稿的导航行一致，段落位置不同。
const _promptGap = 26.0;

/// 引导段落宽度（设计稿 `text_4 { width: 190px }`）。
const _promptWidth = 190.0;

/// 接口没下发引导文案时的兜底（设计稿 `text_4`）。
///
/// 三行就是设计稿的换行位置：190pt 宽下 Helvetica-Bold 16 的断行结果。
/// 正常情况走产品详情下发的 `overwhelming.bocking`。
const _fallbackPrompt =
    'Confirm your ID details\n'
    'below to ensure funds\n'
    'land in your account.';

/// 白卡顶边（设计稿 `box_3 { top: 194 }`）：
/// 比头图底边高 19pt，白卡顶边压在头图下沿上。
const _cardTop = 194.0;

/// 白卡高度（设计稿 `box_3 { height: 396 }`）。
const _cardHeight = 396.0;

/// 白卡圆角（设计稿 `box_3 { border-radius: 12 }`）。
const _cardRadius = 12.0;

/// 证件照与白卡顶边（含 1pt 分隔线）的距离（设计稿 `box_5 { margin-top: 11 }`）。
const _idCardTop = 11.0;

/// 证件照尺寸（设计稿 `box_5`，319x200）。
const _idCardWidth = 319.0;
const _idCardHeight = 200.0;

/// 证件照的 2pt 白色描边（设计稿 `box_5 { border: 2px solid rgba(255,255,255,1) }`）。
const _idCardBorder = 2.0;

/// 信息行与证件照的距离（设计稿 `list_2 { margin-top: 12 }`）。
const _rowsTop = 12.0;

/// 信息行高度（设计稿 `text-wrapper_4`：14 + 20 + 14）。
const _rowHeight = 48.0;

/// 信息行之间的间距（设计稿 `text-wrapper_4 { margin-bottom: 8 }`）。
const _rowGap = 8.0;

/// 信息行圆角（设计稿 `text-wrapper_4 { border-radius: 4 }`）。
const _rowRadius = 4.0;

/// 白卡与 `Upload` 按钮之间的间距（设计稿 590 -> 714）。
const _cardToButtonGap = 124.0;

/// 按钮下沿到页面底边的留白（设计稿 762 -> 812，比手势条高，不用再补安全区）。
const _buttonBottom = 50.0;

/// 识别信息行的字段名（设计稿 `text_6`，与后端字段一一对应）。
const _nameLabel = 'Full Name';
const _idNumberLabel = 'ID No.';
const _birthDateLabel = 'Date of Birth';

/// 证件信息确认页（蓝湖稿 `03-01 - 身份认证-上传成功`），认证流程第三步。
///
/// 上传证件照成功后进这一页，让用户核对后端识别出的姓名 / 证件号 / 出生日期，
/// 确认无误再点 `Upload` 保存（`POST /outsulk/wardmote`）。页面分三段：
/// 1. 通栏头图（`section_1`）：绿色渐变 + 吉祥物。切图不带标题，导航标题与
///    引导段落由页面叠上去，返回按钮复用 [BackNavBar]。
/// 2. 白卡（`box_3`，343x396）：卡顶 1pt 分隔线、证件照（`box_5`，319x200）
///    与三行识别结果（`list_2`）。
/// 3. 底部 `Upload` 主按钮（`text-wrapper_3`）：柠檬绿胶囊，保存成功后继续
///    产品详情的下一步认证。
///
/// 识别结果由后端 OCR 下发，用户核对后可修正：姓名 / 证件号直接编辑，
/// 出生日期点开日期选择面板（`03-02 - 个人信息-日期选择`）改，提交用改后的值。
class IdConfirmPage extends ConsumerStatefulWidget {
  const IdConfirmPage({
    super.key,
    required this.productId,
    required this.cardType,
    required this.recognition,
  });

  /// 产品 id。
  final String productId;

  /// 选中的证件类型文案（保存接口的 `heterological`）。
  final String cardType;

  /// 后端识别出的身份信息。
  final IdentityRecognition recognition;

  @override
  ConsumerState<IdConfirmPage> createState() => _IdConfirmPageState();
}

class _IdConfirmPageState extends ConsumerState<IdConfirmPage> {
  /// 保存中：挡住 `Upload` 按钮，避免同一份资料被提交两次。
  bool _isSubmitting = false;

  /// 风控埋点场景 3（证件信息）的开始时间：进入本页时记录。
  late final int _sceneStartSeconds;

  /// 识别结果落到三个可编辑字段上，用户改完直接提交改后的值。
  late final TextEditingController _nameController;
  late final TextEditingController _idNumberController;
  late final TextEditingController _birthDateController;

  @override
  void initState() {
    super.initState();
    _sceneStartSeconds = ReportService.nowSeconds();
    final recognition = widget.recognition;
    _nameController = TextEditingController(text: recognition.name);
    _idNumberController = TextEditingController(text: recognition.idNumber);
    _birthDateController = TextEditingController(text: recognition.birthDate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    // 引导文案由产品详情 `overwhelming.bocking` 下发，没下发时用设计稿兜底。
    final cachedPrompt = ref
        .watch(sessionStoreProvider)
        .productDetailIdentitySuccessPrompt
        .trim();
    final prompt = cachedPrompt.isEmpty ? _fallbackPrompt : cachedPrompt;

    return CertificationScaffold(
      navTitle: _navTitle,
      prompt: prompt,
      promptGap: _promptGap,
      promptWidth: _promptWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: layout.px(_cardTop)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: _RecognitionCard(
              layout: layout,
              nameController: _nameController,
              idNumberController: _idNumberController,
              birthDateController: _birthDateController,
              imageUrl: widget.recognition.imageUrl,
              onPickBirthDate: _pickBirthDate,
            ),
          ),
          SizedBox(height: layout.px(_cardToButtonGap)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: UploadButton(
              layout: layout,
              enabled: !_isSubmitting,
              onTap: _save,
            ),
          ),
          SizedBox(height: layout.px(_buttonBottom)),
        ],
      ),
    );
  }

  /// 保存识别出的身份信息，成功后继续产品详情的下一步认证。
  Future<void> _save() async {
    if (_isSubmitting) return;

    final name = _nameController.text.trim();
    final idNumber = _idNumberController.text.trim();
    final birthDate = _birthDateController.text.trim();
    // 识别失败或用户清空字段都不能提交：空值后端也会拒，先给明确提示。
    if (name.isEmpty || idNumber.isEmpty || birthDate.isEmpty) {
      ToastHelper.showError('Please complete all fields');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final response = await repository.saveIdentityInfo(
        name: name,
        idNumber: idNumber,
        birthDate: birthDate,
        cardType: widget.cardType,
      );
      if (!mounted) return;

      if (!response.isSuccess) {
        ToastHelper.showError(
          response.message.isNotEmpty ? response.message : 'Save failed',
        );
        return;
      }

      // 风控埋点场景 3：结束时间是证件信息保存成功这一刻。
      unawaited(
        ReportService.current?.reportRisk(
              productId: widget.productId,
              scene: '3',
              startedAtSeconds: _sceneStartSeconds,
            ) ??
            Future<void>.value(),
      );

      final flow = await ref.read(productApplicationFlowProvider.future);
      if (mounted) {
        await flow.continueProductDetailFlow(widget.productId);
      }
    } on ApiException catch (error) {
      if (mounted) ToastHelper.showError(error.message);
    } catch (_) {
      if (mounted) ToastHelper.showError('Save failed, please try again');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 打开生日选择面板（蓝湖稿 `03-02 - 个人信息-日期选择`）。
  Future<void> _pickBirthDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final initial =
        IdentityRecognition.parseBirthDate(_birthDateController.text) ??
        DateTime(1997, 7, 15);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.idVerifyPickerBarrier,
      elevation: 0,
      // 面板自己带 16pt 顶部圆角。
      shape: const RoundedRectangleBorder(),
      builder: (context) =>
          _BirthDateSheet(layout: AppLayout.of(context), initialDate: initial),
    );
    if (picked == null) return;
    _birthDateController.text = IdentityRecognition.formatBirthDate(picked);
  }
}

/// 白卡（设计稿 `box_3`，343x396）：证件照 + 三行识别结果。
class _RecognitionCard extends StatelessWidget {
  const _RecognitionCard({
    required this.layout,
    required this.nameController,
    required this.idNumberController,
    required this.birthDateController,
    required this.imageUrl,
    required this.onPickBirthDate,
  });

  final AppLayout layout;
  final TextEditingController nameController;
  final TextEditingController idNumberController;
  final TextEditingController birthDateController;
  final String imageUrl;
  final VoidCallback onPickBirthDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: layout.px(_cardHeight),
      // 设计稿 `box_3 { padding-bottom: 12 }`。
      padding: layout.edgeInsets(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: layout.radius(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 卡顶 1pt 分隔线（设计稿 `box_4`，343x1 rgba(238,238,238)）。
          SizedBox(
            height: layout.px(1),
            child: const ColoredBox(color: AppColors.idVerifyDivider),
          ),
          SizedBox(height: layout.px(_idCardTop)),
          Center(child: _idCardImage()),
          SizedBox(height: layout.px(_rowsTop)),
          _field(
            key: const Key('id-confirm-name'),
            label: _nameLabel,
            controller: nameController,
          ),
          SizedBox(height: layout.px(_rowGap)),
          _field(
            key: const Key('id-confirm-id-number'),
            label: _idNumberLabel,
            controller: idNumberController,
          ),
          SizedBox(height: layout.px(_rowGap)),
          _field(
            key: const Key('id-confirm-birth-date'),
            label: _birthDateLabel,
            controller: birthDateController,
            readOnly: true,
            onTap: onPickBirthDate,
          ),
        ],
      ),
    );
  }

  /// 证件照（设计稿 `box_5`，319x200 + 12 圆角 + 2pt 白描边）。
  ///
  /// 优先展示后端下发的证件照地址，地址为空或加载失败时回落到设计稿切图。
  Widget _idCardImage() {
    return Container(
      width: layout.px(_idCardWidth),
      height: layout.px(_idCardHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: layout.radius(_cardRadius),
        border: Border.all(
          color: AppColors.surface,
          width: layout.px(_idCardBorder),
        ),
      ),
      child: RemoteImage(
        url: imageUrl,
        fallbackAsset: AppAssets.idVerifyIdCard,
      ),
    );
  }

  /// 一行识别结果（设计稿 `text-wrapper_4`）：左字段名、右字段值。
  ///
  /// 值是可编辑的：设计稿画的是只读态，但 OCR 会认错，用户要能就地改。
  /// 视觉保持设计稿的灰底行，不引入输入框边框。
  Widget _field({
    required Key key,
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      height: layout.px(_rowHeight),
      margin: layout.edgeInsets(left: 12, right: 12),
      padding: layout.edgeInsets(left: 12, right: 12),
      decoration: BoxDecoration(
        color: AppColors.idVerifyFieldBackground,
        borderRadius: layout.radius(_rowRadius),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.idVerifyFieldLabel,
              fontSize: layout.px(14),
              // 设计稿：`font-size: 14px; line-height: 20px`。
              height: 20 / 14,
            ),
          ),
          SizedBox(width: layout.px(12)),
          Expanded(
            child: TextField(
              key: key,
              controller: controller,
              readOnly: readOnly,
              onTap: onTap,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              maxLines: 1,
              textAlign: TextAlign.right,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: AppColors.idVerifyFieldValue,
              style: TextStyle(
                color: AppColors.idVerifyFieldValue,
                fontSize: layout.px(14),
                fontWeight: FontWeight.w700,
                height: 20 / 14,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 生日选择面板（蓝湖稿 `03-02 - 个人信息-日期选择`）。
///
/// 375x307 白面板 + 16pt 顶部圆角：右上角只有灰色 `Done`（没有 `Cancel`，
/// 点遮罩关闭），下面是日 / 月 / 年三列滚轮。滚轮行高 52.5、可视高 234，
/// 选中行加粗加深，上下各一条 1pt `#EEEEEE` 分隔线，两侧留 68 / 59。
class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({required this.layout, required this.initialDate});

  final AppLayout layout;
  final DateTime initialDate;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  /// 面板高度（设计稿 `矩形` @(0,505) 375x307）。
  static const _sheetHeight = 307.0;

  /// 顶部圆角（设计稿 `矩形` radius 16 16 0 0）。
  static const _sheetRadius = 16.0;

  /// 右上角 `Done`（设计稿 `text_1`：16px / line-height 19，右边距 15）。
  static const _headerTopPadding = 10.0;
  static const _headerHeight = 19.0;
  static const _doneRightPadding = 15.0;

  /// 滚轮区（设计稿 `group_1`）：上 22、下 12，可视高 234。
  static const _wheelTopPadding = 22.0;
  static const _wheelBottomPadding = 12.0;
  static const _wheelHeight = 234.0;

  /// 滚轮行高（设计稿 5 行中心间距 52.5）。
  static const _itemExtent = 52.5;

  /// 选中行上下分隔线的间距（设计稿 `text-wrapper_3`：11 + 24 + 15）。
  static const _selectionHeight = 50.0;

  /// 滚轮左右边距与三列宽度（设计稿 `text-wrapper_*`：left 68 / right 58）。
  static const _wheelLeftPadding = 68.0;
  static const _wheelRightPadding = 59.0;
  static const _dayWidth = 50.0;
  static const _monthWidth = 50.0;
  static const _yearWidth = 70.0;

  /// 年份下限。
  static const _firstYear = 1900;

  late int _year;
  late int _month;
  late int _day;

  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year.clamp(_firstYear, DateTime.now().year);
    _month = widget.initialDate.month;
    _day = widget.initialDate.day.clamp(1, _daysInMonth(_year, _month));
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _year - _firstYear,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  /// 某年某月的天数（下个月第 0 天就是本月最后一天）。
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  int get _yearCount => DateTime.now().year - _firstYear + 1;

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return Container(
      height: layout.px(_sheetHeight),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(layout.px(_sheetRadius)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: layout.px(_headerTopPadding)),
          SizedBox(
            height: layout.px(_headerHeight),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: layout.edgeInsets(right: _doneRightPadding),
                child: GestureDetector(
                  key: const Key('id-confirm-birth-done'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _done,
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.idVerifyFieldLabel,
                      fontSize: layout.px(16),
                      // 设计稿：`font-size: 16px; line-height: 19px`。
                      height: 19 / 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: layout.px(10)),
          Padding(
            padding: layout.edgeInsets(
              top: _wheelTopPadding,
              bottom: _wheelBottomPadding,
            ),
            child: SizedBox(
              height: layout.px(_wheelHeight),
              child: Stack(
                children: [
                  // 选中行上下各一条 1pt 分隔线（设计稿 `text-wrapper_3` 的描边）。
                  _selectionLine(
                    layout,
                    _wheelHeight / 2 - _selectionHeight / 2,
                  ),
                  _selectionLine(
                    layout,
                    _wheelHeight / 2 + _selectionHeight / 2,
                  ),
                  Padding(
                    padding: layout.edgeInsets(
                      left: _wheelLeftPadding,
                      right: _wheelRightPadding,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: layout.px(_dayWidth),
                          child: _wheel(
                            wheelKey: const Key('id-confirm-birth-day'),
                            count: _daysInMonth(_year, _month),
                            controller: _dayController,
                            selectedIndex: _day - 1,
                            onChanged: _onDayChanged,
                            labelOf: (index) => '${index + 1}',
                          ),
                        ),
                        SizedBox(
                          width: layout.px(_monthWidth),
                          child: _wheel(
                            wheelKey: const Key('id-confirm-birth-month'),
                            count: 12,
                            controller: _monthController,
                            selectedIndex: _month - 1,
                            onChanged: _onMonthChanged,
                            labelOf: (index) => '${index + 1}',
                          ),
                        ),
                        SizedBox(
                          width: layout.px(_yearWidth),
                          child: _wheel(
                            wheelKey: const Key('id-confirm-birth-year'),
                            count: _yearCount,
                            controller: _yearController,
                            selectedIndex: _year - _firstYear,
                            onChanged: _onYearChanged,
                            labelOf: (index) => '${_firstYear + index}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionLine(AppLayout layout, double top) => Positioned(
    top: layout.px(top),
    left: 0,
    right: 0,
    child: SizedBox(
      height: layout.px(1),
      child: const ColoredBox(color: AppColors.idVerifyDivider),
    ),
  );

  /// 一列滚轮。设计稿的行是平的（没有 3D 透视），深浅靠每行颜色拉开：
  /// 选中行 `#0D1B17` 加粗，相邻行 `#666666`，再往外 `#999999`。
  Widget _wheel({
    required Key wheelKey,
    required int count,
    required FixedExtentScrollController controller,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    required String Function(int index) labelOf,
  }) {
    final layout = widget.layout;
    return ListWheelScrollView.useDelegate(
      key: wheelKey,
      controller: controller,
      itemExtent: layout.px(_itemExtent),
      physics: const FixedExtentScrollPhysics(),
      // 设计稿的行是平的：透视取最小值，避免出现 3D 缩放。
      perspective: 0.0001,
      diameterRatio: 1.0,
      overAndUnderCenterOpacity: 1.0,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          final distance = (index - selectedIndex).abs();
          final selected = distance == 0;
          return Center(
            child: Text(
              labelOf(index),
              // 设计稿 `white-space: nowrap`：列宽不足时也不换行。
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: selected
                    ? AppColors.idVerifyPickerTextSelected
                    : distance == 1
                    ? AppColors.idVerifyPickerTextNear
                    : AppColors.idVerifyFieldLabel,
                fontSize: layout.px(20),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                // 设计稿：`font-size: 20px; line-height: 24px`。
                height: 24 / 20,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onDayChanged(int index) => setState(() => _day = index + 1);

  void _onMonthChanged(int index) {
    final month = index + 1;
    _clampDay(_daysInMonth(_year, month));
    setState(() => _month = month);
  }

  void _onYearChanged(int index) {
    final year = _firstYear + index;
    _clampDay(_daysInMonth(year, _month));
    setState(() => _year = year);
  }

  /// 换月 / 换年后把日收进当月范围（2 月没有 30 号）。
  ///
  /// 在 setState 之前先把日滚轮拨回去：新 childCount 比旧选中下标小时，
  /// `ListWheelScrollView` 会直接断言失败。
  void _clampDay(int maxDay) {
    if (_day <= maxDay) return;
    _day = maxDay;
    if (_dayController.hasClients) _dayController.jumpToItem(maxDay - 1);
  }

  void _done() => Navigator.pop(context, DateTime(_year, _month, _day));
}
