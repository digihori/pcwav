"""Smoke-test bundled pcwav with synthetic data; requires Python 3.10+ and Perl."""
from pathlib import Path
import subprocess
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parent.parent / "dist"


class RoundTripTests(unittest.TestCase):
    def test_modes(self):
        for mode in ('oldbasic', 's1basic', 's2basic', 'oldbin', 's1bin'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                directory = Path(directory)
                binary = mode.endswith('bin')
                original = bytes(range(256)) if binary else b'10 PRINT "TEST OK"\n20 END\n'
                source, wav, restored = (directory / name for name in ('source', 'audio.wav', 'restored'))
                source.write_bytes(original)
                parameters = ['TEST', '0x9000'] if binary else ['TEST']
                encode = ['perl', str(TOOLS / 'pcwav-encode.pl'), mode, str(source), str(wav), *parameters]
                decode = ['perl', str(TOOLS / 'pcwav-decode.pl'), mode, str(wav), str(restored)]
                for command in (encode, decode):
                    result = subprocess.run(command, cwd=directory, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr.decode())
                expected = original if binary else b'10:PRINT "TEST OK"\n20:END\n'
                self.assertEqual(restored.read_bytes(), expected)

    def test_numeric_cli(self):
        with tempfile.TemporaryDirectory(prefix='pcwav-cli-') as directory:
            root = Path(directory)
            source = root / 'data.bin'
            source.write_bytes(bytes(range(121)))
            basic = root / 'data.bas'
            basic.write_text('10 END\n')
            wav, out = root / 'data.wav', root / 'out.bin'
            def run(script, args, success):
                result = subprocess.run(['perl', str(TOOLS / script), *map(str,args)],
                                        capture_output=True, text=True, cwd=root)
                self.assertNotIn('Undefined subroutine', result.stderr)
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
            for mode in ('s1bin','oldbin'):
                for addr in ('0x9000','36864'):
                    run('pcwav-encode.pl',[mode,source,wav,'TEST',addr],True)
                for addr in ('','abc','-1','0x10000','0xFFFF'):
                    run('pcwav-encode.pl',[mode,source,wav,'TEST',addr],False)
            for value in ('0x27','39','0x37'):
                run('pcwav-encode.pl',['s2basic',basic,wav,'TEST',value],True)
            for value in ('','-1','abc','0x100','0x28'):
                run('pcwav-encode.pl',['s2basic',basic,wav,'TEST',value],False)
            run('pcwav-encode.pl',['s1bin',source,wav,'TEST','0x9000'],True)
            for option in ('--skip-ms','--skip-samples'):
                for value in ('0','0x0'):
                    run('pcwav-decode.pl',['s1bin',option,value,wav,out],True)
                    self.assertEqual(out.read_bytes(), source.read_bytes())
                for value in ('','-1','abc','999999999'):
                    run('pcwav-decode.pl',['s1bin',option,value,wav,out],False)
                run('pcwav-decode.pl',['s1bin',option,wav,out],False)
            # Damaged Binary WAV must fail without creating an output file.
            out.unlink()
            code = "use PCWAV::Binary::S1Encode; use PCWAV::WavWriter; my @p=PCWAV::Binary::S1Encode::build_payload(addr=>0,bytes=>[1..121]); $p[-1]^=1; PCWAV::WavWriter::write_wav_file($ARGV[0],PCWAV::Binary::S1Encode::payload_to_pcm(@p));"
            subprocess.run(['perl','-I'+str(TOOLS.parent/'src'),'-e',code,str(wav)],check=True)
            run('pcwav-decode.pl',['s1bin',wav,out],False)
            self.assertFalse(out.exists())


if __name__ == '__main__':
    unittest.main()
