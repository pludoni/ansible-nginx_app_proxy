#!/bin/bash
# {{ansible_managed }}
# This script is intended to run as a cronjob


{% for routing in routings %}
{% if routing.letsencrypt is defined and routing.letsencrypt %}
/bin/bash -l -c "letsencrypt-cli manage --no-color \
  --key-directory {{letsencrypt_cert_directory}}\
  --account-key {{letsencrypt_account_key_path}}\
  --webroot-path {{letsencrypt_webroot_path}}/.well-known/acme-challenge/\
  {{routing.domains | join(" ")}}"
{% endif %}
{% endfor %}
