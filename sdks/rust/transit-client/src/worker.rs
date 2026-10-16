use crate::{Error, ErrorKind, Result};
use std::{
    cell::Cell,
    marker::PhantomData,
    panic::{AssertUnwindSafe, catch_unwind},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    thread,
};

#[derive(Clone, Default)]
pub struct StopToken(Arc<AtomicBool>);
impl StopToken {
    pub fn stop(&self) {
        self.0.store(true, Ordering::Release);
    }
    pub fn is_stopped(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }
}
type Job<S> = Box<dyn FnOnce(&mut S) + Send>;
thread_local! { static NATIVE_WORKER: Cell<bool> = const { Cell::new(false) }; }
pub(crate) fn on_worker() -> bool {
    NATIVE_WORKER.get()
}
/// One bounded worker with exclusive admission. Never call its blocking API on
/// an executor thread; dropping a host wait does not cancel the owned native work.
pub struct Worker<S> {
    sender: Option<mpsc::SyncSender<Job<S>>>,
    join: Option<thread::JoinHandle<()>>,
    _exclusive: PhantomData<Cell<()>>,
}
impl<S: 'static> Worker<S> {
    pub fn open(stack: usize, create: impl FnOnce() -> Result<S> + Send + 'static) -> Result<Self> {
        let (sender, receiver) = mpsc::sync_channel::<Job<S>>(1);
        let (ready, started) = mpsc::sync_channel(1);
        let join = thread::Builder::new()
            .name("transit-native".into())
            .stack_size(stack.max(crate::abi::MINIMUM_STACK_BYTES))
            .spawn(move || {
                NATIVE_WORKER.set(true);
                let initialized = catch_unwind(AssertUnwindSafe(create));
                let mut state = match initialized {
                    Ok(Ok(state)) => {
                        if ready.send(Ok(())).is_err() {
                            return;
                        }
                        state
                    }
                    Ok(Err(error)) => {
                        let _ = ready.send(Err(error));
                        return;
                    }
                    Err(_) => {
                        let _ = ready.send(Err(Error::new(ErrorKind::WorkerPanic, "open")));
                        return;
                    }
                };
                while let Ok(work) = receiver.recv() {
                    work(&mut state);
                }
                // Native destruction also runs on the qualified stack.
            })
            .map_err(|_| Error::new(ErrorKind::ReadFailed, "start-worker"))?;
        match started.recv() {
            Ok(Ok(())) => Ok(Self {
                sender: Some(sender),
                join: Some(join),
                _exclusive: PhantomData,
            }),
            Ok(Err(error)) => {
                let _ = join.join();
                Err(error)
            }
            Err(_) => {
                let _ = join.join();
                Err(Error::new(ErrorKind::WorkerPanic, "open"))
            }
        }
    }
    pub fn call<T: Send + 'static>(
        &mut self,
        work: impl FnOnce(&mut S) -> Result<T> + Send + 'static,
    ) -> Result<T> {
        if self
            .join
            .as_ref()
            .is_some_and(|join| join.thread().id() == thread::current().id())
        {
            return Err(Error::new(ErrorKind::Busy, "worker-reentry"));
        }
        let sender = self
            .sender
            .as_ref()
            .ok_or_else(|| Error::new(ErrorKind::Closed, "worker"))?;
        let (reply, receive) = mpsc::sync_channel(1);
        sender
            .try_send(Box::new(move |state| {
                let result = catch_unwind(AssertUnwindSafe(|| work(state)))
                    .unwrap_or_else(|_| Err(Error::new(ErrorKind::WorkerPanic, "worker")));
                let _ = reply.send(result);
            }))
            .map_err(|error| {
                Error::new(
                    match error {
                        mpsc::TrySendError::Full(_) => ErrorKind::Busy,
                        mpsc::TrySendError::Disconnected(_) => ErrorKind::Closed,
                    },
                    "admission",
                )
            })?;
        receive
            .recv()
            .map_err(|_| Error::new(ErrorKind::WorkerPanic, "worker"))?
    }
    pub fn close(&mut self) -> Result<()> {
        if self
            .join
            .as_ref()
            .is_some_and(|join| join.thread().id() == thread::current().id())
        {
            return Err(Error::new(ErrorKind::Busy, "worker-reentry"));
        }
        self.sender.take();
        if let Some(join) = self.join.take() {
            join.join()
                .map_err(|_| Error::new(ErrorKind::WorkerPanic, "close"))?;
        }
        Ok(())
    }
}
impl<S> Drop for Worker<S> {
    fn drop(&mut self) {
        self.sender.take();
        if let Some(join) = self.join.take() {
            if join.thread().id() != thread::current().id() {
                let _ = join.join();
            }
        }
    }
}
