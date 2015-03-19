{%- import "makina-states/services/db/postgresql/hooks.sls" as hooks with context %}
{% set cfg = opts.ms_project %}
{% set data = cfg.data %}
include:
  - makina-states.localsettings.nodejs
  - makina-states.services.db.postgresql.client
  - makina-states.localsettings.npm

{{cfg.name}}-htaccess:
  file.managed:
    - name: {{data.htaccess}}
    - source: ''
    - user: www-data
    - group: www-data
    - mode: 770

{% if data.get('http_users', {}) %}
{% for userrow in data.http_users %}
{% for user, passwd in userrow.items() %}
{{cfg.name}}-{{user}}-htaccess:
  webutil.user_exists:
    - name: {{user}}
    - password: {{passwd}}
    - htpasswd_file: {{data.htaccess}}
    - options: m
    - force: true
    - watch:
      - file: {{cfg.name}}-htaccess
{% endfor %}
{% endfor %}
{% endif %}

{{cfg.name}}-www-data:
  user.present:
    - name: www-data
    - optional_groups:
      - {{cfg.group}}
    - remove_groups: false

prepreqs-{{cfg.name}}:
  pkg.installed:
    - watch:
      - user: {{cfg.name}}-www-data
      - mc_proxy: {{hooks.orchestrate['base']['postpkg']}}
    - pkgs:
      - sqlite3
      - liblcms2-2
      - liblcms2-dev
      - libcairomm-1.0-dev
      - libcairo2-dev
      - libsqlite3-dev
      - apache2-utils
      - autoconf
      - automake
      - build-essential
      - bzip2
      - gettext
      - libpq-dev
      - libmysqlclient-dev
      - git
      - groff
      - libbz2-dev
      - libcurl4-openssl-dev
      - libdb-dev
      - libgdbm-dev
      - libreadline-dev
      - libfreetype6-dev
      - libsigc++-2.0-dev
      - libsqlite0-dev
      - libsqlite3-dev
      - libtiff5
      - libtiff5-dev
      - libwebp5
      - libwebp-dev
      - libssl-dev
      - libtool
      - libxml2-dev
      - libxslt1-dev
      - libopenjpeg-dev
      - libopenjpeg2
      - m4
      - man-db
      - pkg-config
      - poppler-utils
      - python-dev
      - python-imaging
      - python-setuptools
      - tcl8.4
      - tcl8.4-dev
      - tcl8.5
      - tcl8.5-dev
      - tk8.5-dev
      - cython
      - python-numpy
      - zlib1g-dev
      # geodjango
      - gdal-bin
      - libgdal1-dev
      - libgeos-dev
      - geoip-bin
      - libgeoip-dev

{{cfg.name}}-dl-odoo:
  mc_git.latest:
    - user: {{cfg.user}}
    - target: "{{cfg.project_root}}/src/odoo"
    - name: "{{data.odoo_url}}"
    - rev: "{{data.odoo_rev}}"


{{cfg.name}}-dirs:
  file.directory:
    - makedirs: true
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - pkg: prepreqs-{{cfg.name}}
      - user: {{cfg.name}}-www-data
    - names:
      - {{cfg.data.odoo_data}}
      - {{cfg.data_root}}/addons
      - {{cfg.data_root}}/addons_repos
      - "{{data.www}}"

{{cfg.name}}-npm:
  cmd.run:
    - require:
      - mc_proxy: nodejs-post-install
    - unless: |
              set -e
              test -e /usr/lib/node_modules/less-plugin-clean-css
              test -e /usr/lib/node_modules/less
    - name: npm install -g less less-plugin-clean-css

{% if data.get('addons_repos', []) %}
{% for i, cdata in salt['mc_utils.json_load'](data.addons_repos).items() %}
{{cfg.name}}-addons-repos-{{i}}:
  mc_git.latest:
    - name: "{{cdata.url}}"
    - user: "{{cfg.user}}"
    {% if cdata.get('rev') %}
    - rev: "{{cdata.get('rev')}}"
    {%endif %}
    - target: "{{cfg.data_root}}/addons_repos/{{i}}"
    - require:
      - file: {{cfg.name}}-dirs
{% endfor %}
{% endif %}


{% set w_ver = '0.12.2.1' %}
{% set suf = '_linux-trusty-amd64' %}
{% set deb = "wkhtmltox-{w_ver}{suf}.deb".format(suf=suf, w_ver=w_ver) %}

{{cfg.name}}-html:
  cmd.run:
    - unless: test "x$(dpkg -l|grep wkhtmltox|awk '{print $3}')" = "x{{w_ver}}"
    - name: |
            set -e
            set -x
            apt-get install -y --force-yes wkhtmltopdf
            apt-get remove wkhtmltopdf
            cd /tmp
            if [ -e "{{deb}}"];then rm -f "{{deb}}";fi
            wget -c "http://downloads.sourceforge.net/project/wkhtmltopdf/{{w_ver}}/{{deb}}"
            apt-get install xfonts-75dpi
            dpkg -i "{{deb}}"
            apt-get -f install
    - use_vt: true
