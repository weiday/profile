NDB_BASEDIR=$HOME/mysql
NDB_CONFIG=$HOME/ndb.cnf
NDB_PRIMARY_CONFIG=$HOME/ndb_primary.cnf
NDB_REPLICA_CONFIG=$HOME/ndb_replica.cnf
NDB_DEFAULT_TABLE_COUNT=250
NDB_DEFAULT_TABLE_SIZE=25000
NDB_DEFAULT_PASSWORD=TAKE0one
# NVME SSD, LF
NDB_LOG_PATH_1=blob://store-hl/ndb_lf_01/public/
# NVME SSD, LF-SY-LQ
NDB_LOG_PATH_2=blob://store-hl/ndb_3az/public/
# NVME SSD, LQ
NDB_LOG_PATH_3=blob://store-hl/ndb_lq_01/public/
# NVME SSD, LQ
NDB_DATA_PATH_2=blob://store-hl/pst-normal-nvme-0/public/
# NVME SSD, HL-SY
NDB_DATA_PATH_4=blob://store-hl/pst-normal-nvme-1/public/
# NVME SSD, LF
NDB_DATA_PATH_6=blob://store-hl/pst-normal-nvme-3/public/
# NVME SSD, LF-SY-LQ
NDB_DATA_PATH_8=blob://store-hl/pst-lf-sy-lq-001/public/

function ndbstart()
{
  NDB_DATADIR=$(cat $CMDDIR/ndb.cfg | awk '{print $1}')
  if [ ! -d $NDB_DATADIR/mysql ]; then
    echo "Data directory $NDB_DATADIR is not initialized yet"
    return
  fi

  if [ ! -f $NDB_CONFIG ]; then
    echo "Unable to find configuration file $NDB_CONFIG"
    return
  fi

  TYPE=$1
  if [ -z $TYPE ]; then
    echo "Start ByteNDB server in normal mode"
    mysqld --defaults-file=$NDB_CONFIG --datadir=$NDB_DATADIR --gdb > $NDB_DATADIR/error.log 2>&1 &
  elif [ $TYPE = "trace" ]; then
    echo "Start ByteNDB server in tracing mode"
    mysqld --defaults-file=$NDB_CONFIG --datadir=$NDB_DATADIR --gdb --debug=d:t:i:o,$PWD/mysqld.trace > $NDB_DATADIR/error.log 2>&1 &
  elif [ $TYPE = "querylog" ]; then
    echo "Start ByteNDB server with slow query log"
    mysqld --defaults-file=$NDB_CONFIG --datadir=$NDB_DATADIR --gdb --slow_query_log=1 --slow_query_log_file=$NDB_DATADIR/slowquery.log --long_query_time=0 --min_examined_row_limit=0 > $NDB_DATADIR/error.log 2>&1 &
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
    echo "r --defaults-file=$NDB_CONFIG --datadir=$NDB_DATADIR --gdb" >> $CMDFILE
    if [ `which cgdb` ]; then
      cgdb -x $CMDFILE $NDB_BASEDIR/bin/mysqld
    else
      gdb -x $CMDFILE $NDB_BASEDIR/bin/mysqld
    fi
  else
    echo "Unknown starting mode"
  fi
}

function ndbstartprimaryreplica()
{
  PRIMARY_DATADIR=$(cat $CMDDIR/primary.cfg | awk '{print $1}')
  if [ ! -d $PRIMARY_DATADIR/mysql ]; then
    echo "Primary data directory $PRIMARY_DATADIR is not initialized yet"
    return
  fi
  REPLICA_DATADIR=$(cat $CMDDIR/replica.cfg | awk '{print $1}')
  if [ ! -d $REPLICA_DATADIR/mysql ]; then
    echo "Replica data directory $REPLICA_DATADIR is not initialized yet"
    return
  fi

  if [ ! -f $NDB_PRIMARY_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PRIMARY_CONFIG"
    return
  fi
  if [ ! -f $NDB_REPLICA_CONFIG ]; then
    echo "Unable to find configuration file $NDB_REPLICA_CONFIG"
    return
  fi

  echo "Start ByteNDB primary server in normal mode"
  mysqld --defaults-file=$NDB_PRIMARY_CONFIG --datadir=$PRIMARY_DATADIR --gdb > $PRIMARY_DATADIR/error.log 2>&1 &
  echo "Start ByteNDB replica server in normal mode"
  mysqld --defaults-file=$NDB_REPLICA_CONFIG --datadir=$REPLICA_DATADIR --gdb > $REPLICA_DATADIR/error.log 2>&1 &
}

function ndbstartprimary()
{
  PRIMARY_DATADIR=$(cat $CMDDIR/primary.cfg | awk '{print $1}')
  if [ ! -d $PRIMARY_DATADIR/mysql ]; then
    echo "Primary data directory $PRIMARY_DATADIR is not initialized yet"
    return
  fi

  if [ ! -f $NDB_PRIMARY_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PRIMARY_CONFIG"
    return
  fi

  echo "Start ByteNDB primary server in normal mode"
  mysqld --defaults-file=$NDB_PRIMARY_CONFIG --datadir=$PRIMARY_DATADIR --gdb > $PRIMARY_DATADIR/error.log 2>&1 &
}

function ndbstartreplica()
{
  REPLICA_DATADIR=$(cat $CMDDIR/replica.cfg | awk '{print $1}')
  if [ ! -d $REPLICA_DATADIR/mysql ]; then
    echo "Replica data directory $REPLICA_DATADIR is not initialized yet"
    return
  fi

  if [ ! -f $NDB_REPLICA_CONFIG ]; then
    echo "Unable to find configuration file $NDB_REPLICA_CONFIG"
    return
  fi

  echo "Start ByteNDB replica server in normal mode"
  mysqld --defaults-file=$NDB_REPLICA_CONFIG --datadir=$REPLICA_DATADIR --gdb > $REPLICA_DATADIR/error.log 2>&1 &
}

function ndbstop()
{
  if [ ! -f $NDB_CONFIG ]; then
    echo "Unable to find configuration file $NDB_CONFIG"
    return
  fi

  mysqladmin --defaults-file=$NDB_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD shutdown
}

function ndbstopprimaryreplica()
{
  if [ ! -f $NDB_PRIMARY_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PRIMARY_CONFIG"
    return
  fi
  if [ ! -f $NDB_REPLICA_CONFIG ]; then
    echo "Unable to find configuration file $NDB_REPLICA_CONFIG"
    return
  fi

  mysqladmin --defaults-file=$NDB_PRIMARY_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD shutdown
  mysqladmin --defaults-file=$NDB_REPLICA_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD shutdown
}

function ndbconnect()
{
  DBNAME=$1
  if [ -z $DBNAME ]; then
    DBNAME=test
  fi

  if [ ! -f $NDB_CONFIG ]; then
    echo "Unable to find configuration file $NDB_CONFIG"
    return
  fi

  mysql --defaults-file=$NDB_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD $DBNAME
}

function ndbconnectprimary()
{
  DBNAME=$1
  if [ -z $DBNAME ]; then
    DBNAME=test
  fi

  if [ ! -f $NDB_PRIMARY_CONFIG ]; then
    echo "Unable to find configuration file $NDB_PRIMARY_CONFIG"
    return
  fi

  mysql --defaults-file=$NDB_PRIMARY_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD $DBNAME
}

function ndbconnectreplica()
{
  DBNAME=$1
  if [ -z $DBNAME ]; then
    DBNAME=test
  fi

  if [ ! -f $NDB_REPLICA_CONFIG ]; then
    echo "Unable to find configuration file $NDB_REPLICA_CONFIG"
    return
  fi

  mysql --defaults-file=$NDB_REPLICA_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD $DBNAME
}

function ndbinit()
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

  INSTANCE_ID=$1
  if [ -z $1 ]; then
    INSTANCE_ID=test$(date +%s)
  fi

  BASE_DATADIR=$HOME

  NDB_DATADIR=$BASE_DATADIR/ndb_data
  rm -rf $NDB_DATADIR
  NDB_TMPDIR=$BASE_DATADIR/ndb_tmp
  rm -rf $NDB_TMPDIR
  NDB_LOGDIR=$BASE_DATADIR/ndb_log
  rm -rf $NDB_LOGDIR

  rm -f $NDB_CONFIG
  cp $CMDDIR/mysql_perf.cnf $NDB_CONFIG

  PORT=3600
  if [ ! -z "$(echo $MYSQLDVER | grep 5.6)" ]; then
    sed -i '/secure-file-priv/d' $NDB_CONFIG
  fi
  sed -i '/innodb_file_per_table/d' $NDB_CONFIG
  sed -i '/innodb_buffer_pool_size/d' $NDB_CONFIG
  sed -i '/port/d' $NDB_CONFIG
  sed -i '/socket/d' $NDB_CONFIG
  sed -i '/skip-networking/d' $NDB_CONFIG
  sed -i '/performance_schema/d' $NDB_CONFIG
  sed -i '/thread_handling/d' $NDB_CONFIG
  sed -i '/innodb_log_file_size/d' $NDB_CONFIG
  echo "default-time-zone='+8:00'" >> $NDB_CONFIG
  echo "log-bin=mysql-bin" >> $NDB_CONFIG
  echo "sync_binlog=1" >> $NDB_CONFIG
  echo "server-id=1" >> $NDB_CONFIG
  echo "binlog-format=row" >> $NDB_CONFIG
  # Turn on GTID for ByteNDB
  echo "gtid-mode=on" >> $NDB_CONFIG
  echo "enforce-gtid-consistency" >> $NDB_CONFIG
  echo "log-slave-updates" >> $NDB_CONFIG
  echo "master-info-repository=TABLE" >> $NDB_CONFIG
  echo "relay-log-info-repository=TABLE" >> $NDB_CONFIG
  echo "binlog-checksum=NONE" >> $NDB_CONFIG
  # Disable binlog for ByteNDB
  echo "disable_log_bin" >> $NDB_CONFIG
  mkdir -p $NDB_TMPDIR
  echo "tmpdir=$NDB_TMPDIR" >> $NDB_CONFIG
  echo "innodb_data_file_path=ibdata1:512M:autoextend" >> $NDB_CONFIG
  echo "innodb_file_per_table=1" >> $NDB_CONFIG
  echo "innodb_buffer_pool_size=4G" >> $NDB_CONFIG
  echo "loose-mock_server_host=localhost:8080" >> $NDB_CONFIG
  echo "thread_handling=pool-of-threads" >> $NDB_CONFIG
  echo "thread_pool_size=64" >> $NDB_CONFIG
  echo "thread_pool_stall_limit=10" >> $NDB_CONFIG
  echo "thread_pool_idle_timeout=60" >> $NDB_CONFIG
  echo "thread_pool_max_threads=50000" >> $NDB_CONFIG
  echo "thread_pool_oversubscribe=128" >> $NDB_CONFIG
  echo "log_path=$NDB_LOG_PATH_3" >> $NDB_CONFIG
  echo "data_path=$NDB_DATA_PATH_2" >> $NDB_CONFIG
  echo "instance_id=$INSTANCE_ID" >> $NDB_CONFIG
  echo "log_lst_dashboard_port=3400" >> $NDB_CONFIG
  echo "log_pst_dashboard_port=3401" >> $NDB_CONFIG
  mkdir -p $NDB_LOGDIR
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/1/lst_log
  echo "log_lst_log_level=info" >> $NDB_CONFIG
  echo "log_lst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/1/lst_log" >> $NDB_CONFIG
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/1/pst_log
  echo "log_pst_log_level=info" >> $NDB_CONFIG
  echo "log_pst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/1/pst_log" >> $NDB_CONFIG
  echo "bind-address=0.0.0.0" >> $NDB_CONFIG
  #echo "skip-grant-tables" >> $NDB_CONFIG
  echo "port=$PORT" >> $NDB_CONFIG
  echo "socket=/tmp/ndb.socket.$USER" >> $NDB_CONFIG
  echo "[client]" >> $NDB_CONFIG
  echo "port=$PORT" >> $NDB_CONFIG
  echo "socket=/tmp/ndb.socket.$USER" >> $NDB_CONFIG

  echo $MYSQLDVER
  echo "Initialize data directory with password $NDB_DEFAULT_PASSWORD"
  mysqld --defaults-file=$NDB_CONFIG --initialize --init-file=$CMDDIR/mysql8_init.sql --basedir=$NDB_BASEDIR --datadir=$NDB_DATADIR
  cat $NDB_DATADIR/error.log

  # Save configuration
  echo "$NDB_DATADIR" > $CMDDIR/ndb.cfg
}

function ndbinitprimaryreplica()
{
  NDBPROC=`ps -ef | grep $USER | grep mysqld | grep -v safe | grep -v grep | awk '{print $2}'`
  if [ -z "$NDBPROC" ]; then
    echo "ByteNDB server is not active"
  else
    ndbstopprimaryreplica
  fi

  MYSQLDVER=$(mysqld --version)

  INSTANCE_ID=$1
  if [ -z $1 ]; then
    INSTANCE_ID=test$(date +%s)
  fi

  BASE_DATADIR=$HOME

  PRIMARY_DATADIR=$BASE_DATADIR/primary_data
  rm -rf $PRIMARY_DATADIR
  REPLICA_DATADIR=$BASE_DATADIR/replica_data
  rm -rf $REPLICA_DATADIR
  NDB_TMPDIR=$BASE_DATADIR/ndb_tmp
  rm -rf $NDB_TMPDIR
  NDB_LOGDIR=$BASE_DATADIR/ndb_log
  rm -rf $NDB_LOGDIR

  rm -f $NDB_PRIMARY_CONFIG
  cp $CMDDIR/mysql_perf.cnf $NDB_PRIMARY_CONFIG
  rm -f $NDB_REPLICA_CONFIG
  cp $CMDDIR/mysql_perf.cnf $NDB_REPLICA_CONFIG

  PORT=3600
  if [ ! -z "$(echo $MYSQLDVER | grep 5.6)" ]; then
    sed -i '/secure-file-priv/d' $NDB_PRIMARY_CONFIG
  fi
  sed -i '/innodb_file_per_table/d' $NDB_PRIMARY_CONFIG
  sed -i '/innodb_buffer_pool_size/d' $NDB_PRIMARY_CONFIG
  sed -i '/port/d' $NDB_PRIMARY_CONFIG
  sed -i '/socket/d' $NDB_PRIMARY_CONFIG
  sed -i '/skip-networking/d' $NDB_PRIMARY_CONFIG
  sed -i '/performance_schema/d' $NDB_PRIMARY_CONFIG
  sed -i '/thread_handling/d' $NDB_PRIMARY_CONFIG
  sed -i '/innodb_log_file_size/d' $NDB_PRIMARY_CONFIG
  echo "default-time-zone='+8:00'" >> $NDB_PRIMARY_CONFIG
  echo "log-bin=mysql-bin" >> $NDB_PRIMARY_CONFIG
  echo "sync_binlog=1" >> $NDB_PRIMARY_CONFIG
  echo "server-id=1" >> $NDB_PRIMARY_CONFIG
  echo "binlog-format=row" >> $NDB_PRIMARY_CONFIG
  # Turn on GTID for ByteNDB
  echo "gtid-mode=on" >> $NDB_PRIMARY_CONFIG
  echo "enforce-gtid-consistency" >> $NDB_PRIMARY_CONFIG
  echo "log-slave-updates" >> $NDB_PRIMARY_CONFIG
  echo "master-info-repository=TABLE" >> $NDB_PRIMARY_CONFIG
  echo "relay-log-info-repository=TABLE" >> $NDB_PRIMARY_CONFIG
  echo "binlog-checksum=NONE" >> $NDB_PRIMARY_CONFIG
  # Disable binlog for ByteNDB
  echo "disable_log_bin" >> $NDB_PRIMARY_CONFIG
  mkdir -p $NDB_TMPDIR
  echo "tmpdir=$NDB_TMPDIR" >> $NDB_PRIMARY_CONFIG
  echo "innodb_data_file_path=ibdata1:512M:autoextend" >> $NDB_PRIMARY_CONFIG
  echo "innodb_file_per_table=1" >> $NDB_PRIMARY_CONFIG
  echo "innodb_buffer_pool_size=4G" >> $NDB_PRIMARY_CONFIG
  echo "loose-mock_server_host=localhost:8080" >> $NDB_PRIMARY_CONFIG
  echo "thread_handling=pool-of-threads" >> $NDB_PRIMARY_CONFIG
  echo "thread_pool_size=64" >> $NDB_PRIMARY_CONFIG
  echo "thread_pool_stall_limit=10" >> $NDB_PRIMARY_CONFIG
  echo "thread_pool_idle_timeout=60" >> $NDB_PRIMARY_CONFIG
  echo "thread_pool_max_threads=50000" >> $NDB_PRIMARY_CONFIG
  echo "thread_pool_oversubscribe=128" >> $NDB_PRIMARY_CONFIG
  echo "log_path=$NDB_LOG_PATH_3" >> $NDB_PRIMARY_CONFIG
  echo "data_path=$NDB_DATA_PATH_2" >> $NDB_PRIMARY_CONFIG
  echo "instance_id=$INSTANCE_ID" >> $NDB_PRIMARY_CONFIG
  mkdir -p $NDB_LOGDIR
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/1/lst_log
  echo "log_lst_log_level=info" >> $NDB_PRIMARY_CONFIG
  echo "log_lst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/1/lst_log" >> $NDB_PRIMARY_CONFIG
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/1/pst_log
  echo "log_pst_log_level=info" >> $NDB_PRIMARY_CONFIG
  echo "log_pst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/1/pst_log" >> $NDB_PRIMARY_CONFIG
  echo "bind-address=0.0.0.0" >> $NDB_PRIMARY_CONFIG
  echo "port=$PORT" >> $NDB_PRIMARY_CONFIG
  echo "socket=/tmp/ndb.socket.$USER.primary" >> $NDB_PRIMARY_CONFIG
  echo "[client]" >> $NDB_PRIMARY_CONFIG
  echo "port=$PORT" >> $NDB_PRIMARY_CONFIG
  echo "socket=/tmp/ndb.socket.$USER.primary" >> $NDB_PRIMARY_CONFIG

  PORT=$(( PORT+1 ))    # increments $PORT
  if [ ! -z "$(echo $MYSQLDVER | grep 5.6)" ]; then
    sed -i '/secure-file-priv/d' $NDB_REPLICA_CONFIG
  fi
  sed -i '/innodb_file_per_table/d' $NDB_REPLICA_CONFIG
  sed -i '/innodb_buffer_pool_size/d' $NDB_REPLICA_CONFIG
  sed -i '/port/d' $NDB_REPLICA_CONFIG
  sed -i '/socket/d' $NDB_REPLICA_CONFIG
  sed -i '/skip-networking/d' $NDB_REPLICA_CONFIG
  sed -i '/performance_schema/d' $NDB_REPLICA_CONFIG
  sed -i '/thread_handling/d' $NDB_REPLICA_CONFIG
  sed -i '/innodb_log_file_size/d' $NDB_REPLICA_CONFIG
  echo "default-time-zone='+8:00'" >> $NDB_REPLICA_CONFIG
  echo "log-bin=mysql-bin" >> $NDB_REPLICA_CONFIG
  echo "sync_binlog=1" >> $NDB_REPLICA_CONFIG
  echo "server-id=2" >> $NDB_REPLICA_CONFIG
  echo "binlog-format=row" >> $NDB_REPLICA_CONFIG
  # Turn on GTID for ByteNDB
  echo "gtid-mode=on" >> $NDB_REPLICA_CONFIG
  echo "enforce-gtid-consistency" >> $NDB_REPLICA_CONFIG
  echo "log-slave-updates" >> $NDB_REPLICA_CONFIG
  echo "master-info-repository=TABLE" >> $NDB_REPLICA_CONFIG
  echo "relay-log-info-repository=TABLE" >> $NDB_REPLICA_CONFIG
  echo "binlog-checksum=NONE" >> $NDB_REPLICA_CONFIG
  # Disable binlog for ByteNDB
  echo "disable_log_bin" >> $NDB_REPLICA_CONFIG
  echo "tmpdir=$NDB_TMPDIR" >> $NDB_REPLICA_CONFIG
  echo "replica-mode=on" >> $NDB_REPLICA_CONFIG
  echo "innodb_data_file_path=ibdata1:512M:autoextend" >> $NDB_REPLICA_CONFIG
  echo "innodb_file_per_table=1" >> $NDB_REPLICA_CONFIG
  echo "innodb_buffer_pool_size=4G" >> $NDB_REPLICA_CONFIG
  echo "loose-mock_server_host=localhost:8080" >> $NDB_REPLICA_CONFIG
  echo "thread_handling=pool-of-threads" >> $NDB_REPLICA_CONFIG
  echo "thread_pool_size=64" >> $NDB_REPLICA_CONFIG
  echo "thread_pool_stall_limit=10" >> $NDB_REPLICA_CONFIG
  echo "thread_pool_idle_timeout=60" >> $NDB_REPLICA_CONFIG
  echo "thread_pool_max_threads=50000" >> $NDB_REPLICA_CONFIG
  echo "thread_pool_oversubscribe=128" >> $NDB_REPLICA_CONFIG
  echo "log_path=$NDB_LOG_PATH_3" >> $NDB_REPLICA_CONFIG
  echo "data_path=$NDB_DATA_PATH_2" >> $NDB_REPLICA_CONFIG
  echo "instance_id=$INSTANCE_ID" >> $NDB_REPLICA_CONFIG
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/2/lst_log
  echo "log_lst_log_level=info" >> $NDB_REPLICA_CONFIG
  echo "log_lst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/2/lst_log" >> $NDB_REPLICA_CONFIG
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/2/pst_log
  echo "log_pst_log_level=info" >> $NDB_REPLICA_CONFIG
  echo "log_pst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/2/pst_log" >> $NDB_REPLICA_CONFIG
  echo "bind-address=0.0.0.0" >> $NDB_REPLICA_CONFIG
  echo "port=$PORT" >> $NDB_REPLICA_CONFIG
  echo "socket=/tmp/ndb.socket.$USER.replica" >> $NDB_REPLICA_CONFIG
  echo "[client]" >> $NDB_REPLICA_CONFIG
  echo "port=$PORT" >> $NDB_REPLICA_CONFIG
  echo "socket=/tmp/ndb.socket.$USER.replica" >> $NDB_REPLICA_CONFIG

  echo $MYSQLDVER
  echo "Initialize primary data directory with password $NDB_DEFAULT_PASSWORD"
  mysqld --defaults-file=$NDB_PRIMARY_CONFIG --initialize --init-file=$CMDDIR/mysql8_init.sql --basedir=$NDB_BASEDIR --datadir=$PRIMARY_DATADIR
  # No need to initialize replica, just share data with primary.
  cp -R $PRIMARY_DATADIR $REPLICA_DATADIR

  # Save configuration
  echo "$PRIMARY_DATADIR" > $CMDDIR/primary.cfg
  echo "$REPLICA_DATADIR" > $CMDDIR/replica.cfg
}

function ndbattach()
{
  MYSQLD=$NDB_BASEDIR/bin/mysqld
  NDBPROC=$1
  if [ -z $NDBPROC ]; then
    NDBPROC=$(ps -ef | grep $USER | grep mysqld | grep "$NDB_CONFIG" | grep -v safe | grep -v grep | awk '{print $2}')
  fi
  if [ -z "$NDBPROC" ]; then
    echo "Can't find the mysqld to be attached"
  else
    CMDFILE=$CMDDIR/loadmysql.cmd
    gdb -x $CMDFILE $MYSQLD $NDBPROC
  fi
}

function ndbattachprimary()
{
  MYSQLD=$NDB_BASEDIR/bin/mysqld
  NDBPROC=$(ps -ef | grep $USER | grep mysqld | grep "$NDB_PRIMARY_CONFIG" | grep -v safe | grep -v grep | awk '{print $2}')
  if [ -z "$NDBPROC" ]; then
    echo "Can't find the master mysqld to be attached"
  else
    gdb -x $CMDDIR/loadmysql.cmd $MYSQLD $NDBPROC
  fi
}

function ndbattachreplica()
{
  MYSQLD=$NDB_BASEDIR/bin/mysqld
  NDBPROC=$(ps -ef | grep $USER | grep mysqld | grep "$NDB_REPLICA_CONFIG" | grep -v safe | grep -v grep | awk '{print $2}')
  if [ -z "$NDBPROC" ]; then
    echo "Can't find the slave mysqld to be attached"
  else
    gdb -x $CMDDIR/loadmysql.cmd $MYSQLD $NDBPROC
  fi
}

function ndbsingleprepare()
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

  sysbench --test=tests/db/oltp.lua --oltp_tables_count=$NDB_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --num-threads=$NDB_DEFAULT_TABLE_COUNT --report-interval=10 prepare
}

function ndbprepare()
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

  sysbench --test=tests/db/parallel_prepare.lua --oltp_tables_count=$NDB_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --num-threads=$NDB_DEFAULT_TABLE_COUNT --report-interval=10 run
}

function ndbrunwrite()
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

  sysbench --test=tests/db/oltp.lua --mysql-table-engine=innodb --oltp_tables_count=$NDB_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --rand-type=uniform --num-threads=$CONCURRENCY --max-requests=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=off --report-interval=10 --percentile=99 --forced-shutdown=3 run
}

function ndbrunread()
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

  sysbench --test=tests/db/oltp.lua --oltp_tables_count=$NDB_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --db-dirver=mysql --num-threads=$CONCURRENCY --max-requests=0 --oltp_simple_ranges=0 --oltp-distinct-ranges=0 --oltp-sum-ranges=0 --oltp-order-ranges=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=on --report-interval=10 --percentile=99 --forced-shutdown=3 run
}

function ndbrunpurewrite()
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

  sysbench --test=tests/db/oltp.lua --mysql-table-engine=innodb --oltp_tables_count=$NDB_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --rand-type=uniform --num-threads=$CONCURRENCY --max-requests=0 --max-requests=0 --oltp_simple_ranges=0 --oltp-distinct-ranges=0 --oltp-sum-ranges=0 --oltp-order-ranges=0 --oltp-point-selects=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=off --report-interval=10 --percentile=99 --forced-shutdown=3 run
}

function ndbinitmulti()
{
  NDBPROC=`ps -ef | grep $USER | grep mysqld | grep -v safe | grep -v grep | awk '{print $2}'`
  if [ -z "$NDBPROC" ]; then
    echo "ByteNDB server is not active"
  else
    ndbstopmulti $2
  fi

  MYSQLDVER=$(mysqld --version)

  BASE_DATADIR=$HOME
  NUM_REPLICAS=$1
  if [ -z $1 ]; then
    NUM_REPLICAS=15
  fi

  INSTANCE_ID=$2
  if [ -z $2 ]; then
    INSTANCE_ID=test$(date +%s)
  fi

  PRIMARY_DATADIR=$PWD/ndb_data_0
  rm -rf $PRIMARY_DATADIR
  PRIMARY_CONFIG=${NDB_CONFIG}.0
  rm -f $PRIMARY_CONFIG
  cp $CMDDIR/mysql_perf.cnf $PRIMARY_CONFIG

  NDB_TMPDIR=$BASE_DATADIR/ndb_tmp
  rm -rf $NDB_TMPDIR
  NDB_LOGDIR=$BASE_DATADIR/ndb_log
  rm -rf $NDB_LOGDIR

  PORT=3600
  if [ ! -z "$(echo $MYSQLDVER | grep 5.6)" ]; then
    sed -i '/secure-file-priv/d' $PRIMARY_CONFIG
  fi
  sed -i '/innodb_file_per_table/d' $PRIMARY_CONFIG
  sed -i '/innodb_buffer_pool_size/d' $PRIMARY_CONFIG
  sed -i '/port/d' $PRIMARY_CONFIG
  sed -i '/socket/d' $PRIMARY_CONFIG
  sed -i '/skip-networking/d' $PRIMARY_CONFIG
  sed -i '/performance_schema/d' $PRIMARY_CONFIG
  sed -i '/thread_handling/d' $PRIMARY_CONFIG
  sed -i '/innodb_log_file_size/d' $PRIMARY_CONFIG
  echo "default-time-zone='+8:00'" >> $PRIMARY_CONFIG
  echo "log-bin=mysql-bin" >> $PRIMARY_CONFIG
  echo "sync_binlog=1" >> $PRIMARY_CONFIG
  echo "server-id=0" >> $PRIMARY_CONFIG
  echo "binlog-format=row" >> $PRIMARY_CONFIG
  # Turn on GTID for ByteNDB
  echo "gtid-mode=on" >> $PRIMARY_CONFIG
  echo "enforce-gtid-consistency" >> $PRIMARY_CONFIG
  echo "log-slave-updates" >> $PRIMARY_CONFIG
  echo "master-info-repository=TABLE" >> $PRIMARY_CONFIG
  echo "relay-log-info-repository=TABLE" >> $PRIMARY_CONFIG
  echo "binlog-checksum=NONE" >> $PRIMARY_CONFIG
  # Disable binlog for ByteNDB
  echo "disable_log_bin" >> $PRIMARY_CONFIG
  mkdir -p $NDB_TMPDIR
  echo "tmpdir=$NDB_TMPDIR" >> $PRIMARY_CONFIG
  echo "innodb_data_file_path=ibdata1:512M:autoextend" >> $PRIMARY_CONFIG
  echo "innodb_file_per_table=1" >> $PRIMARY_CONFIG
  echo "innodb_buffer_pool_size=4G" >> $PRIMARY_CONFIG
  echo "loose-mock_server_host=localhost:8080" >> $PRIMARY_CONFIG
  echo "thread_handling=pool-of-threads" >> $PRIMARY_CONFIG
  echo "thread_pool_size=64" >> $PRIMARY_CONFIG
  echo "thread_pool_stall_limit=10" >> $PRIMARY_CONFIG
  echo "thread_pool_idle_timeout=60" >> $PRIMARY_CONFIG
  echo "thread_pool_max_threads=50000" >> $PRIMARY_CONFIG
  echo "thread_pool_oversubscribe=128" >> $PRIMARY_CONFIG
  echo "log_path=$NDB_LOG_PATH_3" >> $PRIMARY_CONFIG
  echo "data_path=$NDB_DATA_PATH_2" >> $PRIMARY_CONFIG
  echo "instance_id=$INSTANCE_ID" >> $PRIMARY_CONFIG
  mkdir -p $NDB_LOGDIR
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/0/lst_log
  echo "log_lst_log_level=info" >> $PRIMARY_CONFIG
  echo "log_lst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/0/lst_log" >> $PRIMARY_CONFIG
  mkdir -p $NDB_LOGDIR/$INSTANCE_ID/0/pst_log
  echo "log_pst_log_level=info" >> $PRIMARY_CONFIG
  echo "log_pst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/0/pst_log" >> $PRIMARY_CONFIG
  echo "bind-address=0.0.0.0" >> $PRIMARY_CONFIG
  echo "port=$PORT" >> $PRIMARY_CONFIG
  echo "socket=/tmp/ndb.socket.$USER.0" >> $PRIMARY_CONFIG
  echo "[client]" >> $PRIMARY_CONFIG
  echo "port=$PORT" >> $PRIMARY_CONFIG
  echo "socket=/tmp/ndb.socket.$USER.0" >> $PRIMARY_CONFIG

  echo $MYSQLDVER
  echo "Initialize primary data directory with password $NDB_DEFAULT_PASSWORD"
  mysqld --defaults-file=$PRIMARY_CONFIG --initialize --init-file=$CMDDIR/mysql8_init.sql --basedir=$NDB_BASEDIR --datadir=$PRIMARY_DATADIR

  # Save configuration
  echo "$PRIMARY_DATADIR" > $CMDDIR/ndb.cfg.0

  if [ $NUM_REPLICAS -lt 1 ]; then
    return
  fi

  IFS=$'\n'
  for i in $(seq $NUM_REPLICAS)
  do
    REPLICA_DATADIR=$PWD/ndb_data_${i}
    rm -rf $REPLICA_DATADIR
    REPLICA_CONFIG=${NDB_CONFIG}.${i}
    rm -f $REPLICA_CONFIG
    cp $CMDDIR/mysql_perf.cnf $REPLICA_CONFIG

    PORT=$(( PORT+1 ))    # increments $PORT
    if [ ! -z "$(echo $MYSQLDVER | grep 5.6)" ]; then
      sed -i '/secure-file-priv/d' $REPLICA_CONFIG
    fi
    sed -i '/innodb_file_per_table/d' $REPLICA_CONFIG
    sed -i '/innodb_buffer_pool_size/d' $REPLICA_CONFIG
    sed -i '/port/d' $REPLICA_CONFIG
    sed -i '/socket/d' $REPLICA_CONFIG
    sed -i '/skip-networking/d' $REPLICA_CONFIG
    sed -i '/performance_schema/d' $REPLICA_CONFIG
    sed -i '/thread_handling/d' $REPLICA_CONFIG
    sed -i '/innodb_log_file_size/d' $REPLICA_CONFIG
    echo "default-time-zone='+8:00'" >> $REPLICA_CONFIG
    echo "log-bin=mysql-bin" >> $REPLICA_CONFIG
    echo "sync_binlog=1" >> $REPLICA_CONFIG
    echo "server-id=${i}" >> $REPLICA_CONFIG
    echo "binlog-format=row" >> $REPLICA_CONFIG
    # Turn on GTID for ByteNDB
    echo "gtid-mode=on" >> $REPLICA_CONFIG
    echo "enforce-gtid-consistency" >> $REPLICA_CONFIG
    echo "log-slave-updates" >> $REPLICA_CONFIG
    echo "master-info-repository=TABLE" >> $REPLICA_CONFIG
    echo "relay-log-info-repository=TABLE" >> $REPLICA_CONFIG
    echo "binlog-checksum=NONE" >> $REPLICA_CONFIG
    # Disable binlog for ByteNDB
    echo "disable_log_bin" >> $REPLICA_CONFIG
    echo "tmpdir=$NDB_TMPDIR" >> $REPLICA_CONFIG
    echo "replica-mode=on" >> $REPLICA_CONFIG
    echo "innodb_data_file_path=ibdata1:512M:autoextend" >> $REPLICA_CONFIG
    echo "innodb_file_per_table=1" >> $REPLICA_CONFIG
    echo "innodb_buffer_pool_size=4G" >> $REPLICA_CONFIG
    echo "loose-mock_server_host=localhost:8080" >> $REPLICA_CONFIG
    echo "thread_handling=pool-of-threads" >> $REPLICA_CONFIG
    echo "thread_pool_size=64" >> $REPLICA_CONFIG
    echo "thread_pool_stall_limit=10" >> $REPLICA_CONFIG
    echo "thread_pool_idle_timeout=60" >> $REPLICA_CONFIG
    echo "thread_pool_max_threads=50000" >> $REPLICA_CONFIG
    echo "thread_pool_oversubscribe=128" >> $REPLICA_CONFIG
    echo "log_path=$NDB_LOG_PATH_3" >> $REPLICA_CONFIG
    echo "data_path=$NDB_DATA_PATH_2" >> $REPLICA_CONFIG
    echo "instance_id=$INSTANCE_ID" >> $REPLICA_CONFIG
    mkdir -p $NDB_LOGDIR/$INSTANCE_ID/${i}/lst_log
    echo "log_lst_log_level=info" >> $REPLICA_CONFIG
    echo "log_lst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/${i}/lst_log" >> $REPLICA_CONFIG
    mkdir -p $NDB_LOGDIR/$INSTANCE_ID/${i}/pst_log
    echo "log_pst_log_level=info" >> $REPLICA_CONFIG
    echo "log_pst_log_dir=$NDB_LOGDIR/$INSTANCE_ID/${i}/pst_log" >> $REPLICA_CONFIG
    echo "bind-address=0.0.0.0" >> $REPLICA_CONFIG
    echo "port=$PORT" >> $REPLICA_CONFIG
    echo "socket=/tmp/ndb.socket.$USER.${i}" >> $REPLICA_CONFIG
    echo "[client]" >> $REPLICA_CONFIG
    echo "port=$PORT" >> $REPLICA_CONFIG
    echo "socket=/tmp/ndb.socket.$USER.${i}" >> $REPLICA_CONFIG

    # No need to initialize replica, just share data with primary.
    cp -R $PRIMARY_DATADIR $REPLICA_DATADIR

    # Save configuration
    echo "$REPLICA_DATADIR" > $CMDDIR/ndb.cfg.${i}
  done
  IFS=$' '
}

function ndbstartmulti()
{
  NUM_REPLICAS=$1
  if [ -z $1 ]; then
    NUM_REPLICAS=15
  fi

  PRIMARY_CONFIG=${NDB_CONFIG}.0
  if [ ! -f $PRIMARY_CONFIG ]; then
    echo "Unable to find configuration file $PRIMARY_CONFIG"
    return
  fi
  PRIMARY_DATADIR=$(cat $CMDDIR/ndb.cfg.0 | awk '{print $1}')
  if [ ! -d $PRIMARY_DATADIR/mysql ]; then
    echo "Primary data directory $PRIMARY_DATADIR is not initialized yet"
    return
  fi

  echo "Start ByteNDB primary server in normal mode"
  mysqld --defaults-file=$PRIMARY_CONFIG --datadir=$PRIMARY_DATADIR --gdb > $PRIMARY_DATADIR/error.log 2>&1 &
  echo "ByteNDB primary server is starting "
  while :
  do
    mysql --defaults-file=$PRIMARY_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD mysql -e "select * from information_schema.innodb_tablespaces" > /dev/null 2>&1
    if [ $? = 0 ]; then
      echo
      break
    fi
    printf "."
    sleep 0.5
  done

  IFS=$'\n'
  for i in $(seq $NUM_REPLICAS)
  do
    REPLICA_CONFIG=${NDB_CONFIG}.${i}
    if [ ! -f $REPLICA_CONFIG ]; then
      break
    fi
    REPLICA_DATADIR=$(cat $CMDDIR/ndb.cfg.$i | awk '{print $1}')
    if [ ! -d $REPLICA_DATADIR/mysql ]; then
      echo "Replica data directory $REPLICA_DATADIR is not initialized yet"
      break
    fi

    echo "Start ByteNDB replica server ${i} in normal mode"
    mysqld --defaults-file=$REPLICA_CONFIG --datadir=$REPLICA_DATADIR --gdb > $REPLICA_DATADIR/error.log 2>&1 &
    echo "ByteNDB replica server ${i} is starting "
    while :
    do
      mysql --defaults-file=$REPLICA_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD mysql -e "select * from information_schema.innodb_tablespaces" > /dev/null 2>&1
      if [ $? = 0 ]; then
        echo
        break
      fi
      printf "."
      sleep 0.5
    done
  done
  IFS=$' '
}

function ndbstartserver()
{
  SERVER_ID=$1
  if [ -z $SERVER_ID ]; then
    SERVER_ID=0
  fi

  SERVER_CONFIG=${NDB_CONFIG}.${SERVER_ID}
  if [ ! -f ${SERVER_CONFIG} ]; then
    echo "Unable to find configuration file ${SERVER_CONFIG}"
    return
  fi
  SERVER_DATADIR=$(cat $CMDDIR/ndb.cfg.${SERVER_CONFIG} | awk '{print $1}')
  if [ ! -d ${SERVER_DATADIR}/mysql ]; then
    echo "Server data directory ${SERVER_DATADIR} is not initialized yet"
    return
  fi

  echo "Start ByteNDB server ${SERVER_ID} in normal mode"
  mysqld --defaults-file=${SERVER_CONFIG} --datadir=${SERVER_DATADIR} --gdb > ${SERVER_DATADIR}/error.log 2>&1 &
  echo "ByteNDB server ${SERVER_ID} is starting "
  while :
  do
    mysql --defaults-file=${SERVER_CONFIG} --user=root --password=$NDB_DEFAULT_PASSWORD mysql -e "select * from information_schema.innodb_tablespaces" > /dev/null 2>&1
    if [ $? = 0 ]; then
      echo
      break
    fi
    printf "."
    sleep 0.5
  done
}

function ndbstopmulti()
{
  NUM_REPLICAS=$1
  if [ -z $1 ]; then
    NUM_REPLICAS=15
  fi

  PRIMARY_CONFIG=${NDB_CONFIG}.0
  if [ ! -f $PRIMARY_CONFIG ]; then
    echo "Unable to find configuration file $PRIMARY_CONFIG"
    return
  fi

  echo "Stop ByteNDB primary server"
  mysqladmin --defaults-file=$PRIMARY_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD shutdown

  IFS=$'\n'
  for i in $(seq $NUM_REPLICAS)
  do
    REPLICA_CONFIG=${NDB_CONFIG}.${i}
    if [ ! -f $REPLICA_CONFIG ]; then
      break
    fi

    echo "Stop ByteNDB replica server ${i}"
    mysqladmin --defaults-file=$REPLICA_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD shutdown
  done
  IFS=$' '
}

function ndbconnectserver()
{
  SERVER_ID=$1
  if [ -z $SERVER_ID ]; then
    SERVER_ID=0
  fi

  SERVER_CONFIG=${NDB_CONFIG}.${SERVER_ID}
  if [ ! -f $SERVER_CONFIG ]; then
    echo "Unable to find configuration file $SERVER_CONFIG"
    return
  fi

  DBNAME=$2
  if [ -z $DBNAME ]; then
    DBNAME=test
  fi

  mysql --defaults-file=$SERVER_CONFIG --user=root --password=$NDB_DEFAULT_PASSWORD $DBNAME
}

function ndbrunserverread()
{
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  DBNAME=test
  DBUSER=root
  DBINSTANCE=$1
  DBHOST=$4

  DURATION=$2
  CONCURRENCY=$3
  if [ -z $DBINSTANCE ]; then
    DBINSTANCE=0
  fi
  if [ -z $DURATION ]; then
    DURATION=60
  fi
  if [ -z $CONCURRENCY ]; then
    CONCURRENCY=100
  fi
  if [ -z $DBHOST ]; then
    DBHOST=$LOCALIP
  fi
  DBPORT=$(( DBINSTANCE+3600 ))

  sysbench --test=tests/db/oltp.lua --oltp_tables_count=$NDB_DEFAULT_TABLE_COUNT --mysql-db=$DBNAME --oltp-table-size=$NDB_DEFAULT_TABLE_SIZE --mysql-user=$DBUSER --mysql-password=$NDB_DEFAULT_PASSWORD --mysql-port=$DBPORT --mysql-host=$DBHOST --db-dirver=mysql --num-threads=$CONCURRENCY --max-requests=0 --oltp_simple_ranges=0 --oltp-distinct-ranges=0 --oltp-sum-ranges=0 --oltp-order-ranges=0 --rand-seed=42 --max-time=$DURATION --oltp-read-only=on --report-interval=10 --percentile=99 --forced-shutdown=3 run
}

function ndbconnecthost()
{
  if [ -z "$(cat /etc/issue | grep SUSE)" ]; then
    LOCALIP=$(hostname -I | awk '{print $1}')
  else
    LOCALIP=$(hostname -i | awk '{print $1}')
  fi

  DBHOST=$1
  if [ -z $DBHOST ]; then
    DBHOST=$LOCALIP
  fi

  DBPORT=$2
  if [ -z $DBPORT ]; then
    DBPORT=3600
  fi

  mysql -h $DBHOST -P $DBPORT --user=root --password=$NDB_DEFAULT_PASSWORD
}
