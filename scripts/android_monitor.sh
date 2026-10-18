#!/system/bin/sh
# Once per second for 6 minutes: GPU busy %, GPU clock, CPU clocks per cluster, GPU temperature.
i=0
sleep 5
while [ $i -lt 900 ]; do
  pidof com.uaw.recomp >/dev/null || break
  g=$(cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null)
  gf=$(cat /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq 2>/dev/null)
  c0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
  c3=$(cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_cur_freq 2>/dev/null)
  c7=$(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_cur_freq 2>/dev/null)
  t=$(cat /sys/class/kgsl/kgsl-3d0/temp 2>/dev/null)
  echo "$(date +%H:%M:%S) gpu=$g gfreq=$gf little=$c0 big=$c3 prime=$c7 gtemp=$t"
  i=$((i+1))
  sleep 1
done
