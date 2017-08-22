package FixMyStreet::DB::ResultSet::State;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use Memcached;

sub _hardcoded_states {
    my $rs = shift;
    my $open = $rs->new({ id => -1, label => 'confirmed', type => 'open', name => _("Open") });
    my $closed = $rs->new({ id => -2, label => 'closed', type => 'closed', name => _("Closed") });
    return ($open, $closed);
}

# As states will change rarely, and then only through the admin,
# we cache these in the package on first use, and clear on update.

sub clear {
    Memcached::set('states', '');
}

sub states {
    my $rs = shift;

    my $states = Memcached::get('states');
    if ($states && !FixMyStreet->test_mode) {
        # Need to reattach schema
        $states->[0]->result_source->schema( $rs->result_source->schema ) if $states->[0];
        return $states;
    }

    # Pick up and cache any translations
    my $q = $rs->result_source->schema->resultset("Translation")->search({
        tbl => 'state',
        col => 'name',
    });
    my %trans;
    $trans{$_->object_id}{$_->lang} = { id => $_->id, msgstr => $_->msgstr } foreach $q->all;

    my @states = ($rs->_hardcoded_states, $rs->search(undef, { order_by => 'label' })->all);
    $_->translated->{name} = $trans{$_->id} || {} foreach @states;
    $states = \@states;
    Memcached::set('states', $states);
    return $states;
}

# Some functions to provide filters on the above data

sub open { [ $_[0]->_filter(sub { $_->type eq 'open' }) ] }
sub closed { [ $_[0]->_filter(sub { $_->type eq 'closed' }) ] }
sub fixed { [ $_[0]->_filter(sub { $_->type eq 'fixed' }) ] }

# We sometimes have only a state label to display, no associated object.
# This function can be used to return that label's display name.

sub display {
    my ($rs, $label) = @_;
    my $unchanging = {
        unconfirmed => _("Unconfirmed"),
        hidden => _("Hidden"),
        partial => _("Partial"),
        'fixed - council' => _("Fixed - Council"),
        'fixed - user' => _("Fixed - User"),
    };
    return $unchanging->{$label} if $unchanging->{$label};
    my ($state) = $rs->_filter(sub { $_->label eq $label });
    return $label unless $state;
    return $state->msgstr;
}

sub _filter {
    my ($rs, $fn) = @_;
    my $states = $rs->states;
    grep &$fn, @$states;
}

1;
