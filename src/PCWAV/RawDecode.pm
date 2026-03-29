package PCWAV::RawDecode;
use strict;
use warnings;

sub decode_samples_to_bytes {
    my ($sample_rate, $samples_ref) = @_;

    # 念のためここでも保険
    die "unsupported sample rate: ${sample_rate}Hz (supported: up to 32000Hz)\n"
        if $sample_rate > 32000;

    my @samples = @$samples_ref;

    my $level      = 0;
    my $is_sync    = 1;
    my $sync_count = 0;
    my $gap_count0 = int($sample_rate / 500);
    my $gap_count  = 0;
    my $read_bit   = 0x01;
    my $data       = 0;
    my $lcount     = 0;

    my $tap = int($sample_rate / 4000 + 0.5);
    $tap = 1 if $tap < 1;

    my @z = (0) x ($tap + 1);
    my @out;

    my $threshold = 20 * 256;

    for my $s (@samples) {
        $z[0] = $s;
        my $y = $z[0] - $z[$tap];

        if ($y > $threshold || $y < -$threshold) {
            $level  = 0;
            $lcount = 0;
        } else {
            $level = 1 if $lcount > 3;
            $lcount++;
        }

        if ($is_sync) {
            if ($gap_count) {
                $gap_count--;
            } else {
                if ($level == 0) {
                    $is_sync   = 0;
                    $gap_count = int($gap_count0 * 1.5);
                } else {
                    $sync_count++;
                    if ($sync_count > 1000 && $read_bit == 0x10) {
                        $read_bit = 0x01;
                        $data     = 0;
                    }
                }
            }
        } else {
            if (--$gap_count <= 0) {
                $gap_count = $gap_count0;
                $data |= $read_bit if $level;
                $read_bit *= 2;

                if ($read_bit == 0x100) {
                    $is_sync    = 1;
                    $sync_count = 0;
                    push @out, $data & 0xFF;
                    $data     = 0;
                    $read_bit = 0x01;
                }

                if ($read_bit == 0x10) {
                    $is_sync    = 1;
                    $sync_count = 0;
                }
            }
        }

        for (my $i = $tap; $i >= 1; $i--) {
            $z[$i] = $z[$i - 1];
        }
    }

    return @out;
}

1;