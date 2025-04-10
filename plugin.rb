# name: discourse-qq-oauth2
# about: Authenticate with Discourse using QQ OAuth2
# version: 0.1
# authors: tiantom1314

require 'omniauth-oauth2'

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

    current_info = ::PluginStore.get('qq', "qq_uid_#{qq_uid}")

    result.user =
      if current_info
        User.where(id: current_info[:user_id]).first
      end

    result.name = name
    result.username = username
    result.email = "qq_#{qq_uid}@example.com"
    result.extra_data = { qq_uid: qq_uid, raw_info: raw_info }

    result
  end

  def after_create_account(user, auth)
    qq_uid = auth[:uid]
    ::PluginStore.set('qq', "qq_id_#{qq_uid}", {user_id: user.id})
  end

  def register_middleware(omniauth)
    omniauth.provider :qq_connect, :setup => lambda { |env|
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
      access_token.options[:param_name] = 'acces
