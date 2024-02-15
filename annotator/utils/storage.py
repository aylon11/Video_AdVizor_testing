from google.cloud import storage
from google.cloud.storage import Blob
from typing import List
import pandas as pd
import os

class BucketHandler:
    def __init__(self, bucket_name: str):
        """
        Initializes the Google Cloud Storage Manager with the specified bucket.

        :param bucket_name: The name of the Google Cloud Storage bucket to interact with.
        """
        self.client = storage.Client()
        self.bucket = self.client.bucket(bucket_name)
    
    
    def list_blobs(self) -> List[Blob]:
        """
        Lists all blobs in the Google Cloud Storage bucket.

        :return: List of Blob objects.
        """
        return list(self.bucket.list_blobs())


    def delete_blob(self, blob_name: str):
        """
        Deletes a blob from the Google Cloud Storage bucket.

        :param blob_name: The name of the blob to delete.
        """
        blob = self.bucket.blob(blob_name)
        blob.delete()


    def delete_all_blobs(self):
        """
        Deletes all blobs from the Google Cloud Storage bucket.
        """
        blobs = self.list_blobs()
        for blob in blobs:
            self.delete_blob(blob.name)

    
    def read_csv(self, blob_name: str, temp_file_path: str = '/tmp/temp_csv.csv') -> pd.DataFrame:
        """
        Reads a CSV file from the Google Cloud Storage bucket into a pandas DataFrame.

        :param blob_name: The name of the CSV blob in the bucket.
        :param temp_file_path: Temporary local file path to store the CSV file. Defaults to '/tmp/temp_csv.csv'.
        :return: DataFrame containing the CSV data.
        """
        blob = self.bucket.blob(blob_name)
        blob.download_to_filename(temp_file_path)
        df = pd.read_csv(temp_file_path)
        os.remove(temp_file_path)  # Clean up the temporary file
        return df