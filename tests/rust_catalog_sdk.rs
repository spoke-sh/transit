//! Installed Rust general Table lifecycle, owned values and exact saved recovery.
use serde_json::{Value, json};
use std::os::unix::fs::OpenOptionsExt;
use std::{
    fs,
    io::{self, BufRead, Write},
    path::Path,
    time::{Duration, Instant},
};
use transit_client::{ClientConfig, Credential, ProcessRef, ResourceRef, Result};
use transit_station_sdk::{catalog as m, logical as l};
fn text<'a>(v: &'a Value, key: &str) -> &'a str {
    v[key].as_str().unwrap()
}
fn number(v: &Value, key: &str) -> u64 {
    v[key].as_u64().unwrap()
}
fn connect(config: &Value) -> Result<m::Client> {
    let c = &config["connection"];
    let s = &c["scope"];
    let realm = number(s, "realm");
    let native = ClientConfig::growing(text(config, "url"))?.with_timeout(if config["table_service_url"].is_string() {30000} else {10000})?;
    let credential = Credential::new(realm, number(c, "principal"), text(config, "seed_file"))?;
    let mut connection = m::Connection::new(
        ProcessRef::new(realm, number(c, "owner"))?,
        m::Scope::new(
            ResourceRef::new(realm, number(s, "resource"))?,
            text(s, "catalog").parse().unwrap(),
        )?,
    )?;
    if let Some(role) = c["role"].as_u64() {
        connection = connection.with_role(role)?;
    }
    if let Some(namespace) = c["namespace"].as_u64() {
        connection = connection.with_namespace(namespace)?;
    }
    if let Some(service) = config["table_service_url"].as_str() {
        m::Client::open_mediated(native, credential, connection, service.into())
    } else {
        m::Client::open(native, credential, connection)
    }
}
fn persist(path: &Path, data: &[u8]) {
    let mut file = fs::OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .mode(0o600)
        .open(path)
        .unwrap();
    file.write_all(data).unwrap();
    file.sync_all().unwrap();
}
fn finish(client: &mut m::Client, compiled: m::Compiled, path: &Path) -> Result<m::Outcome> {
    persist(
        &path.join("intent.json"),
        &serde_json::to_vec(
            &json!({"definition":compiled.saved.definition(),"bytes":compiled.saved.bytes()}),
        )
        .unwrap(),
    );
    let reference = compiled.intent.reference;
    let deadline = Instant::now() + Duration::from_secs(120);
    loop {
        assert!(
            Instant::now() < deadline,
            "Table operation exceeded its budget"
        );
        match client.next(&reference)? {
            m::Next::Terminal(outcome) => return Ok(outcome),
            m::Next::Running => continue,
            m::Next::UploadCancelled => panic!("Unexpected upload cancellation"),
            m::Next::Send(prepared) => {
                persist(&path.join("step.json"), prepared.data().as_bytes());
                let position = client.submit(&prepared)?.position.get();
                persist(&path.join("receipt.json"), position.to_string().as_bytes());
                loop {
                    assert!(
                        Instant::now() < deadline,
                        "Table progress exceeded its budget"
                    );
                    match client.progress(&reference, &prepared, position, true)? {
                        m::Progress::Pending => continue,
                        m::Progress::Processed {
                            disposition,
                            outcome,
                            ..
                        } => {
                            assert!(disposition.is_none(), "{disposition:?}");
                            if let Some(outcome) = outcome {
                                if outcome.terminal {
                                    return Ok(outcome);
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}
fn atom(value: l::Atom) -> l::Cell {
    l::Cell::Value(l::CellValue::Atom(value))
}
fn assignment(column: u64, value: l::Cell) -> m::Assignment {
    m::Assignment {
        column,
        value: m::AssignmentValue::Cell(value),
    }
}
fn scenario(mut client: m::Client, config: &Value, path: &Path, index: u64) -> Result<Value> {
    let base = 1100 + index * 100;
    let original_object = 12001 + index * 10;
    let name = format!("sdk_people_{index}");
    let ids = |offset| m::Identity::new(base + offset, base + offset + 100000).unwrap();
    let description = client.describe()?;
    assert_eq!(description.configuration.scope, client.connection().scope());
    assert_eq!(
        description.subject.principal,
        number(&config["connection"], "principal")
    );
    let compiled=client.compile_sql(&format!("CREATE TABLE {name} (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))"),ids(0),Some(original_object))?;
    assert_eq!(
        finish(&mut client, compiled, path)?.phase,
        m::Phase::Applied
    );
    let original = client.lookup(&name)?.unwrap();
    assert_eq!(original.schema.columns.len(), 3);
    assert!(matches!(
        original.schema.columns[1].datatype,
        l::Descriptor::Structure(_)
    ));
    let payload = l::Cell::Value(l::CellValue::Structure(vec![
        atom(l::Atom::Binary(vec![0, 128, 255])),
        atom(l::Atom::Utf8("東京".into())),
    ]));
    let amount = atom(l::Atom::Decimal(123456789012345678901234567890));
    let insert = client.prepare(
        &name,
        ids(1),
        &m::Operation::Mutate {
            basis: original.metadata.basis(),
            mutation: m::Mutation::Insert {
                rows: vec![vec![
                    assignment(3, amount.clone()),
                    assignment(1, atom(l::Atom::Signed(1))),
                    assignment(2, payload),
                ]],
            },
        },
    )?;
    let saved = insert.saved.clone();
    let applied = finish(&mut client, insert, path)?;
    assert_eq!(
        applied.counts,
        Some(m::Counts {
            matched: 1,
            changed: 1
        })
    );
    let predicate = vec![m::Predicate::Compare {
        column: 1,
        op: m::CompareOperator::Eq,
        value: l::Atom::Signed(1),
    }];
    let update = client.prepare(
        &name,
        ids(2),
        &m::Operation::Mutate {
            basis: original.metadata.basis(),
            mutation: m::Mutation::Update {
                assignments: vec![assignment(3, amount)],
                predicate: Some(predicate.clone()),
            },
        },
    )?;
    assert_eq!(
        finish(&mut client, update, path)?.counts,
        Some(m::Counts {
            matched: 1,
            changed: 0
        })
    );
    let altered = client.prepare(
        &name,
        ids(3),
        &m::Operation::Alter {
            basis: original.metadata.basis(),
            change: m::Change::Add {
                name: "enabled".into(),
                datatype: l::Descriptor::Scalar(l::ScalarType::Boolean),
                nullable: false,
                default: Some(atom(l::Atom::Boolean(true))),
                max_characters: None,
            },
        },
    )?;
    assert_eq!(finish(&mut client, altered, path)?.phase, m::Phase::Applied);
    assert!(
        client
            .prepare(
                &name,
                ids(4),
                &m::Operation::Drop {
                    basis: Some(original.metadata.basis()),
                    if_exists: false
                }
            )
            .is_err()
    );
    let current = client.lookup(&name)?.unwrap();
    let deleted = client.prepare(
        &name,
        ids(5),
        &m::Operation::Mutate {
            basis: current.metadata.basis(),
            mutation: m::Mutation::Delete {
                predicate: Some(predicate),
            },
        },
    )?;
    assert_eq!(
        finish(&mut client, deleted, path)?.counts,
        Some(m::Counts {
            matched: 1,
            changed: 1
        })
    );
    let dropped = client.prepare(
        &name,
        ids(6),
        &m::Operation::Drop {
            basis: Some(current.metadata.basis()),
            if_exists: false,
        },
    )?;
    assert_eq!(finish(&mut client, dropped, path)?.phase, m::Phase::Applied);
    let replacement = client.compile_sql(
        &format!("CREATE TABLE {name} (replacement TEXT)"),
        ids(7),
        Some(original_object + 1),
    )?;
    assert_eq!(
        finish(&mut client, replacement, path)?.phase,
        m::Phase::Applied
    );
    client.close()?;
    let mut client = connect(config)?;
    let loaded = client.load(&m::SavedIntent::new(
        saved.definition().into(),
        saved.bytes().to_vec(),
    )?)?;
    assert_eq!(loaded.object, original_object);
    assert_eq!(client.status(&loaded.reference)?.outcome, Some(applied));
    assert_eq!(
        client.lookup(&name)?.unwrap().metadata.object,
        original_object + 1
    );
    let historical = client
        .definition(original_object, original.metadata.revision)?
        .unwrap();
    assert_eq!(historical.metadata, original.metadata);
    assert_eq!(historical.schema, original.schema);
    assert!(client.definition(original_object, 999)?.is_none());
    assert!(!client.list(None)?.entries.is_empty());
    client.close()?;
    Ok(
        json!({"profile":"installed-rust-general-table","original_object":original_object.to_string(),"replacement_object":(original_object+1).to_string(),"counts":{"matched":"1","changed":"1"}}),
    )
}
fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let path = std::env::args().nth(1).unwrap();
    let path = Path::new(&path);
    let config: Value = serde_json::from_slice(&fs::read(path)?)?;
    let mut client = Some(connect(&config)?);
    println!("{{\"ready\":true}}");
    io::stdout().flush()?;
    for line in io::stdin().lock().lines() {
        let action: Value = serde_json::from_str(&line?)?;
        if action.get("close").is_some() {
            break;
        }
        if action.get("denied").is_some() {
            let mut fresh = connect(&config)?;
            assert_eq!(fresh.describe().unwrap_err().status, Some(4));
            fresh.close()?;
            println!("{}", json!({"status":0,"value":{"denied":true}}));
            io::stdout().flush()?;
            continue;
        }
        let value = scenario(
            client.take().unwrap(),
            &config,
            path.parent().unwrap(),
            number(&action["scenario"], "index"),
        )?;
        println!("{}", json!({"status":0,"value":value}));
        io::stdout().flush()?;
    }
    if let Some(client) = client {
        client.close()?;
    }
    println!("{{\"closed\":true}}");
    Ok(())
}
