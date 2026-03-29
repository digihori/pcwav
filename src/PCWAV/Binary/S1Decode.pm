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

        my $addr = (($meta[4] << 8) | $meta[5]) & 0xFFFF;
        my $len  = ((($meta[6] << 8) | $meta[7]) + 1) & 0xFFFF;

        my $pos = $i + 19;
        my @body_raw;
        my $remaining = $len;

        while ($remaining > 120) {
            last if $pos + 120 >= @bytes;
            my @chunk = @bytes[$pos .. $pos + 119];
            $pos += 120;
            my $sum = $bytes[$pos++];
            my $expect = PCWAV::Common::nibswap(PCWAV::Common::checksum_s1_logical(@chunk));
            next unless $sum == $expect;
            push @body_raw, @chunk;
            $remaining -= 120;
        }

        last if $pos + $remaining - 1 >= @bytes;
        push @body_raw, @bytes[$pos .. $pos + $remaining - 1];
        $pos += $remaining;

        my $footer_ok = 0;
        if ($pos + 2 < @bytes && $bytes[$pos] == 0xFF && $bytes[$pos+1] == 0xFF) {
            $footer_ok = 1;
        }

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
            footer_ok   => $footer_ok,
        };
    }

    die "s1 binary header not found\n";
}

1;
