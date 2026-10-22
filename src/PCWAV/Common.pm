package PCWAV::Common;
use strict;
use warnings;

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

sub bytes_to_scalar {
    my (@bytes) = @_;
    return pack('C*', @bytes);
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

# CLI integers: decimal or explicitly prefixed hexadecimal, never signed.
sub parse_num {
    my ($s) = @_;
    die "number is required\n" unless defined $s && length $s;
    die "invalid non-negative integer: $s\n"
        unless $s =~ /\A(?:[0-9]+|0[xX][0-9A-Fa-f]+)\z/;
    # Accumulate with an exact-integer bound, avoiding overflow/rounding.
    my $base = $s =~ s/\A0[xX]// ? 16 : 10;
    my $n = 0;
    for my $digit (split //, $s) {
        my $v = $digit =~ /[0-9]/ ? ord($digit) - 48 : ord(lc $digit) - 87;
        die "integer is too large\n" if $n > int((9007199254740991 - $v) / $base);
        $n = $n * $base + $v;
    }
    return $n;
}

sub validate_binary_range {
    my ($addr, $len) = @_;
    die "address must be in 0x0000..0xFFFF\n"
        unless defined $addr && $addr =~ /\A[0-9]+\z/ && $addr <= 0xFFFF;
    die "binary length must be in 1..65536 bytes\n"
        unless defined $len && $len =~ /\A[0-9]+\z/ && $len >= 1 && $len <= 65536;
    die "binary range exceeds 0xFFFF\n" if $addr + $len > 65536;
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
