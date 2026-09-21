import 'package:flutter/material.dart';

import '../../data/models/bind_card_data.dart';
import '../../theme/theme.dart';
import '../../widgets/remote_image.dart';

/// 绑卡页的打款渠道单选面板（蓝湖稿 `认证-绑定电子钱包-选择`）。
///
/// 面板自下弹出，白底通栏：每行是「渠道 logo + 渠道名」，维护中的渠道在名字
/// 下面补一行红字提示（仍可选中，不置灰）；当前选中的渠道行尾打勾。
/// 底部是一条 8pt 间隔带 + 居中的 `Done`，点 `Done` 才回填选中值，
/// 中途点行只改面板内的选中态（与设计稿一致）。
Future<BindCardOption?> showBindCardOptionSheet({
  required BuildContext context,
  required List<BindCardOption> options,
  String? selectedValue,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<BindCardOption>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bindCardSheetBarrier,
    elevation: 0,
    isScrollControlled: true,
    builder: (_) =>
        _BindCardOptionSheet(options: options, selectedValue: selectedValue),
  );
}

/// 面板里每行的行高（设计稿：572 -> 629，含渠道名与维护提示）。
const _rowHeight = 57.0;

/// 行与行之间的 1pt 分隔线。
const _dividerHeight = 1.0;

/// 渠道 logo 的边长（设计稿 `block_7` / `group_9`，20x20）。
const _logoSize = 20.0;

/// logo 与渠道名之间的间距。
const _logoGap = 15.0;

/// 选中行尾部对勾距右边缘的距离。
const _checkRight = 24.0;

/// `Done` 上方的分组间隔带高度（设计稿 `block_6`，8pt）。
const _doneGapHeight = 8.0;

/// `Done` 文案行高（设计稿 `text_18 { line-height: 19 }`）。
const _doneLineHeight = 19.0;

/// `Done` 行的上下留白（设计稿 `group_5 { padding: 11 0 20 0 }` 的底部一段）。
const _doneTopPadding = 20.0;
const _doneBottomPadding = 20.0;

/// 维护中渠道在面板里的提示文案（设计稿 `text_17`）。
///
/// 接口只下发「是否维护中」（`catchpenny == 0`），没有提示文案字段，
/// 所以这行文案是客户端常量。
const _maintenanceHint = 'Under maintenance. Loans may be delayed';

class _BindCardOptionSheet extends StatefulWidget {
  const _BindCardOptionSheet({
    required this.options,
    required this.selectedValue,
  });

  final List<BindCardOption> options;
  final String? selectedValue;

  @override
  State<_BindCardOptionSheet> createState() => _BindCardOptionSheetState();
}

class _BindCardOptionSheetState extends State<_BindCardOptionSheet> {
  late BindCardOption? _selected = _initialSelected();

  BindCardOption? _initialSelected() {
    for (final option in widget.options) {
      if (option.value == widget.selectedValue) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final rowsHeight =
        widget.options.length * (_rowHeight + _dividerHeight) - _dividerHeight;
    final contentHeight =
        rowsHeight +
        _doneGapHeight +
        _doneTopPadding +
        _doneLineHeight +
        _doneBottomPadding;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final sheetHeight = layout.px(contentHeight).clamp(0.0, maxHeight);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: sheetHeight + bottomInset,
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = 0;
                        index < widget.options.length;
                        index++
                      )
                        ..._buildRow(layout, widget.options[index], index),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: layout.px(_doneGapHeight),
                child: const ColoredBox(color: AppColors.bindCardSheetGap),
              ),
              _buildDone(layout),
              SizedBox(height: layout.px(_doneBottomPadding) + bottomInset),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRow(AppLayout layout, BindCardOption option, int index) {
    return [
      _BindCardOptionRow(
        option: option,
        selected: option.value == _selected?.value,
        onTap: () => setState(() => _selected = option),
      ),
      if (index < widget.options.length - 1)
        SizedBox(
          height: layout.px(_dividerHeight),
          child: const ColoredBox(color: AppColors.bindCardSheetDivider),
        ),
    ];
  }

  Widget _buildDone(AppLayout layout) {
    return GestureDetector(
      key: const Key('bind-card-option-done'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(_selected),
      child: Padding(
        padding: layout.edgeInsets(top: _doneTopPadding),
        child: SizedBox(
          height: layout.px(_doneLineHeight),
          child: Center(
            child: Text(
              'Done',
              style: TextStyle(
                color: AppColors.bindCardSheetDoneText,
                fontSize: layout.px(16),
                // 设计稿：`font-size: 16px; line-height: 19px`。
                height: _doneLineHeight / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BindCardOptionRow extends StatelessWidget {
  const _BindCardOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final BindCardOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      key: Key('bind-card-option-${option.value}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: layout.px(_rowHeight),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.logoUrl.isNotEmpty) ...[
                        _logo(layout),
                        SizedBox(width: layout.px(_logoGap)),
                      ],
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.bindCardOptionText,
                          fontSize: layout.px(16),
                          // 设计稿：`font-size: 16px; line-height: 19px`。
                          height: 19 / 16,
                        ),
                      ),
                    ],
                  ),
                  if (!option.available) ...[
                    SizedBox(height: layout.px(2)),
                    Text(
                      _maintenanceHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.bindCardOptionHint,
                        fontSize: layout.px(10),
                        // 设计稿：`font-size: 10px; line-height: 12px`。
                        height: 12 / 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: layout.edgeInsets(right: _checkRight),
                  child: _OptionCheck(layout: layout),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logo(AppLayout layout) {
    return Container(
      width: layout.px(_logoSize),
      height: layout.px(_logoSize),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: layout.radius(4),
        border: Border.all(
          color: AppColors.bindCardOptionLogoBorder,
          width: layout.px(1),
        ),
      ),
      child: ClipRRect(
        borderRadius: layout.radius(4),
        child: RemoteImage(
          url: option.logoUrl,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

/// 选中渠道的对勾（设计稿 `thumbnail_4`，11x8）。
///
/// `assets/` 里没有这张切图，按设计稿尺寸用画笔还原
/// （与 `FieldChevron` 的处理一致）。
class _OptionCheck extends StatelessWidget {
  const _OptionCheck({required this.layout});

  final AppLayout layout;

  static const _width = 11.0;
  static const _height = 8.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.px(_width),
      height: layout.px(_height),
      child: const CustomPaint(painter: _OptionCheckPainter()),
    );
  }
}

class _OptionCheckPainter extends CustomPainter {
  const _OptionCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.bindCardTabActiveText
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.42)
        ..lineTo(size.width * 0.36, size.height)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OptionCheckPainter oldDelegate) => false;
}
