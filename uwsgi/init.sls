{# get sites data from the pillar #}
{% set sites = pillar.get('sites', {}) %}

{# Only set-up uwsgi if we have a site #}
{% if sites|length %}

{% set postgres_settings = pillar.get('postgres_settings') -%}

/home/web/repo/uwsgi:
  file.directory:
    - user: web
    - group: web
    - mode: 755
    - require:
      - file.directory: /home/web/repo

/home/web/repo/uwsgi/log:
  file.directory:
    - user: web
    - group: web
    - mode: 755
    - require:
      - file.directory: /home/web/repo/uwsgi

/home/web/repo/uwsgi/vassals:
  file.directory:
    - user: web
    - group: web
    - mode: 755
    - require:
      - file.directory: /home/web/repo/uwsgi

{% for site, settings in sites.iteritems() %}

/home/web/repo/uwsgi/vassals/{{ site }}.ini:
  file:
    - managed
    - source: salt://uwsgi/vassal.ini
    - user: web
    - group: web
    - template: jinja
    - context:
      site: {{ site }}
      postgres_settings: {{ postgres_settings }}
      settings: {{ settings }}
    - require:
      - file.directory: /home/web/repo/uwsgi/vassals

{% endfor %}

/home/web/repo/uwsgi/venv_uwsgi:
  virtualenv.manage:
    - no_site_packages: True
    - requirements: salt://uwsgi/requirements.txt   # install uwsgi into the virtualenv
    - require:                              # requisite declaration
      - pkg: python-virtualenv              # requisite reference
  file.directory:
    - user: web
    - group: web
    - mode: 755
    - makedirs: False
    - recurse:
      - user
      - group
    - require:
      - file.directory: /home/web/repo/uwsgi

/home/web/opt/runinenv.sh:                  # ID declaration
  file:                                     # state declaration
    - managed                               # function
    - source: salt://uwsgi/runinenv.sh      # function arg
    - user: web
    - group: web
    - require:                              # requisite declaration
      - pkg: python-virtualenv              # requisite reference
    - require:
      - file.directory: /home/web/opt
      - user: web

{% endif %}