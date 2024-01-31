from google.cloud import bigquery
from typing import List, Dict, Any

class BigQueryTableInteractor:
    def __init__(self, dataset_id: str, table_id: str):
        """
        Initializes the BigQuery Table Interactor with the specified project, dataset, and table.

        :param project_id: The Google Cloud project ID.
        :param dataset_id: The dataset ID.
        :param table_id: The table ID.
        """
        self.client = bigquery.Client()
        self.dataset_id = dataset_id
        self.table_id = table_id
        self.table_ref = self.client.dataset(self.dataset_id).table(self.table_id)
        self.table = self.client.get_table(self.table_ref)

    def query_table(self, query: str) -> List[Dict[str, Any]]:
        """
        Executes a query against the BigQuery table and returns the results.

        :param query: The SQL query to execute.
        :return: A list of dictionaries representing the query results.
        """
        query_job = self.client.query(query)
        return [dict(row) for row in query_job.result()]

    def insert_rows(self, rows: List[Dict[str, Any]]):
        """
        Inserts rows into the BigQuery table.

        :param rows: A list of dictionaries, each representing a row to insert.
        """
        errors = self.client.insert_rows_json(self.table, rows)
        if errors:
            raise RuntimeError(f"Errors occurred while inserting rows: {errors}")
