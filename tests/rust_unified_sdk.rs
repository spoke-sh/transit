use serde_json::{Value, json};
use std::{
    fs,
    io::{self, BufRead, Write},
};
use transit_client::{ClientConfig, Credential, ProcessRef, ResourceRef};
use transit_station_sdk::{Aggregate, Comparison, DocumentReference, unified as q};
type AnyResult<T> = Result<T, Box<dyn std::error::Error>>;
fn hex(v: &[u8]) -> String {
    v.iter().map(|b| format!("{b:02x}")).collect()
}
fn unhex(v: &str) -> Vec<u8> {
    v.as_bytes()
        .chunks_exact(2)
        .map(|c| u8::from_str_radix(std::str::from_utf8(c).unwrap(), 16).unwrap())
        .collect()
}
fn text<'a>(v: &'a Value, key: &str) -> &'a str {
    v[key].as_str().unwrap()
}
fn number(v: &Value, key: &str) -> u64 {
    v[key].as_u64().unwrap()
}
fn reference(
    resource: ResourceRef,
    document: u64,
    epoch: u64,
    revision: u64,
) -> AnyResult<DocumentReference> {
    let mut bytes = b"SDR1".to_vec();
    bytes.extend(resource.resource().to_le_bytes());
    bytes.extend(document.to_le_bytes());
    bytes.extend(epoch.to_le_bytes());
    bytes.extend(1u32.to_le_bytes());
    bytes.extend(revision.to_le_bytes());
    Ok(DocumentReference::decode(resource.realm(), &bytes, None)?)
}
fn projection(
    name: &str,
    datatype: q::Type,
    relative: bool,
    mode: q::ProjectionMode,
    path: Vec<String>,
) -> q::Projection {
    q::Projection {
        column: q::Column {
            name: name.into(),
            value_type: datatype,
        },
        path,
        relative,
        mode,
        text_bytes: 4096,
        text_steps: 4096,
    }
}
fn inspected_atom(value: q::InspectedAtom) -> Value {
    match value {
        q::InspectedAtom::All => json!({"all":{}}),
        q::InspectedAtom::State { column, state } => {
            json!({"state":{"column":column,"value":match state {q::State::TypeError=>"type_error".to_owned(),_=>format!("{state:?}").to_lowercase()}}})
        }
        q::InspectedAtom::Compare {
            column,
            comparison,
            value_type,
        } => {
            json!({"compare":{"column":column,"op":format!("{comparison:?}").to_lowercase(),"type":format!("{value_type:?}").to_lowercase()}})
        }
    }
}
fn codecs(config: &Value) -> AnyResult<()> {
    let resource = ResourceRef::new(46, 7)?;
    let sources = [
        q::Source::KV {
            resource,
            prefix: b"data/".to_vec(),
            key: q::Decoder::v1(q::Type::Binary),
            value: q::Decoder::v1(q::Type::Uint64),
        },
        q::Source::Table {
            resource,
            table: 9,
            names: ["id".into(), "label".into()],
            value_type: q::Type::Utf8,
        },
        q::Source::Document {
            reference: reference(resource, u64::MAX, 3, 42)?,
            expand: None,
            projections: vec![
                projection(
                    "title",
                    q::Type::Utf8,
                    false,
                    q::ProjectionMode::Scalar,
                    vec!["title".into()],
                ),
                projection(
                    "body",
                    q::Type::Utf8,
                    false,
                    q::ProjectionMode::Text,
                    vec!["body".into()],
                ),
            ],
        },
    ];
    let fixtures: Value = serde_json::from_slice(&fs::read(text(config, "bundles"))?)?;
    for (index, source) in sources.iter().enumerate() {
        let plan = q::Plan {
            output_names: None,
            projection: vec![1, 0],
            predicate: q::Predicate::Compare {
                column: 1,
                comparison: Comparison::Ne,
                value: if index == 0 {
                    q::Scalar::Uint64(u64::MAX)
                } else {
                    q::Scalar::Utf8("x".repeat(512))
                },
            },
            limit: Some(u64::MAX),
            aggregate: Aggregate::Rows,
        };
        let bundle = q::Bundle::prepare(
            source,
            &plan,
            q::Budgets {
                pages: 1000,
                segments: 500,
                result_bytes: 1048576,
            },
            None,
        )?;
        assert_eq!(hex(bundle.data()), text(&fixtures[index], "wire_hex"));
        let mut named = plan.clone();
        named.output_names = Some(vec![Some("Result".into()), None]);
        let bundle = q::Bundle::prepare(
            source,
            &named,
            q::Budgets {
                pages: 1000,
                segments: 500,
                result_bytes: 1048576,
            },
            None,
        )?;
        assert_eq!(hex(bundle.data()), text(&fixtures[index], "named_wire_hex"));
        let counted = q::Plan {
            projection: vec![1],
            predicate: q::Predicate::All,
            aggregate: Aggregate::CountValues,
            limit: None,
            output_names: Some(vec![Some("present".into())]),
        };
        let bundle = q::Bundle::prepare(
            source,
            &counted,
            q::Budgets {
                pages: 1000,
                segments: 500,
                result_bytes: 1048576,
            },
            None,
        )?;
        assert_eq!(
            hex(bundle.data()),
            text(&fixtures[index], "counted_wire_hex")
        );
    }
    let boolean_fixtures: Value = serde_json::from_slice(&fs::read(text(config, "boolean"))?)?;
    let types = [
        q::Type::Int64,
        q::Type::Uint64,
        q::Type::Float64,
        q::Type::Boolean,
        q::Type::Utf8,
        q::Type::Binary,
    ];
    let scalars = [
        q::Scalar::Int64(i64::MIN),
        q::Scalar::Uint64(u64::MAX),
        q::Scalar::Float64(-0.0),
        q::Scalar::Boolean(true),
        q::Scalar::Utf8("café é 🙂".into()),
        q::Scalar::Binary(vec![0, 255, 128]),
        q::Scalar::Utf8("x".repeat(512)),
    ];
    for (index, fixture) in boolean_fixtures.as_array().unwrap().iter().enumerate() {
        use q::{PredicateAtom as A, PredicateInstruction as I};
        let source = q::Source::KV {
            resource,
            prefix: vec![],
            key: q::Decoder::v1(types[number(fixture, "type") as usize - 1]),
            value: q::Decoder::v1(q::Type::Uint64),
        };
        let instructions = if index < 7 {
            vec![
                I::Atom(A::Compare {
                    column: 0,
                    comparison: Comparison::Eq,
                    value: scalars[index].clone(),
                }),
                I::Negate,
                I::Atom(A::State {
                    column: 0,
                    state: q::State::Null,
                }),
                I::Disjunction,
            ]
        } else if text(fixture, "name") == "all-and-not-null" {
            vec![
                I::Atom(A::All),
                I::Atom(A::State {
                    column: 0,
                    state: q::State::Null,
                }),
                I::Negate,
                I::Conjunction,
            ]
        } else {
            let mut v = vec![I::Atom(A::All)];
            v.extend(vec![I::Negate; 63]);
            v
        };
        let plan = q::Plan {
            projection: vec![0],
            output_names: None,
            predicate: q::Predicate::Program(instructions),
            limit: None,
            aggregate: Aggregate::Rows,
        };
        let bundle = q::Bundle::prepare(
            &source,
            &plan,
            q::Budgets {
                pages: 1000,
                segments: 500,
                result_bytes: 1048576,
            },
            None,
        )?;
        assert_eq!(hex(bundle.data()), text(fixture, "wire_hex"));
    }
    {
        use q::{PredicateAtom as A, PredicateInstruction as I};
        let source = q::Source::KV {
            resource,
            prefix: vec![],
            key: q::Decoder::v1(q::Type::Int64),
            value: q::Decoder::v1(q::Type::Uint64),
        };
        let mut oversized = vec![I::Atom(A::All)];
        oversized.extend(vec![I::Negate; 64]);
        for instructions in [
            vec![],
            vec![I::Negate],
            vec![I::Atom(A::All), I::Atom(A::All)],
            oversized,
            vec![I::Atom(A::State {
                column: 8,
                state: q::State::Null,
            })],
            vec![I::Atom(A::Compare {
                column: 0,
                comparison: Comparison::Eq,
                value: q::Scalar::Utf8("wrong type".into()),
            })],
        ] {
            let plan = q::Plan {
                projection: vec![0],
                output_names: None,
                predicate: q::Predicate::Program(instructions),
                limit: None,
                aggregate: Aggregate::Rows,
            };
            assert!(
                q::Bundle::prepare(
                    &source,
                    &plan,
                    q::Budgets {
                        pages: 1,
                        segments: 1,
                        result_bytes: 1024
                    },
                    None
                )
                .is_err()
            );
        }
    }
    let invalid = q::Source::KV {
        resource,
        prefix: vec![],
        key: q::Decoder {
            version: 2,
            value_type: q::Type::Binary,
        },
        value: q::Decoder::v1(q::Type::Utf8),
    };
    assert!(
        q::Bundle::prepare(
            &invalid,
            &q::Plan {
                output_names: None,
                projection: vec![0],
                predicate: q::Predicate::All,
                limit: None,
                aggregate: Aggregate::Rows
            },
            q::Budgets {
                pages: 1,
                segments: 1,
                result_bytes: 1
            },
            None
        )
        .is_err()
    );
    let columns = [
        ("int64", q::Type::Int64),
        ("uint64", q::Type::Uint64),
        ("float64", q::Type::Float64),
        ("boolean", q::Type::Boolean),
        ("utf8", q::Type::Utf8),
        ("binary", q::Type::Binary),
    ]
    .into_iter()
    .map(|(name, value_type)| q::Column {
        name: name.into(),
        value_type,
    })
    .collect::<Vec<_>>();
    let rows = q::decode_arrow(&columns, &fs::read(text(config, "arrow"))?, 5, None)?;
    assert_eq!(rows.len(), 5);
    assert!(rows[0].iter().all(|v| matches!(v, q::Cell::Missing)));
    assert!(rows[1].iter().all(|v| matches!(v, q::Cell::Null)));
    assert!(
        rows[2]
            .iter()
            .all(|v| matches!(v,q::Cell::TypeError(k) if k=="map"))
    );
    let expected = [
        q::Scalar::Int64(i64::MIN),
        q::Scalar::Uint64(u64::MAX),
        q::Scalar::Float64(-0.0),
        q::Scalar::Boolean(false),
        q::Scalar::Utf8("café é 東京🙂".into()),
        q::Scalar::Binary(vec![0, 255, 128]),
    ];
    for (index, expected) in expected.iter().enumerate() {
        assert!(matches!(&rows[3][index],q::Cell::Value(v) if v==expected));
        let q::Cell::Conflict(values) = &rows[4][index] else {
            panic!("Missing conflict")
        };
        assert_eq!(values.len(), 2);
        assert_eq!(
            (
                values[0].counter,
                values[0].replica,
                values[1].counter,
                values[1].replica
            ),
            (u64::MAX, 1, u64::MAX, 2)
        );
        assert!(matches!(&values[0].value,q::AlternativeValue::Value(v) if v==expected));
        assert!(matches!(values[1].value, q::AlternativeValue::Null));
    }
    assert!(
        matches!(rows[3][2],q::Cell::Value(q::Scalar::Float64(v)) if v.to_bits()==(-0.0f64).to_bits())
    );
    assert!(q::decode_arrow(&columns, &fs::read(text(config, "empty"))?, 0, None)?.is_empty());
    assert!(q::decode_arrow(&columns, &fs::read(text(config, "malformed"))?, 5, None).is_err());
    println!(
        "Rust installed unified codecs: three sources, nine Boolean bundles, six types, five states and malformed rejection passed"
    );
    Ok(())
}
fn inspection(value: q::Inspection) -> Value {
    fn columns(values: Vec<q::Column>) -> Value {
        json!(
            values
                .into_iter()
                .map(|v| json!({"name":v.name,"type":format!("{:?}",v.value_type).to_lowercase()}))
                .collect::<Vec<_>>()
        )
    }
    let details = match value.details {
        q::InspectionDetails::Description { columns: values } => {
            json!({"description":{"columns":columns(values)}})
        }
        q::InspectionDetails::Tables { names } => json!({"tables":names}),
        q::InspectionDetails::Explanation {
            operators,
            predicate,
            projection,
            limit,
            aggregate,
            columns: values,
            budgets,
        } => {
            let predicate = match predicate {
                q::InspectedPredicate::All => json!({"all":{}}),
                q::InspectedPredicate::State { column, state } => {
                    json!({"state":{"column":column,"value":match state {
                        q::State::TypeError => "type_error".to_owned(), _ => format!("{state:?}").to_lowercase(),
                    }}})
                }
                q::InspectedPredicate::Compare {
                    column,
                    comparison,
                    value_type,
                } => {
                    json!({"compare":{"column":column,"op":format!("{comparison:?}").to_lowercase(),"type":format!("{value_type:?}").to_lowercase()}})
                }
                q::InspectedPredicate::Program(instructions) => {
                    json!({"program":instructions.into_iter().map(|v|match v {
                    q::InspectedInstruction::Atom(atom)=>json!({"atom":inspected_atom(atom)}),
                    q::InspectedInstruction::Negate=>json!({"negate":{}}),
                    q::InspectedInstruction::Conjunction=>json!({"conjunction":{}}),
                    q::InspectedInstruction::Disjunction=>json!({"disjunction":{}}),
                }).collect::<Vec<_>>()})
                }
            };
            json!({"explanation":{"operators":operators.iter().map(|v|format!("{v:?}").to_lowercase().replace("countvalues", "count_values")).collect::<Vec<_>>(),
                "predicate":predicate,"projection":projection,"limit":limit.map(|v|v.to_string()),"aggregate":format!("{aggregate:?}").to_lowercase().replace("countvalues", "count_values"),
                "columns":columns(values),"budgets":{"pages":budgets.pages.to_string(),"segments":budgets.segments.to_string(),"result_bytes":budgets.result_bytes.to_string()}}})
        }
    };
    json!({"inspection":{"version":1,"scope":"configured_source","name":value.name,"resource":value.resource.resource(),
        "source_kind":format!("{:?}",value.source_kind).to_lowercase(),"contract":value.source_digest,"schema":value.schema_digest,
        "resource_revision":value.resource_revision,"policy_revision":value.policy_revision.to_string(),"details":details}})
}

fn serve(config: &Value) -> AnyResult<()> {
    let v = &config["connection"];
    let realm = number(v, "realm");
    let resource = ResourceRef::new(realm, number(v, "resource"))?;
    let connection = q::Connection::new(
        ProcessRef::new(realm, number(v, "source"))?,
        resource,
        ProcessRef::new(realm, number(v, "requester"))?,
        ResourceRef::new(realm, number(v, "requests"))?,
    )?;
    let kind = text(config, "kind");
    let source = match kind {
        "kv" => q::Source::KV {
            resource,
            prefix: b"k".to_vec(),
            key: q::Decoder::v1(q::Type::Binary),
            value: q::Decoder::v1(q::Type::Utf8),
        },
        "table" => q::Source::Table {
            resource,
            table: 1,
            names: ["id".into(), "value".into()],
            value_type: q::Type::Utf8,
        },
        _ => q::Source::Document {
            reference: reference(resource, 17, 1, 13)?,
            expand: Some(vec!["items".into()]),
            projections: vec![
                projection(
                    "value",
                    q::Type::Utf8,
                    true,
                    q::ProjectionMode::Scalar,
                    vec![],
                ),
                projection(
                    "counter",
                    q::Type::Uint64,
                    true,
                    q::ProjectionMode::ElementCounter,
                    vec![],
                ),
                projection(
                    "replica",
                    q::Type::Uint64,
                    true,
                    q::ProjectionMode::ElementReplica,
                    vec![],
                ),
                projection(
                    "optional",
                    q::Type::Utf8,
                    false,
                    q::ProjectionMode::Scalar,
                    vec!["optional".into()],
                ),
            ],
        },
    };
    use q::{PredicateAtom as A, PredicateInstruction as I};
    let column = if kind == "document" { 0 } else { 1 };
    let comparison = A::Compare {
        column,
        comparison: Comparison::Ne,
        value: q::Scalar::Utf8("x".repeat(512)),
    };
    let predicate = if config["compound"].as_bool().unwrap() {
        let ceiling = format!(
            "東京🙂/{}/{}",
            "x".repeat(if kind == "document" { 64 } else { 128 }),
            if kind == "document" { "10" } else { "39" }
        );
        q::Predicate::Program(vec![
            I::Atom(comparison),
            I::Atom(A::Compare {
                column,
                comparison: Comparison::Ge,
                value: q::Scalar::Utf8(ceiling),
            }),
            I::Atom(A::State {
                column,
                state: q::State::Null,
            }),
            I::Disjunction,
            I::Negate,
            I::Conjunction,
        ])
    } else {
        q::Predicate::Compare {
            column,
            comparison: Comparison::Ne,
            value: q::Scalar::Utf8("x".repeat(512)),
        }
    };
    let plan = q::Plan {
        output_names: Some(if kind == "document" {
            vec![Some("Result".into()), None, None, None]
        } else {
            vec![Some("Result".into())]
        }),
        projection: if kind == "document" {
            vec![0, 1, 2, 3]
        } else {
            vec![1]
        },
        predicate,
        limit: None,
        aggregate: Aggregate::Rows,
    };
    let bundle = q::Bundle::prepare(
        &source,
        &plan,
        q::Budgets {
            pages: 1000,
            segments: 100,
            result_bytes: 1048576,
        },
        None,
    )?;
    assert_eq!(bundle.data(), fs::read(text(config, "bundle"))?);
    let mut client = q::Client::open(
        ClientConfig::growing(text(config, "url"))?.with_timeout(10000)?,
        Credential::new(realm, number(v, "principal"), text(config, "seed_file"))?,
        connection,
    )?;
    let description = client.describe(&source)?;
    assert_eq!(
        (description.bundle_bytes, description.batch_rows),
        (16384, 8)
    );
    println!("{}", json!({"ready":true}));
    io::stdout().flush()?;
    for line in io::stdin().lock().lines() {
        let action: Value = serde_json::from_str(&line?)?;
        if action.get("close").is_some() {
            break;
        }
        let result = (|| -> transit_client::Result<Value> {
            Ok(if let Some(v) = action.get("compile") {
                let scope = &v["scope"];
                let limits = &scope["limits"];
                let parameters: Option<Vec<q::Scalar>> =
                    v.get("parameters").and_then(Value::as_array).map(|values| {
                        values
                            .iter()
                            .map(|value| {
                                let (kind, data) =
                                    value.as_object().unwrap().iter().next().unwrap();
                                match kind.as_str() {
                                    "int64" => {
                                        q::Scalar::Int64(data.as_str().unwrap().parse().unwrap())
                                    }
                                    "uint64" => {
                                        q::Scalar::Uint64(data.as_str().unwrap().parse().unwrap())
                                    }
                                    "float_bits" => q::Scalar::Float64(f64::from_le_bytes(
                                        unhex(data.as_str().unwrap()).try_into().unwrap(),
                                    )),
                                    "boolean" => q::Scalar::Boolean(data.as_bool().unwrap()),
                                    "utf8" => q::Scalar::Utf8(data.as_str().unwrap().into()),
                                    "binary" => q::Scalar::Binary(unhex(data.as_str().unwrap())),
                                    _ => panic!("Unknown parameter type"),
                                }
                            })
                            .collect()
                    });
                let value = client.compile_sql(
                    &source,
                    text(scope, "name"),
                    text(v, "sql"),
                    q::Budgets {
                        pages: text(limits, "pages").parse().unwrap(),
                        segments: text(limits, "segments").parse().unwrap(),
                        result_bytes: text(limits, "result_bytes").parse().unwrap(),
                    },
                    parameters.as_deref(),
                )?;
                json!({"compiled":{"bundle":hex(value.data())}})
            } else if let Some(v) = action.get("inspect") {
                let scope = &v["scope"];
                let limits = &scope["limits"];
                let value = client.inspect_sql(
                    &source,
                    text(scope, "name"),
                    text(v, "sql"),
                    q::Budgets {
                        pages: text(limits, "pages").parse().unwrap(),
                        segments: text(limits, "segments").parse().unwrap(),
                        result_bytes: text(limits, "result_bytes").parse().unwrap(),
                    },
                )?;
                assert_eq!(value.resource, resource);
                inspection(value)
            } else if let Some(v) = action.get("next") {
                let bundle = q::Bundle::from_bytes(unhex(text(v, "bundle")))?;
                json!({"prepared":client.prepare_next(text(v,"namespace").parse().unwrap(),&bundle)?.as_ref().map(q::Prepared::data)})
            } else if let Some(v) = action.get("submit") {
                let prepared = q::Prepared::from_data(v.as_str().unwrap().into())?;
                let saved = prepared.data().to_owned();
                let result = client.submit(&prepared);
                assert_eq!(prepared.data(), saved);
                json!({"receipt":{"position":result?.position.get()}})
            } else if let Some(v) = action.get("observe") {
                json!({"observation":match client.observe(v.as_u64().unwrap())?{q::Observation::Pending=>json!({"pending":{}}),q::Observation::Committed=>json!({"committed":{}}),q::Observation::Rejected(v)=>json!({"rejected":hex(v.as_bytes())})}})
            } else if let Some(v) = action.get("status") {
                let value = client.status(v.as_str().unwrap().parse().unwrap())?;
                json!({"status":value.map(|v|json!({"phase":format!("{:?}",v.phase).to_lowercase(),"correlation":v.correlation.to_string()}))})
            } else if let Some(v) = action.get("page") {
                let cursor = v["cursor"]
                    .as_str()
                    .map(|s| q::Cursor::from_data(s.into()))
                    .transpose()?;
                let page = client.page(text(v, "namespace").parse().unwrap(), cursor.as_ref())?;
                assert_eq!(page.manifest.resource, resource);
                assert_eq!(
                    page.manifest.source_kind,
                    match kind {
                        "kv" => q::SourceKind::KV,
                        "table" => q::SourceKind::Table,
                        _ => q::SourceKind::Document,
                    }
                );
                assert_eq!(page.decode(None)?.len(), usize::from(page.rows));
                assert_eq!(page.to_arrow()?.num_rows(), usize::from(page.rows));
                json!({"page":{"ordinal":page.ordinal.to_string(),"ipc":hex(page.ipc()),"manifest":{"segments":page.manifest.segments.to_string(),"selected":page.manifest.selected.to_string(),"value_count":page.manifest.value_count.to_string()},"next":page.next.as_ref().map(q::Cursor::data)}})
            } else {
                panic!("Unsupported test operation")
            })
        })();
        println!(
            "{}",
            match result {
                Ok(value) => json!({"status":0,"value":value}),
                Err(error) => json!({"status":error.status,"value":{"err":error.code}}),
            }
        );
        io::stdout().flush()?;
    }
    client.close()?;
    println!("{}", json!({"closed":true}));
    io::stdout().flush()?;
    Ok(())
}
fn main() -> AnyResult<()> {
    let args = std::env::args().collect::<Vec<_>>();
    let cfg = serde_json::from_slice(&fs::read(&args[2])?)?;
    if args[1] == "codecs" {
        codecs(&cfg)
    } else {
        serve(&cfg)
    }
}
