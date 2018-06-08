# Stop iis
iisreset /Stop

# Stop all listeners
for ( $i = 1; $i -le 10; $i++) {
    &"c:\progra~2\app$i\connect64\lcolist.exe" "-sstop"
}

# Stop all web jobs
for ( $i = 1; $i -le 10; $i++) {
    &"c:\progra~2\app$i\X_Win95\X_Lansa\Execute\w3_p2200.exe" "*FORINSTALL"
}

#Start all listeners
for ( $i = 1; $i -le 10; $i++) {
    &"c:\progra~2\app$i\connect64\lcolist.exe" "-sstart"
}

# Start iis
iisreset /Start
