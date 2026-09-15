import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../../core/network/obfuscation_helper.dart';
import '../models/home_data.dart';

/// 首页相关接口。
class AppRepository {
  const AppRepository(this._client);

  final HttpClient _client;

  /// APP 首页。游客也可访问。
  Future<ApiResponse<HomeData>> getHomePage() {
    return _client.get<HomeData>(
      ApiEndpoints.homePage,
      params: {
        ApiFields.obfuscateHome1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateHome2: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? HomeData.fromJson(data.cast<String, dynamic>())
          : const HomeData(
              banner: null,
              product: null,
              orders: [],
              notices: [],
            ),
    );
  }

  /// 上传 banner 点击记录。
  Future<ApiResponse<void>> recordBannerClick(String bannerId) {
    return _client.post<void>(
      ApiEndpoints.bannerClick,
      params: {
        ApiFields.bannerConfigId: bannerId,
        ApiFields.obfuscateBannerClick: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }
}
