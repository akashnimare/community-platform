package DDGC::DB::Result::Token::Language::Translation::Vote;

use DBIx::Class::Candy -components => [ 'TimeStamp', 'InflateColumn::DateTime', 'InflateColumn::Serializer', 'EncodedColumn' ];

table 'token_language_translation_vote';

column id => {
	data_type => 'bigint',
	is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
	data_type => 'bigint',
	is_nullable => 0,
};

column token_language_translation_id => {
	data_type => 'bigint',
	is_nullable => 0,
};

column created => {
	data_type => 'timestamp with time zone',
	set_on_create => 1,
};

column updated => {
	data_type => 'timestamp with time zone',
	set_on_create => 1,
	set_on_update => 1,
};

unique_constraint [qw/ token_language_translation_id users_id /];

belongs_to 'user', 'DDGC::DB::Result::User', 'users_id';
belongs_to 'token_language_translation', 'DDGC::DB::Result::Token::Language::Translation', 'token_language_translation_id';

use overload '""' => sub {
	my $self = shift;
	return 'Token-Language-Translation-Vote #'.$self->id;
}, fallback => 1;

1;
