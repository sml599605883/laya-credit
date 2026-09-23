import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/report/report.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/emergency_contact_data.dart';
import '../data/models/personal_info_data.dart';
import '../providers/emergency_contact_provider.dart';
import '../providers/product_flow_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/certification_scaffold.dart';
import '../widgets/field_chevron.dart';
import '../widgets/state_views.dart';
import '../widgets/upload_button.dart';
import 'widgets/personal_info_option_sheet.dart';

/// 导航标题（设计稿 `text_30`）。
const _navTitle = 'Urgent contact person';

/// 接口没下发引导文案时的兜底（设计稿 `text_4`）。
///
/// 四行就是设计稿的换行位置：186pt 宽下 Helvetica-Bold 16 的断行结果。
/// 正常情况走产品详情下发的 `overwhelming.embol`，其次走接口的 `befleas`，
/// 都没有（低版本 / 未灰度用户）时才落到这里。
const _fallbackPrompt =
    'Emergency contacts help\n'
    'secure your account. We\n'
    'respect every contact\'s\n'
    'privacy.';

/// 引导段落相对导航行的下移量。
///
/// 设计稿 `text-wrapper_6 { margin-top: 26 }`，导航行 24pt 高；
/// 本页公式把导航行高度单独算掉，与个人信息页取同一个值。
const _promptGap = 18.0;

/// 引导段落宽度（设计稿 `text_4 { width: 186px }`）。
const _promptWidth = 186.0;

/// 进度缎带的顶边（设计稿 `text-wrapper_3 { top: 185 }`）。
const _ribbonTop = 185.0;

/// 缎带尺寸（与个人信息 / 工作信息页共用同一张切图，343x33）。
///
/// 设计稿这里量到的 198x33 是 `text-wrapper_3` 的**元素框**（含 79px 左右内边距），
/// 粉色缎带本体在两张稿里逐像素一致（x 106~270，164pt 宽），
/// 直接复用个人信息页那张把白卡顶角一起烘焙进去的 `编组@3x.png`。
const _ribbonHeight = 33.0;

/// 白卡圆角（设计稿 `box_4 { border-radius: 12 }`，实测圆角约 11-12）。
const _cardRadius = 12.0;

/// 白卡左右内边距（设计稿 `box_4 { padding: 0 12px 14px 12px }`）。
const _cardHorizontal = 12.0;

/// 缎带下沿到第一个字段标题的距离（设计稿：缎带下沿 218，标题 `text_7` 顶边 230）。
///
/// 白卡本体从缎带下沿（185 + 33）开始，顶角由缎带切图自带。
const _cardTop = 12.0;

/// 白卡底部内边距（设计稿 `box_4 { padding-bottom: 14 }`）。
const _cardBottom = 14.0;

/// 分组标题高度（设计稿 `text_7 { line-height: 18 }`）。
const _groupTitleHeight = 18.0;

/// 分组之间的间距（设计稿：组一标题 230 / 组二标题 538，组内元素合计 278）。
const _groupGap = 30.0;

/// 字段标题高度（设计稿 `text_8 { line-height: 22 }`）。
const _labelHeight = 22.0;

/// 第一个字段标题距分组标题的距离（设计稿 `text_8 { margin-top: 16 }`）。
const _labelGapFirst = 16.0;

/// 后续字段标题距上一行的距离（设计稿 `text_10` / `text_12 { margin-top: 12 }`）。
const _labelGap = 12.0;

/// 取值行高度（设计稿 `box_5`：14 + 20 + 14）。
const _rowHeight = 48.0;

/// 字段标题到取值行的距离（设计稿 `box_5 { margin-top: 8 }`）。
const _labelToRow = 8.0;

/// 手机号取值的高度（设计稿 `text_13 { line-height: 20 }`）。
const _phoneHeight = 20.0;

/// 手机号取值距其标题的距离（设计稿 `text_13 { margin-top: 22 }`）。
const _phoneGap = 22.0;

/// 行尾通讯录图标的边长（设计稿 `thumbnail_11 { width: 18px; height: 18px }`）。
///
/// 用户提供的切图是 60x60（20x20 @3x），设计稿按 18x18 摆放。
const _pickerIconSize = 18.0;

/// 关系下拉未选时的占位文案（设计稿 `text_18` 的 `Name` 同理）。
const _relationPlaceholder = 'Please select';

/// 联系人信息未选时的占位文案（设计稿 `text_18`）。
const _namePlaceholder = 'Name';

/// 手机号未选时的占位文案（设计稿 `text_20` / `text_27`）。
const _phonePlaceholder = 'Phone Number';

/// 缎带上的进度文案（设计稿 `text_5`）。
///
/// 文档没有下发进度百分比的字段，先按设计稿写死；接入进度接口后再换成下发值。
const _progressText = '75%';

/// Loading / Error / Empty 态在卡内的最小高度。
const _stateHeight = 200.0;

/// 紧急联系人认证页（蓝湖稿 `03-04 - 联系人信息`，认证第四项）。
///
/// 页面分三段，与设计稿一一对应：
/// 1. 通栏头图（`box_1`）：绿色渐变 + 吉祥物，复用证件上传页那张没有标题的切图；
///    导航标题与引导段落由页面叠上去，返回按钮复用 [BackNavBar]。
/// 2. 白卡（`box_4`，343x946）：卡顶是 33pt 高的进度缎带
///    （复用个人信息页那张，见 [_ribbonHeight]），
///    下面按后端下发的联系人逐组渲染「分组标题 + Relationship + Contact
///    Information + telephone number」。
/// 3. 底部固定操作条（`block_3`）：白底 + 上方投影，柠檬绿 `Upload` 按钮。
///
/// 联系人的条数、位置号（`canmaker`）与关系选项全部由后端下发
/// （`GET /outsulk/liquidators`），页面不写死任何一条。
/// 关系下拉复用个人信息页的选项面板；
/// `Contact Information` 行打开系统通讯录选人，选中后同时回填姓名与手机号
/// （手机号行只读展示，与设计稿一致）。
/// `Upload` 把每个联系人的 `canmaker` 原样回传（`POST /outsulk/stabiliment`），
/// 成功后继续产品详情的下一步认证。
class EmergencyContactPage extends ConsumerStatefulWidget {
  const EmergencyContactPage({
    super.key,
    required this.productId,
    this.orderNo = '',
  });

  /// 产品 id。
  final String productId;

  /// 订单号：风控埋点（`pirate`）回传，由产品申请流程从产品详情带下来。
  final String orderNo;

  @override
  ConsumerState<EmergencyContactPage> createState() =>
      _EmergencyContactPageState();
}

class _EmergencyContactPageState extends ConsumerState<EmergencyContactPage> {
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();

  /// 提交中：挡住 `Upload` 按钮，避免同一份资料被提交两次。
  bool _isSubmitting = false;

  /// 风控埋点场景 7（紧急联系人）的开始时间：进入本页时记录。
  late final int _sceneStartSeconds;

  @override
  void initState() {
    super.initState();
    _sceneStartSeconds = ReportService.nowSeconds();
  }

  /// 已经把哪一份接口数据铺到表单上，避免 build 里重复初始化。
  EmergencyContactData? _syncedData;

  /// 页面正在编辑的联系人（姓名 / 手机号 / 关系都是本地可变状态）。
  List<_ContactEntry> _contacts = const [];

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final data = ref.watch(emergencyContactProvider(widget.productId));

    // 接口的 `befleas` 只在拿到数据后才知道；产品详情下发的那条一定先到。
    final cachedPrompt = ref
        .watch(sessionStoreProvider)
        .productDetailEmergencyContactPrompt
        .trim();
    final apiTips = data.value?.tips.trim() ?? '';
    final prompt = cachedPrompt.isNotEmpty
        ? cachedPrompt
        : (apiTips.isNotEmpty ? apiTips : _fallbackPrompt);

    data.whenData(_ensureContacts);

    return CertificationScaffold(
      navTitle: _navTitle,
      prompt: prompt,
      promptGap: _promptGap,
      promptWidth: _promptWidth,
      dismissKeyboardOnTap: true,
      bottomNavigationBar: _buildBottomBar(layout),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: layout.px(_ribbonTop)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: _buildCard(layout, data),
          ),
          SizedBox(height: layout.px(AppSpacing.md)),
        ],
      ),
    );
  }

  /// 把接口下发的联系人铺到本地可变状态上。
  ///
  /// 只在拿到新的一份数据时初始化（重试会换新实例），不会在每帧重建。
  void _ensureContacts(EmergencyContactData data) {
    if (identical(_syncedData, data)) return;
    _contacts = data.contacts.map(_ContactEntry.new).toList(growable: false);
    _syncedData = data;
  }

  /// 白卡：顶部进度缎带 + 下挂的联系人分组，与个人信息页同一套结构。
  ///
  /// 缎带整块切图自带白卡顶部两角，所以白卡本体只画底部圆角。
  Widget _buildCard(AppLayout layout, AsyncValue<EmergencyContactData> data) {
    final content = data.when(
      loading: () =>
          SizedBox(height: layout.px(_stateHeight), child: const LoadingView()),
      error: (error, _) => SizedBox(
        height: layout.px(_stateHeight),
        child: ErrorView(
          message: switch (error) {
            ApiException(:final message) => message,
            _ => 'Failed to load, please try again',
          },
          onRetry: () =>
              ref.invalidate(emergencyContactProvider(widget.productId)),
        ),
      ),
      data: _buildGroups,
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

  /// 联系人分组列表：每组「标题 + 三行字段」，组之间空 [_groupGap]。
  Widget _buildGroups(EmergencyContactData data) {
    final layout = AppLayout.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: layout.px(_stateHeight),
        child: Center(
          child: Text(
            'No emergency contacts required yet',
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
        for (var index = 0; index < _contacts.length; index++) ...[
          if (index > 0) SizedBox(height: layout.px(_groupGap)),
          _buildGroup(layout, index, _contacts[index]),
        ],
      ],
    );
  }

  Widget _buildGroup(AppLayout layout, int index, _ContactEntry contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Relationship with Emergency Contacts - ${index + 1}',
          key: Key('emergency-contact-title-${contact.number}'),
          // 设计稿 `text_7 { white-space: nowrap }`：文案长也不换行。
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.personalInfoFieldTitle,
            fontSize: layout.px(15),
            fontWeight: FontWeight.w700,
            // 设计稿：`font-size: 15px; line-height: 18px`。
            height: _groupTitleHeight / 15,
          ),
        ),
        SizedBox(height: layout.px(_labelGapFirst)),
        _buildLabel(layout, 'Relationship'),
        SizedBox(height: layout.px(_labelToRow)),
        _buildValueRow(
          layout,
          key: Key('emergency-contact-relation-${contact.number}'),
          value: contact.relationLabel,
          placeholder: _relationPlaceholder,
          trailing: FieldChevron(layout: layout),
          onTap: () => _selectRelation(contact),
        ),
        SizedBox(height: layout.px(_labelGap)),
        _buildLabel(layout, 'Contact Information'),
        SizedBox(height: layout.px(_labelToRow)),
        _buildValueRow(
          layout,
          key: Key('emergency-contact-picker-${contact.number}'),
          value: contact.name,
          placeholder: _namePlaceholder,
          trailing: Image.asset(
            AppAssets.emergencyContactPicker,
            width: layout.px(_pickerIconSize),
            height: layout.px(_pickerIconSize),
          ),
          onTap: () => _pickContact(contact),
        ),
        SizedBox(height: layout.px(_labelGap)),
        _buildLabel(layout, 'telephone number'),
        SizedBox(height: layout.px(_phoneGap)),
        // 手机号由选人一起回填，这里点击同「Contact Information」行一样打开系统通讯录，
        // 口径对齐 peso_shield（那边姓名与手机号在同一个可点区域里）。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pickContact(contact),
          child: SizedBox(
            width: double.infinity,
            height: layout.px(_phoneHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                contact.mobile.isEmpty ? _phonePlaceholder : contact.mobile,
                key: Key('emergency-contact-phone-${contact.number}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _valueStyle(layout, placeholder: contact.mobile.isEmpty),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(AppLayout layout, String text) {
    return SizedBox(
      height: layout.px(_labelHeight),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          // 设计稿三个字段标题都是 `white-space: nowrap`。
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.personalInfoFieldTitle,
            fontSize: layout.px(16),
            fontWeight: FontWeight.w600,
            // 设计稿：`font-size: 16px; line-height: 22px`。
            height: _labelHeight / 16,
          ),
        ),
      ),
    );
  }

  /// 取值行：整行可点，行底 1pt 分隔线（设计稿 `box_5` / `box_6`）。
  Widget _buildValueRow(
    AppLayout layout, {
    required Key key,
    required String value,
    required String placeholder,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: layout.px(_rowHeight),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.isEmpty ? placeholder : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _valueStyle(layout, placeholder: value.isEmpty),
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
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
    );
  }

  static TextStyle _valueStyle(AppLayout layout, {bool placeholder = false}) {
    return TextStyle(
      color: placeholder
          ? AppColors.personalInfoFieldHint
          : AppColors.personalInfoFieldValue,
      fontSize: layout.px(14),
      // 设计稿：`font-size: 14px; line-height: 20px`。
      height: 20 / 14,
    );
  }

  /// 底部固定操作条：白底 + 上方投影，按钮下沿留安全区。
  Widget _buildBottomBar(AppLayout layout) {
    final canSubmit = !_isSubmitting && _contacts.isNotEmpty;
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

  /// 关系下拉：复用个人信息页的选项面板，选中后写回展示文案与提交取值。
  Future<void> _selectRelation(_ContactEntry contact) async {
    if (contact.relationOptions.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showPersonalInfoOptionSheet(
      context: context,
      options: contact.relationOptions
          .map(
            (option) =>
                PersonalInfoOption(label: option.label, value: option.value),
          )
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => contact.relationValue = selected.value);
  }

  /// 打开系统通讯录选人；选中后姓名与手机号一起回填（对齐 peso_shield）。
  Future<void> _pickContact(_ContactEntry contact) async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final picked = await _contactPicker.selectContact();
      if (picked == null || !mounted) return;
      setState(() {
        contact.name = (picked.fullName ?? '').trim();
        contact.mobile = _primaryPhone(picked);
      });
    } catch (_) {
      if (mounted) {
        ToastHelper.showError('Unable to open contacts');
      }
    }
  }

  /// 优先取用户在系统面板里明确选中的号码，其次取第一个非空号码。
  String _primaryPhone(Contact contact) {
    final selected = (contact.selectedPhoneNumber ?? '').trim();
    if (selected.isNotEmpty) return selected;
    for (final phone in contact.phoneNumbers ?? const <String>[]) {
      if (phone.trim().isNotEmpty) return phone.trim();
    }
    return '';
  }

  /// 提交表单：成功后再拉产品详情，走下一步认证。
  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final response = await repository.saveEmergencyContacts(
        productId: widget.productId,
        contacts: _contacts
            .map(
              (contact) => EmergencyContactInput(
                number: contact.number,
                relationValue: contact.relationValue,
                name: contact.name,
                mobile: contact.mobile,
              ),
            )
            .toList(growable: false),
      );
      if (!mounted) return;

      if (!response.isSuccess) {
        ToastHelper.showError(
          response.message.isNotEmpty ? response.message : 'Save failed',
        );
        return;
      }

      // 风控埋点场景 7：结束时间是紧急联系人提交成功这一刻。
      unawaited(
        ReportService.current?.reportRisk(
              productId: widget.productId,
              scene: '7',
              orderNo: widget.orderNo,
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
}

/// 一条联系人的本地可变状态。
///
/// [number]（接口的 `canmaker`）与关系选项来自接口，页面只改姓名 / 手机号 / 关系取值。
class _ContactEntry {
  _ContactEntry(EmergencyContact data)
    : number = data.number,
      relationValue = data.relationValue,
      name = data.name,
      mobile = data.mobile,
      relationOptions = data.relationOptions;

  final String number;
  final List<EmergencyContactOption> relationOptions;
  String relationValue;
  String name;
  String mobile;

  String get relationLabel {
    for (final option in relationOptions) {
      if (option.value == relationValue) return option.label;
    }
    return '';
  }
}
