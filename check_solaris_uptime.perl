#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use Format::Human::Bytes;
use Data::Dumper;
use Time::Seconds;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep clock stat );
	
use Nagios::Plugin;

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <host> --output <path to json> --volume <volumename>",
	version => "v0.01",
	timeout => 30
);

$np->add_arg(spec => 'host|H=s', help => "--host\n   Hostname", required => 1, default => undef);
$np->add_arg(spec => 'output=s', help => "--output\n   path to save json files", required => 1, default => undef);
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => undef);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => "3600:");


$np->getopts();

my $host = $np->opts->host;
my $outputpath = $np->opts->output . $host . ".json";
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;

$np->nagios_exit(return_code=> UNKNOWN, message => "Unable to read from data file $outputpath") unless -r $outputpath;

  local $/ = undef;
  open FILE, $outputpath;
  flock(FILE, 1);
  binmode FILE;
  my $string = <FILE>;
  close FILE;

my %data = %{ decode_json($string) };
my $days = ($data{"uptime"}{"days"})*86400;
my $hours = ($data{"uptime"}{"hours"})*3600;
my $minutes = ($data{"uptime"}{"minutes"})*60;
my $uptime = $days + $hours + $minutes;

my $ts=Time::Seconds->new($uptime);

$np->add_perfdata( label => "uptime", value => $uptime, warning => $np->opts->warning, critical => $np->opts->critical);
$np->nagios_exit(return_code=> $np->check_threshold(check => $uptime), message => "Uptime - " .  $ts->pretty());