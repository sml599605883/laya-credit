import '../../core/network/api_fields.dart';

/// 绑卡页的字段控件类型（认证第五项）。
///
/// 接口文档「值映射 - 认证项组件」给的是三组「原版 → 混淆后」：
/// `enum` → `Obesity`、`txt` → `Ori`、`citySelect` → `CumingsAgami`。
/// 测试环境实测下发的是短名 `enum` / `txt` / `citySelect`，
/// 两套都按语义并起来认，任何一套下发生效都不会把字段渲染成不可用。
enum BindCardControl { selection, text, address, unsupported }

/// 一个打款渠道 / 银行选项（文档示例：`{liquidators, harbingers, salish, catchpenny}`）。
class BindCardOption {
  const BindCardOption({
    required this.label,
    required this.value,
    required this.logoUrl,
    required this.available,
  });

  factory BindCardOption.fromJson(Map<String, dynamic> json) {
    final status = json[ApiFields.bindCardOptionStatus]?.toString() ?? '';
    return BindCardOption(
      label: json[ApiFields.bindCardOptionLabel]?.toString().trim() ?? '',
      value: json[ApiFields.bindCardOptionValue]?.toString().trim() ?? '',
      logoUrl: json[ApiFields.bindCardOptionLogo]?.toString().trim() ?? '',
      // 银行分组不下发 `catchpenny`，缺省按「可用」处理。
      available: status != '0',
    );
  }

  /// 展示名（如 `GCash e-wallet`）。
  final String label;

  /// 提交取值（提交绑卡的打款渠道）。
  final String value;

  /// 渠道 logo，可能为空（银行的 `salish` 就是空串）。
  final String logoUrl;

  /// 是否可用（文档 `catchpenny`：1 可用 / 0 维护中）。
  ///
  /// 维护中的渠道**仍可选中**，页面只补一行提示，不做禁用。
  final bool available;
}

/// 绑卡表单里的一个字段。
class BindCardField {
  const BindCardField({
    required this.title,
    required this.placeholder,
    required this.key,
    required this.control,
    required this.options,
    required this.isNumeric,
    required this.isOptional,
    required this.initialDisplayValue,
    required this.initialSubmitValue,
    required this.suggestedValue,
  });

  factory BindCardField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json[ApiFields.bindCardFieldOptions];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map(
                (option) =>
                    BindCardOption.fromJson(option.cast<String, dynamic>()),
              )
              .where((option) => option.label.isNotEmpty)
              .toList(growable: false)
        : const <BindCardOption>[];
    final currentValue = json[ApiFields.bindCardFieldValue]?.toString() ?? '';
    final initial = _initialValue(options, currentValue);
    return BindCardField(
      title: json[ApiFields.bindCardFieldTitle]?.toString() ?? '',
      placeholder: json[ApiFields.bindCardFieldPlaceholder]?.toString() ?? '',
      key: json[ApiFields.bindCardFieldKey]?.toString().trim() ?? '',
      control: _controlOf(
        json[ApiFields.bindCardFieldControl]?.toString() ?? '',
      ),
      options: options,
      isNumeric: _boolOf(json[ApiFields.bindCardFieldNumeric]),
      isOptional: _boolOf(json[ApiFields.bindCardFieldOptional]),
      initialDisplayValue: initial.display,
      initialSubmitValue: initial.submit,
      suggestedValue:
          json[ApiFields.bindCardFieldSuggested]?.toString().trim() ?? '',
    );
  }

  /// 打款渠道字段的下发 key（`crucians` 给的语义串）。
  ///
  /// 这一项是唯一需要改名的字段：下发 key 是 `channelCode`，
  /// 提交绑卡时后端要的是 `entertainer`（见 [ApiFields.bindCardSubmitChannel]）。
  static const channelKey = 'channelCode';

  /// 字段标题（设计稿里的大标题，如 `Select your recipient E-wallet`）。
  final String title;

  /// 未填时的占位文案。
  final String placeholder;

  /// **提交绑卡的 key**（后端下发，不能写死）。
  final String key;

  final BindCardControl control;

  final List<BindCardOption> options;

  /// 数字键盘（文档 `lazy`）。
  final bool isNumeric;

  /// 是否可选（文档 `als`，1 可选 / 0 必填）。
  final bool isOptional;

  /// 进入页面时行上展示的值（选项类字段是选项文案）。
  final String initialDisplayValue;

  /// 用户没改动时提交的值（选项类字段提交 `liquidators`，不是文案）。
  final String initialSubmitValue;

  /// 后端下发的自动填充建议值（文档 `displayValue`），可能为空。
  final String suggestedValue;

  /// 打款渠道字段：整行是「请选择 + 箭头」，点开单选框。
  bool get isChannel =>
      key == channelKey || control == BindCardControl.selection;

  /// 可选的枚举字段（点头弹单选面板）。
  bool get isSelectable => control == BindCardControl.selection;

  static BindCardControl _controlOf(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'enum':
      case 'obesity':
        return BindCardControl.selection;
      case 'txt':
      case 'ori':
        return BindCardControl.text;
      case 'cityselect':
      case 'cumingsagami':
        return BindCardControl.address;
      default:
        return BindCardControl.unsupported;
    }
  }

  /// 后端下发的是「当前值」（`fed`）：选项类字段可能给文案，也可能给取值，
  /// 展示与提交要分开取值（对齐个人信息 / 工作信息的口径）。
  static ({String display, String submit}) _initialValue(
    List<BindCardOption> options,
    String currentValue,
  ) {
    for (final option in options) {
      if (option.label == currentValue || option.value == currentValue) {
        return (display: option.label, submit: option.value);
      }
    }
    return (display: currentValue, submit: currentValue);
  }

  static bool _boolOf(Object? value) =>
      value == 1 || value == '1' || value == true || value == 'true';
}

/// 一个打款方式分组（E-wallet / Bank / ...），对应页面顶部的一枚 Tab。
class BindCardGroup {
  const BindCardGroup({
    required this.label,
    required this.type,
    required this.fields,
  });

  factory BindCardGroup.fromJson(Map<String, dynamic> json) {
    final rawFields = json[ApiFields.bindCardGroupFields];
    return BindCardGroup(
      label: json[ApiFields.bindCardGroupLabel]?.toString().trim() ?? '',
      type: json[ApiFields.bindCardGroupType]?.toString().trim() ?? '',
      fields: rawFields is List
          ? rawFields
                .whereType<Map>()
                .map(
                  (field) =>
                      BindCardField.fromJson(field.cast<String, dynamic>()),
                )
                .where(
                  (field) =>
                      field.title.isNotEmpty &&
                      field.key.isNotEmpty &&
                      field.control != BindCardControl.unsupported,
                )
                .toList(growable: false)
          : const [],
    );
  }

  /// Tab 文案（如 `E-wallet`）。
  final String label;

  /// 提交绑卡的卡片类型（文档 `cardType`）。
  final String type;

  final List<BindCardField> fields;
}

/// 获取绑卡信息（第五项，`GET /outsulk/cussedly`）的响应。
class BindCardData {
  const BindCardData({
    this.groups = const [],
    this.prompt = '',
    this.bottomPrompt = '',
  });

  factory BindCardData.fromJson(Map<String, dynamic> json) {
    final rawGroups = json[ApiFields.bindCardGroups];
    return BindCardData(
      groups: rawGroups is List
          ? rawGroups
                .whereType<Map>()
                .map(
                  (group) =>
                      BindCardGroup.fromJson(group.cast<String, dynamic>()),
                )
                .where(
                  (group) =>
                      group.label.isNotEmpty &&
                      group.type.isNotEmpty &&
                      group.fields.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
      prompt: json[ApiFields.bindCardTips]?.toString().trim() ?? '',
      bottomPrompt: json[ApiFields.bindCardBottomTips]?.toString().trim() ?? '',
    );
  }

  /// 打款方式分组（顺序即后端下发顺序，页面不要自己排序）。
  final List<BindCardGroup> groups;

  /// 页面顶部引导文案（`befleas`，低版本或未灰度用户不下发）。
  final String prompt;

  /// 页面底部提示文案（`revision`）。
  final String bottomPrompt;

  /// 后端没下发分组：页面走空态，而不是画一张空表单。
  bool get isEmpty => groups.isEmpty;
}
