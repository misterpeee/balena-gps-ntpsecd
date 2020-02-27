function finish {
	echo "termninating, restarting chrony on host OS"
	DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.StartUnit string:'chronyd.service' string:'fail'
}

trap finish EXIT 

curl -v --silent $BALENA_SUPERVISOR_ADDRESS/v2/applications/state?apikey=$BALENA_SUPERVISOR_API_KEY 2>&1 |  grep "\"ntpsecd\":{\"status\":\"Running\""
  if [ $? -eq 0 ]
   then
   echo "Checked ntpsecd is running"
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.StopUnit string:'chronyd.service' string:'fail'
  fi

while [ 1 = 1 ]
do
        curl -v --silent $BALENA_SUPERVISOR_ADDRESS/v2/applications/state?apikey=$BALENA_SUPERVISOR_API_KEY 2>&1 |  grep "\"ntpsecd\":{\"status\":\"Running\""
	if [ $? -eq 0 ]
        then
         echo "Checked ntpsecd is still running"
	 sleep 30
        else
         echo "Found ntpsecd is not running - Restarting chronyd on host OS" >&2
	 DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.StartUnit string:'chronyd.service' string:'fail'
	 sleep 30
        fi
        done
