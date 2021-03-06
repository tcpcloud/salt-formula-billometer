{%- from "billometer/map.jinja" import server with context %}
{%- set broker =  server.message_queue %}

import sys
import os

os.environ['DJANGO_SETTINGS_MODULE'] = 'billometer.settings'

from datetime import timedelta
from kombu import Queue, Exchange
from celery import Celery
import logging

logger = logging.getLogger("billometer.collector")

BROKER_URL = 'amqp://{{ broker.user }}:{{ broker.password }}@{{ broker.host }}:{{ broker.get('port', '5672') }}/{{ broker.virtual_host }}'

CELERY_IMPORTS = ("billometer.tasks")

CELERY_RESULT_BACKEND = "amqp"
CELERY_RESULT_EXCHANGE = 'results'
CELERY_RESULT_EXCHANGE_TYPE = 'fanout'
CELERY_TASK_RESULT_EXPIRES = 120

default_exchange = Exchange('default', type='fanout')

CELERY_ACCEPT_CONTENT = ['json', 'msgpack', 'yaml', 'application/x-python-serialize', ]

CELERY_REDIRECT_STDOUTS_LEVEL = "INFO"

CELERY_QUEUES = (
    Queue('default', default_exchange, routing_key='default'),
)

CELERY_DEFAULT_QUEUE = 'default'
CELERY_DEFAULT_EXCHANGE = 'default'
CELERY_DEFAULT_EXCHANGE_TYPE = 'topic'
CELERY_DEFAULT_ROUTING_KEY = 'default'

CELERY_TIMEZONE = 'UTC'

CELERYBEAT_SCHEDULE = {
    'sync_all': {
        'task': 'billometer.tasks.sync_all',
        'schedule': timedelta(seconds={{ server.get("sync_time", 60) }}),
        'args': tuple()
    },
    'collect_all': {
        'task': 'billometer.tasks.collect_all',
        'schedule': timedelta(seconds={{ server.get("collect_time", 120) }}),
        'args': tuple()
    },
    {%- if server.extra_resource is defined and ('network.rx' or 'network.tx') in server.extra_resource.keys() %}
    'sync_network': {
        'task': 'billometer.tasks.network.sync_network',
        'schedule': timedelta(seconds={{ server.get("sync_time", 60) }}),
        'args': tuple()
    },
    'collect_network': {
        'task': 'billometer.tasks.network.collect_network',
        'schedule': timedelta(seconds={{ server.get("collect_time", 120) }}),
        'args': tuple()
    },
    {%- endif %}
    'collect_price': {
        'task': 'billometer.tasks.collect_price',
        'schedule': timedelta(days=1),
        'args': tuple()
    },
    'backend_cleanup': {
        'task': 'billometer.tasks.backend_cleanup',
        'schedule': timedelta(days=3),
        'args': tuple()
    },
}

celery = Celery('collector', broker=BROKER_URL)

try:
    from billometer.utils.celery import register_signal
    from raven.contrib.django.raven_compat.models import client
    register_signal(client)
except Exception as e:
    logger.exception(str(e))
