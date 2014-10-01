#!/usr/bin/python
"Fabric script"

# Support 3.x syntax in 2.7
# See this link for differences berween 2 and 3:
# http://python-future.org/compatible_idioms.html
# from __future__ import (absolute_import, division, print_function, unicode_literals)
from __future__ import (print_function)
# from future.builtins import *       # pylint: disable=wildcard-import
# End of 3.x syntax setup

def hello( name="world", fromarg="Sydney" ):
    "A doc string"
    print( "Hello %s from %s!" % (name, fromarg) )
