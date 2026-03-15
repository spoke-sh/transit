import sys
import os
from transit.client import TransitClient

def main():
    client = TransitClient()
    
    # 1. Create Root
    stream_id = "python.root"
    print(f"\n[1] Creating root stream: {stream_id}")
    ack, status = client.create_root(stream_id, actor="python-client", reason="multi-op proof")
    print(f"Status: {status}")
    
    # 2. Append
    print(f"\n[2] Appending records to: {stream_id}")
    client.append(stream_id, "record 1")
    client.append(stream_id, "record 2")
    print("Appended 2 records.")
    
    # 3. Read
    print(f"\n[3] Reading stream: {stream_id}")
    ack, outcome = client.read(stream_id)
    print(f"Read {len(outcome['records'])} records.")
    for r in outcome["records"]:
        payload = bytes(r["payload"]).decode("utf-8")
        print(f"  @{r['position']['offset']}: {payload}")
        
    # 4. Branch
    branch_id = "python.branch"
    print(f"\n[4] Creating branch: {branch_id} from {stream_id}@0")
    client.create_branch(branch_id, stream_id, 0, actor="python-client", reason="branching proof")
    
    # 5. Append to branch
    print(f"[5] Appending to branch: {branch_id}")
    client.append(branch_id, "branch record")
    
    # 6. Read branch
    print(f"\n[6] Reading branch: {branch_id}")
    ack, outcome = client.read(branch_id)
    print(f"Read {len(outcome['records'])} records.")
    for r in outcome["records"]:
        payload = bytes(r["payload"]).decode("utf-8")
        print(f"  @{r['position']['offset']}: {payload}")

    print("\nSDK Proof successful!")

if __name__ == "__main__":
    main()
