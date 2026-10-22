"""Generate synthetic S1 Binary fixtures; never reads ROM or recordings."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def swap(byte):
    return (byte & 15) * 16 + (byte >> 4)


def checksum(data):
    total = 0
    for byte in data:
        total += byte & 15
        if total > 255:
            total = (total + 1) & 255
        total = (total + (byte >> 4)) & 255
    return swap(total)


def expected_payload(body, address, name):
    name_block = [0, *reversed(name.encode('ascii'))]
    name_block += [0] * (7 - len(name_block)) + [0xF5]
    size = len(body) - 1
    meta = [0, 0, 0, 0, address >> 8, address & 255, size >> 8, size & 255]
    result = [0x67, *name_block, checksum(name_block), *meta, checksum(meta)]
    raw = [swap(b) for b in body]
    full = (len(raw) - 1) // 120 * 120
    for offset in range(0, full, 120):
        chunk = raw[offset:offset + 120]
        result += chunk + [checksum(chunk)]
    result += raw[full:] + [255, 255, checksum(raw[full:] + [255])]
    return bytes(result)


def run(*args):
    subprocess.run([str(a) for a in args], check=True, capture_output=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--addr', required=True, type=lambda s: int(s, 0), help='Writable RAM start, e.g. 0x9000')
    parser.add_argument('--model', default='PC-1360K', help='Target model recorded in manifest')
    parser.add_argument('--output', type=Path, default=ROOT / '.local' / 'hardware-tests')
    args = parser.parse_args()
    if not 0 <= args.addr <= 65536 - 4112:
        parser.error('address must allow a 4112-byte region within 0x0000..0xFFFF')
    if args.output.exists():
        parser.error('output directory already exists; choose a fresh directory')
    encode = ROOT / 'dist/pcwav-encode.pl'
    if not encode.exists():
        parser.error('run perl build.pl first')
    args.output.mkdir(parents=True)
    records = []
    for length in (1, 119, 120, 121, 240, 4112, 65536):
        case = f'S{length:05d}'
        # Nonzero, varying data. Partial tails deliberately differ from legacy FF-only SUM.
        body = bytes((i * 73 + 19) & 255 for i in range(length))
        address = 0 if length == 65536 else args.addr
        payload = expected_payload(body, address, case)
        (args.output / f'{case}.bin').write_bytes(body)
        (args.output / f'{case}.expected.raw').write_bytes(payload)
        partial = length % 120
        assert not partial or payload[-1] != checksum([255])
        record = dict(case=case, length=length, address=f'0x{address:04X}',
                      end_address=f'0x{address + length - 1:04X}', partial_bytes=partial,
                      tail_sum=f'0x{payload[-1]:02X}', legacy_tail_sum=f'0x{checksum([255]):02X}',
                      hardware_candidate=length != 65536, result='NOT_RUN')
        if length != 65536:
            wav = args.output / f'{case}.wav'
            run('perl', encode, 's1bin', args.output / f'{case}.bin', wav, case, hex(address))
            raw = args.output / f'{case}.actual.raw'
            run('perl', ROOT / 'dist/pcwav-decode.pl', 'raw', wav, raw)
            if raw.read_bytes() != payload:
                raise RuntimeError(f'{case}: waveform raw bytes differ from independent expected payload')
            restored = args.output / f'{case}.decoded.bin'
            run('perl', ROOT / 'dist/pcwav-decode.pl', 's1bin', wav, restored)
            if restored.read_bytes() != body:
                raise RuntimeError(f'{case}: round trip mismatch')
        records.append(record)
    manifest = dict(version='0.5.2', synthetic_only=True, hardware_model=args.model, address_selected_by_operator=True,
                    cases=records, files={})
    for path in sorted(args.output.iterdir()):
        manifest['files'][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (args.output / 'SHA256SUMS').write_text(''.join(f'{digest}  {name}\n' for name, digest in manifest['files'].items()))
    print(f'Generated {args.output} for {args.model}, address 0x{args.addr:04X}. Hardware tests are NOT_RUN.')


if __name__ == '__main__':
    main()
