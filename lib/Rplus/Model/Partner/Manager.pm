package Rplus::Model::Partner::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::Partner;

sub object_class { 'Rplus::Model::Partner' }

__PACKAGE__->make_manager_methods('partners');

1;

