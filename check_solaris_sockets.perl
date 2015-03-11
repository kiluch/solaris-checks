#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use Format::Human::Bytes;
	
use Nagios::Plugin;

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <host> --output <path to json> --volume <volumename>",
	version => "v0.01",
	timeout => 30
);

$np->add_arg(spec => 'host|H=s', help => "--host\n   Hostname", required => 1, default => undef);
$np->add_arg(spec => 'output=s', help => "--output\n   path to save json files", required => 1, default => undef);
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => 50);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => 80);


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
my $used_sockets = $data{"sockets"}{"established"};

$np->add_perfdata( label => "used_sockets", value => $used_sockets, warning => $warning, critical => $critical);
$np->nagios_exit(return_code=> $np->check_threshold(check => $used_sockets), message => "Used Sockets: $used_sockets");