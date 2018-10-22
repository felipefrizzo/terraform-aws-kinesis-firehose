"""
For processing data sent to Kinesis Firehose by CloudWatch logs subscription filter.

CloudWatch Logs sends to Firehose records that look like that:
{
   "messageType":"DATA_MESSAGE",
   "owner":"123456789012",
   "logGroup":"log_group_name",
   "logStream":"log_stream_name",
   "subscriptionFilters":[
      "subscription_filter_name"
   ],
   "logEvents":[
      {
         "id":"34347401063152187823588091447941432395582337638937001984",
         "timestamp":1540190731627,
         "message": "{"method":"GET", "path":"/example/12345", "format":"html", "action":"show", "status":200, "params":{ "user_id":"11111" }, "ip":"192.168.0.0", "@timestamp":"2018-10-22T06:45:31.428Z", "@version":"1", "message":"[200] GET /example/12345 (ExampleController#show)"}"
      },
      ...
   ]
}
"""
from __future__ import print_function

import base64 as b64
import gzip
import json
import logging

STATUS_OK: str = 'Ok'
DROPPED: str = 'Dropped'
FAILED: str = 'ProcessingFailed'

logger =  logging.getLogger()
logger.setLevel(logging.INFO)


class DataTransformation:
    def __init__(self, records: list) -> None:
        self.records = records
        self.output = []

    def process(self) -> list:
        for record in self.records:
            record_id: int = record.get('recordId', None)
            payload = self.__decompress(record.get('data', None))

            message_type: str = payload.get('messageType', None)

            if message_type == 'CONTROL_MESSAGE':
                output_record = {'recordId': record_id, 'result': DROPPED}
                self.output.append(output_record)
            elif message_type == 'DATA_MESSAGE':
                for data in self.__transformation(payload):
                    output_record = {
                        'recordId': record_id,
                        'result': STATUS_OK,
                        'data': self.__compress(data)
                    }
                    self.output.append(output_record)
            else:
                output_record = {'recordId': record_id, 'result': FAILED}
                self.output.append(output_record)

        return self.output

    def __compress(self, data):
        return b64.b64encode(json.dumps(data).encode('UTF-8')).decode('UTF-8')

    def __decompress(self, data):
        return json.loads(gzip.decompress(b64.b64decode(data)))

    def __transformation(self, payload: dict) -> dict:
        for event in payload.pop('logEvents', None):
            yield json.loads(event.pop('message', None))


def lambda_handler(event, context) -> dict:
    output = DataTransformation(event.get('records', None)).process()
    return dict(records=output)
