package PCWAV::RawDecode;
use strict;
use warnings;

sub decode_samples_to_bytes {
    my ($sample_rate, $samples_ref) = @_;
    my @samples = @$samples_ref;

    my $level = 0;
    my $is_sync = 1;
    my $sync_count = 0;
    my $gap_count0 = int($sample_rate / 500);
    my $gap_count = 0;
    my $read_bit = 0x01;
    my $data = 0;
    my $lcount = 0;
    my @z = (0) x 9;

    my @out;
    my $threshold = 20 * 256;
    my $tap = int($sample_rate / 4000 + 0.5);
    $tap = 8 if $tap > 8;

    for my $s (@samples) {
        # cload.pl と同じ扱いにするため、
        # 現在サンプルは z[0] に入れてから y を計算する
        $z[0] = $s;
        my $y = $z[0] - $z[$tap];

        if ($y > $threshold || $y < -$threshold) {
            $level = 0;
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
                    $is_sync = 0;
                    $gap_count = int($gap_count0 * 1.5);
                } else {
                    $sync_count++;
                    if ($sync_count > 1000 && $read_bit == 0x10) {
                        $read_bit = 0x01;
                        $data = 0;
                    }
                }
            }
        } else {
            if (--$gap_count <= 0) {
                $gap_count = $gap_count0;
                $data |= $read_bit if $level;
                $read_bit *= 2;

                if ($read_bit == 0x100) {
                    $is_sync = 1;
                    $sync_count = 0;
                    push @out, $data & 0xFF;
                    $data = 0;
                    $read_bit = 0x01;
                }

                if ($read_bit == 0x10) {
                    $is_sync = 1;
                    $sync_count = 0;
                }
            }
        }

        # cload.pl の continue 節に合わせる
        $z[8]=$z[7];
        $z[7]=$z[6];
        $z[6]=$z[5];
        $z[5]=$z[4];
        $z[4]=$z[3];
        $z[3]=$z[2];
        $z[2]=$z[1];
        $z[1]=$z[0];
    }

    return @out;
}

1;
