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
         "message": "127.0.0.1 - - [30/Jul/2006:24:59:59 +0000] "GET / HTTP/1.1" 200 195 "-" "ELB-HealthChecker/2.0""
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
import re

STATUS_OK: str = 'Ok'
DROPPED: str = 'Dropped'
FAILED: str = 'ProcessingFailed'

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class DataTransformation:
    def __init__(self, records: list) -> None:
        logger.info('Start Kinesis Firehose data transformation.')
        self.records: list = records
        self.pattern: str = r"(?P<ip>[\d.]+) (\S+) (\S+) \[(?P<date>[\w:/]+\s[\+\-]\d{4})\] \"(?P<method>[A-Z.]+) (?P<path>\S+) (\S+)\" (?P<status>[\d.]+) (\S+) \"(?P<from>\w.|\S+)\" \"(?P<user_agent>\w.+)\""
        self.output: list = []
        self.fields: list = [
            'ip',
            'date',
            'method',
            'path',
            'status',
            'from',
            'user_agent'
        ]

    def process(self) -> list:
        for record in self.records:
            record_id: int = record.get('recordId', None)
            payload: dict = self.__decompress(record.get('data', None))
            logger.info(f'Payload to be transform: {payload}')

            message_type: str = payload.get('messageType', None)

            if message_type == 'CONTROL_MESSAGE':
                output_record = {'recordId': record_id, 'result': DROPPED}
                self.output.append(output_record)
            elif message_type == 'DATA_MESSAGE':
                for data, result in self.__transformation(payload):
                    logger.info(f'Payload after transformation: {data}')
                    output_record = {
                        'recordId': record_id,
                        'result': result,
                        'data': self.__compress(data)
                    }
                    self.output.append(output_record)
            else:
                output_record = {'recordId': record_id, 'result': FAILED}
                self.output.append(output_record)

        logger.info(f'Data after finish transformation: {self.output}')
        return self.output

    def __compress(self, data) -> str:
        return b64.b64encode(json.dumps(data).encode('UTF-8')).decode('UTF-8')
    
    def __decompress(self, data) -> dict:
        return json.loads(gzip.decompress(b64.b64decode(data)))
    
    def __transformation(self, payload: dict) -> [dict, str]:
        data = None

        for event in payload.pop('logEvents', None):
            message = event.pop('message', None)
            matches = re.search(self.pattern, message)

            if matches and 'HealthChecker' not in matches.group('user_agent'):
                data = {field: matches.group(field) for field in self.fields}
                result = STATUS_OK
            elif 'HealthChecker' in matches.group('user_agent'):
                logger.info('Dropped HealthChecker log message')
                result = DROPPED
            else:
                logger.info(
                    "[ERROR] The log message doesn't match with "
                    "the regex pattern"
                )
                result = FAILED

            yield [data, result]


def lambda_handler(event, context) -> dict:
    output = DataTransformation(event.get('records', None)).process()
    return dict(records=output)
