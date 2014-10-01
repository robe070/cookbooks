#!/usr/bin/python
"Test Python script"

# Support 3.x syntax in 2.7
# See this link for differences berween 2 and 3:
# http://python-future.org/compatible_idioms.html
# from __future__ import (absolute_import, division, print_function, unicode_literals)
from __future__ import (print_function)
# from future.builtins import *       # pylint: disable=wildcard-import
# End of 3.x syntax setup

import boto
import boto.ec2
import sys
# import math
# import random
# import os
# import re
import argparse

# Global variable declarations
# Pylint thinks these are constants because they are at the module level
# pylint: disable=C0103
region = 'ap-southeast-2'

# pylint: enable=C0103
# End of global variables

def main():
    "Test passing arguments to Python script"
    global region           # pylint: disable=invalid-name

    parser = argparse.ArgumentParser( description="This is an AWS test script")
    parser.add_argument("-r", "--region", dest="region", help="AWS region", default="ap-southeast-2")
    args = parser.parse_args()

    region = args.region

    try:
        print( "connecting to region '", region, "'", sep='' )
        ec2 = boto.ec2.connect_to_region( region )
        if (not ec2):
            raise
    except:
        print( "Error connecting to region '", region, "'", sep='' )
        sys.exit( 3 )

    reservations = ec2.get_all_reservations()
    if ( reservations ):
        print( reservations )
    else:
        print( "No instances created in region %s" % (region))

def printme():
    """Test passing no arguments to function
    Arguments: None
    Return   : None
    """
    print( "test" )

if __name__ == "__main__":
    main()
