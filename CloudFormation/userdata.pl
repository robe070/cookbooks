#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use File::Path;

# -----------------------------------------------------------------------------
# Simple subs to make it clear when we're testing for BOOL values
# -----------------------------------------------------------------------------

sub TRUE   {return(1);} # BOOLEAN TRUE
sub FALSE  {return(0);} # BOOLEAN FALSE

our ($Initialised, %option ) ;

if ( !$Initialised )
{
    Init();
    $Initialised = 1;
}

#`adduser $option{u} -g lansa` or `/opt/aws/bin/cfn-signal -e 1 -r "Error adding user\n" '$option{w}'` and die "Error adding user\n";
#`echo $option{p} | passwd --stdin $option{u}` or `/opt/aws/bin/cfn-signal -e 1 -r "Error changing password\n"'$option{w}'` and die "Error changing password\n";
#"# Clone the LANSA repository\n",
#"git clone git://github.com/robe070/lansalinux /opt/lansa\n",
#"# Clone the Auto Pull script\n",
#"git clone git://github.com/lansalpc/github-auto-pull.git /var/www/cgi-bin\n",
#"/opt/aws/bin/cfn-signal -e $? '", { "Ref" : "WaitHandle" }, "'\n"
signal( 0, "Successfully ran script\n");

sub signal
# Parm 0 - error code
# Parm 1 - message text to send
{
    my( $errno, $message ) = @_;
    if ( !defined $errno) {
        $errno = 0;
    }
    
    if (!defined $message)
    {
        $message = "Success\n";
        if ($errno > 0 ) {
            $message = "Failed\n";
        }
    }
    
    my( $errstate) = "true";
    if ( $errno > 0 ) {
        $errstate = "false";
    }
    
    print $message;
    `/opt/aws/bin/cfn-signal -e $errstate -r $message "$option{w}"`;
}

sub Init
{
    # Allow -d, -p, etc. If any other switches, display usage and exit.
    
    if (!getopts("d:p:r:s:u:w:", \%option))
    {
       Usage();
       signal();
       exit;
    }
    
    print "-d = $option{d}\n" if defined $option{d};
    print "-p = $option{p}\n" if defined $option{p};
    print "-r = $option{r}\n" if defined $option{r};
    print "-s = $option{s}\n" if defined $option{s};
    print "-u = $option{u}\n" if defined $option{u};
    print "-w = $option{w}\n" if defined $option{w};
    
    # Mandatory Parms
    if (!(defined $option{d} && defined $option{p} && defined $option{s} && defined $option{s} && defined $option{u} && defined $option{w})) {
       Usage();
       exit;        
    }
    
    # Validate Parms
    
    # End Validate Parms

    $SIG{INT} = \&KillChildren;
    $SIG{HUP} = \&KillChildren;
}

sub KillChildren
{
    local $SIG{HUP} = 'IGNORE'; # don't kill myself yet.
    # Kill all children
    print "Killing children...\n";
    kill HUP => -$$;
    print "Finished\n";
    exit;
}

sub Usage
{
print<<USAGE;
Switches
Name                Switch  Default
Database Name       -d      Mandatory
Password            -p      Mandatory
Region              -r      Mandatory
Stack Id            -s      Mandatory
User Name           -u      Mandatory
Wait Handle         -w      Mandatory.

USAGE
}
