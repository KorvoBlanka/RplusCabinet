package Rplus::Model::Billing;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'billing',

    columns => [
        id         => { type => 'bigserial', not_null => 1 },
        date       => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        sum        => { type => 'integer', not_null => 1 },
        state      => { type => 'integer', default => '0', not_null => 1 },
        account_id => { type => 'integer' },
        provider   => { type => 'varchar', remarks => 'платежная система, через которую проводится счет (null если списание)' },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

