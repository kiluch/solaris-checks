#!/usr/bin/perl

use warnings;
use strict;

use JSON;
use Format::Human::Bytes;
	
use Nagios::Plugin;

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <host> --output <path to json> --nic <nic name>",
	version => "v0.01",
	timeout => 30
);

$np->add_arg(spec => 'host|H=s', help => "--host\n   Hostname", required => 1, default => undef);
$np->add_arg(spec => 'output=s', help => "--output\n   path to save json files", required => 1, default => undef);
$np->add_arg(spec => 'nic=s', help => "--nic\n    nic name", required => 1, default => undef);
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => 30);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => 60);


$np->getopts();

my $host = $np->opts->host;
my $outputpath = $np->opts->output . $host . ".json";
my $nic = $np->opts->nic;
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

if (exists $data{"nics"}{$nic})
{
	my $tx = $data{"nics"}{$nic}{"tx"};
	my $rx = $data{"nics"}{$nic}{"rx"};
	my $fhb = Format::Human::Bytes->new();
	
	$np->add_perfdata( label => "rx", value => $rx);
	$np->add_perfdata( label => "tx", value => $tx);

	#$np->nagios_exit(return_code=> OK, message => "$nic - Transmit: " . $fhb->base2($tx) ." Receive: " . $fhb->base2($rx));
        $np->nagios_exit(return_code=> OK, message => "$nic - Transmit: " . $tx . " packets, Receive: " . $rx . " packets");

}
else
{
	$np->nagios_exit(return_code=> UNKNOWN, message => "Interface $nic  does not exist")
}


