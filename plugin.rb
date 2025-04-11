# name: discourse-qq-oauth2
# about: Authenticate with Discourse using QQ OAuth2
# version: 0.2
# authors: tiantom1314, Grok (xAI)
# url: https://github.com/tiantom1314/discourse-qq-oauth2

require 'omniauth-oauth2'

# 定义 QQ 认证器
class QQAuthenticator < ::Auth::Authenticator
  def name
    'qq_connect'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    raw_info = auth_token[:extra][:raw_info]
    name = data['nickname']
    username = data['name']
    qq_uid = auth_token[:uid]

    # 检查是否已有用户绑定了这个 QQ UID
    current_info = ::PluginStore.get('qq', "qq_uid_#{qq_uid}")

    result.user =
      if current_info
        User.where(id: current_info[:user_id]).first
      end

    result.name = name
    result.username = username
    # QQ 登录不返回邮箱，生成一个虚拟邮箱，后续需要用户手动填写
    result.email = "qq_#{qq_uid}@example.com"
    result.email_valid = false # 强制用户验证邮箱
    result.extra_data = { qq_uid: qq_uid, raw_info: raw_info }

    result
  end

  def after_create_account(user, auth)
    qq_uid = auth[:extra_data][:qq_uid]
    ::PluginStore.set('qq', "qq_uid_#{qq_uid}", { user_id: user.id })
  end

  def register_middleware(omniauth)
    omniauth.provider :qq_connect,
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                        strategy.options[:client_id] = SiteSetting.qq_connect_client_id
                        strategy.options[:client_secret] = SiteSetting.qq_connect_client_secret
                        strategy.options[:client_options] = {
                          site: 'https://graph.qq.com',
                          authorize_url: '/oauth2.0/authorize',
                          token_url: '/oauth2.0/token'
                        }
                        strategy.options[:token_params] = { parse: :query }
                        strategy.options[:authorize_params] = { scope: 'get_user_info' }
                      }
  end
end

# 自定义 OAuth2 策略
class OmniAuth::Strategies::QQConnect < OmniAuth::Strategies::OAuth2
  option :name, 'qq_connect'

  uid { raw_info['id'] }

  info do
    {
      name: raw_info['nickname'],
      username: raw_info['nickname'],
      image: raw_info['figureurl_qq_2']
    }
  end

  extra do
    { raw_info: raw_info }
  end

  def raw_info
    @raw_info ||= begin
      access_token.options[:mode] = :query
      access_token.options[:param_name] = 'access_token'

      # 获取 openid
      openid_response = access_token.get('/oauth2.0/me').body
      openid_json = openid_response[/\{.*\}/]
      openid_data = JSON.parse(openid_json)
      openid = openid_data['openid']

      # 获取用户信息
      user_info = access_token.get('/user/get_user_info', params: { oauth_consumer_key: client.id, openid: openid }).parsed
      user_info['id'] = openid
      user_info
    end
  end
end

# 注册设置项
enabled_site_setting :qq_connect_enabled

SiteSetting.add_setting :qq_connect_enabled, type: :boolean, default: false
SiteSetting.add_setting :qq_connect_client_id, type: :string, default: ''
SiteSetting.add_setting :qq_connect_client_secret, type: :string, default: '', secret: true

add_to_serializer(:site, :qq_connect_enabled) { SiteSetting.qq_connect_enabled }
add_to_serializer(:site, :qq_connect_client_id) { SiteSetting.qq_connect_client_id }
add_to_serializer(:site, :qq_connect_client_secret) { SiteSetting.qq_connect_client_secret }

# 注册认证提供者
auth_provider title: 'with QQ',
              enabled_setting: 'qq_connect_enabled',
              frame_width: 760,
              frame_height: 500,
              authenticator: QQAuthenticator.new,
              background_color: '#51b7ec'

# 添加样式
register_css <<CSS
.btn-social.qq_connect:before {
  font-family: "Font Awesome 5 Free";
  content: "\\f3ce";
}
CSS
