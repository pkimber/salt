{% set monitor = pillar.get('monitor', None) %}
{% if monitor %}

/opt/graphite:
  file.directory:
    - user: web
    - group: web
    - makedirs: True
    - require:
      - user: web

/opt/graphite/conf/carbon.conf:
  file:
    - managed
    - source: salt://monitor/carbon.conf
    - user: web
    - group: web
    - require:
      - user: web

/opt/graphite/conf/storage-schemas.conf:
  file:
    - managed
    - source: salt://monitor/storage-schemas.conf
    - user: web
    - group: web
    - require:
      - user: web

/opt/graphite/venv_graphite:
  virtualenv.manage:
    - system_site_packages: False
    - requirements: salt://monitor/requirements.txt
    - user: web
    - require:
      - pkg: python-virtualenv

{% endif %}