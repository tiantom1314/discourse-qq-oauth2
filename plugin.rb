# name: discourse-qq-oauth2
# about: OAuth2 strategy for QQ login (based on discourse-oauth2-basic)
# version: 0.1
# authors: Your Name
# url: https://github.com/yourname/discourse-qq-oauth2

require_dependency 'auth/oauth2_authenticator'

# 自定义 OAuth2 策略
class OmniAuth::Strategies::QQOAuth2 < OmniAuth::Strategies::OAuth2
  option :name, 'qq_oauth2'

  option :client_options, {
    site: 'https://graph.qq.com',
    authorize_url: '/oauth2.0/authorize',
    token_url: '/oauth2.0/token'
  }

  option :token_params, {
    parse: :query
  }

  option :authorize_params, {
    scope: 'get_user_info'
  }

  uid { raw_info['id'] }

  info do
    {
      name: raw_info['nickname'],
      username: raw_info['nickname'],
      image: raw_info['figureurl_qq_2'],
      email: "qq_#{raw_info['id']}@example.com" # 占位邮箱
    }
  end

  extra do
    { raw_info: raw_info }
  end

  def raw_info
    @raw_info ||= begin
      # 设置 access_token 的请求模式为 query 参数
      access_token.options[:mode] = :query
      access_token.options[:param_name] = 'access_token'

      # 获取 openid
      openid_response = access_token.get('/oauth2.0/me').body
      openid_json = openid_response[/\{.*\}/] # 提取 JSON 部分
      openid_data = JSON.parse(openid_json)
      openid = openid_data['openid']

      # 获取用户信息
      user_info = access_token.get('/user/get_user_info', params: { oauth_consumer_key: client.id, openid: openid }).parsed
      user_info['id'] = openid
      user_info
    end
  end

  def callback_url
    full_host + script_name + callback_path
  end
end

# 注册 OAuth2 策略
OmniAuth.config.add_camelization('qq_oauth2', 'QQOAuth2')

# 定义认证器
class Auth::QQOAuth2Authenticator < Auth::OAuth2Authenticator
  def name
    'qq_oauth2'
  end

  def enabled?
    SiteSetting.qq_oauth2_enabled
  end
end

# 注册认证器
auth_provider title: 'with QQ',
              enabled_setting: 'qq_oauth2_enabled',
              authenticator: Auth::QQOAuth2Authenticator.new('qq_oauth2', trusted: true)

# 注册设置
SiteSetting.add_setting :qq_oauth2_enabled, type: :boolean, default: false
SiteSetting.add_setting :qq_oauth2_client_id, type: :string, default: ''
SiteSetting.add_setting :qq_oauth2_client_secret, type: :string, default: '', secret: true

# 添加设置到序列化器
add_to_serializer(:site, :qq_oauth2_enabled) { SiteSetting.qq_oauth2_enabled }
add_to_serializer(:site, :qq_oauth2_client_id) { SiteSetting.qq_oauth2_client_id }
add_to_serializer(:site, :qq_oauth2_client_secret) { SiteSetting.qq_oauth2_client_secret }

# 初始化 OAuth2 策略
after_initialize do
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :qq_oauth2,
             SiteSetting.qq_oauth2_client_id,
             SiteSetting.qq_oauth2_client_secret,
             provider_ignores_state: true
  end
end
