{% macro get_index(list_if_items, find_item) %}

  {%- for item in list_if_items %}
  {%- if item == find_item %}
        {{ return(loop.index) }}
  {% endif%}
  {% endfor %}

{% endmacro %}


{% materialization table_partitions, adapter='bigquery' -%}

  {%- set dataset_name = config.get('schema', none) -%}
  {%- set table_name = config.get('table', default=model['alias']) -%}
  {%- set write_method = config.get('write', default='WRITE_TRUNCATE') -%}

  {%- set raw_partition_by = config.get('partition_by', none) -%}
  {%- set partition_by = adapter.parse_partition_by(raw_partition_by) -%}

  {%- set cluster_by = config.get('cluster_by', none) -%}

  {%- set update_range = config.get('selector_update_range', default={}) -%}
  {%- set default_start_date = config.get('default_start_date', none) -%}
  {%- set min_start_date = config.get('min_start_date', none) -%}

  {%- set existing = adapter.get_relation(database=database, schema=dataset_name, identifier=table_name) %}
  {%- set target_relation = api.Relation.create(database=database, schema=dataset_name, identifier=table_name, type='table') -%}


  {%- set run_index = get_index(selected_resources , model.unique_id) %}
  {% set job_id = invocation_id ~ '_' ~ run_index %}
  {{ print("Running with job_id : " ~ job_id ~ ", " ) }}


  {%- if default_start_date is not none %}
        {%- set start_date = modules.datetime.datetime.strptime(default_start_date, '%Y-%m-%d').date() %}

  {%- elif var("start_date") == '@start_date' %}
        {%- set update_range_start = update_range.get(var("run_tags"), 0) %}
        {%- set start_date = modules.datetime.date.today()-modules.datetime.timedelta(days=update_range_start) %}

  {%- else %}
        {%- set start_date = modules.datetime.datetime.strptime(var("start_date"), '%Y-%m-%d').date() %}
  {%- endif %}

  {%- if min_start_date is not none and start_date < modules.datetime.datetime.strptime(min_start_date, '%Y-%m-%d').date() %}
        {%- set start_date = modules.datetime.datetime.strptime(min_start_date, '%Y-%m-%d').date() %}
   {%- endif %}


  {%- if var("end_date") == '@end_date' %}
        {%- set end_date =modules.datetime.date.today() %}
  {%- else %}
        {%- set end_date = modules.datetime.datetime.strptime(var("end_date"), '%Y-%m-%d').date() %}
  {%- endif %}

  {%- if min_start_date is not none and end_date < modules.datetime.datetime.strptime(min_start_date, '%Y-%m-%d').date() %}
        {%- set end_date = modules.datetime.datetime.strptime(min_start_date, '%Y-%m-%d').date() %}
  {%- endif %}


   {{ run_hooks(pre_hooks) }}

   {%- set response = (adapter.run_query(query=sql,
                                         dataset_name=dataset_name,
                                         table_name=table_name,
                                         write=write_method,
                                         partition_by=partition_by,
                                         clusters=cluster_by,
                                         start_date=start_date, end_date=end_date,
                                         dry_run=var("dry_run"),
                                         job_id=job_id
                                         )) %}

  {{ run_hooks(post_hooks) }}

   {{(adapter.update_table_description(database=database,
                                       schema=dataset_name, identifier=table_name,
                                       description=model.description
                                       )
    )}}

  {% do persist_docs(target_relation, model) %}


  {{ store_result('main', response=response) }}


  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}


