"""Run installed SDK connector consumers against the shared durable schedule."""
import argparse
import importlib
from pathlib import Path
from sdk_exchange_runner import run


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('node'); parser.add_argument('cli'); parser.add_argument('library')
    parser.add_argument('worker'); parser.add_argument('artifacts')
    parser.add_argument('--language', choices=('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam'), action='append')
    parser.add_argument('--fault', choices=('published', 'retirement'))
    parser.add_argument('--protocol', choices=('http', 'grpc'), default='grpc')
    args = parser.parse_args()
    if args.fault and args.protocol != 'grpc':
        parser.error('--fault requires the gRPC protocol')
    for language in args.language or ('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam'):
        module = importlib.import_module(language + '_station_sdk')
        artifacts = Path(args.artifacts) / ('wheels' if language == 'python' else language)
        def execute(node, cli, library, install, label):
            run(node, cli, library, args.worker, install, label, public_release=True, public_followup=True, protocol=args.protocol, fault=args.fault)
        module.run(args.node, args.cli, args.library, artifacts, execute=execute)


if __name__ == '__main__': main()
