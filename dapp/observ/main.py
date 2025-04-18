from flask import Flask, request, jsonify
import control
import logging
from models import init_db
from models import Session, File

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize database
init_db()

@app.route('/upload', methods=['POST'])
def upload():
    """Endpoint to upload a file to storage-1."""
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    file_path = file.filename
    
    try:
        file_id = control.upload_file(file.stream, file_path, 'storage-1')
        return jsonify({"message": "File uploaded successfully", "file_id": file_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/move', methods=['POST'])
def move():
    """Endpoint to move a file between storages."""
    data = request.get_json()
    if not data or 'file_id' not in data or 'target_storage' not in data:
        return jsonify({"error": "Missing file_id or target_storage"}), 400
    
    file_id = data['file_id']
    target_storage = data['target_storage']
    
    try:
        file_path = control.move_file(file_id, target_storage)
        return jsonify({"message": "File moved successfully", "path": file_path}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
@app.route('/files', methods=['GET'])
def list_files():
    """Retrieve a list of all files with their metadata."""
    session = Session()
    try:
        files = session.query(File).order_by(File.upload_time.desc()).all()
        file_list = [
            {
                'id': file.id,
                'path': file.path,
                'storage': file.storage,
                'size': file.size,
                'upload_time': file.upload_time.isoformat() 
            }
            for file in files
        ]
        return jsonify(file_list), 200
    except Exception as e:
        logger.error(f"Error retrieving files: {str(e)}")
        return jsonify({"error": "Failed to retrieve files"}), 500
    finally:
        session.close()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=6000)