#  Balena GPS based NTP server 
**Balena-ready NTPD + GPS + AdafruitGPS**

Are you worried about how accurate internet based NTP servers are?  Concerned the devices on your network do not have precise enough time??!  You need a GPS based Stratum 1 NTP server running on a Raspberry PI!

This project is inspired by and has borrowed ideas from:  

 - http://www.unixwiz.net/techtips/raspberry-pi3-gps-time.html
 - https://hackaday.io/project/15137/instructions

Thanks to [Steve Friedl](http://www.unixwiz.net/about/) and [Nick Sayer](https://hackaday.io/nsayer) for sharing!

## Part 1 – Hardware 

I've built and testing this project on a Raspberry Pi 3B+.  The B+ is recommended as it comes with a ethernet port.  Whilst its absolutely possible to use a A Wifi based device, The clients NTP sync may be affected by the inherent latency you get with Wifi.

The GPS receiver used on this project is the Adafruit Ultimate GPS Hat.  The HAT comes pretty much ready to use with the exception being the 40pin connector will need soldering.

Parts list:

- [Raspbery Pi 3B+](https://www.raspberrypi.org/products/raspberry-pi-3-model-b-plus/)
- [AdaFruit Ultimate GPS](https://shop.pimoroni.com/products/adafruit-ultimate-gps-hat-for-raspberry-pi-a-or-b-mini-kit)
- [External Active Antenna](https://shop.pimoroni.com/products/adafruit-gps-antenna-external-active-antenna-3-5v-28db-5-meter-sma)
- [Power Supply](https://shop.pimoroni.com/products/raspberry-pi-universal-power-supply)
- [CR1220 (Optional](https://www.amazon.co.uk/Energizer-CR1220-Lithium-Button-Battery/dp/B000JTIC3Y)
- [Micro SD Card](https://www.amazon.co.uk/SanDisk-microSDHC-Memory-Adapter-Performance/dp/B073JWXGNT/ref=sr_1_6?crid=3IBPK4WTGLMAT&keywords=micro+sd+card&qid=1573296236&s=electronics&sprefix=micro%2Celectronics%2C142&sr=1-6)

A case is optional, but just make sure there is enough space to fit the HAT on top of the Pi!

You will need a soldering iron and solder to attach the 40pin connector to the HAT.  Attaching it is just a case of carefully soldering the pins.  

## Part 2 - How does it work?

The project is based around the following Linux services:

- [GPSD](https://gpsd.gitlab.io/gpsd/index.html)

GPSD is responsible for the communication with the GPS receiver on the HAT via the UART pins 8 & 10 on the Pi's GPIO header.  The GPS data is read from UART pins and inserted into a shared memory area in the Linux Kernel.

Accurate time is core to the function of GPS.  GPS time is theoretically accurate to about 14 nanoseconds, due to the clock drift that atomic clocks experience in GPS transmitters, relative to International Atomic Time. Most receivers lose accuracy in the interpretation of the signals and are only accurate to 100 nanoseconds.  The more satellites a GPS device is locked onto the more accurate the time signal becomes.

- [NTPSec](https://www.ntpsec.org)

The Network Time Protocol (NTP) is a networking protocol for clock synchronization between computer systems over packet-switched, variable-latency data networks. In operation since before 1985, NTP is one of the oldest Internet protocols in current use. NTP was designed by David Mills of the University of Delaware.  The NTPsec project is a secure, hardened, and improved implementation of the NTP.

NTPSec is able to read the GPS time data from the shared memory created by GPSD.

- [PPS](https://en.wikipedia.org/wiki/Pulse-per-second_signal)

A pulse per second (PPS or 1PPS) is an electrical signal that has a width of less than one second and a sharply rising or abruptly falling edge that accurately repeats once per second.   The AdaFruit GPS provides a PPS signal obtained from the satellites it is locked onto via the GPIO pin 4.  The PPS signal is read by the Linux kernel and like GPSD its data is placed into a shared memory area to provide ultra-low latency access.

## Part 3 - How does the project work?

The project is based on 3 services running in their own Docker Containers.

gpsd - This container runs the GPS daemon.  The docker container is granted access to the GPS by exposing the host OS UART device /dev/ttyAMA0.  The container runs in privileged mode and has access to the hosts shared memory to put the GPS data.

ntpsecd - This container runs the ntpsec daemon.  The docker container is granted access to the kernel PPS device on /dev/pps0.  Like GPDS it runs in privileged mode to enable it to manipulate the host OS clock and access the shared memory to obtain the time data from the shared memory area.  At startup, this containing talks to the host OS via DBUS to disable the inbuilt Chrony service and prevent a battle between the NTP in the container and on the host OS.

ntpsecdobserver - This containing monitors the ntp container to ensure it is running.  If for any reason it fails, it restarts the chronyd service on the host OS to prevent the time going out of sync and potentially preventing the OS failing to connect to the Balena services.

## Part 4 - How to deploy the project

Firstly and most importantly the project will currently only work with the production BalenaOS.  If you use the Dev version, the serial tty and HAT may not play nicely and prevent the PI from booting :(

Once your device is booted up and you can see it in the Balena console, the next step is to add a custom configuration variable for your device:

(for Raspberry Pi's 4 and below)

```
RESIN_HOST_CONFIG_dtoverlay - "pi3-miniuart-bt","pps-gpio,gpiopin=4"
RESIN_HOST_CONFIG_nohz = off
```

for Raspberry Pi 5 ive been advised (i havent tested!) the overlay needs modification:

```
RESIN_HOST_CONFIG_dtoverlay - "disable-bt","pps-gpio,gpiopin=4"
RESIN_HOST_CONFIG_nohz = off
RESIN_HOST_CONFIG_dtparam = "uart0"
```

The first variable will disable the onboard Bluetooth reciever that uses the UART port and will also enable the PPS capability in the Linux kernel.

Your raspberry Pi will disable the Bluetooth device reboot.

Once your Pi has rebooted, shut it down and power it off.  You can now attach the GPS HAT!

It may take some time to boot, but it should come up and appear in your console as normal.

Next step is to define a reference NPT server.  It is strongly advised to have at least 2 NTP servers to enable your device to compare the time received from the GPS as well as cater for when the GPS signal are weak or lost completely.

By default, the code will reference the same NTP servers configured by default in the BalenaOS, howeever, it is advisable to use one as local as possible to you.  I am based in the UK, therefore i selected 0.uk.pool.ntp.org & 1.uk.pool.ntp.org.  When the GPS signal is normal, these NTP servers will be used as reference servers in the complexity algorithm used by NTPSec to calculate the time - So they will also assist with accuracy!

You can set your own NTP servers via the optional environment variables REFNTPSERVER1 and REFNTPSERVER2.

Now you have everything ready to go, you can push your code to your application.

Clone the code from the rep and cd into the directory you cloned it to.

Make sure your balena CLI is setup and you are logged in etc.

Simply run: belena push <application name>

Your code will build and be deployed onto your Pi.

## Part 5 - Checking your NTPSec time

You have 2 options:

- Logon to the container directly via the Balena CLI

belena ssh <device uid> <app name>

run: ntpq -p

- From a remote host with ntpq installed

run: ntpq -p <ip of your pi>

Example Output:

```
root@xxxxxxxxxx:/# ntpq -p
     remote                                   refid      st t when poll reach   delay   offset   jitter
=======================================================================================================
+185.121.25.166                          85.199.214.99    2 u   57   64  377  15.6256   0.8717   7.5630
+time.videxio.net                        131.188.3.223    2 u   41   64  377  14.9750   1.3900   1.0695
oPPS(0)                                  .PPS.            0 l    5   16  377   0.0000   0.0042   0.0016
*SHM(0)                                  .GPS.            1 l    9   16  377   0.0000 -42.2027  14.9065
 SHM(2)                                  .SHM2.           0 l    -   16    0   0.0000   0.0000   0.0019
root@xxxxxxxxxxx:/# 
```

Checking the output:

\* indicates the time source is being used

o indicates the PPS signal is being used to increase the time accurancy

Now all you need to do is ensure your devices are configured to obtain time from your device - This is best done by updating your dhcp server to pass the ip address of your PI as the NTP server.

Enjoy! :+1:
