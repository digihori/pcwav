package PCWAV::Binary::S1Decode;
use strict;
use warnings;
use PCWAV::Common;

sub find_and_extract {
    my ($bytes_ref) = @_;
    my @bytes = @$bytes_ref;

    for (my $i = 0; $i + 19 < @bytes; $i++) {
        next unless $bytes[$i] == 0x67;

        my @name = @bytes[$i+1 .. $i+8];
        my $name_csum = $bytes[$i+9];
        next unless PCWAV::Common::nibswap(PCWAV::Common::checksum_s1_logical(@name)) == $name_csum;

        my @meta = @bytes[$i+10 .. $i+17];
        my $meta_csum = $bytes[$i+18];
        next unless PCWAV::Common::nibswap(PCWAV::Common::checksum_s1_logical(@meta)) == $meta_csum;

        my $addr = ($meta[4] << 8) | $meta[5];
        my $len  = (($meta[6] << 8) | $meta[7]) + 1;
        PCWAV::Common::validate_binary_range($addr, $len);

        my $pos = $i + 19;
        my @body_raw;
        my $remaining = $len;
        while ($remaining >= 120) {
            die "s1 binary truncated chunk at $pos\n" if $pos + 121 > @bytes;
            my @chunk = @bytes[$pos .. $pos + 119];
            $pos += 120;
            my $sum = $bytes[$pos++];
            my $expect = PCWAV::Common::nibswap(PCWAV::Common::checksum_s1_logical(@chunk));
            die "s1 binary chunk checksum mismatch at " . ($pos - 1) . "\n"
                unless $sum == $expect;
            push @body_raw, @chunk;
            $remaining -= 120;
        }
        die "s1 binary truncated tail at $pos\n" if $pos + $remaining + 3 > @bytes;
        my @partial = $remaining ? @bytes[$pos .. $pos + $remaining - 1] : ();
        push @body_raw, @partial;
        $pos += $remaining;
        die "s1 binary missing FF FF terminator at $pos\n"
            unless $bytes[$pos] == 0xFF && $bytes[$pos+1] == 0xFF;
        my $expect_tail = PCWAV::Common::nibswap(
            PCWAV::Common::checksum_s1_logical(@partial, 0xFF));
        die "s1 binary tail checksum mismatch at " . ($pos + 2) . "\n"
            unless $bytes[$pos+2] == $expect_tail;

        my @body = map { PCWAV::Common::nibswap($_) } @body_raw;

        my @name_chars = @name[1 .. 6];
        @name_chars = reverse grep { $_ != 0x00 } @name_chars;
        my $name_text = join '', map { chr($_) } @name_chars;

        return {
            offset      => $i,
            addr        => $addr,
            length      => $len,
            name        => $name_text,
            body_bytes  => \@body,
            footer_ok   => 1,
        };
    }

    die "s1 binary header not found\n";
}

1;
