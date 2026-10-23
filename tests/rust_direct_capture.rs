use serde_json::Value;
use std::{fs, os::unix::fs::PermissionsExt, path::Path};
use transit_client::{ClientConfig, Credential, ProcessRef, ResourceRef};
use transit_station_sdk::{catalog as c, logical as l, unified as q};
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
fn number(v: &Value, key: &str) -> u64 { v[key].as_u64().unwrap() }
fn wide(v: &Value, key: &str) -> u64 { v[key].as_str().unwrap().parse().unwrap() }
fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let profile_path = Path::new(&args[2]); let phase = &args[3];
    let root: Value = serde_json::from_slice(&fs::read(profile_path)?)?;
    let profile = &root["captured"]; let route = &profile["connection"];
    let realm = number(route,"realm"); let declaration = &profile["declaration"]["source"]["table"];
    let resource = ResourceRef::new(realm,number(&declaration["scope"],"resource"))?;
    let scope = c::Scope::new(resource,wide(&declaration["scope"],"catalog"))?;
    let connection = q::Connection::new(ProcessRef::new(realm,number(route,"source"))?,ResourceRef::new(realm,number(route,"resource"))?,
        ProcessRef::new(realm,number(route,"requester"))?,ResourceRef::new(realm,number(route,"requests"))?)?;
    assert_ne!(resource,connection.resource());
    let seed=profile_path.with_file_name("rust-capture.seed");
    fs::write(&seed,if phase=="prepare" { "1d" } else { "3b" }.repeat(32))?;
    fs::set_permissions(&seed,fs::Permissions::from_mode(0o600))?;
    let tables = q::Tables { url:args[1].clone(),scope,branch:wide(declaration,"branch"),audience:number(declaration,"owner") };
    let bundle = q::Bundle::from_bytes(fs::read(&args[4])?)?;
    let mut client=q::Client::open(ClientConfig::growing(&args[1])?.with_timeout(10000)?,Credential::new(realm,number(route,"principal"),seed)?,connection.clone(),Some(tables))?;
    if phase=="prepare" {
        assert!(client.lookup_table(1,"missing_capture_input")?.is_none());
        let definition=client.lookup_table(1,"captured_input")?.unwrap();let saved=&profile["capture"];
        assert_eq!(definition.partition,wide(&saved["expected"],"partition"));assert_eq!(definition.next_lsn,wide(&saved["expected"],"next_lsn"));
        let compiled=client.compile_sql(&definition.source,"captured_input","SELECT COUNT(*) AS n FROM captured_input",q::Budgets {pages:64,segments:64,result_bytes:1048576},None)?;
        assert_eq!(client.authorize_bundle(&compiled,Some(definition.capture(number(saved,"executor"),wide(saved,"operation"))?))?.data(),bundle.data());
    } else {
        assert!(client.lookup_table(1,"captured_input")?.is_none());
        let definition=client.lookup_table(1,"captured_renamed")?.unwrap();
        match definition.source { q::Source::Table { interpretation,schema,.. }=>{assert_eq!(interpretation.revision,2);assert_eq!(schema.revision,1);},_=>panic!("Wrong source") }
        let page=client.page(1,None)?;assert!(page.next.is_none());assert_eq!(page.rows,1);assert_eq!(page.manifest.resource,resource);
        assert!(matches!(page.manifest.source,q::Retention::Table(worker) if worker==connection.source()));assert!(matches!(page.manifest.cut,q::Cut::Table(_)));
        assert_eq!(page.manifest.pages,3);assert_eq!(page.manifest.scanned,19);
        assert_eq!(page.decode(None)?,vec![vec![l::Cell::Value(l::CellValue::Atom(l::Atom::Unsigned(19)))]]);
        assert!(!client.prepare_cleanup(1,&bundle)?.data().is_empty());
    }
    client.close()?;println!("Rust installed direct capture {phase}: public API passed");Ok(())
}
