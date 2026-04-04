use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/PCWAV";
use lib "$FindBin::Bin/..";

use PCWAV::Common;
use PCWAV::WavReader;
use PCWAV::PcmNormalize;
use PCWAV::RawDecode;
use PCWAV::Binary::S1Decode;
use PCWAV::Basic::S1Decode;
use PCWAV::Basic::S2Decode;
use PCWAV::Binary::OldDecode;
use PCWAV::Basic::OldDecode;

sub usage {
    die <<'MSG';
usage:
  perl src/decode_main.pl raw      input.wav output.bin
  perl src/decode_main.pl s1bin    [--skip-ms 1000] [--skip-samples N] input.wav output.bin
  perl src/decode_main.pl s1basic  [--skip-ms 1000] [--skip-samples N] input.wav output.bas
  perl src/decode_main.pl s2basic  [--skip-ms 1000] [--skip-samples N] input.wav output.bas
  perl src/decode_main.pl oldbin   [--skip-ms 1000] [--skip-samples N] input.wav output.bin
  perl src/decode_main.pl oldbasic [--skip-ms 1000] [--skip-samples N] input.wav output.bas
MSG
}

sub decode_raw {
    my ($input, $output) = @_;

    my $wav = PCWAV::WavReader::read_wav($input);
    my $pcm = PCWAV::PcmNormalize::normalize_to_mono_s16($wav);

    my @bytes = PCWAV::RawDecode::decode_samples_to_bytes(
        $pcm->{sample_rate},
        $pcm->{samples},
    );

    my $data = join '', map { chr($_) } @bytes;
    PCWAV::Common::write_file_bin($output, $data);
    print "wrote $output\n";
}

sub _parse_decode_options_and_decode_raw {
    my (@args) = @_;

    my %opt = (
        skip_ms      => 1000,
        skip_samples => 0,
    );

    while (@args > 2) {
        my $k = shift @args;
        if ($k eq '--skip-ms') {
            $opt{skip_ms} = PCWAV::Common::parse_num(shift @args);
        }
        elsif ($k eq '--skip-samples') {
            $opt{skip_samples} = PCWAV::Common::parse_num(shift @args);
        }
        else {
            die "unknown option: $k\n";
        }
    }

    usage() unless @args == 2;
    my ($input, $output) = @args;

    my $wav = PCWAV::WavReader::read_wav($input);
    my $pcm = PCWAV::PcmNormalize::normalize_to_mono_s16($wav);

    my @samples = @{$pcm->{samples}};
    my $skip_samples = $opt{skip_samples} || int($pcm->{sample_rate} * ($opt{skip_ms} / 1000.0));

    if ($skip_samples > 0) {
        die "skip exceeds sample count\n" if $skip_samples >= @samples;
        @samples = @samples[$skip_samples .. $#samples];
    }

    my @raw = PCWAV::RawDecode::decode_samples_to_bytes(
        $pcm->{sample_rate},
        \@samples,
    );

    return ($output, \@raw);
}

sub decode_s1bin {
    my (@args) = @_;

    my ($output, $raw_ref) = _parse_decode_options_and_decode_raw(@args);
    my $info = PCWAV::Binary::S1Decode::find_and_extract($raw_ref);

    my $data = join '', map { chr($_) } @{$info->{body_bytes}};
    PCWAV::Common::write_file_bin($output, $data);

    print "wrote $output\n";
    printf "offset: %d\n", $info->{offset};
    printf "name: %s\n", $info->{name};
    printf "addr: %04X\n", $info->{addr};
    printf "length: %d\n", $info->{length};
}

sub decode_s1basic {
    my (@args) = @_;

    my ($output, $raw_ref) = _parse_decode_options_and_decode_raw(@args);
    my $info = PCWAV::Basic::S1Decode::find_and_extract_basic($raw_ref);
    my $text = PCWAV::Basic::S1Decode::decode_s1_basic_body($info->{body_bytes});

    PCWAV::Common::write_file_bin($output, $text);

    print "wrote $output\n";
    printf "offset: %d\n", $info->{offset};
    printf "name: %s\n", $info->{name};
}

sub decode_s2basic {
    my (@args) = @_;

    my ($output, $raw_ref) = _parse_decode_options_and_decode_raw(@args);

    my $info = PCWAV::Basic::S2Decode::find_and_extract_basic($raw_ref);
    my $text = PCWAV::Basic::S2Decode::decode_s2_basic_body($info->{body_bytes});

    PCWAV::Common::write_file_bin($output, $text);

    print "wrote $output\n";
    printf "offset: %d\n", $info->{offset};
    printf "type: %02X\n", $info->{type};
    printf "name: %s\n",  $info->{name};
}

sub decode_oldbin {
    my (@args) = @_;

    my ($output, $raw_ref) = _parse_decode_options_and_decode_raw(@args);
    my $info = PCWAV::Binary::OldDecode::find_and_extract($raw_ref);

    my $data = join '', map { chr($_) } @{$info->{body_bytes}};
    PCWAV::Common::write_file_bin($output, $data);

    print "wrote $output\n";
    printf "name: %s\n", $info->{filename};
    printf "addr: %04X\n", $info->{start_addr};
    printf "end_offset: %04X\n", $info->{end_offset};
    printf "end_addr: %04X\n", $info->{end_addr};
    printf "length: %d\n", $info->{size};
}

sub decode_oldbasic {
    my (@args) = @_;

    my ($output, $raw_ref) = _parse_decode_options_and_decode_raw(@args);
    my ($text, $info) = PCWAV::Basic::OldDecode::decode_payload($raw_ref);

    PCWAV::Common::write_file_bin($output, $text);

    print "wrote $output\n";
    printf "name: %s\n", $info->{filename};
    printf "password: %d\n", $info->{password} ? 1 : 0;
}

sub main {
    my @args = @ARGV;
    usage() unless @args >= 3;

    my $mode = shift @args;

    if    ($mode eq 'raw')      { usage() unless @args == 2; decode_raw(@args); }
    elsif ($mode eq 's1bin')    { decode_s1bin(@args); }
    elsif ($mode eq 's1basic')  { decode_s1basic(@args); }
    elsif ($mode eq 's2basic')  { usage() unless @args >= 2; decode_s2basic(@args); }
    elsif ($mode eq 'oldbin')   { decode_oldbin(@args); }
    elsif ($mode eq 'oldbasic') { decode_oldbasic(@args); }
    else {
        die "unknown mode: $mode\n";
    }
}

main();