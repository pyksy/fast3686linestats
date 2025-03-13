# Sagemcom FAST3686 Line Stats
Scrape the per-channel power and Signal-to-Noise Ratio stats from a Sagemcom FAST3686 cable modem and output them in human readable or CSV format, or post the values to an InfluxDB database.

# Setup
Copy the dotfile to ~/.fast3686linestats.conf and edit the cable modem and (if needed) InfluxDB credentials there, or export the variables from your shell.

# Usage
```
% bash fast3686linestats.sh -h
Usage: fast3686linestats.sh [-c] [-h] [-i] [-p]
  -c   Output modem line stats in CSV format
  -h   Print this help
  -i   Post modem line stats to InfluxDB
  -p   Pretty print modem line stats in human readable form
```

# Example
```
% bash fast3686linestats.sh -p
DOWNSTREAM
Ch  Power     SNR
01  3.7 dBmV  42.0 dB
02  3.7 dBmV  42.5 dB
03  3.7 dBmV  42.9 dB
04  3.9 dBmV  42.8 dB
05  3.8 dBmV  42.9 dB
06  3.9 dBmV  42.9 dB
07  3.6 dBmV  42.6 dB
08  4.1 dBmV  43.1 dB
09  4.2 dBmV  43.1 dB
10  4.1 dBmV  40.1 dB
11  4.3 dBmV  42.9 dB
12  4.0 dBmV  42.8 dB
13  4.2 dBmV  42.9 dB
14  4.4 dBmV  40.0 dB
15  3.7 dBmV  42.4 dB
16  4.1 dBmV  42.6 dB
17  3.5 dBmV  41.4 dB
18  3.7 dBmV  42.8 dB
19  4.1 dBmV  43.2 dB
20  3.7 dBmV  43.1 dB
21  4.1 dBmV  43.1 dB
22  3.6 dBmV  43.1 dB
UPSTREAM
Ch  Power
01  49.8 dBmV
02  49.8 dBmV
03  50.1 dBmV
05  50.1 dBmV

```

# FAQ
- Q: Does it work with other Sagemcom cable modems?
- A: I don't know, I only have a FAST3686 sold by my ISP.

<!-- -->
- Q: It doesn't work?!
- A: It Works On My Machine (tm)
