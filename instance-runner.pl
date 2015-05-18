#!/usr/bin/perl -w
use strict;
use POSIX ':sys_wait_h';
use POSIX qw(WNOHANG);
use Errno qw(EAGAIN);
use FindBin;

$SIG{CHLD} = \&fCleanChld;

unless (scalar(@ARGV)) {
    print "\n  ", $FindBin::RealScript, <<'EOF';
 <cmd_to_run>  [<number_of_tasks>]   [<number_of_childs>]
 
- <cmd_to_run> - the name of program, that should be run;
- [<number_of_tasks>]  - number of tasks.
  This argument argument is, default value is 1;
- [<number_of_childs>] - number of child process in one "task".
  This argument is optional, default value is 1.

EOF
    exit;
};

my $strCmdName = $ARGV[0];

# How many times to run "task"
my $intNumberOfTasks;
if (defined $ARGV[1] ) {
    $intNumberOfTasks = $ARGV[1];
} else {
    $intNumberOfTasks = 1;
};
if ($intNumberOfTasks =~ /\D/) {
    die "The number of tasks must be numerical!";
};

# Set number of child-processs in one "task"
my $intNumberOfChlds;
if (defined $ARGV[2] ) {
    $intNumberOfChlds = $ARGV[2];
} else {
    $intNumberOfChlds = 1;
};
if ($intNumberOfChlds =~ /\D/) {
    die "The number of childs must be numerical!";
};

print "number of childs in one task: $intNumberOfChlds\n";
print "number of tasks:              $intNumberOfTasks\n";

my $intCurrentNumberOfChlds = 0;
my $intCurrentNumberOfTasks = 0;
my %hashChildPIDs;
my $intChldPID;

while ($intCurrentNumberOfTasks < $intNumberOfTasks) {

  $intCurrentNumberOfChlds = 0;    
  while ($intCurrentNumberOfChlds < $intNumberOfChlds) {
    FORK: {  
        if ( $intChldPID = fork ) {
            $hashChildPIDs{$intChldPID} = 'runned';
        }  elsif ( defined($intChldPID)  ) {
        
            # Child process code
            system ($strCmdName);
            exit;

        } elsif ($! == EAGAIN) {
            sleep 5;
            redo FORK;
        } else {
            die("Couldn't fork\n");
        };
    };
    ++$intCurrentNumberOfChlds;
  };

    ++$intCurrentNumberOfTasks;
    
    # Wait for all child process finished
    my $intTimer = 0;
    while ( scalar keys((%hashChildPIDs) ) > 0 ) {

        # If some processes present in process list too long time, check are they alive
        if ($intTimer>3) {
            foreach my $intChldPID ( keys(%hashChildPIDs) ) {
                # remove process if it not answering
                # (may be it finished very quickly)
                unless ( kill( 0, $intChldPID)   ) {
                    delete( $hashChildPIDs{ $intChldPID } );
                };
            };
             $intTimer = 0;
        };
        ++$intTimer;
        sleep (1);
    };
};

sub fCleanChld {
    my $chld;
    while ( ($chld = waitpid(-1, &WNOHANG )) > 0 ) {
        delete($hashChildPIDs{$chld});
    };
    $SIG{CHLD} = \&fCleanChld;
}
