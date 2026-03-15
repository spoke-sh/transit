import sys
import os
import time
from training.sparring_tapes import SparringTape

def main():
    tape = SparringTape("dojo.sparring.proof")
    
    print("\n[Dojo] Recording agent execution...")
    tape.record_execution(
        agent_id="agent-007",
        plan="implement-consensus-fencing",
        execution_delta="added-ownership-proof-field"
    )
    
    print("[Dojo] Simulation: Agent working autonomously...")
    time.sleep(1)
    
    print("[Dojo] Recording user intent (alignment merge)...")
    tape.record_intent(
        user_id="player-one",
        verification_status="accepted",
        feedback="fencing logic is sound, proceed to manager"
    )
    
    print("\n[Dojo] Sparring Tape recorded successfully in Transit!")
    drift = tape.get_drift_vector()
    print(f"[Dojo] Current Drift Vector: {drift}")

if __name__ == "__main__":
    main()
