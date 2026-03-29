package PCWAV::WavReader;
use strict;
use warnings;

sub read_wav {
    my ($path) = @_;

    open my $fh, '<', $path or die "cannot open $path: $!";
    binmode $fh;

    read($fh, my $riff, 4) == 4 or die "short read: RIFF\n";
    die "WAV format error: no RIFF\n" unless $riff eq 'RIFF';
    my $riff_size = _read_u32le($fh);

    read($fh, my $wave, 4) == 4 or die "short read: WAVE\n";
    die "WAV format error: no WAVE\n" unless $wave eq 'WAVE';

    my %fmt;
    my $data;

    while (!eof($fh)) {
        my $n = read($fh, my $tag, 4);
        last if !$n;
        die "truncated chunk tag\n" unless $n == 4;
        my $len = _read_u32le($fh);

        if ($tag eq 'fmt ') {
            my $buf = '';
            read($fh, $buf, $len) == $len or die "truncated fmt chunk\n";
            my @b = map { ord($_) } split //, $buf;
            die "fmt chunk too short\n" if @b < 16;

            $fmt{audio_format}    = $b[0]  | ($b[1]  << 8);
            $fmt{channels}        = $b[2]  | ($b[3]  << 8);
            $fmt{sample_rate}     = $b[4]  | ($b[5]  << 8) | ($b[6]  << 16) | ($b[7]  << 24);
            $fmt{byte_rate}       = $b[8]  | ($b[9]  << 8) | ($b[10] << 16) | ($b[11] << 24);
            $fmt{block_align}     = $b[12] | ($b[13] << 8);
            $fmt{bits_per_sample} = $b[14] | ($b[15] << 8);
        }
        elsif ($tag eq 'data') {
            $data = '';
            read($fh, $data, $len) == $len or die "truncated data chunk\n";
        }
        else {
            seek($fh, $len, 1) or die "cannot skip chunk $tag\n";
        }

        if ($len % 2) {
            seek($fh, 1, 1) or die "cannot skip pad byte\n";
        }
    }

    die "unsupported WAV: only PCM supported\n"
        unless ($fmt{audio_format} || 0) == 1;

    die "missing data chunk\n" unless defined $data;

    die "unsupported channel count: $fmt{channels} (supported: 1 or 2)\n"
        unless ($fmt{channels} == 1 || $fmt{channels} == 2);

    die "unsupported bits/sample: $fmt{bits_per_sample} (supported: 8 or 16)\n"
        unless ($fmt{bits_per_sample} == 8 || $fmt{bits_per_sample} == 16);

    die "unsupported sample rate: $fmt{sample_rate}Hz (supported: up to 32000Hz)\n"
        unless ($fmt{sample_rate} <= 32000);

    return {
        channels        => $fmt{channels},
        sample_rate     => $fmt{sample_rate},
        bits_per_sample => $fmt{bits_per_sample},
        data            => $data,
    };
}

sub _read_u32le {
    my ($fh) = @_;
    read($fh, my $buf, 4) == 4 or die "short read: u32\n";
    my @b = map { ord($_) } split //, $buf;
    return $b[0] | ($b[1] << 8) | ($b[2] << 16) | ($b[3] << 24);
}

1;