use serde_json::{Value, json};
use std::{
    fs,
    io::{self, BufRead, Write},
};
use transit_client::{ClientConfig, Credential, ErrorKind, ProcessRef, ResourceRef, Result};
use transit_station_sdk::{CellType, catalog as m};
fn text<'a>(v: &'a Value, key: &str) -> &'a str {
    v[key].as_str().unwrap()
}
fn number(v: &Value, key: &str) -> u64 {
    v[key].as_u64().unwrap()
}
fn wide(v: &Value, key: &str) -> u64 {
    text(v, key).parse().unwrap()
}
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|v| format!("{v:02x}")).collect()
}
fn tag(value: impl std::fmt::Debug) -> String {
    let mut result = String::new();
    for (i, c) in format!("{value:?}").chars().enumerate() {
        if i > 0 && c.is_uppercase() {
            result.push('_');
        }
        result.extend(c.to_lowercase());
    }
    result
}
fn scope(v: &Value) -> Result<m::Scope> {
    m::Scope::new(
        ResourceRef::new(number(v, "realm"), number(v, "resource"))?,
        wide(v, "catalog"),
    )
}
fn scope_json(v: m::Scope) -> Value {
    json!({"realm":v.resource().realm(),"resource":v.resource().resource(),"catalog":v.catalog().to_string()})
}
fn configuration(v: &Value) -> Result<m::Configuration> {
    let s = scope(&v["scope"])?;
    m::Configuration::new(
        s,
        ProcessRef::new(s.resource().realm(), number(v, "owner"))?,
        number(v, "administrator"),
    )
}
fn configuration_json(v: &m::Configuration) -> Value {
    json!({"scope":scope_json(v.scope()),"owner":v.owner().pid(),"administrator":v.administrator()})
}
fn policy(v: &Value) -> Result<m::Policy> {
    m::Policy::new(
        scope(&v["scope"])?,
        number(v, "principal"),
        wide(v, "revision"),
        v["inspect"].as_bool().unwrap(),
        v["create"].as_bool().unwrap(),
    )
}
fn policy_json(v: &m::Policy) -> Value {
    json!({"scope":scope_json(v.scope()),"principal":v.principal(),"revision":v.revision().to_string(),"inspect":v.inspect(),"create":v.create()})
}
fn request(v: &Value) -> Result<m::CreateTable> {
    let schema = &v["schema"];
    let kind = match text(schema, "value_type") {
        "int64" => CellType::Int64,
        "boolean" => CellType::Boolean,
        "utf8" => CellType::Utf8,
        "binary" => CellType::Binary,
        _ => panic!("Invalid fixture type"),
    };
    let names = schema["names"].as_array().unwrap();
    m::CreateTable::new(
        scope(&v["scope"])?,
        wide(v, "operation"),
        wide(v, "object"),
        number(v, "table").try_into().unwrap(),
        text(v, "name").into(),
        m::Schema::new(
            [
                names[0].as_str().unwrap().into(),
                names[1].as_str().unwrap().into(),
            ],
            kind,
        )?,
    )
}
fn request_json(v: &m::CreateTable) -> Value {
    json!({"scope":scope_json(v.scope()),"operation":v.operation().to_string(),"object":v.object().to_string(),"table":v.table(),"name":v.name(),"schema":{"names":v.schema().names(),"value_type":tag(v.schema().value_type())}})
}
fn definition_json(v: m::Definition) -> Value {
    json!({"scope":scope_json(v.scope),"object":v.object.to_string(),"revision":v.revision.to_string(),"name":v.name,
        "source":{"table":{"id":v.source.table,"schema":{"names":v.source.schema.names(),"value_type":tag(v.source.schema.value_type())}}},
        "principal":v.principal,"operation":v.operation.to_string(),"input":v.input})
}
fn cursor_json(v: &m::Cursor) -> Value {
    json!({"definition":v.definition(),"scope":scope_json(v.scope()),"resource_revision":v.resource_revision(),"after":v.after()})
}
fn call(client: &mut m::Client, action: &Value) -> Result<Value> {
    Ok(if action.get("capabilities").is_some() {
        let v = client.capabilities()?;
        json!({"capabilities":{"version":v.version,"definition":v.definition,"initialize":v.initialize,"create_table":v.create_table,"conditional_policy":v.conditional_policy,"current_metadata":v.current_metadata,"max_saved_bytes":v.max_saved_bytes,"table_columns":v.table_columns}})
    } else if action.get("describe").is_some() {
        let v = client.describe()?;
        json!({"description":{"configuration":configuration_json(&v.configuration),"policy":policy_json(&v.policy),"resource_revision":v.resource_revision}})
    } else if let Some(v) = action.get("lookup") {
        json!({"definition":client.lookup(v.as_str().unwrap())?.map(definition_json)})
    } else if let Some(v) = action.get("definition") {
        json!({"definition":client.definition(wide(v,"object"),wide(v,"revision"))?.map(definition_json)})
    } else if let Some(v) = action.get("list") {
        let cursor = if v.is_null() {
            None
        } else {
            Some(m::Cursor::new(
                text(v, "definition").into(),
                scope(&v["scope"])?,
                number(v, "resource_revision"),
                text(v, "after").into(),
            )?)
        };
        let v = client.list(cursor.as_ref())?;
        let mut entries: Vec<Value> = v.entries.into_iter().map(definition_json).collect();
        entries.resize(8, Value::Null);
        json!({"page":{"resource_revision":v.resource_revision,"entries":entries,"next":v.next.as_ref().map(cursor_json)}})
    } else if let Some(v) = action.get("compile") {
        let v = client.compile_sql(
            text(v, "sql"),
            wide(v, "operation"),
            wide(v, "object"),
            number(v, "table").try_into().unwrap(),
        )?;
        json!({"compiled":{"request":request_json(v.request()),"canonical":hex(v.canonical())}})
    } else if let Some(v) = action.get("prepare_initialize") {
        json!({"prepared":client.prepare_initialize(&configuration(v)?)?.data()})
    } else if let Some(v) = action.get("prepare_create") {
        json!({"prepared":client.prepare_create(&request(v)?)?.data()})
    } else if let Some(v) = action.get("prepare_policy") {
        json!({"prepared":client.prepare_policy(&m::PolicyChange::new(wide(v,"expected_revision"),policy(&v["policy"])?))?.data()})
    } else if let Some(v) = action.get("submit") {
        let prepared = m::Prepared::from_data(v.as_str().unwrap().into())?;
        let original = prepared.data().to_owned();
        let result = client.submit(&prepared);
        assert_eq!(prepared.data(), original);
        json!({"receipt":{"position":result?.position.get()}})
    } else if let Some(v) = action.get("observe") {
        json!({"observation":tag(client.observe(&m::Prepared::from_data(text(v,"prepared").into())?,number(v,"input"))?)})
    } else if let Some(v) = action.get("input_disposition") {
        json!({"disposition":client.input_disposition(&m::Prepared::from_data(text(v,"prepared").into())?,number(v,"input"))?.map(|v|json!({"scope":scope_json(v.scope),"origin":tag(v.origin),"principal":v.principal,"input":v.input,"payload":hex(&v.payload),"outcome":tag(v.outcome)}))})
    } else if let Some(v) = action.get("status") {
        json!({"status":client.status(&request(v)?)?.map(|v|json!({"request":request_json(&v.request),"principal":v.principal,"input":v.input,"outcome":tag(v.outcome)}))})
    } else {
        panic!("Unsupported catalog action")
    })
}
fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let config: Value = serde_json::from_slice(&fs::read(std::env::args().nth(1).unwrap())?)?;
    let c = &config["connection"];
    let s = scope(&c["scope"])?;
    let connection = m::Connection::new(
        ProcessRef::new(s.resource().realm(), number(c, "owner"))?,
        s,
    )?;
    let mut client = m::Client::open(
        ClientConfig::growing(text(&config, "url"))?.with_timeout(10000)?,
        Credential::new(
            s.resource().realm(),
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
                json!({"status":error.status.unwrap_or(if error.kind==ErrorKind::UnknownOutcome {6} else {1}),"value":{"err":error.code,"diagnostic":error.diagnostic,"diagnostic_invalid":error.diagnostic_invalid}})
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
