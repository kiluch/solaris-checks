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
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => "20:");
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => "10:");


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


	my $free = $data{"swap"}{"available"}*1024;
	my $used = $data{"swap"}{"used"}*1024;
        my $total = $used + $free;
	my $usedperc = $used / $total * 100;
        $usedperc = sprintf("%.1f",$usedperc);
	
	my $fhb = Format::Human::Bytes->new();
	my $code;
	
	if (index($warning, "%") > 0 || index($critical, "%") > 0)
	{
		$warning =~ tr/%//d;
		$critical =~ tr/%//d;

		$code = $np->check_threshold(
     			check => $usedperc,
     			warning => $warning,
     			critical => $critical,
   		);
	}
	else
	{
		$code = $np->check_threshold(
     			check => $free,
     			warning => $warning,
     			critical => $critical,
   		);
	}
	$np->add_perfdata( label => "used", uom => "B", value => $used);
	$np->add_perfdata( label => "free", uom => "B", value => $free);
	$np->add_perfdata( label => "percent", uom => "%", value => $usedperc, warning => $warning, critical => $critical);

	$np->nagios_exit(return_code=> $code, message => "Swap Usage " .sprintf("%.1f",$usedperc) . "% used (" . $fhb->base2($total) . " total - ". $fhb->base2($free) . " free)" );





