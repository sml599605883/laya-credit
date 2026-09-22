import '../../core/network/api_fields.dart';

/// 收款账户卡片下半部分的字段排布（蓝湖稿 `04-01 - 确认借款-选择其它方式`）。
///
/// 与文档 `cardType`（`heterological`）的对应：1 电子钱包 / 2 银行 →
/// [receiptAccount]；3 便利店（现金网点）→ [cashPickup]。
enum LoanAccountKind {
  /// 银行 / 电子钱包：一行「`Receipt Account` + 收款账号」，值右对齐。
  receiptAccount,

  /// 现金网点：等分三列「`First Name` / `Middle Name` / `Last Name`」。
  cashPickup,
}

/// 借款确认页里可选的一笔收款账户。
///
/// 页面按 [kind] 决定卡下半部分的排布，其余部分（渠道 logo、账户名、
/// 维护中提示、右侧单选圈）三种类型一致。
class LoanAccount {
  const LoanAccount({
    required this.id,
    required this.name,
    this.kind = LoanAccountKind.receiptAccount,
    this.logoUrl = '',
    this.available = true,
    this.isMain = false,
    this.receiptAccount = '',
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
  });

  /// [groupTitle] 是所属分节名（文档 `cardTypeName`），[groupCardType] 是所属
  /// 分节的卡片类型（文档 `cardType`，1 电子钱包 / 2 银行 / 3 便利店），
  /// 两者共同决定下半部分排版，见 [_kindOf]。
  factory LoanAccount.fromJson(
    Map<String, dynamic> json, {
    required String groupTitle,
    int? groupCardType,
  }) {
    // 收款人姓名挂在 `telecomm`（文档语义 `option`）里，现金网点才下发。
    final holder = json[ApiFields.loanAccountHolder];
    final names = holder is Map
        ? holder.cast<String, dynamic>()
        : const <String, dynamic>{};
    final firstName = _textOf(names[ApiFields.loanAccountFirstName]);
    final middleName = _textOf(names[ApiFields.loanAccountMiddleName]);
    final lastName = _textOf(names[ApiFields.loanAccountLastName]);
    final hasHolder =
        firstName.isNotEmpty || middleName.isNotEmpty || lastName.isNotEmpty;
    final status = json[ApiFields.loanAccountStatus];

    return LoanAccount(
      id: _textOf(json[ApiFields.loanAccountBindId]),
      name: _textOf(json[ApiFields.loanAccountName]),
      kind: _kindOf(groupCardType, groupTitle, hasHolder),
      logoUrl: _textOf(json[ApiFields.loanAccountLogo]),
      // 缺少状态字段时按「可用」处理，不把账户默认标成维护中。
      available: status == null || _intOf(status) != 0,
      isMain: _intOf(json[ApiFields.loanAccountIsMain]) == 1,
      receiptAccount: _textOf(json[ApiFields.loanAccountNumber]),
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
    );
  }

  /// 绑卡 id（文档 `bindId`）：选中态与提交换卡都用它。
  final String id;

  /// 渠道展示名（文档 `bankName`，如 `BDO` / `GCash` / `M Lhuillier`）。
  final String name;

  final LoanAccountKind kind;

  /// 渠道 logo 地址，可能为空（设计稿里的 logo 有兜底底色）。
  final String logoUrl;

  /// 是否可用（文档 `catchpenny`：1 可用 / 0 维护中）。
  ///
  /// 维护中的账户**仍可选中**，页面只补一行提示，不做禁用。
  final bool available;

  /// 是否需要展示「维护中」提示。文案由页面给出，模型只暴露状态。
  bool get underMaintenance => !available;

  /// 是否后端指定的默认账户（文档 `isMain`），页面用它决定进入时的预选项。
  final bool isMain;

  /// `receiptAccount` 类型：收款账号（设计稿 `text_8` / `text_11`）。
  final String receiptAccount;

  /// `cashPickup` 类型：收款人三节姓名（设计稿 `text_14` / `text_16` / `text_18`）。
  final String firstName;
  final String middleName;
  final String lastName;
}

/// 一组同类型的收款账户（设计稿里的 `Bank` / `E-wallet` / `Cash Pickup` 分节）。
class LoanAccountGroup {
  const LoanAccountGroup({required this.title, required this.accounts});

  factory LoanAccountGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json[ApiFields.loanAccountItems];
    // 分节标题与卡片类型都由后端下发（文档 `cardTypeName` / `cardType`）。
    final title = _textOf(json[ApiFields.loanAccountGroupTitle]);
    final cardType = _intOrNull(json[ApiFields.loanAccountGroupType]);
    return LoanAccountGroup(
      title: title,
      accounts: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => LoanAccount.fromJson(
                    item.cast<String, dynamic>(),
                    groupTitle: title,
                    groupCardType: cardType,
                  ),
                )
                .where((account) => account.id.isNotEmpty)
                .toList(growable: false)
          : const <LoanAccount>[],
    );
  }

  /// 分节标题（设计稿 `text_4` / `text_9` / `text_12`）。
  final String title;

  final List<LoanAccount> accounts;
}

/// 借款确认页的数据：分节顺序即页面展示顺序，不由页面重排。
class LoanConfirmData {
  const LoanConfirmData({this.groups = const [], this.selectedId = ''});

  factory LoanConfirmData.fromJson(Map<String, dynamic> json) {
    final rawGroups = json[ApiFields.loanAccountGroups];
    final groups = rawGroups is List
        ? rawGroups
              .whereType<Map>()
              .map(
                (group) =>
                    LoanAccountGroup.fromJson(group.cast<String, dynamic>()),
              )
              .where((group) => group.accounts.isNotEmpty)
              .toList(growable: false)
        : const <LoanAccountGroup>[];
    return LoanConfirmData(
      groups: groups,
      selectedId: _defaultSelected(groups),
    );
  }

  final List<LoanAccountGroup> groups;

  /// 默认选中的账户 id：取后端标了 `isMain` 的那一笔；
  /// 后端没有指定时留空，页面不预选（`Upload` 也就点不动）。
  final String selectedId;

  /// 没有任何可选账户时页面走空态，而不是画一张空列表。
  bool get isEmpty => groups.isEmpty;

  static String _defaultSelected(List<LoanAccountGroup> groups) {
    for (final group in groups) {
      for (final account in group.accounts) {
        if (account.isMain) return account.id;
      }
    }
    return '';
  }
}

String _textOf(Object? value) => value?.toString().trim() ?? '';

int _intOf(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intOrNull(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// 分节的卡片类型 / 分节名判定卡下半部分怎么排版。
///
/// 本项目接口文档「提交绑卡（第五项）」对分组的 `cardType`（账户列表挂在分组上
/// 的 `heterological`）定义了枚举：1 电子钱包 / 2 银行 / 3 便利店（现金网点）。
/// 只有 `3` 是明确的现金网点信号，直接按它判定；`1` / `2` 不反推——文档「用户账户
/// 列表」的样例里 `heterological` 与 `retzian` 本身就对不上（`1` + `Bank`），
/// 所以其余情况退回分节名（`cardTypeName`）：名字里带 `cash` 就是现金网点；
/// 分节名为空但有收款人姓名也按现金网点排版。
LoanAccountKind _kindOf(int? cardType, String groupTitle, bool hasHolder) {
  if (cardType == 3) return LoanAccountKind.cashPickup;
  if (groupTitle.toLowerCase().contains('cash')) {
    return LoanAccountKind.cashPickup;
  }
  if (groupTitle.isEmpty && hasHolder) return LoanAccountKind.cashPickup;
  return LoanAccountKind.receiptAccount;
}
