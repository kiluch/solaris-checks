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
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => 30);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => 60);


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


	my $total = ($data{"memory"}{"total"})*1024*1024;
	my $free = ($data{"memory"}{"free"})*1024*1024;
	#my $cached = $data{"memory"}{"freeswap"};
	my $used = ($total - $free);
	my $freeperc = $free / $total * 100;
        $freeperc = sprintf("%.1f",$freeperc); 
	
	my $fhb = Format::Human::Bytes->new();
	my $code;
	
	if (index($warning, "%") > 0 || index($critical, "%") > 0)
	{
		$warning =~ tr/%//d;
		$critical =~ tr/%//d;

		$code = $np->check_threshold(
     			check => $freeperc,
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
	$np->add_perfdata( label => "percent", uom => "%", value => $freeperc);

	$np->nagios_exit(return_code=> $code, message => "Free Memory " .sprintf("%.1f",$freeperc) . "% (" . $fhb->base2($free) . " free - ". $fhb->base2($used) . " used)" );




