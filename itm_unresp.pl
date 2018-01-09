#!/usr/bin/perl -w
#------------------------------------------------------------------------------
# Licensed Materials - Property of IBM (C) Copyright IBM Corp. 2010, 2010
# All Rights Reserved US Government Users Restricted Rights - Use, duplication
# or disclosure restricted by GSA ADP Schedule Contract with IBM Corp
#------------------------------------------------------------------------------

#  perl itm_unresp.pl
#
#  capture data about agent responsiveness
#
#  This is an example program which you can take ideas from and adapt to your own usage.
#
#  john alvord, IBM Corporation, 1 April 2013
#  jalvord@us.ibm.com
#
# tested on Linux on Z, Perl 5.8.7

use strict;
use File::stat;

my $unresp_version = "0.10000";
my $gWin = (-e "C://") ? 1 : 0;               # 1=Windows, 0=Linux/Unix

# $DB::single=2;

# local tailoring variables

my $local_hub_server = "xxx";                                # server hub name or ip address where hub TEMS runs
my $local_userid     = "userid";                             # valid userid for tacmd login
my $local_password   = "password";                           # password for userid
my $local_agent_code = "lz";                                 # type of agent
my $local_dir        = "/tmp/";                              # directory where touch files are stored
   $local_dir        = "c:/temp/" if $gWin == 1;             # directory where touch files are stored
my $local_ext        = "touch";                              # extension of touch files
my $local_late_secs  = 900;                                  # how late should touch files be
#  $local_dir        = "c:/projects/liveness/";              # testing directory where Windows touch files are stored


my $fake_node = 0;                                           # When 1, adds a fake missing nodeid to test logic
my $fake_online = 0;                                         # When 1, adds fake online nodes without using tacmd


my @GetSitOut = ();                                          # captured output of tacmd
my $line;                                                    # each line of tacmd output
my $cmd;                                                     # command line

print "Online agent check start $unresp_version\n";          # user message

if ($fake_online == 0) {
   $cmd = "/opt/IBM/ITM/bin/tacmd login -s $local_hub_server -u $local_userid -p $local_password";
   @GetSitOut = `$cmd`;

   $cmd = "/opt/IBM/ITM/bin/tacmd listsystems -t $local_agent_code";
   @GetSitOut = `$cmd`;

} else {
   $GetSitOut[0] = "Managed System Name              Product Code Version     Status";
   $GetSitOut[1] = "XXX183.xxxxxx.xxxxxxx.ibm.com:LZ LZ           06.22.07.00 Y";
   $GetSitOut[2] = "XXX184.xxxxxx.xxxxxxx.ibm.com:LZ LZ           06.22.07.00 Y";
   $GetSitOut[3] = "xxx182.xxxxxx.xxxxxxx.ibm.com:LZ LZ           06.22.07.00 Y";
   $GetSitOut[4] = "xxx180:LZ                        LZ           06.22.07.00 Y";
}

my $l = -1;                          # count of tacmd lines, used to skip first one
my $in_node;                         # managed system name
my $in_status;                       # agent status
my $in_nodetype;                     # type of agent
my $in_nodever;                      # agent version
my $msn_ct = -1;                     # count of online agents
my @msn = ();                        # online agents
my %msn_ndx = ();                    # hash from agent name to count index
my @msn_use = ();                    # count of usages

foreach $line (@GetSitOut) {
    chomp $line;                               # remove end of line
    $l += 1;
    next if $l == 0;                           # skip first line
    ($in_node, $in_nodetype, $in_nodever, $in_status) = split(' ', $line);   # capture data
    next if $in_status ne 'Y';                 # skip non-online cases
    $in_node = substr($line,0,32);             # extract agent name
    $in_node =~ s/(^\s+|\s+$)//g;              # remove leading and trailing white space
    $in_node =~ s/:/_/g if $gWin == 1;         # convert to Windows touch file name if running on windows
    $msn_ct += 1;                              # insert into data structure
    $msn[$msn_ct] = $in_node;
    $msn_ndx{$in_node} = $msn_ct;
    $msn_use[$msn_ct] = 0;
}

# fake online inode if wanted
if ($fake_node == 1) {
   $msn_ct += 1;
   $in_node = "XXX185.xxxxxx.xxxxxxx.ibm.com:LZ";
   $in_node =~ s/:/_/g if $gWin == 1;         # convert to Windows touch file name if running on windows
   $msn[$msn_ct] = $in_node;
   $msn_ndx{$in_node} = $msn_ct;
   $msn_use[$msn_ct] = 0;
}


# prepare to extract touch files

my $logdir = $local_dir;
my  @rawfiles = ();
my $f;

#$DB::single=2;
opendir(DIR,$logdir) || die("cannot opendir $logdir: $!\n");      # get list of files in directory

@rawfiles = grep {/^.*\.$local_ext/} readdir(DIR);                # filter by extension type

my $n;                                                            # Index back to names
my $file_mtime;                                                   # file modify time
my $full_file;                                                    # fully qualifued file name
my $sb;                                                           # stat structure
my $local_epoch = time;                                           # current local time in epoch seconds
my $local_late = $local_epoch - $local_late_secs;                 # calculcate late boundary
my $node;                                                         # agent name

foreach $f (sort @rawfiles) {                                     # pick out name in sorted order
#   print "working on $f\n";                                      # debug
   $node = $f;                                                    # extract agent name from filename
   $node =~ s/\.$local_ext//;                                     # ...
   $n = $msn_ndx{$node};                                          # check for msn index
   if (!defined $n) {                                             # if not found, record that
      print "node $node not in online capture\n";
      next;
   }
   $msn_use[$n] += 1;                                             # add to use count
   $full_file = $local_dir . $f;                                  # calculcate fully qualified name
   $sb = stat $full_file;                                         # use stat to get file data
   $file_mtime = $sb->mtime;                                      # capture modify time
   next if $file_mtime >= $local_late;                            # skip if not late
   print "node $node modify[$file_mtime] late[$local_late]\n";    # record late node
}

for ($n=0; $n <= $msn_ct; $n++) {                                 # run through msn data
   next if $msn_use[$n] > 0;                                      # skip if used
   print "Online agent $msn[$n] missing from touch files\n";      # record a missing node
}

print "Online agent check complete\n";                            # record end
exit 0;

#history
# 0.10000                    Initial release
