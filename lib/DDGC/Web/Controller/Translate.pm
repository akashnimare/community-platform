package DDGC::Web::Controller::Translate;
use Moose;
use namespace::autoclean;

use DDGC::Config;
use Data::Printer;

BEGIN {extends 'Catalyst::Controller'; }

sub base :Chained('/base') :PathPart('translate') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
	if ($c->user && !$c->user->user_languages) {
		$c->response->redirect($c->chained_uri('Translate','index'));
		return $c->detach;
	}
	$c->stash->{title} = 'Translations';
}

sub do :Chained('base') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
}

sub index :Chained('do') :Args(0) {
    my ( $self, $c ) = @_;
	$c->stash->{token_domains} = $c->d->rs('Token::Domain')->search({});
}

sub logged_in :Chained('base') :PathPart('') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
	if (!$c->user) {
		$c->response->redirect($c->chained_uri('Translate','index'));
		return $c->detach;
	}
}

sub tokenlanguage :Chained('logged_in') :Args(1) {
	my ( $self, $c, $token_language_id ) = @_;
	$self->save_translate_params($c) if ($c->req->params->{save_translation});
	$c->stash->{token_language} = $c->d->rs('Token::Language')->find({ id => $token_language_id });
	if (!$c->stash->{token_language}) {
		$c->response->redirect($c->chained_uri('Translate','index',{ no_token_language => 1 }));
		return $c->detach;
	}
}

sub translation :Chained('logged_in') :CaptureArgs(1) {
	my ( $self, $c, $translation_id ) = @_;
	$c->stash->{translation} = $c->d->rs('Token::Language::Translation')->find({ id => $translation_id });
	if (!$c->stash->{translation}) {
		$c->response->redirect($c->chained_uri('Translate','index',{ no_translation => 1 }));
		return $c->detach;
	}
}

sub vote :Chained('translation') :Args(1) {
	my ( $self, $c, $vote ) = @_;
	$c->stash->{translation}->set_user_vote($c->user,0+$vote);
}

sub check :Chained('translation') :Args(1) {
	my ( $self, $c, $checked ) = @_;
	if ($c->user->translation_manager) {
		$c->stash->{translation}->set_check($c->user,$checked);
		$c->stash->{translation}->update;
	}
}

sub domain :Chained('logged_in') :PathPart('') :CaptureArgs(1) {
    my ( $self, $c, $token_domain_key ) = @_;
	$c->stash->{locale} = $c->req->params->{locale} ? $c->req->params->{locale} :
		$c->session->{cur_locale}->{$token_domain_key} ? $c->session->{cur_locale}->{$token_domain_key} : undef;
	$c->stash->{token_domain} = $c->d->rs('Token::Domain')->find({ key => $token_domain_key },{
		prefetch => {
			token_domain_languages => 'language',
		},
	});
	$c->stash->{locales} = {};
	for ($c->stash->{token_domain}->token_domain_languages) {
		my $l = $_->language;
		my $tcl = $_;
		my $u;
		$u = $c->user->locales->{$l->locale} if $c->user->locales->{$l->locale};
		$c->stash->{locale} = $u->language->locale if $u && !$c->stash->{locale};
		$c->stash->{locales}->{$l->locale} = {
			l => $l,
			u => $u,
			tcl => $tcl,
		};
		$c->stash->{last_locale} = $l->locale;
	}
}

sub domainindex :Chained('domain') :PathPart('') :Args(0) {
    my ( $self, $c ) = @_;
	if ($c->stash->{locale}) {
		$c->response->redirect($c->chained_uri('Translate','snippets',$c->stash->{token_domain}->key,$c->stash->{locale}));
	} else {
		$c->response->redirect($c->chained_uri('Translate','index',{ cantspeak => 'any' }));
	}
	return $c->detach;
}

sub locale :Chained('domain') :PathPart('') :CaptureArgs(1) {
    my ( $self, $c, $locale ) = @_;
	$c->stash->{locale} = $locale;
	if (!$c->stash->{locales}->{$c->stash->{locale}}->{u}) {
		$c->response->redirect($c->chained_uri('Translate','index',{ cantspeak => $locale }));
		return $c->detach;
	}
	$c->stash->{cur_language} = $c->stash->{locales}->{$c->stash->{locale}}->{l};
	$c->session->{cur_locale}->{$c->stash->{token_domain}->key} = $c->stash->{locale};
}

sub allsnippets :Chained('locale') :Args(0) {
    my ( $self, $c ) = @_;
	$c->stash->{token_languages} = $c->stash->{locales}->{$c->stash->{locale}}->{tcl}->token_languages->search({
		'token.type' => 1,
	},{
		order_by => 'me.created',
		prefetch => 'token',
	});
}

sub save_translate_params {
	my ( $self, $c ) = @_;
	my %k; # storage of token_language_id + msgstr index
	for (keys %{$c->req->params}) {
		if (length($c->req->params->{$_}) > 0 && $_ =~ m/token_language_(\d+)_msgstr(\d)/) {
			$k{$1} = {} unless defined $k{$1};
			$k{$1}->{'msgstr'.$2} = $c->req->params->{$_} ;
		}
		if ($c->user->translation_manager) {
			if ($_ =~ m/token_notes_(\d+)_edit'/) {
				my $token = $c->d->rs('Token')->find($1);
				$token->notes($c->req->params->{$_});
				$token->update;
			}
			if ($_ =~ m/token_language_notes_(\d+)_edit'/) {
				my $token_language = $c->d->rs('Token::Language')->find($1);
				$token_language->notes($c->req->params->{$_});
				$token_language->update;
			}
		}
	}
	if ($c->user) {
		for (keys %k) {
			my $token_language = $c->d->rs('Token::Language')->find($_);
			$token_language->set_user_translation($c->user,$k{$_});
		}
	}
}

sub snippets :Chained('locale') :Args(0) {
    my ( $self, $c ) = @_;
	$c->pager_init($c->action.$c->stash->{token_domain}->key.$c->stash->{locale},20);
	my $save_translations = $c->req->params->{save_translations} || $c->req->params->{save_translations_next_page} ? 1 : 0;
	my $next_page = $c->req->params->{save_translations_next_page} ? 1 : 0;
	if ($save_translations) {
		$self->save_translate_params($c);
		if ($next_page && $c->stash->{token_languages}->pager->next_page) {
			$c->res->redirect($c->chained_uri('Translate','snippets',$c->stash->{token_domain}->key,$c->stash->{locale},{ page => $c->stash->{token_languages}->pager->next_page }));
			return $c->detach;
		}
	}
	$c->stash->{token_languages} = $c->stash->{locales}->{$c->stash->{locale}}->{tcl}->token_languages->search({
		'token.type' => 1,
	},{
		order_by => 'me.created',
		page => $c->stash->{page},
		rows => $c->stash->{pagesize},
		prefetch => 'token',
	});
}

sub texts :Chained('locale') :Args(0) {
    my ( $self, $c ) = @_;
	$c->pager_init({$c->action}.{$c->stash->{token_domain}->key}.{$c->stash->{locale}},1);
	$c->stash->{no_pagesize} = 1;
	my $save_translations = $c->req->params->{save_translations} || $c->req->params->{save_translations_next_page} ? 1 : 0;
	my $next_page = $c->req->params->{save_translations_next_page} ? 1 : 0;
	$c->stash->{token_languages} = $c->stash->{locales}->{$c->stash->{locale}}->{tcl}->token_languages->search({
		'token.type' => 2,
	},{
		order_by => 'me.created',
		page => $c->stash->{page},
		rows => $c->stash->{pagesize},
		prefetch => 'token',
	});
	if ($save_translations) {
		# OLD CODE - RECHECK
		# my %k; # storage of token_language_id
		# for (keys %{$c->req->params}) {
			# if (length($c->req->params->{$_}) > 0 && $_ =~ m/token_language_(\d+)_text/) {
				# $k{$1} = $c->req->params->{$_};
			# }
		# }
		# for ($c->stash->{token_languages}->all) {
			# if ($c->user->admin) {
				# my $change = 0;
				# if ($c->req->params->{'token_notes_'.$_->id.'_edit'}) {
					# $_->token->notes($c->req->params->{'token_notes_'.$_->id.'_edit'});
					# $_->token->update;
				# }
				# if ($c->req->params->{'token_language_notes_'.$_->id.'_edit'}) {
					# $_->notes($c->req->params->{'token_language_notes_'.$_->id.'_edit'});
					# $_->update;
				# }
			# }
			# if (defined $k{$_->id}) {
				# $_->update_or_create_related('token_language_translations',{
					# msgstr0 => $k{$_->id},
					# user => $c->user->db,
				# },{
					# key => 'token_language_translation_token_language_id_username',
				# });
			# }
		# }
		# if ($next_page && $c->stash->{token_languages}->pager->next_page) {
			# $c->res->redirect($c->chained_uri('Translate','texts',$c->stash->{token_domain}->key,$c->stash->{locale},{ page => $c->stash->{token_languages}->pager->next_page }));
			# return $c->detach;
		# }
	}
}

#
# TODO
#
sub images :Chained('locale') :Args(0) {
    my ( $self, $c ) = @_;
	$c->pager_init({$c->action}.{$c->stash->{token_domain}->key}.{$c->stash->{locale}},5);
	my $save_translations = $c->req->params->{save_translations} || $c->req->params->{save_translations_next_page} ? 1 : 0;
	my $next_page = $c->req->params->{save_translations_next_page} ? 1 : 0;
	$c->stash->{token_languages} = $c->stash->{locales}->{$c->stash->{locale}}->{tcl}->token_languages->search({
		'token.type' => 3,
	},{
		order_by => 'me.created',
		page => $c->stash->{page},
		rows => $c->stash->{pagesize},
		prefetch => 'token',
	});
	if ($save_translations) {
		#
		# check for files
		#
		for ($c->stash->{token_languages}->all) {
			if ($c->user->admin) {
				my $change = 0;
				if ($c->req->params->{'token_notes_'.$_->id.'_edit'}) {
					$_->token->notes($c->req->params->{'token_notes_'.$_->id.'_edit'});
					$_->token->update;
				}
				if ($c->req->params->{'token_language_notes_'.$_->id.'_edit'}) {
					$_->notes($c->req->params->{'token_language_notes_'.$_->id.'_edit'});
					$_->update;
				}
			}
			# TODO
		}
		if ($next_page && $c->stash->{token_languages}->pager->next_page) {
			$c->res->redirect($c->chained_uri('Translate','images',$c->stash->{token_domain}->key,$c->stash->{locale},{ page => $c->stash->{token_languages}->pager->next_page }));
			return $c->detach;
		}
	}
}

__PACKAGE__->meta->make_immutable;

1;
