"""A durable counter and requester; no future or object field holds waiting state."""
import argparse
import json
from pathlib import Path
from transit_client import ProcessRef
from transit_client.errors import HandlerError
from transit_station import (Activation, ServiceConfig, Turn, Incoming, Cast, Call, Reply,
    Key, U64, WaitPolicy, Runner, Recovery, FailurePolicy, Committed)
from .codecs import (Add, Read, Start, Total, counter_codec, requester_codec, total_codec, u64)

TOTAL, REQUEST, OBSERVED = Key(b'total', u64), Key(b'request', u64), Key(b'observed', u64)


class Counter:
    def initialize(self, turn: Turn) -> None:
        turn.state.put(TOTAL, 0)
    def handle(self, turn: Turn, incoming: Incoming[Add | Read]) -> None:
        if isinstance(incoming, Cast) and isinstance(incoming.value, Add):
            turn.state.put(TOTAL, U64.checked_add(turn.state.require(TOTAL), incoming.value.value))
        elif isinstance(incoming, Call) and isinstance(incoming.value, Read):
            turn.reply(Total(turn.state.require(TOTAL)), codec=total_codec)
        else:
            raise HandlerError('Unexpected counter message')


class Requester:
    def __init__(self, counter: ProcessRef) -> None:
        self.counter = counter
    def initialize(self, turn: Turn) -> None:
        pass
    def handle(self, turn: Turn, incoming: Incoming[Start | Total]) -> None:
        if isinstance(incoming, Cast) and isinstance(incoming.value, Start):
            if turn.state.find(REQUEST) is not None:
                raise HandlerError('Request already started')
            correlation = turn.call(self.counter, Read(), codec=counter_codec, wait=WaitPolicy.untimed())
            turn.state.put(REQUEST, correlation)
        elif isinstance(incoming, Reply) and isinstance(incoming.value, Total):
            turn.require_reply(incoming, peer=self.counter, correlation=turn.state.require(REQUEST))
            turn.state.put(OBSERVED, incoming.value.value)
        else:
            raise HandlerError('Unexpected requester message')


def configuration(path: Path) -> tuple[ServiceConfig, ProcessRef]:
    value = json.loads(path.read_bytes())
    activation = Activation(ProcessRef(value['realm'], value['pid']), value['principal'],
                            value['generation'], Path(value['seed_file']))
    return (ServiceConfig(value['url'], value['profile'], activation, query_results=value.get('query_results', False)),
            ProcessRef(value['realm'], value['peer']))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    parser.add_argument('role', choices=('service', 'requester'))
    parser.add_argument('--commits', type=int, default=1)
    args = parser.parse_args()
    config, peer = configuration(args.config)
    if args.commits < 1: parser.error('--commits must be positive')
    # This example explicitly requires a fresh activation after host loss.
    # Production applications may instead supply a durable RecoveryStore.
    if args.role == 'service':
        with Runner.open(config, handler=Counter(), codec=counter_codec, failure_policy=FailurePolicy.STOP, recovery=Recovery.fence_on_restart()) as service:
            consume(service, args.commits)
    else:
        with Runner.open(config, handler=Requester(peer), codec=requester_codec, failure_policy=FailurePolicy.STOP, recovery=Recovery.fence_on_restart()) as requester:
            consume(requester, args.commits)


def consume[M](runner: Runner[M], count: int) -> None:
    for event in runner.run():
        if not isinstance(event, Committed):
            raise RuntimeError(f'Runner stopped with {type(event).__name__}')
        print(json.dumps({'input': event.input_position, 'committed': event.receipt.position}), flush=True)
        count -= 1
        if count == 0: return


if __name__ == '__main__':
    main()
