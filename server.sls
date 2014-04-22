{%- set server = pillar.billometer.server %}
{%- if server.enabled %}

include:
- git
- python

billometer_packages:
  pkg.installed:
  - names:
    - python-pip
    - python-virtualenv
    - python-memcached
    - python-imaging
    - python-docutils
    - python-simplejson
    - python-tz
    - gettext
  - require:
    - pkg: python_packages

/srv/billometer:
  virtualenv.manage:
  - system_site_packages: True
  - requirements: salt://billometer/conf/requirements.txt
  - require:
    - pkg: billometer_packages

billometer_user:
  user.present:
  - name: billometer
  - system: True
  - home: /srv/billometer
  - require:
    - virtualenv: /srv/billometer

{{ server.source.address }}:
  git.latest:
  - target: /srv/billometer/billometer
  - rev: {{ server.source.rev }}
  - require:
    - virtualenv: /srv/billometer
    - pkg: git_packages

/srv/billometer/site/core/wsgi.py:
  file:
  - managed
  - source: salt://billometer/conf/wsgi.py
  - mode: 755
  - template: jinja
  - require:
    - file: /srv/billometer/site/core

/srv/billometer/bin/gunicorn_start:
  file.managed:
  - source: salt://billometer/conf/gunicorn_start
  - mode: 700
  - user: billometer
  - group: billometer
  - template: jinja
  - require:
    - virtualenv: /srv/billometer

billometer_dirs:
  file.directory:
  - names:
    - /srv/billometer/site/core
    - /srv/billometer/static
    - /srv/billometer/logs
  - user: root
  - group: root
  - mode: 755
  - makedirs: true
  - require:
    - virtualenv: /srv/billometer

/srv/billometer/media:
  file:
  - directory
  - user: billometer
  - group: billometer
  - mode: 755
  - makedirs: true
  - require:
    - virtualenv: /srv/billometer

/srv/billometer/site/core/settings.py:
  file.managed:
  - user: root
  - group: root
  - source: salt://billometer/conf/settings.py
  - template: jinja
  - mode: 644
  - require:
    - file: billometer_dirs

/srv/billometer/site/core/__init__.py:
  file.managed:
  - user: root
  - group: root
  - template: jinja
  - mode: 644
  - require:
    - file: billometer_dirs

/srv/billometer/site/manage.py:
  file.managed:
  - user: root
  - group: root
  - source: salt://billometer/conf/manage.py
  - template: jinja
  - mode: 755
  - require:
    - file: billometer_dirs

sync_database_billometer:
  cmd.run:
  - name: python manage.py syncdb --noinput
  - cwd: /srv/billometer/site
  - require:
    - file: /srv/billometer/site/manage.py

migrate_database_billometer:
  cmd.run:
  - name: python manage.py migrate --noinput
  - cwd: /srv/billometer/site
  - require:
    - cmd: sync_database_billometer

collect_static_billometer:
  cmd.run:
  - name: python manage.py collectstatic --noinput
  - cwd: /srv/billometer/site
  - require:
    - cmd: sync_database_billometer

{%- endif %}