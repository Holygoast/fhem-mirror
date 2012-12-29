##############################################
# $Id: $
package main;

use strict;
use warnings;
use IO::Socket::INET;

sub BlockingCall($$$$);


=pod
### Usage:
sub TestBlocking() { BlockingCall("DoSleep", 5, "SleepDone", 8); }
sub DoSleep($)     { sleep(shift); return "I'm done"; }
sub SleepDone($)   { Log 1, "SleepDone: " . shift; }

=cut


sub
BlockingCall($$$$)
{
  my ($blockingFn, $arg, $finishFn, $timeout) = @_;

  my $pid = fork;
  if(!defined($pid)) {
    Log 1, "Cannot fork: $!";
    return undef;
  }

  if($pid) {
    InternalTimer(gettimeofday()+$timeout, "BlockingKill", $pid, 0)
      if($timeout);
    return $pid;
  }

  # Child here
  no strict "refs";
  my $ret = &{$blockingFn}($arg);
  use strict "refs";

  # Look for the telnetport
  my $tp;
  foreach my $d (sort keys %defs) {
    my $h = $defs{$d};
    next if(!$h->{TYPE} || $h->{TYPE} ne "telnet" || $h->{TEMPORARY});
    next if($attr{$d}{SSL} || $attr{$d}{password});
    next if($h->{DEF} =~ m/IPV6/);
    $tp = $d;
    last;
  }

  if(!$tp) {
    Log 1, "CallBlockingFn: No telnet port found for sending the data back.";
    exit(0);
  }

  # Write the data back, calling the function
  my $addr = "localhost:$defs{$tp}{PORT}";
  my $client = IO::Socket::INET->new(PeerAddr => $addr);
  Log 1, "CallBlockingFn: Can't connect to $addr\n" if(!$client);
  $ret =~ s/'/\\'/g;
  syswrite($client, "{$finishFn('$ret')}\n");
  exit(0);
}

sub
BlockingKill($)
{
  my $pid = shift;
  Log 1, "Terminated $pid" if($pid && kill(9, $pid));
}


1;