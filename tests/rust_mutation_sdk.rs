use serde_json::{Value, json};
use std::{
    fs,
    io::{self, BufRead, Write},
};
use transit_client::{ClientConfig, Credential, ErrorKind, ProcessRef, ResourceRef};
use transit_station_sdk::mutations as m;
type AnyResult<T> = Result<T, Box<dyn std::error::Error>>;
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|v| format!("{v:02x}")).collect()
}
fn unhex(value: &str) -> Vec<u8> {
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|v| u8::from_str_radix(std::str::from_utf8(v).unwrap(), 16).unwrap())
        .collect()
}
fn text<'a>(value: &'a Value, key: &str) -> &'a str {
    value[key].as_str().unwrap()
}
fn number(value: &Value, key: &str) -> u64 {
    value[key].as_u64().unwrap()
}
fn reference(value: &str) -> m::Reference {
    m::Reference::from_data(unhex(value).try_into().unwrap())
}
fn tag(value: impl std::fmt::Debug) -> String {
    let mut result = String::new();
    for (index, c) in format!("{value:?}").chars().enumerate() {
        if index > 0 && c.is_uppercase() {
            result.push('_');
        }
        result.extend(c.to_lowercase());
    }
    result
}
fn call(client: &mut m::Client, action: &Value) -> transit_client::Result<Value> {
    Ok(if action.get("capabilities").is_some() {
        json!({"capabilities":{"version":1,"max_rows":3}})
    } else if action.get("describe").is_some() {
        let v = client.describe()?;
        json!({"description":{"resource":v.resource.resource(),"table":v.table,"names":v.names,"value_type":tag(v.value_type),
            "resource_revision":v.resource_revision,"policy_revision":v.policy_revision.to_string(),"declaration":hex(&v.declaration),
            "permissions":v.permissions.bits(),"active":v.active.map(|n|n.to_string())}})
    } else if let Some(v) = action.get("compile") {
        let v = client.compile_sql(
            text(v, "name"),
            text(v, "sql"),
            text(v, "namespace").parse().unwrap(),
        )?;
        json!({"compiled":{"request":hex(v.request()),"reference":hex(v.reference().data())}})
    } else if let Some(v) = action.get("next") {
        let compiled =
            m::Compiled::from_data(unhex(text(v, "request")), reference(text(v, "reference")))?;
        let saved = compiled.request().to_vec();
        let result = client.prepare_next(&compiled);
        assert_eq!(compiled.request(), saved);
        json!({"prepared":result?.as_ref().map(m::Prepared::data)})
    } else if let Some(v) = action.get("prepare") {
        let (kind, value) = v.as_object().unwrap().iter().next().unwrap();
        let r = reference(value.as_str().unwrap());
        let value = match kind.as_str() {
            "apply" => client.prepare_apply(&r)?,
            "cancel" => client.prepare_cancel(&r)?,
            _ => panic!("Unsupported control"),
        };
        json!({"prepared":value.data()})
    } else if let Some(v) = action.get("submit") {
        let prepared = m::Prepared::from_data(v.as_str().unwrap().to_owned())?;
        let saved = prepared.data().to_owned();
        let result = client.submit(&prepared);
        assert_eq!(prepared.data(), saved);
        json!({"receipt":{"position":result?.position.get()}})
    } else if let Some(v) = action.get("observe") {
        let prepared = m::Prepared::from_data(text(v, "prepared").to_owned())?;
        json!({"observation":tag(client.observe(&prepared,number(v,"input"))?)})
    } else if let Some(v) = action.get("rejection") {
        let prepared = m::Prepared::from_data(text(v, "prepared").to_owned())?;
        json!({"rejection":client.rejection(&prepared,number(v,"input"))?.map(|v|json!({"principal":v.principal,"input":v.input,"payload":hex(&v.payload),"reason":tag(v.reason),"diagnostic":v.diagnostic}))})
    } else if let Some(v) = action.get("status") {
        json!({"status":client.status(&reference(v.as_str().unwrap()))?.map(|v|json!({
            "reference":hex(v.reference.data()),"principal":v.principal,"table":v.table,"declaration":hex(&v.declaration),
            "policy_revision":v.policy_revision.to_string(),"phase":tag(v.phase),"affected_rows":v.affected_rows,"reason":tag(v.reason),"input":v.input,"diagnostic":v.diagnostic,"conflict":v.conflict.map(|c| json!({"key":c.key.to_string(),"row":c.row}))}))})
    } else {
        panic!("Unsupported test action")
    })
}
fn main() -> AnyResult<()> {
    let path = std::env::args().nth(1).unwrap();
    let config: Value = serde_json::from_slice(&fs::read(path)?)?;
    let c = &config["connection"];
    let connection = m::Connection::new(
        ProcessRef::new(number(c, "realm"), number(c, "writer"))?,
        ResourceRef::new(number(c, "realm"), number(c, "resource"))?,
        number(c, "table").try_into()?,
    )?;
    let mut client = m::Client::open(
        ClientConfig::growing(text(&config, "url"))?.with_timeout(10000)?,
        Credential::new(
            number(c, "realm"),
            number(c, "principal"),
            text(&config, "seed_file"),
        )?,
        connection,
    )?;
    println!("{}", json!({"ready":true}));
    io::stdout().flush()?;
    for line in io::stdin().lock().lines() {
        let action: Value = serde_json::from_str(&line?)?;
        if action.get("close").is_some() {
            break;
        }
        let output = match call(&mut client, &action) {
            Ok(value) => json!({"status":0,"value":value}),
            Err(error) => {
                json!({"status":error.status.unwrap_or(if error.kind == ErrorKind::UnknownOutcome {6} else {1}),"value":{"err":error.code,"diagnostic":error.diagnostic,"diagnostic_invalid":error.diagnostic_invalid}})
            }
        };
        println!("{output}");
        io::stdout().flush()?;
    }
    client.close()?;
    println!("{}", json!({"closed":true}));
    io::stdout().flush()?;
    Ok(())
}
