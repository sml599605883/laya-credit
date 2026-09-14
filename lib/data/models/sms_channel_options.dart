import '../../core/network/api_fields.dart';

/// 验证码发送渠道开关（首次短信发送失败后可换渠道重发）。
class SmsChannelOptions {
  const SmsChannelOptions({
    required this.sms,
    required this.voice,
    required this.viber,
  });

  factory SmsChannelOptions.fromJson(Map<String, dynamic> json) {
    return SmsChannelOptions(
      sms: _enabled(json[ApiFields.channelSms]),
      voice: _enabled(json[ApiFields.channelVoice]),
      viber: _enabled(json[ApiFields.channelViber]),
    );
  }

  final bool sms;
  final bool voice;
  final bool viber;

  /// 后端用 1/0（也可能下发字符串）表示开关。
  static bool _enabled(Object? value) {
    if (value is num) return value != 0;
    return value?.toString() == '1';
  }

  bool get hasAny => sms || voice || viber;
}

/// 验证码发送渠道。
enum SmsChannel {
  sms('sms'),
  voice('voice'),
  viber('viber');

  const SmsChannel(this.value);

  final String value;
}
