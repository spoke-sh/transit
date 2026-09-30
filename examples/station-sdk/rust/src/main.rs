use serde_json::{Value, json};
use std::{fs, path::Path, thread, time::Duration};
use transit_client::{ClientConfig, Error, ErrorKind, ProcessRef, Result};
use transit_sdk_examples::{
    Counter, Requester,
    codecs::{CounterCodec, RequesterCodec},
};
use transit_station_sdk::{
    Activation, FailurePolicy, Recovery, Runner, RunnerEvent, RunnerOptions, ServiceConfig,
};

fn invalid() -> Error {
    Error::new(ErrorKind::InvalidArgument, "example-configuration")
}
fn configuration(path: &Path) -> Result<(ServiceConfig, ProcessRef)> {
    let bytes = fs::read(path).map_err(|_| invalid())?;
    let value: Value = serde_json::from_slice(&bytes).map_err(|_| invalid())?;
    let n = |name| value[name].as_u64().ok_or_else(invalid);
    let s = |name| value[name].as_str().ok_or_else(invalid);
    if s("profile")? != "native_v1" {
        return Err(invalid());
    }
    let process = ProcessRef::new(n("realm")?, n("pid")?)?;
    let activation = Activation::new(process, n("principal")?, n("generation")?, s("seed_file")?)?;
    Ok((
        ServiceConfig::new(ClientConfig::growing(s("url")?)?, activation),
        ProcessRef::new(n("realm")?, n("peer")?)?,
    ))
}
fn consume<M: 'static>(
    mut runner: Runner<M>,
    mut remaining: u64,
) -> std::result::Result<(), Box<dyn std::error::Error>> {
    loop {
        match runner.next()? {
            Some(RunnerEvent::Committed { input, receipt }) => {
                println!(
                    "{}",
                    json!({"input":input.get(),"committed":receipt.position.get()})
                );
                remaining -= 1;
                if remaining == 0 {
                    break;
                }
            }
            Some(RunnerEvent::Progress) => {}
            Some(RunnerEvent::Idle) => thread::sleep(Duration::from_millis(20)),
            _ => return Err(Error::new(ErrorKind::Handler, "runner-stopped").into()),
        }
    }
    runner.close()?;
    Ok(())
}
fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 3 && args.len() != 5 {
        return Err(invalid().into());
    }
    let count = if args.len() == 5 {
        if args[3] != "--commits" {
            return Err(invalid().into());
        }
        args[4].parse::<u64>()?
    } else {
        1
    };
    if count == 0 {
        return Err(invalid().into());
    }
    let (config, peer) = configuration(Path::new(&args[1]))?;
    let options = RunnerOptions {
        failure: FailurePolicy::Stop,
        recovery: Recovery::FenceOnRestart,
    };
    match args[2].as_str() {
        "service" => consume(Runner::open(config, Counter, CounterCodec, options)?, count),
        "requester" => consume(
            Runner::open(config, Requester { counter: peer }, RequesterCodec, options)?,
            count,
        ),
        _ => Err(invalid().into()),
    }
}
