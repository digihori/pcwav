package PCWAV::Format::S1;
use strict;
use warnings;

sub build_name_block {
    my ($name) = @_;
    $name //= '';
    $name = uc $name;
    $name =~ s/[^A-Z0-9 ]//g;

    # 実測に合わせた s1 binary 向け 8 バイト名領域
    # 00 + 逆順6文字 + F5
    $name = substr($name, 0, 6) if length($name) > 6;
    my @chars = map { ord($_) } split //, $name;
    @chars = reverse @chars;
    my @block = (0x00, @chars);
    push @block, 0x00 while @block < 7;
    push @block, 0xF5;
    return @block;
}

sub build_binary_meta_block {
    my (%opt) = @_;
    my $addr = $opt{addr} & 0xFFFF;
    my $lenm1 = $opt{len_minus_1} & 0xFFFF;
    return (0x00, 0x00, 0x00, 0x00, ($addr >> 8) & 0xFF, $addr & 0xFF, ($lenm1 >> 8) & 0xFF, $lenm1 & 0xFF);
}

1;
