package FixMyStreet::Cobrand::Bexley;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2494 }
sub council_area { 'Bexley' }
sub council_name { 'London Borough of Bexley' }
sub council_url { 'bexley' }
sub get_geocoder { 'OSM' }

sub enable_category_groups { 1 }
sub suggest_duplicates { 1 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.46088,0.142359',
        bounds => [ 51.408484, 0.074653, 51.515542, 0.2234676 ],
    };
}

sub on_map_default_status { 'open' }

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->result_source->schema->resultset("Contact")->not_deleted->find({
        body_id => $body->id,
        category => $comment->problem->category
    });
    $params->{service_code} = $contact->email;
}

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    # If we've received an update via Open311 that's closed
    # or fixed the report, also close it to updates.
    $comment->problem->set_extra_metadata(closed_updates => 1)
        if !$comment->problem->is_open;
}

sub lookup_site_code_config {
    # uncoverable subroutine
    # uncoverable statement
    {
        buffer => 200, # metres
        url => "https://tilma.mysociety.org/mapserver/bexley",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Streets",
        property => "NSG_REF",
        accept_feature => sub { 1 }
    }
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;

    # Reports made via the app probably won't have a NSGRef because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # WFS service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row)) {
            push @$extra, { name => 'NSGRef', description => 'NSG Ref', value => $ref };
        }
    }

    $row->set_extra_fields(@$extra);
}

sub admin_user_domain { 'bexley.gov.uk' }

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    if ($row->category eq 'Abandoned and untaxed vehicles') {
        my $burnt = $row->get_extra_field_value('burnt') || '';
        return unless $burnt eq 'Yes';
    }

    my @lighting = (
        'Lamp post',
        'Light in multi-storey car park',
        'Light in outside car park',
        'Light in park or open space',
        'Traffic bollard',
        'Traffic sign light',
        'Underpass light',
        'Zebra crossing light',
    );
    my %lighting = map { $_ => 1 } @lighting;

    my $emails = $self->feature('open311_email') || return;
    my ($e, $n);
    if ($row->category eq 'Abandoned and untaxed vehicles' || $row->category eq 'Dead animal') {
        $e = $emails->{p1};
        $n = 'Bexley P1 email';
    } elsif ($lighting{$row->category}) {
        $e = $emails->{lighting};
        $n = 'FixMyStreet Bexley Street Lighting';
    }
    return unless $e;
    my $sender = FixMyStreet::SendReport::Email->new( to => [ [ $e, $n ] ] );

    $self->open311_config($row); # Populate NSGRef again if needed

    my $extra_data = join "; ", map { "$_->{description}: $_->{value}" } @{$row->get_extra_fields};
    $h->{additional_information} = $extra_data;

    $sender->send($row, $h);
}

1;