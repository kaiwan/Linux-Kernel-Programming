#!/bin/bash
# latency_test.sh
# Sourced from OSADL (lightly modified here): 
#  https://www.osadl.org/uploads/media/mklatencyplot.bash
# Notes:
#  http://www.osadl.org/Create-a-latency-plot-from-cyclictest-hi.bash-script-for-latency-plot.0.html
# Detailed slides on cyclictest, good for understanding latency and it's
# measurement: 'Using and Understanding the Real-Time Cyclictest Benchmark',
# Rowand, Oct 2013: #  https://events.static.linuxfound.org/sites/events/files/slides/cyclictest.pdf
name=$(basename $0)

[ $# -ne 1 ] && {
 echo "Usage: ${name} \"<test title>\""
 exit 1
}
title="$1"

which cyclictest >/dev/null && pfx="" || {
pfx=~/kaiwantech/rtl/rt-tests/   # adjust as required !
 [ ! -x ${pfx}/cyclictest ] && {
   echo "${name}: cyclictest not located, aborting..."
   exit 1
 }
}

echo "--------------------------"
echo "Test Title :: \"${title}\""
echo "--------------------------"
echo "Version info:"
lsb_release -a
uname -a
cat /proc/version
echo

# 1. Redirect the output of cyclictest to a file, for example
loops=100000000
# use -n : clock_nanosleep() ??
#echo "sudo ${pfx}cyclictest -l${loops} -m -Sp90 -i200 -h400 -q >output"
#sudo ${pfx}cyclictest -l${loops} -m -Sp90 -i200 -h400 -q >output
# (Please note that this with loops==100,000,000 will take 5 hours and 33 minutes.)
# alt: by duration
[ 0 -eq 1 ] && {
duration=2h
} || {
duration=12h
}
echo "sudo ${pfx}/cyclictest --duration=${duration} -m -Sp90 -i200 -h400 -q >output"
sudo ${pfx}/cyclictest --duration=${duration} -m -Sp90 -i200 -h400 -q >output

# 2. Get maximum latency
min=$(grep "Min Latencies" output | tr " " "\n" | grep "^[0-9]" | sort -n | head -1 | sed s/^0*//)
max=$(grep "Max Latencies" output | tr " " "\n" | sort -n | tail -1 | sed s/^0*//)
avg=$(grep "Avg Latencies" output | tr " " "\n" | grep "^[0-9]" | sed s/^0*// |awk '{sum += $1} END {print sum/NR}')
latstr="min/avg/max latency: ${min} us / ${avg} us / ${max} us"
echo "${latstr}"

# 3. Grep data lines, remove empty lines and create a common field separator
grep -v -e "^#" -e "^$" output | tr " " "\t" >histogram 

# 4. Set the number of cores, for example
#cores=4
# (If the script is used on a variety of systems with a different number of cores,
# this can, of course, be determined from the system.)
cores=$(lscpu |grep "^CPU(s)" | awk -F: '{print $2}' |awk '{$1=$1};1')

# 5. Create two-column data sets with latency classes and frequency values for each core
for i in $(seq 1 $cores)
do
    column=`expr $i + 1`
    cut -f1,$column histogram >histogram$i
done

# 6. Create plot command header
title="${title}\n\${latstr}\n\kernel ver $(uname -r)"
echo -n -e "set title \"${title}\"\n\
    set terminal png\n\
    set xlabel \"Latency (us), max $max us\"\n\
    set logscale y\n\
    set xrange [0:400]\n\
    set yrange [0.8:*]\n\
    set ylabel \"Number of latency samples\"\n\
    set output \"plot_$(uname -r).png\"\n\
    plot " >plotcmd

# 7. Append plot command data references
for i in $(seq 1 $cores)
do
      if test $i != 1
        then
	    echo -n ", " >>plotcmd
        fi
        cpuno=`expr $i - 1`
        if test $cpuno -lt 10
        then
          title=" CPU$cpuno"
        else
          title="CPU$cpuno"
        fi
        echo -n "\"histogram$i\" using 1:2 title \"$title\" with histeps" >>plotcmd
done

# 8. Execute plot command
gnuplot -persist <plotcmd
