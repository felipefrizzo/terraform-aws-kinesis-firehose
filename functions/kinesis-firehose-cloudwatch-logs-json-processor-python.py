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

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class DataTransformation:
    def __init__(self, records: list) -> None:
        logger.info('Start Kinesis Firehose data transformation.')
        self.records: list = records
        self.output: list = []

    def process(self) -> list:
        for record in self.records:
            record_id: int = record.get('recordId', None)
            payload: dict = self.__decompress(record.get('data', None))
            logger.info(f'Payload to be transform: {payload}')

            message_type: str = payload.get('messageType', None)

            if message_type == 'CONTROL_MESSAGE':
                output_record = {'recordId': record_id, 'result': DROPPED}
            elif message_type == 'DATA_MESSAGE':
                data = self.__transformation(payload)
                logger.info(f'Payload after transformation: {data}')
                output_record = {
                    'recordId': record_id,
                    'result': STATUS_OK,
                    'data': self.__compress(data)
                }
            else:
                output_record = {'recordId': record_id, 'result': FAILED}
            self.output.append(output_record)

        logger.info(f'Data after finish transformation: {self.output}')
        return self.output

    def __compress(self, data) -> str:
        return b64.b64encode(data.encode('UTF-8')).decode('UTF-8')

    def __decompress(self, data) -> dict:
        return json.loads(gzip.decompress(b64.b64decode(data)))

    def __transformation(self, payload: dict) -> str:
        record = '\r\n'.join(
            e.pop('message') for e in payload.pop('logEvents', None)
        )
        return record


def lambda_handler(event, context) -> dict:
    output = DataTransformation(event.get('records', None)).process()
    return dict(records=output)
