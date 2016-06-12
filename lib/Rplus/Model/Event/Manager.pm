package Rplus::Model::Event::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::Event;

sub object_class { 'Rplus::Model::Event' }

__PACKAGE__->make_manager_methods('events');

1;

