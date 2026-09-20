import 'personal_info_page.dart';

/// 工作信息认证页（蓝湖稿 `03-03 - 工作信息`），认证流程的工作信息项。
///
/// 与 [PersonalInfoPage] 是同一套 UI（头图 / 进度缎带 / 动态字段表单 /
/// 底部 Upload），只换数据源与文案：`GET /outsulk/timeling` +
/// `POST /outsulk/kneeing`、进度 `50%`、导航标题 `Job information`。
class WorkInformationPage extends PersonalInfoPage {
  const WorkInformationPage({super.key, required super.productId})
    : super.work();
}
