{% macro normalize_name(column) %}
    trim(regexp_replace(
        lower(regexp_replace(unaccent('unaccent', trim({{ column }})), '[^a-zA-Z0-9 ]', ' ', 'g')),
        '\s+', ' ', 'g'))
{% endmacro %}