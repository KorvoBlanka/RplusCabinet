package Rplus::Model::Partner;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'partners',

    columns => [
        id            => { type => 'serial', not_null => 1 },
        name          => { type => 'varchar', not_null => 1 },
        code          => { type => 'varchar', not_null => 1 },
        active        => { type => 'boolean', default => 'true', not_null => 1 },
        add_date      => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        balance_bonus => { type => 'integer', default => 120, not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

