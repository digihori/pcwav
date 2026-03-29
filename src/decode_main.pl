use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";

die <<'MSG';
decode side is not implemented yet.

planned subcommands:
  perl src/decode_main.pl raw input.wav output.bin
  perl src/decode_main.pl bin --format s1 input.wav output.bin
  perl src/decode_main.pl basic --format s1 input.wav output.bas
MSG
