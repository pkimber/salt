{% set sites = pillar.get('sites', {}) %}

{# Do any of the sites on this server have FTP #}
{# nasty workaround from #}
{# http://stackoverflow.com/questions/9486393/jinja2-change-the-value-of-a-variable-inside-a-loop #}
{% set vars = {'has_ftp': False} %}
{% for site, settings in sites.iteritems() %}
  {% if settings.get('ftp', None) %}
    {% if vars.update({'has_ftp': True}) %} {% endif %}
  {% endif %}
{% endfor %}
{% set has_ftp = vars.has_ftp %}

{# Only set-up ftp if we have a site using ftp #}
{% if has_ftp %}
  vsftpd:
    pkg:
      - installed
    service:
      - running
      - watch:
         - file: /etc/vsftpd.conf
         - file: /etc/vsftpd.userlist

  /etc/vsftpd.conf:
    file.managed:
      - source: salt://ftp/vsftpd.conf
      - user: root
      - group: root
      - mode: 644
      - require:
        - pkg: vsftpd

  /etc/vsftpd.userlist:
    file:
      - managed
      - source: salt://ftp/vsftpd.userlist
      - template: jinja
      - context:
        sites: {{ sites }}
      - require:
        - pkg: vsftpd

  /home/web/repo/ftp:
    file.directory:
      - user: web
      - group: web
      - mode: 755
      - require:
        - file: /home/web/repo
{% endif %}

{% for site, settings in sites.iteritems() %}
{% if settings.get('ftp', None) %}
{# for ftp uploads #}
  /home/web/repo/ftp/{{ site }}:
    file.directory:
      - user: web
      - group: web
      - mode: 755
      - require:
        - file: /home/web/repo/ftp

  ftp_group_{{ site }}:
    group.present:
      - name: {{ site }}
      - gid: {{ settings.get('ftp_user_id') }}
      - system: True

  ftp_user_{{ site }}:
    user.present:
      - name: {{ site }}
      - uid: {{ settings.get('ftp_user_id') }}
      - gid_from_name: True
      - password: {{ settings.get('ftp_password') }}
      - shell: /bin/bash
      - require:
        - group: ftp_group_{{ site }}

  {# folder for ftp upload #}
  /home/{{ site }}/site:
    file.directory:
      - user: {{ site }}
      - group: web
      - require:
        - user: {{ site }}
      - mode: 755

  /home/{{ site }}/site/static:
    file.directory:
      - user: {{ site }}
      - group: web
      - require:
        - file: /home/{{ site }}/site
      - mode: 755

  /home/{{ site }}/site/templates:
    file.directory:
      - user: {{ site }}
      - group: web
      - require:
        - file: /home/{{ site }}/site
      - mode: 755

  /home/{{ site }}/site/templates/templatepages:
    file.directory:
      - user: {{ site }}
      - group: web
      - require:
        - file: /home/{{ site }}/site/templates
      - mode: 755

  {# symlink uploads to site folder #}
  /home/web/repo/ftp/{{ site }}/site:
    file.symlink:
      - target: /home/{{ site }}/site
      - require:
        - file: /home/web/repo/ftp/{{ site }}
        - file: /home/{{ site }}/site

  /home/{{ site }}/opt:
    file.directory:
      - user: {{ site }}
      - group: web
      - mode: 755
      - makedirs: False

  /home/{{ site }}/opt/venv_watch_ftp_folder:
    virtualenv.manage:
      - system_site_packages: False
      - requirements: salt://ftp/requirements2.txt
      - user: {{ site }}
      - require:
        - pkg: python-virtualenv

  {# watch files created in the site folder and set correct mode #}
  /home/{{ site }}/opt/watch_ftp_folder.py:
    file:
      - managed
      - source: salt://ftp/watch_ftp_folder.py
      - user: {{ site }}
      - group: web
      - mode: 755
      - makedirs: False

{% endif %}
{% endfor %}
