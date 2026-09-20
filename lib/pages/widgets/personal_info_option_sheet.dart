import 'package:flutter/material.dart';

import '../../data/models/personal_info_data.dart';
import '../../theme/theme.dart';

/// 选项选择面板（认证表单里的「枚举」字段，如 Gender / Education / Payday）。
///
/// 蓝湖稿没有单独出这一张，沿用同一设计家族的面板规格
/// （`03-02 - 个人信息-日期选择`）：白底 + 16pt 顶部圆角 + 右上角灰色 `Done`，
/// 下面是单列滚轮，选中行上下各一条 1pt `#EEEEEE` 分隔线，
/// 越远离选中行文字越浅（±1 行 `#666666`，其余 `#999999`）。
///
/// 面板每次打开都从**第一项**开始，不回填当前值（产品要求不预选）。
Future<PersonalInfoOption?> showPersonalInfoOptionSheet({
  required BuildContext context,
  required List<PersonalInfoOption> options,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<PersonalInfoOption>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.idVerifyPickerBarrier,
    elevation: 0,
    // 面板自己带 16pt 顶部圆角。
    shape: const RoundedRectangleBorder(),
    builder: (context) => _PersonalInfoOptionSheet(options: options),
  );
}

class _PersonalInfoOptionSheet extends StatefulWidget {
  const _PersonalInfoOptionSheet({required this.options});

  final List<PersonalInfoOption> options;

  @override
  State<_PersonalInfoOptionSheet> createState() =>
      _PersonalInfoOptionSheetState();
}

class _PersonalInfoOptionSheetState extends State<_PersonalInfoOptionSheet> {
  /// 面板高度（与日期面板同高，换字段不会跳高度）。
  static const _sheetHeight = 307.0;
  static const _sheetRadius = 16.0;

  /// `Done` 行（设计稿 `text-wrapper_2`：上留 10，行高 19，右边距 15）。
  static const _headerTopPadding = 10.0;
  static const _headerHeight = 19.0;
  static const _doneRightPadding = 15.0;

  /// 滚轮区（设计稿 `text-wrapper_4`：上下留白 22 / 12，可视高 234）。
  static const _wheelTopPadding = 22.0;
  static const _wheelBottomPadding = 12.0;
  static const _wheelHeight = 234.0;

  /// 滚轮行高与选中行高（设计稿 `text-wrapper_3`：14 + 20 + 16）。
  static const _itemExtent = 52.5;
  static const _selectionHeight = 50.0;

  late final FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    // 不预选：每次打开都停在第一项。
    _index = 0;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
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
                  key: const Key('personal-info-option-done'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Navigator.of(context).pop(widget.options[_index]),
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
                  ListWheelScrollView.useDelegate(
                    key: const Key('personal-info-option-wheel'),
                    controller: _controller,
                    itemExtent: layout.px(_itemExtent),
                    physics: const FixedExtentScrollPhysics(),
                    // 设计稿的行是平的（没有 3D 透视）。
                    perspective: 0.0001,
                    diameterRatio: 1.0,
                    overAndUnderCenterOpacity: 1.0,
                    onSelectedItemChanged: (index) =>
                        setState(() => _index = index),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.options.length,
                      builder: (context, index) {
                        final distance = (index - _index).abs();
                        final selected = distance == 0;
                        return Center(
                          child: Text(
                            widget.options[index].label,
                            // 设计稿 `white-space: nowrap`：文案长也不换行。
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.idVerifyPickerTextSelected
                                  : distance == 1
                                  ? AppColors.idVerifyPickerTextNear
                                  : AppColors.idVerifyFieldLabel,
                              fontSize: layout.px(20),
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              // 设计稿：`font-size: 20px; line-height: 24px`。
                              height: 24 / 20,
                            ),
                          ),
                        );
                      },
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
}
