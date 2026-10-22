use strict;
use warnings;
use Test::More;
use lib 'src';
use PCWAV::Common;
use PCWAV::Binary::S1Encode;
use PCWAV::Binary::S1Decode;

# Independent wire-format oracle. No production checksum/swap helpers.
sub swap { my ($b) = @_; return (($b % 16) * 16) + int($b / 16); }
sub sumwire {
    my $s = 0;
    for (@_) {
        $s += $_ % 16;
        $s = ($s + 1) % 256 if $s > 255;
        $s = ($s + int($_ / 16)) % 256;
    }
    return swap($s);
}
sub fixture {
    my ($data, $addr) = @_;
    my $m = @$data - 1;
    my @name = (0, 84, 83, 69, 84, 0, 0, 245); # TEST reversed
    my @meta = (0,0,0,0,int($addr/256),$addr%256,int($m/256),$m%256);
    my @p = (103,@name,sumwire(@name),@meta,sumwire(@meta));
    my @raw = map { swap($_) } @$data;
    while (@raw >= 120) { my @c = splice @raw,0,120; push @p,@c,sumwire(@c); }
    push @p,@raw,255,255,sumwire(@raw,255);
    return @p;
}
sub rejected {
    my ($p,$label) = @_;
    my $ok = eval { PCWAV::Binary::S1Decode::find_and_extract($p); 1 };
    ok(!$ok, $label);
}
for my $len (1,119,120,121,240,4112,65536) {
    my @data = map { ($_ * 73 + 19) % 256 } 0..$len-1;
    my @expected = fixture(\@data,0);
    my @actual = PCWAV::Binary::S1Encode::build_payload(bytes=>\@data,addr=>0,name=>'TEST');
    is_deeply(\@actual,\@expected,"independent payload length $len");
    my $info = PCWAV::Binary::S1Decode::find_and_extract(\@expected);
    is($info->{length},$len,"declared length $len");
    is_deeply($info->{body_bytes},\@data,"decoded bytes $len");
    is($info->{footer_ok},1,"footer verified $len");
    for my $idx (0,9,18,$#expected) {
        my @bad = @expected; $bad[$idx] ^= 1;
        rejected(\@bad,"corrupt position $idx length $len");
    }
    if ($len >= 120) {
        my @bad = @expected; $bad[139] ^= 1;
        rejected(\@bad,"corrupt full chunk length $len");
    }
    for my $cut (grep { $_ < @expected } (1,9,18,19,20,100,139,140,scalar(@expected)-3,scalar(@expected)-1)) {
        my @bad = @expected[0..$cut-1];
        rejected(\@bad,"truncated at $cut length $len");
    }
    my @bad = @expected; $bad[-3]=0;
    rejected(\@bad,"missing terminator length $len");
    if ($len % 120) {
        @bad=@expected; $bad[-1]=sumwire(255);
        rejected(\@bad,"legacy tail rejected length $len") if $bad[-1] != $expected[-1];
    }
}
for my $case ([65535,1,1],[65535,2,0],[0,65536,1],[1,65536,0],[-1,1,0],[65536,1,0],[0,65537,0]) {
    my ($addr,$len,$valid)=@$case;
    my @data=(1)x$len;
    my $ok=eval { PCWAV::Binary::S1Encode::build_payload(addr=>$addr,bytes=>\@data); 1 };
    is(!!$ok,!!$valid,"range $addr/$len");
}
my @bad_range=fixture([(1)x121],65535);
rejected(\@bad_range,'decoder range overflow with valid metadata checksum');
for my $case (['0',0],['123',123],['0x9000',36864],['0XFF',255],['0010',10]) {
    is(PCWAV::Common::parse_num($case->[0]),$case->[1],"parse $case->[0]");
}
for my $s (undef,'','-1','1.5','abc','0x','1e3',' 1','1 ','9007199254740992') {
    my $ok=eval { PCWAV::Common::parse_num($s);1 };
    ok(!$ok,'reject invalid number '.(defined $s ? $s : 'undef'));
}
done_testing();
