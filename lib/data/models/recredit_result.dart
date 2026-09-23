import '../../core/network/api_fields.dart';

/// 重新授信接口（`GET /outsulk/phantom`）的授信结果。
///
/// 文档只定义了两个取值：`1` 授信成功、`2` 暂无授信结果。
/// 其他取值一律按「还没出结果」处理：等待授信页会继续轮询，
/// 既不会误判成功、也不会因为没见过的值而抛异常。
class RecreditResult {
  const RecreditResult({required this.resultCode});

  factory RecreditResult.fromJson(Map<String, dynamic> json) {
    return RecreditResult(
      resultCode: _intOf(json[ApiFields.recreditResultCode]),
    );
  }

  /// 授信结果码（`connectedly.countercharged`）。
  final int resultCode;

  /// 是否授信成功（`1`）。
  bool get isGranted => resultCode == _grantedCode;

  static const _grantedCode = 1;
}

int _intOf(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
