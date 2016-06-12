#!/usr/bin/perl

use Digest::MD5 qw(md5_hex);

my $mrh_login = "rplusmgmt";
my $mrh_pass1 = "ckj;ysqgfhjkm1";
my $inv_id = 1000;               

my $crc = md5_hex("$mrh_login:$inv_id:$mrh_pass1");

# форма оплаты товара
# payment form
print "$crc\n";
