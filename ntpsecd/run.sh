REFNTPSERVER1="${REFNTPSERVER1:-0.resinio.pool.ntp.org}"
REFNTPSERVER2="${REFNTPSERVER2:-1.resinio.pool.ntp.org}"

echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

mkdir -p /etc/ntpsec/

if [ -f /etc/ntp.conf.new ]
then
  mv /etc/ntp.conf.new /etc/ntpsec/ntp.conf
fi

echo "Setting first reference ntp server to: ${REFNTPSERVER1}"
sed -i "s/NTPSERVER1/${REFNTPSERVER1}/g" /etc/ntpsec/ntp.conf
echo "Setting second reference ntp server to: ${REFNTPSERVER2}"
sed -i "s/NTPSERVER2/${REFNTPSERVER2}/g" /etc/ntpsec/ntp.conf

/usr/sbin/ntpd -g -c /etc/ntpsec/ntp.conf

if [ $? -eq 0 ]
then
  echo "Success: ntp running."
else
  echo "Failure: ntp gave a non-zero return code" >&2
  exit 8
fi

DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.StopUnit string:'chronyd.service' string:'fail'

while [ 1 = 1 ]
do
  sleep 60
  pgrep ntp > /dev/null && echo "NTP still active" || exit 8
done

