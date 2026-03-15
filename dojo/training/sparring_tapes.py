import json
import time
from transit.client import TransitClient

class SparringTape:
    def __init__(self, stream_id, host="127.0.0.1", port=7171):
        self.client = TransitClient(host, port)
        self.stream_id = stream_id
        self._ensure_stream()

    def _ensure_stream(self):
        try:
            self.client.create_root(self.stream_id, actor="dojo", reason="sparring tape initialization")
        except Exception as e:
            # Assume already exists
            pass

    def record_execution(self, agent_id, plan, execution_delta):
        event = {
            "type": "execution",
            "agent_id": agent_id,
            "plan": plan,
            "delta": execution_delta,
            "timestamp": time.time()
        }
        return self.client.append(self.stream_id, json.dumps(event))

    def record_intent(self, user_id, verification_status, feedback):
        event = {
            "type": "intent",
            "user_id": user_id,
            "status": verification_status, # "accepted", "rejected", "drifted"
            "feedback": feedback,
            "timestamp": time.time()
        }
        return self.client.append(self.stream_id, json.dumps(event))

    def get_drift_vector(self):
        # In a real impl, this would analyze the log
        # For now, it's a placeholder for dojo training
        return {"magnitude": 0.0, "direction": "aligned"}
