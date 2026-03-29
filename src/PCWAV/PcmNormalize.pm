package PCWAV::PcmNormalize;
use strict;
use warnings;

sub normalize_to_mono_s16 {
    my ($wav) = @_;
    my $bps = $wav->{bits_per_sample};
    my $ch  = $wav->{channels};
    my $raw = $wav->{data};

    my @samples;

    if ($bps == 8) {
        my @u = map { ord($_) } split //, $raw;
        if ($ch == 1) {
            @samples = map { ($_ - 128) * 256 } @u;
        } else {
            for (my $i = 0; $i + 1 < @u; $i += 2) {
                my $l = ($u[$i]   - 128) * 256;
                my $r = ($u[$i+1] - 128) * 256;
                push @samples, int(($l + $r) / 2);
            }
        }
    }
    elsif ($bps == 16) {
        my @b = map { ord($_) } split //, $raw;
        if ($ch == 1) {
            for (my $i = 0; $i + 1 < @b; $i += 2) {
                my $v = $b[$i] | ($b[$i+1] << 8);
                $v -= 65536 if $v >= 32768;
                push @samples, $v;
            }
        } else {
            for (my $i = 0; $i + 3 < @b; $i += 4) {
                my $l = $b[$i]   | ($b[$i+1] << 8);
                my $r = $b[$i+2] | ($b[$i+3] << 8);
                $l -= 65536 if $l >= 32768;
                $r -= 65536 if $r >= 32768;
                push @samples, int(($l + $r) / 2);
            }
        }
    }
    else {
        die "unsupported bits/sample: $bps\n";
    }

    return {
        sample_rate => $wav->{sample_rate},
        samples     => \@samples,
    };
}

1;
