#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use Format::Human::Bytes;
use Data::Dumper;
use Try::Tiny;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep clock stat );
	
use Nagios::Plugin;

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <host> --output <path to json> --volume <volumename>",
	version => "v0.01",
	timeout => 30
);

$np->add_arg(spec => 'host|H=s', help => "--host\n   Hostname", required => 1, default => undef);
$np->add_arg(spec => 'output=s', help => "--output\n   path to save json files", required => 1, default => undef);
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => 30);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => 60);


$np->getopts();

my $host = $np->opts->host;
my $outputpath = $np->opts->output . $host . ".json";
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;

$np->nagios_exit(return_code=> UNKNOWN, message => "Unable to read from data file $outputpath") unless -r $outputpath;

  local $/ = undef;
  open FILE, "<", $outputpath;
  flock(FILE, 1);
  binmode FILE;
  my $string = <FILE>;
  close FILE;

try 
{
	decode_json($string);	
}
catch
{
	$np->nagios_exit(return_code=> UNKNOWN, message => "Unable to parse JSON file");
};

my $json = JSON->new->allow_nonref;
my %data = %{ $json->decode($string) };

my $users = $data{"users"}{"connected"};

$np->add_perfdata( label => "users", value => $users, warning => $np->opts->warning, critical => $np->opts->critical);
$np->nagios_exit(return_code=> $np->check_threshold(check => $users), message => "Logged in users - $users" );