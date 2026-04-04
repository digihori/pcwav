package PCWAV::WavWriter;
use strict;
use warnings;

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

sub w1_old { return "\xff\x00" x 8; }
sub w0_old { return "\xff\xff\x00\x00" x 4; }

sub encode_byte_old {
    my ($v) = @_;
    my $w1 = w1_old();
    my $w0 = w0_old();
    my $out = '';
    $out .= $w0;
    $out .= (($v & 0x10) ? $w1 : $w0);
    $out .= (($v & 0x20) ? $w1 : $w0);
    $out .= (($v & 0x40) ? $w1 : $w0);
    $out .= (($v & 0x80) ? $w1 : $w0);
    $out .= $w1 x 4;
    $out .= $w0;
    $out .= (($v & 0x01) ? $w1 : $w0);
    $out .= (($v & 0x02) ? $w1 : $w0);
    $out .= (($v & 0x04) ? $w1 : $w0);
    $out .= (($v & 0x08) ? $w1 : $w0);
    $out .= $w1 x 5;
    return $out;
}

1;
