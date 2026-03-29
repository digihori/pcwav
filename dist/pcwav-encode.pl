#!/usr/bin/perl
use strict;
use warnings;

# ===== BEGIN src/PCWAV/Common.pm =====
package PCWAV::Common;

sub read_file_bin {
    my ($path) = @_;
    open my $fh, '<', $path or die "cannot open $path: $!";
    binmode $fh;
    local $/;
    my $data = <$fh>;
    close $fh;
    return $data;
}

sub write_file_bin {
    my ($path, $data) = @_;
    open my $fh, '>', $path or die "cannot open $path: $!";
    binmode $fh;
    print {$fh} $data;
    close $fh;
}

sub bytes_from_scalar {
    my ($data) = @_;
    return map { ord($_) } split //, $data;
}

sub nibswap {
    my ($v) = @_;
    return (($v >> 4) | (($v << 4) & 0xF0)) & 0xFF;
}

sub checksum_old_logical {
    my (@bytes) = @_;
    my $sum = 0;
    for my $b (@bytes) {
        $sum += (($b & 0xF0) >> 4);
        $sum = ($sum + 1) & 0xFF if $sum > 0xFF;
        $sum = ($sum + ($b & 0x0F)) & 0xFF;
    }
    return $sum & 0xFF;
}

sub checksum_s1_logical {
    my (@bytes) = @_;
    my $sum = 0;
    for my $b (@bytes) {
        $sum += ($b & 0x0F);
        $sum = ($sum + 1) & 0xFF if $sum > 0xFF;
        $sum = ($sum + (($b >> 4) & 0x0F)) & 0xFF;
    }
    return $sum & 0xFF;
}

sub parse_hex_addr {
    my ($s) = @_;
    die "address is required\n" unless defined $s && length $s;
    return hex($1) if $s =~ /^\$([0-9A-Fa-f]+)$/;
    return hex($1) if $s =~ /^0x([0-9A-Fa-f]+)$/i;
    return hex($s) if $s =~ /^[0-9A-Fa-f]+$/ && $s =~ /[A-Fa-f]/;
    return int($s) if $s =~ /^[0-9]+$/;
    die "invalid address: $s\n";
}

1;

# ===== END src/PCWAV/Common.pm =====

# ===== BEGIN src/PCWAV/WavWriter.pm =====
package PCWAV::WavWriter;

sub w1_s1 {
    return "\xff\x00" x 8;
}

sub w0_s1 {
    return "\xff\xff\x00\x00" x 4;
}

sub encode_byte_s1 {
    my ($v) = @_;
    my $w1 = w1_s1();
    my $w0 = w0_s1();

    my $out = '';
    $out .= $w0;
    $out .= (($v & 0x01) ? $w1 : $w0);
    $out .= (($v & 0x02) ? $w1 : $w0);
    $out .= (($v & 0x04) ? $w1 : $w0);
    $out .= (($v & 0x08) ? $w1 : $w0);
    $out .= $w1;
    $out .= $w0;
    $out .= (($v & 0x10) ? $w1 : $w0);
    $out .= (($v & 0x20) ? $w1 : $w0);
    $out .= (($v & 0x40) ? $w1 : $w0);
    $out .= (($v & 0x80) ? $w1 : $w0);
    $out .= $w1 x 5;
    return $out;
}

sub wav_header_8bit_mono_8k {
    my ($data_len) = @_;
    my $riff_size = $data_len + 44 - 8;

    return
        "RIFF" .
        pack("V", $riff_size) .
        "WAVE" .
        "fmt " .
        pack("V", 16) .
        pack("v", 1) .
        pack("v", 1) .
        pack("V", 8000) .
        pack("V", 8000) .
        pack("v", 1) .
        pack("v", 8) .
        "data" .
        pack("V", $data_len);
}

sub write_wav_file {
    my ($path, $pcm) = @_;
    open my $fh, '>', $path or die "cannot write $path: $!";
    binmode $fh;
    print {$fh} wav_header_8bit_mono_8k(length($pcm));
    print {$fh} $pcm;
    close $fh;
}

1;

# ===== END src/PCWAV/WavWriter.pm =====

# ===== BEGIN src/PCWAV/Format/S1.pm =====
package PCWAV::Format::S1;

sub build_name_block {
    my ($name) = @_;
    $name //= '';
    $name = uc $name;
    $name =~ s/[^A-Z0-9 ]//g;

    # 実測に合わせた s1 binary 向け 8 バイト名領域
    # 00 + 逆順6文字 + F5
    $name = substr($name, 0, 6) if length($name) > 6;
    my @chars = map { ord($_) } split //, $name;
    @chars = reverse @chars;
    my @block = (0x00, @chars);
    push @block, 0x00 while @block < 7;
    push @block, 0xF5;
    return @block;
}

sub build_binary_meta_block {
    my (%opt) = @_;
    my $addr = $opt{addr} & 0xFFFF;
    my $lenm1 = $opt{len_minus_1} & 0xFFFF;
    return (0x00, 0x00, 0x00, 0x00, ($addr >> 8) & 0xFF, $addr & 0xFF, ($lenm1 >> 8) & 0xFF, $lenm1 & 0xFF);
}

1;

# ===== END src/PCWAV/Format/S1.pm =====

# ===== BEGIN src/PCWAV/Binary/S1Encode.pm =====
package PCWAV::Binary::S1Encode;



sub build_payload {
    my (%opt) = @_;
    my $addr = $opt{addr};
    my $name = $opt{name} // '';
    my @bin  = @{$opt{bytes} || []};
    die "binary data is empty\n" unless @bin;

    my @payload;
    push @payload, 0x67;

    my @name_block = PCWAV::Format::S1::build_name_block($name);
    push @payload, @name_block;
    my $name_sum = PCWAV::Common::checksum_s1_logical(@name_block);
    push @payload, PCWAV::Common::nibswap($name_sum);

    my @meta = PCWAV::Format::S1::build_binary_meta_block(
        addr        => $addr,
        len_minus_1 => scalar(@bin) - 1,
    );
    push @payload, @meta;
    my $meta_sum = PCWAV::Common::checksum_s1_logical(@meta);
    push @payload, PCWAV::Common::nibswap($meta_sum);

    my @chunk;
    for my $b (@bin) {
        push @chunk, PCWAV::Common::nibswap($b);
        if (@chunk == 120) {
            push @payload, @chunk;
            my $sum = PCWAV::Common::checksum_s1_logical(@chunk);
            push @payload, PCWAV::Common::nibswap($sum);
            @chunk = ();
        }
    }
    push @payload, @chunk if @chunk;

    push @payload, 0xFF;
    my $tail_sum = PCWAV::Common::checksum_s1_logical(0xFF);
    push @payload, 0xFF;
    push @payload, PCWAV::Common::nibswap($tail_sum);

    return @payload;
}

sub payload_to_pcm {
    my (@payload) = @_;
    my $pcm = '';
    my $w1 = PCWAV::WavWriter::w1_s1();
    for (1 .. 0x400) {
        $pcm .= $w1;
    }
    for my $b (@payload) {
        $pcm .= PCWAV::WavWriter::encode_byte_s1($b);
    }
    return $pcm;
}

1;

# ===== END src/PCWAV/Binary/S1Encode.pm =====

package main;

# ===== BEGIN src/encode_main.pl =====


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

# ===== END src/encode_main.pl =====
