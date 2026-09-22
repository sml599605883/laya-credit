import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/identity_photo_permission.dart';
import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/network/api_fields.dart';
import '../core/network/api_response.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/bind_card_data.dart';
import '../providers/bind_card_provider.dart';
import '../providers/liveness_provider.dart';
import '../providers/product_flow_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/certification_scaffold.dart';
import '../widgets/field_chevron.dart';
import '../widgets/state_views.dart';
import '../widgets/upload_button.dart';
import 'widgets/bind_card_option_sheet.dart';

/// 导航标题（设计稿 `text_19` / `text_24`）。
const _navTitle = 'Account management';

/// 接口没下发引导文案时的兜底（设计稿 `text_4`）。
///
/// 正常情况走产品详情下发的 `overwhelming.mobilization`，其次走获取绑卡信息接口的
/// `befleas`，都没有（低版本 / 未灰度用户）时才落到这里。
const _fallbackPrompt =
    'Check that your receiving\n'
    'account is active, belongs\n'
    'to you, and can receive\n'
    'funds before continuing.';

/// 引导段落相对导航行的下移量（设计稿 `text-wrapper_9 { margin-top: 26 }`）。
const _promptGap = 26.0;

/// 引导段落宽度（设计稿 `text_4 { width: 185px }`）。
const _promptWidth = 185.0;

/// 进度缎带的顶边（设计稿 `text-wrapper_3 { top: 185 }`）。
const _ribbonTop = 185.0;

/// 缎带高度（与个人信息 / 工作信息 / 紧急联系人共用同一张切图，343x33）。
const _ribbonHeight = 33.0;

/// 缎带上的进度文案（设计稿 `text_5`）。
///
/// 文档没有下发进度百分比的字段，先按设计稿写死；接入进度接口后再换成下发值。
const _progressText = '100%';

/// 白卡圆角（设计稿 `box_4`，343x336）。
const _cardRadius = 12.0;

/// 白卡左右内边距（设计稿 `box_4 { padding: ... 11px ... 12px }`）。
const _cardLeft = 12.0;
const _cardRight = 11.0;

/// 缎带下沿到卡片内容的距离（设计稿：缎带下沿 218，内容顶边 230）。
const _cardTop = 12.0;

/// 白卡底部内边距。
const _cardBottom = 14.0;

/// 打款方式 Tab 的高度（设计稿 `text-wrapper_5`：5 + 19 + 4）。
const _tabHeight = 28.0;

/// 选中 Tab 的圆角与左右内边距（设计稿 `text-wrapper_5 { border-radius: 16; padding: 5 12 4 12 }`）。
const _tabRadius = 16.0;
const _tabHorizontal = 12.0;

/// Tab 行与第一个字段标题的距离（设计稿 `text_11 { margin-top: 12 }`）。
const _tabToFields = 12.0;

/// 字段标题高度（设计稿 `text_11 { line-height: 22 }`）。
const _labelHeight = 22.0;

/// 标题到取值行的距离（设计稿 `group_4 { margin-top: 8 }`）。
const _labelToRow = 8.0;

/// 取值行高度（设计稿 `group_4`：14 + 20 + 14）。
const _rowHeight = 48.0;

/// 字段之间的间距（设计稿：取值行底 348，下一个标题顶 360）。
const _fieldGap = 12.0;

/// 卡片底部红色提示的宽高与上边距（设计稿 `group_5` / `text_6`）。
const _bottomPromptWidth = 307.0;
const _bottomPromptGap = 16.0;

/// 自动填充气泡的尺寸（设计稿 `group_3`：22 高、4 圆角、padding 4 5 4 4）。
const _suggestionHeight = 22.0;
const _suggestionRadius = 4.0;
const _suggestionLeft = 4.0;
const _suggestionRight = 5.0;

/// 气泡右侧关闭按钮的边长（设计稿 `thumbnail_4`，12x12）。
const _suggestionCloseSize = 12.0;

/// Loading / Error / Empty 态在卡内的最小高度。
const _stateHeight = 200.0;

/// 提交绑卡返回的特殊 code：后端要求先做活体，做完带活体参数再提交一次。
const _codeNeedsLiveness = 20000;

/// 绑卡页（蓝湖稿 `03-05 - 绑定账户`，认证第五项）。
///
/// 页面分三段，与设计稿一一对应：
/// 1. 通栏头图（`box_1`）：绿色渐变 + 吉祥物，复用证件上传页那张没有标题的切图；
///    导航标题与引导段落由页面叠上去，返回按钮复用 [BackNavBar]。
/// 2. 白卡（`box_4`）：卡顶是 33pt 高的进度缎带（设计稿 `100%`），
///    卡内是打款方式 Tab + 后端下发的字段列表。
/// 3. 底部固定操作条：红色提示文案 + 柠檬绿 `Upload` 按钮。
///
/// 打款方式分组、每个分组的字段与下拉渠道全部由后端下发
/// （`GET /outsulk/cussedly`），页面不写死任何一条。
/// 提交后若后端返回 `20000`，先拉起活体（token 走 `type = 1`），
/// 再把活体结果连同原字段重提交一次。
class BindCardPage extends ConsumerStatefulWidget {
  const BindCardPage({
    required this.productId,
    super.key,
    this.orderNo = '',
    this.isAccountChange = false,
  });

  /// 产品 id，分组 / 字段与提交都按它取值。
  final String productId;

  /// 订单号（`resex`），活体 token 接口要用，由产品申请流程从产品详情带下来。
  final String orderNo;

  /// 改卡场景（订单详情里更换打款账户）。
  ///
  /// 打开时跟认证流程一样拉表单，但提交成功后**不发**下一步认证：用返回的
  /// 绑卡 id 调更换银行卡接口，再把订单详情页地址 pop 给调用方
  /// （口径对齐 peso_shield 的 `isAccountChange`）。
  final bool isAccountChange;

  @override
  ConsumerState<BindCardPage> createState() => _BindCardPageState();
}

class _BindCardPageState extends ConsumerState<BindCardPage> {
  /// 提交 / 活体进行中：挡住 `Upload` 按钮，避免同一笔绑卡提交两次。
  bool _isSubmitting = false;

  /// 当前选中的打款方式分组（后端的 `cardType`）。
  String _selectedType = '';

  /// 已经把哪一份接口数据铺到表单上，避免 build 里重复初始化。
  BindCardData? _syncedData;

  /// 每个字段的提交值（选项类字段是 `liquidators`，不是展示文案）。
  final _values = <String, String>{};

  /// 每个字段的输入框；选项类字段只借它存展示文案。
  final _controllers = <String, TextEditingController>{};

  /// 每个输入框的焦点（自动填充气泡要判断「聚焦且为空」）。
  final _focusNodes = <String, FocusNode>{};

  /// 用户点过关闭的气泡：同一个字段不再自动弹出。
  final _dismissedSuggestions = <String>{};

  /// 当前正在展示气泡的字段 key。
  String? _activeSuggestion;

  @override
  void dispose() {
    _disposeFieldState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final info = ref.watch(bindCardProvider(widget.productId));

    // 引导文案：产品详情下发的优先，其次接口的 `befleas`，都没有时用设计稿兜底。
    final cachedPrompt = ref
        .watch(sessionStoreProvider)
        .productDetailBindCardPrompt
        .trim();
    final apiPrompt = info.value?.prompt.trim() ?? '';
    final prompt = cachedPrompt.isNotEmpty
        ? cachedPrompt
        : (apiPrompt.isNotEmpty ? apiPrompt : _fallbackPrompt);

    info.whenData(_ensureForm);

    return CertificationScaffold(
      navTitle: _navTitle,
      prompt: prompt,
      promptGap: _promptGap,
      promptWidth: _promptWidth,
      dismissKeyboardOnTap: true,
      dismissKeyboardOnDrag: true,
      bottomNavigationBar: _buildBottomBar(layout, info),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: layout.px(_ribbonTop)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: _buildCard(layout, info),
          ),
          SizedBox(height: layout.px(AppSpacing.md)),
        ],
      ),
    );
  }

  /// 白卡：顶部进度缎带 + 下挂的 Tab 与字段内容。
  ///
  /// 缎带整块切图自带白卡顶部两角，所以白卡本体只画底部圆角。
  Widget _buildCard(AppLayout layout, AsyncValue<BindCardData> info) {
    final content = info.when(
      loading: () =>
          SizedBox(height: layout.px(_stateHeight), child: const LoadingView()),
      error: (error, _) => SizedBox(
        height: layout.px(_stateHeight),
        child: ErrorView(
          message: switch (error) {
            ApiException(:final message) => message,
            _ => 'Failed to load, please try again',
          },
          onRetry: () => ref.invalidate(bindCardProvider(widget.productId)),
        ),
      ),
      data: (data) => _buildForm(layout, data),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: layout.edgeInsets(top: _ribbonHeight),
          child: Container(
            padding: layout.edgeInsets(
              left: _cardLeft,
              top: _cardTop,
              right: _cardRight,
              bottom: _cardBottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(layout.px(_cardRadius)),
                bottomRight: Radius.circular(layout.px(_cardRadius)),
              ),
            ),
            child: content,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: layout.px(_ribbonHeight),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AppAssets.personalInfoProgressRibbon,
                  fit: BoxFit.fill,
                ),
                Center(
                  child: Text(
                    _progressText,
                    style: TextStyle(
                      color: AppColors.personalInfoProgressText,
                      fontSize: layout.px(18),
                      fontWeight: FontWeight.w600,
                      // 设计稿：`font-size: 18px; line-height: 25px`。
                      height: 25 / 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 把接口下发的分组铺到本地表单状态上（切换分组时按分组重建控制器）。
  void _ensureForm(BindCardData data) {
    if (identical(_syncedData, data)) return;
    _disposeFieldState();
    _syncedData = data;
    _selectedType = data.groups.isEmpty ? '' : data.groups.first.type;
    _bindGroupFields(_currentGroup(data));
  }

  BindCardGroup? _currentGroup(BindCardData data) {
    for (final group in data.groups) {
      if (group.type == _selectedType) return group;
    }
    return data.groups.isEmpty ? null : data.groups.first;
  }

  /// 为当前分组的字段建控制器 / 焦点节点，并回填接口下发的当前值。
  void _bindGroupFields(BindCardGroup? group) {
    if (group == null) return;
    for (final field in group.fields) {
      final key = _fieldKey(field);
      final controller = TextEditingController(text: field.initialDisplayValue);
      final focusNode = FocusNode();
      if (field.control == BindCardControl.text) {
        controller.addListener(_updateActiveSuggestion);
        focusNode.addListener(_updateActiveSuggestion);
      }
      _controllers[key] = controller;
      _focusNodes[key] = focusNode;
      _values[key] = field.initialSubmitValue;
    }
  }

  void _disposeFieldState() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _values.clear();
    _dismissedSuggestions.clear();
    _activeSuggestion = null;
  }

  String _fieldKey(BindCardField field) => '$_selectedType:${field.key}';

  /// Tab + 字段列表 + 卡下红色提示。
  Widget _buildForm(AppLayout layout, BindCardData data) {
    final group = _currentGroup(data);
    if (group == null) {
      return SizedBox(
        height: layout.px(_stateHeight),
        child: Center(
          child: Text(
            'No payment methods available',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: layout.px(14),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabs(layout, data, group),
        SizedBox(height: layout.px(_tabToFields)),
        for (var index = 0; index < group.fields.length; index++) ...[
          if (index > 0) SizedBox(height: layout.px(_fieldGap)),
          _buildField(
            layout,
            group.fields[index],
            showDivider: index < group.fields.length - 1,
          ),
        ],
      ],
    );
  }

  /// 顶部打款方式 Tab：选中项是柠檬绿胶囊，未选中是纯文案。
  Widget _buildTabs(AppLayout layout, BindCardData data, BindCardGroup group) {
    return SizedBox(
      height: layout.px(_tabHeight),
      child: Row(
        children: [
          for (final item in data.groups)
            // 等分三等分并居中：Tab 文案由后端下发，长度不可控，
            // 用 Expanded + 文本省略避免长文案把这一行撑爆（设计稿是三枚短 Tab 平铺）。
            Expanded(
              child: GestureDetector(
                key: Key('bind-card-tab-${item.type}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectGroup(item.type, data),
                child: Center(
                  child: Container(
                    height: layout.px(_tabHeight),
                    padding: layout.edgeInsets(
                      left: _tabHorizontal,
                      right: _tabHorizontal,
                    ),
                    decoration: item.type == group.type
                        ? BoxDecoration(
                            color: AppColors.bindCardTabActiveBackground,
                            borderRadius: layout.radius(_tabRadius),
                          )
                        : null,
                    // Row 贴内容宽度，胶囊跟着文案走，不在三等分里被拉伸。
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: item.type == group.type
                                ? TextStyle(
                                    color: AppColors.bindCardTabActiveText,
                                    fontSize: layout.px(16),
                                    fontWeight: FontWeight.w700,
                                    // 设计稿：`font-size: 16px; line-height: 19px`。
                                    height: 19 / 16,
                                  )
                                : TextStyle(
                                    color: AppColors.bindCardTabText,
                                    fontSize: layout.px(14),
                                    // 设计稿：`font-size: 14px; line-height: 17px`。
                                    height: 17 / 14,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectGroup(String type, BindCardData data) {
    if (_selectedType == type) return;
    _dismissKeyboard();
    setState(() {
      _disposeFieldState();
      _selectedType = type;
      _bindGroupFields(_currentGroup(data));
    });
  }

  /// 字段：标题 + 取值行 + 行底 1pt 分隔线，最后一行不画分隔线。
  Widget _buildField(
    AppLayout layout,
    BindCardField field, {
    required bool showDivider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: layout.px(_labelHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              field.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.bindCardFieldTitle,
                fontSize: layout.px(16),
                fontWeight: FontWeight.w600,
                // 设计稿：`font-size: 16px; line-height: 22px`。
                height: 22 / 16,
              ),
            ),
          ),
        ),
        SizedBox(height: layout.px(_labelToRow)),
        SizedBox(
          height: layout.px(_rowHeight),
          child: Stack(
            // Stack 默认是 loose，非 Positioned 的 Row 会缩到内容高度、贴着行顶。
            // 撑成 48pt 让 Row 的 crossAxisAlignment.center 把取值行垂直居中。
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  Expanded(child: _buildValue(layout, field)),
                  if (field.isSelectable) FieldChevron(layout: layout),
                ],
              ),
              if (showDivider)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: layout.px(1),
                    child: const ColoredBox(
                      color: AppColors.personalInfoFieldDivider,
                    ),
                  ),
                ),
              if (_activeSuggestion == _fieldKey(field))
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _buildSuggestion(layout, field)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 取值行：输入框字段可编辑，枚举字段点整行弹单选面板。
  Widget _buildValue(AppLayout layout, BindCardField field) {
    final key = _fieldKey(field);
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();

    final valueStyle = TextStyle(
      color: AppColors.bindCardFieldValue,
      fontSize: layout.px(14),
      // 设计稿：`font-size: 14px; line-height: 20px`。
      height: 20 / 14,
    );
    final hintStyle = valueStyle.copyWith(color: AppColors.bindCardFieldHint);

    if (field.isSelectable) {
      final display = controller.text;
      return GestureDetector(
        key: Key('bind-card-field-${field.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _pickOption(field),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            display.isEmpty ? field.placeholder : display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: display.isEmpty ? hintStyle : valueStyle,
          ),
        ),
      );
    }

    return TextField(
      key: Key('bind-card-field-${field.key}'),
      controller: controller,
      focusNode: _focusNodes[key],
      keyboardType: field.isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: field.isNumeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: valueStyle,
      cursorColor: AppColors.primary,
      decoration: InputDecoration.collapsed(
        hintText: field.placeholder,
        hintStyle: hintStyle,
      ),
      onChanged: (value) => _values[key] = value,
    );
  }

  /// 自动填充气泡：深色底 + 建议值 + 右侧关闭按钮（设计稿 `group_3`）。
  Widget _buildSuggestion(AppLayout layout, BindCardField field) {
    return GestureDetector(
      key: Key('bind-card-suggestion-${field.key}'),
      behavior: HitTestBehavior.opaque,
      onTap: _applySuggestions,
      child: Container(
        height: layout.px(_suggestionHeight),
        padding: layout.edgeInsets(
          left: _suggestionLeft,
          right: _suggestionRight,
        ),
        decoration: BoxDecoration(
          color: AppColors.bindCardSuggestionBackground,
          borderRadius: layout.radius(_suggestionRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              field.suggestedValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.surface,
                fontSize: layout.px(12),
                // 设计稿：`font-size: 12px; line-height: 14px`。
                height: 14 / 12,
              ),
            ),
            SizedBox(width: layout.px(4)),
            GestureDetector(
              key: Key('bind-card-suggestion-close-${field.key}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _dismissSuggestion(field),
              child: Image.asset(
                AppAssets.bindCardSuggestionClose,
                width: layout.px(_suggestionCloseSize),
                height: layout.px(_suggestionCloseSize),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 枚举 / 渠道字段：弹单选面板，`Done` 后把展示文案与提交值写回。
  Future<void> _pickOption(BindCardField field) async {
    _dismissKeyboard();
    final key = _fieldKey(field);
    final option = await showBindCardOptionSheet(
      context: context,
      options: field.options,
      selectedValue: _values[key],
    );
    if (option == null || !mounted) return;
    setState(() {
      _values[key] = option.value;
      _controllers[key]?.text = option.label;
    });
  }

  /// 输入框聚焦且为空、又有建议值时才弹气泡；填过值或关过就不再弹。
  void _updateActiveSuggestion() {
    if (!mounted) return;
    final data = ref.read(bindCardProvider(widget.productId)).value;
    if (data == null) return;
    final group = _currentGroup(data);
    if (group == null) return;

    for (final field in group.fields) {
      if (field.control != BindCardControl.text) continue;
      final key = _fieldKey(field);
      if ((_controllers[key]?.text.trim().isNotEmpty ?? false)) {
        _dismissedSuggestions.remove(key);
      }
    }

    String? next;
    for (final field in group.fields) {
      if (field.control != BindCardControl.text) continue;
      final key = _fieldKey(field);
      final focused = _focusNodes[key]?.hasFocus ?? false;
      final empty = (_controllers[key]?.text.trim().isEmpty ?? true);
      if (!focused ||
          !empty ||
          field.suggestedValue.isEmpty ||
          _dismissedSuggestions.contains(key)) {
        continue;
      }
      next = key;
      break;
    }
    if (_activeSuggestion != next) {
      setState(() => _activeSuggestion = next);
    }
  }

  void _dismissSuggestion(BindCardField field) {
    setState(() {
      _dismissedSuggestions.add(_fieldKey(field));
      _activeSuggestion = null;
    });
  }

  /// 点气泡：把当前分组里所有空的输入框一次填上各自的建议值。
  void _applySuggestions() {
    _dismissKeyboard();
    final data = ref.read(bindCardProvider(widget.productId)).value;
    final group = data == null ? null : _currentGroup(data);
    if (group == null) return;
    setState(() {
      for (final field in group.fields) {
        if (field.control != BindCardControl.text) continue;
        final suggestion = field.suggestedValue.trim();
        final key = _fieldKey(field);
        if (suggestion.isEmpty) continue;
        if ((_controllers[key]?.text.trim().isEmpty ?? false)) {
          _controllers[key]?.text = suggestion;
          _values[key] = suggestion;
        }
      }
      _activeSuggestion = null;
    });
  }

  /// 底部固定操作条：红色提示文案 + 白底 + 上方投影 + 柠檬绿 `Upload`。
  Widget _buildBottomBar(AppLayout layout, AsyncValue<BindCardData> info) {
    final bottomPrompt = info.value?.bottomPrompt.trim().isNotEmpty == true
        ? info.value!.bottomPrompt.trim()
        : ref.watch(sessionStoreProvider).productDetailBindCardBottomPrompt;
    final canSubmit =
        !_isSubmitting && (info.value?.groups.isNotEmpty ?? false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            // 设计稿 `box_3 { box-shadow: 0 -5px 6px rgba(233,233,233,0.5) }`。
            color: AppColors.personalInfoBottomBarShadow,
            blurRadius: layout.px(6),
            offset: Offset(0, layout.px(-5)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: layout.edgeInsets(top: _bottomPromptGap, bottom: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bottomPrompt.isNotEmpty) ...[
                SizedBox(
                  width: layout.px(_bottomPromptWidth),
                  child: Text(
                    bottomPrompt,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.bindCardBottomPrompt,
                      fontSize: layout.px(12),
                      // 设计稿：`font-size: 12px; line-height: 14px`。
                      height: 14 / 12,
                    ),
                  ),
                ),
                SizedBox(height: layout.px(AppSpacing.sm)),
              ],
              Padding(
                padding: layout.edgeInsets(
                  left: AppSpacing.pageHorizontal,
                  right: AppSpacing.pageHorizontal,
                ),
                child: UploadButton(
                  layout: layout,
                  enabled: canSubmit,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  /// 校验并提交绑卡；后端要求活体时先做活体再补交一次。
  Future<void> _submit() async {
    if (_isSubmitting) return;
    // TODO(埋点): 点击 Upload 提交绑卡需要在 Firebase Analytics 上报事件。

    final data = ref.read(bindCardProvider(widget.productId)).value;
    final group = data == null ? null : _currentGroup(data);
    if (group == null) return;

    final fields = <String, String>{};
    for (final field in group.fields) {
      final value = (_values[_fieldKey(field)] ?? '').trim();
      if (!field.isOptional && value.isEmpty) {
        ToastHelper.showError('${field.title} is required');
        return;
      }
      fields[field.key] = value;
    }
    final account = fields['cardNo'];
    final confirmation = fields['confirmCardNo'];
    if (account != null && confirmation != null && account != confirmation) {
      ToastHelper.showError('Account numbers do not match');
      return;
    }

    _dismissKeyboard();
    setState(() => _isSubmitting = true);
    final loading = ToastHelper.showLoading();
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      var response = await repository.submitBindCard(
        productId: widget.productId,
        cardType: group.type,
        fields: fields,
      );

      // `20000`：后端要求先做活体，再带活体结果补交同一份字段。
      if (response.code == _codeNeedsLiveness) {
        loading();
        if (mounted) setState(() => _isSubmitting = false);
        final liveness = await _runLiveness(fields, group.type);
        if (liveness == null) return;
        response = liveness;
      }

      if (!mounted) return;
      if (!response.isSuccess) {
        ToastHelper.showError(
          response.message.isNotEmpty
              ? response.message
              : 'Unable to bind account',
        );
        return;
      }

      // 改卡场景：刚绑上的账户直接拿去换绑，成功把订单详情页地址回给调用方。
      if (widget.isAccountChange) {
        final bindId =
            response.data[ApiFields.bindCardSubmitBindId]?.toString().trim() ??
            '';
        final orderNo = widget.orderNo.trim();
        if (orderNo.isEmpty || bindId.isEmpty) {
          ToastHelper.showError('Missing account change information');
          return;
        }
        final url = await _changeAccount(orderNo, bindId);
        if (!mounted) return;
        if (url.isEmpty) {
          ToastHelper.showError('Missing account change result');
          return;
        }
        AppNavigator.pop<String>(url);
        return;
      }

      final flow = await ref.read(productApplicationFlowProvider.future);
      if (mounted) {
        await flow.continueProductDetailFlow(widget.productId);
      }
    } on ApiException catch (error) {
      if (mounted) ToastHelper.showError(error.message);
    } catch (_) {
      if (mounted) ToastHelper.showError('Unable to bind account');
    } finally {
      loading();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 改卡场景：拿刚绑上的账户调更换银行卡接口，返回订单详情页地址。
  ///
  /// 失败弹提示并返回空串（调用方看到空串就不再跳转）。
  Future<String> _changeAccount(String orderNo, String bindId) async {
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final response = await repository.changeBankCard(
        orderNo: orderNo,
        bindId: bindId,
      );
      if (!response.isSuccess) {
        if (mounted) {
          ToastHelper.showError(
            response.message.isNotEmpty
                ? response.message
                : 'Unable to change payment method',
          );
        }
        return '';
      }
      return response.data;
    } on ApiException catch (error) {
      if (mounted) ToastHelper.showError(error.message);
      return '';
    } catch (_) {
      if (mounted) ToastHelper.showError('Unable to change payment method');
      return '';
    }
  }

  /// 相机权限 -> face++ token（绑卡用 `type = 1`）-> 活体 SDK -> 补交绑卡。
  ///
  /// 任何一步失败都返回 null（已经弹过提示），调用方直接结束本次提交。
  Future<ApiResponse<Map<String, dynamic>>?> _runLiveness(
    Map<String, String> fields,
    String cardType,
  ) async {
    final granted = await IdentityPhotoPermission.ensureCameraForLiveness(
      context,
    );
    if (!granted || !mounted) return null;

    final orderNo = widget.orderNo.trim();
    if (orderNo.isEmpty) {
      ToastHelper.showError('Order information is missing');
      return null;
    }

    setState(() => _isSubmitting = true);
    final loading = ToastHelper.showLoading();
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final tokenResponse = await repository.getFaceToken(
        orderNo: orderNo,
        type: 1,
      );
      loading();
      if (!mounted) return null;

      if (!tokenResponse.isSuccess) {
        ToastHelper.showError(tokenResponse.message);
        return null;
      }
      final token = tokenResponse.data;
      if (!token.canStartLiveness) {
        ToastHelper.showError(
          token.error.isNotEmpty
              ? token.error
              : 'Unable to start face verification',
        );
        return null;
      }

      final outcome = await ref.read(livenessGatewayProvider).run(token.token);
      if (!mounted) return null;

      if (!outcome.passed || !outcome.hasUploadPayload) {
        ToastHelper.showError(
          outcome.message.isNotEmpty
              ? outcome.message
              : 'Face verification was not completed',
        );
        return null;
      }

      ToastHelper.showLoading();
      final result = await repository.submitBindCard(
        productId: widget.productId,
        cardType: cardType,
        fields: fields,
        faceType: '${token.livenessType}',
        livenessId: outcome.livenessId,
        image: outcome.imageBase64,
        license: token.token,
      );
      return result;
    } on ApiException catch (error) {
      if (mounted) ToastHelper.showError(error.message);
      return null;
    } catch (_) {
      if (mounted) ToastHelper.showError('Face verification was not completed');
      return null;
    } finally {
      loading();
    }
  }
}
