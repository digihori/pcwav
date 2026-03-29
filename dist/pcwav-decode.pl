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

# ===== BEGIN src/PCWAV/WavReader.pm =====
package PCWAV::WavReader;

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
# ===== END src/PCWAV/WavReader.pm =====

# ===== BEGIN src/PCWAV/PcmNormalize.pm =====
package PCWAV::PcmNormalize;

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

# ===== END src/PCWAV/PcmNormalize.pm =====

# ===== BEGIN src/PCWAV/RawDecode.pm =====
package PCWAV::RawDecode;

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
# ===== END src/PCWAV/RawDecode.pm =====

# ===== BEGIN src/PCWAV/Binary/S1Decode.pm =====
package PCWAV::Binary::S1Decode;

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

# ===== END src/PCWAV/Binary/S1Decode.pm =====

package main;

# ===== BEGIN src/decode_main.pl =====





sub usage {
    die <<'MSG';
usage:
  perl src/decode_main.pl raw input.wav output.bin
  perl src/decode_main.pl s1bin [--skip-ms 1000] [--skip-samples N] input.wav output.bin
MSG
}

sub decode_raw {
    my ($input, $output) = @_;
    my $wav = PCWAV::WavReader::read_wav($input);
    my $pcm = PCWAV::PcmNormalize::normalize_to_mono_s16($wav);
    my @bytes = PCWAV::RawDecode::decode_samples_to_bytes(
        $pcm->{sample_rate},
        $pcm->{samples},
    );
    my $data = join '', map { chr($_) } @bytes;
    PCWAV::Common::write_file_bin($output, $data);
    print "wrote $output\n";
}

sub decode_s1bin {
    my (@args) = @_;
    my %opt = (skip_ms => 1000, skip_samples => 0);

    while (@args > 2) {
        my $k = shift @args;
        if ($k eq '--skip-ms') {
            $opt{skip_ms} = PCWAV::Common::parse_num(shift @args);
        } elsif ($k eq '--skip-samples') {
            $opt{skip_samples} = PCWAV::Common::parse_num(shift @args);
        } else {
            die "unknown option: $k\n";
        }
    }

    usage() unless @args == 2;
    my ($input, $output) = @args;

    my $wav = PCWAV::WavReader::read_wav($input);
    my $pcm = PCWAV::PcmNormalize::normalize_to_mono_s16($wav);

    my @samples = @{$pcm->{samples}};
    my $skip_samples = $opt{skip_samples} || int($pcm->{sample_rate} * ($opt{skip_ms} / 1000.0));
    if ($skip_samples > 0) {
        die "skip exceeds sample count\n" if $skip_samples >= @samples;
        @samples = @samples[$skip_samples .. $#samples];
    }

    my @raw = PCWAV::RawDecode::decode_samples_to_bytes(
        $pcm->{sample_rate},
        \@samples,
    );
    my $info = PCWAV::Binary::S1Decode::find_and_extract(\@raw);
    my $data = join '', map { chr($_) } @{$info->{body_bytes}};
    PCWAV::Common::write_file_bin($output, $data);

    print "wrote $output\n";
    printf "offset: %d\n", $info->{offset};
    printf "name: %s\n", $info->{name};
    printf "addr: %04X\n", $info->{addr};
    printf "length: %d\n", $info->{length};
}

sub main {
    my @args = @ARGV;
    usage() unless @args >= 3;
    my $mode = shift @args;

    if ($mode eq 'raw') {
        usage() unless @args == 2;
        decode_raw(@args);
    } elsif ($mode eq 's1bin') {
        decode_s1bin(@args);
    } else {
        die "unknown mode: $mode\n";
    }
}

main();

# ===== END src/decode_main.pl =====
