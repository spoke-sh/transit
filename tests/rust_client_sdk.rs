use serde_json::{Value, json};
use std::{fs, path::Path, sync::mpsc, thread, time::{Duration, Instant}};
use transit_client::{Client, ClientConfig, Credential, DispatchError, ErrorKind, ProcessRef, Sequence};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let arguments: Vec<_> = std::env::args().collect();
    let mode = arguments.get(1).unwrap();
    let cfg: Value = serde_json::from_slice(&fs::read(&arguments[2])?)?;
    let config = ClientConfig::growing(cfg["url"].as_str().unwrap())?.with_timeout(3000)?;
    let credential = Credential::new(72, 65536, cfg["seed"].as_str().unwrap())?;
    let peer = ProcessRef::new(72, cfg["pid"].as_u64().unwrap())?;
    assert!(ProcessRef::new(72, 0).is_err());
    assert!(ProcessRef::new(72, 1 << 53).is_err());
    assert!(Client::open(config.clone().with_native_directory("/missing-transit")).is_err());
    let pending_path = cfg["pending"].as_str().unwrap();
    if mode == "first" {
        let mut client = Client::open(config)?;
        let caps = client.capabilities(&credential)?;
        assert_eq!(caps.principal_sequence.get(), 0); assert_eq!(caps.page_size.get(), 8); assert!(caps.retained_versions);
        let mut value = b"wide".to_vec();
        let pending = client.prepare_send(peer, &value, &credential, Sequence::new(1)?)?;
        let frozen = pending.export(); value.fill(0);
        let mut copy = pending.export(); copy.fill(0);
        assert_eq!(pending.export(), frozen);
        fs::write(pending_path, &frozen)?;
        match client.dispatch(&pending) {
            Err(DispatchError::Uncertain { cause, recovery }) => { assert_eq!(cause.status, Some(6)); assert_eq!(recovery, frozen); },
            other => panic!("Expected uncertainty: {other:?}"),
        }
        drop(pending); client.close()?;
    } else if mode == "recover" {
        assert!(!Path::new(cfg["seed"].as_str().unwrap()).exists());
        let mut client = Client::open(config)?;
        let pending = client.recover_send(&fs::read(pending_path)?)?;
        let receipt = client.dispatch(&pending)?;
        assert_eq!(client.last_receipt(), Some(receipt));
        println!("{}", json!({"position": receipt.position.get()}));
        assert_eq!(client.dispatch(&pending)?, receipt);
        assert_eq!(client.recover_send(&fs::read(cfg["spawn"].as_str().unwrap())?).unwrap_err().kind, ErrorKind::UnsupportedCapability);
        let mut bad = vec![b' ']; bad.extend_from_slice(&pending.export()); assert!(client.recover_send(&bad).is_err());
        client.close()?;
    } else if mode == "async" {
        // The core Rust API is blocking. A controller can abandon its own receive
        // while the moved client remains owned by this task until explicit close.
        let mut client = Client::open(config)?;
        let pending = client.prepare_send(peer, b"async", &credential, Sequence::new(2)?)?;
        let bytes = pending.export();
        let (reply, receive) = mpsc::sync_channel(1);
        let worker = thread::spawn(move || {
            let result = client.dispatch(&pending).unwrap();
            let shutdown = client.close().unwrap();
            assert_eq!(shutdown.last_admission, Some(result));
            assert!(reply.send(result).is_err(), "The controller should already have abandoned its receive");
            result
        });
        let deadline = Instant::now() + Duration::from_secs(15);
        while !Path::new(cfg["accepted"].as_str().unwrap()).exists() { assert!(Instant::now() < deadline); thread::sleep(Duration::from_millis(5)); }
        drop(receive);
        let mut beats = 0;
        while !worker.is_finished() { beats += 1; thread::sleep(Duration::from_millis(10)); }
        let accepted = worker.join().unwrap(); assert!(beats > 5);
        let mut fresh = Client::open(ClientConfig::growing(cfg["url"].as_str().unwrap())?)?;
        let recovered = fresh.recover_send(&bytes)?;
        assert_eq!(fresh.dispatch(&recovered)?, accepted); fresh.close()?;
        println!("{}", json!({"scenario":"blocking-owner-disposal", "observations":{
            "controller_wait_abandoned":true, "responsive_during_join":beats>5, "owned_work_joined":true, "receipt_recovered":true}}));
    } else if mode == "denied" {
        let mut client = Client::open(config)?;
        let pending = client.recover_send(&fs::read(pending_path)?)?;
        match client.dispatch(&pending) { Err(DispatchError::Rejected(error)) => { assert_eq!(error.kind, ErrorKind::AccessDenied); assert_eq!(error.status, Some(4)); }, other => panic!("Expected revoked retry: {other:?}") }
        client.close()?;
    } else { panic!("Unknown mode"); }
    Ok(())
}
