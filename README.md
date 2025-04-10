# Discourse QQ OAuth2 Plugin

A Discourse plugin for QQ OAuth2 login, based on `discourse-oauth2-basic`.

## Installation

Add the following to your `app.yml` in the `after_code` hook:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/yourname/discourse-qq-oauth2.git
