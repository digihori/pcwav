package PCWAV::Binary::S1Encode;
use strict;
use warnings;
use PCWAV::Common;
use PCWAV::Format::S1;
use PCWAV::WavWriter;

sub build_payload {
    my (%opt) = @_;
    my $addr = $opt{addr};
    my $name = $opt{name} // '';
    my @bin  = @{$opt{bytes} || []};
    die "binary data is empty\n" unless @bin;

    PCWAV::Common::validate_binary_range($addr, scalar @bin);

    my @payload;
    push @payload, 0x67;

    my @name_block = PCWAV::Format::S1::build_name_block($name);
    push @payload, @name_block;
    my $name_sum = PCWAV::Common::checksum_s1_logical(@name_block);
    push @payload, PCWAV::Common::nibswap($name_sum);

    my @meta = PCWAV::Format::S1::build_binary_meta_block(
        addr        => $addr,
        len_minus_1 => scalar(@bin) - 1,
    );
    push @payload, @meta;
    my $meta_sum = PCWAV::Common::checksum_s1_logical(@meta);
    push @payload, PCWAV::Common::nibswap($meta_sum);

    # Keep the final 1..120 bytes for the tail, including exact multiples.
    # PC-1360K CSAVE M: only non-final chunks have a separate checksum.
    my @chunk = map { PCWAV::Common::nibswap($_) } @bin;
    while (@chunk > 120) {
        my @full = splice @chunk, 0, 120;
        push @payload, @full;
        my $sum = PCWAV::Common::checksum_s1_logical(@full);
        push @payload, PCWAV::Common::nibswap($sum);
    }
    push @payload, @chunk;

    push @payload, 0xFF;
    my $tail_sum = PCWAV::Common::checksum_s1_logical(@chunk, 0xFF);
    push @payload, 0xFF;
    push @payload, PCWAV::Common::nibswap($tail_sum);

    return @payload;
}

sub payload_to_pcm {
    my (@payload) = @_;
    my $pcm = '';
    my $w1 = PCWAV::WavWriter::w1_s1();
    for (1 .. 0x800) {
        $pcm .= $w1;
    }
    for my $b (@payload) {
        $pcm .= PCWAV::WavWriter::encode_byte_s1($b);
    }
    return $pcm;
}

1;
