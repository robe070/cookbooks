#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use File::Path;
# use Devel::Trace;

$Devel::Trace::TRACE = 0;

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

$Devel::Trace::TRACE = 1;

`adduser $option{u} -g lansa`;
if ( $? ){ signal( $?, "Error adding user\n"); }

`echo $option{p} | passwd --stdin $option{u}`;
if ( $? ){ signal( $?, "Error changing password\n"); }

if ( $option{t} eq "WebServer") {
    print "Cloning the LANSA Application repository...";
    `git clone -q git://github.com/robe070/lansalinux /opt/lansa`;
    if ( $? ){ signal( $?, "Error cloning LANSA repository\n"); }
    print "done\n";
    
    print "Cloning the auto pull script...";
    `git clone -q git://github.com/lansalpc/github-auto-pull.git /var/www/cgi-bin\n`;
    if ( $? ){ signal( $?, "Error cloning Auto Pull script\n"); }
    print "done\n";
} else {
    print "Cloning the LANSA repository...";
    `git clone -q git://github.com/lansalpc/lansalinux /opt/lansa`;
    if ( $? ){ signal( $?, "Error cloning LANSA repository\n"); }
    print "done\n";
}

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
    
    print "Error = $errno, $message";
    `/opt/aws/bin/cfn-signal -e $errno -r \"$message\" -d \"$option{t}: $message\" \"$option{w}\"`;
    die if ( $errno );
}

sub Init
{
    # Allow -d, -p, etc. If any other switches, display usage and exit.
    
    if (!getopts("d:p:r:s:t:u:w:", \%option))
    {
       Usage();
       signal();
       exit;
    }
    
    print "-d = $option{d}\n" if defined $option{d};
    print "-p = $option{p}\n" if defined $option{p};
    print "-r = $option{r}\n" if defined $option{r};
    print "-s = $option{s}\n" if defined $option{s};
    print "-t = $option{t}\n" if defined $option{t};
    print "-u = $option{u}\n" if defined $option{u};
    print "-w = \"$option{w}\"\n" if defined $option{w};
    
    # Mandatory Parms
    if (!(defined $option{d} && defined $option{p} && defined $option{s} && defined $option{s} && defined $option{t} && defined $option{u} && defined $option{w})) {
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
Type                -t      Mandatory
User Name           -u      Mandatory
Wait Handle         -w      Mandatory.

USAGE
}
