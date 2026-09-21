import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/personal_info_data.dart';
import '../providers/personal_info_provider.dart';
import '../providers/product_flow_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../providers/work_info_provider.dart';
import '../theme/theme.dart';
import '../widgets/certification_scaffold.dart';
import '../widgets/field_chevron.dart';
import '../widgets/state_views.dart';
import '../widgets/upload_button.dart';
import 'widgets/personal_info_address_sheet.dart';
import 'widgets/personal_info_option_sheet.dart';

/// 认证表单页的两种形态：个人信息（认证第二项）/ 工作信息（认证第三项）。
///
/// 两页共用同一套 UI（头图 / 进度缎带 / 动态字段表单 / 底部 Upload 条），
/// 只有导航标题、进度文案、引导段排版、数据源与保存接口不同，
/// 所以用同一个页面类按 [PersonalInfoPage] 的形态参数切换，
/// 不在客户端复制第二份布局。
enum _CertificationFormKind { personal, work }

/// 导航标题（个人信息稿 `text_26` / 工作信息稿 `text_27`）。
const _navTitlePersonal = 'Basic identity information';
const _navTitleWork = 'Job information';

/// 引导段落相对导航行的下移量。
///
/// 个人信息稿导航行到段落顶边 104，工作信息稿同位置只有 94，差 10pt；
/// 本页公式把导航行高度单独算掉，所以两个形态取 18 / 8。
const _promptGapPersonal = 18.0;
const _promptGapWork = 8.0;

/// 引导段落宽度（个人信息稿 `text_4 { width: 193px }` /
/// 工作信息稿 `text_4 { width: 164px }`）。
const _promptWidthPersonal = 193.0;
const _promptWidthWork = 164.0;

/// 引导段字号 / 行高（个人信息稿 16/19，工作信息稿 14/17）。
const _promptFontSizePersonal = 16.0;
const _promptFontSizeWork = 14.0;
const _promptLineHeightPersonal = 19.0;
const _promptLineHeightWork = 17.0;

/// 接口没下发引导文案时的兜底（个人信息稿 `text_4`）。
///
/// 四行就是设计稿的换行位置：193pt 宽下 Helvetica-Bold 16 的断行结果。
/// 正常情况走产品详情下发的 `overwhelming.deerherd`，其次走表单接口的
/// `befleas`，都没有（低版本 / 未灰度用户）时才落到这里。
const _fallbackPromptPersonal =
    'Share your info securely.\n'
    'It\'s the first step toward\n'
    'getting the funds you\n'
    'need.';

/// 接口没下发引导文案时的兜底（工作信息稿 `text_4`）。
///
/// 五行就是设计稿的换行位置：164pt 宽下 Helvetica-Bold 14 的断行结果。
/// 正常情况走产品详情下发的 `overwhelming.ssn`，其次走表单接口的
/// `befleas`，都没有（低版本 / 未灰度用户）时才落到这里。
const _fallbackPromptWork =
    'Your job info stays\n'
    'confidential and is only\n'
    'used for credit\n'
    'assessment. Share it\n'
    'with confidence.';

/// 进度缎带的顶边（设计稿 `编组 { top: 185 }`）：比白卡顶边高 7pt，
/// 缎带自己带白卡顶部两角，压在头图下沿与白卡之间。
const _ribbonTop = 185.0;

/// 缎带高度（设计稿 `编组`，343x33）。
const _ribbonHeight = 33.0;

/// 缎带上的进度文案（个人信息稿 25% / 工作信息稿 50%）。
///
/// 文档没有下发进度百分比的字段，先按设计稿写死；接入进度接口后再换成下发值。
const _progressTextPersonal = '25%';
const _progressTextWork = '50%';

/// 白卡圆角（设计稿 `矩形`，343x772，border-radius 12）。
const _cardRadius = 12.0;

/// 白卡左右内边距（设计稿 `block_3 { padding: 0 12px 14px 12px }`）。
const _cardHorizontal = 12.0;

/// 白卡底部内边距（设计稿 `block_3 { padding-bottom: 14 }`）。
const _cardBottom = 14.0;

/// 白卡内容顶边到第一个字段标题的距离。
///
/// 设计稿第一个标题顶边 228，缎带下沿（= 白卡内容顶边）218，相差 10pt。
const _cardTop = 10.0;

/// 字段标题高度（设计稿 `text_7 { line-height: 22 }`）。
const _labelHeight = 22.0;

/// 标题到取值行的距离（设计稿 `section_2 { margin-top: 8 }`）。
const _labelToRow = 8.0;

/// 取值行高度（设计稿 `section_2`：14 + 20 + 14）。
const _rowHeight = 48.0;

/// 字段之间的间距（设计稿：标题顶边 228 / 322，字段高 78）。
const _fieldGap = 16.0;

/// Loading / Error / Empty 态在卡内的最小高度。
const _stateHeight = 200.0;

/// 认证表单页：个人信息（蓝湖稿 `03-02-认证-个人信息`）与
/// 工作信息（蓝湖稿 `03-03 - 工作信息`）共用同一套布局。
///
/// 页面分三段，与设计稿一一对应：
/// 1. 通栏头图（`蒙版` + `位图`）：绿色渐变 + 吉祥物，复用证件上传页那张
///    没有标题的切图；导航标题与引导段落由页面叠上去，返回按钮复用 [BackNavBar]。
/// 2. 白卡（343x772）：卡顶是带进度的粉红缎带（`编组` 整块切图），
///    下面是「标题 + 取值行 + 1pt 分隔线」的字段列表。
/// 3. 底部固定操作条（`section_1`）：白底 + 上方投影，柠檬绿 `Upload` 按钮。
///
/// 字段（标题 / 占位 / 控件类型 / 选项 / 当前值）全部由后端下发
/// （个人信息 `POST /outsulk/orchel` / 工作信息 `GET /outsulk/timeling`），
/// 页面只按描述渲染，不在客户端写死任何字段；`Upload` 把每个字段的 `crucians`
/// 当 key 回传（个人信息 `POST /outsulk/marantas` / 工作信息 `POST /outsulk/kneeing`），
/// 成功后继续产品详情的下一步认证。枚举 / 地址字段分别弹
/// [showPersonalInfoOptionSheet] / [showPersonalInfoAddressSheet]。
class PersonalInfoPage extends ConsumerStatefulWidget {
  /// 个人信息形态（认证第二项）。
  const PersonalInfoPage({super.key, required this.productId})
    : _kind = _CertificationFormKind.personal;

  /// 工作信息形态（认证第三项）：与个人信息同一套 UI，只换数据源 / 保存接口。
  const PersonalInfoPage.work({super.key, required this.productId})
    : _kind = _CertificationFormKind.work;

  /// 产品 id。
  final String productId;

  /// 当前页面形态，决定文案与数据源。
  final _CertificationFormKind _kind;

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  /// 导航标题（个人信息 / 工作信息两稿各一条）。
  String get _navTitle => switch (widget._kind) {
    _CertificationFormKind.personal => _navTitlePersonal,
    _CertificationFormKind.work => _navTitleWork,
  };

  /// 缎带上的进度文案。
  String get _progressText => switch (widget._kind) {
    _CertificationFormKind.personal => _progressTextPersonal,
    _CertificationFormKind.work => _progressTextWork,
  };

  /// 接口没下发引导文案时的兜底（两稿各一条）。
  String get _fallbackPrompt => switch (widget._kind) {
    _CertificationFormKind.personal => _fallbackPromptPersonal,
    _CertificationFormKind.work => _fallbackPromptWork,
  };

  /// 引导段落宽度。
  double get _promptWidth => switch (widget._kind) {
    _CertificationFormKind.personal => _promptWidthPersonal,
    _CertificationFormKind.work => _promptWidthWork,
  };

  /// 引导段落相对导航行的下移量。
  double get _promptGap => switch (widget._kind) {
    _CertificationFormKind.personal => _promptGapPersonal,
    _CertificationFormKind.work => _promptGapWork,
  };

  /// 引导段字号。
  double get _promptFontSize => switch (widget._kind) {
    _CertificationFormKind.personal => _promptFontSizePersonal,
    _CertificationFormKind.work => _promptFontSizeWork,
  };

  /// 引导段行高。
  double get _promptLineHeight => switch (widget._kind) {
    _CertificationFormKind.personal => _promptLineHeightPersonal,
    _CertificationFormKind.work => _promptLineHeightWork,
  };

  /// 当前形态的表单数据源（个人信息 / 工作信息）。
  FutureProvider<PersonalInfoData> get _formProvider => switch (widget._kind) {
    _CertificationFormKind.personal => personalInfoProvider(widget.productId),
    _CertificationFormKind.work => workInfoProvider(widget.productId),
  };

  /// 提交中：挡住 `Upload` 按钮，避免同一份资料被提交两次。
  bool _isSubmitting = false;

  /// 已经把哪一份接口数据铺到表单上，避免 build 里重复初始化。
  PersonalInfoData? _syncedData;

  /// 每个字段的提交值（选项类字段是 `liquidators`，不是展示文案）。
  final _values = <String, String>{};

  /// 每个字段的输入框；选项 / 地址字段只借它存展示文案。
  final _controllers = <String, TextEditingController>{};

  /// 地址层级缓存（`GET /outsulk/avern`），同一页面只拉一次。
  List<AddressNode>? _addressNodes;

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final info = ref.watch(_formProvider);

    // 表单接口的 `befleas` 只在拿到数据后才知道；产品详情下发的那条一定先到。
    final store = ref.watch(sessionStoreProvider);
    final cachedPrompt =
        (widget._kind == _CertificationFormKind.work
                ? store.productDetailWorkPrompt
                : store.productDetailPersonalPrompt)
            .trim();
    final apiTips = info.value?.tips.trim() ?? '';
    final prompt = cachedPrompt.isNotEmpty
        ? cachedPrompt
        : (apiTips.isNotEmpty ? apiTips : _fallbackPrompt);

    info.whenData(_ensureForm);

    return CertificationScaffold(
      navTitle: _navTitle,
      prompt: prompt,
      promptGap: _promptGap,
      promptWidth: _promptWidth,
      promptFontSize: _promptFontSize,
      promptLineHeight: _promptLineHeight,
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

  /// 把接口下发的字段铺到本地表单状态上。
  ///
  /// 只在拿到新的一份数据时初始化（重试会换新实例），不会在每帧重建控制器。
  void _ensureForm(PersonalInfoData data) {
    if (identical(_syncedData, data)) return;
    _disposeControllers();
    _values.clear();
    for (final field in data.fields) {
      _values[field.key] = field.initialSubmitValue;
      _controllers[field.key] = TextEditingController(
        text: field.initialDisplayValue,
      );
    }
    _syncedData = data;
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  /// 白卡：顶部进度缎带 + 下挂的字段内容。
  ///
  /// 缎带整块切图自带白卡顶部两角，所以白卡本体只画底部圆角，
  /// 顶边由缎带下沿接着，不重复画圆角。
  Widget _buildCard(AppLayout layout, AsyncValue<PersonalInfoData> info) {
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
          onRetry: () => ref.invalidate(_formProvider),
        ),
      ),
      data: _buildFields,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: layout.edgeInsets(top: _ribbonHeight),
          child: Container(
            padding: layout.edgeInsets(
              left: _cardHorizontal,
              top: _cardTop,
              right: _cardHorizontal,
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

  /// 字段列表：标题 + 取值行 + 行底 1pt 分隔线，最后一行不画分隔线。
  Widget _buildFields(PersonalInfoData data) {
    final layout = AppLayout.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: layout.px(_stateHeight),
        child: Center(
          child: Text(
            'No information required yet',
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
        for (var index = 0; index < data.fields.length; index++) ...[
          if (index > 0) SizedBox(height: layout.px(_fieldGap)),
          _buildField(
            layout,
            data.fields[index],
            showDivider: index < data.fields.length - 1,
          ),
        ],
      ],
    );
  }

  Widget _buildField(
    AppLayout layout,
    PersonalInfoField field, {
    required bool showDivider,
  }) {
    final selectable =
        field.control == PersonalInfoControl.selection ||
        field.control == PersonalInfoControl.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: layout.px(_labelHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              field.title,
              style: TextStyle(
                color: AppColors.personalInfoFieldTitle,
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
            // Stack 默认是 loose，非 Positioned 的 Row 会缩到内容高度、贴着行顶；
            // 撑成 48pt 让 Row 的 crossAxisAlignment.center 把取值行垂直居中。
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  Expanded(child: _buildValue(layout, field, selectable)),
                  if (selectable) FieldChevron(layout: layout),
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
            ],
          ),
        ),
      ],
    );
  }

  /// 取值行：输入框字段可编辑，选项 / 地址字段点整行弹面板。
  Widget _buildValue(
    AppLayout layout,
    PersonalInfoField field,
    bool selectable,
  ) {
    final controller = _controllers[field.key];
    if (controller == null) return const SizedBox.shrink();

    final valueStyle = TextStyle(
      color: AppColors.personalInfoFieldValue,
      fontSize: layout.px(14),
      // 设计稿：`font-size: 14px; line-height: 20px`。
      height: 20 / 14,
    );
    final hintStyle = valueStyle.copyWith(
      color: AppColors.personalInfoFieldHint,
    );

    if (selectable) {
      final display = controller.text;
      return GestureDetector(
        key: Key('personal-info-field-${field.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectField(field),
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

    // `txt` 字段直接编辑；未知控件类型只读展示，不当成输入框。
    return TextField(
      key: Key('personal-info-field-${field.key}'),
      controller: controller,
      readOnly: field.control != PersonalInfoControl.text,
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
      onChanged: (value) => _values[field.key] = value,
    );
  }

  /// 底部固定操作条：白底 + 上方投影，按钮下沿留安全区。
  Widget _buildBottomBar(AppLayout layout, AsyncValue<PersonalInfoData> info) {
    final canSubmit =
        !_isSubmitting && (info.value?.fields.isNotEmpty ?? false);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            // 设计稿 `section_1 { box-shadow: 0 -5px 6px rgba(233,233,233,0.5) }`。
            color: AppColors.personalInfoBottomBarShadow,
            blurRadius: layout.px(6),
            offset: Offset(0, layout.px(-5)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: layout.edgeInsets(
            left: AppSpacing.pageHorizontal,
            top: 14,
            right: AppSpacing.pageHorizontal,
            bottom: 14,
          ),
          child: UploadButton(
            layout: layout,
            enabled: canSubmit,
            onTap: _submit,
          ),
        ),
      ),
    );
  }

  /// 收起当前焦点输入框的键盘，空白点击与字段点击共用。
  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  /// 枚举 / 地址字段：弹对应面板，选中后把展示文案与提交值写回。
  Future<void> _selectField(PersonalInfoField field) async {
    _dismissKeyboard();
    if (field.control == PersonalInfoControl.address) {
      await _pickAddress(field);
      return;
    }
    if (field.control != PersonalInfoControl.selection) return;

    // 二级选项（工作信息 `Payday`）：先选发薪周期，再按周期选具体发薪日。
    if (field.hasNestedOptions) {
      await _pickNestedOption(field);
      return;
    }

    await _pickOption(field);
  }

  /// 单级选项：选完直接按 `liquidators` 回填。
  Future<void> _pickOption(PersonalInfoField field) async {
    final option = await showPersonalInfoOptionSheet(
      context: context,
      options: field.options,
    );
    if (option == null || !mounted) return;
    setState(() {
      _values[field.key] = option.value;
      _controllers[field.key]?.text = option.label;
    });
  }

  /// 二级选项（工作信息 `Payday`，口径对齐 peso_shield）：
  ///
  /// 一级取发薪周期（`Daily` / `Weekly` / `Twice per Month` / `Once a Month`），
  /// 选中后若该周期自带下级（周几 / 每月几号）再弹一次选择面板；
  /// 行上展示 `周期|发薪日`，提交接口要的是**下级**的 `liquidators`，
  /// 与接口文档 `fed: "Once a Month|1"` 的口径一致。
  ///
  /// 面板每次打开都从第一项开始，不回填上一次选中的值（对齐 peso_shield：
  /// 重新打开始终停在周期列表顶部）。
  Future<void> _pickNestedOption(PersonalInfoField field) async {
    final parent = await showPersonalInfoOptionSheet(
      context: context,
      options: field.options,
    );
    if (parent == null || !mounted) return;

    if (parent.children.isEmpty) {
      setState(() {
        _values[field.key] = parent.value;
        _controllers[field.key]?.text = parent.label;
      });
      return;
    }

    final child = await showPersonalInfoOptionSheet(
      context: context,
      options: parent.children,
    );
    if (child == null || !mounted) return;
    setState(() {
      _values[field.key] = child.value;
      _controllers[field.key]?.text = '${parent.label}|${child.label}';
    });
  }

  /// 地址字段：先拉层级数据（同页缓存），再弹地址面板。
  Future<void> _pickAddress(PersonalInfoField field) async {
    final cancel = ToastHelper.showLoading();
    try {
      _addressNodes ??= await _loadAddressNodes();
      cancel();
      if (!mounted) return;
      final address = await showPersonalInfoAddressSheet(
        context: context,
        nodes: _addressNodes!,
      );
      if (address == null || !mounted) return;
      setState(() {
        _values[field.key] = address;
        _controllers[field.key]?.text = address;
      });
    } catch (_) {
      cancel();
      if (mounted) ToastHelper.showError('Unable to load address options');
    }
  }

  Future<List<AddressNode>> _loadAddressNodes() async {
    final repository = await ref.read(certificationRepositoryProvider.future);
    final response = await repository.getAddressInit();
    if (!response.isSuccess) {
      throw ApiException(
        type: ApiFailureType.business,
        message: response.message,
        code: response.code,
      );
    }
    return response.data.nodes;
  }

  /// 提交表单：成功后再拉产品详情，走下一步认证。
  Future<void> _submit() async {
    if (_isSubmitting) return;
    // TODO(埋点): 点击 Upload 提交认证表单需要在 Firebase Analytics 上报事件。

    setState(() => _isSubmitting = true);
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      // key 是接口下发的 `crucians`，两个形态各自回各自的保存接口。
      final response = switch (widget._kind) {
        _CertificationFormKind.personal => await repository.savePersonalInfo(
          productId: widget.productId,
          formData: _values,
        ),
        _CertificationFormKind.work => await repository.saveWorkInfo(
          productId: widget.productId,
          formData: _values,
        ),
      };
      if (!mounted) return;

      if (!response.isSuccess) {
        ToastHelper.showError(
          response.message.isNotEmpty ? response.message : 'Save failed',
        );
        return;
      }

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
}
