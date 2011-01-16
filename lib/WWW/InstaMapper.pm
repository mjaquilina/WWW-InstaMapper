package WWW::InstaMapper;

use strict;
use warnings;
use Carp;
use DateTime;
use Date::Parse qw(str2time);
use JSON;
use LWP::UserAgent;

our $VERSION = '0.01';

=item new

Returns a new instance of WWW::InstaMapper.

Accepts a hash, containing the following parameters:

api_key (required): The InstaMapper API key (as a string) or multiple keys (as
an array reference of strings) that you would like to retrieve positions for.

ssl (optional): Boolean indication of whether or not to make API calls via HTTPS.

Please note that in accordance with the InstaMapper API terms, a delay of 10
seconds (or 30 seconds if using SSL) will be enforced between requests via this
module.

=cut

sub new
{
    my ($class, %args) = @_;
    croak "You must specify your API key" unless $args{api_key};
    my $self = { %args };
    bless $self, $class;
    return $self;
};

=head2 get_positions

Returns an array of hash references representing position data for the devices
whose API keys are associated with this object.

Accepts the following optional parameters:

num - The number of positions to return (maximum of 1000)
from_timestamp - Timestamp of the earliest time you would like positions from
from_unixtime - Epoch timestamp (UTC) of the earliest time you would like positions from

The hash references contain the following data:

device_key:   InstaMapper device key
device_label: InstaMapper device label
timestamp:    DateTime object representing the time the position was logged, in UTC
latitude:     Latitude
longitude:    Longitude
altitude:     Altitude (in meters)
speed:        Speed (in meters/second)
heading:      Heading (in degrees)

=cut

sub get_positions
{
    my $self   = shift;
    $self->_api_call('getPositions', @_);
}

=head2 $self->get_last_position

Returns a hash reference containing data on the last position logged for the
devices whose API keys are associated with this object.

=cut

sub get_last_position
{
    my $self = shift;
    my @p = $self->get_positions;
    return $p[0];
}

sub _api_call
{
    my $self   = shift;
    my $action = shift;
    my %params = @_; 
    my $key    = $self->{api_key};

    $key = join(',', map { "<$_>" } @$key)
        if (ref($key) eq 'ARRAY');

    my $https  = $self->{ssl} ? 'https' : 'http';
    my $uri    = "$https://www.instamapper.com/api?" .
        "action=$action" .
        "&key=$key"      .
        "&format=json";

    if ($params{num})
    {
        my $num = $params{num};
        if ($num > 1000)
        {
            warn "The InstaMapper API allows a maximum of 1000 positions to " .
                 "be retrieved at a time. Restricting to 1000.";
            $num = 1000;
        }
        $uri .= "&num=$params{num}";
    }

    my $from = $params{from_unixtime};
    $from = str2time($params{from_timestamp})
        if ($params{from_timestamp} and !$from);
    $uri .= "&from_ts=$from" if $from;

    $self->_enforce_terms;

    my $agent    = LWP::UserAgent->new;
    my $response = $agent->get($uri);
    if ($response->is_success)
    {
        my $json = $response->content;
        $self->{last_request} = scalar time;
        my $data = JSON->new->decode($json);

        return unless $data->{positions};

        my $positions = $data->{positions};
        my @positions_to_return;
        for my $position (@$positions)
        {
            $position->{timestamp} =
                DateTime->from_epoch(epoch => $position->{timestamp});
            push @positions_to_return, $position;
        }

        return @positions_to_return;
    }
    else
    {
        croak "Can't retrieve data from $uri: " .
            $response->status_line;
    }
}

sub _enforce_terms
{
    my $self         = shift;
    my $last_request = $self->{last_request};
    return unless $last_request;

    my $difference  = time - $last_request;
    my $requirement = $self->{ssl} ? 30 : 10;
    return if ($difference > $requirement);

    my $sleep_time = $requirement - $difference;
    return unless $sleep_time;

    my $https = $self->{ssl} ? 'HTTPS' : 'HTTP';
    warn "InstaMapper API terms limit $https requests to $requirement " .
         "seconds. Pausing for $sleep_time seconds.";

    sleep $requirement - $difference;
}

1;

=head1 NAME

WWW::InstaMapper - Perl interface to the InstaMapper.com API

=head1 SYNOPSIS

  use WWW::InstaMapper;

  my $instamapper = WWW::InstaMapper->new(
      api_key => '1234567890',
      ssl     => 1,
  );

  my $position = $instamapper->get_last_position;
  print "Last position logged at $position->{timestamp}";

  my @positions = $instamapper->get_positions(
      num            => 500,
      from_timestamp => '2009-01-01',
  );

  for my $position (@positions)
  {
    print "$position->{device_label} was at lat " .
          "$position->{latitude}/long $position->{longitude} " .
          "at $position->{timestamp}";
  }

=head1 DESCRIPTION

This module provides an object-oriented Perl interface to the InstaMapper.com API.

=head1 DEPENDENCIES

DateTime, Date::Parse, LWP::UserAgent, JSON

=head1 DISCLAIMER

The author of this module is not affiliated in any way with InstaMapper.com.

Users of this module must be sure to follow the InstaMapper.com API terms of service.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 Michael Aquilina. All rights reserved.

This code is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=head1 AUTHOR

Michael Aquilina, aquilina@cpan.org

=cut
