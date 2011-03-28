package FixMyStreet::App;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use FixMyStreet;
use FixMyStreet::Cobrand;
use Memcached;
use Problems;
use mySociety::Email;

use Catalyst (
    'Static::Simple',    #
    'Unicode',
    'Session',
    'Session::Store::DBIC',
    'Session::State::Cookie',
    'Authentication',
);

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(

    # get the config from the core object
    %{ FixMyStreet->config() },

    name => 'FixMyStreet::App',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    # Some generic stuff
    default_view => 'Web',

    # Serve anything in web dir that is not a .cgi script
    static => {    #
        include_path      => [ FixMyStreet->path_to("web") . "" ],
        ignore_extensions => ['cgi'],
    },

    'Plugin::Session' => {    # Catalyst::Plugin::Session::Store::DBIC
        dbic_class => 'DB::Session',
        expires    => 3600 * 24 * 7 * 6,    # 6 months
    },

    'Plugin::Authentication' => {
        default_realm => 'default',
        default       => {
            credential => {    # Catalyst::Authentication::Credential::Password
                class              => 'Password',
                password_field     => 'password',
                password_type      => 'hashed',
                password_hash_type => 'SHA-1',
            },
            store => {         # Catalyst::Authentication::Store::DBIx::Class
                class      => 'DBIx::Class',
                user_model => 'DB::User',
            },
        },
        no_password => {       # use post confirm etc
            credential => {    # Catalyst::Authentication::Credential::Password
                class         => 'Password',
                password_type => 'none',
            },
            store => {         # Catalyst::Authentication::Store::DBIx::Class
                class      => 'DBIx::Class',
                user_model => 'DB::User',
            },
        },
    },
);

# Start the application
__PACKAGE__->setup();

# set up DB handle for old code
FixMyStreet->configure_mysociety_dbhandle;

# disable debug logging unless in debaug mode
__PACKAGE__->log->disable('debug')    #
  unless __PACKAGE__->debug;

=head1 NAME

FixMyStreet::App - Catalyst based application

=head1 SYNOPSIS

    script/fixmystreet_app_server.pl

=head1 DESCRIPTION

FixMyStreet.com codebase

=head1 METHODS

=head2 cobrand

    $cobrand = $c->cobrand();

Returns the cobrand object. If not already determined this request finds it and
caches it to the stash.

=cut

sub cobrand {
    my $c = shift;
    return $c->stash->{cobrand} ||= $c->_get_cobrand();
}

sub _get_cobrand {
    my $c             = shift;
    my $host          = $c->req->uri->host;
    my $cobrand_class = FixMyStreet::Cobrand->get_class_for_host($host);
    return $cobrand_class->new( { request => $c->req } );
}

=head2 setup_cobrand

    $cobrand = $c->setup_cobrand();

Work out which cobrand we should be using. Set the environment correctly - eg
template paths

=cut

sub setup_cobrand {
    my $c       = shift;
    my $cobrand = $c->cobrand;

    # append the cobrand templates to the include path
    $c->stash->{additional_template_paths} =
      [ $cobrand->path_to_web_templates->stringify ]
      unless $cobrand->is_default;

    my $host = $c->req->uri->host;
    my $lang =
        $host =~ /^en\./ ? 'en-gb'
      : $host =~ /cy/    ? 'cy'
      :                    undef;

    # set the language and the translation file to use - store it on stash
    my $set_lang = $cobrand->set_lang_and_domain(
        $lang,                                       # language
        1,                                           # return unicode
        FixMyStreet->path_to('locale')->stringify    # use locale directory
    );
    $c->stash->{lang_code} = $set_lang;

    # debug
    $c->log->debug( sprintf "Set lang to '%s' and cobrand to '%s'",
        $set_lang, $cobrand->moniker );

    Problems::set_site_restriction_with_cobrand_object($cobrand);

    Memcached::set_namespace( FixMyStreet->config('BCI_DB_NAME') . ":" );

    return $cobrand;
}

=head2 send_email

    $email_sent = $c->send_email( 'email_template.txt', $extra_stash_values );

Send an email by filling in the given template with values in the stash.

You can specify extra values to those already in the stash by passing a hashref
as the second argument.

The stash (or extra_stash_values) keys 'to', 'from' and 'subject' are used to
set those fields in the email if they are present.

If a 'from' is not specified then the default from the config is used.

=cut

sub send_email {
    my $c                  = shift;
    my $template           = shift;
    my $extra_stash_values = shift || {};

    # create the vars to pass to the email template
    my $vars = {
        from => FixMyStreet->config('CONTACT_EMAIL'),
        %{ $c->stash },
        %$extra_stash_values,
        additional_template_paths =>
          [ $c->cobrand->path_to_email_templates->stringify ]
    };

    # render the template
    my $content = $c->view('Email')->render( $c, $template, $vars );

    # create an email - will parse headers out of content
    my $email = Email::Simple->new($content);
    $email->header_set( ucfirst($_), $vars->{$_} )
      for grep { $vars->{$_} } qw( to from subject);

    # pass the email into mySociety::Email to construct the on the wire 7bit
    # format - this should probably happen in the transport instead but hohum.
    my $email_text = mySociety::Email::construct_email(
        {
            _unwrapped_body_ => $email->body,    # will get line wrapped
            $email->header_pairs
        }
    );

    # send the email
    $c->model('EmailSend')->send($email_text);

    return $email;
}

=head1 SEE ALSO

L<FixMyStreet::App::Controller::Root>, L<Catalyst>

=cut

1;
