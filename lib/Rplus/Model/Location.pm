package Rplus::Model::Location;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'locations',

    columns => [
        id                => { type => 'integer', not_null => 1 },
        name              => { type => 'varchar' },
        city_guid         => { type => 'varchar', not_null => 1, remarks => 'гео id города' },
        phone_prefix      => { type => 'varchar', not_null => 1 },
        realty_buffer_url => { type => 'varchar', not_null => 1 },
        add_date          => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        delete_date       => { type => 'timestamp with time zone' },
        map               => { type => 'scalar', default => '{}', not_null => 1, remarks => 'координаты центра карты' },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,

    relationships => [
        accounts => {
            class      => 'Rplus::Model::Account',
            column_map => { id => 'location_id' },
            type       => 'one to many',
        },
    ],
);

1;

