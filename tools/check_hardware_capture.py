"""Strictly decode a CSAVE recording and compare it with a generated synthetic case."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('case_directory', type=Path)
parser.add_argument('case', help='e.g. S00121')
parser.add_argument('recording', type=Path)
parser.add_argument('--skip-ms', default='0', help='Recording prefix to skip; default 0')
args = parser.parse_args()
manifest = json.loads((args.case_directory / 'manifest.json').read_text())
case = next((c for c in manifest['cases'] if c['case'] == args.case), None)
if not case:
    parser.error('unknown case')
expected = (args.case_directory / f'{args.case}.bin').read_bytes()
with tempfile.TemporaryDirectory(prefix='pcwav-capture-') as directory:
    output = Path(directory) / 'decoded.bin'
    result = subprocess.run(['perl', str(ROOT / 'dist/pcwav-decode.pl'), 's1bin',
                             '--skip-ms', args.skip_ms, str(args.recording), str(output)],
                            capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('FAIL: recording decode/checksum validation failed\n' + result.stderr)
    match = re.search(r'^addr: ([0-9A-Fa-f]+)$', result.stdout, re.MULTILINE)
    if not match or int(match[1], 16) != int(case['address'], 16):
        raise SystemExit('FAIL: recorded start address differs from manifest\n' + result.stdout)
    actual = output.read_bytes()
    if actual != expected:
        first = next((i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]), min(len(actual), len(expected)))
        raise SystemExit(f'FAIL: data mismatch at offset 0x{first:04X}; expected {len(expected)} bytes, got {len(actual)}')
print(f'PASS: {args.case}, address {case["address"]}, all {len(expected)} bytes match; checksums verified')
