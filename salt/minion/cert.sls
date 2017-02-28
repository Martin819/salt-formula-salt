{%- from "salt/map.jinja" import minion with context %}
{%- if minion.enabled %}

{%- for cert_name,cert in minion.get('cert', {}).iteritems() %}
{%- set rowloop = loop %}

{%- set key_file  = cert.get('key_file', '/etc/ssl/private/' + cert.common_name + '.key') %}
{%- set cert_file = cert.get('cert_file', '/etc/ssl/certs/' + cert.common_name + '.crt') %}
{%- set ca_file = cert.get('ca_file', '/etc/ssl/certs/ca-' + cert.authority + '.crt') %}
{%- set key_dir = key_file|replace(key_file.split('/')[-1], "") %}
{%- set cert_dir = cert_file|replace(cert_file.split('/')[-1], "") %}
{%- set ca_dir = ca_file|replace(ca_file.split('/')[-1], "") %}

{# Only ensure directories exists, don't touch permissions, etc. #}
salt_minion_cert_{{ cert_name }}_dirs:
  file.directory:
    - names:
      - {{ key_dir }}
      - {{ cert_dir }}
      - {{ ca_dir }}
    - makedirs: true
    - replace: false

{{ key_file }}:
  x509.private_key_managed:
    - bits: {{ cert.get('bits', 4096) }}
  require:
    - file: salt_minion_cert_{{ cert_name }}_dirs

{{ key_file }}_key_permissions:
  file.managed:
    - name: {{ key_file }}
    - mode: {{ cert.get("mode", 0600) }}
    {%- if salt['user.info'](cert.get("user", "root")) %}
    - user: {{ cert.get("user", "root") }}
    {%- endif %}
    {%- if salt['group.info'](cert.get("group", "root")) %}
    - group: {{ cert.get("group", "root") }}
    {%- endif %}
    - replace: false
    - watch:
      - x509: {{ key_file }}

{{ cert_file }}:
  x509.certificate_managed:
    - ca_server: {{ cert.host }}
    - signing_policy: {{ cert.authority }}_{{ cert.signing_policy }}
    - public_key: {{ key_file }}
    - CN: "{{ cert.common_name }}"
    {%- if cert.alternative_names is defined %}
    - subjectAltName: "{{ cert.alternative_names }}"
    {%- endif %}
    {%- if cert.extended_key_usage is defined %}
    - extendedKeyUsage: "{{ cert.extended_key_usage }}"
    {%- endif %}
    {%- if cert.key_usage is defined %}
    - keyUsage: "{{ cert.key_usage }}"
    {%- endif %}
    - days_remaining: 30
    - backup: True
    - watch:
      - x509: {{ key_file }}

{{ cert_file }}_cert_permissions:
  file.managed:
    - name: {{ cert_file }}
    - mode: {{ cert.get("mode", 0600) }}
    {%- if salt['user.info'](cert.get("user", "root")) %}
    - user: {{ cert.get("user", "root") }}
    {%- endif %}
    {%- if salt['group.info'](cert.get("group", "root")) %}
    - group: {{ cert.get("group", "root") }}
    {%- endif %}
    - replace: false
    - watch:
      - x509: {{ cert_file }}

{%- for ca_path,ca_cert in salt['mine.get'](cert.host, 'x509.get_pem_entries').get(cert.host, {}).iteritems() %}

{%- if '/etc/pki/ca/'+cert.authority in ca_path %}

{{ ca_file }}_{{ rowloop.index }}:
  x509.pem_managed:
    - name: {{ ca_file }}
    - text: {{ ca_cert|replace('\n', '') }}
    - watch:
      - x509: {{ cert_file }}
    {%- if cert.all_file is defined %}
    - watch_in:
      - cmd: salt_minion_cert_{{ cert_name }}_all
    {%- endif %}

{{ ca_file }}_cert_permissions_{{ rowloop.index }}:
  file.managed:
    - name: {{ ca_file }}
    - mode: 0644
    - watch:
      - x509: {{ ca_file }}

{%- endif %}

{%- endfor %}

{%- if cert.all_file is defined %}
salt_minion_cert_{{ cert_name }}_all:
  cmd.wait:
    - name: cat {{ key_file }} {{ cert_file }} {{ ca_file }} > {{ cert.all_file }}
    - watch:
      - x509: {{ key_file }}
      - x509: {{ cert_file }}

{{ cert.all_file }}_cert_permissions:
  file.managed:
    - name: {{ cert.all_file }}
    - mode: {{ cert.get("mode", 0600) }}
    {%- if salt['user.info'](cert.get("user", "root")) %}
    - user: {{ cert.get("user", "root") }}
    {%- endif %}
    {%- if salt['group.info'](cert.get("group", "root")) %}
    - group: {{ cert.get("group", "root") }}
    {%- endif %}
    - replace: false
    - watch:
      - cmd: salt_minion_cert_{{ cert_name }}_all
{%- endif %}

{%- endfor %}

{%- endif %}
