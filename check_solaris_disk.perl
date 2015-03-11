#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use Format::Human::Bytes;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep clock stat );
	
use Nagios::Plugin;

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <host> --output <path to json> --volume <volumename>",
	version => "v0.01",
	timeout => 30
);

$np->add_arg(spec => 'host|H=s', help => "--host\n   Hostname", required => 1, default => undef);
$np->add_arg(spec => 'output=s', help => "--output\n   path to save json files", required => 1, default => undef);
$np->add_arg(spec => 'volume=s', help => "--volume\n   volumename", required => 1, default => undef);
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => 30);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => 60);


$np->getopts();

my $host = $np->opts->host;
my $outputpath = $np->opts->output . $host . ".json";
my $volume = $np->opts->volume;
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

if (exists $data{"disks"}{$volume})
{
	my $used = ($data{"disks"}{$volume}{"used"})*1024;
	my $available = ($data{"disks"}{$volume}{"available"})*1024;
	my $capacity = $data{"disks"}{$volume}{"capacity"};
	my $fhb = Format::Human::Bytes->new();
	my $code;

	if (index($warning, "%") > 0 || index($critical, "%") > 0)
	{
		$warning =~ tr/%//d;
		$critical =~ tr/%//d;

		$code = $np->check_threshold(
     			check => $capacity,
     			warning => $warning,
     			critical => $critical,
   		);
	}
	else
	{
		$code = $np->check_threshold(
     			check => $available,
     			warning => $warning,
     			critical => $critical,
   		);
	}
	$np->add_perfdata( label => "used", uom => "B", value => $used);
	$np->add_perfdata( label => "available", uom => "B", value => $available);
	$np->add_perfdata( label => "capacity", uom => "%", value => $capacity);

	$np->nagios_exit(return_code=> $code, message => "$volume - $capacity% used " . $fhb->base2($used) . " used - ". $fhb->base2($available) . " free" );

}
else
{
	$np->nagios_exit(return_code=> UNKNOWN, message => "Volume $volume does not exist")
}


