cd /var/www/mail_proxy
git pull

export $(cat /etc/mail_proxy/env | xargs)
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix release --overwrite

# run migrations if schema changed
_build/prod/rel/mail_proxy/bin/mail_proxy eval "MailProxy.Release.migrate()"

sudo systemctl restart mail_proxy
