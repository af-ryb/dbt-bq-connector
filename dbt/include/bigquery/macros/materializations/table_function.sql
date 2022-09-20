{% materialization table_func, adapter='bigquery' -%}


  {%- set dataset_name = config.get('schema', none) -%}
  {%- set table_name = config.get('table', default=model['alias']) -%}

  {%- set func_arguments = config.require('arguments') -%}

  {%- set target_relation = api.Relation.create(database=database, schema=dataset_name, identifier=table_name, type='view') -%}


   {%- set response = (adapter.create_table_func(query=sql,
                                                 dataset_name=dataset_name,
                                                 table_name=table_name,
                                                 arguments=func_arguments,

                                                 )) %}

  {{ store_result('main', response=response) }}



  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}


