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
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => "2,2,2");
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => "4,4,4");


$np->getopts();

my $host = $np->opts->host;
my $outputpath = $np->opts->output . $host . ".json";
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;

my $criticalcommas = ($critical =~ tr/,//);
my $warningcommas = ($warning =~ tr/,//);

$np->nagios_exit(return_code=> UNKNOWN, message => "Critical threshold in wrong format should be 1m,5m,15m") unless $criticalcommas == 2;
$np->nagios_exit(return_code=> UNKNOWN, message => "Warning threshold in wrong format should be 1m,5m,15m") unless $warningcommas == 2;

$np->nagios_exit(return_code=> UNKNOWN, message => "Unable to read from data file $outputpath") unless -r $outputpath;

  local $/ = undef;
  open FILE, $outputpath;
  flock(FILE, 1);
  binmode FILE;
  my $string = <FILE>;
  close FILE;

my %data = %{ decode_json($string) };


	my $m1 = $data{"loadavg"}{"1m"};
	my $m5 = $data{"loadavg"}{"5m"};
	my $m15 = $data{"loadavg"}{"15m"};
	
	my @warnings = split(/,/,$warning);
	my @criticals = split(/,/,$critical);
	
	my $code = OK;
	
	if ($warnings[0] < $m1 || $warnings[1] < $m5 || $warnings[2] < $m15)
	{
		$code = "WARNING";
	}

	if ($criticals[0] < $m1 || $criticals[1] < $m5 || $criticals[2] < $m15)
        {
                $code = "CRITICAL";
        }

	
	$np->add_perfdata( label => "1m", value => $m1);
	$np->add_perfdata( label => "5m", value => $m5);
	$np->add_perfdata( label => "15m", value => $m15);
	$np->nagios_exit(return_code=> $code, message => "Load Average - 1m - $m1, 5m - $m5, 15m - $m15");





