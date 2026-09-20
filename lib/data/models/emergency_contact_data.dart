import '../../core/network/api_fields.dart';

/// 紧急联系人列表里的一项（接口文档「获取联系人信息（第四项）」）。
///
/// 字段全部由后端下发，页面只按描述渲染：
/// - [number] 是后端给这一项编的位置号（`first` / `second` / `third`…），
///   保存时必须原样回传，不能用列表下标代替。
/// - [relationValue] 是关系下拉的提交取值（`liquidators`），展示文案在选项里查。
/// - [name] / [mobile] 获取接口通常不下发，由用户在系统通讯录里选。
class EmergencyContact {
  const EmergencyContact({
    this.number = '',
    this.relationValue = '',
    this.name = '',
    this.mobile = '',
    this.relationOptions = const [],
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final options = <EmergencyContactOption>[];
    for (final item in _mapListOf(json[ApiFields.emergencyContactDropdown])) {
      final option = EmergencyContactOption.fromJson(item);
      if (option.label.isNotEmpty && option.value.isNotEmpty) {
        options.add(option);
      }
    }
    return EmergencyContact(
      // 后端的 `canmaker` 是 `first` / `second` 这类位置号，同时也是保存时的回传值，
      // 这里不做任何加工。
      number: _text(json[ApiFields.emergencyContactNumber]),
      relationValue: _text(json[ApiFields.emergencyContactRelation]),
      name: _text(json[ApiFields.emergencyContactName]),
      mobile: _text(json[ApiFields.emergencyContactMobile]),
      relationOptions: options,
    );
  }

  /// 位置号（`canmaker`），保存时原样回传。
  final String number;

  /// 关系下拉的提交取值。
  final String relationValue;

  /// 联系人姓名。
  final String name;

  /// 联系人手机号。
  final String mobile;

  /// 关系下拉的选项，由后端下发。
  final List<EmergencyContactOption> relationOptions;

  /// 关系下拉当前取值对应的展示文案（没匹配上时为空）。
  String get relationLabel {
    for (final option in relationOptions) {
      if (option.value == relationValue) return option.label;
    }
    return '';
  }
}

/// 关系下拉的一项：`label` 展示、`value` 提交。
class EmergencyContactOption {
  const EmergencyContactOption({required this.label, required this.value});

  factory EmergencyContactOption.fromJson(Map<String, dynamic> json) {
    return EmergencyContactOption(
      label: _text(json[ApiFields.emergencyContactOptionLabel]),
      value: _text(json[ApiFields.emergencyContactOptionValue]),
    );
  }

  final String label;
  final String value;
}

/// 「获取联系人信息（第四项）」的响应体。
class EmergencyContactData {
  const EmergencyContactData({this.tips = '', this.contacts = const []});

  factory EmergencyContactData.fromJson(Map<String, dynamic> json) {
    // 联系人数组挂在 `conopholis.kneeing` 下；引导文案 `befleas` 与它同级。
    final emergent = json[ApiFields.emergencyContactEmergent];
    final list = emergent is Map
        ? emergent[ApiFields.emergencyContactList]
        : null;
    return EmergencyContactData(
      tips: _text(json[ApiFields.emergencyContactTips]),
      contacts: [
        for (final item in _mapListOf(list)) EmergencyContact.fromJson(item),
      ],
    );
  }

  /// 页面顶部引导文案（低版本 / 未灰度用户不下发，页面用设计稿兜底）。
  final String tips;

  final List<EmergencyContact> contacts;

  /// 后端没下发联系人（低版本 / 未灰度用户），页面走空态。
  bool get isEmpty => contacts.isEmpty;
}

/// 保存联系人信息（第四项）时提交的一项。
///
/// 混淆字段名只出现在这里和仓库层，页面不直接拼字符串。
class EmergencyContactInput {
  const EmergencyContactInput({
    required this.number,
    required this.relationValue,
    required this.name,
    required this.mobile,
  });

  /// 获取接口下发的 `canmaker`，原样回传。
  final String number;

  /// 关系下拉的提交取值（`liquidators`）。
  final String relationValue;

  final String name;
  final String mobile;

  Map<String, String> toJson() => {
    ApiFields.emergencyContactMobile: mobile.trim(),
    ApiFields.emergencyContactName: name.trim(),
    ApiFields.emergencyContactRelation: relationValue.trim(),
    ApiFields.emergencyContactNumber: number,
  };
}

String _text(Object? value) => value?.toString().trim() ?? '';

/// 把响应里的数组转成 `Map` 列表；非对象元素（脏数据）直接丢掉。
List<Map<String, dynamic>> _mapListOf(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.cast<String, dynamic>(),
  ];
}
