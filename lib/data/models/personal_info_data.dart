import '../../core/network/api_fields.dart';

/// 个人信息认证页的字段控件类型（认证第二项）。
///
/// 接口文档「值映射 - 认证项组件」给的是「原版 → 混淆后」三组
/// （`enum` → `Obesity`、`txt` → `Ori`、`citySelect` → `CumingsAgami`），
/// 但文档里「获取用户信息（第二项）」的响应示例用的又是 `stepped` / `stage` / `onto`。
/// 两套都按语义并起来认，任何一套下发生效都不会把字段渲染成不可用：
/// 选项选择 = `Obesity` / `enum` / `stepped`，文本输入 = `Ori` / `txt` / `onto`，
/// 地址选择 = `CumingsAgami` / `citySelect` / `stage`。
enum PersonalInfoControl { selection, text, address, unsupported }

/// 获取用户信息（第二项，`POST /outsulk/orchel`）的响应。
class PersonalInfoData {
  const PersonalInfoData({required this.fields, required this.tips});

  factory PersonalInfoData.fromJson(Map<String, dynamic> json) {
    final rawFields = json[ApiFields.infoFieldList];
    return PersonalInfoData(
      fields: rawFields is List
          ? rawFields
                .whereType<Map>()
                .map(
                  (field) =>
                      PersonalInfoField.fromJson(field.cast<String, dynamic>()),
                )
                .where((field) => field.key.isNotEmpty)
                .toList(growable: false)
          : const [],
      tips: json[ApiFields.infoFieldTips]?.toString().trim() ?? '',
    );
  }

  /// 表单字段（顺序即后端下发顺序，页面不要自己排序）。
  final List<PersonalInfoField> fields;

  /// 页面引导文案（`befleas`，低版本或未灰度用户不下发）。
  final String tips;

  /// 后端没下发字段：页面走空态，而不是画一张空表单。
  bool get isEmpty => fields.isEmpty;
}

/// 一个可选项（文档里是 `{harbingers, liquidators}`）。
///
/// 工作信息的 `Payday`（发薪日）字段是**二级选项**：一级是发薪周期
/// （Daily / Weekly / Twice per Month / Once a Month），每个周期自己再带一组
/// 下级选项（周几 / 每月几号），下级数组用的仍是 `overwhelming`
/// （口径对齐 peso_shield 的同名处理）。
class PersonalInfoOption {
  const PersonalInfoOption({
    required this.label,
    required this.value,
    this.children = const [],
  });

  factory PersonalInfoOption.fromJson(Map<String, dynamic> json) {
    final children = json[ApiFields.infoFieldOptions];
    return PersonalInfoOption(
      label: json[ApiFields.infoOptionLabel]?.toString() ?? '',
      value: json[ApiFields.infoOptionValue]?.toString() ?? '',
      children: children is List
          ? children
                .whereType<Map>()
                .map(
                  (child) => PersonalInfoOption.fromJson(
                    child.cast<String, dynamic>(),
                  ),
                )
                .where(
                  (child) => child.label.isNotEmpty && child.value.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
    );
  }

  /// 展示文案。
  final String label;

  /// 保存接口要提交的值。
  final String value;

  /// 下级选项；为空表示这是一级选项或普通单级选项。
  final List<PersonalInfoOption> children;
}

/// 一个表单字段。
class PersonalInfoField {
  const PersonalInfoField({
    required this.title,
    required this.placeholder,
    required this.key,
    required this.control,
    required this.isNumeric,
    required this.options,
    required this.initialDisplayValue,
    required this.initialSubmitValue,
  });

  factory PersonalInfoField.fromJson(Map<String, dynamic> json) {
    final options = json[ApiFields.infoFieldOptions];
    final parsedOptions = options is List
        ? options
              .whereType<Map>()
              .map(
                (option) =>
                    PersonalInfoOption.fromJson(option.cast<String, dynamic>()),
              )
              .where(
                (option) => option.label.isNotEmpty && option.value.isNotEmpty,
              )
              .toList(growable: false)
        : const <PersonalInfoOption>[];
    final currentValue = json[ApiFields.infoFieldValue]?.toString() ?? '';
    final initial = _initialValue(parsedOptions, currentValue);
    return PersonalInfoField(
      title: json[ApiFields.infoFieldTitle]?.toString() ?? '',
      placeholder: json[ApiFields.infoFieldPlaceholder]?.toString() ?? '',
      key: json[ApiFields.infoFieldKey]?.toString().trim() ?? '',
      control: _controlOf(json[ApiFields.infoFieldControl]?.toString() ?? ''),
      isNumeric:
          json[ApiFields.infoFieldNumeric] == 1 ||
          json[ApiFields.infoFieldNumeric] == '1',
      options: parsedOptions,
      initialDisplayValue: initial.display,
      initialSubmitValue: initial.submit,
    );
  }

  /// 字段标题（设计稿 `text_7` 等）。
  final String title;

  /// 未填时的占位文案。
  final String placeholder;

  /// **保存接口的业务 key**（后端下发，不能写死）。
  final String key;

  final PersonalInfoControl control;

  /// 数字键盘（文档 `lazy`）。
  final bool isNumeric;

  final List<PersonalInfoOption> options;

  /// 进入页面时输入框 / 行上展示的值。
  final String initialDisplayValue;

  /// 用户没改动时提交的值（选项类字段提交 `liquidators`，不是文案）。
  final String initialSubmitValue;

  /// 是否有二级选项（工作信息的 `Payday`：发薪周期 + 具体发薪日）。
  ///
  /// 有二级选项的字段不能走单级选择面板，否则只能选到周期、丢掉具体日期。
  bool get hasNestedOptions =>
      options.any((option) => option.children.isNotEmpty);

  static PersonalInfoControl _controlOf(String raw) {
    switch (raw) {
      case 'Obesity':
      case 'enum':
      case 'stepped':
        return PersonalInfoControl.selection;
      case 'Ori':
      case 'txt':
      case 'onto':
        return PersonalInfoControl.text;
      case 'CumingsAgami':
      case 'citySelect':
      case 'stage':
        return PersonalInfoControl.address;
      default:
        return PersonalInfoControl.unsupported;
    }
  }

  /// 后端下发的是「当前值」（`fed`）：选项类字段给的是**文案**，
  /// 保存时要换成选项对应的 `liquidators`（对齐 peso_shield 的口径）。
  static ({String display, String submit}) _initialValue(
    List<PersonalInfoOption> options,
    String currentValue,
  ) {
    for (final option in options) {
      if (option.label == currentValue || option.value == currentValue) {
        return (display: option.label, submit: option.value);
      }

      // 二级选项的回填口径对齐 peso_shield：后端下发的 `fed` 形如
      // `Once a Month|1`（一级文案|二级文案），提交值要换成二级的 `liquidators`。
      for (final child in option.children) {
        final display = '${option.label}|${child.label}';
        if (currentValue == display ||
            currentValue == child.value ||
            currentValue == child.label ||
            currentValue.endsWith('|${child.label}')) {
          return (display: display, submit: child.value);
        }
      }
    }
    return (display: currentValue, submit: currentValue);
  }
}

/// 地址初始化（`GET /outsulk/avern`）的响应。
class AddressInitData {
  const AddressInitData({required this.nodes});

  factory AddressInitData.fromJson(Object? data) {
    return AddressInitData(nodes: AddressNode.parseRoot(data));
  }

  /// 顶层地址（省 / 州），下级在各自的 `children` 里。
  final List<AddressNode> nodes;
}

/// 地址初始化（`GET /outsulk/avern`）的一个层级节点。
class AddressNode {
  const AddressNode({
    required this.id,
    required this.code,
    required this.name,
    required this.children,
  });

  factory AddressNode.fromJson(Map<String, dynamic> json) {
    return AddressNode(
      id: json[ApiFields.addressId]?.toString().trim() ?? '',
      code: json[ApiFields.addressCode]?.toString().trim() ?? '',
      name: json[ApiFields.addressName]?.toString().trim() ?? '',
      children: _parseFirst(json, const [
        ApiFields.addressChildren,
        ApiFields.addressNodes,
      ]),
    );
  }

  /// 层级 id（`cussedly`）。
  final String id;

  /// 层级编码（`crucians`）。
  final String code;

  /// 层级名称（`harbingers`），提交时用它拼接完整地址。
  final String name;

  final List<AddressNode> children;

  /// 顶层节点数组。文档下发在 `kneeing`，但后端同一族的地址接口把省列表
  /// 直接放在 `burner` 下的情况也存在，两个键都认，避免只读一个键时
  /// 解析结果为 `null`、弹窗整片空白。
  static List<AddressNode> parseRoot(Object? data) {
    if (data is List) return parseList(data);
    if (data is Map) {
      return _parseFirst(data.cast<String, dynamic>(), const [
        ApiFields.addressNodes,
        ApiFields.addressChildren,
      ]);
    }
    return const [];
  }

  static List<AddressNode> _parseFirst(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final nodes = parseList(json[key]);
      if (nodes.isNotEmpty) return nodes;
    }
    return const [];
  }

  /// 解析一个地址数组，丢掉没有名称的脏数据。
  ///
  /// 编码（`crucians`）是文档约定的节点字段，正常情况下按「名称 + 编码」
  /// 过滤；个别环境会整批漏下发编码，此时退回只校验名称，保证有名称的
  /// 层级仍能展示，而不是整片空白。
  static List<AddressNode> parseList(Object? raw) {
    if (raw is! List) return const [];
    final nodes = raw
        .whereType<Map>()
        .map((node) => AddressNode.fromJson(node.cast<String, dynamic>()))
        .toList(growable: false);
    final withCode = nodes
        .where((node) => node.name.isNotEmpty && node.code.isNotEmpty)
        .toList(growable: false);
    if (withCode.isNotEmpty) return withCode;
    return nodes.where((node) => node.name.isNotEmpty).toList(growable: false);
  }
}
