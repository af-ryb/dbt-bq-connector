import requests
from datetime import date, datetime, timedelta
from dataclasses import dataclass
from pandas import date_range
from dateutil.relativedelta import relativedelta

from google.cloud.bigquery.job import QueryJobConfig
from google.cloud.bigquery.table import TimePartitioning
from google.cloud.bigquery.query import ScalarQueryParameter

from os import environ
from dotenv import load_dotenv

from dbt.dataclass_schema import dbtClassMixin
from dbt.events import AdapterLogger

logger = AdapterLogger("BigQuery")

load_dotenv()

DBT_URL = environ.get('DBT_URL', '')
HEADERS = {'access_token': environ.get('API_KEY')}


@dataclass
class PartitionsModelResp(dbtClassMixin):
    unique_id: str
    job_id: str
    status: str
    start_date: date
    end_date: date
    total_gb_billed: float = None
    estimated_gb_processed: float = None
    dry_run: bool = False
    success: bool = None
    error: str = None
    started: datetime | None = None
    ended: datetime | None = None


def list_intersection(lst1, lst2):
    lst = [value for value in lst1 if value in lst2]
    return lst


def get_relative_start(interval):
    start = date.today()
    if str(interval).endswith('m'):
        start = (date.today() + relativedelta(months=-int(str(interval).replace('m', '')))).replace(day=1)
    elif str(interval).endswith('w'):
        start = (date.today() + relativedelta(weeks=-int(str(interval).replace('w', ''))))
    else:
        try:
            if int(interval):
                start = date.today() - timedelta(days=interval)
        except ValueError:
            pass
    return start


def make_date_range(start_date: date, end_date: date, freq: str):
    return date_range(start_date.replace(day=1) if freq == 'MS' else start_date,
                      end_date, freq=freq).to_list()


def build_query_config(project_id, dataset_name, table_name, write,
                       partitions_field, partitions_type, clusters,
                       start_date, end_date, dry_run):

    job_data = QueryJobConfig()
    job_data.write_disposition = write
    job_data.destination = f'{project_id}.{dataset_name}.{table_name}'
    job_data.dry_run = dry_run

    if partitions_field:
        job_data.time_partitioning = TimePartitioning(type_=partitions_type, field=partitions_field)

        if start_date and end_date:
            job_data.query_parameters = [
                ScalarQueryParameter(type_='DATE', name='start_date', value=format(start_date)),
                ScalarQueryParameter(type_='DATE', name='end_date', value=format(end_date)),
            ]

    if clusters:
        job_data.clustering_fields = clusters

    return job_data


def post_query_status(query_status: PartitionsModelResp):
    api_path = 'dbt/set_query_status'

    try:
        logger.debug(f'make post to {DBT_URL}{api_path}, with payload {PartitionsModelResp}')
        requests.post(url=f'{DBT_URL}{api_path}',
                      json=query_status.to_dict(),
                      headers=HEADERS
                      )
    except Exception as e:
        logger.error(f'got error {e}')
    return
