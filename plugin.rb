# plugin.rb
require 'omniauth-oauth2'

class QQAuthenticator < ::Auth::Authenticator
  PLUGIN_NAME = 'qq_connect'.freeze
  QQ_PROVIDER = 'qq_connect'.freeze

  def name
    QQ_PROVIDER
  end

  def enabled?
    SiteSetting.qq_connect_enabled # 添加启用/禁用开关
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    # 提取认证数据
    uid = auth_token[:uid]
    info = auth_token[:info] || {}
    extra = auth_token[:extra] || {}

    # 设置用户信息
    result.name = info['nickname'] || "QQUser_#{uid}"
    result.username = generate_username(info['name'], uid)
    result.email = info['email'] if info['email'] # QQ API 可能返回邮箱
    result.email_valid = false # 默认不信任第三方邮箱

    # 检查现有用户
    current_info = PluginStore.get(PLUGIN_NAME, "qq_#{uid}")
    result.user = User.find_by(id: current_info[:user_id]) if current_info

    # 存储额外数据
    result.extra_data = { qq_uid: uid, raw_info: extra[:raw_info] }

    result
  rescue StandardError => e
    Rails.logger.error("QQ Auth Error: #{e.message}")
    result.failed = true
    result.failed_reason = "Authentication failed: #{e.message}"
    result
  end

  def after_create_account(user, auth)
    uid = auth[:uid]
    PluginStore.set(PLUGIN_NAME, "qq_#{uid}", { user_id: user.id })
  end

  def register_middleware(omniauth)
    omniauth.provider :qq_connect,
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                        strategy.options[:client_id] = SiteSetting.qq_connect_client_id
                        strategy.options[:client_secret] = SiteSetting.qq_connect_client_secret
                        strategy.options[:authorize_url] = 'https://graph.qq.com/oauth2.0/authorize'
                        strategy.options[:token_url] = 'https://graph.qq.com/oauth2.0/token'
                        strategy.options[:scope] = 'get_user_info' # 根据需要调整
                      }
  end

  private

  def generate_username(name, uid)
    base = name&.parameterize || "qq_#{uid}"
    UserNameSuggester.suggest(base) # 使用 Discourse 的用户名生成工具
  end
end

# 配置认证提供者
auth_provider title: 'Login with QQ',
              authenticator: QQAuthenticator.new,
              frame_width: 760,
              frame_height: 500,
              background_color: '#51b7ec'

# 添加设置项
add_admin_route 'qq_connect.title', 'qq_connect'
register_setting :qq_connect_enabled, type: :boolean, default: false
register_setting :qq_connect_client_id, type: :string, secret: true
register_setting :qq_connect_client_secret, type: :string, secret: true

# CSS 样式
register_css <<CSS
.btn-social.qq_connect:before {
  font-family: "Font Awesome 5 Free";
  content: "\f1d6";
  font-weight: 900;
}
CSS
