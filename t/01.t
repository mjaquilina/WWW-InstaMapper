#!/usr/bin/perl

use strict;
use warnings;
use Test::More skip_all => 'Requires API key';
use Test::Warn;
use Data::Dumper;
use WWW::InstaMapper;

my $key = '';

sleep 10;

my $instamapper = WWW::InstaMapper->new(
    api_key => $key,
);
my $position = $instamapper->get_last_position;
is $position->{timestamp}->year, 2009;

sleep 10;

my @positions = $instamapper->get_positions(
    num            => 10,
    from_timestamp => '2009-11-01 01:00:00',
);

is scalar(@positions), 10;

my $time_before = time;
warning_like { $instamapper->get_positions } qr/API terms limit/;
my $time_after = time;

my $difference = $time_after - $time_before;
ok $difference >= 10;

sleep 10;

warning_like { $instamapper->get_positions(num => 15000) } qr/maximum of 1000/;

