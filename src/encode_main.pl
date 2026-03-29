use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/PCWAV";
use lib "$FindBin::Bin/..";
use PCWAV::Common;
use PCWAV::Binary::S1Encode;

sub usage {
    die <<'USAGE';
usage:
  perl src/encode_main.pl s1bin [--addr 0000] [--name FNAME] input.bin output.wav
USAGE
}

sub main {
    my @args = @ARGV;
    usage() unless @args >= 1;
    my $mode = shift @args;
    die "only 's1bin' is implemented now\n" unless $mode eq 's1bin';

    my %opt = (addr => 0x0000, name => 'FNAME');

    while (@args > 2) {
        my $k = shift @args;
        if ($k eq '--addr') {
            $opt{addr} = PCWAV::Common::parse_num(shift @args);
        } elsif ($k eq '--name') {
            $opt{name} = shift @args;
        } else {
            die "unknown option: $k\n";
        }
    }

    usage() unless @args == 2;
    my ($input, $output) = @args;

    my $data = PCWAV::Common::read_file_bin($input);
    my @bytes = PCWAV::Common::bytes_from_scalar($data);
    my @payload = PCWAV::Binary::S1Encode::build_payload(
        addr  => $opt{addr},
        name  => $opt{name},
        bytes => \@bytes,
    );
    my $pcm = PCWAV::Binary::S1Encode::payload_to_pcm(@payload);
    PCWAV::WavWriter::write_wav_file($output, $pcm);

    print "wrote $output\n";
}

main();
