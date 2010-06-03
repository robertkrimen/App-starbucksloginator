package App::starbucksloginator;
# ABSTRACT: Access the wireless at Starbucks (via AT&T)

use strict;
use warnings;

=head1 SYNOPSIS

    $ starbucksloginator

    $ starbucksloginator --username alice --password hunter2

=head1 DESCRIPTION

    AT&T/Starbucks has an annoying login screen needed access their wireless. It is especially annoying since it has a habit of logging you out every so often (sometimes just after you logged in)

    This is a commandline-based, no-hassle way to log in
    
=head1 USAGE

    Usage: starbucksloginator <options>

        --username <username>   Your AT&T wireless username
        --password <password>   The password for the above
                                Instead of supplying your identity on the
                                commandline, you can setup $HOME/.starbucks like so:
        
                                    username <username>
                                    password <password>

        --agent <agent>         The agent to pass the loginator off as (user agent string).
                                Windows Firefox by default

=cut

use Config::Identity;
use Getopt::Long qw/ GetOptions /;
use Getopt::Usaginator <<_END_;
Usage: starbucksloginator <options>

    --username <username>   Your AT&T wireless username
    --password <password>   The password for the above
                            Instead of supplying your identity on the
                            commandline, you can setup \$HOME/.starbucks like so:
    
                                username <username>
                                password <password>

    --agent <agent>         The agent to pass the loginator off as (user agent string).
                            Windows Firefox by default
_END_

use WWW::Mechanize;

my $__agent__ = WWW::Mechanize->new;
$__agent__->agent( "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-GB; rv:1.9.0.6) Gecko/2009011913 Firefox/3.0.6" );
sub agent { $__agent__ }

sub try_google {
    my $self = shift;
    my $response = agent->get( 'http://google.com' );
    my $success = $response->decoded_content =~ m/<title>[^<]*Google.*?</i;
    return ( $success, $response );
}

sub say { 
    print "> ", @_, "\n";
}

sub run {
    my $self = shift;
    my @arguments = @_;
    
    my ( $help, $username, $password, $agent );
    {
        local @ARGV = @arguments;
        GetOptions(
            'username=s' => \$username,
            'password=s' => \$password,
            'agent=s' => \$agent,
            'help|h|?' => \$help,
        );
    }

    usage 0 if $help;

    my %identity = Config::Identity->try_best( 'starbucks' );
    $username = $identity{username} unless defined $username;
    $password = $identity{password} unless defined $password;
    agent->agent( $agent ) if defined $agent;

    usage '! Missing username and/or password' unless
        defined $username && defined $password;

    my ( $connected, $response );
    ( $connected, $response ) = $self->try_google;

    if ( $connected ) { 
        say "It looks like you can already get out to Google -- Cancelling login";
        exit 0;
    }
    else {
        say "Unable to connect to Google -- Attempting to login";
    }

    if ( agent->form_name( 'MEMBERLOGIN' ) ) {
        say "Attempting to authenticate as $username";
        $response = agent->submit_form( 
            form_name => 'MEMBERLOGIN',
            fields => {
                username => $username,
                password => $password,
                roamRealm => 'attwifi.com',
                aupAgree => 1,
            },
        );
    }
    else {
        say "Unable to find form MEMBERLOGIN -- Cancelling login";
        print $response->as_string;
        exit -1;
    }

    ( $connected ) = $self->try_google;

    if ( $connected ) {
        say "Connected to Google -- Login successful";
        exit 0;
    }

    say "Unable to connect to Google -- Login failed";
    print $response->as_string;
    exit -1;
}

1;
