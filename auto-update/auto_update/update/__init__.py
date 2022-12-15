from flask import Blueprint, request
from flask.wrappers import Response
from os import getenv
from time import sleep
from filelock import FileLock
import logging


UPDATE_FRONTEND_TOKEN = getenv("UPDATE_FRONTEND_TOKEN", default=None)
UPDATE_BACKEND_TOKEN = getenv("UPDATE_BACKEND_TOKEN", default=None)
PADDING_TIME = int(getenv("PADDING_TIME", default=5))
MAX_RETRY_COUNT = int(getenv("MAX_RETRY_COUNT", default=100))

def check_token_env():
    if UPDATE_FRONTEND_TOKEN == None or UPDATE_BACKEND_TOKEN == None:
        raise ValueError("Environment updating token not found!")


check_token_env()


def do_update(which: str) -> str:
    def update_status(sta: str):
        open("/flag/status", "w+").write(sta)

    def status_is_empty() -> bool:
        return open("/flag/status").readline() == "empty"

    retry_count = 0
    # Try lock updating file
    while True:
        with FileLock("/flag/lock") as file_lock:
            retry_count += 1
            if status_is_empty():
                update_status(f"update {which}")
                break
            elif retry_count >= MAX_RETRY_COUNT:
                raise TimeoutError(
                    "Retry max count: {retry_count} locking {which}")
            else:
                file_lock.release()
                logging.warning("status file is locked.")
                sleep(PADDING_TIME)
                continue

    retry_count = 0
    # Waiting for "outside" worker returns the result
    while True:
        with FileLock("/flag/lock") as file_lock:
            retry_count += 1
            status = open("/flag/status").readline()
            if status.find("compelete"):
                update_status("empty")
                return status
            elif retry_count >= MAX_RETRY_COUNT:
                raise TimeoutError(
                    "Retry max count: {retry_count} waiting for {which} worker")
            else:
                file_lock.release()
                logging.warning(f"{status} is working.")
                sleep(PADDING_TIME)
                continue


Update = Blueprint('update', __name__)


@Update.route("/frontend", methods=['GET', 'POST'])
def frontend():
    if request.method == 'POST' and request.args.get('key', str) == UPDATE_BACKEND_TOKEN:
        try:
            return do_update("frontend")
        except Exception as e:
            return Response(e.__str__(), 500)
    else:
        return Response("Bad Request", 400)


@Update.route("/backend", methods=['GET', 'POST'])
def backend():
    if request.method == 'POST' and request.args.get('key', str) == UPDATE_BACKEND_TOKEN:
        try:
            return do_update("backend")
        except Exception as e:
            return Response(e.__str__(), 500)
    else:
        return Response("Bad Request", 400)
