import json
import socket
import uuid

class TransitClient:
    def __init__(self, host="127.0.0.1", port=7171):
        self.host = host
        self.port = port

    def _send_request(self, operation):
        request_id = str(uuid.uuid4())
        request = {
            "request_id": request_id,
            "operation": operation
        }
        
        payload = json.dumps(request).encode("utf-8") + b"\n"
        
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.host, self.port))
            s.sendall(payload)
            s.shutdown(socket.SHUT_WR)
            
            response_data = b""
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    break
                response_data += chunk
                
        response = json.loads(response_data.decode("utf-8").strip())
        
        if response["request_id"] != request_id:
            raise Exception(f"Request ID mismatch: expected {request_id}, got {response['request_id']}")
            
        envelope = response["envelope"]
        if envelope["kind"] == "error":
            error = envelope["error"]
            raise Exception(f"Remote error ({error['code']}): {error['message']}")
            
        return envelope["ack"], envelope["outcome"]

    def append(self, stream_id, payload):
        if isinstance(payload, str):
            payload = payload.encode("utf-8")
            
        op = {
            "type": "append",
            "stream_id": stream_id,
            "payload": list(payload)
        }
        
        return self._send_request(op)

    def create_root(self, stream_id, actor=None, reason=None):
        op = {
            "type": "create_root",
            "stream_id": stream_id,
            "metadata": {
                "actor": actor,
                "reason": reason,
                "labels": {}
            }
        }
        return self._send_request(op)

    def read(self, stream_id):
        op = {
            "type": "read",
            "stream_id": stream_id
        }
        return self._send_request(op)

    def tail(self, stream_id, from_offset=0):
        op = {
            "type": "tail",
            "stream_id": stream_id,
            "from_offset": from_offset
        }
        return self._send_request(op)

    def create_branch(self, stream_id, parent_stream_id, parent_offset, actor=None, reason=None):
        op = {
            "type": "create_branch",
            "stream_id": stream_id,
            "parent": {
                "stream_id": parent_stream_id,
                "offset": parent_offset
            },
            "metadata": {
                "actor": actor,
                "reason": reason,
                "labels": {}
            }
        }
        return self._send_request(op)

    def create_merge(self, stream_id, parents):
        # parents is a list of {"stream_id": str, "offset": int}
        op = {
            "type": "create_merge",
            "stream_id": stream_id,
            "merge": {
                "parents": parents
            }
        }
        return self._send_request(op)
