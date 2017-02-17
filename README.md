## Ansible Role for Nginx router/proxy with brotli/http2

These roles are intended for a single-purpose host that acts as an internet-facing proxy/router service, which protects internal apps.

* Routing multiple domains to (internal) ips
* SSL termination with up2date cipherlist and HTTP/2, optional force-ssl redirect
* automatic issuing of missing ssl certificates if requested

**requires Ubuntu 16.04+**

* Ubuntu 16.04 ships a nginx version with http2 but without Brotli, which we will compile

This module consists of 2 independent submodules:

### nginx_brotli

* Installs nginx from (Ubuntu)-Source with enabled ngx_brotli support

```yaml
- hosts: router
  roles:
  - role: pludoni.nginx_app_proxy/nginx_brotli
    nginx_conf_extra:
      # create extra files under /etc/nginx/conf.d/brotli
      brotli:
        # there are already gzip and proxy headers enabled, just e.g.
        - brotli on
        - brotli_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript
```

**Note** Brotli on-the-fly encoding is disabled by default. It will only be active if you enable the option in a conf.d/*.conf like shown above.

All Brotli-options here: https://github.com/google/ngx_brotli

### letsencrypt

* Creates an unpriviliged user that will run the certificate request and have hold of the ssl certificates/keys

```yaml
- hosts: router
  roles:
  - role: pludoni.nginx_app_proxy/letsencrypt
    # for Letsencrypt registration, Letsencrypt will write you emails if your certificates are about to expire
    letsencrypt_email: youradmin@yourdomain.de
    routings:
      # a list of http/https hosts which are bundled together
      - name: myservice1
        # target ip
        target: '10.10.10.3'
        # issue letsencrypt certificate and add to cronjob
        letsencrypt: true
        # redirect all http -> https traffic and enable HSTS
        force_ssl: true
        domains:
          - mydomain.de
          - www.mydomain.de

      # variant 2: NO Letsencrypt but manually uploaded ssl certs (must to by yourself before)
      # also overwrite some configs
      - name: myservice2
        target: '10.10.10.2'
        ssl_key: '/etc/ssl/main.key'
        ssl_crt: '/etc/ssl/combined.crt'
        proxy_read_timeout: 120s
        proxy_send_timeout: 120s
        client_max_body_size: 50M
        domains:
          - myservice1.de
          - www.myservice1.de
          - en.myservice1.de
```

* Each routing will receive its own logfiles under /var/log/nginx/NAME/[access|error].log with logrotate.
* There are several cronjobs:
  * Every month or so, letsencrypt will update the certificates that are running out in the current month
  * Every day, all certificates and private keys are packaged as a .tar.gz and put to /backup

* You can download that seed file every so often and use it, if you are making a new host use that seedfile:
  * ``letsencrypt_seed_file: "{{playbook_dir}}/files/letsencrypt-data.tar.gz"``
  * It will uploaded/unzipped once.

## Caveats

* Uses SSL local session cache, so if you have more than 40.000 clients / 10minute window, that cache will be empty. Then switching to session tickets would help, or reducing that timeout in ``letsencrypt/templates/nginx-ssl.conf``
* This router doesnt add security headers X-Frame-Options or Content-Type Options by default. For our uses, we need some apps that need to be embeddable and our app server add that header anyways.
* No real "Load Balancer" at the moment. Target can only be one IP.
* Uses the "Legacy config" from https://cipherli.st/, which still supports IE &lt; 9 and Android 2.3.

## Fail2ban

* There is a locally tested Fail2Ban jail config which can be run as another role:

```yaml
  - role: pludoni.nginx_app_proxy/fail2ban
    letsencrypt_email: youradmin@yourdomain.de
    fail2ban_ignoreip: 127.0.0.1/8 10.0.0.0/8
    fail2ban_destmail: admin@localhost
    fail2ban_sender: "{{fail2ban_destmail}}"
    fail2ban_mta: "sendmail"
```

As the letsencrypt role modifies the nginx default access logs to include the hostname and more information, the fail2ban also needed some adjustments. Most important is the nginx-noscript Fail2Ban Jail, which will block out spider that are looking for missing scripts, like wp-admin, wp-login, phpmyadmin etc.

There are another 2 jails, nginx-home (for blocking crawler that querying /~) and badbots, but those are less valuable.

You can read more about this here:
https://www.digitalocean.com/community/tutorials/how-to-protect-an-nginx-server-with-fail2ban-on-ubuntu-14-04
