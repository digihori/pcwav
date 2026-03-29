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

package main;

# ===== BEGIN src/decode_main.pl =====

die <<'MSG';
decode side is not implemented yet.

planned subcommands:
  perl src/decode_main.pl raw input.wav output.bin
  perl src/decode_main.pl bin --format s1 input.wav output.bin
  perl src/decode_main.pl basic --format s1 input.wav output.bas
MSG

# ===== END src/decode_main.pl =====
