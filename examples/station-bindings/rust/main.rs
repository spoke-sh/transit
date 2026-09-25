use serde_json::json;
use transit_station::{GenServer, Value};

fn unhex(text: &str) -> Vec<u8> {
    assert!(text.len() % 2 == 0);
    text.as_bytes()
        .chunks_exact(2)
        .map(|chunk| u8::from_str_radix(std::str::from_utf8(chunk).unwrap(), 16).unwrap())
        .collect()
}
fn worker() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args: Vec<_> = std::env::args().collect();
    let config: Value = serde_json::from_str(&std::fs::read_to_string(&args[1])?)?;
    let text = std::fs::read_to_string(config["seed_file"].as_str().unwrap())?;
    let mut seed: [u8; 32] = unhex(text.trim()).try_into().unwrap();
    let mut server = GenServer::new(config["url"].as_str().unwrap(), &seed, &config["server"])?;
    seed.fill(0);
    let peer: u64 = args[3].parse()?;
    loop {
        let deadline = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_millis() as u64
            + 30000;
        let event = server.next(deadline)?;
        let state = event["event"].as_str().unwrap();
        if state == "committed" {
            return Ok(());
        }
        assert!(state != "idle" && state != "blocked");
        if state != "ready" {
            continue;
        }
        if event["initializing"] == true {
            server.apply(&json!({"table_create":{"id":1,"key_name":"id","value_name":"value","value_type":"int64"}}))?;
            if args[2] == "service" {
                server.apply(&json!({"query_policy":{"peer":peer,"table":1,"expected_revision":0,"allow":true}}))?;
                server.apply(&json!({"table_write":{"id":1,"mode":"insert","row":{"key":"1","value":{"int64":"9007199254740993"}}}}))?;
            }
        }
        let input = &event["input"];
        if input["payload"] == "696e6974" {
        } else {
            match input["kind"].as_str().unwrap() {
                "cast" => {
                    server.apply(&json!({"call":{"pid":peer,"value":"7175657279"}}))?;
                }
                "call" => {
                    server.apply(&json!({"query_reply":{"id":1}}))?;
                }
                "result_complete" => {
                    let result = server.apply(&json!({"query_result":input["correlation"]}))?;
                    let ipc = unhex(result["arrow"].as_str().unwrap());
                    let cell = transit_station::arrow_cell(&ipc, 0, 1)?;
                    assert_eq!(cell["value"]["int64"], "9007199254740993");
                    server.apply(&json!({"put":{"key":"6f62736572766564","value":"39303037313939323534373430393933"}}))?;
                }
                _ => panic!("Unexpected Station input"),
            }
        }
        server.finish(false)?;
    }
}
fn main() {
    // Native work runs on an owned worker, never an async executor thread.
    // Errors/panics drop the handle without acknowledging the current input.
    transit_station::spawn(worker)
        .unwrap()
        .join()
        .unwrap()
        .unwrap();
}
