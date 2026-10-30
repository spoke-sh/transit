//! Installed direct Table lifecycle, retained metadata and original recovery.
use serde_json::{Value,json};
use std::{fs,io::{self,BufRead,Write},os::unix::fs::OpenOptionsExt,path::Path};
use transit_client::{ClientConfig,Credential,ResourceRef,ErrorKind};
use transit_station_sdk::{catalog as m,logical as l};
type Result<T> = std::result::Result<T,Box<dyn std::error::Error>>;
fn text<'a>(v:&'a Value,key:&str)->&'a str{v[key].as_str().unwrap()}
fn number(v:&Value,key:&str)->u64{v[key].as_u64().unwrap()}
fn persist(path:&Path,data:&str){let mut f=fs::OpenOptions::new().create(true).truncate(true).write(true).mode(0o600).open(path).unwrap();f.write_all(data.as_bytes()).unwrap();f.sync_all().unwrap();}
fn compile(c:&mut m::Client,sql:&str,operation:u64,object:Option<u64>)->Result<m::Compiled>{Ok(c.compile_sql(sql,m::Identity::new(operation,1)?,object,m::Dialect::Transit,m::Ingestion::Point)?)}
fn complete(c:&mut m::Client,work:m::Compiled,path:&Path)->Result<m::Observation>{
    persist(&path.join("work.json"),&work.saved.save());let original=c.stage(&work.intent)?;persist(&path.join("work-reference.json"),&original.save());let mut observed=c.admit(&original)?;
    for _ in 0..16{if observed.state!=m::OperationState::Admitted{break}observed=c.execute(&original,32)?;}assert_eq!(observed.state,m::OperationState::Committed);Ok(observed)
}
fn uncertain<T>(result:m::DispatchResult<T>,original:&str){match result {Err(m::DispatchError::Uncertain{cause,original:recovery})=>{
    assert_eq!(recovery.save(),original);assert_eq!(cause.kind,ErrorKind::UnknownOutcome);assert_eq!(cause.status,Some(6));assert!(!cause.diagnostic_invalid);assert_eq!(cause.diagnostic.as_ref().unwrap()["outcome"],"unknown");
},_=>panic!("expected uncertainty with original recovery")}}
fn atom(a:l::Atom)->l::Cell{l::Cell::Value(l::CellValue::Atom(a))}
fn assignment(column:u64,value:l::Cell)->m::Assignment{m::Assignment{column,value:m::AssignmentValue::Cell(value)}}
fn snapshot(path:&Path)->m::Snapshot{m::Snapshot::restore(&fs::read_to_string(path.join("snapshot.json")).unwrap()).unwrap()}
fn main()->Result<()>{
    let argument=std::env::args().nth(1).unwrap();let path=Path::new(&argument);let config:Value=serde_json::from_slice(&fs::read(path)?)?;let c=&config["connection"];let s=&c["scope"];
    let scope=m::Scope::new(ResourceRef::new(number(s,"realm"),number(s,"resource"))?,text(s,"catalog").parse()?)?;
    let mut connection=m::Connection::new(scope,number(c,"audience"))?.with_branch(text(c,"branch").parse()?)?;
    if let Some(role)=c["role"].as_u64(){connection=connection.with_role(role)?;}
    let mut client=m::Client::open(ClientConfig::growing(text(&config,"url"))?.with_timeout(10000)?,Credential::new(number(s,"realm"),number(c,"principal"),text(&config,"seed_file"))?,connection,Some(text(&config,"service_url").into()))?;
    let directory=path.parent().unwrap().join("rust");fs::create_dir_all(&directory)?;let name="rust_items";let object=u64::MAX-1;
    println!("{}",json!({"ready":true}));io::stdout().flush()?;
    for line in io::stdin().lock().lines(){let action:Value=serde_json::from_str(&line?)?;let (command,_)=action.as_object().unwrap().iter().next().unwrap();if command=="close"{break}
        let result=match command.as_str(){
            "prepare"=>{
                let description=client.describe()?;assert_eq!(description.subject.principal,number(c,"principal"));assert_eq!((description.configuration.authority.stream_domain,description.configuration.authority.queue_domain),(31,32));assert_eq!(client.namespace(1)?.unwrap().name,"public");assert!(client.namespaces(None)?.entries.iter().any(|n|n.id==1));
                let work=compile(&mut client,&format!("CREATE TABLE {name} (id BIGINT PRIMARY KEY, payload BINARY)"),1,Some(object))?;complete(&mut client,work,&directory)?;
                eprintln!("Rust direct prepare: current definition");let current=client.lookup(name,1)?.unwrap();assert_eq!(current.row_count,0);assert_eq!(current.basis.object(),object);
                let rows=(0..9).map(|i|vec![assignment(1,atom(l::Atom::Signed(i))),assignment(2,atom(l::Atom::Binary(vec![i as u8;32768])))]).collect();
                eprintln!("Rust direct prepare: typed bulk work");let work=client.prepare(name,m::Identity::new(2,1)?,&m::Operation::Mutate{basis:current.basis,mutation:m::Mutation::Insert{rows},ingestion:m::Ingestion::Bulk})?;
                eprintln!("Rust direct prepare: preview");assert!(matches!(client.preview(&work.intent)?.current,Some(m::PreviewCurrent::Definition{row_count:0,..})));
                persist(&directory.join("intent.json"),&work.saved.save());eprintln!("Rust direct prepare: load exact work");let loaded=client.load(&m::SavedIntent::restore(&fs::read_to_string(directory.join("intent.json"))?)?)?;
                let original=client.stage(&loaded)?;persist(&directory.join("original.json"),&original.save());assert_eq!(client.admit(&original)?.state,m::OperationState::Admitted);
                uncertain(client.execute(&original,32),&original.save());json!({"uncertain":true})
            },
            "recover"=>{
                let original=m::Reference::restore(&fs::read_to_string(directory.join("original.json"))?)?;let observed=client.inspect(&original)?;let commit=observed.commit.as_ref().unwrap();
                assert_eq!((commit.matched,commit.affected,commit.live_rows),(9,9,9));assert_eq!(client.execute(&original,32)?,observed);
                let current=client.lookup(name,1)?.unwrap();let acquisition=client.prepare_snapshot(&current,90000)?;persist(&directory.join("basis.json"),&current.basis.save());persist(&directory.join("acquisition.json"),&acquisition.save());
                uncertain(client.acquire_snapshot(&acquisition),&acquisition.save());json!({"retention_uncertain":true})
            },
            "retained"=>{
                let acquisition=m::SnapshotAcquisition::restore(&fs::read_to_string(directory.join("acquisition.json"))?)?;let status=client.snapshot_status(&acquisition.owner())?;assert!(!status.released);
                let snapshot=status.snapshot.unwrap();persist(&directory.join("snapshot.json"),&snapshot.save());let metadata=client.snapshot_metadata(&snapshot)?;assert_eq!(metadata.accepted,acquisition.expected());assert_eq!((metadata.row_count,metadata.schema.columns.len()),(9,2));json!({"retained":true})
            },
            "denied"=>{let e=client.snapshot_metadata(&snapshot(&directory)).unwrap_err();assert_eq!(e.kind,ErrorKind::AccessDenied);assert_eq!(e.status,Some(4));assert_eq!(e.diagnostic.unwrap()["category"],"access");json!({"denied":true})},
            "metadata"=>{let metadata=client.snapshot_metadata(&snapshot(&directory))?;let basis=m::Basis::restore(&fs::read_to_string(directory.join("basis.json"))?)?;assert_eq!(metadata.interpretation,basis.interpretation());json!({"rows":metadata.row_count,"columns":metadata.schema.columns.len()})},
            "retire"=>{
                let work=compile(&mut client,&format!("UPDATE {name} SET id=0 WHERE id=0"),3,None)?;let unchanged=complete(&mut client,work,&directory)?.commit.unwrap();assert_eq!((unchanged.matched,unchanged.affected),(1,0));
                let work=compile(&mut client,&format!("DELETE FROM {name} WHERE id=8"),4,None)?;let deleted=complete(&mut client,work,&directory)?.commit.unwrap();assert_eq!((deleted.matched,deleted.affected),(1,1));
                let old=client.lookup(name,1)?.unwrap();let work=client.prepare(name,m::Identity::new(5,1)?,&m::Operation::Alter{basis:old.basis.clone(),change:m::Change::Add{name:"extra".into(),datatype:l::Descriptor::Scalar(l::ScalarType::Int64),nullable:true,default:None,max_characters:None,encoding:m::Encoding::Plain,collation:m::Collation::None}})?;
                complete(&mut client,work,&directory)?;let error=client.prepare(name,m::Identity::new(55,1)?,&m::Operation::Drop{basis:Some(old.basis),if_exists:false}).unwrap_err();assert_eq!(error.code.as_deref(),Some("TableDefinitionChanged"));
                let work=compile(&mut client,&format!("ALTER TABLE {name} RENAME TO {name}_old"),6,None)?;complete(&mut client,work,&directory)?;
                let work=compile(&mut client,&format!("DROP TABLE {name}_old"),7,None)?;complete(&mut client,work,&directory)?;
                let work=compile(&mut client,&format!("CREATE TABLE {name} (replacement BIGINT)"),8,Some(object-1))?;complete(&mut client,work,&directory)?;
                assert_eq!(client.lookup(name,1)?.unwrap().basis.object(),object-1);assert_eq!(client.snapshot_metadata(&snapshot(&directory))?.row_count,9);json!({"original":true})
            },
            "release"=>{let snapshot=snapshot(&directory);assert!(!client.snapshot_status(&snapshot.owner())?.released);uncertain(client.release_snapshot(&snapshot),&snapshot.save());json!({"release_uncertain":true})},
            "verify"=>{
                let snapshot=snapshot(&directory);assert!(client.snapshot_status(&snapshot.owner())?.released);client.release_snapshot(&snapshot)?;
                let original=m::Reference::restore(&fs::read_to_string(directory.join("original.json"))?)?;assert_eq!(client.inspect(&original)?.commit.unwrap().affected,9);
                let saved=m::SavedIntent::restore(&fs::read_to_string(directory.join("intent.json"))?)?;assert_eq!(client.load(&saved)?.identity().operation(),2);
                assert_eq!(client.lookup(name,1)?.unwrap().basis.object(),object-1);assert_eq!(client.tables(1,None)?.consistency,Some(m::Consistency::Independent));json!({"recovered":true})
            },_=>panic!("unknown proof phase")
        };println!("{}",json!({"status":0,"value":result}));io::stdout().flush()?;
    }client.close()?;println!("{}",json!({"closed":true}));Ok(())
}
