#!/usr/bin/env python3
"""Repeat the recorded local probes without downloading or modifying models.

Run the Flutter tests first: their replay checks ensure these fixtures still
match the app's prompt and board serialization.
"""
import argparse
import json
from pathlib import Path
import time
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', default='http://127.0.0.1:11435')
parser.add_argument('--model', default='logos-7b')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
fixtures = json.loads((root / 'outputs/logos-fidelity.json').read_text())
results = []
for probe in fixtures:
    fixture, mode = probe['fixture'], probe['mode']
    body = {'model': args.model, 'stream': False, 'keep_alive': '30m',
            'options': {'temperature': 0.2, 'seed': 4, 'num_predict': 512}}
    if mode == 'chat':
        endpoint = 'chat'
        body['messages'] = [
            {'role': 'system', 'content': fixture['system']},
            {'role': 'user', 'content': fixture['user']}]
    else:
        endpoint = 'generate'
        body.update(prompt=fixture['system'] + fixture['user'], raw=True)
    start = time.monotonic()
    request = urllib.request.Request(
        args.url.rstrip('/') + '/api/' + endpoint,
        data=json.dumps(body).encode(),
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=600) as response:
        data = json.load(response)
    results.append({'fixture': fixture, 'mode': mode,
                    'wall': time.monotonic() - start, 'response': data})
    args.output.write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(f"{fixture['moves']} {mode}: {data.get('done_reason')} "
          f"({data.get('eval_count')} tokens)", flush=True)
