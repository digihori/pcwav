use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/PCWAV";
use lib "$FindBin::Bin/..";

use PCWAV::Common;
use PCWAV::WavWriter;
use PCWAV::Binary::S1Encode;
use PCWAV::Basic::S1Encode;
use PCWAV::Basic::S2Encode;
use PCWAV::Binary::OldEncode;
use PCWAV::Basic::OldEncode;

sub usage {
    die <<'MSG';
usage:
  perl src/encode_main.pl s1bin    input.bin output.wav [filename] [addr]
  perl src/encode_main.pl s1basic  input.bas output.wav [filename]
  perl src/encode_main.pl s2basic  input.bas output.wav [filename]
  perl src/encode_main.pl oldbin   input.bin output.wav [filename] [addr]
  perl src/encode_main.pl oldbasic input.bas output.wav [filename]
MSG
}

sub encode_s1bin {
    my ($input, $output, $filename, $addr) = @_;

    $filename = defined $filename ? $filename : '';
    $addr     = defined $addr ? PCWAV::Common::parse_num($addr) : 0xC000;

    my $bin   = PCWAV::Common::read_file_bin($input);
    my @bytes = PCWAV::Common::bytes_from_scalar($bin);

    my @payload = PCWAV::Binary::S1Encode::build_payload(
        addr  => $addr,
        name  => $filename,
        bytes => \@bytes,
    );

    my $pcm = PCWAV::Binary::S1Encode::payload_to_pcm(@payload);
    PCWAV::WavWriter::write_wav_file($output, $pcm);
    print "wrote $output\n";
}

sub encode_s1basic {
    my ($input, $output, $filename) = @_;

    $filename = defined $filename ? $filename : '';

    my $text = PCWAV::Common::read_file_bin($input);
    my $payload = PCWAV::Basic::S1Encode::encode_s1_basic_text($text, $filename);
    my @payload_bytes = PCWAV::Common::bytes_from_scalar($payload);

    my $pcm = PCWAV::Binary::S1Encode::payload_to_pcm(@payload_bytes);
    PCWAV::WavWriter::write_wav_file($output, $pcm);
    print "wrote $output\n";
}

sub encode_s2basic {
    my ($input, $output, $filename, $type) = @_;
    $filename = defined $filename ? $filename : '';

    my $type_num = defined $type ? PCWAV::Common::parse_num($type) : 0x27;

    my $text = PCWAV::Common::read_file_bin($input);
    my $payload = PCWAV::Basic::S2Encode::encode_s2_basic_text($text, $filename, $type_num);

    my @payload_bytes = PCWAV::Common::bytes_from_scalar($payload);
    my $pcm = PCWAV::Binary::S1Encode::payload_to_pcm(@payload_bytes);

    PCWAV::WavWriter::write_wav_file($output, $pcm);
    print "wrote $output\n";
}

sub encode_oldbin {
    my ($input, $output, $filename, $addr) = @_;

    $filename = defined $filename ? $filename : '';
    $addr     = defined $addr ? PCWAV::Common::parse_num($addr) : 0xC000;

    my $bin   = PCWAV::Common::read_file_bin($input);
    my @bytes = PCWAV::Common::bytes_from_scalar($bin);

    my $payload = PCWAV::Binary::OldEncode::encode_payload(
        filename   => $filename,
        start_addr => $addr,
        body       => \@bytes,
    );
    my @payload_bytes = PCWAV::Common::bytes_from_scalar($payload);

    my $pcm = PCWAV::Binary::OldEncode::payload_to_pcm(@payload_bytes);
    PCWAV::WavWriter::write_wav_file($output, $pcm);
    print "wrote $output\n";
}

sub encode_oldbasic {
    my ($input, $output, $filename) = @_;

    $filename = defined $filename ? $filename : '';

    my $text = PCWAV::Common::read_file_bin($input);
    my $payload = PCWAV::Basic::OldEncode::encode_payload(
        text     => $text,
        filename => $filename,
        password => 0,
    );
    my @payload_bytes = PCWAV::Common::bytes_from_scalar($payload);

    my $pcm = PCWAV::Binary::OldEncode::payload_to_pcm(@payload_bytes);
    PCWAV::WavWriter::write_wav_file($output, $pcm);
    print "wrote $output\n";
}

sub main {
    my @args = @ARGV;
    usage() unless @args >= 3;

    my $mode = shift @args;

    if    ($mode eq 's1bin')    { usage() unless @args >= 2; encode_s1bin(@args); }
    elsif ($mode eq 's1basic')  { usage() unless @args >= 2; encode_s1basic(@args); }
    elsif ($mode eq 's2basic')  { usage() unless @args >= 2; encode_s2basic(@args); }
    elsif ($mode eq 'oldbin')   { usage() unless @args >= 2; encode_oldbin(@args); }
    elsif ($mode eq 'oldbasic') { usage() unless @args >= 2; encode_oldbasic(@args); }
    else {
        die "unknown mode: $mode\n";
    }
}

main();