"""Run installed native SDK RPC consumers against the shared durable schedule."""
import argparse
import importlib
from pathlib import Path
from sdk_exchange_runner import run


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('node'); parser.add_argument('cli'); parser.add_argument('library')
    parser.add_argument('worker'); parser.add_argument('artifacts')
    parser.add_argument('--language', choices=('python', 'node', 'rust', 'ruby', 'c'), action='append')
    args = parser.parse_args()
    for language in args.language or ('python', 'node', 'rust', 'ruby', 'c'):
        module = importlib.import_module(language + '_station_sdk')
        artifacts = Path(args.artifacts) / ('wheels' if language == 'python' else language)
        def execute(node, cli, library, install, label):
            run(node, cli, library, args.worker, install, label, public_release=True, public_followup=True, protocol='grpc')
        module.run(args.node, args.cli, args.library, artifacts, execute=execute)


if __name__ == '__main__': main()
