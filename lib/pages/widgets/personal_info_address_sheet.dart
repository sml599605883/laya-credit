import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/personal_info_data.dart';
import '../../theme/theme.dart';

/// 地址选择面板（认证第二项里的「地址选择」字段）。
///
/// 蓝湖稿 `03-02 - 个人信息-地址选择`：底部白色面板（16pt 顶部圆角）+
/// 右上角关闭按钮 + 灰底层级导航条（已选层级实心点、当前层级加粗）+
/// 单列滚轮。地址按省 / 市 / 区的层级下发（`GET /outsulk/avern`），
/// 点某一行即选中该层级的取值：还有下级就自动进下一层，没有下级就收面板。
///
/// 返回值是层级名称用 `-` 拼起来的完整地址（与接口下发的 `fed`
/// 形如 `Region I-Pangasinan-Alcala` 一致），取消关闭返回 `null`。
Future<String?> showPersonalInfoAddressSheet({
  required BuildContext context,
  required List<AddressNode> nodes,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.idVerifyPickerBarrier,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    // 面板块数多，允许面板超过半屏。
    isScrollControlled: true,
    builder: (context) => _PersonalInfoAddressSheet(nodes: nodes),
  );
}

/// 层级名称：接口只下发名称与编码，层级语义由设计稿固定成这三层。
/// 层级超过三层时沿用最后一级的名称（文档示例最深三层）。
const _levelNames = ['Region', 'Province', 'Municipality'];

class _PersonalInfoAddressSheet extends StatefulWidget {
  const _PersonalInfoAddressSheet({required this.nodes});

  final List<AddressNode> nodes;

  @override
  State<_PersonalInfoAddressSheet> createState() =>
      _PersonalInfoAddressSheetState();
}

class _PersonalInfoAddressSheetState extends State<_PersonalInfoAddressSheet> {
  /// 面板顶部留白（设计稿 `group_1` 的 `padding-top: 21`）。
  static const _topPadding = 21.0;

  /// 关闭按钮 24x24，右边距 15（设计稿 `label_1`）。
  static const _closeSize = 24.0;
  static const _closeRight = 15.0;

  /// 关闭按钮到层级导航条的间距（设计稿 `block_1` 的 `padding-top: 20`）。
  static const _closeToPath = 20.0;

  /// 层级导航条到滚轮的间距（设计稿 534 -> 554）。
  static const _pathToWheel = 20.0;

  /// 层级导航条（设计稿 `box_1`：351x122，圆角 8，内边距 9 / 10 / 10 / 10）。
  static const _pathHorizontal = 12.0;
  static const _pathRadius = 8.0;
  static const _pathPaddingTop = 9.0;
  static const _pathPaddingSide = 10.0;
  static const _pathPaddingBottom = 10.0;

  /// 一行层级的高度（设计稿：行高 18 + 行距 23），连接圆点在行中心。
  static const _pathRowHeight = 41.0;
  static const _pathRowLineHeight = 18.0;

  /// 连接线 / 圆点（设计稿 `编组 35`：11x93，线宽 2，点直径 11）。
  static const _connectorWidth = 11.0;
  static const _connectorLineWidth = 2.0;
  static const _connectorDotSize = 11.0;

  /// 层级行文字到连接列的间距（设计稿文字左边界距面板左边缘 38pt）。
  static const _pathTextGap = 16.0;

  /// 层级行尾箭头（设计稿 `icon_common_go_h`，17x17，三层一致）。
  static const _pathChevron = 17.0;

  /// 滚轮行高与可视高（设计稿：选中行 `text-wrapper_1` 53 高，窗口 5 行）。
  static const _wheelItemExtent = 53.0;
  static const _wheelHeight = 265.0;

  /// 已选层级；下标即层级。点回上层会丢掉更深的选择，避免出现
  /// 「Region A / Province B / Municipality C」这种跨分支的旧值。
  List<AddressNode> _path = [];

  /// 当前正在选的层级。
  int _level = 0;

  List<AddressNode> get _options =>
      _level == 0 ? widget.nodes : _path[_level - 1].children;

  /// 层级导航条的行数：至少三层，选满三层后多留一行给下一层。
  int get _levelCount => math.max(3, _path.length + 1);

  double get _pathHeight =>
      _pathPaddingTop +
      _pathRowLineHeight +
      _pathRowHeight * (_levelCount - 1) +
      _pathPaddingBottom;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final sheetHeight =
        _topPadding +
        _closeSize +
        _closeToPath +
        _pathHeight +
        _pathToWheel +
        _wheelHeight;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        key: const Key('personal-info-address-sheet'),
        width: double.infinity,
        height: layout.px(sheetHeight) + bottomInset,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(layout.px(AppSpacing.radiusMd)),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: layout.px(_topPadding)),
                SizedBox(
                  height: layout.px(_closeSize),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: layout.edgeInsets(right: _closeRight),
                      child: Semantics(
                        button: true,
                        label: 'Close',
                        child: GestureDetector(
                          key: const Key('personal-info-address-close'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: Image.asset(
                            AppAssets.personalInfoSheetClose,
                            width: layout.px(_closeSize),
                            height: layout.px(_closeSize),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: layout.px(_closeToPath)),
                Padding(
                  padding: layout.edgeInsets(
                    left: _pathHorizontal,
                    right: _pathHorizontal,
                  ),
                  child: _LevelPath(
                    layout: layout,
                    path: _path,
                    level: _level,
                    levelCount: _levelCount,
                    rowHeight: _pathRowHeight,
                    rowLineHeight: _pathRowLineHeight,
                    paddingTop: _pathPaddingTop,
                    paddingSide: _pathPaddingSide,
                    paddingBottom: _pathPaddingBottom,
                    radius: _pathRadius,
                    connectorWidth: _connectorWidth,
                    connectorLineWidth: _connectorLineWidth,
                    connectorDotSize: _connectorDotSize,
                    textGap: _pathTextGap,
                    chevron: _pathChevron,
                    onLevelSelected: _selectLevel,
                  ),
                ),
                SizedBox(height: layout.px(_pathToWheel)),
                SizedBox(
                  height: layout.px(_wheelHeight),
                  child: _LevelWheel(
                    key: ValueKey('personal-info-address-wheel-$_level'),
                    layout: layout,
                    options: _options,
                    selectedCode: _selectedCode,
                    itemExtent: _wheelItemExtent,
                    onSelected: _selectNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _selectedCode => _level < _path.length ? _path[_level].code : '';

  /// 点层级导航条回到某一层（更深的已选值作废）。
  void _selectLevel(int level) {
    if (level > _path.length || level == _level) return;
    setState(() {
      _level = level;
      _path = _path.take(level).toList();
    });
  }

  void _selectNode(AddressNode node) {
    // 还有下级就继续往下选，没有下级就收面板。
    if (node.children.isEmpty) {
      Navigator.of(
        context,
      ).pop([..._path.take(_level), node].map((item) => item.name).join('-'));
      return;
    }
    setState(() {
      _path = [..._path.take(_level), node];
      _level = _path.length;
    });
  }
}

/// 灰底层级导航条（设计稿 `box_1`）。
class _LevelPath extends StatelessWidget {
  const _LevelPath({
    required this.layout,
    required this.path,
    required this.level,
    required this.levelCount,
    required this.rowHeight,
    required this.rowLineHeight,
    required this.paddingTop,
    required this.paddingSide,
    required this.paddingBottom,
    required this.radius,
    required this.connectorWidth,
    required this.connectorLineWidth,
    required this.connectorDotSize,
    required this.textGap,
    required this.chevron,
    required this.onLevelSelected,
  });

  final AppLayout layout;
  final List<AddressNode> path;
  final int level;
  final int levelCount;
  final double rowHeight;
  final double rowLineHeight;
  final double paddingTop;
  final double paddingSide;
  final double paddingBottom;
  final double radius;
  final double connectorWidth;
  final double connectorLineWidth;
  final double connectorDotSize;
  final double textGap;
  final double chevron;
  final ValueChanged<int> onLevelSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: layout.edgeInsets(
        left: paddingSide,
        top: paddingTop,
        right: paddingSide,
        bottom: paddingBottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.personalInfoAddressPathBackground,
        borderRadius: layout.radius(radius),
      ),
      child: Stack(
        children: [
          // 连接各层级的竖线 + 圆点：画在文字下层，`Positioned.fill` 让它按行高铺满。
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: layout.px(connectorWidth),
            child: CustomPaint(
              painter: _LevelConnectorPainter(
                level: level,
                levelCount: levelCount,
                rowHeight: layout.px(rowHeight),
                firstRowCenter: layout.px(rowLineHeight / 2),
                lineWidth: layout.px(connectorLineWidth),
                dotSize: layout.px(connectorDotSize),
                lineColor: AppColors.surface,
                activeColor: AppColors.personalInfoAddressPathActive,
                dotColor: AppColors.surface,
              ),
            ),
          ),
          Column(
            children: [
              for (var index = 0; index < levelCount; index++)
                SizedBox(
                  height: layout.px(
                    index == levelCount - 1 ? rowLineHeight : rowHeight,
                  ),
                  // 文字与箭头都贴在该行 18pt 的行框上（而不是在 41pt 的
                  // 行高里居中），这样行距才会是设计稿的 23 / 24pt。
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      height: layout.px(rowLineHeight),
                      child: Row(
                        children: [
                          SizedBox(width: layout.px(connectorWidth)),
                          SizedBox(width: layout.px(textGap)),
                          Expanded(
                            child: Text(
                              index < path.length
                                  ? path[index].name
                                  : _levelNames[math.min(
                                      index,
                                      _levelNames.length - 1,
                                    )],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: index == level
                                    ? AppColors.personalInfoAddressPathActive
                                    : AppColors.personalInfoAddressPathInactive,
                                fontSize: layout.px(14),
                                fontWeight: index == level
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                // 设计稿：`font-size: 14px; line-height: 18px`。
                                height: 18 / 14,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: index == level
                                ? null
                                : () => onLevelSelected(index),
                            child: Image.asset(
                              AppAssets.personalInfoAddressChevron,
                              width: layout.px(chevron),
                              height: layout.px(chevron),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 层级导航条左侧的连接线与圆点（设计稿 `编组 35`）。
///
/// 状态口径与 fund_nexus 的地址选择进度条一致：**已走过的层级（含当前层）**
/// 的圆点与它到下一层的连线都用选中色，只有还没走到的层级保持白色。
/// 也就是说已经选过的层级不会因为焦点下移而退回白色。
class _LevelConnectorPainter extends CustomPainter {
  const _LevelConnectorPainter({
    required this.level,
    required this.levelCount,
    required this.rowHeight,
    required this.firstRowCenter,
    required this.lineWidth,
    required this.dotSize,
    required this.lineColor,
    required this.activeColor,
    required this.dotColor,
  });

  final int level;
  final int levelCount;
  final double rowHeight;
  final double firstRowCenter;
  final double lineWidth;
  final double dotSize;
  final Color lineColor;
  final Color activeColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centers = [
      for (var index = 0; index < levelCount; index++)
        firstRowCenter + rowHeight * index,
    ];
    // 连线按「上一点 -> 下一点」拆成一段段画：连到 index 这一层的线，
    // 只要这一层已经走过就上选中色。
    for (var index = 0; index < centers.length - 1; index++) {
      canvas.drawLine(
        Offset(centerX, centers[index]),
        Offset(centerX, centers[index + 1]),
        Paint()
          ..color = index + 1 <= level ? activeColor : lineColor
          ..strokeWidth = lineWidth,
      );
    }

    for (var index = 0; index < centers.length; index++) {
      canvas.drawCircle(
        Offset(centerX, centers[index]),
        dotSize / 2,
        Paint()..color = index <= level ? activeColor : dotColor,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelConnectorPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.levelCount != levelCount;
}

/// 当前层级的取值滚轮：点某一行即选中（面板没有确认按钮，
/// 与设计稿一致——设计稿上只有关闭按钮）。
class _LevelWheel extends StatefulWidget {
  const _LevelWheel({
    super.key,
    required this.layout,
    required this.options,
    required this.selectedCode,
    required this.itemExtent,
    required this.onSelected,
  });

  final AppLayout layout;
  final List<AddressNode> options;
  final String selectedCode;
  final double itemExtent;
  final ValueChanged<AddressNode> onSelected;

  @override
  State<_LevelWheel> createState() => _LevelWheelState();
}

class _LevelWheelState extends State<_LevelWheel> {
  late final FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    final index = widget.options.indexWhere(
      (node) => node.code == widget.selectedCode,
    );
    _index = index < 0 ? 0 : index;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    if (widget.options.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        // 选中行上下各一条 1pt 分隔线（设计稿 `text-wrapper_1` 的描边）。
        // 滚轮把选中项居中，窗口正好 5 行高，所以选中行的上下边界落在
        // 第 2、3 个 itemExtent 处；写成 2/3 而不是中心 ± 半行，避免偏半行。
        _selectionLine(layout, widget.itemExtent * 2),
        _selectionLine(layout, widget.itemExtent * 3),
        ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: layout.px(widget.itemExtent),
          physics: const FixedExtentScrollPhysics(),
          // 设计稿的行是平的（没有 3D 透视）。
          perspective: 0.0001,
          diameterRatio: 1.0,
          overAndUnderCenterOpacity: 1.0,
          onSelectedItemChanged: (index) => setState(() => _index = index),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.options.length,
            builder: (context, index) {
              final distance = (index - _index).abs();
              final selected = distance == 0;
              return GestureDetector(
                key: Key('personal-info-address-option-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelected(widget.options[index]),
                child: Center(
                  child: Text(
                    widget.options[index].name,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: selected
                          ? AppColors.idVerifyPickerTextSelected
                          : distance == 1
                          ? AppColors.idVerifyPickerTextNear
                          : AppColors.idVerifyFieldLabel,
                      fontSize: layout.px(18),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      // 设计稿：`font-size: 18px; line-height: 20px`。
                      height: 20 / 18,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
