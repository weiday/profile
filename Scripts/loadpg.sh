export PGPORT=1930
export PGUSER=postgres
export PGDATA=$HOME/pgdata
export LANG=en_US.utf8
export PGHOME=$HOME/postgres

function pginit()
{
  rm -rf $PGDATA
  initdb -D $PGDATA -E=UTF8 --locale=C -U postgres

  echo "jit = on # allow JIT compilation" >> $PGDATA/postgresql.conf
  echo "jit_provider = 'llvmjit' # JIT implementation to use" >> $PGDATA/postgresql.conf
  echo "host all        all     0.0.0.0/0       md5" >> $PGDATA/pg_hba.conf
}

function pgstart()
{
  pg_ctl start > $PGDATA/error.log 2>&1
}

function pgstop()
{
  pg_ctl stop
}

function pgconnect()
{
  psql $*
}
