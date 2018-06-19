{%- macro initial_audit_partial(schema_key, entity_key, cdc_target, cast_target_as= False, incremental = True, entity_type = 'Table', database_key = 'RAW') -%}
/*  INTENT: gets the CDC range values for this audit, builds an 
    initial row without measures that we set to 'In Progress' status.

    ARGS:
        - schema_name (string) the raw source schema.
        - cdc_target (string) the name of the column that indicates a new or updated row.
        - cast_target_as (varchar default None) if not none, cast the target before comparison.
        - incremental (boolean default True) does the audit table already exist.
        - entity_key (string) the name of the source entity.
        - entity_type (string default 'Table') the type of source entity targeted.
        - database_name (string default 'RAW') the raw source database.
    RETURNS: string fully wrapped CTE named '<schema>_<table>_initial_audit'
*/

{{schema_key}}_{{entity_key}}_new_audit_record AS (      
    -- get the max value of the most recent audit if the audit table exists
    {%- if incremental -%}
    WITH
    {{schema_key}}_{{entity_key}}_audit_max AS (
        SELECT
            MAX(highest_cdc) as record_max
        FROM
           "{{target.database}}"."QUALITY"."AUDIT"
        WHERE
            database_key = "{{database_name}}"
        AND
            schema_key = "{{schema_key}}"
        AND
            entity_key = "{{entity_key}}"
        AND
            entity_type = "{{entity_type}}"
    ),

    {%- endif -%}

---- get min and max value of source for this audit
    {{schema_name}}_{{target_name}}_source_min_max AS (
        SELECT
            MIN({{cdc_target}}) AS lowest_cdc,
            MAX({{cdc_target}}) AS highest_cdc
        FROM
            "{{database_name}}"."{{schema_name}}"."{{entity_name}}"

    {%- if incremental -%}
        WHERE
            {%- if cast_target_as is not None -%}
                {{cdc_target}}::{{cast_target_as}} > (SELECT record_max::{{cast_target_as}}  FROM {{schema_name}}_{{target_name}}_audit_max LIMIT 1)
            {%- else -%}
                {{cdc_target}} > (SELECT record_max FROM {{schema_name}}_{{target_name}}_audit_max LIMIT 1)
            {%- endif -%}

    {%- endif -%}
    ),
    
    -- create the final partial    
    SELECT
        'In Process' AS audit_status,
        {{cdc_target}} as cdc_target,
        {{entity_type}} AS entity_type,
        {{entity_key}} AS entity_key,
        {{schema_key}} AS schema_key,
        {{database_key}} AS database_Key,
        'Not Available' AS dbt_version,
        'Not Available' AS dbt_repo_release_version,
        {{schema_key}}_{{entity_key}}_source_min_max.lowest_cdc,
        {{schema_key}}_{{entity_key}}_source_min_max.highest_cdc 

    FROM 
    
    {{schema_name}}_{{target_name}}_source_min_max 
)    