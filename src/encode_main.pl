use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/PCWAV";
use lib "$FindBin::Bin/..";
use PCWAV::Common;
use PCWAV::Binary::S1;
use PCWAV::WavWriter;
use PCWAV::Format::S1;

sub usage {
    die <<'USAGE';
usage:
  perl src/encode_main.pl bin [--format s1] [--addr 0000] [--name FNAME] input.bin output.wav

defaults:
  --format s1
  --addr   0000
  --name   FNAME

notes:
  - currently implemented: s1 binary encode only
  - future:
      basic --format s1/s2/old
      bin   --format old
USAGE
}

sub main {
    my @args = @ARGV;
    usage() unless @args >= 1;

    my $mode = shift @args;
    die "only 'bin' mode is implemented now\n" unless $mode eq 'bin';

    my %opt = (
        format => 's1',
        addr   => 0x0000,
        name   => 'FNAME',
    );

    while (@args > 2) {
        my $k = shift @args;
        if ($k eq '--format') {
            $opt{format} = shift @args;
        } elsif ($k eq '--addr') {
            $opt{addr} = PCWAV::Common::parse_hex_addr(shift @args);
        } elsif ($k eq '--name') {
            $opt{name} = shift @args;
        } else {
            die "unknown option: $k\n";
        }
    }

    usage() unless @args == 2;
    my ($input, $output) = @args;

    die "only --format s1 is implemented now\n" unless $opt{format} eq 's1';

    my $data = PCWAV::Common::read_file_bin($input);
    my @bytes = PCWAV::Common::bytes_from_scalar($data);

    my @payload = PCWAV::Binary::S1::build_payload(
        addr  => $opt{addr},
        name  => $opt{name},
        bytes => \@bytes,
    );

    my $pcm = PCWAV::Binary::S1::payload_to_pcm(@payload);
    PCWAV::WavWriter::write_wav_file($output, $pcm);

    printf "wrote %s\n", $output;
    printf "format: %s\n", $opt{format};
    printf "addr:   %04X\n", $opt{addr};
    printf "name:   %s\n", $opt{name};
    printf "payload bytes: %d\n", scalar(@payload);
}

main();
