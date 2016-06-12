package Rplus::Model::Account;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'accounts',

    columns => [
        id          => { type => 'serial', not_null => 1 },
        email       => { type => 'varchar', not_null => 1 },
        password    => { type => 'varchar', not_null => 1 },
        reg_date    => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        balance     => { type => 'integer', default => '0', not_null => 1 },
        name        => { type => 'varchar' },
        del_date    => { type => 'date' },
        user_count  => { type => 'integer', default => 1, not_null => 1 },
        reg_code    => { type => 'varchar', default => 'abc', not_null => 1 },
        mode        => { type => 'varchar', default => 'all', length => 8, not_null => 1, remarks => 'all | sale | rent' },
        location_id => { type => 'integer', not_null => 1, remarks => 'id расположения клиента' },
        options     => { type => 'scalar', default => '{}', not_null => 1, remarks => 'кол-во пользователей, режим, буффер посредников' },
    ],

    primary_key_columns => [ 'id' ],

    unique_key => [ 'email' ],

    allow_inline_column_values => 1,

    foreign_keys => [
        location => {
            class       => 'Rplus::Model::Location',
            key_columns => { location_id => 'id' },
        },
    ],
);

1;

