NDB_PERF_BASEDIR=$HOME/mysql
NDB_PERF_CONFIG=$HOME/ndb.cnf
NDB_PERF_DEFAULT_TABLE_COUNT=64
NDB_PERF_DEFAULT_TABLE_SIZE=10000000
NDB_PERF_DEFAULT_PASSWORD=TAKE0one
# HDD
NDB_PERF_LOG_PATH_1=blob://store-hl/hdd-01/public/
# HDD, LQ, 6 nodes
NDB_PERF_LOG_PATH_2=blob://store-hl/doc_hdd_test3/public/
# NVME SSD, HL-SY, 3 nodes
NDB_PERF_LOG_PATH_3=blob://store-hl/ndb_test_2/public/
# NVME SSD, 6 nodes
NDB_PERF_DATA_PATH_1=blob://store-hl/pst-normal-df-0/public/
# NVME SSD, 10 nodes
NDB_PERF_DATA_PATH_2=blob://store-hl/pst-normal-nvme-0/public/
# SATA SSD, 3 nodes
NDB_PERF_DATA_PATH_3=blob://store-hl/store-pst-test2/public/
# NVME SSD, HL-SY, 10 nodes
NDB_PERF_DATA_PATH_4=blob://store-hl/pst-normal-nvme-1/public/

function ndbperfstart()
{
  NDB_DATADIR=$(cat $CMDDIR/ndb.cfg | awk '{print $1}')
  if [ ! -d $NDB_DATADIR/mysql ]; then
    echo "Data directory $NDB_DATADIR is not initialized yet"
    return
  fi

  if [ ! -f $NDB_PERF_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PERF_CONFIG"
    return
  fi

  TYPE=$1
  if [ -z $TYPE ]; then
    echo "Start ByteNDB server in normal mode"
    mysqld --defaults-file=$NDB_PERF_CONFIG --datadir=$NDB_DATADIR --gdb > $NDB_DATADIR/error.log 2>&1 &
  elif [ $TYPE = "safe" ]; then
    echo "Start ByteNDB server in safe mode"
    mysqld_safe --defaults-file=$NDB_PERF_CONFIG --datadir=$NDB_DATADIR --gdb > $NDB_DATADIR/error.log 2>&1 &
  elif [ $TYPE = "trace" ]; then
    echo "Start ByteNDB server in tracing mode"
    mysqld --defaults-file=$NDB_PERF_CONFIG --datadir=$NDB_DATADIR --gdb --debug=d:t:i:o,$PWD/mysqld.trace > $NDB_DATADIR/error.log 2>&1 &
  elif [ $TYPE = "querylog" ]; then
    echo "Start ByteNDB server with slow query log"
    mysqld --defaults-file=$NDB_PERF_CONFIG --datadir=$NDB_DATADIR --gdb --slow_query_log=1 --slow_query_log_file=$NDB_DATADIR/slowquery.log --long_query_time=0 --min_examined_row_limit=0 > $NDB_DATADIR/error.log 2>&1 &
  elif [ $TYPE = "gdb" ]; then
    echo "Debugging ByteNDB server with gdb"
    CMDFILE=$CMDDIR/loadmysql2.cmd
    cat $CMDDIR/loadmysql.cmd > $CMDFILE
    echo >> $CMDFILE
    echo "set pagination off" >> $CMDFILE
    echo "set non-stop on" >> $CMDFILE
    echo "set target-async on" >> $CMDFILE
    echo "b srv_start" >> $CMDFILE
    echo "b recv_recovery_from_checkpoint_start" >> $CMDFILE
    echo "r --defaults-file=$NDB_PERF_CONFIG --datadir=$NDB_DATADIR --gdb" >> $CMDFILE
    if [ `which cgdb` ]; then
      cgdb -x $CMDFILE $NDB_PERF_BASEDIR/bin/mysqld
    else
      gdb -x $CMDFILE $NDB_PERF_BASEDIR/bin/mysqld
    fi
  else
    echo "Unknown starting mode"
  fi
}

function ndbperfstop()
{
  if [ ! -f $NDB_PERF_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PERF_CONFIG"
    return
  fi

  mysqladmin --defaults-file=$NDB_PERF_CONFIG --user=root --password=$NDB_PERF_DEFAULT_PASSWORD shutdown
}

function ndbperfconnect()
{
  DBNAME=$1
  if [ -z $DBNAME ]; then
    DBNAME=test
  fi

  if [ ! -f $NDB_PERF_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PERF_CONFIG"
    return
  fi

  mysql --defaults-file=$NDB_PERF_CONFIG --user=root --password=$NDB_PERF_DEFAULT_PASSWORD $DBNAME
}

function ndbperfinit()
{
  NDBPROC=`ps -ef | grep $USER | grep mysqld | grep -v safe | grep -v grep | awk '{print $2}'`
  if [ -z "$NDBPROC" ]; then
    echo "ByteNDB server is not active"
  else
    ndbstop
  fi

  MYSQLDVER=$(mysqld --version)
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  BASE_DATADIR=$1
  if [ -z $1 ]; then
    BASE_DATADIR=$HOME
  fi

  if [ ! -d $BASE_DATADIR ]; then
    echo "Unable to find base data directory $BASE_DATADIR"
    return
  fi

  NDB_DATADIR=$BASE_DATADIR/ndb_data
  rm -rf $NDB_DATADIR
  NDB_TMPDIR=$BASE_DATADIR/ndb_tmp
  rm -rf $NDB_TMPDIR
  NDB_LOGDIR=$BASE_DATADIR/ndb_log
  rm -rf $NDB_LOGDIR

  rm -f $NDB_PERF_CONFIG
  cp $CMDDIR/mysql_perf.cnf $NDB_PERF_CONFIG

  PORT=3600
  if [ ! -z "$(echo $MYSQLDVER | grep 5.6)" ]; then
    sed -i '/secure-file-priv/d' $NDB_PERF_CONFIG
  fi
  sed -i '/innodb_file_per_table/d' $NDB_PERF_CONFIG
  sed -i '/innodb_buffer_pool_size/d' $NDB_PERF_CONFIG
  sed -i '/port/d' $NDB_PERF_CONFIG
  sed -i '/socket/d' $NDB_PERF_CONFIG
  sed -i '/skip-networking/d' $NDB_PERF_CONFIG
  sed -i '/performance_schema/d' $NDB_PERF_CONFIG
  sed -i '/thread_handling/d' $NDB_PERF_CONFIG
  sed -i '/innodb_log_file_size/d' $NDB_PERF_CONFIG
  echo "default-time-zone='+8:00'" >> $NDB_PERF_CONFIG
  echo "log-bin=mysql-bin" >> $NDB_PERF_CONFIG
  echo "sync_binlog=1" >> $NDB_PERF_CONFIG
  echo "server-id=1" >> $NDB_PERF_CONFIG
  echo "binlog-format=row" >> $NDB_PERF_CONFIG
  # Turn on GTID for ByteNDB
  echo "gtid-mode=on" >> $NDB_PERF_CONFIG
  echo "enforce-gtid-consistency" >> $NDB_PERF_CONFIG
  echo "log-slave-updates" >> $NDB_PERF_CONFIG
  echo "master-info-repository=TABLE" >> $NDB_PERF_CONFIG
  echo "relay-log-info-repository=TABLE" >> $NDB_PERF_CONFIG
  echo "binlog-checksum=NONE" >> $NDB_PERF_CONFIG
  # Disable binlog for ByteNDB
  echo "disable_log_bin" >> $NDB_PERF_CONFIG
  mkdir -p $NDB_TMPDIR
  echo "tmpdir=$NDB_TMPDIR" >> $NDB_PERF_CONFIG
  echo "innodb_data_file_path=ibdata1:512M:autoextend" >> $NDB_PERF_CONFIG
  echo "innodb_file_per_table=1" >> $NDB_PERF_CONFIG
  echo "innodb_buffer_pool_size=128G" >> $NDB_PERF_CONFIG
  echo "innodb_log_writer_group_commit_timeout=500" >> $NDB_PERF_CONFIG
  echo "innodb_log_writer_group_commit_len=64K" >> $NDB_PERF_CONFIG
  echo "loose-innodb_mock_server_host=localhost:8080" >> $NDB_PERF_CONFIG
  echo "thread_handling=pool-of-threads" >> $NDB_PERF_CONFIG
  echo "thread_pool_size=64" >> $NDB_PERF_CONFIG
  echo "thread_pool_stall_limit=10" >> $NDB_PERF_CONFIG
  echo "thread_pool_idle_timeout=60" >> $NDB_PERF_CONFIG
  echo "thread_pool_max_threads=50000" >> $NDB_PERF_CONFIG
  echo "thread_pool_oversubscribe=128" >> $NDB_PERF_CONFIG
  echo "log_path=$NDB_PERF_LOG_PATH_1" >> $NDB_PERF_CONFIG
  echo "data_path=$NDB_PERF_DATA_PATH_2" >> $NDB_PERF_CONFIG
  INSTANCE_ID=test$(date +%s)
  echo "instance_id=$INSTANCE_ID" >> $NDB_PERF_CONFIG
  echo "log_write_parallelism=32" >> $NDB_PERF_CONFIG
  mkdir -p $NDB_LOGDIR
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/1/lst_log
  echo "log_lst_log_level=info" >> $NDB_PERF_CONFIG
  echo "log_lst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/1/lst_log" >> $NDB_PERF_CONFIG
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/1/pst_log
  echo "log_pst_log_level=info" >> $NDB_PERF_CONFIG
  echo "log_pst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/1/pst_log" >> $NDB_PERF_CONFIG
  echo "bind-address=0.0.0.0" >> $NDB_PERF_CONFIG
  #echo "skip-grant-tables" >> $NDB_PERF_CONFIG
  echo "port=$PORT" >> $NDB_PERF_CONFIG
  echo "socket=/tmp/ndb.socket.$USER" >> $NDB_PERF_CONFIG
  echo "[client]" >> $NDB_PERF_CONFIG
  echo "port=$PORT" >> $NDB_PERF_CONFIG
  echo "socket=/tmp/ndb.socket.$USER" >> $NDB_PERF_CONFIG

  echo $MYSQLDVER
  echo "Initialize data directory with password $NDB_PERF_DEFAULT_PASSWORD"
  mysqld --defaults-file=$NDB_PERF_CONFIG --initialize --init-file=$CMDDIR/mysql8_init.sql --basedir=$NDB_PERF_BASEDIR --datadir=$NDB_DATADIR
  cat $NDB_DATADIR/error.log

  # Save configuration
  echo "$NDB_DATADIR" > $CMDDIR/ndb.cfg
}

function ndbperfprepare()
{
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  DBNAME=test
  DBUSER=root
  DBPORT=3600
  DBHOST=$1
  if [ -z $DBHOST ]; then
    DBHOST=$LOCALIP
  fi

  sysbench --test=tests/db/parallel_prepare.lua --oltp_tables_count=$NDB_PERF_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_PERF_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_PERF_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --num-threads=$NDB_PERF_DEFAULT_TABLE_COUNT --report-interval=10 --percentile=99 run
}

function ndbperfrunwrite()
{
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  DBNAME=test
  DBUSER=root
  DBPORT=3600
  DBHOST=$3
  if [ -z $DBHOST ]; then
    DBHOST=$LOCALIP
  fi

  DURATION=$1
  CONCURRENCY=$2
  if [ -z $DURATION ]; then
    DURATION=60
  fi
  if [ -z $CONCURRENCY ]; then
    CONCURRENCY=100
  fi

  sysbench --test=tests/db/oltp.lua --mysql-table-engine=innodb --oltp_tables_count=$NDB_PERF_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_PERF_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_PERF_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --rand-type=uniform --num-threads=$CONCURRENCY --max-requests=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=off --report-interval=10 --percentile=99 --forced-shutdown=3 run
}

function ndbperfrunread()
{
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  DBNAME=test
  DBUSER=root
  DBPORT=3600
  DBHOST=$3
  if [ -z $DBHOST ]; then
    DBHOST=$LOCALIP
  fi

  DURATION=$1
  CONCURRENCY=$2
  if [ -z $DURATION ]; then
    DURATION=60
  fi
  if [ -z $CONCURRENCY ]; then
    CONCURRENCY=100
  fi

  sysbench --test=tests/db/oltp.lua --oltp_tables_count=$NDB_PERF_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_PERF_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_PERF_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --db-dirver=mysql --num-threads=$CONCURRENCY --max-requests=0 --oltp_simple_ranges=0 --oltp-distinct-ranges=0 --oltp-sum-ranges=0 --oltp-order-ranges=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=on --report-interval=10 --percentile=99 --forced-shutdown=3 run
}

function ndbperfrunpurewrite()
{
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  DBNAME=test
  DBUSER=root
  DBPORT=3600
  DBHOST=$3
  if [ -z $DBHOST ]; then
    DBHOST=$LOCALIP
  fi

  DURATION=$1
  CONCURRENCY=$2
  if [ -z $DURATION ]; then
    DURATION=60
  fi
  if [ -z $CONCURRENCY ]; then
    CONCURRENCY=100
  fi

  sysbench --test=tests/db/oltp.lua --mysql-table-engine=innodb --oltp_tables_count=$NDB_PERF_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_PERF_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_PERF_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --rand-type=uniform --num-threads=$CONCURRENCY --max-requests=0 --max-requests=0 --oltp_simple_ranges=0 --oltp-distinct-ranges=0 --oltp-sum-ranges=0 --oltp-order-ranges=0 --oltp-point-selects=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=off --report-interval=10 --percentile=99 --forced-shutdown=3 run
}
