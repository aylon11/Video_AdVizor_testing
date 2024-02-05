from utils.storage import BucketHandler
from utils.bq import BigQueryTableInteractor
from utils.video_intelligence import VideoObjectDetection
import logging

_BUCKET_NAME = 'videos_export'
_DATASET = 'video_data'
_TABLE = 'video_annotations'
_VIDEO_METADATA_FILE = 'videos.csv'
_LENGTH_MS_CAP = 250000

logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s:%(levelname)s:%(message)s')


def get_video_id_lists(bq_interactor, videos_df ):
    """
    Retrieves lists of video IDs that exist and do not exist in the BigQuery table.

    :param bq_interactor: An instance of BigQueryTableInteractor.
    :return: A tuple of two lists (exist_list, not_exist_list)
    """

    # Get all video IDs as a list
    video_ids = videos_df['Video ID'].tolist()

    # Construct and run a single query to check all IDs
    formatted_ids = "', '".join(video_ids)
    query = f"""
    SELECT DISTINCT(video_id)
    FROM `{bq_interactor.dataset_id}.{bq_interactor.table_id}`
    WHERE video_id IN ('{formatted_ids}')
    """
    result = bq_interactor.query_table(query)

    # Extract existing IDs from the query result
    exist_list = [row['video_id'] for row in result]

    # Determine which IDs do not exist
    not_exist_list = [vid for vid in video_ids if vid not in exist_list]

    return exist_list, not_exist_list


def process_and_store_video_annotations(bq_interactor, video_id, video_name):
    # Initialize the VideoObjectDetection
    video_detector = VideoObjectDetection(_BUCKET_NAME, video_name)
    video_detector.analyze_video()
    objects_by_second = video_detector.get_objects_by_second()

    # Prepare data for insertion
    rows_to_insert = []
    for second, objects in objects_by_second.items():
        for (obj_name, entity_id), confidence in objects.items():
            row = {
                "video_id": video_id,
                "video_name": video_name,
                "timestamp_seconds": second,
                "annotations": {"object_name": obj_name, "entity_id": entity_id, "confidence": confidence}
            }
            rows_to_insert.append(row)

    # Insert data into BigQuery
    bq_interactor.insert_rows(rows_to_insert)  # Assuming there is a method like 'insert_rows'


def main():
    # Init handlers
    bucket = BucketHandler(_BUCKET_NAME)
    bq_interactor = BigQueryTableInteractor(_DATASET, _TABLE)

    # List and sort videos
    videos_df = bucket.read_csv(_VIDEO_METADATA_FILE)
    logging.info("Videos metadata file read")

    exist_list, not_exist_list = get_video_id_lists(bq_interactor, videos_df)
    logging.info(
        f"Got exisiting and non-existing video lists. Existing length: {str(len(exist_list))}  Non-exising length: {str(len(not_exist_list))}")
    
    columns_to_select = ['Video ID',
                         'Video Title (Original)', 'Approx Duration (ms)']
    videos_to_process_df = videos_df[videos_df['Video ID'].isin(not_exist_list)][columns_to_select]

    # Process videos
    videos_processed = []
    videos_skipped= []
    for row in videos_to_process_df.itertuples():
        if row._3 <= _LENGTH_MS_CAP:
            try:
                process_and_store_video_annotations(bq_interactor, row._1, row._2 + '.mp4')
                videos_processed.append(row._1)
                logging.info(f"Processed video with ID {row._1} and name {row._2}")
            except Exception as e:
                videos_skipped.append(row._1)
                logging.error(f"Failed to process video with ID {row._1} and name {row._2} due to error {str(e)}")
        else:
            videos_skipped.append(row._1)
            logging.error(f"Did not process video with ID {row._1} and name {row._2} due to length")


    logging.info(f'Videos Processed: {str(videos_processed)}')
    logging.info(f'Videos Already Existed: {str(exist_list)}')
    logging.info(f'Videos Skipped: {str(videos_skipped)}')

    # Clean Bucket
    logging.info('Cleaning Bucket..')
    # bucket.delete_all_blobs()

if __name__ == "__main__":
    main()
