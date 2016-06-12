package Rplus::Model::User;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'users',

    columns => [
        id       => { type => 'serial', not_null => 1 },
        login    => { type => 'varchar', not_null => 1 },
        password => { type => 'varchar', not_null => 1 },
        add_date => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        del_date => { type => 'timestamp with time zone' },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

