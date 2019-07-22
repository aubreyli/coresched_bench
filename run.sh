if [ -z "$1" ]; then
	echo "num of utilization level missing..."
	exit
fi

bench_time=10

sudo mkdir -p /sys/fs/cgroup/cpu/sysbench
sudo mkdir -p /sys/fs/cgroup/cpu/gemmbench

log_prefix="default"
if [ -z "$2" ]; then
	echo "core scheduling disabled"
	echo 0 | sudo tee /sys/fs/cgroup/cpu/sysbench/cpu.tag
	echo 0 | sudo tee /sys/fs/cgroup/cpu/gemmbench/cpu.tag
	log_prefix="default"

else
	echo "core scheduling enabled"
	echo 1 | sudo tee /sys/fs/cgroup/cpu/sysbench/cpu.tag
	echo 1 | sudo tee /sys/fs/cgroup/cpu/gemmbench/cpu.tag
	log_prefix="coresched"
fi

vmstat 1 &> ./log/cpu"_"$log_prefix"_"$1.log &

echo "start avx512 benchmark..."
for i in `seq 1 $1`
do
	sudo cgexec -g cpu:gemmbench ./gemmbench &> /dev/null &
done
sleep 1

echo "start sysbench benchmark..."
sudo cgexec -g cpu:sysbench sysbench --report-interval=1 --time=$bench_time --threads=$1 oltp_read_only.lua --mysql-host=localhost --mysql-port=3306 --mysql-user=root --mysql-password=<your_mysql_password> --mysql-db=sbtest --table-size=10000000 run &> ./log/$log_prefix"_"$1.log
sleep 1

sudo pkill gemmbench
pkill vmstat
echo "benchmark $1 done"
