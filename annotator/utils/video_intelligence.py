from google.cloud import videointelligence
from collections import defaultdict

class VideoObjectDetection:
    def __init__(self, bucket_name, file_name):
        """
        Initialize the VideoObjectDetection class with the bucket name and file name.
        Constructs the video URI from the bucket and file names.
        """
        self.video_uri = f"gs://{bucket_name}/{file_name}"
        self.client = videointelligence.VideoIntelligenceServiceClient()
        self.objects_by_second = defaultdict(lambda: defaultdict(float))

    def analyze_video(self):
        """
        Analyzes the video to detect objects and their highest confidence scores.
        """
        request = {
            "input_uri": self.video_uri,
            "features": ["OBJECT_TRACKING"],
        }
        
        operation = self.client.annotate_video(request=request)
        result = operation.result(timeout=180)  # Adjust timeout as needed

        for annotation_result in result.annotation_results:
            for annotation in annotation_result.object_annotations:
                object_name = annotation.entity.description
                entity_id = annotation.entity.entity_id

                for frame in annotation.frames:
                    time_offset = frame.time_offset
                    total_seconds = time_offset.seconds + time_offset.microseconds / 1e6
                    rounded_second = round(total_seconds)
                    object_key = (object_name, entity_id)
                    current_confidence = self.objects_by_second[rounded_second][object_key]
                    self.objects_by_second[rounded_second][object_key] = max(annotation.confidence, current_confidence)

    def get_objects_by_second(self):
        """
        Returns a dictionary with the highest confidence score for each object per second.
        """
        return self.objects_by_second

# Usage example:
# video_detector = VideoObjectDetection("your-bucket", "your-video.mp4")
# video_detector.analyze_video()
# objects_by_second = video_detector.get_objects_by_second()
# for second, objects in sorted(objects_by_second.items()):
#     print(f"Second {second}:")
#     for (obj_name, entity_id), confidence in objects.items():
#         print(f"    Object Name: {obj_name}, Entity ID: {entity_id}, Highest Confidence: {confidence}")
