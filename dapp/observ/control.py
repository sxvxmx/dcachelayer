import requests
from requests.auth import HTTPBasicAuth
from models import Session, File
import logging

# Configure logging
logger = logging.getLogger(__name__)

# WebDAV endpoints and authentication
WEBDAV_URLS = {
    'storage-1': 'http://10.220.18.166:30003/data/pool-a/',
    'storage-2': 'http://159.93.44.118:30003/data/pool-a/',
}

WEBDAV_AUTH = {
    'storage-1': HTTPBasicAuth('admin', '123'),
    'storage-2': HTTPBasicAuth('admin', '123'),
}

def upload_file(file_stream, file_path, target_storage='storage-1'):
    """Upload a file to the specified storage using WebDAV."""
    session = Session()
    try:
        if target_storage not in WEBDAV_URLS:
            raise ValueError("Invalid target storage")
        dest_url = WEBDAV_URLS[target_storage] + file_path

        # Upload file using WebDAV PUT
        response = requests.put(dest_url, data=file_stream, )
        response.raise_for_status()

        # Store metadata in the database
        file_size = file_stream.tell()  
        new_file = File(path=file_path, storage=target_storage, size=file_size)
        session.add(new_file)
        session.commit()
        return new_file.id
    except Exception as e:
        session.rollback()
        logger.error(f"Upload failed: {str(e)}")
        raise
    finally:
        session.close()

def move_file(file_id, target_storage):
    """Move a file between storage-1 and storage-2 using WebDAV."""
    session = Session()
    try:
        # Retrieve file metadata
        file = session.query(File).filter_by(id=file_id).first()
        if not file:
            raise ValueError("File not found")
        if file.storage == target_storage:
            raise ValueError("File is already in the target storage")
        if target_storage not in WEBDAV_URLS:
            raise ValueError("Invalid target storage")

        source_url = WEBDAV_URLS[file.storage] + file.path
        dest_url = WEBDAV_URLS[target_storage] + file.path

        # Download from source using WebDAV
        response = requests.get(source_url, auth=WEBDAV_AUTH[file.storage], stream=True)
        response.raise_for_status()
        upload_response = requests.put(dest_url, data=response.iter_content(chunk_size=8192), 
                                      auth=WEBDAV_AUTH[target_storage])
        upload_response.raise_for_status()
        delete_response = requests.delete(source_url, auth=WEBDAV_AUTH[file.storage])
        delete_response.raise_for_status()

        # Update metadata
        file.storage = target_storage
        session.commit()
        return file.path
    except Exception as e:
        session.rollback()
        logger.error(f"Move failed: {str(e)}")
        raise
    finally:
        session.close()