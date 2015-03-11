#!/usr/bin/perl -X

use warnings;
use strict;
use Nagios::Plugin;
use Net::OpenSSH;
use JSON;
use Switch;
use Data::Dumper;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep clock stat );

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <host> --user <username> --password <password> [--port <SSH port>]",
	version => "v0.01",
	timeout => 30
);


$np->add_arg(spec => 'host|H=s', help => "--host\n   Hostname", required => 1, default => undef);
$np->add_arg(spec => 'user=s', help => "--user\n   username", required => 1, default => undef);
$np->add_arg(spec => 'password=s', help => "--password\n   password", required => 0, default => undef);
$np->add_arg(spec => 'keyfile=s', help => "--keyfile\n   location of id_rsa", required => 0, default => undef);
$np->add_arg(spec => 'debug=s', help => "--debug\n   turn on debugging", required => 0, default => 0);
$np->add_arg(spec => 'output=s', help => "--output\n   path to save json files", required => 1, default => "/usr/lib64/nagios/plugins/solaris_stats_data/");
$np->add_arg(spec => 'port=i', help => "--port\n   SSH port", required => 0, default => 22);
$np->add_arg(spec => 'warning=s', help => "--warning\n   Warning Threshold", required => 0, default => 90);
$np->add_arg(spec => 'critical=s', help => "--critical\n   Critical Threshold", required => 0, default => 120);
$np->add_arg(spec => 'cpuqty=i', help => "--cpuqty\n   Number of times to check CPU usage", required => 0, default => 3);

$np->getopts();

my $host = $np->opts->host;
my $user = $np->opts->user;
my $password = $np->opts->password;
my $port = $np->opts->port;
my $keyfile = $np->opts->keyfile;
my $debug = $np->opts->debug;
my $outputpath = $np->opts->output;
my $cpuqty = $np->opts->cpuqty;
my $stdout;
my @KEYFILE =();
my %stats;
my $ssh;

$np->nagios_exit(return_code=> UNKNOWN, message => "Unable to write to $outputpath") unless -w $outputpath;
my $start_time = [gettimeofday];

if (defined $keyfile)
{
	$ssh = Net::OpenSSH->new($host,(
		user=>$user,
		port=>$port,
		key_path=>$keyfile,
		master_stderr_discard=>1
	));
}
else
{
	if (defined $password)
	{
		$ssh = Net::OpenSSH->new($host,(
			user=>$user,
			port=>$port,
			password=>$password,
			master_stderr_discard => 1,
			master_stdout_discard => 1
		));
	}
	else
	{
		$np->nagios_exit(return_code=> UNKNOWN, message => "You must specify either a private key or a password");
	}
}

$ssh->error and $np->nagios_exit(return_code=> UNKNOWN, message => "Unable to connect.  Error: " . $ssh->error);

#######
# CPU #
#######

	$stdout = $ssh->capture("sar 1 | grep :");
	my @cpustats = split /\s+/, $stdout;
	
#	print Dumper(@cpustats);

	my %cpustats = (
		"user" => $cpustats[6],
		"sys" => $cpustats[7],
		"wait" => $cpustats[8],
		"idle" => $cpustats[9],
	);

	$stats{"cpu"} = \%cpustats;

################
# Load Average #
################

	$stdout = $ssh->capture("uptime");

	my @loadavg = (split /[,:\s]+/, $stdout);
#	my @loadavg = (split /[,]/, $stdout);
	
#	print Dumper(@loadavg);

	my %loadavg = (
		"1m"=>$loadavg[12],
		"5m"=>$loadavg[13],
		"15m"=>$loadavg[14],
	);
	
	$stats{"loadavg"} = \%loadavg;

############
# IO Stats #
############
	my %iostats;
	$stdout = $ssh->capture("iostat -x 1 1");
	my @iodisks = split(/\n/,$stdout);

#	print Dumper(@iodisks);
	
	my $count = 0;
	
	foreach(@iodisks)
	{
		if ($count > 1){
			my $io = $_;
			my @stats = (split /\s+/, $io);
			#print Dumper(@stats);
			my %stats = (
				'rs'=>$stats[1],
				'ws'=>$stats[2],
				'krs'=>$stats[4],
				'kws'=>$stats[5],
				'wait'=>$stats[6],
				'actv'=>$stats[7],
				'waiting'=>$stats[8],
				'busy'=>$stats[9],
	
			);
			$iostats{$stats[0]} = \%stats;
			}
		$count++;
	}
	$stats{"iostats"} = \%iostats;

##########
# Memory #
##########

	$stdout = $ssh->capture("vmstat 1 1");

	my @memory = split(/\n/,$stdout);
	
	$count = 0;
	
	#print Dumper(@memory);
	my %memorystats;
	my @stats;
	foreach(@memory)
	{
		my $memory = $_;
		#$memory  =~ tr/://d;
		if ($count >= 2){
			@stats = (split /\s+/, $memory);
			#print Dumper(@stats);
			$memorystats{'freeswap'} = sprintf "%.0f", $stats[4] / 1024;
			$memorystats{'free'} = sprintf "%.0f", $stats[5] / 1024;
		}
		$count++;
	}

	my $stdout2 = $ssh->capture("/usr/platform/`uname -i`/sbin/prtdiag -v | grep size");
	my @memory2 = split(/[:\s]+/,$stdout2);
	#print Dumper(@memory2);
	
	$memorystats{'total'} = sprintf "%.0f", $memory2[2];
	#$memorystats{'used'} = $memory2[2] - ($stats[5]/1024);
	
	$stats{"memory"} = \%memorystats;

###############
# Swap Memory #
###############

	$stdout = $ssh->capture("/usr/sbin/swap -s");

	my @swap = split(/\s+/,$stdout);

        #print Dumper(@swap);
        chop($swap[1],$swap[5],$swap[8],$swap[10]);
        my %swapstats = (
		"allocated" => $swap[1],
		"reserved" => $swap[5],
		"used" => $swap[8],
		"available" => $swap[10],
	);

	$stats{"swap"} = \%swapstats;

#################
# Network Usage #
#################

	my (%nicstats,%start,%end);
	my (@start,@end);
	my $i;
	$count = 0;
	$stdout = $ssh->capture("netstat -i");
	sleep 1;
	$stdout2 = $ssh->capture("netstat -i");
		
	my @nics = (split /\n+/,$stdout);
	my @nics2 = (split /\n+/,$stdout2);
	
	my $size = @nics;
	for ($i = 1; $i < $size; $i++){
		@start = (split /\s+/, $nics[$i]);
		@end = (split /\s+/, $nics2[$i]);
		my %stats = (
			'rx'=>$end[4] - $start[4],
			'tx'=>$end[6] - $start[6],
		);
		$nicstats{$start[0]} = \%stats;
	}
	$stats{"nics"} = \%nicstats;
	
###########
# Sockets #
###########

	$stdout = $ssh->capture("netstat -na");
	
	my %socketstats;
	my @sockets = split(/\n/,$stdout);
	
	#print Dumper(@sockets);
	my ($listen, $idle, $established, $bound, $unbound) = 0;
	foreach(@sockets){
		if (lc($_) =~ /listen/) {
			$listen++;
		}
		if (lc($_) =~ /established/) {
			$established++;
		}
		if (lc($_) =~ /idle/) {
			$idle++;
		}
		if (lc($_) =~ /bound/) {
			$bound++;
		}
		if (lc($_) =~ /unbound/) {
			$unbound++;
		}
		%socketstats = (
			'listen'=>$listen,
			'established'=>$established,
			'idle'=>$idle,
			'bound'=>$bound,
			'unbound'=>$unbound,
		);
	}
	$stats{"sockets"} = \%socketstats;	

##########
# Uptime #
##########
	
	my %uptimestats = (
			'days'=>$loadavg[4],
			'hours'=>$loadavg[6],
			'minutes'=>$loadavg[7],
	);

	$stats{"uptime"} = \%uptimestats;

#############
# Processes #
#############

	my %procstats;
	$stdout = $ssh->capture("ps -ef -o user,pid,pcpu,vsz,etime,s,comm");
	my @procs = split(/\n/,$stdout);

	#print Dumper(@procs);
	
	shift @procs;
	foreach(@procs)
	{
		$_ =~ s/^\s+//;
		my @proc = (split /\s+/, $_);
		#print Dumper(@proc);
		my @etime = (split /-/, $proc[4]);
		my $fulletime;
		foreach (@etime){
			if ($etime[1]){
				$fulletime = $etime[0]." days ".$etime[1];
			}
			else {
				$fulletime = "0 days ".$etime[0];
			}
		}
		my %stats = (
			"name"=>$proc[6],
			"user"=>$proc[0],
			"cpu"=>$proc[2],
			"mem"=>$proc[3],
			"pid"=>$proc[1],
			"state"=>$proc[5],
			"etime"=>$fulletime				
		);
		$procstats{$proc[1]} = \%stats;	
	}
	$stats{"procs"} = \%procstats;

#########
# Users #
#########

	$stdout = $ssh->capture("who | wc -l");
	chomp $stdout;
	
	my %userstats = (
		'connected'=>$loadavg[8]
	);

 	
	$stats{"users"} = \%userstats;	

##############
# Disk Usage #
##############	

	$stdout = $ssh->capture("df -k");
	
	my @disks = split(/\n/,$stdout);
	
	shift @disks;
	#print Dumper(@disks);
	
	my %diskstats;
	$count = 0;
	foreach(@disks)
	{
		
		my @stats = split /[():\s]+/, $_;
		#print Dumper(@stats);
		if(@stats == 6)
		{	
			my $capacity = $stats[4];
			$capacity =~ tr/%//d;

			my %stats = (
				"available"=>$stats[3],
				"used"=>$stats[2],
				"capacity"=>$capacity
			);
			$diskstats{$stats[5]} = \%stats;
		}	
	}
	$stats{"disks"} = \%diskstats;

	unless(open FILE, '>'. $outputpath . $host.".json") 
	{
		$np->nagios_exit(return_code=> UNKNOWN, message => "Unable to open $outputpath$host.json");	
	}
	flock(FILE,2) || $np->nagios_exit(return_code=> UNKNOWN, message => "Unable to lock file $outputpath$host.json");	
	print FILE encode_json \%stats;
	close FILE;

my $end_time = [gettimeofday];
$np->add_perfdata( label => "time", uom=>'s', value => sprintf("%.3f",tv_interval($start_time,$end_time)), warning => $np->opts->warning, critical => $np->opts->critical);
$np->nagios_exit(return_code=> $np->check_threshold(check => tv_interval($start_time,$end_time)), message => "Collected data for $host in " . sprintf("%.3f",tv_interval($start_time,$end_time)). " seconds");